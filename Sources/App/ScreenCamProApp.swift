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
    static var shared: AppDelegate?

    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var recordingWindow: RecordingIndicatorWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 屏幕录制权限
            if !CGPreflightScreenCaptureAccess() {
                _ = CGRequestScreenCaptureAccess()
            }

            // 摄像头权限
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { _ in }
            }

            // 麦克风权限
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
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
            // Ensure the popover window can become key so buttons work
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func closePopover() {
        popover?.performClose(nil)
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
