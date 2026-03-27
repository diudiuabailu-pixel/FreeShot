import Foundation
import AppKit
import ScreenCaptureKit

class ScrollCaptureManager {
    static let shared = ScrollCaptureManager()

    private var isCapturing = false
    private var scrollView: NSView?
    private var captureTimer: Timer?
    private var capturedImages: [CGImage] = []
    private var lastScrollPosition: CGFloat = 0
    private var escMonitor: Any?
    private var completionHandler: ((NSImage?) -> Void)?

    private init() {}

    /// 开始滚动截图
    func startScrollCapture(completion: @escaping (NSImage?) -> Void = { _ in }) {
        guard !isCapturing else { return }

        isCapturing = true
        capturedImages = []
        completionHandler = completion

        // 显示滚动截图指示器
        showScrollIndicator()

        // 监听 ESC 键停止截图
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.finishCapture()
                return nil
            }
            return event
        }

        // 开始定时截取
        captureTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.captureScrollFrame()
        }
    }

    /// 停止滚动截图
    func stopScrollCapture(completion: @escaping (NSImage?) -> Void) {
        completionHandler = completion
        finishCapture()
    }

    private func finishCapture() {
        guard isCapturing else { return }

        isCapturing = false
        captureTimer?.invalidate()
        captureTimer = nil

        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }

        hideScrollIndicator()

        // 拼接图片
        let finalImage = stitchImages(capturedImages)
        capturedImages = []

        let handler = completionHandler
        completionHandler = nil
        handler?(finalImage)
    }
    
    private func captureScrollFrame() {
        guard let screen = NSScreen.main else { return }
        
        // 获取当前可见区域
        let visibleRect = CGRect(
            x: 0,
            y: 0,
            width: Int(screen.frame.width),
            height: Int(screen.frame.height)
        )
        
        if let image = CGWindowListCreateImage(
            visibleRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) {
            capturedImages.append(image)
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
    
    private func showScrollIndicator() {
        let indicator = ScrollCaptureIndicator()
        indicator.makeKeyAndOrderFront(nil)
    }
    
    private func hideScrollIndicator() {
        NSApp.windows.filter { $0 is ScrollCaptureIndicator }.forEach { $0.close() }
    }
    
    /// 检测是否需要停止（用户按 ESC）
    func checkStopCondition() -> Bool {
        return !isCapturing
    }
}

class ScrollCaptureIndicator: NSWindow {
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
        
        let label = NSTextField(labelWithString: L("scroll.capturing"))
        label.frame = NSRect(x: 0, y: 20, width: 200, height: 20)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        
        let tip = NSTextField(labelWithString: L("scroll.press_esc"))
        tip.frame = NSRect(x: 0, y: 5, width: 200, height: 15)
        tip.font = NSFont.systemFont(ofSize: 11)
        tip.textColor = .white.withAlphaComponent(0.7)
        tip.alignment = .center
        
        container.addSubview(label)
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
}
