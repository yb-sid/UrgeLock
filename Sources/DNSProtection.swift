import Foundation

/// Backs up per-service DNS and applies CleanBrowsing Adult Filter.
final class DNSProtection {
    static let shared = DNSProtection()

    struct ServiceDNS: Codable {
        var service: String
        var servers: [String]  // empty means DHCP/default
    }

    private init() {}

    /// Network services that look like real interfaces (Wi-Fi, Ethernet, USB…).
    func listServices() -> [String] {
        let r = Shell.run("/usr/sbin/networksetup", arguments: ["-listallnetworkservices"])
        let lines = r.stdout.split(separator: "\n").map(String.init)
        // First line is an asterisk legend
        return lines.dropFirst().filter { !$0.hasPrefix("*") && !$0.isEmpty }
    }

    func getDNS(for service: String) -> [String] {
        let r = Shell.run("/usr/sbin/networksetup", arguments: ["-getdnsservers", service])
        let text = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().contains("there aren't any") || text.lowercased().contains("aren't any dns") {
            return []
        }
        return text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func backupCurrentDNS() throws {
        var backup: [ServiceDNS] = []
        for service in listServices() {
            backup.append(ServiceDNS(service: service, servers: getDNS(for: service)))
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(backup)
        try data.write(to: AppConfig.dnsBackupURL, options: .atomic)
    }

    func loadBackup() -> [ServiceDNS]? {
        guard let data = try? Data(contentsOf: AppConfig.dnsBackupURL) else { return nil }
        return try? JSONDecoder().decode([ServiceDNS].self, from: data)
    }

    /// Apply adult filter DNS to all services. networksetup usually works without admin for the current user.
    @discardableResult
    func enableFilterDNS() -> [String] {
        var errors: [String] = []
        if loadBackup() == nil {
            try? backupCurrentDNS()
        } else {
            // Refresh backup only if we were off
            try? backupCurrentDNS()
        }
        let servers = [AppConfig.filterDNSPrimary, AppConfig.filterDNSSecondary]
        for service in listServices() {
            let args = ["-setdnsservers", service] + servers
            let r = Shell.run("/usr/sbin/networksetup", arguments: args)
            if r.exitCode != 0 {
                errors.append("\(service): \(r.stderr.isEmpty ? r.stdout : r.stderr)")
            }
        }
        // Flush DNS cache
        _ = Shell.run("/usr/bin/dscacheutil", arguments: ["-flushcache"])
        _ = Shell.run("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
        return errors
    }

    @discardableResult
    func restoreDNS() -> [String] {
        var errors: [String] = []
        guard let backup = loadBackup() else {
            // Fall back to empty (DHCP)
            for service in listServices() {
                let r = Shell.run("/usr/sbin/networksetup", arguments: ["-setdnsservers", service, "Empty"])
                if r.exitCode != 0 {
                    errors.append("\(service): \(r.stderr)")
                }
            }
            return errors
        }
        for item in backup {
            let args: [String]
            if item.servers.isEmpty {
                args = ["-setdnsservers", item.service, "Empty"]
            } else {
                args = ["-setdnsservers", item.service] + item.servers
            }
            let r = Shell.run("/usr/sbin/networksetup", arguments: args)
            if r.exitCode != 0 {
                errors.append("\(item.service): \(r.stderr.isEmpty ? r.stdout : r.stderr)")
            }
        }
        _ = Shell.run("/usr/bin/dscacheutil", arguments: ["-flushcache"])
        _ = Shell.run("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
        return errors
    }

    func isFilterLikelyActive() -> Bool {
        for service in listServices() {
            let dns = getDNS(for: service)
            if dns.contains(AppConfig.filterDNSPrimary) || dns.contains(AppConfig.filterDNSSecondary) {
                return true
            }
        }
        return false
    }
}
