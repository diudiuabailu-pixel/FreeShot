import AppKit
import ScreenCaptureKit

class WindowPickerWindow: NSWindow {
    private var tableView: NSTableView!
    private var windows: [SCWindow]
    
    init(windows: [SCWindow]) {
        self.windows = windows
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "选择窗口"
        self.center()
        self.setupUI()
    }
    
    private func setupUI() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(windowSelected)
        tableView.target = self
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("window"))
        column.title = "窗口"
        column.width = 380
        tableView.addTableColumn(column)
        tableView.headerView = nil
        
        scrollView.documentView = tableView
        
        let contentView = NSView()
        contentView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
        
        self.contentView = contentView
    }
    
    @objc private func windowSelected() {
        let row = tableView.selectedRow
        if row >= 0 && row < windows.count {
            captureWindow(windows[row])
        }
    }
    
    private func captureWindow(_ window: SCWindow) {
        self.close()
        
        let windowID = CGWindowID(window.windowID)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let image = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                [.bestResolution]
            ) {
                self.saveScreenshot(image)
            }
        }
    }
    
    private func saveScreenshot(_ image: CGImage) {
        // Show quick preview (same as region/fullscreen screenshots)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreeShot-Window-\(dateString()).png")
        
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        if let data = bitmapRep.representation(using: .png, properties: [:]) {
            try? data.write(to: tempURL)
            
            // Save to history
            ScreenshotHistory.shared.add(tempURL)
            
            // Show quick preview
            let previewWindow = QuickPreviewWindow(image: image, url: tempURL)
            previewWindow.makeKeyAndOrderFront(nil)
        }
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

extension WindowPickerWindow: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return windows.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let window = windows[row]
        
        let cellView = NSTableCellView()
        let textField = NSTextField(labelWithString: window.title ?? "Untitled")
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        cellView.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        return cellView
    }
}
