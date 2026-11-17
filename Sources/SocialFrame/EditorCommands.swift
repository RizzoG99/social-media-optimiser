import SwiftUI
import SocialCore

/// Ogni comando della toolbar esiste anche nella barra dei menu, perché la
/// toolbar si può personalizzare o nascondere. Le condizioni di disabilitazione
/// coincidono con quelle dei controlli della finestra.
struct EditorCommands: Commands {
    @ObservedObject var model: EditorModel
    @ObservedObject var viewState: EditorViewState
    @AppStorage("canvasBackground") private var canvasBackground = "gray"

    private var editingDisabled: Bool { model.document == nil || model.isLoading }
    private var viewZoomDisabled: Bool { editingDisabled || viewState.tool == .crop }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(action: model.chooseImage) { Label("Apri immagine…", systemImage: "photo.on.rectangle") }
                .keyboardShortcut("o")
        }
        CommandGroup(replacing: .undoRedo) {
            Button(action: model.undo) { Label("Annulla modifica", systemImage: "arrow.uturn.backward") }
                .keyboardShortcut("z").disabled(!model.canUndo)
            Button(action: model.redo) { Label("Ripristina", systemImage: "arrow.uturn.forward") }
                .keyboardShortcut("z", modifiers: [.command, .shift]).disabled(!model.canRedo)
        }
        CommandGroup(replacing: .importExport) {
            Button(action: model.export) { Label("Esporta…", systemImage: "square.and.arrow.up") }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model.document == nil || model.isExporting || model.isLoading)
        }
        SidebarCommands()
        // `InspectorCommands` mostra "Inspector Hide" in italiano: comando proprio
        // con titolo localizzato e la stessa scorciatoia di sistema (⌃⌘I).
        CommandGroup(after: .sidebar) {
            Button(viewState.inspectorVisible ? L10n.text("Nascondi inspector") : L10n.text("Mostra inspector")) {
                viewState.inspectorVisible.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .control])
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
            Picker("Griglia", selection: $model.gridStyle) {
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
                .disabled(editingDisabled || model.isAutoLeveling)
            Divider()
            Button("Azzera modifiche", action: model.reset).disabled(editingDisabled)
        }
    }
}
