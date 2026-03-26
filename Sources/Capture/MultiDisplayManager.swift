import Foundation
import ScreenCaptureKit
import AppKit

class MultiDisplayManager {
    static let shared = MultiDisplayManager()
    
    private init() {}
    
    /// 获取所有显示器
    func getDisplays() async throws -> [SCDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.displays
    }
    
    /// 获取显示器信息
    func getDisplayInfo() async -> [(id: CGDirectDisplayID, name: String, width: Int, height: Int)] {
        do {
            let displays = try await getDisplays()
            return displays.map { display in
                let name = "Display \(display.displayID)"
                return (id: display.displayID, name: name, width: Int(display.width), height: Int(display.height))
            }
        } catch {
            await MainActor.run {
                AppDelegate.showError("获取显示器列表失败：\(error.localizedDescription)")
            }
            return []
        }
    }
    
    /// 截取指定显示器
    func captureDisplay(_ displayID: CGDirectDisplayID) -> CGImage? {
        let bounds = CGDisplayBounds(displayID)
        return CGWindowListCreateImage(
            bounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        )
    }
    
    /// 录屏指定显示器
    func recordDisplay(_ displayID: CGDirectDisplayID, includeCamera: Bool) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw NSError(domain: "MultiDisplayManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Display not found"])
        }
        
        let bounds = CGDisplayBounds(display.displayID)
        RecordingManager.shared.startRecordingWithRegion(
            bounds,
            includeCamera: includeCamera,
            preferredDisplayID: display.displayID
        )
    }
}
