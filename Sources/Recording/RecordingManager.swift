import Foundation
import AppKit
import AVFoundation
import ScreenCaptureKit
import CoreGraphics
import ApplicationServices

final class RecordingManager: NSObject {
    static let shared = RecordingManager()

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?

    private var outputURL: URL?
    private var isRecording = false
    private var isPaused = false  // Bug 4: track pause state for frame skipping
    private var includeCamera = false

    // Bug 1: Track session start for correct timestamp alignment
    private var sessionStarted = false
    private var firstSampleTime: CMTime?

    // 暂停时间戳偏移（消除恢复后的视频时间跳跃）
    private var pauseTimeOffset: CMTime = .zero
    private var lastPauseTime: CMTime = .zero

    private var regionSelector: RegionSelectorWindow?
    private var cameraPreviewWindow: CameraPreviewWindow?

    // 摄像头位置配置
    var cameraPosition: CameraPosition = .bottomRight
    var cameraSize: CGSize = CGSize(width: 200, height: 150)
    var cameraCornerRadius: CGFloat = 12

    // 录屏选项
    var showMouseClicks = true
    var showKeystrokes = false
    var microphoneEnabled = true
    var systemAudioEnabled = true

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

    enum RecordingPreparationError: LocalizedError {
        case screenRecordingPermissionDenied
        case accessibilityPermissionDenied
        case noDisplayAvailable
        case invalidRegion
        case fileCreationFailed(String)
        case cameraPermissionDenied
        case microphonePermissionDenied

        var errorDescription: String? {
            switch self {
            case .screenRecordingPermissionDenied:
                return "未授予屏幕录制权限。请到 系统设置 > 隐私与安全性 > 屏幕录制 中开启 FreeShot。"
            case .accessibilityPermissionDenied:
                return "显示按键需要辅助功能权限。请到 系统设置 > 隐私与安全性 > 辅助功能 中开启 FreeShot。"
            case .noDisplayAvailable:
                return "没有找到可录制的显示器。"
            case .invalidRegion:
                return "录制区域无效，请重新选择。"
            case .fileCreationFailed(let message):
                return "创建录制文件失败：\(message)"
            case .cameraPermissionDenied:
                return "未授予摄像头权限。请到 系统设置 > 隐私与安全性 > 摄像头 中开启 FreeShot。"
            case .microphonePermissionDenied:
                return "未授予麦克风权限。请到 系统设置 > 隐私与安全性 > 麦克风 中开启 FreeShot。"
            }
        }
    }

    // MARK: - Public Methods

    func startRegionRecording(includeCamera: Bool) {
        self.includeCamera = includeCamera
        closePopover()

        Task { @MainActor in
            do {
                try await prepareForRecording(needsRegionSelection: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showRegionSelector()
                }
            } catch {
                self.present(error: error)
            }
        }
    }

    func startFullScreenRecording(includeCamera: Bool) {
        self.includeCamera = includeCamera
        closePopover()

        Task { @MainActor in
            do {
                try await prepareForRecording(needsRegionSelection: false)
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    throw RecordingPreparationError.noDisplayAvailable
                }

                // Bug 6: Full screen rect is already in CG coordinates, pass isFullScreen flag
                let fullRegion = CGRect(x: 0, y: 0, width: display.width, height: display.height)
                self.startCountdown {
                    self.beginRecording(region: fullRegion, includeCamera: includeCamera, preferredDisplayID: display.displayID, isFullScreen: true)
                }
            } catch {
                self.present(error: error)
            }
        }
    }

    func pauseRecording() {
        isPaused = true  // Bug 4: actually stop writing frames
        RecordingState.shared.pauseRecording()
    }

    func resumeRecording() {
        isPaused = false  // Bug 4: resume writing frames
        RecordingState.shared.resumeRecording()
    }

    func stopRecording() {
        isRecording = false
        isPaused = false

        KeystrokeMonitor.shared.stopMonitoring()
        MouseClickMonitor.shared.stopMonitoring()
        cameraPreviewWindow?.close()
        cameraPreviewWindow = nil

        Task {
            do {
                try await stream?.stopCapture()
            } catch {
                NSLog("[FreeShot] Error stopping capture stream: %@", error.localizedDescription)
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

    func updateCameraSize(_ size: CGSize) {
        cameraSize = size
        cameraPreviewWindow?.updatePosition(cameraPosition, size: size)
    }

    // MARK: - Countdown

    func startCountdown(completion: @escaping () -> Void) {
        guard countdownSeconds > 0 else {
            completion()
            return
        }

        let countdownWindow = CountdownWindow(seconds: countdownSeconds)
        countdownWindow.show {
            completion()
        }
    }

    // MARK: - Public Entry for Multi-Display (CG coordinates)

    func startRecordingWithRegion(_ region: CGRect, includeCamera: Bool, preferredDisplayID: CGDirectDisplayID? = nil) {
        // Called from MultiDisplayManager with CG coordinates
        beginRecording(region: region, includeCamera: includeCamera, preferredDisplayID: preferredDisplayID, isFullScreen: true)
    }

    // MARK: - State Reset (Bug 5)

    private func resetState() {
        stream = nil
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        outputURL = nil
        isRecording = false
        isPaused = false
        sessionStarted = false
        firstSampleTime = nil
        pauseTimeOffset = .zero
        lastPauseTime = .zero
    }

    // MARK: - Private Methods

    private func closePopover() {
        NSApp.keyWindow?.close()
    }

    @MainActor
    private func prepareForRecording(needsRegionSelection: Bool) async throws {
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
            throw RecordingPreparationError.screenRecordingPermissionDenied
        }

        if showKeystrokes {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            guard AXIsProcessTrustedWithOptions(options) else {
                throw RecordingPreparationError.accessibilityPermissionDenied
            }
        }

        if includeCamera {
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            switch cameraStatus {
            case .notDetermined:
                let granted = await requestMediaAccess(for: .video)
                if !granted { throw RecordingPreparationError.cameraPermissionDenied }
            case .denied, .restricted:
                throw RecordingPreparationError.cameraPermissionDenied
            case .authorized:
                break
            @unknown default:
                break
            }
        }

        if microphoneEnabled {
            let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            switch micStatus {
            case .notDetermined:
                let granted = await requestMediaAccess(for: .audio)
                if !granted { throw RecordingPreparationError.microphonePermissionDenied }
            case .denied, .restricted:
                throw RecordingPreparationError.microphonePermissionDenied
            case .authorized:
                break
            @unknown default:
                break
            }
        }

        if !needsRegionSelection && countdownSeconds < 0 {
            countdownSeconds = 0
        }
    }

    private func showRegionSelector() {
        regionSelector = RegionSelectorWindow(onSelected: { [weak self] rect in
            guard let self else { return }
            // Bug 3: Region selector returns AppKit coords, convert to CG here
            let screenHeight = NSScreen.main?.frame.height ?? 0
            let cgRect = CGRect(x: rect.minX, y: screenHeight - rect.maxY, width: rect.width, height: rect.height)
            self.beginRecording(region: cgRect, includeCamera: RecordingState.shared.includeCamera, preferredDisplayID: nil, isFullScreen: false)
        })
        regionSelector?.makeKeyAndOrderFront(nil)
    }

    private func beginRecording(region: CGRect, includeCamera: Bool, preferredDisplayID: CGDirectDisplayID?, isFullScreen: Bool) {
        regionSelector?.close()

        guard region.width > 1, region.height > 1 else {
            present(error: RecordingPreparationError.invalidRegion)
            return
        }

        // Bug 5: Reset state before starting new recording
        resetState()

        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showRecordingIndicator()
        }

        if includeCamera {
            showCameraPreview()
        }

        if showKeystrokes {
            KeystrokeMonitor.shared.startMonitoring()
        }

        if showMouseClicks {
            MouseClickMonitor.shared.startMonitoring()
        }

        RecordingState.shared.startRecording(includeCamera: includeCamera)

        startCountdown {
            Task {
                do {
                    try await self.setupAndStartRecording(region: region, includeCamera: includeCamera, preferredDisplayID: preferredDisplayID, isFullScreen: isFullScreen)
                } catch {
                    await MainActor.run {
                        RecordingState.shared.stopRecording()
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.hideRecordingIndicator()
                        }
                        self.cameraPreviewWindow?.close()
                        self.cameraPreviewWindow = nil
                        self.present(error: error)
                    }
                }
            }
        }
    }

    private func showCameraPreview() {
        cameraPreviewWindow = CameraPreviewWindow(position: cameraPosition, size: cameraSize)
        cameraPreviewWindow?.makeKeyAndOrderFront(nil)
    }

    private func setupAndStartRecording(region: CGRect, includeCamera: Bool, preferredDisplayID: CGDirectDisplayID?, isFullScreen: Bool) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let targetDisplay = try pickDisplay(from: content.displays, preferredDisplayID: preferredDisplayID, region: region)

        // Bug 3 & 6: region is now always in CG coordinates
        let sourceRect: CGRect
        if isFullScreen {
            // Full screen: use full display dimensions directly
            sourceRect = CGRect(x: 0, y: 0, width: CGFloat(targetDisplay.width), height: CGFloat(targetDisplay.height))
        } else {
            sourceRect = try makeDisplayRelativeRect(from: region, displayID: targetDisplay.displayID)
        }

        guard sourceRect.width > 0, sourceRect.height > 0 else {
            throw RecordingPreparationError.invalidRegion
        }

        let scaleFactor = scaleFactorForDisplay(targetDisplay.displayID)
        let filter = SCContentFilter(display: targetDisplay, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.width = max(Int(sourceRect.width * scaleFactor), 2)
        config.height = max(Int(sourceRect.height * scaleFactor), 2)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 5
        config.showsCursor = true
        config.capturesAudio = systemAudioEnabled || microphoneEnabled
        if #available(macOS 14.0, *) {
            if #available(macOS 15.0, *) {
                config.captureMicrophone = microphoneEnabled
            }
        }
        config.sourceRect = sourceRect

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreeShot-\(dateString()).mp4")
        self.outputURL = outputURL

        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let bitRate: Int
        switch UserDefaults.standard.string(forKey: "videoQuality") ?? "high" {
        case "low": bitRate = 3_000_000
        case "medium": bitRate = 6_000_000
        default: bitRate = 10_000_000
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.width,
            AVVideoHeightKey: config.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        guard let videoInput else {
            throw RecordingPreparationError.fileCreationFailed("无法创建视频输入")
        }
        assetWriter?.add(videoInput)

        if systemAudioEnabled || microphoneEnabled {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true
            if let audioInput {
                assetWriter?.add(audioInput)
            }
        } else {
            audioInput = nil
        }

        guard assetWriter?.startWriting() == true else {
            throw RecordingPreparationError.fileCreationFailed(assetWriter?.error?.localizedDescription ?? "未知错误")
        }
        // Bug 1: Do NOT startSession here; wait for first sample buffer timestamp
        // assetWriter?.startSession(atSourceTime: .zero) -- REMOVED
        sessionStarted = false
        firstSampleTime = nil

        stream = SCStream(filter: filter, configuration: config, delegate: self)

        if let stream {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
            if systemAudioEnabled || microphoneEnabled {
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .main)
            }
            try await stream.startCapture()
            isRecording = true
        }
    }

    private func pickDisplay(from displays: [SCDisplay], preferredDisplayID: CGDirectDisplayID?, region: CGRect) throws -> SCDisplay {
        if let preferredDisplayID,
           let preferred = displays.first(where: { $0.displayID == preferredDisplayID }) {
            return preferred
        }

        let globalMidPoint = CGPoint(x: region.midX, y: region.midY)
        for display in displays {
            let frame = CGDisplayBounds(display.displayID)
            if frame.contains(globalMidPoint) {
                return display
            }
        }

        guard let first = displays.first else {
            throw RecordingPreparationError.noDisplayAvailable
        }
        return first
    }

    private func scaleFactorForDisplay(_ displayID: CGDirectDisplayID) -> CGFloat {
        NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        })?.backingScaleFactor ?? 2.0
    }

    // Bug 3: Now expects CG coordinates (top-left origin) as input
    private func makeDisplayRelativeRect(from cgRegion: CGRect, displayID: CGDirectDisplayID) throws -> CGRect {
        let displayBounds = CGDisplayBounds(displayID)

        let clippedGlobal = cgRegion.intersection(displayBounds)
        guard !clippedGlobal.isNull, clippedGlobal.width > 0, clippedGlobal.height > 0 else {
            throw RecordingPreparationError.invalidRegion
        }

        // sourceRect is in display-local CG coordinates (top-left origin)
        let localX = clippedGlobal.minX - displayBounds.minX
        let localY = clippedGlobal.minY - displayBounds.minY

        return CGRect(x: localX, y: localY, width: clippedGlobal.width, height: clippedGlobal.height)
    }

    private func requestMediaAccess(for mediaType: AVMediaType) async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func finishRecording() {
        guard assetWriter != nil else { return }

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        let writer = assetWriter
        let url = outputURL

        assetWriter = nil
        videoInput = nil
        audioInput = nil

        writer?.finishWriting { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }

                RecordingState.shared.stopRecording()
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.hideRecordingIndicator()
                }
                self.stream = nil
                self.sessionStarted = false
                self.firstSampleTime = nil
                self.pauseTimeOffset = .zero
                self.lastPauseTime = .zero

                guard writer?.status == .completed else {
                    let errorMsg = writer?.error?.localizedDescription ?? "写入文件时发生未知错误"
                    self.present(error: RecordingPreparationError.fileCreationFailed(errorMsg))
                    if let url { try? FileManager.default.removeItem(at: url) }
                    return
                }

                guard let url,
                      FileManager.default.fileExists(atPath: url.path),
                      (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0 > 0 else {
                    self.present(error: RecordingPreparationError.fileCreationFailed("录制文件为空或不存在"))
                    return
                }

                self.saveRecording(url: url)
            }
        }
    }

    private func saveRecording(url: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        savePanel.nameFieldStringValue = "FreeShot-\(dateString()).mp4"

        if savePanel.runModal() == .OK, let destURL = savePanel.url {
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: url, to: destURL)
                try? FileManager.default.removeItem(at: url)
            } catch {
                present(error: error)
            }
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func present(error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "录制失败"
            alert.informativeText = message
            alert.addButton(withTitle: "好")
            alert.runModal()
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
        NSLog("[FreeShot] Stream stopped with error: %@", error.localizedDescription)
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.present(error: error)
            self?.finishRecording()
        }
    }
}

// MARK: - SCStreamOutput

extension RecordingManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard isRecording else { return }

        // Bug 4: Skip frames while paused, record pause start time
        if isPaused {
            if lastPauseTime == .zero {
                lastPauseTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            }
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Bug 1: Start session with first real sample timestamp
        if !sessionStarted {
            guard timestamp.isValid, timestamp.seconds > 0 else { return }
            assetWriter?.startSession(atSourceTime: timestamp)
            sessionStarted = true
            firstSampleTime = timestamp
        }

        // Accumulate pause duration on resume
        if lastPauseTime != .zero {
            let pauseDuration = CMTimeSubtract(timestamp, lastPauseTime)
            pauseTimeOffset = CMTimeAdd(pauseTimeOffset, pauseDuration)
            lastPauseTime = .zero
        }

        // Adjust timestamp to remove pause gaps
        let bufferToWrite: CMSampleBuffer
        if pauseTimeOffset > .zero {
            let adjustedTime = CMTimeSubtract(timestamp, pauseTimeOffset)
            var timing = CMSampleTimingInfo(
                duration: CMSampleBufferGetDuration(sampleBuffer),
                presentationTimeStamp: adjustedTime,
                decodeTimeStamp: .invalid
            )
            var adjustedBuffer: CMSampleBuffer?
            let status = CMSampleBufferCreateCopyWithNewTiming(
                allocator: nil,
                sampleBuffer: sampleBuffer,
                sampleTimingEntryCount: 1,
                sampleTimingArray: &timing,
                sampleBufferOut: &adjustedBuffer
            )
            bufferToWrite = (status == noErr && adjustedBuffer != nil) ? adjustedBuffer! : sampleBuffer
        } else {
            bufferToWrite = sampleBuffer
        }

        switch type {
        case .screen:
            if videoInput?.isReadyForMoreMediaData == true {
                videoInput?.append(bufferToWrite)
            }
        case .audio:
            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(bufferToWrite)
            }
        @unknown default:
            break
        }
    }
}
