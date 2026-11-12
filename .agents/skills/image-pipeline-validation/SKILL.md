---
name: image-pipeline-validation
description: Validate SocialFrame image-processing changes to crop, pan, zoom, rotation, EXIF, auto-level, clone stamping, color conversion, and export with rendered-pixel regression scenarios. Use macos-interaction-validation for UI responsiveness rather than pixel correctness.
---

# Validare la pipeline immagini

Esegui i comandi dalla radice del repository. Leggi [AGENTS.md](../../../AGENTS.md), poi le decisioni pertinenti in [docs/adr.md](../../../docs/adr.md). Scegli gli scenari da [docs/scenari-test.md](../../../docs/scenari-test.md).

## Prova osservabile

1. Collega la modifica al codice in `Sources/SocialCore` e ai test in `Tests/SocialCoreTests`. Per analisi asincrone, undo e ripristino dei timbri controlla anche `AutoLevelModelTests` ed `EditorModelTests` in `Tests/SocialFrameTests`.
2. Per una regressione costruisci un caso che distingua il comportamento errato dall’atteso. Verifica i pixel renderizzati: confrontare soltanto formula o parametri non prova il verso effettivo della rotazione.
3. Per autolivellamento riusa `HorizonScenarioTests`: copre inclinazioni note nei due versi, angolo nello stato e nuova importazione del file già storto. La misura del bordo cielo/mare è indipendente da Vision. Non allargare le tolleranze per far passare il test senza una motivazione e nuove evidenze.
4. Per crop/pan verifica i pixel ai bordi con rotazione e spostamento estremo: il solo alpha non rivela buchi nascosti dal fondo bianco. Per import/export controlla EXIF, dimensioni decodificate, formato effettivo, profilo colore e integrità del sorgente. Leggi i limiti correnti nel codice.

## Esecuzione

Inizia dalla classe pertinente, per esempio `swift test --filter HorizonScenarioTests`. Per produrre campioni prima/dopo senza sovrascrivere quelli versionati:

```sh
socialframe_fixture_dir="$(mktemp -d /tmp/socialframe-fixtures.XXXXXX)"
printf 'Campioni: %s\n' "$socialframe_fixture_dir"
SOCIALFRAME_FIXTURE_OUTPUT="$socialframe_fixture_dir" swift test --filter HorizonScenarioTests
```

Usa lo strumento di visualizzazione immagini disponibile per ispezionare i campioni nel percorso stampato e confrontali con le misure; se non è disponibile, dichiara la verifica visiva non eseguita. I campioni sintetici non dimostrano affidabilità su tutte le fotografie o sui decoder disponibili: usa foto rappresentative se il difetto dipende dal contenuto.

Per modifiche di codice completa i controlli del progetto:

```sh
swift test --enable-code-coverage
./scripts/build-app.sh
```

## Evidenza finale

Riporta scenario, atteso, misure, comandi e limiti in [docs/verifica.md](../../../docs/verifica.md). Distingui test del renderer, scenari del model e prove UI. Mantieni aperto un problema segnalato dall’utente finché le prove pertinenti non lo risolvono: una suite verde non dimostra fluidità durante il tracking reale degli slider.
