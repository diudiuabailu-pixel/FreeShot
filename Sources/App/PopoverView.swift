import SwiftUI

struct PopoverView: View {
    @StateObject private var recordingState = RecordingState.shared
    @State private var showCameraPreview = true
    @State private var cameraPosition: CameraPositionOption = .bottomRight
    @State private var cameraSize: CameraSizeOption = .medium
    @State private var showCountdown = true
    @State private var countdownSeconds = 3
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
    
    @State private var countdownOption: CountdownOption = .three
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "video.fill")
                    .font(.title3)
                Text("FreeShot")
                    .font(.headline)
                Text("- 免费录屏")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Divider()
            
            // 录制状态
            if recordingState.isRecording {
                RecordingStatusView()
            } else {
                // 录制选项
                VStack(spacing: 12) {
                    // 摄像头开关
                    Toggle(isOn: $showCameraPreview) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("显示摄像头")
                        }
                    }
                    .toggleStyle(.switch)
                    
                    // 摄像头位置（仅在开启摄像头时显示）
                    if showCameraPreview {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("摄像头位置")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("位置", selection: $cameraPosition) {
                                ForEach(CameraPositionOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: cameraPosition) { newValue in
                                RecordingManager.shared.updateCameraPosition(newValue.recordingPosition)
                            }
                        }
                        
                        // 摄像头大小
                        VStack(alignment: .leading, spacing: 8) {
                            Text("摄像头大小")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("大小", selection: $cameraSize) {
                                ForEach(CameraSizeOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: cameraSize) { newValue in
                                RecordingManager.shared.cameraSize = newValue.size
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 录屏选项
                    Text("录屏选项")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 倒计时
                    VStack(alignment: .leading, spacing: 8) {
                        Text("倒计时")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("倒计时", selection: $countdownOption) {
                            ForEach(CountdownOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // 鼠标点击
                    Toggle(isOn: $showMouseClicks) {
                        HStack {
                            Image(systemName: "cursorarrow.click")
                            Text("显示鼠标点击")
                        }
                    }
                    .toggleStyle(.switch)
                    
                    // 键盘按键
                    Toggle(isOn: $showKeystrokes) {
                        HStack {
                            Image(systemName: "keyboard")
                            Text("显示键盘按键")
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Divider()
                    
                    // 音频选项
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
                }
                
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
                        .background(Color.blue.opacity(0.1))
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
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // 底部
            HStack {
                Button("设置") {
                    // TODO: 打开设置
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 280, height: 520)
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
            // 录制指示器
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
            
            // 控制按钮
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
            
            // 状态信息
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
