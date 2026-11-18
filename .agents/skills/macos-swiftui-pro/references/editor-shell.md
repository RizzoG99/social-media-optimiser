# Shell della finestra editor

Anatomia obiettivo per `SocialFrameApp`, `EditorView` e `GlassChrome`. Modello mentale: Foto in modalità Modifica e Anteprima con inspector aperto.

## Anatomia obiettivo

| Area | Contenuto | Implementazione |
| --- | --- | --- |
| Titolo finestra | Nome del file aperto; senza foto, un titolo descrittivo come "Nessuna foto" | `.navigationTitle(fileName)` |
| Sottotitolo | Destinazione e dimensioni, per esempio "Instagram · Post verticale · 1080 × 1350" | `.navigationSubtitle(...)` |
| Toolbar leading | Pulsante sidebar di sistema, titolo, sottotitolo | Automatico con `NavigationSplitView` |
| Toolbar centro | Selettore dello strumento (Composizione, Ritaglio, Timbro) | `Picker` `.segmented` in `.principal` |
| Toolbar trailing | Al massimo due gruppi: comandi di modifica frequenti, poi Esporta prominente e pulsante inspector | `ToolbarItemGroup` + `ToolbarSpacer(.fixed)` |
| Sidebar | Piattaforme come sezioni richiudibili, preset come righe con simbolo del rapporto | `List(selection:)`, `Section(isExpanded:)`, `Label` |
| Canvas | Solo la foto su fondo neutro, guide e griglia di composizione; nessuna intestazione | Livello contenuto, nessun vetro |
| Inspector | Sezioni Composizione, Strumento attivo, Esportazione; dettagli secondari in gruppi richiudibili | `.inspector` + `Form` `.grouped` |
| Menu Vista | Adatta alla finestra, Dimensioni reali, ingrandisci/riduci, sfondo del canvas, griglia, mostra/nascondi sidebar e inspector | `CommandMenu`/`CommandGroup` con scorciatoie |
| Barra inferiore | Facoltativa: solo stato breve (esito export, profilo sRGB), nessun controllo | Testo secondario |

Ogni comando della toolbar compare anche nei menu (File, Composizione, Vista, Immagine), con scorciatoia dove esiste una convenzione.

## Anti-pattern della shell attuale

Rilevati sulla shell di novembre 2026 (`GlassChrome.swift`, `EditorView.swift`), prescritta da ADR-012 e dai paragrafi Liquid Glass di `docs/requisiti-prodotto.md`: entrambi sono superati da questa tabella. Quando tocchi una di queste aree, sostituisci il pattern invece di estenderlo e aggiorna requisiti e ADR.

| Pattern attuale | Regola violata | Sostituzione |
| --- | --- | --- |
| Capsule `glassEffect(.regular, in: Capsule())` attorno a gruppi della toolbar, con `sharedBackgroundVisibility(.hidden)` per nascondere quella di sistema | La toolbar raggruppa da sé; ridurre sfondi personalizzati; niente vetro ridisegnato | `ToolbarItem`/`ToolbarItemGroup` semplici e `ToolbarSpacer` |
| `.glass` + `glassEffectUnion` su ogni pulsante della toolbar, icone con `font(.system(size:))`, `frame` e `controlSize(.small)` | Simboli di sistema senza bordo; metriche standard; niente vetro su vetro | `Button(_:systemImage:action:)` senza stile |
| Schede di modalità come pulsanti `.glass` uniti, con rappresentazione accessibile manuale | Controlli standard prima di quelli personalizzati | `Picker` `.segmented`: selezione, frecce da tastiera e VoiceOver inclusi |
| Slider di zoom vista dentro una capsula `interactive` in `.navigation` | Leading riservato a sidebar e titolo; niente superfici manuali | Comandi zoom nel menu Vista; eventuale slider come `ToolbarItem` semplice nella zona centrale |
| Titolo "SocialFrame" rimosso dalla toolbar e nome file come intestazione dentro il canvas | Non usare il nome dell'app come titolo; niente contenuto duplicato | Nome file come titolo, preset nel sottotitolo; intestazione nel canvas eliminata |
| Pulsanti a tutta larghezza `.glass` nell'inspector (Azzera modifiche, Autolivella, timbro) | Niente vetro nel livello contenuto; inspector sobrio | Pulsanti di stile standard in `Form` `.grouped`; Azzera in fondo alla sezione |
| Slider dell'opacità della griglia senza etichetta | Ogni controllo ha un'etichetta | `LabeledContent("Opacità griglia")` o `Slider` con label visibile |
| Adatta, 100% e Sfondo come capsula glass nella barra inferiore del canvas | Nessuna azione nella barra inferiore | Menu Vista con scorciatoie; eventuale `Menu` "Vista" in toolbar |
| Esporta duplicato: icona `.glass` in toolbar e pulsante `.glassProminent` a tutta larghezza nell'inspector | Una sola azione primaria, trailing in toolbar | Esporta prominente in toolbar; l'inspector regola solo formato e qualità |
| Intestazione dell'inspector tagliata sotto la toolbar | Effetto bordo di scorrimento e safe area di sistema | `Form` nell'inspector senza padding o header manuali sopra |

## Vincoli che restano validi

- `ResettableSlider` (doppio clic per ripristinare) è un comportamento di prodotto: tienilo, ma con etichetta e senza superficie intorno. `NSSlider` riceve il vetro durante l'interazione dal sistema.
- La foto non riceve mai effetti UI: niente `backgroundExtensionEffect()` sul canvas, perché i pixel specchiati sotto la sidebar sembrerebbero contenuto esportato. Su un fondo neutro è superfluo.
- Riduci movimento: le transizioni dello strumento attivo usano la policy di animazione esistente.
- Nomi accessibili distinti per ogni comando (problema già emerso con i gruppi uniti: con controlli standard non serve `accessibilityRepresentation`).
- Testi via `L10n` o chiavi localizzabili: le etichette SwiftUI letterali si risolvono solo nel bundle `.app` (vedi `docs/localizzazione.md`).
