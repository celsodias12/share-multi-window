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
            // Ícone do app
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 18, height: 18)
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 9))
                    .foregroundStyle(.white)
            }

            Text("Compartilhar Janela")
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            if !manager.selectedWindowIDs.isEmpty {
                Text("\(manager.selectedWindowIDs.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
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
                    .frame(width: 24, height: 24)
                    .background(Color(nsColor: .quaternaryLabelColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.borderless)
            .help("Atualizar lista de janelas")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
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
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(manager.appGroups) { group in
                    // App section header
                    HStack(spacing: 6) {
                        if let icon = group.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 14, height: 14)
                        }
                        Text(group.name)
                            .font(.caption)
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(.secondary)

                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(maxWidth: .infinity, maxHeight: 1)
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

    @State private var isHovered = false

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
                    RoundedRectangle(cornerRadius: 7)
                        .fill(.blue.opacity(0.08))
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 16, height: 16)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(6)
                        }
                        Spacer()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))

            // Window title
            HStack(spacing: 6) {
                if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                }

                Text(window.title)
                    .font(.caption)
                    .fontWeight(isSelected ? .medium : .regular)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.top, 6)
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.06)
                      : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected
                        ? Color.accentColor.opacity(0.4)
                        : Color.white.opacity(0.06),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
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
