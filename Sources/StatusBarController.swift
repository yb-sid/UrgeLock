import AppKit

final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!

    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "UrgeLock")
            button.image?.isTemplate = true
            button.toolTip = "UrgeLock"
        }
        menu = NSMenu()
        statusItem.menu = menu

        ProtectionController.shared.onChange = { [weak self] in
            self?.rebuildMenu()
        }
        rebuildMenu()
    }

    func rebuildMenu() {
        menu.removeAllItems()
        let status = ProtectionController.shared.statusLabel
        let header = NSMenuItem(title: "UrgeLock — \(status)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        let st = StateStore.shared.state.protectionStatus
        let hostsOn = StateStore.shared.state.hostsModeEnabled
        let userCount = UserBlocklistStore.shared.domains.count

        if !StateStore.shared.state.isSetupComplete || !PasswordService.shared.hasPassword {
            menu.addItem(item("Run setup…", #selector(runSetup)))
        } else {
            switch st {
            case .off:
                menu.addItem(item("Enable protection (DNS only)", #selector(enableProtection)))
                menu.addItem(item("Enable protection + hosts blocklist…", #selector(enableWithHosts)))
            case .on:
                menu.addItem(item("Request pause (password + cooldown)…", #selector(requestPause)))
                if hostsOn {
                    menu.addItem(item("Re-apply hosts blocklist now…", #selector(reapplyHosts)))
                } else {
                    menu.addItem(item("Apply hosts blocklist (extra sites)…", #selector(reapplyHosts)))
                }
            case .cooldown:
                menu.addItem(item("Cancel cooldown (stay protected)…", #selector(cancelCooldown)))
            case .paused:
                menu.addItem(item("Re-enable protection now", #selector(enableProtection)))
            }

            menu.addItem(NSMenuItem.separator())

            // Extra block sites — works after install, no rebuild
            let blockHeader = NSMenuItem(
                title: "My blocked sites (\(userCount))",
                action: nil,
                keyEquivalent: ""
            )
            blockHeader.isEnabled = false
            menu.addItem(blockHeader)
            menu.addItem(item("Block extra site…", #selector(addBlockedSite)))
            menu.addItem(item("Remove blocked site…", #selector(removeBlockedSite)))
            menu.addItem(item("Show my blocked sites", #selector(showBlockedSites)))

            menu.addItem(NSMenuItem.separator())
            menu.addItem(item("Add to allowlist…", #selector(addAllowlist)))
            menu.addItem(item("Remove from allowlist…", #selector(removeAllowlist)))
            menu.addItem(item("Show allowlist", #selector(showAllowlist)))

            menu.addItem(NSMenuItem.separator())
            menu.addItem(item("Strictness: cooldown \(Int(StateStore.shared.state.cooldownSeconds / 60)) min", #selector(setCooldown)))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(item("About UrgeLock", #selector(showAbout)))
            menu.addItem(item("Quit UrgeLock…", #selector(quitApp)))
        }

        if let button = statusItem.button {
            let symbol: String
            switch st {
            case .on: symbol = "lock.shield.fill"
            case .cooldown: symbol = "hourglass"
            case .paused: symbol = "pause.circle"
            case .off: symbol = "lock.open"
            }
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "UrgeLock")
            button.image?.isTemplate = true
            button.toolTip = "UrgeLock — \(status)"
        }
    }

    private func item(_ title: String, _ sel: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        i.target = self
        return i
    }

    @objc private func runSetup() {
        if Dialogs.setupWizard() {
            rebuildMenu()
        } else if !PasswordService.shared.hasPassword {
            NSApp.terminate(nil)
        }
    }

    @objc private func enableProtection() {
        let msg = ProtectionController.shared.enableProtection(applyHosts: false)
        rebuildMenu()
        if let msg, !msg.isEmpty {
            Dialogs.alert(title: "Protection enabled (with notes)", message: msg)
        } else {
            Dialogs.alert(
                title: "Protected",
                message: "DNS is using CleanBrowsing Adult Filter.\n\nTo also enforce sites you add under “Block extra site…”, use “Apply hosts blocklist”."
            )
        }
    }

    @objc private func enableWithHosts() {
        guard Dialogs.confirm(
            title: "Apply hosts blocklist?",
            message: "macOS will ask for your Mac login password (admin) to update /etc/hosts with built-in + your extra blocked domains."
        ) else { return }
        let msg = ProtectionController.shared.enableProtection(applyHosts: true)
        rebuildMenu()
        Dialogs.alert(title: "Protected", message: msg ?? "DNS filter + hosts blocklist applied.")
    }

    @objc private func reapplyHosts() {
        guard Dialogs.confirm(
            title: "Apply hosts blocklist?",
            message: "Writes built-in + your extra blocked sites into /etc/hosts. Admin password required. DNS filter is unchanged."
        ) else { return }
        if let err = ProtectionController.shared.reapplyHostsBlocklist() {
            Dialogs.alert(title: "Hosts update failed", message: err)
        } else {
            let n = HostsBlocklist.shared.effectiveBlockDomains().count
            Dialogs.alert(
                title: "Hosts updated",
                message: "Blocked \(n) hostnames via /etc/hosts (includes www. variants). Your list is saved in Application Support."
            )
        }
        rebuildMenu()
    }

    @objc private func requestPause() {
        guard let pass = Dialogs.askPassword(
            title: "Request pause",
            message: "Enter master password. Protection stays ON for \(Int(StateStore.shared.state.cooldownSeconds / 60)) more minutes, then pauses briefly."
        ) else { return }
        guard PasswordService.shared.verifyPassword(pass) else {
            Dialogs.alert(title: "Wrong password", message: "Pause not started.")
            return
        }
        ProtectionController.shared.requestPauseWithPassword()
        rebuildMenu()
        Dialogs.alert(
            title: "Cooldown started",
            message: "You must wait \(Int(StateStore.shared.state.cooldownSeconds / 60)) minutes before protection pauses."
        )
    }

    @objc private func cancelCooldown() {
        guard let pass = Dialogs.askPassword(title: "Cancel cooldown", message: "Stay protected. Enter password.") else { return }
        guard PasswordService.shared.verifyPassword(pass) else {
            Dialogs.alert(title: "Wrong password", message: "Cooldown continues.")
            return
        }
        ProtectionController.shared.cancelCooldown(passwordVerified: true)
        rebuildMenu()
    }

    // MARK: - User extra blocklist

    @objc private func addBlockedSite() {
        guard let raw = Dialogs.askText(
            title: "Block extra site",
            message: """
            Enter a domain to block (e.g. eurogirlsescort.com).
            No master password needed — adding is always allowed.

            Saved on this Mac under Application Support. To enforce via hosts, use “Apply hosts blocklist” (admin once).
            CleanBrowsing may already block many adult sites via DNS.
            """,
            placeholder: "example.com"
        ), !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        guard let domain = UserBlocklistStore.shared.add(raw) else {
            Dialogs.alert(title: "Not added", message: "Could not parse a domain from that input.")
            return
        }

        var message = "Added \(domain) to your personal blocklist."
        let st = StateStore.shared.state

        if st.protectionStatus == .on || st.hostsModeEnabled {
            if Dialogs.confirm(
                title: "Apply to system now?",
                message: "Re-write /etc/hosts so \(domain) is blocked immediately? (Mac admin password)"
            ) {
                if let err = ProtectionController.shared.reapplyHostsBlocklist() {
                    message += "\n\nSaved, but hosts apply failed: \(err)"
                } else {
                    message += "\n\nHosts updated — should be blocked now."
                }
            } else {
                message += "\n\nSaved only. Use “Apply hosts blocklist” when ready."
            }
        } else {
            message += "\n\nEnable protection + hosts (or Apply hosts) to enforce it system-wide."
        }

        Dialogs.alert(title: "Blocked site saved", message: message)
        rebuildMenu()
    }

    @objc private func removeBlockedSite() {
        guard let pass = Dialogs.askPassword(
            title: "Remove blocked site",
            message: "Master password required to remove a site from your blocklist."
        ) else { return }
        guard PasswordService.shared.verifyPassword(pass) else {
            Dialogs.alert(title: "Wrong password", message: "Nothing removed.")
            return
        }
        guard let raw = Dialogs.askText(
            title: "Remove blocked site",
            message: "Which domain to remove from your personal blocklist?",
            placeholder: "example.com"
        ), !raw.isEmpty else { return }

        if UserBlocklistStore.shared.remove(raw) {
            var msg = "Removed \(AllowlistStore.normalize(raw))."
            if StateStore.shared.state.hostsModeEnabled {
                if Dialogs.confirm(
                    title: "Update hosts?",
                    message: "Re-apply /etc/hosts so this domain is no longer force-blocked by UrgeLock hosts?"
                ) {
                    if let err = ProtectionController.shared.reapplyHostsBlocklist() {
                        msg += "\n\nHosts re-apply failed: \(err)"
                    } else {
                        msg += "\n\nHosts updated."
                    }
                }
            }
            // CleanBrowsing may still block adult domains via DNS.
            msg += "\n\nNote: CleanBrowsing DNS may still block adult sites even after hosts removal."
            Dialogs.alert(title: "Removed", message: msg)
        } else {
            Dialogs.alert(title: "Not found", message: "That domain is not on your personal blocklist.")
        }
        rebuildMenu()
    }

    @objc private func showBlockedSites() {
        let user = UserBlocklistStore.shared.domains
        let bundled = HostsBlocklist.shared.loadBundledDomains()
        var body = "Your extras (\(user.count)):\n"
        body += user.isEmpty ? "(none yet — use Block extra site…)\n" : user.joined(separator: "\n") + "\n"
        body += "\nBuilt-in list (\(bundled.count) domains) ships with the app.\n"
        body += "Effective hosts entries: \(HostsBlocklist.shared.effectiveBlockDomains().count) (with www. + minus allowlist)."
        Dialogs.alert(title: "Blocked sites", message: body)
    }

    // MARK: - Allowlist

    @objc private func addAllowlist() {
        guard let raw = Dialogs.askText(
            title: "Allowlist",
            message: "Domain to exclude from UrgeLock hosts blocks only (e.g. work site). Does not override CleanBrowsing adult DNS.",
            placeholder: "example.com"
        ), !raw.isEmpty else { return }
        if AllowlistStore.shared.add(raw) {
            Dialogs.alert(
                title: "Added",
                message: "\(AllowlistStore.normalize(raw)) allowlisted for hosts. Re-apply hosts if hosts mode is on."
            )
        } else {
            Dialogs.alert(title: "Not added", message: "Empty or already listed.")
        }
        rebuildMenu()
    }

    @objc private func removeAllowlist() {
        guard let pass = Dialogs.askPassword(title: "Remove allowlist entry", message: "Password required.") else { return }
        guard PasswordService.shared.verifyPassword(pass) else {
            Dialogs.alert(title: "Wrong password", message: "Nothing removed.")
            return
        }
        guard let raw = Dialogs.askText(title: "Remove domain", message: "Which allowlist domain?", placeholder: "example.com"),
              !raw.isEmpty else { return }
        if AllowlistStore.shared.remove(raw) {
            Dialogs.alert(title: "Removed", message: AllowlistStore.normalize(raw))
        } else {
            Dialogs.alert(title: "Not found", message: "Not on the allowlist.")
        }
        rebuildMenu()
    }

    @objc private func showAllowlist() {
        let list = AllowlistStore.shared.domains
        Dialogs.alert(title: "Allowlist", message: list.isEmpty ? "(empty)" : list.joined(separator: "\n"))
    }

    @objc private func setCooldown() {
        guard let pass = Dialogs.askPassword(title: "Change strictness", message: "Password required.") else { return }
        guard PasswordService.shared.verifyPassword(pass) else {
            Dialogs.alert(title: "Wrong password", message: "Unchanged.")
            return
        }
        guard let raw = Dialogs.askText(
            title: "Cooldown minutes",
            message: "Minutes to wait after password before pause (recommended 30+)",
            placeholder: "30"
        ), let mins = Int(raw), mins >= 1 else {
            Dialogs.alert(title: "Invalid", message: "Enter a whole number ≥ 1.")
            return
        }
        StateStore.shared.update { $0.cooldownSeconds = TimeInterval(mins * 60) }
        rebuildMenu()
        Dialogs.alert(title: "Updated", message: "Cooldown is now \(mins) minutes.")
    }

    @objc private func showAbout() {
        Dialogs.alert(
            title: "UrgeLock 0.1.1",
            message: """
            Open-source self-control shield for macOS.

            • CleanBrowsing Adult DNS (all browsers)
            • Extra sites you add after install → personal blocklist + /etc/hosts
            • Pause = password + cooldown

            https://github.com/yb-sid/UrgeLock
            """
        )
    }

    @objc private func quitApp() {
        guard let pass = Dialogs.askPassword(
            title: "Quit UrgeLock",
            message: "Password required. DNS/hosts are NOT automatically turned off."
        ) else { return }
        guard PasswordService.shared.verifyPassword(pass) else {
            Dialogs.alert(title: "Wrong password", message: "Still running.")
            return
        }
        NSApp.terminate(nil)
    }
}
