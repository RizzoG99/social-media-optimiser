# Analisi — Set di foto con pellicola ed Esporta tutto

**Stato:** in sviluppo sul ramo `claude/elegant-archimedes-frp9h9` · **Data:** 18 novembre 2026 · **Requisiti:** F-11, F-12, F-13 · **Decisione:** ADR-014 · **Scenari:** T-17…T-27

> Testo preparato come issue GitHub. La creazione dell'issue è stata rifiutata dall'integrazione (HTTP 403: l'app GitHub non ha il permesso di scrittura sulle issue); questo file è la fonte versionata finché l'issue non viene aperta.

## Contesto e problema

Oggi SocialFrame lavora su **una foto alla volta**: per ogni scatto bisogna rifare File › Apri, e aprire una nuova foto sostituisce l'intera sessione (con conferma se non esportata). Chi prepara più scatti della stessa sessione ripete import ed export per ciascuno.

**Obiettivo:** importare un insieme di foto una volta sola, vederle in una **pellicola in basso** (come Adobe Lightroom), passare dall'una all'altra mantenendo le modifiche di ciascuna ed esportarle tutte in un colpo.

## Utenti e flusso

Creator o operatore apre più foto (selezione multipla, cartella o trascinamento), sceglie per ciascuna formato social e inquadratura, si sposta tra le foto con la pellicola o con ⌘← / ⌘→, controlla dai badge cosa è già esportato ed esporta tutto in una cartella.

## Requisiti funzionali

### F-11 Set di foto
- Import tramite selezione multipla nel pannello Apri (⌘O), scelta di una **cartella** (solo immagini al primo livello), trascinamento di più file.
- Con un set aperto: **Aggiungi al set / Sostituisci il set / Annulla**. Sostituire un set con foto non esportate richiede conferma esplicita.
- Un file già presente (stesso percorso risolto, anche via symlink) non viene aggiunto di nuovo. Nessun limite numerico.
- File illeggibili o oltre i limiti di F-01 saltati con messaggio riepilogativo; il resto del set e la foto attiva restano intatti.
- **Ogni foto conserva** modifiche (pan, zoom, livella, rotazione, timbri, nitidezza), **preset** e **cronologia annulla/ripristina**. Le nuove foto partono dal preset selezionato.
- Il cambio foto non chiede conferma e non perde nulla.
- Set **solo in memoria** (ADR-005). Uscire con foto modificate e non esportate mostra un avviso.
- Gli originali non vengono mai modificati.

### F-12 Pellicola
- Striscia orizzontale sopra la barra di stato con miniature del **risultato modificato**, aggiornate dopo le modifiche.
- Selezione evidenziata e sempre visibile nello scorrimento.
- Badge: **modificata e non esportata**, **esportata**. Etichette accessibili.
- **Rimuovi dal set** (Canc, menu contestuale, menu Immagine) con conferma se ci sono modifiche non esportate; il file su disco non si tocca.
- **⌘← / ⌘→** foto precedente/successiva; frecce semplici quando la pellicola ha il focus (sul canvas continuano a spostare l'inquadratura).
- Vista › Mostra/Nascondi pellicola, scelta ricordata.

### F-13 Esporta tutto
- File › Esporta tutto… (⌥⇧⌘E): cartella di destinazione; esporta **tutte** le foto, ciascuna con preset e modifiche proprie, nel **formato e qualità correnti dell'inspector**.
- Nome: `<nome originale>-<id preset>.<jpg|png>`.
- File omonimi già presenti: **un'unica domanda** Sostituisci / Mantieni entrambi (suffisso `-2`, `-3`, …). Nomi doppi nel set ricevono sempre un suffisso.
- Gli originali non vengono mai sovrascritti, anche tramite symlink/hard link (come F-06).
- Avanzamento in barra di stato; errori raccolti e riepilogati; le foto riuscite passano a "esportata".
- Resta l'export singolo (⇧⌘E) della foto attiva.

## Criteri di accettazione
- [ ] Import di 5 foto in un passaggio; tutte in pellicola con miniatura.
- [ ] Modificare la foto 1, passare alla 3 e tornare: modifiche, preset e cronologia della foto 1 intatti.
- [ ] Aggiungere un file già presente non crea doppioni.
- [ ] Aggiungi vs Sostituisci; Sostituisci con modifiche non esportate chiede conferma.
- [ ] Badge: modificata → esportata → di nuovo modificata.
- [ ] Rimuovere la foto selezionata seleziona la vicina; rimuovere l'ultima svuota l'editor.
- [ ] ⌘← / ⌘→ si fermano ai bordi; la pellicola si nasconde/mostra dal menu Vista.
- [ ] Esporta tutto: un file per foto con le dimensioni esatte del suo preset; conflitti con una sola domanda.
- [ ] Uscita con foto non esportate: avviso.
- [ ] Nessuna regressione su anteprima, ritaglio, clone, autolivellamento, export singolo.

## Decisioni prese con l'utente

| Tema | Decisione |
|---|---|
| Modifiche al cambio foto | Conservate per foto, con cronologia |
| Preset | Per foto |
| Export | Singolo + Esporta tutto in cartella |
| Persistenza | Solo memoria, avviso in uscita |
| Import | Multiselezione, cartella, drag & drop, scelta Aggiungi/Sostituisci |
| Pellicola | Badge, Rimuovi, ⌘←/⌘→, Mostra/Nascondi |
| Miniature | Risultato modificato |
| Esporta tutto | Tutte le foto, formato corrente; conflitti: una domanda Sostituisci/Mantieni entrambi |
| Limiti | Nessun limite, duplicati saltati |
| Lingua della documentazione | Italiano |

## Fuori perimetro
- Persistenza del set tra avvii.
- Copia/incolla o sincronizzazione delle impostazioni tra foto.
- Multiselezione nella pellicola, riordino, valutazioni/etichette.
- Sottocartelle nell'import di cartelle.

## Analisi tecnica e impatti
- **Modello:** `PhotoItem` (url, modifica, preset, cronologia, snapshot esportato, miniatura) in `Sources/SocialFrame/PhotoSet.swift`; `EditorModel` gestisce `items` e `selectedItemID`. Al cambio foto lo stato corrente viene salvato nell'item uscente e quello dell'item scelto ripristinato dopo la decodifica, fuori dal MainActor. Risultati obsoleti scartati cancellando il task di selezione e con `documentGeneration`/`revision`.
- **Memoria:** solo la foto attiva è decodificata; le altre hanno una miniatura (~160 px). Le miniature d'import si generano in sequenza; quella della foto attiva deriva dall'anteprima già calcolata.
- **Export in blocco:** `ExportPlan` (funzione pura, testata) calcola nomi e conflitti; esportazione sequenziale con `ImageRenderer.export` (stessa geometria, sRGB, alpha su bianco, metadata esclusi).
- **UI:** `FilmstripView` con componenti di sistema (ADR-013); comandi nei menu File/Vista/Immagine con le stesse condizioni di disabilitazione; dialoghi di sistema.
- **Documentazione:** requisiti F-11…F-13, ADR-014 (emenda ADR-005), scenari T-17…T-27, `verifica.md`, `CLAUDE.md`, localizzazione it/en.

## Rischi
- Stato ripristinato sulla foto sbagliata con cambi rapidi → task di selezione cancellabile e test dedicato.
- Memoria all'import di molte foto grandi → decodifica sequenziale, documento rilasciato dopo la miniatura.
- Conflitto con il pan da tastiera → ⌘←/⌘→ globali; frecce semplici solo con focus nella pellicola. Effetto collaterale: ⌘←/⌘→ non spostano il cursore nei campi dell'inspector.

## Test e verifica
- Test model in `Tests/SocialFrameTests/PhotoSetModelTests.swift` (non XCUITest).
- Su macOS: `swift test --enable-code-coverage`, `./scripts/build-app.sh`, collaudo reale degli scenari T-17…T-27. Esiti e limiti in `docs/verifica.md`.
