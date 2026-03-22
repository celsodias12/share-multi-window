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

    private var scWindows: [CGWindowID: SCWindow] = [:]
    private var streams: [CGWindowID: SCStream] = [:]
    private var outputs: [CGWindowID: StreamOutput] = [:]
    private var previewTimer: Timer?
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

            let filtered = content.windows.filter { w in
                guard w.isOnScreen else { return false }
                guard let title = w.title, !title.isEmpty else { return false }
                guard w.frame.width > 50, w.frame.height > 50 else { return false }
                return w.owningApplication?.bundleIdentifier != ownBundle
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
        } catch {
            permissionError = "Permissão necessária: Ajustes do Sistema → Privacidade → Gravação de Tela"
        }
    }

    func toggle(_ windowID: CGWindowID) async {
        if selectedWindowIDs.contains(windowID) {
            selectedWindowIDs.remove(windowID)
            await stopCapture(windowID)
            frames.removeValue(forKey: windowID)
        } else {
            selectedWindowIDs.insert(windowID)
            await startCapture(windowID)
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
