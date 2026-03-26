import SwiftUI

struct ScreenshotHistoryView: View {
    @State private var screenshots: [URL] = []
    @State private var selectedScreenshot: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("截图历史")
                    .font(.headline)
                Spacer()
                if !screenshots.isEmpty {
                    Button("清空") {
                        ScreenshotHistory.shared.clear()
                        loadHistory()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            .padding()
            
            Divider()
            
            if screenshots.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("暂无截图历史")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                        ForEach(Array(screenshots.enumerated()), id: \.offset) { index, url in
                            ScreenshotThumbnail(url: url)
                                .onTapGesture {
                                    selectedScreenshot = url
                                }
                                .contextMenu {
                                    Button("复制") {
                                        copyToClipboard(url: url)
                                    }
                                    Button("在 Finder 中显示") {
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                    }
                                    Divider()
                                    Button("删除", role: .destructive) {
                                        ScreenshotHistory.shared.remove(at: index)
                                        loadHistory()
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 250, maxWidth: 350)
        .onAppear {
            loadHistory()
        }
    }
    
    private func loadHistory() {
        screenshots = ScreenshotHistory.shared.history
    }
    
    private func copyToClipboard(url: URL) {
        if let image = NSImage(contentsOf: url) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        }
    }
}

struct ScreenshotThumbnail: View {
    let url: URL
    
    var body: some View {
        Group {
            if let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .clipped()
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 80, height: 60)
                    .cornerRadius(6)
            }
        }
    }
}

#Preview {
    ScreenshotHistoryView()
}

class ScreenshotHistoryWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.title = "截图历史"
        self.isReleasedWhenClosed = false
        self.contentViewController = NSHostingController(rootView: ScreenshotHistoryView())
        self.center()
    }
}
