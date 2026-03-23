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
            return []
        }
    }
    
    /// 截取指定显示器（使用 CGWindowListCreateImage 作为后备）
    func captureDisplay(_ displayID: CGDirectDisplayID) -> CGImage? {
        // 简化实现，使用主屏幕
        guard let screen = NSScreen.main else { return nil }
        
        return CGWindowListCreateImage(
            screen.frame,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
    }
    
    /// 录屏指定显示器
    func recordDisplay(_ displayID: CGDirectDisplayID, includeCamera: Bool) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw NSError(domain: "MultiDisplayManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Display not found"])
        }
        
        // 调用 RecordingManager 开始录屏
        RecordingManager.shared.startRecordingWithRegion(
            CGRect(x: 0, y: 0, width: display.width, height: display.height),
            includeCamera: includeCamera
        )
    }
}
