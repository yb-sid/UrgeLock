import Foundation

/// User-added domains to block (extra hosts). Stored in Application Support so
/// the installed app can grow the list without rebuilding.
final class UserBlocklistStore {
    static let shared = UserBlocklistStore()
    private(set) var domains: [String] = []

    private init() {
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: AppConfig.userBlocklistURL),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            domains = list.sorted()
        } else {
            domains = []
        }
    }

    /// Adding strengthens protection — no password.
    @discardableResult
    func add(_ raw: String) -> String? {
        let d = AllowlistStore.normalize(raw)
        guard !d.isEmpty else { return nil }
        guard !domains.contains(d) else { return d } // already there
        domains.append(d)
        domains.sort()
        save()
        return d
    }

    /// Removing weakens protection — caller must verify password.
    @discardableResult
    func remove(_ raw: String) -> Bool {
        let d = AllowlistStore.normalize(raw)
        guard let idx = domains.firstIndex(of: d) else { return false }
        domains.remove(at: idx)
        save()
        return true
    }

    func contains(_ raw: String) -> Bool {
        domains.contains(AllowlistStore.normalize(raw))
    }

    private func save() {
        if let data = try? JSONEncoder().encode(domains) {
            try? data.write(to: AppConfig.userBlocklistURL, options: .atomic)
        }
    }
}
