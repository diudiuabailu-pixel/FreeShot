import AppKit

final class RegionSelectorWindow: NSWindow {
    private var selectionView: RegionSelectionView!
    private var overlayView: NSView!

    private let onSelected: (NSRect) -> Void
    private let onCancel: (() -> Void)?

    init(onSelected: @escaping (NSRect) -> Void, onCancel: (() -> Void)? = nil) {
        self.onSelected = onSelected
        self.onCancel = onCancel

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setupOverlay()
    }

    private func setupOverlay() {
        overlayView = NSView(frame: frame)
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor

        selectionView = RegionSelectionView(frame: frame)
        selectionView.delegate = self

        overlayView.addSubview(selectionView)
        contentView = overlayView
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            close()
        }
        super.keyDown(with: event)
    }
}

extension RegionSelectorWindow: RegionSelectionDelegate {
    func regionSelected(_ rect: NSRect) {
        onSelected(rect)
        close()
    }

    func selectionCancelled() {
        onCancel?()
        close()
    }
}

protocol RegionSelectionDelegate: AnyObject {
    func regionSelected(_ rect: NSRect)
    func selectionCancelled()
}

final class RegionSelectionView: NSView {
    weak var delegate: RegionSelectionDelegate?

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let start = startPoint, let current = currentPoint else { return }

        let selectionRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )

        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)

        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: selectionRect)
        path.lineWidth = 2
        path.stroke()

        let sizeText = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        let textSize = sizeText.size(withAttributes: attrs)
        let textRect = NSRect(
            x: selectionRect.maxX - textSize.width - 8,
            y: max(selectionRect.minY - textSize.height - 8, 8),
            width: textSize.width + 8,
            height: textSize.height + 4
        )
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4).fill()
        sizeText.draw(at: NSPoint(x: textRect.minX + 4, y: textRect.minY + 2), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = startPoint, let current = currentPoint else { return }

        let rect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )

        if rect.width > 50 && rect.height > 50 {
            delegate?.regionSelected(rect)
        } else {
            delegate?.selectionCancelled()
        }
    }
}
