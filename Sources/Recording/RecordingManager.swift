import Foundation
import AppKit
import AVFoundation
import ScreenCaptureKit

class RecordingManager: NSObject {
    static let shared = RecordingManager()
    
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    
    private var outputURL: URL?
    private var isRecording = false
    private var includeCamera = false
    
    private var regionSelector: RegionSelectorWindow?
    private var cameraPreviewWindow: CameraPreviewWindow?
    
    // 摄像头位置配置
    var cameraPosition: CameraPosition = .bottomRight
    var cameraSize: CGSize = CGSize(width: 200, height: 150)
    var cameraCornerRadius: CGFloat = 12
    
    // 录屏选项
    var showMouseClicks = true
    var showKeystrokes = false
    
    private var countdownTimer: Timer?
    var countdownSeconds = 3
    
    override private init() {
        super.init()
    }
    
    // MARK: - Camera Position
    
    enum CameraPosition {
        case topLeft, topRight, bottomLeft, bottomRight
        
        func offset(in screenRect: CGRect, cameraSize: CGSize, padding: CGFloat = 20) -> CGPoint {
            switch self {
            case .topLeft:
                return CGPoint(x: padding, y: screenRect.height - cameraSize.height - padding)
            case .topRight:
                return CGPoint(x: screenRect.width - cameraSize.width - padding, y: screenRect.height - cameraSize.height - padding)
            case .bottomLeft:
                return CGPoint(x: padding, y: padding)
            case .bottomRight:
                return CGPoint(x: screenRect.width - cameraSize.width - padding, y: padding)
            }
        }
    }
    
    // MARK: - Public Methods
    
    func startRegionRecording(includeCamera: Bool) {
        self.includeCamera = includeCamera
        closePopover()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showRegionSelector()
        }
    }
    
    func startFullScreenRecording(includeCamera: Bool) {
        self.includeCamera = includeCamera
        closePopover()
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else { return }
                
                await MainActor.run {
                    self.startRecordingWithRegion(
                        CGRect(x: 0, y: 0, width: display.width, height: display.height),
                        includeCamera: includeCamera
                    )
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    func pauseRecording() {
        RecordingState.shared.pauseRecording()
    }
    
    func resumeRecording() {
        RecordingState.shared.resumeRecording()
    }
    
    func stopRecording() {
        isRecording = false
        
        // 停止键盘监听
        KeystrokeMonitor.shared.stopMonitoring()
        
        // 关闭摄像头预览窗口
        cameraPreviewWindow?.close()
        cameraPreviewWindow = nil
        
        Task {
            do {
                try await stream?.stopCapture()
            } catch {
                print("Error stopping stream: \(error)")
            }
            
            await MainActor.run {
                self.finishRecording()
            }
        }
    }
    
    func updateCameraPosition(_ position: CameraPosition) {
        cameraPosition = position
        cameraPreviewWindow?.updatePosition(position, size: cameraSize)
    }
    
    // MARK: - Countdown
    
    func startCountdown(completion: @escaping () -> Void) {
        guard countdownSeconds > 0 else {
            completion()
            return
        }
        
        // 显示倒计时窗口
        let countdownWindow = CountdownWindow(seconds: countdownSeconds)
        countdownWindow.show { [weak self] in
            self?.countdownTimer?.invalidate()
            completion()
        }
    }
    
    // MARK: - Private Methods
    
    private func closePopover() {
        NSApp.keyWindow?.close()
    }
    
    private func showRegionSelector() {
        regionSelector = RegionSelectorWindow()
        regionSelector?.makeKeyAndOrderFront(nil)
    }
    
    func startRecordingWithRegion(_ region: CGRect, includeCamera: Bool) {
        regionSelector?.close()
        
        // 显示录制指示器
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showRecordingIndicator()
        }
        
        // 如果需要摄像头，显示摄像头预览窗口
        if includeCamera {
            showCameraPreview()
        }
        
        // 如果开启键盘显示，启动键盘监听
        if showKeystrokes {
            KeystrokeMonitor.shared.startMonitoring()
        }
        
        RecordingState.shared.startRecording(includeCamera: includeCamera)
        
        Task {
            do {
                try await setupAndStartRecording(region: region, includeCamera: includeCamera)
            } catch {
                print("Recording error: \(error)")
                await MainActor.run {
                    RecordingState.shared.stopRecording()
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.hideRecordingIndicator()
                    }
                    self.cameraPreviewWindow?.close()
                }
            }
        }
    }
    
    private func showCameraPreview() {
        cameraPreviewWindow = CameraPreviewWindow(position: cameraPosition, size: cameraSize)
        cameraPreviewWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func setupAndStartRecording(region: CGRect, includeCamera: Bool) async throws {
        // 获取屏幕内容
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { return }
        
        // 创建录制过滤器 - 包含所有窗口（包括摄像头预览窗口）
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // 配置
        let config = SCStreamConfiguration()
        config.width = Int(region.width) * 2  // Retina
        config.height = Int(region.height) * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 5
        config.showsCursor = true
        config.capturesAudio = true
        
        // 鼠标点击高亮 - ScreenCaptureKit 默认显示鼠标点击
        // showMouseClicks 在 macOS 14+ 可以通过其他方式实现
        
        // 创建 AVAssetWriter
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreeShot-\(dateString()).mp4")
        self.outputURL = outputURL
        
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // 视频输入
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(region.width) * 2,
            AVVideoHeightKey: Int(region.height) * 2,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ])
        videoInput?.expectsMediaDataInRealTime = true
        
        if let videoInput = videoInput {
            assetWriter?.add(videoInput)
        }
        
        // 音频输入
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ])
        audioInput?.expectsMediaDataInRealTime = true
        
        if let audioInput = audioInput {
            assetWriter?.add(audioInput)
        }
        
        assetWriter?.startWriting()
        assetWriter?.startSession(atSourceTime: .zero)
        
        // 创建并启动 SCStream
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        
        if let stream = stream {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .main)
            try await stream.startCapture()
            isRecording = true
        }
    }
    
    private func finishRecording() {
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        assetWriter?.finishWriting { [weak self] in
            guard let self = self, let url = self.outputURL else { return }
            
            DispatchQueue.main.async {
                self.saveRecording(url: url)
            }
        }
        
        RecordingState.shared.stopRecording()
    }
    
    private func saveRecording(url: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        savePanel.nameFieldStringValue = "FreeShot-\(dateString()).mp4"
        
        if savePanel.runModal() == .OK, let destURL = savePanel.url {
            try? FileManager.default.copyItem(at: url, to: destURL)
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - SCStreamDelegate

extension RecordingManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
        finishRecording()
    }
}

// MARK: - SCStreamOutput

extension RecordingManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard isRecording else { return }
        
        switch type {
        case .screen:
            if videoInput?.isReadyForMoreMediaData == true {
                videoInput?.append(sampleBuffer)
            }
        case .audio:
            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            }
        @unknown default:
            break
        }
    }
}
