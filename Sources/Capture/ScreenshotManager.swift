import Foundation
import AppKit
import ScreenCaptureKit

class ScreenshotManager {
    static let shared = ScreenshotManager()
    
    private var screenshotWindow: RegionSelectorWindow?
    private var quickPreviewWindow: QuickPreviewWindow?
    private var lastScreenshotURL: URL?
    
    private init() {}
    
    // MARK: - 截图方法
    
    /// 截取区域
    func captureRegion() {
        NSApp.keyWindow?.close()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showRegionSelector()
        }
    }
    
    /// 截取窗口
    func captureWindow() {
        NSApp.keyWindow?.close()
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let windows = content.windows.filter { $0.isOnScreen && !($0.title?.isEmpty ?? true) }

                await MainActor.run {
                    self.showWindowPicker(windows: windows)
                }
            } catch {
                AppDelegate.showError("获取窗口列表失败：\(error.localizedDescription)")
            }
        }
    }
    
    /// 截取全屏
    func captureFullScreen() {
        NSApp.keyWindow?.close()
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else { return }
                
                let screenFrame = CGRect(x: 0, y: 0, width: display.width, height: display.height)
                
                if let image = CGWindowListCreateImage(
                    screenFrame,
                    .optionOnScreenOnly,
                    kCGNullWindowID,
                    [.bestResolution, .boundsIgnoreFraming]
                ) {
                    await MainActor.run {
                        self.handleScreenshot(image)
                    }
                }
            } catch {
                AppDelegate.showError("截图失败：\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func showRegionSelector() {
        screenshotWindow = RegionSelectorWindow(onSelected: { [weak self] rect in
            self?.captureRegionImage(in: rect)
        })
        screenshotWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func showWindowPicker(windows: [SCWindow]) {
        let picker = WindowPickerWindow(windows: windows)
        picker.makeKeyAndOrderFront(nil)
    }
    
    private func captureRegionImage(in rect: CGRect) {
        let imageRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        if let image = CGWindowListCreateImage(
            imageRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) {
            handleScreenshot(image)
        }
    }

    private func handleScreenshot(_ image: CGImage) {
        // 保存到临时文件
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreeShot-\(dateString()).png")
        
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        if let data = bitmapRep.representation(using: .png, properties: [:]) {
            try? data.write(to: tempURL)
            lastScreenshotURL = tempURL
            
            // 显示快速预览浮窗
            showQuickPreview(image: image, url: tempURL)
            
            // 同时保存到历史
            saveToHistory(url: tempURL)
        }
    }
    
    private func showQuickPreview(image: CGImage, url: URL) {
        quickPreviewWindow = QuickPreviewWindow(image: image, url: url)
        quickPreviewWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func saveToHistory(url: URL) {
        ScreenshotHistory.shared.add(url)
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
