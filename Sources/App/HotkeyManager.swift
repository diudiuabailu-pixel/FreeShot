import Foundation
import AppKit
import Carbon.HIToolbox

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private init() {}
    
    func startListening() {
        // 全局监听 Command + Shift + R (区域录屏)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // 本地监听（当 app 活跃时）
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
        
        // ⌘+Shift+R: 区域录屏
        if flags == [.command, .shift] && event.charactersIgnoringModifiers?.lowercased() == "r" {
            DispatchQueue.main.async {
                RecordingManager.shared.startRegionRecording(includeCamera: true)
            }
        }
        
        // ⌘+Shift+F: 全屏录屏
        if flags == [.command, .shift] && event.charactersIgnoringModifiers?.lowercased() == "f" {
            DispatchQueue.main.async {
                RecordingManager.shared.startFullScreenRecording(includeCamera: true)
            }
        }
        
        // ⌘+Shift+S: 停止录屏
        if flags == [.command, .shift] && event.charactersIgnoringModifiers?.lowercased() == "s" {
            DispatchQueue.main.async {
                RecordingManager.shared.stopRecording()
            }
        }
    }
}
