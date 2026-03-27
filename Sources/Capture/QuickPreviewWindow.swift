import AppKit
import UniformTypeIdentifiers

class QuickPreviewWindow: NSWindow {
    private var screenshotImage: NSImage
    private var screenshotURL: URL
    
    init(image: CGImage, url: URL) {
        self.screenshotImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        self.screenshotURL = url
        
        // 计算合适的窗口大小
        let maxWidth: CGFloat = 400
        let maxHeight: CGFloat = 300
        var width = CGFloat(image.width) / 2
        var height = CGFloat(image.height) / 2
        
        if width > maxWidth {
            height = height * maxWidth / width
            width = maxWidth
        }
        if height > maxHeight {
            width = width * maxHeight / height
            height = maxHeight
        }
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width + 20, height: height + 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        
        setupUI(width: width, height: height)
        positionWindow(width: width, height: height)
        
        // 5秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.close()
        }
    }
    
    private func setupUI(width: CGFloat, height: CGFloat) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width + 20, height: height + 60))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        container.layer?.cornerRadius = 12
        
        // 截图预览
        let imageView = NSImageView(frame: NSRect(x: 10, y: 50, width: width, height: height - 10))
        imageView.image = screenshotImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        
        // 按钮工具栏
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.frame = NSRect(x: 10, y: 10, width: width, height: 30)
        
        let copyButton = createButton(title: "复制", icon: "doc.on.doc")
        copyButton.target = self
        copyButton.action = #selector(copyImage)
        
        let saveButton = createButton(title: "保存", icon: "square.and.arrow.down")
        saveButton.target = self
        saveButton.action = #selector(saveImage)
        
        let annotateButton = createButton(title: "标注", icon: "pencil")
        annotateButton.target = self
        annotateButton.action = #selector(openAnnotate)
        
        let ocrButton = createButton(title: "OCR", icon: "text.viewfinder")
        ocrButton.target = self
        ocrButton.action = #selector(recognizeText)
        
        let openButton = createButton(title: "打开", icon: "folder")
        openButton.target = self
        openButton.action = #selector(openInFinder)
        
        buttonStack.addArrangedSubview(copyButton)
        buttonStack.addArrangedSubview(saveButton)
        buttonStack.addArrangedSubview(annotateButton)
        buttonStack.addArrangedSubview(ocrButton)
        buttonStack.addArrangedSubview(openButton)
        
        container.addSubview(imageView)
        container.addSubview(buttonStack)
        
        self.contentView = container
    }
    
    private func createButton(title: String, icon: String) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .texturedRounded
        button.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
        button.title = " \(title)"
        button.imagePosition = .imageLeading
        button.font = NSFont.systemFont(ofSize: 11)
        return button
    }
    
    private func positionWindow(width: CGFloat, height: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        // 右下角
        let x = screenFrame.maxX - width - 30
        let y = screenFrame.minY + 30
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    @objc private func copyImage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([screenshotImage])
        close()
    }
    
    @objc private func saveImage() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg, .tiff]
        savePanel.nameFieldStringValue = screenshotURL.lastPathComponent

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.copyItem(at: self.screenshotURL, to: url)
            }
            self.close()
        }
    }
    
    @objc private func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([screenshotURL])
        close()
    }
    
    @objc private func openAnnotate() {
        close()
        
        if let image = NSImage(contentsOf: screenshotURL) {
            let annotationWindow = AnnotationWindow(image: image)
            annotationWindow.onSave = { [weak self] annotatedImage in
                self?.saveAnnotatedImage(annotatedImage)
            }
            annotationWindow.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func recognizeText() {
        // 识别文字
        OCRManager.shared.recognizeText(from: screenshotURL) { [weak self] (result: Result<String, Error>) in
            switch result {
            case .success(let text):
                // 复制到剪贴板
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                
                // 显示结果
                self?.showMessage("文字已复制到剪贴板")
            case .failure(let error):
                self?.showMessage("识别失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func showMessage(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "OCR 识别"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    private func saveAnnotatedImage(_ image: NSImage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateStr = formatter.string(from: Date())
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "FreeShot-annotated-\(dateStr).png"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }
}
