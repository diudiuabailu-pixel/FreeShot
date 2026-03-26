import SwiftUI
import AppKit

struct DisplayPickerView: View {
    @State private var displays: [(id: CGDirectDisplayID, name: String, width: Int, height: Int)] = []
    @State private var selectedDisplay: CGDirectDisplayID = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("选择显示器")
                .font(.headline)
            
            if displays.isEmpty {
                ProgressView()
                    .padding()
            } else {
                List(displays, id: \.id, selection: $selectedDisplay) { display in
                    HStack {
                        Image(systemName: "display")
                        VStack(alignment: .leading) {
                            Text(display.name)
                            Text("\(display.width) × \(display.height)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if display.id == selectedDisplay {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .tag(display.id)
                }
                .frame(height: 200)
            }
            
            HStack {
                Button("取消") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("截取") {
                    captureSelectedDisplay()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedDisplay == 0)
            }
        }
        .padding()
        .frame(width: 350)
        .task {
            let info = await MultiDisplayManager.shared.getDisplayInfo()
            await MainActor.run {
                displays = info
                if let first = info.first {
                    selectedDisplay = first.id
                }
            }
        }
    }
    
    private func captureSelectedDisplay() {
        // 截取选中的显示器
        if let image = MultiDisplayManager.shared.captureDisplay(selectedDisplay) {
            saveImage(CGImage: image)
        }
        NSApp.keyWindow?.close()
    }
    
    private func saveImage(CGImage image: CGImage) {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "FreeShot-Display-\(dateString()).png"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if let tiffData = nsImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}

class DisplayPickerWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "选择显示器"
        self.center()
        
        let hostingView = NSHostingView(rootView: DisplayPickerView())
        self.contentView = hostingView
    }
}
