import SwiftUI
import AppKit

@main
struct SocialFrameApp: App {
    @StateObject private var model = EditorModel()
    @StateObject private var viewState = EditorViewState()
    var body: some Scene {
        WindowGroup {
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
