import SwiftUI
import ScreenCaptureKit
import AppKit

struct ContentView: View {
    @Environment(WindowCaptureManager.self) private var manager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if let error = manager.permissionError {
                permissionView(error)
            } else if manager.allWindows.isEmpty {
                emptyView
            } else {
                windowGrid
            }

            Divider()
            footer
        }
        .frame(minWidth: 500, minHeight: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .task { await manager.loadWindows() }
        .onDisappear { manager.stopPreviewTimer() }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Compartilhar Janela")
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            if !manager.selectedWindowIDs.isEmpty {
                Text("\(manager.selectedWindowIDs.count) selecionada(s)")
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }

            Button {
                Task { await manager.loadWindows() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
            }
            .buttonStyle(.borderless)
            .help("Atualizar lista de janelas")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Permission error

    private func permissionView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Abrir Ajustes do Sistema") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty state

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Nenhuma janela encontrada", systemImage: "macwindow")
        } description: {
            Text("Clique em ↻ para atualizar")
        }
    }

    // MARK: - Window grid (Discord-style)

    private var windowGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(manager.appGroups) { group in
                    // App section header
                    HStack(spacing: 8) {
                        if let icon = group.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 18, height: 18)
                        }
                        Text(group.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    // Window cards in 2-column grid
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 10
                    ) {
                        ForEach(group.windows) { window in
                            WindowCard(
                                window: window,
                                preview: manager.previews[window.id],
                                isSelected: manager.selectedWindowIDs.contains(window.id)
                            ) {
                                Task { await manager.toggle(window.id) }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button {
                openWindow(id: "composite")
            } label: {
                Label("Compartilhar", systemImage: "rectangle.inset.filled.and.person.filled")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(manager.selectedWindowIDs.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Window card (Discord-style)

struct WindowCard: View {
    let window: WindowInfo
    let preview: NSImage?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Live preview thumbnail
            ZStack {
                previewImage
                    .frame(minHeight: 110, maxHeight: 130)
                    .frame(maxWidth: .infinity)
                    .clipped()

                // Selection overlay
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.blue.opacity(0.08))
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 3)
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Window title
            HStack(spacing: 6) {
                if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                }

                Text(window.title)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.08)
                      : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var previewImage: some View {
        if let preview {
            Image(nsImage: preview)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(.gray.opacity(0.1))
                .overlay {
                    ProgressView()
                        .scaleEffect(0.6)
                }
        }
    }
}
