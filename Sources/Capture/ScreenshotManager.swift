import Foundation
import AppKit
import ScreenCaptureKit

class ScreenshotManager {
    static let shared = ScreenshotManager()
    
    private var screenshotWindow: RegionSelectorWindow?
    
    private init() {}
    
    // MARK: - 截图方法
    
    /// 截取区域
    func captureRegion() {
        NSApp.keyWindow?.close()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showRegionSelector(mode: .region)
        }
    }
    
    /// 截取窗口
    func captureWindow() {
        NSApp.keyWindow?.close()
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let windows = content.windows.filter { $0.isOnScreen && ($0.title?.isEmpty ?? true) == false }
                
                await MainActor.run {
                    self.showWindowPicker(windows: windows)
                }
            } catch {
                print("Error getting windows: \(error)")
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
                        self.saveScreenshot(image)
                    }
                }
            } catch {
                print("Error capturing: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func showRegionSelector(mode: ScreenshotMode) {
        screenshotWindow = RegionSelectorWindow()
        screenshotWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func showWindowPicker(windows: [SCWindow]) {
        let picker = WindowPickerWindow(windows: windows)
        picker.makeKeyAndOrderFront(nil)
    }
    
    private func saveScreenshot(_ image: CGImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "FreeShot-\(dateString()).png"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let bitmapRep = NSBitmapImageRep(cgImage: image)
                if let data = bitmapRep.representation(using: .png, properties: [:]) {
                    try? data.write(to: url)
                }
            }
        }
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

enum ScreenshotMode {
    case region
    case window
    case fullScreen
}
