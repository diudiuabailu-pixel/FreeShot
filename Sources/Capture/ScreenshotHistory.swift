import Foundation

class ScreenshotHistory {
    static let shared = ScreenshotHistory()
    
    private let historyKey = "ScreenshotHistory"
    
    var history: [URL] {
        get {
            guard let paths = UserDefaults.standard.array(forKey: historyKey) as? [String] else {
                return []
            }
            return paths.compactMap { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        }
        set {
            let paths = newValue.map { $0.path }
            UserDefaults.standard.set(paths, forKey: historyKey)
        }
    }
    
    private init() {}
    
    func add(_ url: URL) {
        var current = history
        current.insert(url, at: 0)
        
        // 限制数量
        if current.count > 100 {
            current = Array(current.prefix(100))
        }
        
        history = current
    }
    
    func remove(at index: Int) {
        var current = history
        guard index < current.count else { return }
        
        let url = current[index]
        try? FileManager.default.removeItem(at: url)
        
        current.remove(at: index)
        history = current
    }
    
    func clear() {
        // 删除所有文件
        for url in history {
            try? FileManager.default.removeItem(at: url)
        }
        history = []
    }
}
