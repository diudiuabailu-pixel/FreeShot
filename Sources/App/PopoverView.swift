import SwiftUI

struct PopoverView: View {
    @State private var selectedTab: Tab = .screenshot
    
    enum Tab: String, CaseIterable {
        case screenshot = "截图"
        case recording = "录屏"
        
        var icon: String {
            switch self {
            case .screenshot: return "camera.fill"
            case .recording: return "video.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题
            HStack {
                Image(systemName: "viewfinder")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("FreeShot")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Tab 切换
            HStack(spacing: 4) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Divider()
                .padding(.top, 12)
            
            // 内容区域
            ScrollView {
                VStack(spacing: 12) {
                    if selectedTab == .screenshot {
                        ScreenshotContent()
                    } else {
                        RecordingContent()
                    }
                }
                .padding(16)
            }
            
            Divider()
            
            // 底部工具
            HStack {
                ToolButton(icon: "photo.on.rectangle.angled", title: "历史") {
                    // 截图历史
                }
                ToolButton(icon: "doc.badge.gearshape", title: "设置") {
                    // 设置
                }
                Spacer()
            }
            .padding(12)
        }
        .frame(width: 320, height: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? .blue : .secondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screenshot Content

struct ScreenshotContent: View {
    var body: some View {
        VStack(spacing: 10) {
            // 快速截图按钮
            ActionCard(
                icon: "rectangle.dashed",
                title: "截取区域",
                subtitle: "⌘+Shift+4",
                color: .blue
            ) {
                ScreenshotManager.shared.captureRegion()
            }
            
            ActionCard(
                icon: "macwindow",
                title: "截取窗口",
                subtitle: "⌘+Shift+5",
                color: .purple
            ) {
                ScreenshotManager.shared.captureWindow()
            }
            
            ActionCard(
                icon: "rectangle.fill",
                title: "截取全屏",
                subtitle: "⌘+Shift+6",
                color: .green
            ) {
                ScreenshotManager.shared.captureFullScreen()
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // 截图选项
            VStack(alignment: .leading, spacing: 10) {
                Text("选项")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                OptionToggle(icon: "camera.fill", title: "同时录制摄像头", isOn: .constant(false))
                OptionToggle(icon: "timer", title: "倒计时 3秒", isOn: .constant(false))
            }
        }
    }
}

// MARK: - Recording Content

struct RecordingContent: View {
    @StateObject private var state = RecordingState.shared
    
    var body: some View {
        VStack(spacing: 10) {
            if state.isRecording {
                // 录制中状态
                RecordingActiveView()
            } else {
                // 录制选项
                RecordingOptionsView()
            }
        }
    }
}

// MARK: - Recording Options

struct RecordingOptionsView: View {
    @State private var showCamera = true
    @State private var cameraPosition = 0
    @State private var cameraSize = 1
    @State private var countdown = 1
    @State private var showMic = true
    @State private var showSystemAudio = true
    @State private var showMouseClicks = true
    @State private var showKeystrokes = false
    
    var body: some View {
        VStack(spacing: 10) {
            // 摄像头选项
            OptionToggle(icon: "camera.fill", title: "显示摄像头", isOn: $showCamera)
            
            if showCamera {
                VStack(alignment: .leading, spacing: 8) {
                    Text("位置")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Picker("", selection: $cameraPosition) {
                        Text("左上").tag(0)
                        Text("右上").tag(1)
                        Text("左下").tag(2)
                        Text("右下").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(.leading, 28)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("大小")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Picker("", selection: $cameraSize) {
                        Text("小").tag(0)
                        Text("中").tag(1)
                        Text("大").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(.leading, 28)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // 倒计时
            VStack(alignment: .leading, spacing: 8) {
                Text("倒计时")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Picker("", selection: $countdown) {
                    Text("无").tag(0)
                    Text("3秒").tag(1)
                    Text("5秒").tag(2)
                    Text("10秒").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // 显示选项
            OptionToggle(icon: "cursorarrow.click", title: "显示鼠标点击", isOn: $showMouseClicks)
            OptionToggle(icon: "keyboard", title: "显示键盘按键", isOn: $showKeystrokes)
            
            Divider()
                .padding(.vertical, 4)
            
            // 音频选项
            OptionToggle(icon: "mic.fill", title: "麦克风", isOn: $showMic)
            OptionToggle(icon: "speaker.wave.2.fill", title: "系统声音", isOn: $showSystemAudio)
            
            Divider()
                .padding(.vertical, 4)
            
            // 录制按钮
            HStack(spacing: 10) {
                RecordingButton(title: "区域录屏", icon: "rectangle.dashed") {
                    // 开始区域录屏
                }
                RecordingButton(title: "全屏录屏", icon: "macwindow") {
                    // 开始全屏录屏
                }
            }
        }
    }
}

// MARK: - Recording Active View

struct RecordingActiveView: View {
    @StateObject private var state = RecordingState.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // 录制指示器
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
                
                Text(formatTime(state.recordingDuration))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                
                Spacer()
            }
            
            // 控制按钮
            HStack(spacing: 20) {
                Button(action: {
                    if state.isPaused {
                        RecordingManager.shared.resumeRecording()
                    } else {
                        RecordingManager.shared.pauseRecording()
                    }
                }) {
                    Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(22)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    RecordingManager.shared.stopRecording()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.red)
                        .cornerRadius(22)
                }
                .buttonStyle(.plain)
            }
            
            // 状态
            if state.includeCamera {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("摄像头已开启")
                    Spacer()
                }
                .font(.system(size: 12))
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

// MARK: - Action Card

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.15))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Option Toggle

struct OptionToggle: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13))
            }
        }
        .toggleStyle(.switch)
        .scaleEffect(0.8)
    }
}

// MARK: - Recording Button

struct RecordingButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.red)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PopoverView()
}
