import Foundation
import AppKit
import ScreenCaptureKit

class ScreenshotManager {
    static let shared = ScreenshotManager()

    private var screenshotWindow: RegionSelectorWindow?
    private var quickPreviewWindow: QuickPreviewWindow?
    private var lastScreenshotURL: URL?

    /// 截图前倒计时秒数（0 = 不倒计时）
    var timerSeconds: Int = 0

    private init() {}

    /// 当前用户设置的图片格式
    private var imageFormat: NSBitmapImageRep.FileType {
        let format = UserDefaults.standard.string(forKey: "imageFormat") ?? "png"
        switch format {
        case "jpeg": return .jpeg
        case "tiff": return .tiff
        default: return .png
        }
    }

    /// 当前用户设置的图片文件扩展名
    private var imageExtension: String {
        let format = UserDefaults.standard.string(forKey: "imageFormat") ?? "png"
        switch format {
        case "jpeg": return "jpg"
        case "tiff": return "tiff"
        default: return "png"
        }
    }

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

        let doCapture = { [weak self] in
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
                            self?.handleScreenshot(image)
                        }
                    }
                } catch {
                    print("Error capturing: \(error)")
                }
            }
        }

        if timerSeconds > 0 {
            let countdown = CountdownWindow(seconds: timerSeconds)
            countdown.show { doCapture() }
        } else {
            doCapture()
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
        // Bug 2: Convert AppKit coords (bottom-left origin) to CG coords (top-left origin)
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let imageRect = CGRect(x: rect.minX, y: screenHeight - rect.maxY, width: rect.width, height: rect.height)
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
        // 根据用户设置选择保存目录
        let saveDir: URL
        let customDir = UserDefaults.standard.string(forKey: "saveDirectory") ?? ""
        if !customDir.isEmpty, FileManager.default.fileExists(atPath: customDir) {
            saveDir = URL(fileURLWithPath: customDir)
        } else {
            saveDir = FileManager.default.temporaryDirectory
        }

        let fileName = "FreeShot-\(dateString()).\(imageExtension)"
        let fileURL = saveDir.appendingPathComponent(fileName)

        let bitmapRep = NSBitmapImageRep(cgImage: image)
        let properties: [NSBitmapImageRep.PropertyKey: Any] = imageFormat == .jpeg
            ? [.compressionFactor: 0.9] : [:]

        if let data = bitmapRep.representation(using: imageFormat, properties: properties) {
            try? data.write(to: fileURL)
            lastScreenshotURL = fileURL

            // 显示快速预览浮窗
            showQuickPreview(image: image, url: fileURL)

            // 同时保存到历史
            saveToHistory(url: fileURL)
        }
    }
    
    private func showQuickPreview(image: CGImage, url: URL) {
        quickPreviewWindow = QuickPreviewWindow(image: image, url: url)
        quickPreviewWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func saveToHistory(url: URL) {
        var history = ScreenshotHistory.shared.history
        history.insert(url, at: 0)
        
        // 只保留最近30天，最多100个
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        history = history.filter { url in
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let creationDate = attributes?[.creationDate] as? Date ?? Date()
            return creationDate > thirtyDaysAgo
        }
        
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        
        ScreenshotHistory.shared.history = history
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
