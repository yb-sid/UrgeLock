import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only
        NSApp.setActivationPolicy(.accessory)
        statusBar = StatusBarController()
        ProtectionController.shared.start()

        if !StateStore.shared.state.isSetupComplete || !PasswordService.shared.hasPassword {
            DispatchQueue.main.async {
                if !Dialogs.setupWizard() {
                    NSApp.terminate(nil)
                } else {
                    self.statusBar?.rebuildMenu()
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
