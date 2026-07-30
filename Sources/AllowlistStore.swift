import Foundation

final class AllowlistStore {
    static let shared = AllowlistStore()
    private(set) var domains: [String] = []

    private init() {
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: AppConfig.allowlistURL),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            domains = list.sorted()
        } else {
            domains = []
        }
    }

    /// Adding is free (no password) — expand only.
    @discardableResult
    func add(_ raw: String) -> Bool {
        let d = Self.normalize(raw)
        guard !d.isEmpty, !domains.contains(d) else { return false }
        domains.append(d)
        domains.sort()
        save()
        return true
    }

    /// Removing requires caller to have verified password.
    @discardableResult
    func remove(_ raw: String) -> Bool {
        let d = Self.normalize(raw)
        guard let idx = domains.firstIndex(of: d) else { return false }
        domains.remove(at: idx)
        save()
        return true
    }

    static func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        s = s.replacingOccurrences(of: "https://", with: "")
        s = s.replacingOccurrences(of: "http://", with: "")
        if let slash = s.firstIndex(of: "/") {
            s = String(s[..<slash])
        }
        if s.hasPrefix("www.") {
            s = String(s.dropFirst(4))
        }
        return s
    }

    private func save() {
        if let data = try? JSONEncoder().encode(domains) {
            try? data.write(to: AppConfig.allowlistURL, options: .atomic)
        }
    }
}
