import SwiftUI
import AppKit

struct PopoverView: View {
    @State private var selectedTab: Tab = .screenshot

    enum Tab: CaseIterable {
        case screenshot
        case recording

        var title: String {
            switch self {
            case .screenshot: return L("tab.screenshot")
            case .recording: return L("tab.recording")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
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

            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    TabBarButton(
                        title: tab.title,
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

            HStack {
                BottomButton(icon: "clock.arrow.circlepath", title: L("nav.history")) {
                    let historyWindow = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 350, height: 400),
                        styleMask: [.titled, .closable, .resizable],
                        backing: .buffered,
                        defer: false
                    )
                    historyWindow.title = L("history.title")
                    historyWindow.center()
                    historyWindow.contentView = NSHostingController(rootView: ScreenshotHistoryView()).view
                    historyWindow.makeKeyAndOrderFront(nil)
                }

                Spacer()

                BottomButton(icon: "gearshape", title: L("nav.settings")) {
                    let settingsWindow = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                        styleMask: [.titled, .closable],
                        backing: .buffered,
                        defer: false
                    )
                    settingsWindow.title = L("settings.title")
                    settingsWindow.center()
                    settingsWindow.contentView = NSHostingController(rootView: SettingsView()).view
                    settingsWindow.makeKeyAndOrderFront(nil)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 340, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

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

struct ScreenshotTabView: View {
    @State private var timerSelection: Int = 0
    @AppStorage("imageFormat") private var imageFormat: String = "png"

    private func applyOptions() {
        let seconds: Int
        switch timerSelection {
        case 1: seconds = 3
        case 2: seconds = 5
        case 3: seconds = 10
        default: seconds = 0
        }
        ScreenshotManager.shared.timerSeconds = seconds
    }

    var body: some View {
        VStack(spacing: 8) {
            CaptureButton(
                icon: "selection.pin.in.out",
                title: L("screenshot.capture_region"),
                shortcut: "⌘⇧4",
                color: .blue
            ) {
                applyOptions()
                ScreenshotManager.shared.captureRegion()
            }

            CaptureButton(
                icon: "macwindow",
                title: L("screenshot.capture_window"),
                shortcut: "⌘⇧5",
                color: .purple
            ) {
                applyOptions()
                ScreenshotManager.shared.captureWindow()
            }

            CaptureButton(
                icon: "rectangle.fill",
                title: L("screenshot.capture_fullscreen"),
                shortcut: "⌘⇧6",
                color: .green
            ) {
                applyOptions()
                ScreenshotManager.shared.captureFullScreen()
            }

            CaptureButton(
                icon: "arrow.up.and.down",
                title: L("screenshot.scroll_capture"),
                shortcut: "",
                color: .orange
            ) {
                AutoScrollCaptureManager.shared.startCapture()
            }

            CaptureButton(
                icon: "display",
                title: L("screenshot.multi_display"),
                shortcut: "",
                color: .purple
            ) {
                let picker = DisplayPickerWindow()
                picker.makeKeyAndOrderFront(nil)
            }

            Divider()
                .padding(.vertical, 8)

            GroupBox {
                VStack(spacing: 0) {
                    HStack {
                        Label(L("screenshot.timer"), systemImage: "timer")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $timerSelection) {
                            Text(L("timer.none")).tag(0)
                            Text(L("timer.3s")).tag(1)
                            Text(L("timer.5s")).tag(2)
                            Text(L("timer.10s")).tag(3)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    Divider()

                    HStack {
                        Label(L("screenshot.format"), systemImage: "photo")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $imageFormat) {
                            Text("PNG").tag("png")
                            Text("JPEG").tag("jpeg")
                            Text("TIFF").tag("tiff")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                }
                .padding(.vertical, 4)
            }
            .groupBoxStyle(DefaultGroupBoxStyle())
        }
    }
}

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

struct RecordingOptionsView: View {
    @State private var showCamera = true
    @State private var cameraPosition = 3
    @State private var cameraSize = 1
    @State private var countdown = 1
    @State private var micEnabled = true
    @State private var systemAudio = true
    @State private var showClicks = true
    @State private var showKeystrokes = false

    private var manager: RecordingManager { RecordingManager.shared }

    var body: some View {
        VStack(spacing: 8) {
            GroupBox {
                VStack(spacing: 0) {
                    Toggle(isOn: $showCamera) {
                        Label(L("recording.show_webcam"), systemImage: "camera.fill")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    if showCamera {
                        Divider()

                        HStack {
                            Text(L("recording.position"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Picker("", selection: $cameraPosition) {
                                Text(L("recording.position.top_left")).tag(0)
                                Text(L("recording.position.top_right")).tag(1)
                                Text(L("recording.position.bottom_left")).tag(2)
                                Text(L("recording.position.bottom_right")).tag(3)
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                        }
                        .padding(.top, 4)

                        Divider()

                        HStack {
                            Text(L("recording.size"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Picker("", selection: $cameraSize) {
                                Text(L("recording.size.small")).tag(0)
                                Text(L("recording.size.medium")).tag(1)
                                Text(L("recording.size.large")).tag(2)
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.small)
                        }
                    }
                }
            } label: {
                Label(L("recording.camera"), systemImage: "camera.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .groupBoxStyle(DefaultGroupBoxStyle())

            GroupBox {
                HStack {
                    Text(L("recording.timer"))
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $countdown) {
                        Text(L("timer.none")).tag(0)
                        Text(L("timer.3s")).tag(1)
                        Text(L("timer.5s")).tag(2)
                        Text(L("timer.10s")).tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            } label: {
                Label(L("recording.timer"), systemImage: "timer")
                    .font(.system(size: 12, weight: .medium))
            }
            .groupBoxStyle(DefaultGroupBoxStyle())

            GroupBox {
                VStack(spacing: 0) {
                    Toggle(isOn: $showClicks) {
                        Label(L("recording.show_clicks"), systemImage: "cursorarrow.click")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Divider()

                    Toggle(isOn: $showKeystrokes) {
                        Label(L("recording.show_keystrokes"), systemImage: "keyboard")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            } label: {
                Label(L("recording.display"), systemImage: "menubar.dock.rectangle")
                    .font(.system(size: 12, weight: .medium))
            }
            .groupBoxStyle(DefaultGroupBoxStyle())

            GroupBox {
                VStack(spacing: 0) {
                    Toggle(isOn: $micEnabled) {
                        Label(L("recording.microphone"), systemImage: "mic.fill")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Divider()

                    Toggle(isOn: $systemAudio) {
                        Label(L("recording.system_audio"), systemImage: "speaker.wave.2.fill")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            } label: {
                Label(L("recording.audio"), systemImage: "waveform")
                    .font(.system(size: 12, weight: .medium))
            }
            .groupBoxStyle(DefaultGroupBoxStyle())

            Divider()
                .padding(.vertical, 4)

            if micEnabled && !systemAudio {
                Text(L("recording.mic_note"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                RecordButton(title: L("recording.region"), icon: "selection.pin.in.out") {
                    applyRecordingOptions()
                    manager.startRegionRecording(includeCamera: showCamera)
                }

                RecordButton(title: L("recording.fullscreen"), icon: "macwindow") {
                    applyRecordingOptions()
                    manager.startFullScreenRecording(includeCamera: showCamera)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // MARK: - Video Tools
            GroupBox {
                VStack(spacing: 0) {
                    Button(action: {
                        AppDelegate.shared?.closePopover()
                        VideoTrimmer.shared.trimSelectedVideo { _ in }
                    }) {
                        HStack {
                            Image(systemName: "scissors")
                                .foregroundColor(.orange)
                            Text(L("tools.trim_video"))
                                .font(.system(size: 13))
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)

                    Divider()

                    Button(action: {
                        AppDelegate.shared?.closePopover()
                        GifExporter.shared.convertVideoToGif { _ in }
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundColor(.purple)
                            Text(L("tools.video_to_gif"))
                                .font(.system(size: 13))
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            } label: {
                Label(L("tools.title"), systemImage: "wrench.and.screwdriver")
                    .font(.system(size: 12, weight: .medium))
            }
            .groupBoxStyle(DefaultGroupBoxStyle())
        }
        .onAppear(perform: syncFromManager)
    }

    private func syncFromManager() {
        showClicks = manager.showMouseClicks
        showKeystrokes = manager.showKeystrokes
        micEnabled = manager.microphoneEnabled
        systemAudio = manager.systemAudioEnabled
        countdown = countdownTag(for: manager.countdownSeconds)
        cameraPosition = cameraPositionTag(for: manager.cameraPosition)
        cameraSize = cameraSizeTag(for: manager.cameraSize)
    }

    private func applyRecordingOptions() {
        manager.showMouseClicks = showClicks
        manager.showKeystrokes = showKeystrokes
        manager.microphoneEnabled = micEnabled
        manager.systemAudioEnabled = systemAudio
        manager.countdownSeconds = countdownSeconds(for: countdown)
        manager.updateCameraPosition(cameraPositionValue(for: cameraPosition))
        manager.updateCameraSize(cameraSizeValue(for: cameraSize))
    }

    private func countdownSeconds(for tag: Int) -> Int {
        switch tag {
        case 1: return 3
        case 2: return 5
        case 3: return 10
        default: return 0
        }
    }

    private func countdownTag(for seconds: Int) -> Int {
        switch seconds {
        case 3: return 1
        case 5: return 2
        case 10: return 3
        default: return 0
        }
    }

    private func cameraPositionValue(for tag: Int) -> RecordingManager.CameraPosition {
        switch tag {
        case 0: return .topLeft
        case 1: return .topRight
        case 2: return .bottomLeft
        default: return .bottomRight
        }
    }

    private func cameraPositionTag(for value: RecordingManager.CameraPosition) -> Int {
        switch value {
        case .topLeft: return 0
        case .topRight: return 1
        case .bottomLeft: return 2
        case .bottomRight: return 3
        }
    }

    private func cameraSizeValue(for tag: Int) -> CGSize {
        switch tag {
        case 0: return CGSize(width: 160, height: 120)
        case 2: return CGSize(width: 260, height: 195)
        default: return CGSize(width: 200, height: 150)
        }
    }

    private func cameraSizeTag(for size: CGSize) -> Int {
        if size.width <= 160 { return 0 }
        if size.width >= 260 { return 2 }
        return 1
    }
}

struct RecordingActiveView: View {
    @StateObject private var state = RecordingState.shared

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                RecordingDot()

                Text(formatTime(state.recordingDuration))
                    .font(.system(size: 28, weight: .medium, design: .monospaced))

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

            if state.includeCamera {
                HStack {
                    Image(systemName: "camera.fill")
                    Text(L("recording.camera_on"))
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

struct SettingsView: View {
    @AppStorage("saveDirectory") private var saveDirectory: String = ""
    @AppStorage("imageFormat") private var imageFormat: String = "png"
    @AppStorage("videoQuality") private var videoQuality: String = "high"
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    
    var body: some View {
        Form {
            Section(L("settings.screenshot")) {
                Picker(L("settings.image_format"), selection: $imageFormat) {
                    Text("PNG").tag("png")
                    Text("JPEG").tag("jpeg")
                    Text("TIFF").tag("tiff")
                }

                HStack {
                    Text(L("settings.save_location"))
                    Spacer()
                    Text(saveDirectory.isEmpty ? L("settings.desktop") : saveDirectory)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Button(L("settings.choose")) {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url {
                            saveDirectory = url.path
                        }
                    }
                }
            }
            
            Section(L("settings.recording")) {
                Picker(L("settings.video_quality"), selection: $videoQuality) {
                    Text(L("settings.quality.high")).tag("high")
                    Text(L("settings.quality.medium")).tag("medium")
                    Text(L("settings.quality.low")).tag("low")
                }
            }

            Section(L("settings.general")) {
                Toggle(L("settings.launch_at_login"), isOn: $launchAtLogin)
            }

            Section(L("settings.shortcuts")) {
                HStack { Text(L("settings.shortcut.region_screenshot")); Spacer(); Text("⌘⇧4").foregroundColor(.secondary) }
                HStack { Text(L("settings.shortcut.window_screenshot")); Spacer(); Text("⌘⇧5").foregroundColor(.secondary) }
                HStack { Text(L("settings.shortcut.fullscreen_screenshot")); Spacer(); Text("⌘⇧6").foregroundColor(.secondary) }
                HStack { Text(L("settings.shortcut.region_recording")); Spacer(); Text("⌘⇧R").foregroundColor(.secondary) }
                HStack { Text(L("settings.shortcut.fullscreen_recording")); Spacer(); Text("⌘⇧F").foregroundColor(.secondary) }
                HStack { Text(L("settings.shortcut.stop_recording")); Spacer(); Text("⌘⇧S").foregroundColor(.secondary) }
            }

            Section(L("settings.about")) {
                HStack {
                    Text("FreeShot")
                    Spacer()
                    Text("v1.0.0").foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 450)
    }
}
