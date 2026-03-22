import SwiftUI

struct CompositeView: View {
    @Environment(WindowCaptureManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if manager.selectedWindowIDs.isEmpty {
                    emptyState
                } else if let activeID = manager.activeWindowID,
                          let image = manager.frames[activeID] {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.black
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Controles — aparecem no hover
            if !manager.selectedWindowIDs.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        openControlWindow()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.system(size: 10))
                            Text("Selecionar janelas")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(showControls ? 0.2 : 0))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        manager.stopSharing()
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10))
                            Text("Parar")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.red.opacity(showControls ? 0.85 : 0))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 16)
                .opacity(showControls ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: showControls)
            }
        }
        .background(.black)
        .onHover { hovering in
            showControls = hovering
        }
        .task {
            manager.startFocusTracking()
        }
    }

    private func openControlWindow() {
        for window in NSApp.windows {
            if window.title == "Share Multi Window" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 48))
                .foregroundStyle(.gray)
            Text("Nenhuma janela selecionada")
                .foregroundStyle(.gray)
            Text("Selecione janelas no painel de controle")
                .font(.caption)
                .foregroundStyle(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
