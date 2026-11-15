import Foundation
import Observation

@Observable
final class Config {
    static let defaults: [String: String] = [
        "fruit": "Apple", "apples": "1", "speed": "Normal", "map": "Medium",
        "mode": "Classic", "snake": "Classic Blue", "theme": "Classic",
        "bg_photo": "Off", "head_photo": "Off", "fruit_photo": "Off",
    ]

    var v: [String: String] = Config.defaults
    var best: [String: Int] = [:]

    let saveURL = dataDirectory().appendingPathComponent("snake_save.json")

    init() {
        load()
    }

    subscript(key: String) -> String {
        v[key] ?? Config.defaults[key] ?? ""
    }

    var apples: Int { Int(self["apples"]) ?? 1 }

    var theme: Theme { THEMES[self["theme"]] ?? THEMES["Classic"]! }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let saved = root["settings"] as? [String: Any] {
            for opt in OPTIONS {
                var value: String?
                if let s = saved[opt.key] as? String {
                    value = s
                } else if let n = saved[opt.key] as? NSNumber {
                    value = n.stringValue
                }
                if let value, opt.values.contains(value) {
                    v[opt.key] = value
                }
            }
        }
        if let b = root["best"] as? [String: Any] {
            for (mode, score) in b {
                if MODES.contains(mode), let n = score as? NSNumber {
                    best[mode] = n.intValue
                }
            }
        }
    }

    func save() {
        var settings: [String: Any] = [:]
        for (k, value) in v {
            settings[k] = k == "apples" ? (Int(value) ?? 1) : value
        }
        let root: [String: Any] = ["settings": settings, "best": best]
        if let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: saveURL, options: .atomic)
        }
    }

    func cycle(_ key: String, _ step: Int) {
        guard let opt = OPTIONS.first(where: { $0.key == key }) else { return }
        let i = opt.values.firstIndex(of: self[key]) ?? 0
        let n = opt.values.count
        v[key] = opt.values[((i + step) % n + n) % n]
    }
}
