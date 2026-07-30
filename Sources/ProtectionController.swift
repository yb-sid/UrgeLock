import Foundation
import AppKit

/// Orchestrates DNS filter, hosts blocklist, cooldown, and pause timers.
final class ProtectionController: NSObject {
    static let shared = ProtectionController()

    private var tickTimer: Timer?
    var onChange: (() -> Void)?

    private override init() {
        super.init()
    }

    func start() {
        reconcileTimers()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let t = tickTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    var status: ProtectionStatus {
        StateStore.shared.state.protectionStatus
    }

    var statusLabel: String {
        let s = StateStore.shared.state
        switch s.protectionStatus {
        case .off: return "Off"
        case .on: return "Protected"
        case .cooldown:
            if let end = s.cooldownEndsAt {
                return "Cooldown \(formatRemaining(end))"
            }
            return "Cooldown"
        case .paused:
            if let end = s.pauseEndsAt {
                return "Paused \(formatRemaining(end))"
            }
            return "Paused"
        }
    }

    func enableProtection(applyHosts: Bool) -> String? {
        let dnsErrors = DNSProtection.shared.enableFilterDNS()
        var msg: String? = nil
        if applyHosts {
            if let err = HostsBlocklist.shared.applyWithAdmin() {
                msg = "DNS applied; hosts: \(err)"
            }
        }
        StateStore.shared.update {
            $0.protectionStatus = .on
            $0.cooldownEndsAt = nil
            $0.pauseEndsAt = nil
        }
        if !dnsErrors.isEmpty {
            msg = (msg.map { $0 + " | " } ?? "") + "DNS warnings: \(dnsErrors.joined(separator: "; "))"
        }
        notify()
        return msg
    }

    /// Immediate disable — only after cooldown completes, or during setup testing.
    func disableProtectionNow(removeHosts: Bool) -> String? {
        let dnsErrors = DNSProtection.shared.restoreDNS()
        var msg: String? = nil
        if removeHosts {
            if let err = HostsBlocklist.shared.removeWithAdmin() {
                msg = "Hosts: \(err)"
            }
        }
        StateStore.shared.update {
            $0.protectionStatus = .off
            $0.cooldownEndsAt = nil
            $0.pauseEndsAt = nil
        }
        if !dnsErrors.isEmpty {
            msg = (msg.map { $0 + " | " } ?? "") + dnsErrors.joined(separator: "; ")
        }
        notify()
        return msg
    }

    /// Start cooldown after password verified. Protection stays ON until cooldown ends, then pause window.
    func requestPauseWithPassword() {
        let seconds = StateStore.shared.state.cooldownSeconds
        StateStore.shared.update {
            $0.protectionStatus = .cooldown
            $0.cooldownEndsAt = Date().addingTimeInterval(seconds)
            $0.pauseEndsAt = nil
        }
        notify()
    }

    func cancelCooldown(passwordVerified: Bool) {
        guard passwordVerified else { return }
        StateStore.shared.update {
            $0.protectionStatus = .on
            $0.cooldownEndsAt = nil
        }
        // Re-assert DNS in case something drifted
        _ = DNSProtection.shared.enableFilterDNS()
        notify()
    }

    private func tick() {
        let s = StateStore.shared.state
        switch s.protectionStatus {
        case .cooldown:
            if let end = s.cooldownEndsAt, Date() >= end {
                // Enter pause: restore DNS for pause duration
                _ = DNSProtection.shared.restoreDNS()
                let pauseFor = s.pauseDurationSeconds
                StateStore.shared.update {
                    $0.protectionStatus = .paused
                    $0.cooldownEndsAt = nil
                    $0.pauseEndsAt = Date().addingTimeInterval(pauseFor)
                }
                notify()
            }
        case .paused:
            if let end = s.pauseEndsAt, Date() >= end {
                _ = DNSProtection.shared.enableFilterDNS()
                StateStore.shared.update {
                    $0.protectionStatus = .on
                    $0.pauseEndsAt = nil
                }
                notify()
            }
        case .on:
            // Optional: re-assert filter DNS periodically if user flipped settings
            break
        case .off:
            break
        }
    }

    private func reconcileTimers() {
        let s = StateStore.shared.state
        switch s.protectionStatus {
        case .cooldown:
            if let end = s.cooldownEndsAt, Date() >= end {
                tick()
            }
        case .paused:
            if let end = s.pauseEndsAt, Date() >= end {
                tick()
            } else if s.pauseEndsAt != nil {
                // Ensure DNS is open during pause
                _ = DNSProtection.shared.restoreDNS()
            }
        case .on:
            if !DNSProtection.shared.isFilterLikelyActive() {
                _ = DNSProtection.shared.enableFilterDNS()
            }
        case .off:
            break
        }
    }

    private func formatRemaining(_ end: Date) -> String {
        let sec = max(0, Int(end.timeIntervalSinceNow))
        let m = sec / 60
        let s = sec % 60
        if m >= 60 {
            let h = m / 60
            let rm = m % 60
            return String(format: "%dh%02dm", h, rm)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func notify() {
        DispatchQueue.main.async { self.onChange?() }
    }
}
