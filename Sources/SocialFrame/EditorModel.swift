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
    @Published var status = L10n.text("Tutto sul tuo Mac. I tuoi originali restano intatti.")
    @Published var isLoading = false
    @Published var isExporting = false
    @Published var isRendering = false
    @Published var png = false
    @Published var jpegQuality = 0.95
    @Published var gridStyle: CompositionGrid = .thirds
    @Published var gridOpacity = 0.55
    @Published var showDestinationGuides = true
    @Published var showReplacementConfirmation = false
    @Published private(set) var pendingImageURL: URL?
    @Published private(set) var documentGeneration = 0
    var showGrid: Bool { gridStyle != .none }
    @Published private(set) var isAutoLeveling = false
    @Published private(set) var autoLevelMessage: String?
    private let estimateLevel: (ImageDocument, Preset, EditState) async throws -> AutoLevelSuggestion?

    init(estimateLevel: @escaping (ImageDocument, Preset, EditState) async throws -> AutoLevelSuggestion? = { document, preset, edit in
        try await Task.detached(priority: .userInitiated) {
            try AutoLevelEstimator().estimate(document: document, preset: preset, edit: edit)
        }.value
    }) {
        self.estimateLevel = estimateLevel
    }
    private struct Snapshot: Equatable { let edit: EditState; let preset: Preset }
    @Published private var undoStack: [Snapshot] = []
    @Published private var redoStack: [Snapshot] = []
    @Published private var preservedSnapshot: Snapshot?
    var hasUnexportedChanges: Bool {
        document != nil && Snapshot(edit: edit, preset: preset) != preservedSnapshot
    }
    private var previewTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var revision = 0
    private let renderer = ImageRenderer()
    var canUndo: Bool { !isLoading && !undoStack.isEmpty }
    var canRedo: Bool { !isLoading && !redoStack.isEmpty }
    var imageDescription: String {
        guard let document else { return L10n.text("Nessuna immagine") }
        return L10n.format("%d × %d px", document.pixelWidth, document.pixelHeight)
    }

    func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.text("Apri immagine")
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
        if hasUnexportedChanges {
            pendingImageURL = url
            showReplacementConfirmation = true
            return
        }
        loadImage(url)
    }

    func cancelReplacement() {
        pendingImageURL = nil
        showReplacementConfirmation = false
    }

    func discardAndOpenPendingImage() {
        guard let url = pendingImageURL else { return }
        cancelReplacement()
        loadImage(url)
    }

    func exportAndOpenPendingImage() {
        showReplacementConfirmation = false
        let requestedURL = pendingImageURL
        showExportPanel { [weak self] in
            guard let self, self.pendingImageURL == requestedURL else { return }
            if !self.hasUnexportedChanges {
                self.discardAndOpenPendingImage()
            } else {
                // Edits made while exporting have not been preserved in that copy.
                self.showReplacementConfirmation = true
            }
        }
    }

    private func loadImage(_ url: URL) {
        importTask?.cancel()
        revision += 1
        autoLevelMessage = nil
        isLoading = true
        status = L10n.format("Apertura di %@…", url.lastPathComponent)
        importTask = Task {
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    return try ImageDocument(url: url)
                }.value
                guard !Task.isCancelled else { return }
                document = loaded
                documentGeneration += 1
                sourceURL = url
                undoStack = []; redoStack = []
                edit = EditState()
                preservedSnapshot = Snapshot(edit: edit, preset: preset)
                preview = nil
                isLoading = false
                status = L10n.format("Originale caricato · %@", imageDescription)
                requestPreview()
            } catch {
                guard !Task.isCancelled else { return }
                isLoading = false
                errorMessage = error.localizedDescription
                status = L10n.text("Impossibile aprire l’immagine.")
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
        guard !isLoading else { return }
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(Snapshot(edit: edit, preset: preset)); preset = previous.preset; edit = previous.edit
    }
    func redo() {
        guard !isLoading else { return }
        guard let next = redoStack.popLast() else { return }
        undoStack.append(Snapshot(edit: edit, preset: preset)); preset = next.preset; edit = next.edit
    }
    func selectPreset(_ newPreset: Preset) {
        guard !isLoading, preset != newPreset else { return }
        checkpoint()
        clearCloneStrokes()
        preset = newPreset
    }
    func reset() { guard !isLoading else { return }; checkpoint(); edit = EditState() }
    func rotate() { guard !isLoading else { return }; checkpoint(); clearCloneStrokes(); edit.quarterTurns = (edit.quarterTurns + 1) % 4 }

    @discardableResult
    func setZoom(_ value: Double, recordUndo: Bool = true) -> Bool {
        guard value.isFinite else { return false }
        var adjusted = edit
        adjusted.zoom = min(8, max(1, value))
        return applyGeometry(adjusted, recordUndo: recordUndo)
    }

    @discardableResult
    func setStraighten(_ value: Double, recordUndo: Bool = true) -> Bool {
        guard value.isFinite else { return false }
        var adjusted = edit
        adjusted.straightenDegrees = min(45, max(-45, value))
        return applyGeometry(adjusted, recordUndo: recordUndo)
    }

    @discardableResult
    private func applyGeometry(_ adjusted: EditState, recordUndo: Bool = true) -> Bool {
        guard !isLoading else { return false }
        var adjusted = adjusted
        // The pan helper returns cleared stamps even if it clamps to the same
        // position. Only an actual geometry change should invalidate them.
        adjusted.cloneStrokes = edit.cloneStrokes
        guard adjusted != edit else { return false }
        if recordUndo { checkpoint() }
        adjusted.cloneStrokes = []
        edit = adjusted
        return true
    }

    func nudge(horizontal: Double, vertical: Double) {
        guard let document,
              let adjusted = try? renderer.panned(document: document, preset: preset, edit: edit,
                  translationX: horizontal, translationY: vertical) else { return }
        applyGeometry(adjusted)
    }

    func pan(from origin: EditState, translationX: Double, translationY: Double) {
        guard !isLoading, let document else { return }
        if let panned = try? renderer.panned(document: document, preset: preset, edit: origin,
                                            translationX: translationX, translationY: translationY) {
            edit = panned
        }
    }

    func clearCloneStrokes() { if !isLoading && !edit.cloneStrokes.isEmpty { edit.cloneStrokes = [] } }
    func addClone(source: CGPoint, target: CGPoint, radius: Double) {
        guard !isLoading else { return }
        checkpoint()
        edit.cloneStrokes.append(CloneStroke(sourceX: source.x, sourceY: source.y, targetX: target.x, targetY: target.y, radius: radius))
    }

    func autoLevel() {
        guard let document, !isAutoLeveling, !isLoading else { return }
        let preset = preset, edit = edit, requestedRevision = revision
        isAutoLeveling = true
        autoLevelMessage = L10n.text("Analisi dell’orizzonte…")
        Task {
            defer { isAutoLeveling = false }
            do {
                let suggestion = try await estimateLevel(document, preset, edit)
                guard self.document === document, revision == requestedRevision, !isLoading else {
                    autoLevelMessage = L10n.text("Inquadratura cambiata: ripeti l’autolivellamento.")
                    return
                }
                guard let suggestion, suggestion.straightenDegrees.isFinite,
                      (-45...45).contains(suggestion.straightenDegrees),
                      suggestion.confidence.isFinite, suggestion.confidence >= 0.6 else {
                    autoLevelMessage = L10n.text("Orizzonte non riconosciuto con sufficiente affidabilità. Usa Livella.")
                    return
                }
                guard abs(suggestion.straightenDegrees - self.edit.straightenDegrees) >= 0.05 else {
                    autoLevelMessage = L10n.text("L’immagine risulta già livellata.")
                    return
                }
                checkpoint()
                var adjusted = self.edit
                adjusted.cloneStrokes = []
                adjusted.straightenDegrees = suggestion.straightenDegrees
                self.edit = adjusted
                autoLevelMessage = L10n.format("Livellamento applicato: %.1f°. Puoi annullare con ⌘Z.", suggestion.straightenDegrees)
            } catch {
                guard self.document === document, revision == requestedRevision else { return }
                autoLevelMessage = L10n.text("Analisi non disponibile. Usa Livella per la correzione manuale.")
            }
        }
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
        showExportPanel()
    }

    private func showExportPanel(afterSuccess: (() -> Void)? = nil) {
        guard document != nil, !isExporting, !isLoading else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = png ? [.png] : [.jpeg]
        let name = sourceURL?.deletingPathExtension().lastPathComponent ?? L10n.text("Immagine")
        panel.nameFieldStringValue = "\(name)-\(preset.id).\(png ? "png" : "jpg")"
        panel.prompt = L10n.text("Esporta")
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            if response == .OK, let url = panel.url { self?.export(to: url, afterSuccess: afterSuccess) }
        }
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    func export(to url: URL, afterSuccess: (() -> Void)? = nil) {
        guard let document, !isExporting, !isLoading else { return }
        if let sourceURL, url.standardizedFileURL.resolvingSymlinksInPath() == sourceURL.standardizedFileURL.resolvingSymlinksInPath() {
            errorMessage = L10n.text("Scegli un nome diverso: l’originale deve restare intatto.")
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
                if self.document === document {
                    preservedSnapshot = Snapshot(edit: edit, preset: preset)
                }
                status = L10n.format("Esportato %@ · %d × %d px", url.lastPathComponent, preset.width, preset.height)
                isExporting = false
                afterSuccess?()
            } catch { errorMessage = error.localizedDescription }
            isExporting = false
        }
    }
}
