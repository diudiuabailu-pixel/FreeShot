import Foundation

class ScreenshotHistory {
    static let shared = ScreenshotHistory()

    private let historyKey = "ScreenshotHistory"
    private let queue = DispatchQueue(label: "com.freeshot.history", qos: .utility)

    var history: [URL] {
        guard let paths = UserDefaults.standard.array(forKey: historyKey) as? [String] else {
            return []
        }
        return paths.compactMap { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func _save(_ urls: [URL]) {
        let paths = urls.map { $0.path }
        UserDefaults.standard.set(paths, forKey: historyKey)
    }

    private init() {}

    func add(_ url: URL) {
        queue.async { [self] in
            var current = history
            current.insert(url, at: 0)
            if current.count > 100 {
                current = Array(current.prefix(100))
            }
            _save(current)
        }
    }

    func remove(at index: Int) {
        queue.async { [self] in
            var current = history
            guard index < current.count else { return }
            let url = current[index]
            try? FileManager.default.removeItem(at: url)
            current.remove(at: index)
            _save(current)
        }
    }

    func clear() {
        queue.async { [self] in
            for url in history {
                try? FileManager.default.removeItem(at: url)
            }
            _save([])
        }
    }
}
