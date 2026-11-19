import SwiftUI
import Combine
import SocialCore

/// Solo ciò che decide titoli e disabilitazione dei menu. I comandi osservavano l'intero
/// `EditorModel`: ogni evento di trascinamento e ogni fotogramma dell'anteprima ricostruivano
/// la scena e la barra dei menu. Ora si pubblica solo quando questi valori cambiano.
@MainActor
final class EditorMenuState: ObservableObject {
    struct Values: Equatable {
        var hasDocument = false, isLoading = false, isExporting = false
        var canUndo = false, canRedo = false, isAutoLeveling = false
        var canExportAll = false, canSelectPrevious = false, canSelectNext = false, hasSelection = false
        var gridStyle = CompositionGrid.thirds
    }
    @Published private(set) var values = Values()
    private var observation: AnyCancellable?

    init(model: EditorModel) {
        values = Self.values(of: model)
        // `objectWillChange` precede la modifica: la lettura avviene al giro successivo.
        observation = model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak model] _ in
                guard let self, let model else { return }
                let current = Self.values(of: model)
                if current != self.values { self.values = current }
            }
    }

    private static func values(of model: EditorModel) -> Values {
        Values(hasDocument: model.document != nil, isLoading: model.isLoading, isExporting: model.isExporting,
               canUndo: model.canUndo, canRedo: model.canRedo, isAutoLeveling: model.isAutoLeveling,
               canExportAll: model.canExportAll, canSelectPrevious: model.canSelectPrevious,
               canSelectNext: model.canSelectNext, hasSelection: model.selectedItemID != nil,
               gridStyle: model.gridStyle)
    }
}

/// Ogni comando della toolbar esiste anche nella barra dei menu, perché la
/// toolbar si può personalizzare o nascondere. Le condizioni di disabilitazione
/// coincidono con quelle dei controlli della finestra.
struct EditorCommands: Commands {
    let model: EditorModel
    @ObservedObject var menu: EditorMenuState
    @ObservedObject var viewState: EditorViewState
    @AppStorage("canvasBackground") private var canvasBackground = "gray"
    @AppStorage("filmstripVisible") private var filmstripVisible = true

    private var state: EditorMenuState.Values { menu.values }
    private var editingDisabled: Bool { !state.hasDocument || state.isLoading }
    private var viewZoomDisabled: Bool { editingDisabled || viewState.tool == .crop }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(action: model.chooseImage) { Label("Apri immagini…", systemImage: "photo.on.rectangle") }
                .keyboardShortcut("o")
        }
        CommandGroup(replacing: .undoRedo) {
            Button(action: model.undo) { Label("Annulla modifica", systemImage: "arrow.uturn.backward") }
                .keyboardShortcut("z").disabled(!state.canUndo)
            Button(action: model.redo) { Label("Ripristina", systemImage: "arrow.uturn.forward") }
                .keyboardShortcut("z", modifiers: [.command, .shift]).disabled(!state.canRedo)
        }
        CommandGroup(replacing: .importExport) {
            Button(action: model.export) { Label("Esporta…", systemImage: "square.and.arrow.up") }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!state.hasDocument || state.isExporting || state.isLoading)
            Button { model.exportAll() } label: { Label("Esporta tutto…", systemImage: "square.and.arrow.up.on.square") }
                .keyboardShortcut("e", modifiers: [.command, .shift, .option])
                .disabled(!state.canExportAll)
        }
        SidebarCommands()
        // `InspectorCommands` mostra "Inspector Hide" in italiano: comando proprio
        // con titolo localizzato e la stessa scorciatoia di sistema (⌃⌘I).
        CommandGroup(after: .sidebar) {
            Button(viewState.inspectorVisible ? L10n.text("Nascondi inspector") : L10n.text("Mostra inspector")) {
                viewState.inspectorVisible.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .control])
            Button(filmstripVisible ? L10n.text("Nascondi pellicola") : L10n.text("Mostra pellicola")) {
                filmstripVisible.toggle()
            }
        }
        CommandGroup(before: .toolbar) {
            Button("Adatta alla finestra", action: viewState.fit)
                .keyboardShortcut("9").disabled(viewZoomDisabled)
            Button("Dimensioni reali", action: viewState.actualSize)
                .keyboardShortcut("0").disabled(viewZoomDisabled)
            Button("Ingrandisci", action: viewState.zoomIn)
                .keyboardShortcut("+").disabled(viewZoomDisabled || !viewState.canZoomIn)
            Button("Riduci", action: viewState.zoomOut)
                .keyboardShortcut("-").disabled(viewZoomDisabled || !viewState.canZoomOut)
            Divider()
            Picker("Sfondo", selection: $canvasBackground) {
                Text("Bianco").tag("white")
                Text("Grigio").tag("gray")
                Text("Nero").tag("black")
            }
            Picker("Griglia", selection: Binding(get: { state.gridStyle }, set: { model.gridStyle = $0 })) {
                ForEach(CompositionGrid.allCases) { grid in Text(grid.title).tag(grid) }
            }
            Divider()
        }
        CommandMenu("Immagine") {
            ForEach(EditorTool.allCases) { tool in
                Toggle(tool.title, isOn: Binding(get: { viewState.tool == tool }, set: { if $0 { viewState.tool = tool } }))
                    .keyboardShortcut(KeyEquivalent(Character(String(tool.rawValue + 1))))
                    .disabled(editingDisabled)
            }
            Divider()
            Button(action: model.rotate) { Label("Ruota 90°", systemImage: "rotate.left") }
                .keyboardShortcut("l").disabled(editingDisabled)
            Button(action: model.autoLevel) { Label("Autolivella", systemImage: "level") }
                .disabled(editingDisabled || state.isAutoLeveling)
            Divider()
            Button("Azzera modifiche", action: model.reset).disabled(editingDisabled)
            Divider()
            // ⌘← / ⌘→: le frecce semplici spostano l'inquadratura nel canvas.
            Button("Foto precedente", action: model.selectPrevious)
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(!state.canSelectPrevious)
            Button("Foto successiva", action: model.selectNext)
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!state.canSelectNext)
            Button("Rimuovi dal set") { if let id = model.selectedItemID { model.requestRemoval(of: id) } }
                .disabled(!state.hasSelection || state.isExporting)
        }
    }
}
