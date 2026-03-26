import AppKit

class RecordingIndicatorWindow: NSWindow {
    private var timerLabel: NSTextField!
    private var stopButton: NSButton!
    private var recordingState: RecordingState { RecordingState.shared }
    private var displayTimer: Timer?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        setupUI()
        positionWindow()
        startTimer()
    }
    
    private func setupUI() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 50))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        container.layer?.cornerRadius = 25
        
        // 录制红点
        let dot = NSView(frame: NSRect(x: 16, y: 18, width: 14, height: 14))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.red.cgColor
        dot.layer?.cornerRadius = 7
        
        // 动画
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        dot.layer?.add(pulse, forKey: "pulse")
        
        // 时间标签
        timerLabel = NSTextField(labelWithString: "00:00")
        timerLabel.frame = NSRect(x: 38, y: 15, width: 70, height: 20)
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        timerLabel.textColor = .white
        
        // 停止按钮
        stopButton = NSButton(frame: NSRect(x: 115, y: 10, width: 30, height: 30))
        stopButton.bezelStyle = .circular
        stopButton.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop")
        stopButton.contentTintColor = .white
        stopButton.isBordered = false
        stopButton.target = self
        stopButton.action = #selector(stopRecording)
        
        container.addSubview(dot)
        container.addSubview(timerLabel)
        container.addSubview(stopButton)
        
        self.contentView = container
        
        // 添加拖拽手势
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        container.addGestureRecognizer(panGesture)
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = self.frame
        
        // 默认位置：顶部中间
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.maxY - windowFrame.height - 20
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func startTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let duration = self.recordingState.recordingDuration
            let minutes = duration / 60
            let seconds = duration % 60
            self.timerLabel.stringValue = String(format: "%02d:%02d", minutes, seconds)
        }
    }

    override func close() {
        displayTimer?.invalidate()
        displayTimer = nil
        super.close()
    }
    
    @objc private func stopRecording() {
        RecordingManager.shared.stopRecording()
    }
    
    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        let translation = gesture.translation(in: nil)
        var frame = self.frame
        frame.origin.x += translation.x
        frame.origin.y += translation.y
        self.setFrame(frame, display: true)
        gesture.setTranslation(.zero, in: nil)
    }
}
