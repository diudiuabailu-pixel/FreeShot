import AppKit

@available(macOS 10.12.2, *)
class TouchBarController: NSObject, NSTouchBarDelegate {
    static let shared = TouchBarController()
    
    private var touchBar: NSTouchBar?
    
    override init() {
        super.init()
    }
    
    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("com.freeshot.touchbar")
        touchBar.defaultItemIdentifiers = [
            .captureRegion,
            .captureWindow,
            .captureFullScreen,
            .flexibleSpace,
            .recordRegion,
            .recordFullScreen,
            .stopRecording
        ]
        touchBar.customizationAllowedItemIdentifiers = [
            .captureRegion,
            .captureWindow,
            .captureFullScreen,
            .recordRegion,
            .recordFullScreen,
            .stopRecording
        ]
        
        self.touchBar = touchBar
        return touchBar
    }
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .captureRegion:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: L("touchbar.screenshot"), target: self, action: #selector(captureRegion))
            item.view = button
            item.customizationLabel = L("settings.shortcut.region_screenshot")
            return item
            
        case .captureWindow:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: L("touchbar.window"), target: self, action: #selector(captureWindow))
            item.view = button
            item.customizationLabel = L("settings.shortcut.window_screenshot")
            return item
            
        case .captureFullScreen:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: L("touchbar.fullscreen"), target: self, action: #selector(captureFullScreen))
            item.view = button
            item.customizationLabel = L("settings.shortcut.fullscreen_screenshot")
            return item
            
        case .recordRegion:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: L("touchbar.record"), target: self, action: #selector(recordRegion))
            item.view = button
            item.customizationLabel = L("settings.shortcut.region_recording")
            return item
            
        case .recordFullScreen:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: L("touchbar.record_full"), target: self, action: #selector(recordFullScreen))
            item.view = button
            item.customizationLabel = L("settings.shortcut.fullscreen_recording")
            return item
            
        case .stopRecording:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: L("touchbar.stop"), target: self, action: #selector(stopRecording))
            button.bezelColor = .red
            item.view = button
            item.customizationLabel = L("settings.shortcut.stop_recording")
            return item
            
        default:
            return nil
        }
    }
    
    @objc private func captureRegion() {
        ScreenshotManager.shared.captureRegion()
    }
    
    @objc private func captureWindow() {
        ScreenshotManager.shared.captureWindow()
    }
    
    @objc private func captureFullScreen() {
        ScreenshotManager.shared.captureFullScreen()
    }
    
    @objc private func recordRegion() {
        RecordingManager.shared.startRegionRecording(includeCamera: true)
    }
    
    @objc private func recordFullScreen() {
        RecordingManager.shared.startFullScreenRecording(includeCamera: true)
    }
    
    @objc private func stopRecording() {
        RecordingManager.shared.stopRecording()
    }
}

// Touch Bar Item Identifiers
@available(macOS 10.12.2, *)
extension NSTouchBarItem.Identifier {
    static let captureRegion = NSTouchBarItem.Identifier("com.freeshot.captureRegion")
    static let captureWindow = NSTouchBarItem.Identifier("com.freeshot.captureWindow")
    static let captureFullScreen = NSTouchBarItem.Identifier("com.freeshot.captureFullScreen")
    static let recordRegion = NSTouchBarItem.Identifier("com.freeshot.recordRegion")
    static let recordFullScreen = NSTouchBarItem.Identifier("com.freeshot.recordFullScreen")
    static let stopRecording = NSTouchBarItem.Identifier("com.freeshot.stopRecording")
}
