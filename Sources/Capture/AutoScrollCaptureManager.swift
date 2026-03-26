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
        // 硬性上限：防止内存溢出崩溃
        if capturedImages.count >= 200 {
            let result = stitchImages(capturedImages)
            capturedImages = []
            hideIndicator()
            isCapturing = false
            captureTimer?.invalidate()
            captureTimer = nil
            if let img = result { saveImage(img) }
            return
        }

        guard let screen = NSScreen.main else { return }

        let rect = CGRect(x: 0, y: 0, width: Int(screen.frame.width), height: Int(screen.frame.height))

        if let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) {
            capturedImages.append(image)
            updateProgress()
        }
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
    
    func saveImagePublic(_ image: NSImage) {
        saveImage(image)
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
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 70),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setupUI()
        positionWindow()
    }

    private func setupUI() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 70))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        container.layer?.cornerRadius = 12

        progressLabel = NSTextField(labelWithString: "滚动截图中... 0 张")
        progressLabel.frame = NSRect(x: 0, y: 38, width: 220, height: 20)
        progressLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        progressLabel.textColor = .white
        progressLabel.alignment = .center

        let stopButton = NSButton(frame: NSRect(x: 60, y: 8, width: 100, height: 24))
        stopButton.title = "停止并保存"
        stopButton.bezelStyle = .rounded
        stopButton.font = NSFont.systemFont(ofSize: 12)
        stopButton.target = self
        stopButton.action = #selector(stopCapture)

        container.addSubview(progressLabel)
        container.addSubview(stopButton)

        self.contentView = container
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let x = screenFrame.midX - 110
        let y = screenFrame.maxY - 90

        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func stopCapture() {
        AutoScrollCaptureManager.shared.stopCapture { image in
            guard let image = image else { return }
            AutoScrollCaptureManager.shared.saveImagePublic(image)
        }
    }

    func updateProgress(_ count: Int) {
        progressLabel.stringValue = "滚动截图中... \(count) 张"
    }
}
