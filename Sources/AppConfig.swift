import Foundation

enum AppConfig {
    static let appName = "UrgeLock"
    static let bundleID = "app.urgelock.mac"
    /// Default cooldown before pause actually disables protection (seconds).
    static let defaultCooldownSeconds: TimeInterval = 30 * 60
    /// How long protection stays off after a successful pause (seconds).
    static let defaultPauseDurationSeconds: TimeInterval = 15 * 60

    /// CleanBrowsing Adult Filter — free public DNS that blocks adult domains.
    /// https://cleanbrowsing.org/filters#adult
    static let filterDNSPrimary = "185.228.168.10"
    static let filterDNSSecondary = "185.228.169.11"

    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(appName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var stateURL: URL { supportDirectory.appendingPathComponent("state.json") }
    static var allowlistURL: URL { supportDirectory.appendingPathComponent("allowlist.json") }
    static var dnsBackupURL: URL { supportDirectory.appendingPathComponent("dns-backup.json") }
}
