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
    @Published private(set) var cropPreview: NSImage?
    @Published private(set) var cropSelection = CGRect(x: 0, y: 0, width: 1, height: 1)
    private var cropBase: EditState?
    private var cropRevision = 0
    var minimumCropSide: CGFloat { minimumSide(for: cropBase ?? edit) }
    private func minimumSide(for base: EditState) -> CGFloat { CGFloat(base.zoom / 8) }
    @Published var fullResolutionPreview = false { didSet { if oldValue != fullResolutionPreview { requestPreview() } } }
    @Published var errorMessage: String?
    @Published var status = L10n.text("Tutto sul tuo Mac. I tuoi originali restano intatti.")
    @Published var isLoading = false
    @Published var isExporting = false
    @Published var isRendering = false
    @Published var png = false
    @Published var jpegQuality = 0.95
    @Published var gridStyle: CompositionGrid = .thirds
    @Published var gridOpacity = 0.75
    @Published var showDestinationGuides = true
    @Published var showReplacementConfirmation = false
    @Published private(set) var pendingImageURL: URL?
    @Published private(set) var documentGeneration = 0
    var showGrid: Bool { gridStyle != .none }
    @Published private(set) var isAutoLeveling = false
    @Published private(set) var autoLevelMessage: String?
    private let estimateLevel: (ImageDocument, Preset, EditState) async throws -> AutoLevelSuggestion?
    /// Lettura del file, eseguita fuori dal MainActor. Iniettata perché i test contino le decodifiche.
    private let loadDocument: @Sendable (URL) throws -> ImageDocument

    init(estimateLevel: @escaping (ImageDocument, Preset, EditState) async throws -> AutoLevelSuggestion? = { document, preset, edit in
        try await Task.detached(priority: .userInitiated) {
            try AutoLevelEstimator().estimate(document: document, preset: preset, edit: edit)
        }.value
    }, loadDocument: @escaping @Sendable (URL) throws -> ImageDocument = { url in
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        return try ImageDocument(url: url)
    }) {
        self.estimateLevel = estimateLevel
        self.loadDocument = loadDocument
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
    private var pendingLoadURL: URL?
    private var revision = 0
    private let renderer = ImageRenderer()
    var canUndo: Bool { !isLoading && !undoStack.isEmpty }
    var canRedo: Bool { !isLoading && !redoStack.isEmpty }
    var imageDescription: String {
        guard let document else { return L10n.text("Nessuna immagine") }
        return "\(document.pixelWidth) × \(document.pixelHeight) px"
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

    /// Come l'anteprima (ADR-008), un unico worker decodifica l'ultima richiesta: una raffica
    /// di aperture (più file dal Finder) non avvia una decodifica per file. `Task.cancel()`
    /// non fermerebbe la decodifica già partita in un `Task.detached`.
    private func loadImage(_ url: URL) {
        revision += 1
        autoLevelMessage = nil
        isLoading = true
        status = L10n.format("Apertura di %@…", url.lastPathComponent)
        pendingLoadURL = url
        guard importTask == nil else { return }
        importTask = Task {
            defer { importTask = nil }
            while let url = pendingLoadURL {
                pendingLoadURL = nil
                await finishLoading(url)
            }
        }
    }

    private func finishLoading(_ url: URL) async {
        let loadDocument = loadDocument
        do {
            let loaded = try await Task.detached(priority: .userInitiated) { try loadDocument(url) }.value
            // Una richiesta più recente è in coda: questo risultato è già obsoleto.
            guard pendingLoadURL == nil else { return }
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
            guard pendingLoadURL == nil else { return }
            isLoading = false
            errorMessage = error.localizedDescription
            status = L10n.text("Impossibile aprire l’immagine.")
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
    /// L'inquadratura che la selezione `rect` (origine in basso a sinistra) produrrebbe
    /// applicando il ritaglio in corso; `nil` fuori dal ritaglio.
    func cropTarget(for rect: CGRect) -> EditState? {
        guard let document, let base = cropBase else { return nil }
        return try? renderer.cropped(document: document, preset: preset, edit: base, rect: rect)
    }

    /// Avvia il ritaglio sull'inquadratura corrente. Con `keeping` la selezione iniziale
    /// riproduce quell'inquadratura (per esempio quella trascinata prima di cambiare
    /// Livella) con la rotazione attuale, se entra nel nuovo contesto.
    func beginCrop(keeping target: EditState? = nil) {
        guard let document, !isLoading else { return }
        cropRevision += 1
        let token = cropRevision, generation = documentGeneration, original = edit, preset = preset
        guard let context = try? renderer.cropContext(document: document, preset: preset, edit: edit) else { return }
        var selection = context.selection
        if var target {
            target.straightenDegrees = edit.straightenDegrees
            target.quarterTurns = edit.quarterTurns
            // Il limite del pan con la nuova rotazione può spingere l'inquadratura fuori dal
            // contesto di una frazione: entro lo 0,5% la selezione si sposta dentro.
            let slack = 0.005
            if let clamped = try? renderer.panned(document: document, preset: preset, edit: target, translationX: 0, translationY: 0) {
                let r = renderer.selection(document: document, preset: preset, of: clamped, in: context.edit)
                if r.width <= 1, r.width >= minimumSide(for: context.edit),
                   r.minX >= -slack, r.minY >= -slack, r.maxX <= 1 + slack, r.maxY <= 1 + slack {
                    selection = CGRect(x: min(max(0, r.minX), 1 - r.width), y: min(max(0, r.minY), 1 - r.height),
                                       width: r.width, height: r.height)
                }
            }
        }
        cropBase = context.edit; cropPreview = nil; cropSelection = selection
        let renderer = renderer
        Task {
            do {
                let image = try await Task.detached(priority: .userInitiated) {
                    try renderer.render(document: document, preset: preset, edit: context.edit, maxPixelSize: 1400)
                }.value
                guard token == cropRevision, generation == documentGeneration, original == edit, preset == self.preset else { return }
                cropPreview = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            } catch { if token == cropRevision { errorMessage = error.localizedDescription } }
        }
    }
    func cancelCrop() { cropRevision += 1; cropBase = nil; cropPreview = nil }
    func applyCrop(_ rect: CGRect) {
        guard let document, let base = cropBase, let result = try? renderer.cropped(document: document, preset: preset, edit: base, rect: rect) else { return }
        if abs(result.zoom - edit.zoom) < 1e-9, abs(result.panX - edit.panX) < 1e-9, abs(result.panY - edit.panY) < 1e-9 { cancelCrop(); return }
        _ = applyGeometry(result)
        cancelCrop()
    }

    func setSharpening(_ value: OutputSharpening) {
        guard !isLoading, value != edit.outputSharpening else { return }
        checkpoint(); edit.outputSharpening = value
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
                let maxPixelSize: Int? = fullResolutionPreview ? nil : 1400
                do {
                    let image = try await Task.detached(priority: .userInitiated) {
                        try renderer.render(document: document, preset: preset, edit: edit, maxPixelSize: maxPixelSize)
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
                status = L10n.format("Esportato %@ · %@", url.lastPathComponent, preset.sizeDescription)
                isExporting = false
                afterSuccess?()
            } catch { errorMessage = error.localizedDescription }
            isExporting = false
        }
    }
}
