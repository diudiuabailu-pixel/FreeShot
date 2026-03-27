import Foundation
import AppKit
import ScreenCaptureKit
import UniformTypeIdentifiers

class AutoScrollCaptureManager {
    static let shared = AutoScrollCaptureManager()

    private var isCapturing = false
    private var capturedImages: [CGImage] = []
    private var lastScrollPosition: CGFloat = 0
    private var stableCount = 0
    private var captureTimer: Timer?
    private var indicatorWindow: AutoScrollIndicatorWindow?
    private var escMonitor: Any?
    private var scrollMonitor: Any?
    private var lastScrollEventTime: Date = Date()
    private var hasReceivedScrollEvent = false

    private init() {}

    /// 开始自动滚动截图
    func startCapture() {
        guard !isCapturing else { return }

        isCapturing = true
        capturedImages = []
        stableCount = 0
        hasReceivedScrollEvent = false
        lastScrollEventTime = Date()

        // 显示指示器
        showIndicator()

        // 监听 ESC 键停止截图
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.finishAndSave()
                return nil
            }
            return event
        }

        // 监听滚动事件，记录最后滚动时间
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.isCapturing else { return }
            if event.scrollingDeltaY != 0 {
                self.hasReceivedScrollEvent = true
                self.lastScrollEventTime = Date()
                self.stableCount = 0
            }
        }

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
        removeMonitors()
        hideIndicator()

        // 拼接图片
        let result = stitchImages(capturedImages)
        capturedImages = []

        completion(result)
    }

    private func removeMonitors() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }
    
    private func captureFrame() {
        guard isCapturing, let screen = NSScreen.main else { return }

        let rect = CGRect(x: 0, y: 0, width: Int(screen.frame.width), height: Int(screen.frame.height))

        if let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) {
            // 检查用户是否停止滚动（超过 1.5 秒无滚动事件）
            if checkIfShouldStop() {
                stableCount += 1
                if stableCount > 5 {
                    finishAndSave()
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
        // 只有在收到过滚动事件后才检测停止
        guard hasReceivedScrollEvent else { return false }
        // 超过 1.5 秒没有滚动事件，认为滚动停止
        return Date().timeIntervalSince(lastScrollEventTime) > 1.5
    }

    private func finishAndSave() {
        guard isCapturing else { return }

        isCapturing = false
        captureTimer?.invalidate()
        captureTimer = nil
        removeMonitors()
        hideIndicator()

        let result = stitchImages(capturedImages)
        capturedImages = []

        if let img = result {
            saveImage(img)
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
        
        progressLabel = NSTextField(labelWithString: L("scroll.count", 0))
        progressLabel.frame = NSRect(x: 0, y: 20, width: 200, height: 20)
        progressLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        progressLabel.textColor = .white
        progressLabel.alignment = .center
        
        let tip = NSTextField(labelWithString: L("scroll.auto_stop"))
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
        progressLabel.stringValue = L("scroll.count", count)
    }
}
