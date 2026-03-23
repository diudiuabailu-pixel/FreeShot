import Foundation
import AppKit
import ScreenCaptureKit

class AutoScrollCaptureManager {
    static let shared = AutoScrollCaptureManager()
    
    private var isCapturing = false
    private var capturedImages: [CGImage] = []
    private var lastScrollPosition: CGFloat = 0
    private var stableCount = 0
    private var captureTimer: Timer?
    private var indicatorWindow: AutoScrollIndicatorWindow?
    
    private init() {}
    
    /// 开始自动滚动截图
    func startCapture() {
        guard !isCapturing else { return }
        
        isCapturing = true
        capturedImages = []
        stableCount = 0
        
        // 显示指示器
        showIndicator()
        
        // 开始捕获
        captureTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.captureFrame()
        }
    }
    
    /// 停止捕获
    func stopCapture(completion: @escaping (NSImage?) -> Void) {
        guard isCapturing else { return }
        
        isCapturing = false
        captureTimer?.invalidate()
        captureTimer = nil
        
        hideIndicator()
        
        // 拼接图片
        let result = stitchImages(capturedImages)
        capturedImages = []
        
        completion(result)
    }
    
    private func captureFrame() {
        guard let screen = NSScreen.main else { return }
        
        let rect = CGRect(x: 0, y: 0, width: Int(screen.frame.width), height: Int(screen.frame.height))
        
        if let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) {
            // 检查是否停止滚动
            if checkIfShouldStop() {
                stableCount += 1
                if stableCount > 5 {
                    // 停止并保存
                    let result = stitchImages(capturedImages)
                    capturedImages = []
                    
                    // 隐藏指示器
                    hideIndicator()
                    isCapturing = false
                    captureTimer?.invalidate()
                    captureTimer = nil
                    
                    // 保存结果
                    if let img = result {
                        saveImage(img)
                    }
                    return
                }
            } else {
                stableCount = 0
            }
            
            capturedImages.append(image)
            updateProgress()
        }
    }
    
    private func checkIfShouldStop() -> Bool {
        // 简化检测：检查鼠标是否在滚动
        // 实际可以通过监控 scroll wheel 事件
        return false
    }
    
    private func stitchImages(_ images: [CGImage]) -> NSImage? {
        guard !images.isEmpty else { return nil }
        
        let width = images[0].width
        let height = images[0].height
        let totalHeight = height * images.count
        
        let stitchedImage = NSImage(size: NSSize(width: width, height: totalHeight))
        stitchedImage.lockFocus()
        
        for (index, image) in images.enumerated() {
            let nsImage = NSImage(cgImage: image, size: NSSize(width: CGFloat(width), height: CGFloat(height)))
            let yOffset = CGFloat(totalHeight - (index + 1) * height)
            nsImage.draw(
                in: NSRect(x: 0, y: yOffset, width: CGFloat(width), height: CGFloat(height)),
                from: NSRect(origin: .zero, size: nsImage.size),
                operation: .copy,
                fraction: 1.0
            )
        }
        
        stitchedImage.unlockFocus()
        return stitchedImage
    }
    
    private func saveImage(_ image: NSImage) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "FreeShot-Scroll-\(dateString()).png"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }
    
    private func showIndicator() {
        indicatorWindow = AutoScrollIndicatorWindow()
        indicatorWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func hideIndicator() {
        indicatorWindow?.close()
        indicatorWindow = nil
    }
    
    private func updateProgress() {
        indicatorWindow?.updateProgress(capturedImages.count)
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

class AutoScrollIndicatorWindow: NSWindow {
    private var progressLabel: NSTextField!
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        
        setupUI()
        positionWindow()
    }
    
    private func setupUI() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 60))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        container.layer?.cornerRadius = 12
        
        progressLabel = NSTextField(labelWithString: "滚动截图中... 0 张")
        progressLabel.frame = NSRect(x: 0, y: 20, width: 200, height: 20)
        progressLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        progressLabel.textColor = .white
        progressLabel.alignment = .center
        
        let tip = NSTextField(labelWithString: "停止滚动后自动保存")
        tip.frame = NSRect(x: 0, y: 5, width: 200, height: 15)
        tip.font = NSFont.systemFont(ofSize: 10)
        tip.textColor = .white.withAlphaComponent(0.7)
        tip.alignment = .center
        
        container.addSubview(progressLabel)
        container.addSubview(tip)
        
        self.contentView = container
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let x = screenFrame.midX - 100
        let y = screenFrame.maxY - 80
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func updateProgress(_ count: Int) {
        progressLabel.stringValue = "滚动截图中... \(count) 张"
    }
}
