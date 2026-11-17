# API Liquid Glass e disponibilità su macOS

Disponibilità verificata il 12 novembre 2026 sulle interfacce `SwiftUI`/`SwiftUICore` di `MacOSX27.0.sdk` (Xcode 27.1, build 27A9275). Prima di usare un'API non elencata, controllala nell'SDK attivo:

```sh
sdk="$(xcrun --sdk macosx --show-sdk-path)"
grep -n -B8 'func nomeAPI' "$sdk"/System/Library/Frameworks/SwiftUI.framework/Versions/A/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface | grep '@available'
```

Se l'attributo sta sull'`extension` che contiene il simbolo, risali fino a essa. Le pagine di documentazione Apple richiedono un browser.

## Regola di disponibilità

Il deployment target è macOS 14. `#available` gestisce il sistema in esecuzione, non fa compilare un simbolo assente dall'SDK: se la CI del ramo usa un SDK precedente a macOS 26, racchiudi il ramo anche in `#if compiler(>=6.2)`. Il ramo di fallback deve offrire le stesse azioni e gli stessi stati; cambia solo l'aspetto. Isola guardie e fallback in `GlassChrome.swift`, così le viste restano leggibili.

`ToolbarContentBuilder`, `ViewBuilder` e `CommandsBuilder` accettano `if #available` (limited availability da macOS 14.5 per la toolbar personalizzabile, prima per il resto).

## Tabella

| API | macOS | Uso | Fallback macOS 14/15 |
| --- | --- | --- | --- |
| `NavigationSplitView`, `navigationSubtitle(_:)` | 13 | Sidebar + dettaglio; contesto sotto il titolo | — |
| `inspector(isPresented:content:)`, `inspectorColumnWidth` | 14 | Inspector trailing con materiale di sistema | — |
| `Section(isExpanded:)` in `List` | 14 | Gruppi richiudibili in sidebar | — |
| `toolbar(removing:)` | 14 | Rimuovere elementi di sistema (es. `.sidebarToggle`) solo se sostituiti | — |
| `Form` + `.formStyle(.grouped)` | 13 | Inspector e impostazioni | — |
| `windowToolbarLabelStyle(_:)`, `labelsVisibility(_:)` | 15 | Stile etichette della toolbar personalizzabile dall'utente | Etichette di default |
| `glassEffect(_:in:)`, `Glass` (`.regular`, `.clear`, `.identity`, `.tint`, `.interactive`) | 26.0 | Solo controlli personalizzati del livello funzionale | `.background(.regularMaterial, in: shape)` |
| `GlassEffectContainer(spacing:)`, `glassEffectID`, `glassEffectUnion`, `glassEffectTransition` | 26.0 | Raggruppare e far fondere più effetti personalizzati | Contenuto senza container |
| `.buttonStyle(.glass)`, `.glass(_:)`, `.glassProminent` | 26.0 | Pulsanti fuori dalla toolbar che fluttuano sul contenuto; `.glassProminent` per l'unica azione primaria | `.bordered` / `.borderedProminent` |
| `ToolbarSpacer(_:placement:)` con `.fixed` / `.flexible` | 26.0 | Separare gruppi della toolbar | Ordine e `ToolbarItemGroup` distinti |
| `sharedBackgroundVisibility(_:)` | 26.0 | Togliere lo sfondo condiviso a un elemento che non deve averlo (es. un'immagine) | — |
| `backgroundExtensionEffect()` | 26.0 | Estendere contenuto decorativo sotto sidebar/inspector | Nessun effetto |
| `scrollEdgeEffectStyle(_:for:)` (`.automatic`, `.hard`, `.soft`), `scrollEdgeEffectHidden` | 26.0 | Separazione tra barre fluttuanti e contenuto che scorre | Comportamento di sistema |
| `safeAreaBar(edge:alignment:spacing:content:)` | 26.0 | Barra personalizzata che ottiene l'effetto bordo | `safeAreaInset` |
| `ConcentricRectangle`, `rect(corners:isUniform:)` | 26.0 | Forme concentriche con il contenitore | `RoundedRectangle(cornerRadius:style: .continuous)` |
| `buttonSizing(_:)`, `labelIconToTitleSpacing(_:)`, `symbolColorRenderingMode(_:)`, `searchToolbarBehavior(_:)` | 26.0 | Rifiniture di controlli e ricerca | Default |
| `visibilityPriority(_:)`, `ToolbarItemVisibilityPriority` | **26.1** | Tenere visibili più a lungo gli elementi importanti quando la finestra si stringe | Pochi elementi; secondari in un `Menu` |
| `accessibilityShowBorders` (environment) | SDK 26.1+, back-deployed | Mostra bordi nei controlli personalizzati | Con SDK precedenti si chiama `accessibilityShowButtonShapes` |
| `TabsPickerStyle` (`.pickerStyle(.tabs)`) | **27.0** | Nuovo stile picker; aspetto su macOS da verificare a schermo prima di adottarlo | `.segmented` |
| `reorderable()`, `reorderContainer(...)`, `swipeActionsContainer()` | 27.0 | Riordino e azioni di scorrimento in contenitori qualunque | `onMove` in `List` |
| `TabRole.prominent` | 27.0 | Scheda fissata a trailing (app a schede) | — |
| `ToolbarOverflowMenu`, `.topBarPinnedTrailing`, posizionamenti `.topBar*` | **non su macOS** | Concetti iOS | Su macOS il sistema gestisce l'overflow da solo |

## Pattern

### Toolbar raggruppata dal sistema

Gli elementi della toolbar ricevono già vetro, hover e raggruppamento. Passa solo `Label` o `Button(_:systemImage:action:)`: niente `buttonStyle` personalizzato, `font`, `frame`, `controlSize` o capsule intorno.

```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        Picker("Strumento", selection: $tool) {
            Label("Composizione", systemImage: "crop.rotate").tag(EditorTool.composition)
            Label("Ritaglio", systemImage: "crop").tag(EditorTool.crop)
            Label("Timbro", systemImage: "wand.and.rays").tag(EditorTool.clone)
        }
        .pickerStyle(.segmented)
    }
    ToolbarItemGroup(placement: .primaryAction) {
        Button("Ruota a sinistra", systemImage: "rotate.left", action: model.rotate)
            .disabled(model.document == nil)
    }
    #if compiler(>=6.2)
    if #available(macOS 26, *) { ToolbarSpacer(.fixed, placement: .primaryAction) }
    #endif
    ToolbarItem(placement: .primaryAction) {
        Button("Esporta…", systemImage: "square.and.arrow.up", action: model.export)
            .editorPrimaryAction()   // helper da aggiungere in GlassChrome (sotto)
            .disabled(model.document == nil || model.isExporting)
    }
    ToolbarItem(placement: .primaryAction) {
        Button("Inspector", systemImage: "sidebar.trailing") { inspectorVisible.toggle() }
    }
}
```

Undo/Redo stanno già nel menu Composizione con ⌘Z/⇧⌘Z: in toolbar solo se il confronto con Foto lo giustifica, e in ogni caso nello stesso gruppo. Verifica a schermo che il pulsante prominente non produca vetro doppio; se succede, lascia lo stile al sistema e rendi prominente l'azione nell'inspector.

### Helper in `GlassChrome.swift` (da aggiungere)

Un helper per ogni intenzione, mai un helper generico "metti il vetro":

```swift
extension View {
    @ViewBuilder func editorPrimaryAction() -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) { buttonStyle(.glassProminent) } else { buttonStyle(.borderedProminent) }
        #else
        buttonStyle(.borderedProminent)
        #endif
    }
}
```

### Controllo personalizzato sopra la foto (raro)

Solo per un controllo transitorio che deve galleggiare sul canvas (per esempio il raggio del timbro durante il trascinamento). Variante `.clear` sopra la foto, con velo scuro se il fondo è chiaro; più elementi in un unico `GlassEffectContainer`; rispetta Riduci trasparenza con una superficie opaca semantica.

```swift
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

if reduceTransparency {
    content.background(Color(nsColor: .windowBackgroundColor), in: .capsule)
} else {
    #if compiler(>=6.2)
    if #available(macOS 26, *) {
        content.glassEffect(.clear.interactive(), in: .capsule)
    } else {
        content.background(.ultraThinMaterial, in: .capsule)
    }
    #else
    content.background(.ultraThinMaterial, in: .capsule)
    #endif
}
```

### Inspector

```swift
.inspector(isPresented: $inspectorVisible) {
    Form {
        Section("Composizione") {
            LabeledContent("Zoom") { zoomSlider }
            LabeledContent("Raddrizza") { straightenSlider }
            Button("Raddrizza automaticamente", systemImage: "level", action: autoLevel)
        }
        Section("Esportazione") {
            Picker("Formato", selection: $model.png) { Text("JPEG").tag(false); Text("PNG").tag(true) }
                .pickerStyle(.segmented)
        }
    }
    .formStyle(.grouped)
    .inspectorColumnWidth(min: 260, ideal: 300, max: 360)
}
```

Pulsanti dell'inspector con stile di default e larghezza naturale: niente `.glass`, niente `frame(maxWidth: .infinity)`.

### Sidebar

```swift
List(selection: $selectedPresetID) {
    ForEach(Platform.allCases) { platform in
        Section(platform.title, isExpanded: expansionBinding(for: platform)) {
            ForEach(presets(for: platform)) { preset in
                Label {
                    VStack(alignment: .leading) {
                        Text(preset.title)
                        Text(preset.sizeDescription).font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: preset.aspectSymbol)  // es. rectangle.portrait, square, rectangle
                }
                .tag(preset.id)
            }
        }
    }
}
.navigationSplitViewColumnWidth(min: 200, ideal: 240)
```

Nessun `listStyle` o sfondo personalizzato: la sidebar riceve vetro, colore d'accento sulle icone e larghezza fino al bordo dal sistema.
