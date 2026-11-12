# Decisioni architetturali (ADR)

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

## ADR-006 — Interazione allineata alle HIG macOS

**Decisione:** usare pattern SwiftUI/macOS nativi, finestra ridimensionabile, canvas con input di precisione, sidebar nascondibile per i gruppi di preset e toolbar contenuta per le azioni frequenti.

**Motivo:** seguire le convenzioni di navigazione e comandi della piattaforma. La sidebar non deve diventare un contenitore di azioni essenziali; lasciare l’overflow alla toolbar di sistema. Riferimenti: [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars).

## ADR-007 — Animazioni dell’interfaccia

Transizioni SwiftUI ease-in-out di 180 ms per comparsa dell’anteprima, griglia, descrizione preset, stato e aperture dei gruppi clone/JPEG. Nessuna interpolazione dei pixel durante pan, zoom, livellamento o timbro; la geometria interattiva resta immediata. `accessibilityReduceMotion` disabilita animazioni e transizioni, anche nelle transazioni ereditate. Le animazioni non modificano il modello né l’export.

## ADR-008 — Anteprima continua durante le modifiche

Il debounce di 35 ms annullava il rendering a ogni nuovo evento e rimandava l’anteprima fino alla pausa dello slider. Ora un solo worker renderizza uno snapshot fuori dal MainActor e pubblica i fotogrammi intermedi dello stesso documento/preset, anche se nel frattempo sono arrivate altre modifiche. Poi acquisisce direttamente lo stato più recente, senza accodare ogni evento. Quando il flusso termina, completa il fotogramma finale. Risultati di altri documenti/preset vengono scartati. Nessun limite FPS garantito: il ritmo dipende dal costo del rendering e dall’hardware.
