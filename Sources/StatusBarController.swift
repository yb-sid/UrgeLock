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

        if !StateStore.shared.state.isSetupComplete || !PasswordService.shared.hasPassword {
            menu.addItem(item("Run setup…", #selector(runSetup)))
        } else {
            switch st {
            case .off:
                menu.addItem(item("Enable protection", #selector(enableProtection)))
                menu.addItem(item("Enable protection + hosts blocklist…", #selector(enableWithHosts)))
            case .on:
                menu.addItem(item("Request pause (password + cooldown)…", #selector(requestPause)))
            case .cooldown:
                menu.addItem(item("Cancel cooldown (stay protected)…", #selector(cancelCooldown)))
            case .paused:
                menu.addItem(item("Re-enable protection now", #selector(enableProtection)))
            }

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

        // Always refresh title icon state
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
            Dialogs.alert(title: "Protected", message: "DNS is now using CleanBrowsing Adult Filter for all browsers on this Mac.")
        }
    }

    @objc private func enableWithHosts() {
        guard Dialogs.confirm(
            title: "Apply hosts blocklist?",
            message: "macOS will ask for your Mac login password (admin) to update /etc/hosts with extra blocked domains."
        ) else { return }
        let msg = ProtectionController.shared.enableProtection(applyHosts: true)
        rebuildMenu()
        Dialogs.alert(title: "Protected", message: msg ?? "DNS filter + hosts blocklist applied.")
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
            message: "You must wait \(Int(StateStore.shared.state.cooldownSeconds / 60)) minutes before protection pauses. Urge will usually pass before then."
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

    @objc private func addAllowlist() {
        guard let raw = Dialogs.askText(title: "Allowlist", message: "Domain to always allow (e.g. example.com). No password required to add.", placeholder: "example.com"),
              !raw.isEmpty else { return }
        if AllowlistStore.shared.add(raw) {
            Dialogs.alert(title: "Added", message: "\(AllowlistStore.normalize(raw)) is allowlisted. Re-apply hosts blocklist from Enable if you use hosts mode.")
        } else {
            Dialogs.alert(title: "Not added", message: "Empty or already listed.")
        }
        rebuildMenu()
    }

    @objc private func removeAllowlist() {
        guard let pass = Dialogs.askPassword(title: "Remove allowlist entry", message: "Password required to remove allowlist domains.") else { return }
        guard PasswordService.shared.verifyPassword(pass) else {
            Dialogs.alert(title: "Wrong password", message: "Nothing removed.")
            return
        }
        guard let raw = Dialogs.askText(title: "Remove domain", message: "Which domain to remove from allowlist?", placeholder: "example.com"),
              !raw.isEmpty else { return }
        if AllowlistStore.shared.remove(raw) {
            Dialogs.alert(title: "Removed", message: AllowlistStore.normalize(raw))
        } else {
            Dialogs.alert(title: "Not found", message: "That domain is not on the allowlist.")
        }
        rebuildMenu()
    }

    @objc private func showAllowlist() {
        let list = AllowlistStore.shared.domains
        let body = list.isEmpty ? "(empty)" : list.joined(separator: "\n")
        Dialogs.alert(title: "Allowlist", message: body)
    }

    @objc private func setCooldown() {
        guard let pass = Dialogs.askPassword(title: "Change strictness", message: "Password required to change cooldown.") else { return }
        guard PasswordService.shared.verifyPassword(pass) else {
            Dialogs.alert(title: "Wrong password", message: "Unchanged.")
            return
        }
        guard let raw = Dialogs.askText(
            title: "Cooldown minutes",
            message: "How many minutes to wait after password before pause? (recommended 30+)",
            placeholder: "30"
        ), let mins = Int(raw), mins >= 1 else {
            Dialogs.alert(title: "Invalid", message: "Enter a whole number of minutes ≥ 1.")
            return
        }
        StateStore.shared.update { $0.cooldownSeconds = TimeInterval(mins * 60) }
        rebuildMenu()
        Dialogs.alert(title: "Updated", message: "Cooldown is now \(mins) minutes.")
    }

    @objc private func showAbout() {
        Dialogs.alert(
            title: "UrgeLock 0.1.0",
            message: """
            Open-source self-control shield for macOS.

            V1 uses CleanBrowsing Adult Filter DNS + optional /etc/hosts extras.
            Pause requires password + cooldown. Not impossible to remove — hard in the moment.

            https://github.com/yb-sid/UrgeLock
            """
        )
    }

    @objc private func quitApp() {
        guard let pass = Dialogs.askPassword(title: "Quit UrgeLock", message: "Password required to quit. DNS protection is NOT automatically turned off.") else { return }
        guard PasswordService.shared.verifyPassword(pass) else {
            Dialogs.alert(title: "Wrong password", message: "Still running.")
            return
        }
        NSApp.terminate(nil)
    }
}
