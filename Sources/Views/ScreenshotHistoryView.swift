import SwiftUI

struct ScreenshotHistoryView: View {
    @State private var screenshots: [URL] = []
    @State private var selectedScreenshot: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text(L("history.title"))
                    .font(.headline)
                Spacer()
                if !screenshots.isEmpty {
                    Button(L("history.clear")) {
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
                    Text(L("history.empty"))
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
                                    Button(L("history.copy")) {
                                        copyToClipboard(url: url)
                                    }
                                    Button(L("history.show_in_finder")) {
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                    }
                                    Divider()
                                    Button(L("history.delete"), role: .destructive) {
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
