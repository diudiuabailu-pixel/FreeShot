import Foundation
import AppKit
import Carbon.HIToolbox

class KeystrokeOverlayWindow: NSWindow {
    private var keystrokeLabel: NSTextField!
    private var recentKeys: [String] = []
    private let maxKeys = 3
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        
        setupUI()
        positionWindow()
    }
    
    private func setupUI() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 40))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        container.layer?.cornerRadius = 8
        
        keystrokeLabel = NSTextField(labelWithString: "")
        keystrokeLabel.frame = NSRect(x: 0, y: 8, width: 120, height: 24)
        keystrokeLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        keystrokeLabel.textColor = .white
        keystrokeLabel.alignment = .center
        
        container.addSubview(keystrokeLabel)
        self.contentView = container
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        // 显示在屏幕底部中央
        let x = screenFrame.midX - 60
        let y = screenFrame.minY + 60
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func show() {
        self.orderFront(nil)
    }
    
    func hide() {
        self.orderOut(nil)
    }
    
    func addKeystroke(_ key: String) {
        recentKeys.insert(key, at: 0)
        if recentKeys.count > maxKeys {
            recentKeys.removeLast()
        }
        
        keystrokeLabel.stringValue = recentKeys.joined(separator: " + ")
        
        // 显示后自动隐藏
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(autoHide), object: nil)
        perform(#selector(autoHide), with: nil, afterDelay: 2.0)
    }
    
    @objc private func autoHide() {
        hide()
        recentKeys.removeAll()
    }
}

class KeystrokeMonitor {
    static let shared = KeystrokeMonitor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var overlayWindow: KeystrokeOverlayWindow?
    private var isMonitoring = false
    
    private init() {}
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // 创建键盘事件监听
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                return KeystrokeMonitor.shared.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        ) else {
            DispatchQueue.main.async {
                AppDelegate.showError(
                    "无法监听键盘事件，请到系统设置 > 隐私与安全性 > 辅助功能中授权 FreeShot，然后重试。",
                    title: "辅助功能权限不足"
                )
            }
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isMonitoring = true
            
            // 显示 overlay 窗口
            DispatchQueue.main.async {
                self.overlayWindow = KeystrokeOverlayWindow()
                self.overlayWindow?.show()
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
            self.overlayWindow?.hide()
            self.overlayWindow = nil
        }
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let keyString = keyCodeToString(keyCode)
        
        DispatchQueue.main.async {
            self.overlayWindow?.addKeystroke(keyString)
        }
        
        return Unmanaged.passRetained(event)
    }
    
    private func keyCodeToString(_ keyCode: Int64) -> String {
        let keyMap: [Int64: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            51: "⌫", 53: "⎋", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15", 118: "F4", 119: "F2",
            120: "F1", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        
        return keyMap[keyCode] ?? "?"
    }
}
