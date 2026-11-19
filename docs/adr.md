# Decisioni architetturali (ADR)

## ADR-014 — Set di foto in memoria, pellicola ed Esporta tutto

**Stato:** accettato il 18 novembre 2026. Emenda ADR-005: l'esportazione in blocco entra nel perimetro; la persistenza di progetti e sessioni resta esclusa.

**Contesto:** preparare più scatti richiedeva di riaprire ogni foto e la nuova apertura sostituiva la sessione. Requisiti e decisioni dell'utente in `docs/analisi-set-foto.md` (F-11…F-13).

**Decisione:**
- Il set è un array di `PhotoItem` in `EditorModel`. Ogni foto conserva `EditState`, preset, cronologia annulla/ripristina e snapshot esportato. La foto attiva vive nelle proprietà dell'editor; al cambio foto il suo stato viene salvato nell'item e quello dell'item scelto ripristinato dopo la decodifica fuori dal MainActor. Nessuna conferma tra foto del set.
- È decodificata solo la foto attiva. Le altre tengono una miniatura di ~160 px del risultato modificato: all'import viene renderizzata in sequenza e poi il documento viene rilasciato; per la foto attiva deriva dall'ultimo frame dell'anteprima, senza render aggiuntivi (ADR-008 invariato).
- Un nuovo import con il set aperto chiede Aggiungi/Sostituisci. Sostituisci libera il set precedente solo quando almeno un file nuovo è stato aperto (F-01). Duplicati identificati dal percorso standardizzato con symlink risolti.
- Esporta tutto pianifica i nomi con una funzione pura (`ExportPlan`) ed esporta in sequenza con `ImageRenderer.export`, la stessa geometria di anteprima ed export singolo. Lo stato di ogni foto viene fissato all'avvio. I conflitti con file esistenti producono una sola domanda; nomi doppi nel set e originali del set (anche via symlink o hard link) ricevono sempre un suffisso.
- Nessuna persistenza: l'uscita con foto modificate e non esportate chiede conferma.

**Conseguenze:** più memoria per le miniature (lineare nel numero di foto, piccola) e un breve caricamento a ogni cambio foto. Le scorciatoie ⌘←/⌘→ hanno precedenza sui campi di testo dell'inspector, dove normalmente spostano il cursore a inizio/fine riga.

## ADR-013 — Shell editor con componenti di sistema (sostituisce ADR-012)

**Stato:** accettato il 12 novembre 2026. Sostituisce ADR-012 e le parti di ADR-011 su barra a schede, slider della vista in alto a sinistra e posizione dei controlli Adatta/100%.

**Contesto:** la shell di ADR-012 ridisegnava a mano il vetro: capsule `glassEffect` attorno ai gruppi della toolbar con `sharedBackgroundVisibility(.hidden)`, stile `.glass` e `glassEffectUnion` su ogni comando, schede a pillola con rappresentazione accessibile manuale, titolo finestra "SocialFrame", intestazione del file nel canvas, pulsanti `.glass` a tutta larghezza nell'inspector, controlli vista in una barra inferiore ed Esporta duplicato. Le fonti Apple lette il 12 novembre 2026 (sintesi in `.agents/skills/macos-swiftui-pro/references/hig-macos.md`) indicano il contrario:

- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) e [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) (9 set 2025): il vetro è il livello funzionale dei componenti di sistema; ridurre gli sfondi personalizzati in toolbar e barre; niente vetro sopra vetro; `glassEffect` solo con parsimonia su controlli personalizzati.
- [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) (16 dic 2025): al massimo tre gruppi separati dallo spaziatore di sistema, simboli senza bordo, una sola azione prominente sul lato trailing, overflow gestito dal sistema e, su macOS, ogni elemento presente anche nei menu.
- [Windows](https://developer.apple.com/design/human-interface-guidelines/windows) (9 giu 2025): il titolo descrive il contenuto, non l'app; la barra inferiore non ospita azioni.
- [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) (8 giu 2026), [Split views](https://developer.apple.com/design/human-interface-guidelines/split-views), [Panels](https://developer.apple.com/design/human-interface-guidelines/panels): `List` con selezione persistente e simboli; inspector sobrio, riapribile dalla toolbar e dal menu.
- [Menus](https://developer.apple.com/design/human-interface-guidelines/menus) (8 giu 2026): icone solo per azioni chiave e coerenti nel gruppo.

**Decisione:**

- Finestra: `navigationTitle` con il nome del file (“Nessuna foto” senza documento) e `navigationSubtitle` con formato e pixel (la piattaforma resta in sidebar e inspector: con la piattaforma il sottotitolo veniva troncato accanto al selettore anche a 1280 pt). Dimensione iniziale della finestra 1280×820, minima 1020×680. Eliminata l'intestazione nel canvas.
- Toolbar: `Picker` `.segmented` in `.principal` per lo strumento; a destra un `ToolbarItemGroup` con Ruota 90° e il pulsante dell'inspector, `ToolbarSpacer(.fixed)` (macOS 26+) ed Esporta con `editorPrimaryAction()` (`.glassProminent`, su macOS 14/15 `.borderedProminent`) da solo sul bordo trailing. A schermo il pulsante prominente forma sempre una capsula propria: con l'inspector dopo Esporta i gruppi diventavano quattro. Undo/Redo e Apri restano nei menu con le scorciatoie standard, come in Foto e Anteprima.
- Menu: `EditorCommands` riunisce File, Modifica, Vista (Adatta alla finestra ⌘9, Dimensioni reali ⌘0, Ingrandisci ⌘+, Riduci ⌘−, Sfondo, Griglia, `SidebarCommands`, comando proprio Mostra/Nascondi inspector ⌃⌘I al posto di `InspectorCommands`, che in italiano mostrava "Inspector Hide") e Immagine (strumenti ⌘1–⌘3, Ruota 90° ⌘L, Autolivella, Azzera modifiche). Le condizioni di disabilitazione coincidono con quelle dei controlli.
- Lo stato di presentazione condiviso tra finestra e menu (strumento, scala e offset della vista, visibilità dell'inspector) vive in `EditorViewState`, posseduto dall'app come `EditorModel`. Non entra in `EditState`, cronologia o export. Gli effetti del cambio di strumento restano negli `onChange` della vista, così menu e toolbar seguono lo stesso percorso.
- Lo slider della vista è sostituito da passi fissi 10–400% nel menu Vista; il doppio clic sulla foto continua ad alternare Adatta e 100%.
- Sidebar: `List(selection:)`, `Section(isExpanded:)`, `Label` con simbolo del rapporto (`rectangle.portrait`, `square`, `rectangle`, `person.crop.circle` per i profili), senza stile o sfondo personalizzati.
- Inspector: `Form` `.formStyle(.grouped)` con sezioni Formato social, strumento attivo (Inquadratura, Ritaglia o Timbro clone), Guide, Esportazione. Ogni slider è in `LabeledContent`; i campi annidati nascondono l'etichetta duplicata e mantengono il nome accessibile. Pulsanti di stile standard a larghezza naturale; Applica/Annulla del ritaglio usano `.defaultAction`/`.cancelAction`. Lo strumento clone è un `Toggle`.
- Barra di stato: solo testo (stato, scala della vista, sRGB).
- Build: `scripts/build-app.sh` registra nel binario la versione dell'SDK realmente usata (`vtool -set-build-version`), perché SwiftPM vi scrive il deployment target (`sdk 14.0`) e AppKit disattiverebbe il design di sistema di macOS 26+.
- `GlassChrome.swift` contiene solo `editorPrimaryAction()` ed `EditorToolbarSeparator`; ogni API macOS 26+ è dentro `#available` (il deployment target resta macOS 14) e `#if compiler(>=6.2)`. La CI fissa Xcode 27.1 (`docs/ci.md`), quindi compila solo il primo ramo; la guardia sul compilatore resta perché il pacchetto continui a compilare con toolchain precedenti a Swift 6.2, non per la CI. Rimossi `GlassCapsule`, `GlassAction`, `EditorGlassGroup`, `editorSharedSurface`, `editorGlassUnion` e il titolo fisso.

**Conseguenze:** hover, raggruppamento, overflow, Riduci trasparenza e Aumenta contrasto arrivano dal sistema senza codice dedicato; VoiceOver legge nomi distinti senza `accessibilityRepresentation`. Identificatori accessibili rimossi con i rispettivi controlli: `open-image`, `undo-image`, `redo-image`, `view-zoom`. Restano `editor-mode` (sul selettore), `rotate-image`, `export-image`, `toggle-inspector`, `clone-mode`, `auto-level`, `composition-grid`, `image-preview` e `preset-*`. La scala continua della vista non è più disponibile come slider.

## ADR-012 — Chrome Liquid Glass e compatibilità (superato da ADR-013)

> Superato da ADR-013 il 12 novembre 2026. Resta come resoconto storico; non riprodurre capsule, `sharedBackgroundVisibility(.hidden)` né `.glass` sui comandi della toolbar.

### Revisione completa e interattività del puntatore

Le capsule statiche dietro pulsanti plain/borderless non forniscono la risposta al puntatore dei controlli di Foto. Ogni comando toolbar e ogni scheda usa ora lo stile nativo `.glass`; i gruppi sono coordinati con `GlassEffectContainer` e `glassEffectUnion`. La selezione unica delle modalità rimane nello stato della vista, con nome/stato accessibile e frecce da tastiera. Lo slider di vista conserva `NSSlider` e la superficie circostante usa `.regular.interactive(...)`, disattivata quando il controllo è disabilitato. Non simulare il vetro con animazioni hover arbitrarie. Riferimento: [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).

Il pannello destro usa `.inspector` nativo, con larghezza regolabile e comando Mostra/nascondi; rimosso il fondo opaco imposto dal codice. Le azioni di editing principali e clone adottano gli stili glass e glassProminent. Campi numerici, slider densi, picker, guide, foto, menu, alert e pannelli file restano componenti di sistema senza ulteriori lastre di vetro. I menu adottano icone standard e Undo ha una chiave distinta da Cancel. I container di effetti non avvolgono intere aree scorrevoli: nel collaudo ciò provocava disallineamenti delle superfici.

I comandi uniti dal materiale Glass espongono una rappresentazione accessibile separata per ogni pulsante, per evitare che il gruppo toolbar propaghi il nome del primo comando ai successivi. La rappresentazione richiama la stessa azione e rispetta lo stesso stato disabled.

Seguire [Apple — Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass): limitare il vetro al livello di navigazione e ai comandi principali, senza sovrapporlo alla foto o ai controlli numerici dell’inspector. Toolbar unificata, sidebar di sistema e tre gruppi a capsula per zoom, modalità e azioni. I gruppi custom hanno un solo `glassEffect(.regular, in: Capsule())`; il background condiviso automatico della toolbar è disabilitato per evitare doppio vetro. I pulsanti d’azione autonomi usano gli stili nativi `.glass`/`.glassProminent`.

`GlassChrome` isola API e availability: macOS 26+ con SDK recente usa Liquid Glass; macOS 14/15 e compilatori pre Swift 6.2 usano `.regularMaterial` e pulsanti bordered. Il deployment target resta macOS 14. `accessibilityReduceTransparency` usa una capsula opaca di colore semantico; le selezioni rispettano Riduci movimento tramite la policy esistente. Non cambiare preferenze di sistema per ottenere l’effetto del riferimento. Il titolo finestra resta SocialFrame anche quando il suo elemento visibile è rimosso dalla toolbar (macOS 15+).

Le modalità mantengono pulsanti nativi con focus, etichetta, stato selezionato e navigazione con frecce. Ogni azione nel gruppo conserva nome accessibile e tooltip distinti. Nessuna modifica al motore immagini, allo stato di editing o alle esportazioni.

## ADR-011 — Vista, ritaglio provvisorio e nitidezza di output

> Barra a schede, slider della vista in alto a sinistra e controlli vista sono superati da ADR-013; ritaglio, nitidezza e semantica della vista restano validi.

La UI adotta una barra superiore con modalità Inquadratura/Ritaglia/Strumenti e inspector contestuale, ispirata a Foto di Apple. Lo slider della vista (10–400%) si trova in alto a sinistra, la rotazione con icona tra le azioni a destra. Il crop forza la vista adattata e nasconde lo slider della vista; cambiare scheda cancella solo la selezione provvisoria. Il clone rimane un pulsante on/off nella scheda Strumenti e viene disattivato uscendo dalla scheda, conservando i timbri. Nessun filtro o altra regolazione della schermata di riferimento viene introdotto implicitamente.

Ingrandimento Adatta/100% e offset della vista appartengono alla presentazione; non alterano `EditState`, cronologia o export. Il 100% considera il fattore Retina e richiede un rendering alla dimensione finale; la vista adattata mantiene il limite di anteprima 1400 px. Il renderer applica il filtro di output prima della riduzione dell’anteprima, alla dimensione finale del preset.

Il ritaglio è una selezione normalizzata a rapporto fisso sopra un contesto privo di timbri, renderizzato in background. `cropContext` ricostruisce la selezione corrente e allarga il contesto fin dove può contenerla senza scoprire bordi vuoti. `cropped` converte la selezione in zoom e pan tramite `panned`, rispettando rotazione, livellamento e massimo zoom UI 8×. Applica è una sola modifica annullabile; Annulla non modifica lo stato. Token, documento e stato iniziale proteggono dai risultati asincroni obsoleti.

`OutputSharpening` fa parte di `EditState` e quindi degli snapshot undo/export. Dopo clone e alla risoluzione finale, CIUnsharpMask usa raggio 0,7 pixel e intensità 0,2/0,4/0,6 per Bassa/Standard/Alta. Nessuna salta il filtro. Sono valori propri di SocialFrame, non una replica di Lightroom. Le API esistenti conservano il default Nessuna tramite l’inizializzatore di `EditState`.

Gli slider usano tracking AppKit continuo; un clic singolo viene applicato dopo l’intervallo di doppio clic, per evitare un passo di undo intermedio quando il secondo clic richiede il reset. Il trascinamento resta immediato e registra un solo passo di undo.

## ADR-001 — App macOS nativa e offline

**Decisione:** SwiftUI su macOS 14+, senza backend, account o dipendenze di rete per il flusso principale.

**Motivo:** il compito è locale e centrato su file; tutela privacy e rende disponibile l’editor senza connessione. **Conseguenze:** l’app non pubblica sulle piattaforme e non può aggiornare automaticamente le specifiche; i preset sono dati versionati nell’app e richiedono manutenzione.

## ADR-002 — Sorgente immutato, trasformazioni dichiarative e clone

**Decisione:** mantenere sorgente e parametri (crop, scala/traslazione, rotazione/raddrizzamento) separati. Il timbro clone offline campiona la foto dell’utente, attraverso una sorgente selezionata con click, e applica i tratti alla variante normalizzata del crop corrente.

**Motivo:** consente revisioni reversibili e più esportazioni dal medesimo originale. ImageIO gestisce lettura/encoding e metadati; Core Image compone la pipeline. Non riscrivere l’originale. Il clone usa timbri a click discreti, non un tratto continuo. Cambiare la geometria del crop invalida sorgente e timbri clone; una nota persistente spiega il comportamento senza dialogo di conferma. Undo ripristina anche preset/geometria e timbri rimossi. Il progetto v0.1 non conserva una sessione persistente.

## ADR-003 — Export controllato in pixel e spazio colore

**Decisione:** render finale entro 40 MP, conversione a sRGB, composizione su fondo bianco e output JPEG o PNG. Anche il PNG è opaco e appiattito su bianco. JPEG è lossy e la qualità configurabile; PNG conserva senza perdita i pixel renderizzati già appiattiti.

**Motivo:** comportamento prevedibile e formati ampiamente utilizzati. Input previsto fino a 120 MP/512 MB per accogliere originali ad alta risoluzione, inclusi file Fujifilm da circa 40,2 MP. Il successivo trattamento del social è fuori dal controllo dell’app: ridimensionamento, ricompressione, crop e resa possono variare per servizio, account, client e tempo.

## ADR-004 — Preset come guida, non validatore di upload

**Decisione:** associare a ogni valore uno stato esplicito: requisito ufficiale, raccomandazione ufficiale, oppure preset pratico da verificare. Non dedurre che una dimensione raccomandata sia un limite di accettazione.

**Motivo:** le fonti differiscono per superficie e spesso non specificano i limiti d’upload. Registrare URL e data di controllo; mostrare avviso sobrio quando il dato è raccomandativo o non verificato.

## ADR-005 — Ambito v0.1 e dati di sessione

**Decisione:** clone manuale offline incluso; nessuna generazione AI. Persistenza dei progetti e batch esclusi da v0.1.

> Emendato da ADR-014 (18 novembre 2026): set di foto in memoria ed Esporta tutto sono inclusi; la persistenza resta esclusa.

## ADR-006 — Interazione allineata alle HIG macOS

**Decisione:** usare pattern SwiftUI/macOS nativi, finestra ridimensionabile, canvas con input di precisione, sidebar nascondibile per i gruppi di preset e toolbar contenuta per le azioni frequenti.

**Motivo:** seguire le convenzioni di navigazione e comandi della piattaforma. La sidebar non deve diventare un contenitore di azioni essenziali; lasciare l’overflow alla toolbar di sistema. Riferimenti: [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars).

## ADR-007 — Animazioni dell’interfaccia

Transizioni SwiftUI ease-in-out di 180 ms per comparsa dell’anteprima, griglia, descrizione preset, stato e aperture dei gruppi clone/JPEG. Nessuna interpolazione dei pixel durante pan, zoom, livellamento o timbro; la geometria interattiva resta immediata. `accessibilityReduceMotion` disabilita animazioni e transizioni, anche nelle transazioni ereditate. Le animazioni non modificano il modello né l’export.

## ADR-008 — Anteprima continua durante le modifiche

Il debounce di 35 ms annullava il rendering a ogni nuovo evento e rimandava l’anteprima fino alla pausa dello slider. Ora un solo worker renderizza uno snapshot fuori dal MainActor e pubblica i fotogrammi intermedi dello stesso documento/preset, anche se nel frattempo sono arrivate altre modifiche. Poi acquisisce direttamente lo stato più recente, senza accodare ogni evento. Quando il flusso termina, completa il fotogramma finale. Risultati di altri documenti/preset vengono scartati. Nessun limite FPS garantito: il ritmo dipende dal costo del rendering e dall’hardware.

## ADR-009 — Orizzonte locale e griglie separate dall’editing

`VNDetectHorizonRequest` analizza una copia dell’inquadratura corrente, senza timbri e limitata a 1024 px, fuori dal MainActor. Secondo [Apple — transform](https://developer.apple.com/documentation/vision/vnhorizonobservation/transform), la trasformazione va invertita per livellare l’orizzonte; prima viene convertita nella convenzione Y del renderer Core Image. Il verso è verificato sui pixel di un campione inclinato a ±8°, oltre ai test algebrici. Il residuo viene sommato al livellamento già applicato. Si scartano osservazioni con confidenza sotto 0,6, valori non finiti, trasformazioni degeneri e correzioni fuori ±45°. La confidenza di Vision non equivale a una probabilità calibrata e può non essere significativa: il risultato resta una stima, verificabile e annullabile dall’utente.

La richiesta conserva documento e revisione iniziali; se l’utente modifica la foto durante l’analisi, il risultato non viene applicato. Il model accetta uno stimatore asincrono iniettato nei test per verificare concorrenza, nessun risultato e undo senza dipendere dal modello ML. Le griglie sono geometrie normalizzate di sola presentazione, disegnate su Canvas, indipendenti dal motore e dalle immagini esportate.

La prima implementazione del verso, pur coerente con una lettura letterale della documentazione, è stata smentita dal test end-to-end con immagine inclinata. La sola correzione del verso lasciava circa 2° di residuo nel campione. L’analisi ora ricontrolla il risultato per massimo tre passaggi e rifinisce un bordo dominante vicino all’orizzontale quando trova almeno 44 colonne di supporto su 64, estese su almeno il 65% della larghezza, con residuo entro ±4° e scarto RMS massimo di 1,5 pixel. Il raffinamento non opera senza una stima Vision accettata. Se manca un bordo rettilineo affidabile, resta la stima Vision: l’esito su scene reali va verificato visivamente.

## ADR-010 — Protezione della sessione, controlli precisi e risorse linguistiche

Prima di sostituire il documento si confrontano geometria/preset correnti con l'ultimo snapshot importato o esportato. In presenza di modifiche, la scelta è esportare e aprire, scartare e aprire, oppure annullare. Il decode non distrugge la sessione precedente fino al successo; durante l'import le azioni di editing sono sospese anche nel model. Un export asincrono non marca come preservate modifiche successive allo snapshot renderizzato.

Input numerico e pulsanti usano le stesse trasformazioni del canvas e una modifica annullabile; un trascinamento dello slider rimane un solo passo di undo. Un pan bloccato al limite non invalida i timbri. Le guide della destinazione restano separate dalla griglia. Il clone offre coordinate percentuali con origine in basso a sinistra e contorno del raggio relativo al lato corto.

Le risorse italiane `.strings` sono incluse nei bundle SwiftPM dei rispettivi target. I testi dinamici UI usano `L10n`, gli errori del core Foundation senza dipendere da SwiftUI. Le etichette SwiftUI letterali usano il bundle principale, dove lo script copia tutte le cartelle `.lproj` UI e aggiorna le lingue dichiarate. Italiano è la lingua di sviluppo; altre traduzioni richiedono risorse e collaudo dedicati.
