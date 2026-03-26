import Foundation
import AppKit
import CoreGraphics

class MouseClickOverlayWindow: NSWindow {
    init() {
        guard let screen = NSScreen.main else {
            super.init(
                contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            return
        }

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false

        let view = MouseClickCanvasView(frame: screen.frame)
        self.contentView = view
    }

    func showClickEffect(at screenPoint: NSPoint, isRightClick: Bool = false) {
        guard let canvasView = contentView as? MouseClickCanvasView else { return }
        let windowPoint = convertPoint(fromScreen: screenPoint)
        canvasView.addClickEffect(at: windowPoint, isRightClick: isRightClick)
    }
}

class MouseClickCanvasView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addClickEffect(at point: NSPoint, isRightClick: Bool) {
        let effectSize: CGFloat = 40
        let effectFrame = NSRect(
            x: point.x - effectSize / 2,
            y: point.y - effectSize / 2,
            width: effectSize,
            height: effectSize
        )

        let effectLayer = CAShapeLayer()
        let circlePath = CGPath(ellipseIn: CGRect(origin: .zero, size: CGSize(width: effectSize, height: effectSize)), transform: nil)
        effectLayer.path = circlePath
        effectLayer.fillColor = NSColor.clear.cgColor
        effectLayer.strokeColor = isRightClick ? NSColor.orange.withAlphaComponent(0.8).cgColor : NSColor.systemBlue.withAlphaComponent(0.8).cgColor
        effectLayer.lineWidth = 2.5
        effectLayer.frame = effectFrame

        layer?.addSublayer(effectLayer)

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.5
        scaleAnimation.toValue = 1.5

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 1.0
        opacityAnimation.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [scaleAnimation, opacityAnimation]
        group.duration = 0.5
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            effectLayer.removeFromSuperlayer()
        }
        effectLayer.add(group, forKey: "clickEffect")
        CATransaction.commit()
    }
}

class MouseClickMonitor {
    static let shared = MouseClickMonitor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var overlayWindow: MouseClickOverlayWindow?
    private var isMonitoring = false

    private init() {}

    func startMonitoring() {
        guard !isMonitoring else { return }

        let eventMask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, _ in
                MouseClickMonitor.shared.handleEvent(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            NSLog("[FreeShot] Failed to create mouse event tap for click display.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isMonitoring = true

            DispatchQueue.main.async {
                self.overlayWindow = MouseClickOverlayWindow()
                self.overlayWindow?.orderFront(nil)
            }
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isMonitoring = false

        DispatchQueue.main.async {
            self.overlayWindow?.close()
            self.overlayWindow = nil
        }
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let location = event.location
        let isRightClick = type == .rightMouseDown

        let screenHeight = NSScreen.main?.frame.height ?? 0
        let flippedPoint = NSPoint(x: location.x, y: screenHeight - location.y)

        DispatchQueue.main.async {
            self.overlayWindow?.showClickEffect(at: NSPoint(x: location.x, y: flippedPoint.y), isRightClick: isRightClick)
        }
    }
}
