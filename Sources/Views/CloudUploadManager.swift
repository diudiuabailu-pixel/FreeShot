import Foundation
import AppKit

class CloudUploadManager {
    static let shared = CloudUploadManager()
    
    private init() {}
    
    /// 上传图片到本地服务器（可扩展）
    func uploadImage(_ image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        // 转换为 PNG 数据
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            completion(.failure(NSError(domain: "CloudUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])))
            return
        }
        
        // 保存到本地分享文件夹
        let fileManager = FileManager.default
        let shareFolder = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FreeShot/Share")
        
        // 创建分享文件夹
        try? fileManager.createDirectory(at: shareFolder, withIntermediateDirectories: true)
        
        // 生成唯一文件名
        let fileName = "FreeShot-\(dateString()).png"
        let fileURL = shareFolder.appendingPathComponent(fileName)
        
        // 保存文件
        do {
            try pngData.write(to: fileURL)
            
            // 生成分享链接（本地文件 URL）
            let sharePath = "file://\(fileURL.path)"
            completion(.success(sharePath))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 上传视频
    func uploadVideo(at url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let fileManager = FileManager.default
        let shareFolder = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FreeShot/Share")
        
        try? fileManager.createDirectory(at: shareFolder, withIntermediateDirectories: true)
        
        let fileName = "FreeShot-\(dateString()).\(url.pathExtension)"
        let destURL = shareFolder.appendingPathComponent(fileName)
        
        do {
            try fileManager.copyItem(at: url, to: destURL)
            let sharePath = "file://\(destURL.path)"
            completion(.success(sharePath))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 打开分享面板
    func share(_ item: Any) {
        let picker = NSSharingServicePicker(items: [item])
        if let window = NSApp.keyWindow {
            picker.show(relativeTo: window.contentView!.bounds, of: window.contentView!, preferredEdge: .minY)
        }
    }
    
    /// 从文件分享
    func shareFile(at url: URL) {
        share(url)
    }
    
    /// 复制链接到剪贴板
    func copyLink(_ link: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(link, forType: .string)
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Share Sheet Extension

extension CloudUploadManager {
    /// 显示分享面板（包含系统分享选项）
    func showSharePanel(for url: URL) {
        let sharingService = NSSharingService(named: .composeEmail)
        
        if let window = NSApp.keyWindow {
            let picker = NSSharingServicePicker(items: [url])
            picker.show(relativeTo: window.contentView!.bounds, of: window.contentView!, preferredEdge: .minY)
        }
    }
}
