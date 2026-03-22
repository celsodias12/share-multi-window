import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Reabre a janela de controle quando o usuário clica no ícone do dock.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Procura a janela de controle e mostra novamente
            for window in sender.windows {
                if window.title == "Share Multi Window" {
                    window.makeKeyAndOrderFront(nil)
                    return false
                }
            }
        }
        return true
    }
}
