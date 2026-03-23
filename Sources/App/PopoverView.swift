import SwiftUI

struct PopoverView: View {
    @StateObject private var recordingState = RecordingState.shared
    @State private var selectedTab: Tab = .screenshot
    
    enum Tab: String, CaseIterable {
        case screenshot = "截图"
        case recording = "录屏"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "video.fill")
                    .font(.title3)
                Text("FreeShot")
                    .font(.headline)
                Text("- 免费工具")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Tab 切换
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            
            Divider()
            
            // 根据 Tab 显示内容
            if selectedTab == .screenshot {
                ScreenshotView()
            } else {
                RecordingView()
            }
            
            Spacer()
            
            // 底部
            HStack {
                Button("GIF导出") {
                    GifExporter.shared.convertVideoToGif { _ in }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.caption)
                
                Button("视频裁剪") {
                    VideoTrimmer.shared.trimSelectedVideo { _ in }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.caption)
                
                Spacer()
            }
        }
        .padding()
        .frame(width: 300, height: 420)
    }
}

// MARK: - Screenshot View

struct ScreenshotView: View {
    @State private var showCameraInScreenshot = false
    
    var body: some View {
        VStack(spacing: 12) {
            // 截图选项
            Toggle(isOn: $showCameraInScreenshot) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("同时录制摄像头")
                }
            }
            .toggleStyle(.switch)
            
            Divider()
            
            // 截图按钮
            VStack(spacing: 10) {
                Button(action: {
                    ScreenshotManager.shared.captureRegion()
                }) {
                    HStack {
                        Image(systemName: "rectangle.dashed")
                        Text("截取区域")
                        Spacer()
                        Text("⌘+Shift+4")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    ScreenshotManager.shared.captureWindow()
                }) {
                    HStack {
                        Image(systemName: "macwindow")
                        Text("截取窗口")
                        Spacer()
                        Text("⌘+Shift+5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    ScreenshotManager.shared.captureFullScreen()
                }) {
                    HStack {
                        Image(systemName: "rectangle.fill")
                        Text("截取全屏")
                        Spacer()
                        Text("⌘+Shift+6")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Recording View

struct RecordingView: View {
    @StateObject private var recordingState = RecordingState.shared
    @State private var showCameraPreview = true
    @State private var cameraPosition: CameraPositionOption = .bottomRight
    @State private var cameraSize: CameraSizeOption = .medium
    @State private var countdownOption: CountdownOption = .three
    @State private var showMouseClicks = true
    @State private var showKeystrokes = false
    
    enum CameraPositionOption: String, CaseIterable {
        case topLeft = "左上"
        case topRight = "右上"
        case bottomLeft = "左下"
        case bottomRight = "右下"
        
        var recordingPosition: RecordingManager.CameraPosition {
            switch self {
            case .topLeft: return .topLeft
            case .topRight: return .topRight
            case .bottomLeft: return .bottomLeft
            case .bottomRight: return .bottomRight
            }
        }
    }
    
    enum CameraSizeOption: String, CaseIterable {
        case small = "小"
        case medium = "中"
        case large = "大"
        
        var size: CGSize {
            switch self {
            case .small: return CGSize(width: 120, height: 90)
            case .medium: return CGSize(width: 200, height: 150)
            case .large: return CGSize(width: 300, height: 225)
            }
        }
    }
    
    enum CountdownOption: String, CaseIterable {
        case none = "无"
        case three = "3秒"
        case five = "5秒"
        case ten = "10秒"
        
        var seconds: Int {
            switch self {
            case .none: return 0
            case .three: return 3
            case .five: return 5
            case .ten: return 10
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if recordingState.isRecording {
                RecordingStatusView()
            } else {
                // 摄像头开关
                Toggle(isOn: $showCameraPreview) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("显示摄像头")
                    }
                }
                .toggleStyle(.switch)
                
                // 摄像头位置
                if showCameraPreview {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("摄像头位置")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $cameraPosition) {
                            ForEach(CameraPositionOption.allCases, id: \.self) { option in
                                Text(option.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: cameraPosition) { newValue in
                            RecordingManager.shared.updateCameraPosition(newValue.recordingPosition)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("摄像头大小")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $cameraSize) {
                            ForEach(CameraSizeOption.allCases, id: \.self) { option in
                                Text(option.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: cameraSize) { newValue in
                            RecordingManager.shared.cameraSize = newValue.size
                        }
                    }
                }
                
                Divider()
                
                // 倒计时
                VStack(alignment: .leading, spacing: 8) {
                    Text("倒计时")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $countdownOption) {
                        ForEach(CountdownOption.allCases, id: \.self) { option in
                            Text(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 鼠标/键盘
                Toggle(isOn: $showMouseClicks) {
                    HStack {
                        Image(systemName: "cursorarrow.click")
                        Text("显示鼠标点击")
                    }
                }
                .toggleStyle(.switch)
                
                Toggle(isOn: $showKeystrokes) {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("显示键盘按键")
                    }
                }
                .toggleStyle(.switch)
                
                Divider()
                
                // 音频
                Toggle(isOn: .constant(true)) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("麦克风")
                    }
                }
                .toggleStyle(.switch)
                
                Toggle(isOn: .constant(true)) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("系统声音")
                    }
                }
                .toggleStyle(.switch)
                
                Divider()
                
                // 录制按钮
                VStack(spacing: 10) {
                    Button(action: {
                        updateSettings()
                        startRecording(isRegion: true)
                    }) {
                        HStack {
                            Image(systemName: "rectangle.dashed")
                            Text("区域录屏")
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        updateSettings()
                        startRecording(isRegion: false)
                    }) {
                        HStack {
                            Image(systemName: "macwindow")
                            Text("全屏录屏")
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func updateSettings() {
        RecordingManager.shared.cameraPosition = cameraPosition.recordingPosition
        RecordingManager.shared.cameraSize = cameraSize.size
        RecordingManager.shared.countdownSeconds = countdownOption.seconds
        RecordingManager.shared.showMouseClicks = showMouseClicks
        RecordingManager.shared.showKeystrokes = showKeystrokes
    }
    
    private func startRecording(isRegion: Bool) {
        let includeCamera = showCameraPreview
        
        if countdownOption.seconds > 0 {
            RecordingManager.shared.startCountdown {
                if isRegion {
                    RecordingManager.shared.startRegionRecording(includeCamera: includeCamera)
                } else {
                    RecordingManager.shared.startFullScreenRecording(includeCamera: includeCamera)
                }
            }
        } else {
            if isRegion {
                RecordingManager.shared.startRegionRecording(includeCamera: includeCamera)
            } else {
                RecordingManager.shared.startFullScreenRecording(includeCamera: includeCamera)
            }
        }
    }
}

struct RecordingStatusView: View {
    @StateObject private var state = RecordingState.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                    )
                
                Text(formatTime(state.recordingDuration))
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    if state.isPaused {
                        RecordingManager.shared.resumeRecording()
                    } else {
                        RecordingManager.shared.pauseRecording()
                    }
                }) {
                    Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    RecordingManager.shared.stopRecording()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            
            if state.includeCamera {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("摄像头已开启")
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

#Preview {
    PopoverView()
}
