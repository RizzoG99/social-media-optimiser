import SwiftUI

// Liquid Glass arriva dai container e dagli stili di sistema (toolbar, sidebar,
// inspector). Qui restano solo le guardie di disponibilità: un helper per
// intenzione, mai un vetro generico. Il deployment target resta macOS 14 e la CI
// può compilare con un SDK precedente a macOS 26, da qui `#if compiler(>=6.2)`.

extension View {
    /// Unica azione primaria della finestra (Esporta), sul lato trailing della toolbar.
    @ViewBuilder func editorPrimaryAction() -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) { buttonStyle(.glassProminent) } else { buttonStyle(.borderedProminent) }
        #else
        buttonStyle(.borderedProminent)
        #endif
    }
}

#if compiler(>=6.2)
/// Spaziatore fisso di sistema tra due gruppi trailing della toolbar (macOS 26+).
/// Su macOS 14/15 i gruppi restano separati dall'ordine degli elementi; con SDK
/// precedenti il tipo non esiste e la toolbar lo omette con `#if compiler(>=6.2)`.
struct EditorToolbarSeparator: ToolbarContent {
    var body: some ToolbarContent {
        if #available(macOS 26, *) {
            ToolbarSpacer(.fixed, placement: .primaryAction)
        }
    }
}
#endif
