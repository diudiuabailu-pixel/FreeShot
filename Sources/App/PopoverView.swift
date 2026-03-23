import SwiftUI

struct PopoverView: View {
    @State private var selectedTab: Tab = .screenshot
    
    enum Tab: String, CaseIterable {
        case screenshot = "Screenshot"
        case recording = "Recording"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo & Title
            HStack(spacing: 8) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text("FreeShot")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Tab Bar
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    TabBarButton(
                        title: tab.rawValue,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Divider()
                .padding(.top, 12)
            
            // Content
            ScrollView {
                VStack(spacing: 12) {
                    if selectedTab == .screenshot {
                        ScreenshotTabView()
                    } else {
                        RecordingTabView()
                    }
                }
                .padding(16)
            }
            
            Divider()
            
            // Bottom Bar
            HStack {
                BottomButton(icon: "clock.arrow.circlepath", title: "History") {
                    // History
                }
                
                Spacer()
                
                BottomButton(icon: "gearshape", title: "Settings") {
                    // Settings
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 340, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Tab Bar Button

struct TabBarButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue.opacity(0.12) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bottom Button

struct BottomButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 11))
            }
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screenshot Tab

struct ScreenshotTabView: View {
    var body: some View {
        VStack(spacing: 8) {
            // Capture Buttons
            CaptureButton(
                icon: "selection.pin.in.out",
                title: "Capture Region",
                shortcut: "⌘⇧4",
                color: .blue
            ) {
                ScreenshotManager.shared.captureRegion()
            }
            
            CaptureButton(
                icon: "macwindow",
                title: "Capture Window",
                shortcut: "⌘⇧5",
                color: .purple
            ) {
                ScreenshotManager.shared.captureWindow()
            }
            
            CaptureButton(
                icon: "rectangle.fill",
                title: "Capture Full Screen",
                shortcut: "⌘⇧6",
                color: .green
            ) {
                ScreenshotManager.shared.captureFullScreen()
            }
            
            CaptureButton(
                icon: "arrow.up.and.down",
                title: "Scroll Capture",
                shortcut: "",
                color: .orange
            ) {
                AutoScrollCaptureManager.shared.startCapture()
            }
            
            CaptureButton(
                icon: "display",
                title: "Multi-Display",
                shortcut: "",
                color: .purple
            ) {
                let picker = DisplayPickerWindow()
                picker.makeKeyAndOrderFront(nil)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Options
            GroupBox {
                VStack(spacing: 0) {
                    OptionRow(icon: "camera.fill", title: "Include webcam", isOn: .constant(false))
                    Divider()
                    OptionRow(icon: "timer", title: "Timer", isOn: .constant(false))
                    Divider()
                    OptionRow(icon: "cursorarrow.click", title: "Show clicks", isOn: .constant(true))
                }
            }
            .groupBoxStyle(DefaultGroupBoxStyle())
        }
    }
}

// MARK: - Recording Tab

struct RecordingTabView: View {
    @StateObject private var state = RecordingState.shared
    
    var body: some View {
        VStack(spacing: 12) {
            if state.isRecording {
                RecordingActiveView()
            } else {
                RecordingOptionsView()
            }
        }
    }
}

// MARK: - Recording Options

struct RecordingOptionsView: View {
    @State private var showCamera = true
    @State private var cameraPosition = 2
    @State private var cameraSize = 1
    @State private var countdown = 1
    @State private var micEnabled = true
    @State private var systemAudio = true
    @State private var showClicks = true
    @State private var showKeystrokes = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Camera Section
            GroupBox {
                VStack(spacing: 0) {
                    Toggle(isOn: $showCamera) {
                        Label("Show webcam", systemImage: "camera.fill")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    
                    if showCamera {
                        Divider()
                        
                        HStack {
                            Text("Position")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Picker("", selection: $cameraPosition) {
                                Text("Top Left").tag(0)
                                Text("Top Right").tag(1)
                                Text("Bottom Left").tag(2)
                                Text("Bottom Right").tag(3)
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                        }
                        .padding(.top, 4)
                        
                        Divider()
                        
                        HStack {
                            Text("Size")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Picker("", selection: $cameraSize) {
                                Text("Small").tag(0)
                                Text("Medium").tag(1)
                                Text("Large").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                        }
                    }
                }
            } label: {
                Label("Camera", systemImage: "camera.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .groupBoxStyle(DefaultGroupBoxStyle())
            
            // Timer
            GroupBox {
                HStack {
                    Text("Timer")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $countdown) {
                        Text("None").tag(0)
                        Text("3s").tag(1)
                        Text("5s").tag(2)
                        Text("10s").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            } label: {
                Label("Timer", systemImage: "timer")
                    .font(.system(size: 12, weight: .medium))
            }
            .groupBoxStyle(DefaultGroupBoxStyle())
            
            // Display
            GroupBox {
                VStack(spacing: 0) {
                    Toggle(isOn: $showClicks) {
                        Label("Show clicks", systemImage: "cursorarrow.click")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    
                    Divider()
                    
                    Toggle(isOn: $showKeystrokes) {
                        Label("Show keystrokes", systemImage: "keyboard")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            } label: {
                Label("Display", systemImage: "menubar.dock.rectangle")
                    .font(.system(size: 12, weight: .medium))
            }
            .groupBoxStyle(DefaultGroupBoxStyle())
            
            // Audio
            GroupBox {
                VStack(spacing: 0) {
                    Toggle(isOn: $micEnabled) {
                        Label("Microphone", systemImage: "mic.fill")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    
                    Divider()
                    
                    Toggle(isOn: $systemAudio) {
                        Label("System Audio", systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            } label: {
                Label("Audio", systemImage: "waveform")
                    .font(.system(size: 12, weight: .medium))
            }
            .groupBoxStyle(DefaultGroupBoxStyle())
            
            Divider()
                .padding(.vertical, 4)
            
            // Record Buttons
            HStack(spacing: 8) {
                RecordButton(title: "Region", icon: "selection.pin.in.out") {
                    RecordingManager.shared.startRegionRecording(includeCamera: showCamera)
                }
                
                RecordButton(title: "Full Screen", icon: "macwindow") {
                    RecordingManager.shared.startFullScreenRecording(includeCamera: showCamera)
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
            // Timer
            HStack(spacing: 8) {
                RecordingDot()
                
                Text(formatTime(state.recordingDuration))
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                
                Spacer()
            }
            
            // Controls
            HStack(spacing: 16) {
                Button(action: {
                    if state.isPaused {
                        RecordingManager.shared.resumeRecording()
                    } else {
                        RecordingManager.shared.pauseRecording()
                    }
                }) {
                    Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 18))
                        .frame(width: 44, height: 44)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    RecordingManager.shared.stopRecording()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            // Status
            if state.includeCamera {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Camera On")
                    Spacer()
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
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

struct RecordingDot: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.red.opacity(0.5), lineWidth: 2)
                    .scaleEffect(isAnimating ? 1.5 : 1.0)
                    .opacity(isAnimating ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Capture Button

struct CaptureButton: View {
    let icon: String
    let title: String
    let shortcut: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .cornerRadius(8)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(shortcut)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Option Row

struct OptionRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: icon)
                .font(.system(size: 13))
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}

// MARK: - Record Button

struct RecordButton: View {
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
