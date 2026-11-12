import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SocialCore

@MainActor
final class EditorModel: ObservableObject {
    @Published var document: ImageDocument?
    @Published var sourceURL: URL?
    @Published var preset = Preset.all[0] { didSet { requestPreview() } }
    @Published var edit = EditState() { didSet { requestPreview() } }
    @Published var preview: NSImage?
    @Published var errorMessage: String?
    @Published var status = "Tutto sul tuo Mac. I tuoi originali restano intatti."
    @Published var isLoading = false
    @Published var isExporting = false
    @Published var isRendering = false
    @Published var png = false
    @Published var jpegQuality = 0.95
    @Published var showGrid = true
    private struct Snapshot: Equatable { let edit: EditState; let preset: Preset }
    @Published private var undoStack: [Snapshot] = []
    @Published private var redoStack: [Snapshot] = []
    private var previewTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var revision = 0
    private let renderer = ImageRenderer()
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var imageDescription: String {
        guard let document else { return "Nessuna immagine" }
        return "\(document.pixelWidth) × \(document.pixelHeight) px"
    }

    func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Apri immagine"
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            if response == .OK, let url = panel.url { self?.open(url) }
        }
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    func open(_ url: URL) {
        importTask?.cancel()
        isLoading = true
        status = "Apertura di \(url.lastPathComponent)…"
        importTask = Task {
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    return try ImageDocument(url: url)
                }.value
                guard !Task.isCancelled else { return }
                document = loaded
                sourceURL = url
                undoStack = []; redoStack = []
                edit = EditState()
                preview = nil
                isLoading = false
                status = "Originale caricato · \(imageDescription)"
                requestPreview()
            } catch {
                guard !Task.isCancelled else { return }
                isLoading = false
                errorMessage = error.localizedDescription
                status = "Impossibile aprire l’immagine."
            }
        }
    }

    func checkpoint() {
        let snapshot = Snapshot(edit: edit, preset: preset)
        if undoStack.last != snapshot { undoStack.append(snapshot) }
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack = []
    }
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(Snapshot(edit: edit, preset: preset)); preset = previous.preset; edit = previous.edit
    }
    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(Snapshot(edit: edit, preset: preset)); preset = next.preset; edit = next.edit
    }
    func selectPreset(_ newPreset: Preset) {
        guard preset != newPreset else { return }
        checkpoint()
        clearCloneStrokes()
        preset = newPreset
    }
    func reset() { checkpoint(); edit = EditState() }
    func rotate() { checkpoint(); clearCloneStrokes(); edit.quarterTurns = (edit.quarterTurns + 1) % 4 }

    func pan(from origin: EditState, translationX: Double, translationY: Double) {
        guard let document else { return }
        if let panned = try? renderer.panned(document: document, preset: preset, edit: origin,
                                            translationX: translationX, translationY: translationY) {
            edit = panned
        }
    }

    func clearCloneStrokes() { if !edit.cloneStrokes.isEmpty { edit.cloneStrokes = [] } }
    func addClone(source: CGPoint, target: CGPoint, radius: Double) {
        checkpoint()
        edit.cloneStrokes.append(CloneStroke(sourceX: source.x, sourceY: source.y, targetX: target.x, targetY: target.y, radius: radius))
    }

    func requestPreview() {
        revision += 1
        // A single worker drains the latest state. Never debounce or cancel a
        // useful frame because the next slider event arrived while rendering.
        guard document != nil, previewTask == nil else { return }
        isRendering = true
        previewTask = Task {
            defer { previewTask = nil; isRendering = false }
            while let document = self.document {
                let requestedRevision = revision
                let preset = self.preset, edit = self.edit, renderer = renderer
                do {
                    let image = try await Task.detached(priority: .userInitiated) {
                        try renderer.render(document: document, preset: preset, edit: edit, maxPixelSize: 1400)
                    }.value
                    // Intermediate edits are useful during a continuous gesture;
                    // a frame from a different document or preset is never shown.
                    if self.document === document, self.preset == preset {
                        preview = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                    }
                } catch {
                    if revision == requestedRevision { errorMessage = error.localizedDescription }
                }
                if revision == requestedRevision { break }
            }
        }
    }

    func export() {
        guard document != nil, !isExporting else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = png ? [.png] : [.jpeg]
        let name = sourceURL?.deletingPathExtension().lastPathComponent ?? "Immagine"
        panel.nameFieldStringValue = "\(name)-\(preset.id).\(png ? "png" : "jpg")"
        panel.prompt = "Esporta"
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            if response == .OK, let url = panel.url { self?.export(to: url) }
        }
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    func export(to url: URL) {
        guard let document, !isExporting else { return }
        if let sourceURL, url.standardizedFileURL.resolvingSymlinksInPath() == sourceURL.standardizedFileURL.resolvingSymlinksInPath() {
            errorMessage = "Scegli un nome diverso: l’originale deve restare intatto."
            return
        }
        let preset = preset, edit = edit, renderer = renderer
        let format: ExportFormat = png ? .png : .jpeg(quality: jpegQuality)
        isExporting = true
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try renderer.export(document: document, preset: preset, edit: edit, format: format, to: url)
                }.value
                status = "Esportato \(url.lastPathComponent) · \(preset.width) × \(preset.height) px"
            } catch { errorMessage = error.localizedDescription }
            isExporting = false
        }
    }
}
