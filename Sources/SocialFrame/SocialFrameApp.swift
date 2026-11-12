import SwiftUI
import AppKit

@main
struct SocialFrameApp: App {
    @StateObject private var model = EditorModel()
    var body: some Scene {
        WindowGroup {
            EditorView(model: model)
                .frame(minWidth: 1020, minHeight: 680)
                .onOpenURL { model.open($0) }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Apri immagine…", action: model.chooseImage).keyboardShortcut("o")
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Annulla", action: model.undo).keyboardShortcut("z").disabled(!model.canUndo)
                Button("Ripristina", action: model.redo).keyboardShortcut("z", modifiers: [.command, .shift]).disabled(!model.canRedo)
            }
            CommandGroup(replacing: .importExport) {
                Button("Esporta…", action: model.export).keyboardShortcut("e", modifiers: [.command, .shift]).disabled(model.document == nil || model.isExporting || model.isLoading)
            }
        }
    }
}
