import Foundation
import Vision
import AppKit

class OCRManager {
    static let shared = OCRManager()
    
    private init() {}
    
    /// 识别图片中的文字
    func recognizeText(in image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(NSError(domain: "OCRManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])))
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(NSError(domain: "OCRManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "No text found"])))
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            let result = recognizedStrings.joined(separator: "\n")
            completion(.success(result))
        }
        
        // 配置识别选项
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // 支持中文
        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 从文件识别文字
    func recognizeText(from url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let image = NSImage(contentsOf: url) else {
            completion(.failure(NSError(domain: "OCRManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])))
            return
        }
        
        recognizeText(in: image, completion: completion)
    }
    
    /// 显示识别结果
    func showOCRResult(from image: NSImage, onCopy: @escaping (String) -> Void) {
        recognizeText(in: image) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    if text.isEmpty {
                        self.showAlert(message: "未识别到文字")
                    } else {
                        onCopy(text)
                        self.showAlert(message: "文字已复制到剪贴板")
                    }
                case .failure(let error):
                    self.showAlert(message: "识别失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "OCR 识别结果"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
