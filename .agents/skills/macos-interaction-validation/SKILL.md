---
name: macos-interaction-validation
description: Validate SocialFrame macOS interactions after changes to sliders, gestures, preview scheduling, animations, grids, async analysis, undo/redo, and native file dialogs. Exercise the real app and distinguish UI evidence from model tests. Excludes pixel-accuracy and social-specification maintenance.
---

# Collaudare le interazioni macOS

Lavora dalla radice del repository. Leggi [AGENTS.md](../../../AGENTS.md), gli scenari pertinenti in [docs/scenari-test.md](../../../docs/scenari-test.md) e i limiti delle verifiche precedenti in [docs/verifica.md](../../../docs/verifica.md).

## Preparazione

Per modifiche di codice esegui `swift test --enable-code-coverage` e `./scripts/build-app.sh`. Il bundle è `.build/SocialFrame.app`: il processo già aperto non carica automaticamente il nuovo eseguibile.

Individua la sessione attiva prima del collaudo. Non chiudere o sovrascrivere una sessione dell’utente con modifiche in memoria. Se serve isolamento, prepara una copia di test in `.build` con identificatore distinto, firma ad hoc e nome riconoscibile. Verifica di controllare il processo corretto; evita di ricompilarne il bundle durante la prova.

Usa gli strumenti UI disponibili e le API documentate. Attiva la finestra e rileggi lo stato dopo le azioni: menu e dialoghi cambiano gli identificatori accessibili. Se il controllo UI non è disponibile, registra il limite senza presentare i test del model come prova dell’interfaccia.

## Scenari pertinenti

Apri un campione, esercita la modifica, annulla/ripristina ed esporta una copia nella cartella di prova. Controlla il risultato dopo la chiusura del dialogo. Aggiungi le verifiche necessarie:

- **Slider/gesti:** trascina zoom e livellamento continuamente, anche invertendo direzione. L’immagine deve cambiare prima del rilascio o della pausa; il valore testuale aggiornato non basta. Controlla fotogramma finale e assenza di risultati di altre foto/preset.
- **Reattività:** Il metodo `testPreviewUpdatesWhileZoomAndStraightenKeepChanging` in `Tests/SocialFrameTests/EditorModelTests.swift` prova il flusso del model, non tracking AppKit, FPS o latenza sui JPG Fujifilm. Per lentezza usa un campione rappresentativo e, se necessario, registrazione o profilo prestazionale. Non dichiarare fluidità sulla sola base della suite verde.
- **Analisi asincrona:** avvia Autolivella e modifica la composizione prima della risposta. Il risultato precedente non deve sovrascrivere la nuova scelta; undo deve ripristinare angolo e timbri come una sola operazione.
- **Griglie/animazioni:** controlla allineamento, visibilità e hit testing dopo le transizioni. Rispetta “Riduci movimento”; non cambiare la preferenza di sistema dell’utente senza autorizzazione. Se la modalità non viene provata, distingui verifica del codice e prova a schermo.
- **Accessibilità:** per controlli nuovi/modificati verifica focus, etichette e scorciatoie pertinenti. Un identificatore accessibile non dimostra da solo un’esperienza VoiceOver corretta.

## Resoconto

In [docs/verifica.md](../../../docs/verifica.md) annota build/processo, campione e dimensioni, azioni, risultati osservati ed eventuali metriche. Distingui automatici, UI e prove mancanti. Se un dialogo blocca il percorso, indica il punto preciso senza dichiarare completato il flusso. Mantieni espliciti i difetti utente ancora aperti.
