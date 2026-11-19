import SwiftUI
import AppKit

@main
struct SocialFrameApp: App {
    @StateObject private var model = EditorModel()
    @StateObject private var viewState = EditorViewState()
    var body: some Scene {
        // Una sola finestra: il modello è unico. Con `WindowGroup` ogni file aperto dal
        // Finder (o trascinato sull'icona nel Dock) creava una nuova finestra sullo stesso
        // `EditorModel`, ripristinata anche al riavvio; ogni modifica ridisegnava tutte le
        // finestre e un'apertura multipla dalla scheda SD bloccava l'interfaccia.
        Window("SocialFrame", id: "editor") {
            EditorView(model: model, viewState: viewState)
                .frame(minWidth: 1020, minHeight: 680)
                .onOpenURL { model.open($0) }
        }
        // Alla dimensione iniziale titolo e sottotitolo restano interi accanto al selettore.
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands { EditorCommands(model: model, viewState: viewState) }
    }
}
