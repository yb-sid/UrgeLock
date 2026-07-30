import Foundation

/// Applies extra domains to /etc/hosts between UrgeLock markers (needs admin via osascript).
final class HostsBlocklist {
    static let shared = HostsBlocklist()

    private let beginMarker = "# BEGIN UrgeLock"
    private let endMarker = "# END UrgeLock"

    private init() {}

    func loadBundledDomains() -> [String] {
        var urls: [URL] = []
        if let res = Bundle.main.resourceURL?.appendingPathComponent("blocklists/extra-domains.txt") {
            urls.append(res)
        }
        // Dev fallback when running from build dir
        let dev = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/blocklists/extra-domains.txt")
        urls.append(dev)

        for url in urls {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return parseDomainList(text)
            }
        }
        return []
    }

    func parseDomainList(_ text: String) -> [String] {
        text.split(separator: "\n").compactMap { line -> String? in
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") { return nil }
            return AllowlistStore.normalize(t)
        }
    }

    /// Bundled built-in list + user-added list (from the app UI).
    func allConfiguredDomains() -> [String] {
        var set = Set(loadBundledDomains())
        for d in UserBlocklistStore.shared.domains {
            set.insert(d)
        }
        return set.sorted()
    }

    /// Domains to sinkhole = (bundled + user extras) − allowlist (and www variants).
    func effectiveBlockDomains() -> [String] {
        let allow = Set(AllowlistStore.shared.domains)
        var set = Set<String>()
        for d in allConfiguredDomains() {
            let bare = d.hasPrefix("www.") ? String(d.dropFirst(4)) : d
            if allow.contains(d) || allow.contains(bare) { continue }
            set.insert(bare)
            set.insert("www." + bare)
        }
        return set.sorted()
    }

    func hostsBlockSection() -> String {
        var lines = [beginMarker, "# Managed by UrgeLock — do not edit by hand"]
        for d in effectiveBlockDomains() {
            lines.append("0.0.0.0 \(d)")
        }
        lines.append(endMarker)
        return lines.joined(separator: "\n") + "\n"
    }

    /// Apply hosts section with admin privileges (GUI password prompt).
    func applyWithAdmin() -> String? {
        let section = hostsBlockSection()
        let tmp = AppConfig.supportDirectory.appendingPathComponent("hosts-section.txt")
        do {
            try section.write(to: tmp, atomically: true, encoding: .utf8)
        } catch {
            return "Failed to write temp hosts section: \(error.localizedDescription)"
        }

        // Python/shell script embedded: strip old markers, append new section, write /etc/hosts
        let script = """
        set sectionPath to "\(tmp.path)"
        set shellCmd to "python3 - <<'PY'\\nfrom pathlib import Path\\np = Path('/etc/hosts')\\ntext = p.read_text()\\nbegin = '# BEGIN UrgeLock'\\nend = '# END UrgeLock'\\nwhile begin in text and end in text:\\n    i = text.index(begin)\\n    j = text.index(end, i) + len(end)\\n    # eat trailing newline\\n    if j < len(text) and text[j] == '\\\\n':\\n        j += 1\\n    text = text[:i] + text[j:]\\nsection = Path(sectionPath).read_text()\\nif not text.endswith('\\\\n'):\\n    text += '\\\\n'\\ntext = text + section\\np.write_text(text)\\nPY"
        try
            do shell script shellCmd with administrator privileges
        on error errMsg number errNum
            return "error:" & errMsg
        end try
        return "ok"
        """

        let r = Shell.run("/usr/bin/osascript", arguments: ["-e", script])
        let out = (r.stdout + r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        if r.exitCode != 0 || out.hasPrefix("error:") {
            return out.isEmpty ? "Admin hosts update failed" : out
        }
        _ = Shell.run("/usr/bin/dscacheutil", arguments: ["-flushcache"])
        _ = Shell.run("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
        return nil
    }

    func removeWithAdmin() -> String? {
        let script = """
        set shellCmd to "python3 - <<'PY'\\nfrom pathlib import Path\\np = Path('/etc/hosts')\\ntext = p.read_text()\\nbegin = '# BEGIN UrgeLock'\\nend = '# END UrgeLock'\\nwhile begin in text and end in text:\\n    i = text.index(begin)\\n    j = text.index(end, i) + len(end)\\n    if j < len(text) and text[j] == '\\\\n':\\n        j += 1\\n    text = text[:i] + text[j:]\\np.write_text(text)\\nPY"
        try
            do shell script shellCmd with administrator privileges
        on error errMsg number errNum
            return "error:" & errMsg
        end try
        return "ok"
        """
        let r = Shell.run("/usr/bin/osascript", arguments: ["-e", script])
        let out = (r.stdout + r.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        if r.exitCode != 0 || out.hasPrefix("error:") {
            return out.isEmpty ? "Admin hosts remove failed" : out
        }
        return nil
    }
}
