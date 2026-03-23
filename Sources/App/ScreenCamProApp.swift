import SwiftUI
import AVFoundation
import ScreenCaptureKit

@main
struct FreeShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var recordingWindow: RecordingIndicatorWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkPermissions()
        setupStatusBarItem()
        
        // 启动快捷键监听
        HotkeyManager.shared.startListening()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 停止快捷键监听
        HotkeyManager.shared.stopListening()
    }
    
    func checkPermissions() {
        // 摄像头权限 - 延迟请求避免在 app delegate 中使用 async
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { _ in }
            default:
                break
            }
            
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
            default:
                break
            }
        }
    }
    
    func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "FreeShot")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 320)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: PopoverView())
    }
    
    @objc func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func showRecordingIndicator() {
        recordingWindow = RecordingIndicatorWindow()
        recordingWindow?.makeKeyAndOrderFront(nil)
    }
    
    func hideRecordingIndicator() {
        recordingWindow?.close()
        recordingWindow = nil
    }
}
