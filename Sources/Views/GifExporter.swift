import Foundation
import AVFoundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

class GifExporter {
    static let shared = GifExporter()
    
    private init() {}
    
    /// 将视频转换为 GIF
    func exportGif(from videoURL: URL, outputURL: URL, fps: Int = 15, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        
        let duration = CMTimeGetSeconds(asset.duration)
        let frameCount = Int(duration * Double(fps))
        
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
            completion(.failure(NSError(domain: "GifExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create GIF destination"])))
            return
        }
        
        // GIF 属性
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0  // 无限循环
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
        
        // 生成帧
        var frameTimes: [NSValue] = []
        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) / Double(fps), preferredTimescale: 600)
            frameTimes.append(NSValue(time: time))
        }
        
        var framesGenerated = 0
        var framesProcessed = 0
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: frameTimes) { requestedTime, cgImage, actualTime, result, error in
            framesProcessed += 1
            
            if let cgImage = cgImage {
                let frameProperties: [String: Any] = [
                    kCGImagePropertyGIFDictionary as String: [
                        kCGImagePropertyGIFDelayTime as String: 1.0 / Double(fps)
                    ]
                ]
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                framesGenerated += 1
            }
            
            if framesProcessed == frameCount {
                if framesGenerated > 0 {
                    CGImageDestinationFinalize(destination)
                    DispatchQueue.main.async {
                        completion(.success(outputURL))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "GifExporter", code: -2, userInfo: [NSLocalizedDescriptionKey: "No frames could be extracted from video"])))
                    }
                }
            }
        }
    }
    
    /// 视频转 GIF（用户选择文件）
    func convertVideoToGif(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.message = L("gif.select_video")
        
        openPanel.begin { response in
            guard response == .OK, let videoURL = openPanel.url else {
                completion(nil)
                return
            }
            
            // 保存对话框
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.gif]
            savePanel.nameFieldStringValue = videoURL.deletingPathExtension().lastPathComponent + ".gif"
            savePanel.message = L("gif.save_title")
            
            savePanel.begin { saveResponse in
                guard saveResponse == .OK, let outputURL = savePanel.url else {
                    completion(nil)
                    return
                }
                
                self.exportGif(from: videoURL, outputURL: outputURL) { result in
                    switch result {
                    case .success(let url):
                        completion(url)
                    case .failure(let error):
                        print("GIF export error: \(error)")
                        completion(nil)
                    }
                }
            }
        }
    }
}
