import SwiftUI
import AppKit

@main
struct SocialFrameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = EditorModel()
    @StateObject private var viewState = EditorViewState()
    var body: some Scene {
        WindowGroup {
            EditorView(model: model, viewState: viewState)
                .frame(minWidth: 1020, minHeight: 680)
                .onOpenURL { model.open($0) }
                .onAppear { appDelegate.model = model }
        }
        // Alla dimensione iniziale titolo e sottotitolo restano interi accanto al selettore.
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands { EditorCommands(model: model, viewState: viewState) }
    }
}

/// Il set vive solo in memoria (ADR-005, ADR-014): uscire con foto modificate e
/// non esportate chiede conferma.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: EditorModel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model?.hasUnexportedItems == true else { return .terminateNow }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.text("Uscire senza esportare?")
        alert.informativeText = L10n.text("Alcune foto hanno modifiche non esportate. Il set non viene salvato: uscendo le perderai.")
        alert.addButton(withTitle: L10n.text("Esci"))
        alert.addButton(withTitle: L10n.text("Annulla"))
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}
