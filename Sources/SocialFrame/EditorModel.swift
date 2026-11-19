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
    /// File in attesa della scelta Aggiungi/Sostituisci o della conferma di sostituzione.
    @Published private(set) var pendingImportURLs: [URL] = []
    @Published var showImportChoice = false
    @Published private(set) var isImporting = false
    /// Set di foto in memoria (F-11) e foto attiva nell'editor.
    @Published private(set) var items: [PhotoItem] = []
    @Published private(set) var selectedItemID: PhotoItem.ID?
    @Published var showRemovalConfirmation = false
    @Published private(set) var pendingRemovalID: PhotoItem.ID?
    @Published var showExportConflicts = false
    @Published private(set) var pendingExportAll: PendingExportAll?
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
    private typealias Snapshot = EditorSnapshot
    struct PendingExportAll {
        let folder: URL
        let conflictCount: Int
        let afterSuccess: (() -> Void)?
    }
    @Published private var undoStack: [Snapshot] = []
    @Published private var redoStack: [Snapshot] = []
    @Published private var preservedSnapshot: Snapshot?
    @Published private var exportedSnapshot: Snapshot?
    var hasUnexportedChanges: Bool {
        document != nil && Snapshot(edit: edit, preset: preset) != preservedSnapshot
    }
    private var previewTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var selectTask: Task<Void, Never>?
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
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = L10n.text("Apri")
        panel.message = L10n.text("Scegli una o più foto, oppure una cartella.")
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            if response == .OK { self?.open(panel.urls) }
        }
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    func open(_ url: URL) { open([url]) }

    /// Importa file o cartelle. Con un set già aperto chiede se aggiungere o sostituire.
    func open(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if items.isEmpty {
            startImport(urls, mode: .replace)
        } else {
            pendingImportURLs = urls
            showImportChoice = true
        }
    }

    func addPendingImport() {
        let urls = pendingImportURLs
        guard !urls.isEmpty else { return }
        startImport(urls, mode: .append)
    }

    func replaceSetWithPendingImport() {
        guard !pendingImportURLs.isEmpty else { return }
        showImportChoice = false
        if hasUnexportedItems {
            showReplacementConfirmation = true
        } else {
            startImport(pendingImportURLs, mode: .replace)
        }
    }

    func cancelReplacement() {
        pendingImportURLs = []
        showImportChoice = false
        showReplacementConfirmation = false
    }

    func discardAndOpenPendingImage() {
        let urls = pendingImportURLs
        guard !urls.isEmpty else { return }
        startImport(urls, mode: .replace)
    }

    func exportAndOpenPendingImage() {
        showReplacementConfirmation = false
        let requested = pendingImportURLs
        let afterSuccess: () -> Void = { [weak self] in
            guard let self, self.pendingImportURLs == requested else { return }
            if !self.hasUnexportedItems {
                self.discardAndOpenPendingImage()
            } else {
                // Modifiche fatte durante l'esportazione non sono in quelle copie.
                self.showReplacementConfirmation = true
            }
        }
        if items.count > 1 {
            chooseExportFolder(afterSuccess: afterSuccess)
        } else {
            showExportPanel(afterSuccess: afterSuccess)
        }
    }

    /// Decodifica i file uno alla volta fuori dal MainActor: aggiunge al set quelli
    /// leggibili con la loro miniatura e attiva il primo. Con `.replace` il set
    /// precedente resta intatto finché almeno un file non è stato aperto (F-01).
    private func startImport(_ urls: [URL], mode: ImportMode) {
        importTask?.cancel()
        pendingImportURLs = []
        showImportChoice = false
        showReplacementConfirmation = false
        isImporting = true
        isLoading = mode == .replace || selectTask != nil
        if mode == .replace { autoLevelMessage = nil }
        status = urls.count == 1 ? L10n.format("Apertura di %@…", urls[0].lastPathComponent) : L10n.text("Importazione…")
        let existing = mode == .append ? Set(items.map { ExportPlan.fileKey($0.url) }) : []
        let renderer = renderer
        importTask = Task {
            let files = await Task.detached(priority: .userInitiated) { PhotoImport.expand(urls) }.value
            guard !Task.isCancelled else { return }
            var seen = existing
            var failures: [(name: String, message: String)] = []
            var added = 0, duplicates = 0
            var activated = false
            for (index, url) in files.enumerated() {
                guard seen.insert(ExportPlan.fileKey(url)).inserted else { duplicates += 1; continue }
                if files.count > 1 { status = L10n.format("Importazione %d di %d…", index + 1, files.count) }
                let preset = self.preset
                do {
                    let (document, thumbnail) = try await Task.detached(priority: .userInitiated) { () throws -> (ImageDocument, CGImage?) in
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let document = try ImageDocument(url: url)
                        let rendered = try? renderer.render(document: document, preset: preset, edit: EditState(), maxPixelSize: 320)
                        return (document, rendered.flatMap { PhotoImport.thumbnail(from: $0) })
                    }.value
                    guard !Task.isCancelled else { return }
                    if mode == .replace && !activated {
                        // Il vecchio set lascia l'editor solo ora che c'è una foto valida.
                        items = []; selectedItemID = nil
                    }
                    var item = PhotoItem(url: url, preset: preset)
                    item.thumbnail = thumbnail.map { NSImage(thumbnail: $0) }
                    items.append(item)
                    added += 1
                    if !activated {
                        activated = true
                        selectTask?.cancel(); selectTask = nil
                        activate(item, document: document)
                        isLoading = false
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    failures.append((name: url.lastPathComponent, message: error.localizedDescription))
                }
            }
            isImporting = false
            if !activated { isLoading = false }
            if files.isEmpty {
                errorMessage = L10n.text("Nessuna immagine trovata.")
            } else if files.count == 1, let failure = failures.first {
                errorMessage = failure.message
            } else if !failures.isEmpty {
                errorMessage = L10n.format("%d file non importati:", failures.count) + "\n"
                    + failures.map { $0.name + ": " + $0.message }.joined(separator: "\n")
            }
            if added == 0 {
                status = duplicates > 0 && failures.isEmpty ? L10n.text("Le foto scelte sono già nel set.")
                    : L10n.text("Impossibile aprire l’immagine.")
            } else if items.count > 1 {
                status = L10n.format("Foto nel set: %d · aggiunte: %d", items.count, added)
            }
        }
    }

    // MARK: - Set di foto

    var selectedIndex: Int? { items.firstIndex { $0.id == selectedItemID } }
    var canSelectPrevious: Bool { (selectedIndex ?? 0) > 0 }
    var canSelectNext: Bool { selectedIndex.map { $0 < items.count - 1 } ?? false }

    func photoStatus(of item: PhotoItem) -> PhotoStatus {
        if item.id == selectedItemID {
            return .of(current: Snapshot(edit: edit, preset: preset), preserved: preservedSnapshot, exported: exportedSnapshot)
        }
        return .of(current: item.snapshot, preserved: item.preservedSnapshot, exported: item.exportedSnapshot)
    }

    /// Foto con modifiche non esportate in tutto il set (o la foto aperta senza set).
    var hasUnexportedItems: Bool {
        items.isEmpty ? hasUnexportedChanges : items.contains { photoStatus(of: $0) == .edited }
    }

    func selectPrevious() { if let index = selectedIndex, index > 0 { select(items[index - 1].id) } }
    func selectNext() { if let index = selectedIndex, index < items.count - 1 { select(items[index + 1].id) } }

    /// Apre nell'editor una foto del set, conservando modifiche e cronologia di quella
    /// lasciata. Nessuna conferma: nulla va perso.
    func select(_ id: PhotoItem.ID) {
        guard id != selectedItemID, let item = items.first(where: { $0.id == id }) else { return }
        selectTask?.cancel()
        isLoading = true
        status = L10n.format("Apertura di %@…", item.url.lastPathComponent)
        let url = item.url
        selectTask = Task {
            do {
                let document = try await Task.detached(priority: .userInitiated) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    return try ImageDocument(url: url)
                }.value
                guard !Task.isCancelled else { return }
                selectTask = nil
                isLoading = false
                // La foto può essere stata rimossa mentre si apriva.
                guard let current = items.first(where: { $0.id == id }) else { return }
                activate(current, document: document)
            } catch {
                guard !Task.isCancelled else { return }
                selectTask = nil
                isLoading = false
                errorMessage = error.localizedDescription
                status = L10n.text("Impossibile aprire l’immagine.")
                if document == nil || items.first(where: { $0.id == selectedItemID }) == nil { clearEditor() }
            }
        }
    }

    /// Salva lo stato dell'editor nella foto attiva del set.
    private func stashActive() {
        guard let index = selectedIndex else { return }
        items[index].edit = edit
        items[index].preset = preset
        items[index].undoStack = undoStack
        items[index].redoStack = redoStack
        if let preservedSnapshot { items[index].preservedSnapshot = preservedSnapshot }
        items[index].exportedSnapshot = exportedSnapshot
    }

    private func activate(_ item: PhotoItem, document: ImageDocument) {
        stashActive()
        cancelCrop()
        revision += 1
        self.document = document
        documentGeneration += 1
        sourceURL = item.url
        selectedItemID = item.id
        undoStack = item.undoStack
        redoStack = item.redoStack
        preset = item.preset
        edit = item.edit
        preservedSnapshot = item.preservedSnapshot
        exportedSnapshot = item.exportedSnapshot
        preview = nil
        autoLevelMessage = nil
        status = L10n.format("Originale caricato · %@", imageDescription)
        requestPreview()
    }

    private func clearEditor() {
        revision += 1
        cancelCrop()
        document = nil
        documentGeneration += 1
        sourceURL = nil
        selectedItemID = nil
        undoStack = []; redoStack = []
        edit = EditState()
        preservedSnapshot = nil; exportedSnapshot = nil
        preview = nil
        autoLevelMessage = nil
        status = L10n.text("Tutto sul tuo Mac. I tuoi originali restano intatti.")
    }

    /// Chiede conferma solo se la foto ha modifiche non esportate.
    func requestRemoval(of id: PhotoItem.ID) {
        guard !isExporting, let item = items.first(where: { $0.id == id }) else { return }
        if photoStatus(of: item) == .edited {
            pendingRemovalID = id
            showRemovalConfirmation = true
        } else {
            remove(id)
        }
    }

    func confirmRemoval() {
        showRemovalConfirmation = false
        if let id = pendingRemovalID { remove(id) }
        pendingRemovalID = nil
    }

    func cancelRemoval() {
        showRemovalConfirmation = false
        pendingRemovalID = nil
    }

    /// Toglie la foto dal set; il file su disco non viene toccato.
    func remove(_ id: PhotoItem.ID) {
        guard !isExporting, let index = items.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = id == selectedItemID
        items.remove(at: index)
        guard wasSelected else { return }
        selectTask?.cancel(); selectTask = nil
        // La foto rimossa non va salvata: si lascia l'editor senza selezione.
        selectedItemID = nil
        if items.isEmpty {
            isLoading = false
            clearEditor()
        } else {
            select(items[min(index, items.count - 1)].id)
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
                    let (image, thumbnail) = try await Task.detached(priority: .userInitiated) { () throws -> (CGImage, CGImage?) in
                        let image = try renderer.render(document: document, preset: preset, edit: edit, maxPixelSize: maxPixelSize)
                        return (image, PhotoImport.thumbnail(from: image))
                    }.value
                    // Intermediate edits are useful during a continuous gesture;
                    // a frame from a different document or preset is never shown.
                    if self.document === document, self.preset == preset {
                        preview = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                        // La miniatura della pellicola segue l'ultimo frame mostrato.
                        if revision == requestedRevision, let thumbnail, let index = selectedIndex {
                            items[index].thumbnail = NSImage(thumbnail: thumbnail)
                        }
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
        if protectedOriginals.contains(ExportPlan.fileKey(url)) {
            errorMessage = L10n.text("Scegli un nome diverso: l’originale deve restare intatto.")
            return
        }
        let preset = preset, edit = edit, renderer = renderer, itemID = selectedItemID
        let format: ExportFormat = png ? .png : .jpeg(quality: jpegQuality)
        isExporting = true
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try renderer.export(document: document, preset: preset, edit: edit, format: format, to: url)
                }.value
                if let itemID {
                    markExported(itemID, Snapshot(edit: edit, preset: preset))
                } else if self.document === document {
                    preservedSnapshot = Snapshot(edit: edit, preset: preset)
                    exportedSnapshot = preservedSnapshot
                }
                status = L10n.format("Esportato %@ · %@", url.lastPathComponent, preset.sizeDescription)
                isExporting = false
                afterSuccess?()
            } catch { errorMessage = error.localizedDescription }
            isExporting = false
        }
    }

    // MARK: - Esporta tutto (F-13)

    /// Originali del set e foto aperta: non si sovrascrivono mai.
    private var protectedOriginals: Set<String> {
        Set((items.map(\.url) + [sourceURL].compactMap { $0 }).map(ExportPlan.fileKey))
    }

    private func markExported(_ id: PhotoItem.ID, _ snapshot: Snapshot) {
        if id == selectedItemID {
            preservedSnapshot = snapshot
            exportedSnapshot = snapshot
        } else if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].preservedSnapshot = snapshot
            items[index].exportedSnapshot = snapshot
        }
    }

    var canExportAll: Bool { !items.isEmpty && !isExporting && !isLoading && !isImporting }

    func exportAll() { chooseExportFolder() }

    private func chooseExportFolder(afterSuccess: (() -> Void)? = nil) {
        guard canExportAll else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.text("Esporta qui")
        panel.message = L10n.format("Esporta %d foto, ciascuna con il proprio formato social.", items.count)
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            if response == .OK, let url = panel.url { self?.exportAll(to: url, afterSuccess: afterSuccess) }
        }
        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    private var exportRequests: [ExportPlan.Request] {
        items.map { item in
            ExportPlan.Request(itemID: item.id, source: item.url,
                               preset: item.id == selectedItemID ? preset : item.preset)
        }
    }

    private var exportExtension: String { png ? "png" : "jpg" }

    /// Esporta tutte le foto nella cartella. Senza `resolution`, se esistono già file
    /// con gli stessi nomi chiede una sola volta se sostituirli o mantenerli entrambi.
    func exportAll(to folder: URL, resolution: ExportConflictResolution? = nil, afterSuccess: (() -> Void)? = nil) {
        guard canExportAll else { return }
        let fileExists = { (url: URL) in FileManager.default.fileExists(atPath: url.path) }
        if resolution == nil {
            let conflicts = ExportPlan.conflictCount(for: exportRequests, in: folder, fileExtension: exportExtension,
                                                     protected: protectedOriginals, fileExists: fileExists)
            if conflicts > 0 {
                pendingExportAll = PendingExportAll(folder: folder, conflictCount: conflicts, afterSuccess: afterSuccess)
                showExportConflicts = true
                return
            }
        }
        stashActive()
        let entries = ExportPlan.destinations(for: exportRequests, in: folder, fileExtension: exportExtension,
                                              resolution: resolution ?? .keepBoth, protected: protectedOriginals,
                                              fileExists: fileExists)
        // Lo stato di ogni foto si fissa ora: modifiche successive non entrano in queste copie.
        let jobs: [(entry: ExportPlan.Entry, item: PhotoItem, document: ImageDocument?)] = entries.compactMap { entry in
            guard let item = items.first(where: { $0.id == entry.itemID }) else { return nil }
            return (entry: entry, item: item, document: item.id == selectedItemID ? document : nil)
        }
        let originals = items.map(\.url)
        let format: ExportFormat = png ? .png : .jpeg(quality: jpegQuality)
        let renderer = renderer
        isExporting = true
        Task {
            var failures: [String] = []
            var exported = 0
            for (index, job) in jobs.enumerated() {
                status = L10n.format("Esportazione %d di %d…", index + 1, jobs.count)
                let source = job.item.url, edit = job.item.edit, preset = job.item.preset
                let destination = job.entry.destination, loaded = job.document
                do {
                    try await Task.detached(priority: .userInitiated) {
                        // Anche un hard link a un altro originale del set va protetto.
                        if FileManager.default.fileExists(atPath: destination.path) {
                            let target = try? destination.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject
                            for original in originals {
                                let id = try? original.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject
                                if let target, let id, target == id { throw SocialCoreError.wouldOverwriteOriginal }
                            }
                        }
                        let access = source.startAccessingSecurityScopedResource()
                        defer { if access { source.stopAccessingSecurityScopedResource() } }
                        let document = try loaded ?? ImageDocument(url: source)
                        try renderer.export(document: document, preset: preset, edit: edit, format: format, to: destination)
                    }.value
                    markExported(job.item.id, Snapshot(edit: edit, preset: preset))
                    exported += 1
                } catch {
                    failures.append(source.lastPathComponent + ": " + error.localizedDescription)
                }
            }
            isExporting = false
            status = L10n.format("Esportate %d foto su %d in %@", exported, jobs.count, folder.lastPathComponent)
            if failures.isEmpty {
                afterSuccess?()
            } else {
                errorMessage = L10n.format("%d foto non esportate:", failures.count) + "\n" + failures.joined(separator: "\n")
            }
        }
    }

    func resolveExportConflicts(_ resolution: ExportConflictResolution) {
        showExportConflicts = false
        guard let pending = pendingExportAll else { return }
        pendingExportAll = nil
        exportAll(to: pending.folder, resolution: resolution, afterSuccess: pending.afterSuccess)
    }

    func cancelExportAll() {
        showExportConflicts = false
        pendingExportAll = nil
    }
}
