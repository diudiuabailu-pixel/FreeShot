import AppKit

class AnnotationWindow: NSWindow {
    private var imageView: NSImageView!
    private var currentImage: NSImage
    private var originalImage: NSImage
    private var annotations: [AnnotationItem] = []
    private var currentTool: AnnotationTool = .arrow
    
    var onSave: ((NSImage) -> Void)?
    
    enum AnnotationTool: String {
        case arrow = "arrow"
        case rectangle = "rectangle"
        case circle = "circle"
        case text = "text"
    }
    
    struct AnnotationItem {
        var tool: AnnotationTool
        var startPoint: NSPoint
        var endPoint: NSPoint
        var text: String = ""
    }
    
    init(image: NSImage) {
        self.originalImage = image
        self.currentImage = image
        
        let imageSize = image.size
        super.init(
            contentRect: NSRect(origin: .zero, size: imageSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "标注截图"
        self.center()
        
        setupUI()
    }
    
    private func setupUI() {
        imageView = NSImageView(frame: NSRect(origin: .zero, size: originalImage.size))
        imageView.image = originalImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        self.contentView = imageView
        
        // 添加工具栏
        let toolbar = NSView(frame: NSRect(x: 0, y: originalImage.size.height - 50, width: originalImage.size.width, height: 50))
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        let stackView = NSStackView(frame: NSRect(x: 10, y: 10, width: originalImage.size.width - 20, height: 30))
        stackView.orientation = .horizontal
        stackView.spacing = 10
        
        let tools: [(String, String, AnnotationTool)] = [
            ("arrow.up.right", "箭头", .arrow),
            ("rectangle", "矩形", .rectangle),
            ("circle", "圆形", .circle),
            ("textformat", "文字", .text)
        ]
        
        for (icon, title, tool) in tools {
            let button = NSButton()
            button.bezelStyle = .texturedRounded
            button.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
            button.title = " \(title)"
            button.imagePosition = .imageLeading
            button.tag = tools.firstIndex(where: { $0.2 == tool }) ?? 0
            button.target = self
            button.action = #selector(toolSelected(_:))
            stackView.addArrangedSubview(button)
        }
        
        let saveButton = NSButton()
        saveButton.bezelStyle = .texturedRounded
        saveButton.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "保存")
        saveButton.title = " 保存"
        saveButton.imagePosition = .imageLeading
        saveButton.target = self
        saveButton.action = #selector(saveImage)
        
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.addArrangedSubview(spacer)
        stackView.addArrangedSubview(saveButton)
        
        toolbar.addSubview(stackView)
        
        // 创建包含图片和工具栏的容器
        let containerView = NSView(frame: NSRect(origin: .zero, size: NSSize(width: originalImage.size.width, height: originalImage.size.height + 50)))
        imageView.frame.origin.y = 50
        containerView.addSubview(imageView)
        containerView.addSubview(toolbar)
        
        self.contentView = containerView
    }
    
    @objc private func toolSelected(_ sender: NSButton) {
        let tools: [AnnotationTool] = [.arrow, .rectangle, .circle, .text]
        if sender.tag < tools.count {
            currentTool = tools[sender.tag]
        }
    }
    
    @objc private func saveImage() {
        let finalImage = NSImage(size: originalImage.size)
        finalImage.lockFocus()
        
        originalImage.draw(in: NSRect(origin: NSPoint(x: 0, y: 0), size: originalImage.size))
        
        // 绘制标注
        NSColor.red.setStroke()
        
        for annotation in annotations {
            let path = NSBezierPath()
            path.lineWidth = 3
            
            switch annotation.tool {
            case .arrow:
                path.move(to: annotation.startPoint)
                path.line(to: annotation.endPoint)
                // 箭头
                let angle = atan2(annotation.endPoint.y - annotation.startPoint.y, annotation.endPoint.x - annotation.startPoint.x)
                let arrowLength: CGFloat = 15
                let p1 = NSPoint(
                    x: annotation.endPoint.x - arrowLength * cos(angle - .pi / 6),
                    y: annotation.endPoint.y - arrowLength * sin(angle - .pi / 6)
                )
                let p2 = NSPoint(
                    x: annotation.endPoint.x - arrowLength * cos(angle + .pi / 6),
                    y: annotation.endPoint.y - arrowLength * sin(angle + .pi / 6)
                )
                path.move(to: annotation.endPoint)
                path.line(to: p1)
                path.move(to: annotation.endPoint)
                path.line(to: p2)
                
            case .rectangle:
                let rect = NSRect(
                    x: min(annotation.startPoint.x, annotation.endPoint.x),
                    y: min(annotation.startPoint.y, annotation.endPoint.y),
                    width: abs(annotation.endPoint.x - annotation.startPoint.x),
                    height: abs(annotation.endPoint.y - annotation.startPoint.y)
                )
                path.appendRect(rect)
                
            case .circle:
                let rect = NSRect(
                    x: min(annotation.startPoint.x, annotation.endPoint.x),
                    y: min(annotation.startPoint.y, annotation.endPoint.y),
                    width: abs(annotation.endPoint.x - annotation.startPoint.x),
                    height: abs(annotation.endPoint.y - annotation.startPoint.y)
                )
                path.appendOval(in: rect)
                
            case .text:
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 16, weight: .medium),
                    .foregroundColor: NSColor.red
                ]
                annotation.text.draw(at: annotation.startPoint, withAttributes: attrs)
            }
            
            path.stroke()
        }
        
        finalImage.unlockFocus()
        
        onSave?(finalImage)
        close()
    }
}

extension AnnotationWindow {
    override func mouseDown(with event: NSEvent) {
        guard let contentView = self.contentView else { return }
        let point = contentView.convert(event.locationInWindow, from: nil)
        
        if currentTool == .text {
            showTextInput(at: point)
        } else {
            annotations.append(AnnotationItem(tool: currentTool, startPoint: point, endPoint: point))
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let contentView = self.contentView else { return }
        let point = contentView.convert(event.locationInWindow, from: nil)
        
        if var last = annotations.last, last.tool != .text {
            last.endPoint = point
            annotations[annotations.count - 1] = last
            redrawPreview()
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        redrawPreview()
    }
    
    private func redrawPreview() {
        // 临时在图片上绘制
        let previewImage = NSImage(size: originalImage.size)
        previewImage.lockFocus()
        
        originalImage.draw(in: NSRect(origin: .zero, size: originalImage.size))
        
        NSColor.red.setStroke()
        
        for annotation in annotations {
            let path = NSBezierPath()
            path.lineWidth = 3
            
            switch annotation.tool {
            case .arrow:
                path.move(to: annotation.startPoint)
                path.line(to: annotation.endPoint)
            case .rectangle:
                let rect = NSRect(
                    x: min(annotation.startPoint.x, annotation.endPoint.x),
                    y: min(annotation.startPoint.y, annotation.endPoint.y),
                    width: abs(annotation.endPoint.x - annotation.startPoint.x),
                    height: abs(annotation.endPoint.y - annotation.startPoint.y)
                )
                path.appendRect(rect)
            case .circle:
                let rect = NSRect(
                    x: min(annotation.startPoint.x, annotation.endPoint.x),
                    y: min(annotation.startPoint.y, annotation.endPoint.y),
                    width: abs(annotation.endPoint.x - annotation.startPoint.x),
                    height: abs(annotation.endPoint.y - annotation.startPoint.y)
                )
                path.appendOval(in: rect)
            case .text:
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 16),
                    .foregroundColor: NSColor.red
                ]
                annotation.text.draw(at: annotation.startPoint, withAttributes: attrs)
            }
            
            path.stroke()
        }
        
        previewImage.unlockFocus()
        
        // 更新视图（排除工具栏）
        if let containerView = self.contentView {
            for subview in containerView.subviews {
                if subview == imageView {
                    subview.removeFromSuperview()
                }
            }
            
            imageView.frame = NSRect(x: 0, y: 50, width: originalImage.size.width, height: originalImage.size.height)
            imageView.image = previewImage
            containerView.addSubview(imageView)
        }
    }
    
    private func showTextInput(at point: NSPoint) {
        let alert = NSAlert()
        alert.messageText = "添加文字"
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let text = textField.stringValue
            if !text.isEmpty {
                annotations.append(AnnotationItem(tool: .text, startPoint: point, endPoint: point, text: text))
                redrawPreview()
            }
        }
    }
}
