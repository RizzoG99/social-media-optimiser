import SwiftUI
import AppKit

@main
struct SocialFrameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: EditorModel
    @StateObject private var menu: EditorMenuState
    @StateObject private var viewState = EditorViewState()

    init() {
        let model = EditorModel()
        _model = StateObject(wrappedValue: model)
        _menu = StateObject(wrappedValue: EditorMenuState(model: model))
    }
    var body: some Scene {
        // Una sola finestra: il modello è unico. Con `WindowGroup` ogni file aperto dal
        // Finder (o trascinato sull'icona nel Dock) creava una nuova finestra sullo stesso
        // `EditorModel`, ripristinata anche al riavvio; ogni modifica ridisegnava tutte le
        // finestre e un'apertura multipla dalla scheda SD bloccava l'interfaccia.
        // I file aperti dal Finder arrivano tutti insieme all'`AppDelegate`, che li passa al
        // set in un solo import: `onOpenURL` su `Window` riceverebbe solo il primo.
        Window("SocialFrame", id: "editor") {
            EditorView(model: model, viewState: viewState)
                .frame(minWidth: 1020, minHeight: 680)
                .onAppear { appDelegate.attach(model) }
        }
        // Alla dimensione iniziale titolo e sottotitolo restano interi accanto al selettore.
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands { EditorCommands(model: model, menu: menu, viewState: viewState) }
    }
}

/// Il set vive solo in memoria (ADR-005, ADR-014): uscire con foto modificate e
/// non esportate chiede conferma.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) weak var model: EditorModel?
    /// File ricevuti all'avvio, prima che la finestra colleghi il model.
    private var pendingURLs: [URL] = []

    func attach(_ model: EditorModel) {
        self.model = model
        guard !pendingURLs.isEmpty else { return }
        model.open(pendingURLs)
        pendingURLs = []
    }

    /// Apri con / trascinamento sull'icona nel Dock: tutti i file in un'unica chiamata.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        if let model { model.open(urls) } else { pendingURLs += urls }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model?.hasUnexportedItems == true else { return .terminateNow }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.text("Uscire senza esportare?")
        alert.informativeText = L10n.text("Alcune foto hanno modifiche non esportate. Il set non viene salvato: uscendo le perderai.")
        // Uscire scarta il set: azione distruttiva, mai sul tasto Invio (HIG).
        let quit = alert.addButton(withTitle: L10n.text("Esci"))
        quit.hasDestructiveAction = true
        quit.keyEquivalent = ""
        let cancel = alert.addButton(withTitle: L10n.text("Annulla"))
        cancel.keyEquivalent = "\r"
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}
