import Foundation
import AppKit
import Carbon.HIToolbox

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private init() {}
    
    func startListening() {
        // 全局监听
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // 本地监听
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }
    
    func stopListening() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()
        
        // 截图快捷键 ⌘+Shift+4/5/6
        if flags == [.command, .shift] {
            switch key {
            case "4":
                DispatchQueue.main.async {
                    ScreenshotManager.shared.captureRegion()
                }
            case "5":
                DispatchQueue.main.async {
                    ScreenshotManager.shared.captureWindow()
                }
            case "6":
                DispatchQueue.main.async {
                    ScreenshotManager.shared.captureFullScreen()
                }
            // 录屏快捷键
            case "r":
                DispatchQueue.main.async {
                    RecordingManager.shared.startRegionRecording(includeCamera: true)
                }
            case "f":
                DispatchQueue.main.async {
                    RecordingManager.shared.startFullScreenRecording(includeCamera: true)
                }
            case "s":
                DispatchQueue.main.async {
                    RecordingManager.shared.stopRecording()
                }
            default:
                break
            }
        }
    }
}
