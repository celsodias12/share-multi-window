import SwiftUI

struct CompositeView: View {
    @Environment(WindowCaptureManager.self) private var manager

    private static let bgColor = Color(red: 0.11, green: 0.11, blue: 0.118)

    private var windowIDs: [CGWindowID] {
        Array(manager.selectedWindowIDs).sorted()
    }

    private var columns: Int {
        switch windowIDs.count {
        case 0, 1: return 1
        case 2:    return 2
        case 3, 4: return 2
        default:   return 3
        }
    }

    var body: some View {
        Group {
            if windowIDs.isEmpty {
                emptyState
            } else {
                captureGrid
            }
        }
        .background(Self.bgColor)
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

    // MARK: - Grid of captured windows

    private var captureGrid: some View {
        GeometryReader { geo in
            let rows = Int(ceil(Double(windowIDs.count) / Double(columns)))
            let totalHGaps = CGFloat(columns - 1) * 12
            let totalVGaps = CGFloat(rows - 1) * 12
            let cellW = (geo.size.width - 32 - totalHGaps) / CGFloat(columns)
            let cellH = (geo.size.height - 32 - totalVGaps) / CGFloat(rows)

            VStack(spacing: 12) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < windowIDs.count {
                                let windowID = windowIDs[index]
                                let windowInfo = manager.allWindows.first { $0.id == windowID }
                                WindowFrameView(
                                    image: manager.frames[windowID],
                                    title: windowInfo?.title ?? "",
                                    appIcon: windowInfo?.appIcon
                                )
                                .frame(width: cellW, height: cellH)
                            } else {
                                Self.bgColor
                                    .frame(width: cellW, height: cellH)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Single window frame with slim header

struct WindowFrameView: View {
    let image: NSImage?
    let title: String
    let appIcon: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            // Slim header
            HStack(spacing: 6) {
                if let appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.06))

            // Separador
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)

            // Conteúdo da janela
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.black.opacity(0.3)
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 4)
    }
}
