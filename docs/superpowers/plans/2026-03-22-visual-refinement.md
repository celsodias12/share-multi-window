# Visual Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign visual de ambas as telas do Share Multi Window (CompositeView + ContentView) com estilo macOS nativo refinado.

**Architecture:** Mudanças puramente visuais em duas views SwiftUI e uma refatoração de interface no WindowFrameView para suportar slim headers na tela composta. Sem mudanças na lógica de captura.

**Tech Stack:** SwiftUI (macOS 14+), Swift 5.9, ScreenCaptureKit

**Spec:** `docs/superpowers/specs/2026-03-22-visual-refinement-design.md`

**Nota:** Line numbers referem-se ao arquivo original antes de qualquer modificação. Após cada task, use o nome da property/struct para localizar o bloco correto.

---

### Task 1: Redesign completo do CompositeView (WindowFrameView + grid)

**Files:**
- Modify: `Sources/CompositeView.swift` (arquivo inteiro)

- [ ] **Step 1: Reescrever CompositeView.swift completo**

Substituir o conteúdo inteiro de `Sources/CompositeView.swift`:

```swift
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
```

- [ ] **Step 2: Build para verificar compilação**

Run: `cd /Users/celsodias/projects/ai/share-multi-window && swift build 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add Sources/CompositeView.swift
git commit -m "feat: redesign CompositeView with slim headers, dark background, and proper spacing"
```

---

### Task 2: Redesign do toolbar da ContentView

**Files:**
- Modify: `Sources/ContentView.swift` (computed property `toolbar`)

- [ ] **Step 1: Substituir o toolbar**

Localizar o computed property `private var toolbar: some View` e substituir inteiro:

```swift
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
```

- [ ] **Step 2: Build para verificar compilação**

Run: `cd /Users/celsodias/projects/ai/share-multi-window && swift build 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add Sources/ContentView.swift
git commit -m "feat: redesign toolbar with app icon, compact badge, and styled refresh button"
```

---

### Task 3: Redesign dos app group headers

**Files:**
- Modify: `Sources/ContentView.swift` (computed property `windowGrid`)

- [ ] **Step 1: Substituir o windowGrid**

Localizar o computed property `private var windowGrid: some View` e substituir inteiro:

```swift
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
```

- [ ] **Step 2: Build para verificar compilação**

Run: `cd /Users/celsodias/projects/ai/share-multi-window && swift build 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add Sources/ContentView.swift
git commit -m "feat: redesign app group headers with uppercase, tracking, and separator line"
```

---

### Task 4: Redesign do WindowCard

**Files:**
- Modify: `Sources/ContentView.swift` (struct `WindowCard`)

- [ ] **Step 1: Substituir WindowCard inteiro**

Localizar `struct WindowCard: View` e substituir a struct inteira (incluindo o `previewImage`):

```swift
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
```

- [ ] **Step 2: Build para verificar compilação**

Run: `cd /Users/celsodias/projects/ai/share-multi-window && swift build 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add Sources/ContentView.swift
git commit -m "feat: redesign WindowCard with refined borders, hover effect, and new checkmark"
```

---

### Task 5: Redesign do footer com custom button style

**Files:**
- Modify: `Sources/ContentView.swift` (computed property `footer` + novo `GradientButtonStyle`)

- [ ] **Step 1: Adicionar GradientButtonStyle**

Inserir a struct `GradientButtonStyle` entre o fechamento de `struct ContentView` e `struct WindowCard`:

```swift
struct GradientButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [.blue, .indigo],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(isEnabled ? 1 : 0.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(
                color: isEnabled ? Color.accentColor.opacity(0.3) : .clear,
                radius: 8
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

- [ ] **Step 2: Substituir o footer**

Localizar o computed property `private var footer: some View` e substituir:

```swift
    private var footer: some View {
        HStack {
            Spacer()
            Button {
                openWindow(id: "composite")
            } label: {
                Label("Compartilhar", systemImage: "rectangle.on.rectangle")
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(manager.selectedWindowIDs.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }
```

- [ ] **Step 3: Build para verificar compilação**

Run: `cd /Users/celsodias/projects/ai/share-multi-window && swift build 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 4: Commit**

```bash
git add Sources/ContentView.swift
git commit -m "feat: redesign footer with gradient button style and glow shadow"
```

---

### Task 6: Build final e verificação visual

**Files:**
- Nenhum arquivo modificado — apenas verificação

- [ ] **Step 1: Build release**

Run: `cd /Users/celsodias/projects/ai/share-multi-window && swift build -c release 2>&1 | tail -5`
Expected: Build succeeded

- [ ] **Step 2: Gerar o app bundle**

Run: `cd /Users/celsodias/projects/ai/share-multi-window && make app 2>&1 | tail -10`
Expected: App bundle criado em `ShareMultiWindow.app`

- [ ] **Step 3: Abrir o app para verificação visual**

Run: `open /Users/celsodias/projects/ai/share-multi-window/ShareMultiWindow.app`
Expected: App abre, painel de controle mostra o novo visual refinado

Checklist visual:
- [ ] Toolbar tem ícone gradient azul→roxo, badge compacto, botão refresh estilizado
- [ ] App groups têm nome uppercase com tracking e linha separadora
- [ ] Window cards têm bordas translúcidas, hover com escala, checkmark em círculo azul
- [ ] Footer tem botão gradient com sombra glow
- [ ] Tela composta tem fundo escuro (#1C1C1E), gaps de 12pt, slim headers com ícone e título
- [ ] Janelas preservam aspect ratio
- [ ] Células vazias no grid mostram cor de fundo (sem buracos)

- [ ] **Step 4: Commit final (se necessário ajuste)**

```bash
git add -A
git commit -m "fix: visual adjustments after manual verification"
```
