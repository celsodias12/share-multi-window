import SwiftUI

@main
struct ShareMultiWindowApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var manager = WindowCaptureManager()

    var body: some Scene {
        Window("Share Multi Window", id: "control") {
            ContentView()
                .environment(manager)
        }
        .defaultSize(width: 560, height: 520)

        Window("Tela Compartilhada", id: "composite") {
            CompositeView()
                .environment(manager)
        }
        .defaultSize(width: 1280, height: 720)
        .windowStyle(.hiddenTitleBar)
    }
}
