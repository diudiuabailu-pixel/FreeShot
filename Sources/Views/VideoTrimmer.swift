import Foundation
import AVFoundation
import AppKit

class VideoTrimmer {
    static let shared = VideoTrimmer()
    
    private init() {}
    
    /// 裁剪视频
    func trimVideo(inputURL: URL, startTime: Double, endTime: Double, outputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: inputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(NSError(domain: "VideoTrimmer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])))
            return
        }
        
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let end = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: start, end: end)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = timeRange
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(outputURL))
            case .failed:
                completion(.failure(exportSession.error ?? NSError(domain: "VideoTrimmer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])))
            case .cancelled:
                completion(.failure(NSError(domain: "VideoTrimmer", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"])))
            default:
                break
            }
        }
    }
    
    /// 选择视频并裁剪
    func trimSelectedVideo(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.message = "选择要裁剪的视频"
        
        openPanel.begin { response in
            guard response == .OK, let inputURL = openPanel.url else {
                completion(nil)
                return
            }
            
            // 显示裁剪对话框
            self.showTrimDialog(for: inputURL, completion: completion)
        }
    }
    
    private func showTrimDialog(for inputURL: URL, completion: @escaping (URL?) -> Void) {
        // 获取视频时长
        let asset = AVAsset(url: inputURL)
        let duration = CMTimeGetSeconds(asset.duration)
        
        let alert = NSAlert()
        alert.messageText = "裁剪视频"
        alert.informativeText = "视频时长: \(Int(duration))秒\n\n请输入裁剪时间（秒）:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "裁剪")
        alert.addButton(withTitle: "取消")
        
        // 创建输入框
        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 200, height: 60))
        stackView.orientation = .vertical
        stackView.spacing = 10
        
        let startLabel = NSTextField(labelWithString: "开始时间 (秒):")
        let startField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        startField.stringValue = "0"
        
        let endLabel = NSTextField(labelWithString: "结束时间 (秒):")
        let endField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        endField.stringValue = "\(Int(duration))"
        
        stackView.addArrangedSubview(startLabel)
        stackView.addArrangedSubview(startField)
        stackView.addArrangedSubview(endLabel)
        stackView.addArrangedSubview(endField)
        
        alert.accessoryView = stackView
        
        let response = alert.runModal()
        
        guard response == .alertFirstButtonReturn else {
            completion(nil)
            return
        }
        
        let startTime = Double(startField.stringValue) ?? 0
        let endTime = Double(endField.stringValue) ?? duration
        
        guard startTime < endTime && endTime <= duration else {
            completion(nil)
            return
        }
        
        // 保存对话框
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.mpeg4Movie]
        savePanel.nameFieldStringValue = inputURL.deletingPathExtension().lastPathComponent + "_trimmed.mp4"
        
        savePanel.begin { saveResponse in
            guard saveResponse == .OK, let outputURL = savePanel.url else {
                completion(nil)
                return
            }
            
            self.trimVideo(inputURL: inputURL, startTime: startTime, endTime: endTime, outputURL: outputURL) { result in
                switch result {
                case .success(let url):
                    completion(url)
                case .failure(let error):
                    print("Trim error: \(error)")
                    completion(nil)
                }
            }
        }
    }
}
