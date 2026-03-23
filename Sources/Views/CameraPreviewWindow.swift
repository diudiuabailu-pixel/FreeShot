import AppKit
import AVFoundation

class CameraPreviewWindow: NSWindow {
    private var previewView: CameraPreviewView!
    private var currentPosition: RecordingManager.CameraPosition
    private var currentSize: CGSize
    
    init(position: RecordingManager.CameraPosition, size: CGSize) {
        self.currentPosition = position
        self.currentSize = size
        
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
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
        
        setupUI()
        positionWindow()
        startCamera()
    }
    
    private func setupUI() {
        previewView = CameraPreviewView(frame: NSRect(origin: .zero, size: currentSize))
        
        // 圆角蒙版
        let maskLayer = CAShapeLayer()
        let path = CGPath(roundedRect: NSRect(origin: .zero, size: currentSize), cornerWidth: 12, cornerHeight: 12, transform: nil)
        maskLayer.path = path
        previewView.layer?.mask = maskLayer
        
        // 边框
        previewView.wantsLayer = true
        previewView.layer?.borderWidth = 3
        previewView.layer?.borderColor = NSColor.white.cgColor
        previewView.layer?.cornerRadius = 12
        previewView.layer?.masksToBounds = true
        
        self.contentView = previewView
        
        // 拖拽手势
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.contentView?.addGestureRecognizer(panGesture)
        
        // 双击关闭
        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick))
        doubleClick.numberOfClicksRequired = 2
        self.contentView?.addGestureRecognizer(doubleClick)
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let position = currentPosition.offset(in: screenFrame, cameraSize: currentSize)
        self.setFrameOrigin(position)
    }
    
    func updatePosition(_ position: RecordingManager.CameraPosition, size: CGSize) {
        currentPosition = position
        currentSize = size
        positionWindow()
    }
    
    private func startCamera() {
        previewView.startCapture()
    }
    
    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        let translation = gesture.translation(in: nil)
        var frame = self.frame
        frame.origin.x += translation.x
        frame.origin.y += translation.y
        self.setFrame(frame, display: true)
        gesture.setTranslation(.zero, in: nil)
    }
    
    @objc private func handleDoubleClick() {
        // 双击切换位置
        switch currentPosition {
        case .topLeft:
            currentPosition = .topRight
        case .topRight:
            currentPosition = .topLeft
        case .bottomLeft:
            currentPosition = .bottomRight
        case .bottomRight:
            currentPosition = .bottomLeft
        }
        positionWindow()
        
        // 同步到 RecordingManager
        RecordingManager.shared.updateCameraPosition(currentPosition)
    }
}

class CameraPreviewView: NSView {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCamera()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("No camera available")
            return
        }
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .medium
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            }
            
            // 添加预览层
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = bounds
            previewLayer?.cornerRadius = 12
            
            self.layer = previewLayer
            
            // 保持预览层填充视图
            self.wantsLayer = true
            
        } catch {
            print("Camera setup error: \(error)")
        }
    }
    
    func startCapture() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopCapture() {
        captureSession?.stopRunning()
    }
    
    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}
