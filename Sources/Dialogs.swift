import AppKit

enum Dialogs {
    static func alert(title: String, message: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.alertStyle = .informational
        a.addButton(withTitle: "OK")
        a.runModal()
    }

    static func confirm(title: String, message: String) -> Bool {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.alertStyle = .warning
        a.addButton(withTitle: "Continue")
        a.addButton(withTitle: "Cancel")
        return a.runModal() == .alertFirstButtonReturn
    }

    /// Returns password string or nil if cancelled.
    static func askPassword(title: String, message: String) -> String? {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.alertStyle = .warning
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "Master password"
        a.accessoryView = field
        a.window.initialFirstResponder = field

        let res = a.runModal()
        guard res == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    static func askText(title: String, message: String, placeholder: String) -> String? {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = placeholder
        a.accessoryView = field
        a.window.initialFirstResponder = field
        guard a.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    static func setupWizard() -> Bool {
        let phrase = PasswordService.generateRecoveryPhrase()

        let intro = NSAlert()
        intro.messageText = "Welcome to UrgeLock"
        intro.informativeText = """
        This app blocks adult content system-wide via DNS (CleanBrowsing Adult Filter) and an optional local blocklist.

        You will set a master password. Pausing protection requires that password AND a waiting period (default 30 minutes).

        Next: choose a password and write down your recovery phrase.
        """
        intro.addButton(withTitle: "Continue")
        intro.addButton(withTitle: "Quit")
        if intro.runModal() != .alertFirstButtonReturn {
            return false
        }

        guard let pass1 = askPassword(title: "Set master password", message: "At least 6 characters. You will need this to pause or quit."),
              !pass1.isEmpty else { return false }
        guard let pass2 = askPassword(title: "Confirm password", message: "Enter the same password again."),
              pass1 == pass2 else {
            alert(title: "Mismatch", message: "Passwords did not match. Setup cancelled.")
            return false
        }

        let rec = NSAlert()
        rec.messageText = "Write down your recovery phrase"
        rec.informativeText = """
        If you forget your password, this phrase is the only reset method:

        \(phrase)

        Store it offline (paper, password manager). It will not be shown again.
        """
        rec.addButton(withTitle: "I saved it")
        rec.addButton(withTitle: "Cancel")
        if rec.runModal() != .alertFirstButtonReturn {
            return false
        }

        do {
            try PasswordService.shared.setPassword(pass1, recoveryPhrase: phrase)
        } catch {
            alert(title: "Setup failed", message: error.localizedDescription)
            return false
        }

        StateStore.shared.update { $0.isSetupComplete = true }
        alert(title: "Setup complete", message: "Click “Enable protection” in the menu bar to arm UrgeLock.")
        return true
    }
}
