# Visual Refinement — Share Multi Window

**Data:** 2026-03-22
**Status:** Aprovado
**Escopo:** Redesign visual de ambas as telas (CompositeView + ContentView)

## Contexto

Share Multi Window é um app macOS SwiftUI que captura e exibe múltiplas janelas simultaneamente. O uso principal é compartilhar a tela composta em video calls (Zoom/Meet/Teams), mostrando várias janelas ao mesmo tempo para os participantes.

O visual atual é funcional mas genérico — usa cores de sistema sem refinamento, separadores de 1px, sem identidade visual nas janelas da tela composta, e cards básicos no painel de controle.

**Nota:** Todos os valores em "px" neste spec significam pontos SwiftUI (CGFloat). Terminologia SwiftUI é usada para APIs; quando CSS é mencionado, é apenas para referência visual.

## Decisões de Design

- **Estilo:** macOS nativo refinado (tipo Spotlight/AirDrop) — não dark-mode forçado, segue o design system da Apple mas com mais polish
- **Tela composta:** Abordagem "Slim Header" — header compacto por janela com ícone colorido + nome do app
- **Prioridade:** Legibilidade em codec de vídeo comprimido (screen sharing)

## Spec: CompositeView (Tela Composta)

### Fundo e Espaçamento

| Propriedade | Valor |
|-------------|-------|
| Cor de fundo | `Color(red: 0.11, green: 0.11, blue: 0.118)` (equivale a `#1C1C1E`) |
| Padding externo | 16 pt |
| Gap entre janelas | 12 pt |
| Corner radius janela | 10 pt |

### Refatoração de WindowFrameView

O `WindowFrameView` atual recebe apenas `let image: NSImage?`. Para suportar o slim header, precisa ser refatorado para receber dados adicionais:

```swift
struct WindowFrameView: View {
    let image: NSImage?
    let title: String        // título da janela
    let appIcon: NSImage?    // ícone do app
}
```

O chamador no `captureGrid` deve passar esses dados a partir do `WindowInfo` correspondente (lookup pelo `windowID` na lista `manager.allWindows`). O `appIcon` (propriedade computada que faz lookup via `NSWorkspace`) deve ser resolvido uma vez no chamador e passado como valor — evitando lookups repetidos a cada frame (~15fps).

### Slim Header (por janela)

Cada janela capturada recebe um header compacto que identifica o app de origem.

| Propriedade | Valor |
|-------------|-------|
| Altura | ~22pt (padding 4pt vertical, 10pt horizontal) |
| Fundo | `Color.white.opacity(0.06)` |
| Separador inferior | `Color.white.opacity(0.04)`, 1pt |
| Ícone do app | 10x10pt, `clipShape(RoundedRectangle(cornerRadius: 3))`, usa `appIcon` real |
| Fonte | `.caption`, weight `.medium` |
| Cor do texto | `Color.white.opacity(0.6)` |
| Conteúdo | ícone do app + título da janela (truncado com `.lineLimit(1)`) |

### Borda e Sombra (por janela)

| Propriedade | Valor |
|-------------|-------|
| Borda | `Color.white.opacity(0.06)`, 1pt |
| Sombra | `.shadow(color: .black.opacity(0.3), radius: 16, y: 4)` |
| Clipping | `.clipShape(RoundedRectangle(cornerRadius: 10))` |

### Grid Responsivo

O layout continua usando `GeometryReader` com `VStack(spacing: 12)`/`HStack(spacing: 12)` (substituindo o `spacing: 1` atual). O padding externo de 16pt é aplicado ao conteúdo dentro do `GeometryReader` (via `.padding(16)` no `VStack` raiz), não no `GeometryReader` em si — para que o cálculo de `cellW`/`cellH` considere o espaço total disponível e desconte padding e gaps.

| Janelas | Colunas | Layout |
|---------|---------|--------|
| 1 | 1 | Janela ocupa todo o espaço |
| 2 | 2 | Lado a lado |
| 3-4 | 2 | Grid 2x2 |
| 5+ | 3 | Grid 3 colunas |

**Células incompletas na última linha:** Quando a última linha tem menos janelas que colunas (ex: 3 janelas em 2 colunas, 5 janelas em 3 colunas), as células vazias são preenchidas com a mesma cor de fundo (`Color(red: 0.11, green: 0.11, blue: 0.118)`) para robustez — independente do contexto pai. As janelas existentes na última linha mantêm o mesmo tamanho das demais — não esticam para preencher.

### Aspect Ratio

O `.aspectRatio(contentMode: .fit)` é aplicado apenas à `Image` dentro do `WindowFrameView` (como já é feito atualmente). O container da célula ocupa o espaço calculado pelo `GeometryReader`. O fundo escuro da célula preenche qualquer espaço não ocupado pela imagem.

### Empty State

- Ícone: `rectangle.on.rectangle.slash` (mantém atual)
- Texto primário: `Color.gray`
- Texto secundário: `Color.gray.opacity(0.7)`
- Centralizado vertical e horizontalmente

### Loading State (WindowFrameView)

- Fundo: `Color.black.opacity(0.3)` (mais sutil que o atual 0.5)
- ProgressView com `.tint(.white)`

## Spec: ContentView (Painel de Controle)

### Toolbar

| Propriedade | Antes | Depois |
|-------------|-------|--------|
| Fundo | transparente | `Color(nsColor: .windowBackgroundColor).opacity(0.5)` |
| Ícone do app | ausente | SF Symbol `rectangle.on.rectangle` com `.font(.system(size: 9))` em `Color.white`, sobre fundo 18x18pt com `.clipShape(RoundedRectangle(cornerRadius: 5))`, preenchido com `LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)` |
| Badge contador | "2 selecionada(s)" | Apenas o número ("2") — mais compacto |
| Badge estilo | texto + capsule | mesmo, com `.fontWeight(.medium)` |
| Botão refresh | `.borderless` simples | fundo sutil `Color(nsColor: .quaternaryLabelColor)` com cornerRadius 6pt |
| Padding | 16h, 12v | mantém |

### App Group Headers

| Propriedade | Antes | Depois |
|-------------|-------|--------|
| Nome do app | `.subheadline.semibold` normal | `.caption.bold` com `.textCase(.uppercase)` e `.tracking(0.5)` |
| Linha separadora | ausente | `Rectangle().fill(Color.white.opacity(0.04)).frame(maxWidth: .infinity, maxHeight: 1)` no HStack após o nome — o Rectangle preenche o espaço restante automaticamente |
| Ícone | 18x18pt | 14x14pt |
| Spacing entre grupos | 16pt | 18pt |

### Window Cards

| Propriedade | Antes | Depois |
|-------------|-------|--------|
| Corner radius externo | 8pt | 10pt |
| Corner radius preview | 6pt | 7pt |
| Borda não-selecionado | nenhuma | `Color.white.opacity(0.06)`, 1pt |
| Fundo não-selecionado | `controlBackgroundColor` | `Color(nsColor: .controlBackgroundColor)` (mantém, funciona bem) |
| Borda selecionado | `accentColor`, 2pt | `Color.accentColor.opacity(0.4)`, 1.5pt |
| Fundo selecionado | `accentColor.opacity(0.08)` | `Color.accentColor.opacity(0.06)` |
| Checkmark | `checkmark.circle.fill` branco com sombra | `ZStack { Circle().fill(.blue).frame(width: 16, height: 16); Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.white) }` |
| Título selecionado | `.primary` | `.foregroundStyle(.primary)` com `.fontWeight(.medium)` |
| Título não-selecionado | `.secondary` | `.foregroundStyle(.secondary)` (mantém) |
| Hover | nenhum | `@State var isHovered = false` + `.onHover { isHovered = $0 }` + `.scaleEffect(isHovered ? 1.02 : 1.0)` + `.animation(.easeInOut(duration: 0.15), value: isHovered)` |
| Padding interno | 6pt | 5pt |

### Footer

| Propriedade | Antes | Depois |
|-------------|-------|--------|
| Fundo | transparente | `Color(nsColor: .windowBackgroundColor).opacity(0.5)` |
| Botão estilo | `.borderedProminent` padrão | Custom `ButtonStyle` (`.buttonStyle(.plain)` + manual): fundo `LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)`, foreground `.white`, `.fontWeight(.semibold)`, `.padding(.horizontal, 20).padding(.vertical, 8)`, `.clipShape(RoundedRectangle(cornerRadius: 8))` |
| Botão disabled | opacidade padrão sistema | `.opacity(0.4)` no gradiente, sem sombra |
| Botão sombra | nenhuma | `.shadow(color: .accentColor.opacity(0.3), radius: 8)` (somente quando enabled) |
| Ícone no botão | `rectangle.inset.filled.and.person.filled` | `rectangle.on.rectangle` (consistente com toolbar) |
| Padding | 16h, 12v | mantém |

### Permission View e Empty State

Sem mudanças — já estão adequados com o visual do sistema.

## Arquivos Afetados

| Arquivo | Mudanças |
|---------|----------|
| `Sources/CompositeView.swift` | Refatorar `WindowFrameView` (aceitar title/appIcon), refatorar grid (spacing), adicionar slim header, sombras, bordas, novo fundo, tratar células vazias |
| `Sources/ContentView.swift` | Refinamento do toolbar (ícone, badge), app group headers (uppercase, separator), window cards (bordas, hover, checkmark), footer (custom button style) |
| `Sources/WindowCaptureManager.swift` | Nenhuma mudança (lógica de captura inalterada) |
| `Sources/App.swift` | Nenhuma mudança |
| `Sources/AppDelegate.swift` | Nenhuma mudança |

## O Que Não Muda

- Lógica de captura (ScreenCaptureKit)
- Modelo de dados (WindowInfo, AppGroup)
- Número e tipo de janelas (2 windows: control + composite)
- Dimensões das janelas
- Textos e labels (permanecem em português)
- Permissão de tela e error handling
- Timer de refresh de previews
