import SwiftUI

struct CompositeView: View {
    @Environment(WindowCaptureManager.self) private var manager

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
        .background(.black)
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
            let cellW = geo.size.width / CGFloat(columns)
            let cellH = geo.size.height / CGFloat(rows)

            VStack(spacing: 1) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < windowIDs.count {
                                WindowFrameView(image: manager.frames[windowIDs[index]])
                                    .frame(width: cellW - 1, height: cellH - 1)
                            } else {
                                Color.black
                                    .frame(width: cellW - 1, height: cellH - 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Single window frame

struct WindowFrameView: View {
    let image: NSImage?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.black.opacity(0.5)
                .overlay {
                    ProgressView()
                        .scaleEffect(0.7)
                }
        }
    }
}
