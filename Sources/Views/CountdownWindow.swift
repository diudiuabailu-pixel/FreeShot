import AppKit

class CountdownWindow: NSWindow {
    private var seconds: Int
    private var countdownLabel: NSTextField!
    private var completion: (() -> Void)?
    private var countdownTimer: Timer?
    
    init(seconds: Int) {
        self.seconds = seconds
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        setupUI()
        positionWindow()
    }
    
    private func setupUI() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        container.layer?.cornerRadius = 20
        
        countdownLabel = NSTextField(labelWithString: "\(seconds)")
        countdownLabel.frame = NSRect(x: 0, y: 60, width: 200, height: 80)
        countdownLabel.font = NSFont.systemFont(ofSize: 80, weight: .bold)
        countdownLabel.textColor = .white
        countdownLabel.alignment = .center
        
        let tipLabel = NSTextField(labelWithString: "即将开始录制...")
        tipLabel.frame = NSRect(x: 0, y: 20, width: 200, height: 30)
        tipLabel.font = NSFont.systemFont(ofSize: 16)
        tipLabel.textColor = .white
        tipLabel.alignment = .center
        
        container.addSubview(countdownLabel)
        container.addSubview(tipLabel)
        
        self.contentView = container
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let x = screenFrame.midX - 100
        let y = screenFrame.midY - 100
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func show(completion: @escaping () -> Void) {
        self.completion = completion
        self.makeKeyAndOrderFront(nil)
        
        startCountdown()
    }
    
    private func startCountdown() {
        var remaining = seconds

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            remaining -= 1

            if remaining > 0 {
                self.countdownLabel.stringValue = "\(remaining)"
            } else {
                timer.invalidate()
                self.countdownTimer = nil
                self.close()
                self.completion?()
            }
        }
    }

    override func close() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        super.close()
    }
}
