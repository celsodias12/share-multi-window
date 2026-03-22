import ScreenCaptureKit
import AppKit
import CoreImage

// MARK: - Window info model (decoupled from SCWindow)

struct WindowInfo: Identifiable {
    let id: CGWindowID
    let title: String
    let appName: String
    let bundleID: String?
    let frame: CGRect

    var appIcon: NSImage? {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path())
    }
}

// MARK: - App group for Discord-style grouping

struct AppGroup: Identifiable {
    let id: String // bundleID
    let name: String
    let icon: NSImage?
    var windows: [WindowInfo]
}

// MARK: - Manager

@MainActor
@Observable
final class WindowCaptureManager {
    var appGroups: [AppGroup] = []
    var allWindows: [WindowInfo] = []
    var selectedWindowIDs: Set<CGWindowID> = []
    var frames: [CGWindowID: NSImage] = [:]
    var previews: [CGWindowID: NSImage] = [:]
    var permissionError: String?
    /// A janela ativa (em foco) dentre as selecionadas. nil se nenhuma selecionada está em foco.
    var activeWindowID: CGWindowID?

    private var scWindows: [CGWindowID: SCWindow] = [:]
    private var streams: [CGWindowID: SCStream] = [:]
    private var outputs: [CGWindowID: StreamOutput] = [:]
    private var previewTimer: Timer?
    private var windowRefreshTimer: Timer?
    private var focusTimer: Timer?
    private let captureQueue = DispatchQueue(
        label: "com.sharemultiwindow.capture",
        qos: .userInteractive
    )

    // MARK: - Window enumeration

    func loadWindows() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
            let ownBundle = Bundle.main.bundleIdentifier

            // Filtrar apenas janelas normais (layer 0), como o Discord faz.
            // Layers != 0 sao menus, overlays, status bar, widgets, tooltips, etc.
            let systemBundles: Set<String> = [
                "com.apple.WindowManager",
                "com.apple.controlcenter",
                "com.apple.notificationcenterui",
                "com.apple.systemuiserver",
            ]

            let filtered = content.windows.filter { w in
                guard w.isOnScreen else { return false }
                guard w.windowLayer == 0 else { return false }
                guard let title = w.title, !title.isEmpty else { return false }
                guard w.frame.width > 100, w.frame.height > 100 else { return false }
                guard w.owningApplication?.bundleIdentifier != ownBundle else { return false }
                if let bid = w.owningApplication?.bundleIdentifier, systemBundles.contains(bid) {
                    return false
                }
                return true
            }

            // Map to WindowInfo and cache SCWindow refs
            scWindows.removeAll()
            allWindows = filtered.map { w in
                scWindows[w.windowID] = w
                return WindowInfo(
                    id: w.windowID,
                    title: w.title ?? "Sem título",
                    appName: w.owningApplication?.applicationName ?? "Desconhecido",
                    bundleID: w.owningApplication?.bundleIdentifier,
                    frame: w.frame
                )
            }

            // Group by app (Discord style)
            var groups: [String: AppGroup] = [:]
            for win in allWindows {
                let key = win.bundleID ?? win.appName
                if groups[key] == nil {
                    groups[key] = AppGroup(
                        id: key,
                        name: win.appName,
                        icon: win.appIcon,
                        windows: []
                    )
                }
                groups[key]?.windows.append(win)
            }
            appGroups = groups.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            permissionError = nil
            await refreshPreviews()
            startPreviewTimer()
            startWindowRefreshTimer()
        } catch {
            permissionError = "Permissão necessária: Ajustes do Sistema → Privacidade → Gravação de Tela"
        }
    }

    func stopSharing() {
        let ids = selectedWindowIDs
        selectedWindowIDs.removeAll()
        activeWindowID = nil
        frames.removeAll()
        focusTimer?.invalidate()
        focusTimer = nil
        for id in ids {
            if let stream = streams.removeValue(forKey: id) {
                Task { try? await stream.stopCapture() }
            }
            outputs.removeValue(forKey: id)
        }
    }

    func toggle(_ windowID: CGWindowID) async {
        if selectedWindowIDs.contains(windowID) {
            selectedWindowIDs.remove(windowID)
            await stopCapture(windowID)
            frames.removeValue(forKey: windowID)
            if activeWindowID == windowID {
                activeWindowID = selectedWindowIDs.first
            }
        } else {
            selectedWindowIDs.insert(windowID)
            await startCapture(windowID)
            if activeWindowID == nil {
                activeWindowID = windowID
            }
        }
    }

    // MARK: - Live previews (refreshed periodically like Discord)

    private func startPreviewTimer() {
        previewTimer?.invalidate()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshPreviews()
            }
        }
    }

    func stopPreviewTimer() {
        previewTimer?.invalidate()
        previewTimer = nil
        windowRefreshTimer?.invalidate()
        windowRefreshTimer = nil
        focusTimer?.invalidate()
        focusTimer = nil
    }

    // MARK: - Focus tracking

    func startFocusTracking() {
        focusTimer?.invalidate()
        focusTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateActiveWindow()
            }
        }
    }

    private func updateActiveWindow() {
        guard !selectedWindowIDs.isEmpty else {
            activeWindowID = nil
            return
        }

        // CGWindowListCopyWindowInfo retorna janelas ordenadas da frente para trás
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return }

        let ownBundleID = Bundle.main.bundleIdentifier

        for info in windowList {
            guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { continue }

            // Ignorar janelas do próprio app
            if let _ = info[kCGWindowOwnerName as String] as? String,
               let bid = allWindows.first(where: { $0.id == windowID })?.bundleID,
               bid == ownBundleID {
                continue
            }

            // A primeira janela selecionada encontrada (da frente para trás) é a ativa
            if selectedWindowIDs.contains(windowID) {
                if activeWindowID != windowID {
                    activeWindowID = windowID
                }
                return
            }
        }

        // Nenhuma janela selecionada está em foco — manter a última
    }

    private func startWindowRefreshTimer() {
        windowRefreshTimer?.invalidate()
        windowRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshWindowList()
            }
        }
    }

    /// Atualiza a lista de janelas sem perder seleções ou streams ativos.
    private func refreshWindowList() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
            let ownBundle = Bundle.main.bundleIdentifier

            let systemBundles: Set<String> = [
                "com.apple.WindowManager",
                "com.apple.controlcenter",
                "com.apple.notificationcenterui",
                "com.apple.systemuiserver",
            ]

            let filtered = content.windows.filter { w in
                guard w.isOnScreen else { return false }
                guard w.windowLayer == 0 else { return false }
                guard let title = w.title, !title.isEmpty else { return false }
                guard w.frame.width > 100, w.frame.height > 100 else { return false }
                guard w.owningApplication?.bundleIdentifier != ownBundle else { return false }
                if let bid = w.owningApplication?.bundleIdentifier, systemBundles.contains(bid) {
                    return false
                }
                return true
            }

            let currentIDs = Set(filtered.map { $0.windowID })
            let previousIDs = Set(allWindows.map { $0.id })

            // Só atualiza se houve mudança real
            guard currentIDs != previousIDs else { return }

            // Atualiza scWindows mantendo refs existentes
            var newSCWindows: [CGWindowID: SCWindow] = [:]
            let newWindows = filtered.map { w in
                newSCWindows[w.windowID] = w
                return WindowInfo(
                    id: w.windowID,
                    title: w.title ?? "Sem título",
                    appName: w.owningApplication?.applicationName ?? "Desconhecido",
                    bundleID: w.owningApplication?.bundleIdentifier,
                    frame: w.frame
                )
            }
            scWindows = newSCWindows
            allWindows = newWindows

            // Remove seleções de janelas que não existem mais
            let removedIDs = selectedWindowIDs.subtracting(currentIDs)
            for id in removedIDs {
                selectedWindowIDs.remove(id)
                await stopCapture(id)
                frames.removeValue(forKey: id)
                previews.removeValue(forKey: id)
            }

            // Reagrupa
            var groups: [String: AppGroup] = [:]
            for win in allWindows {
                let key = win.bundleID ?? win.appName
                if groups[key] == nil {
                    groups[key] = AppGroup(
                        id: key,
                        name: win.appName,
                        icon: win.appIcon,
                        windows: []
                    )
                }
                groups[key]?.windows.append(win)
            }
            appGroups = groups.values.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            await refreshPreviews()
        } catch {
            // Silently ignore — a próxima iteração tenta novamente
        }
    }

    private func refreshPreviews() async {
        let ciContext = CIContext(options: [.useSoftwareRenderer: false])

        for (windowID, scWindow) in scWindows {
            // Skip windows that have an active stream (they update via SCStream)
            if streams[windowID] != nil { continue }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            config.width = Int(min(scWindow.frame.width, 320))
            config.height = Int(min(scWindow.frame.height, 200))

            if let sampleBuffer = try? await SCScreenshotManager.captureSampleBuffer(
                contentFilter: filter, configuration: config
            ),
               let pixelBuffer = sampleBuffer.imageBuffer {
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                    previews[windowID] = NSImage(cgImage: cgImage, size: .zero)
                }
            }
        }
    }

    // MARK: - Capture lifecycle (full resolution for composite)

    private func startCapture(_ windowID: CGWindowID) async {
        guard let window = scWindows[windowID] else { return }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        config.queueDepth = 3
        config.showsCursor = false

        let output = StreamOutput { [weak self] nsImage in
            Task { @MainActor [weak self] in
                self?.frames[windowID] = nsImage
            }
        }

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)

        do {
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: captureQueue)
            try await stream.startCapture()
            streams[windowID] = stream
            outputs[windowID] = output
        } catch {
            selectedWindowIDs.remove(windowID)
            print("Erro ao capturar janela \(windowID): \(error)")
        }
    }

    private func stopCapture(_ windowID: CGWindowID) async {
        if let stream = streams.removeValue(forKey: windowID) {
            try? await stream.stopCapture()
        }
        outputs.removeValue(forKey: windowID)
    }
}

// MARK: - SCStreamOutput bridge

final class StreamOutput: NSObject, SCStreamOutput {
    private let onFrame: (NSImage) -> Void
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    init(onFrame: @escaping (NSImage) -> Void) {
        self.onFrame = onFrame
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let nsImage = NSImage(cgImage: cgImage, size: .zero)
        onFrame(nsImage)
    }
}
