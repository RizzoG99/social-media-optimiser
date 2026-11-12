# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

Le regole di contributo stanno in `AGENTS.md` (importato sopra) e non vanno ripetute qui. Questo file aggiunge comandi e architettura trasversale. Documentazione, commenti e UI sono in italiano.

## Comandi

```sh
swift test --enable-code-coverage          # suite completa (richiesta per cambi di codice)
./scripts/build-app.sh                     # build release → .build/SocialFrame.app, firmata ad hoc
open .build/SocialFrame.app                # un'istanza già aperta non carica il nuovo binario
swift test list                            # identificatori dei test
swift test --filter HorizonScenarioTests   # una classe
swift test --filter SocialFrameTests.EditorModelTests/testCropUndoRedoAndNewEditInvalidatesRedo  # un metodo
```

- `SOCIALFRAME_FIXTURE_OUTPUT=<dir> swift test --filter HorizonScenarioTests` scrive campioni prima/dopo dell'autolivellamento in una cartella a scelta, senza toccare quelli versionati in `output/fixtures/`.
- Nessun linter configurato. Nessuna dipendenza esterna.
- Nel sandbox di Claude Code, `swift build`/`swift test` falliscono con `sandbox-exec: sandbox_apply: Operation not permitted` (SwiftPM avvia un proprio sandbox per il manifest): vanno eseguiti fuori dal sandbox.
- La CI (`.github/workflows/ci.yml`) fissa Xcode 27.1 build 27A9275 via `DEVELOPER_DIR` e fallisce se la versione differisce. Cambiare toolchain significa aggiornare insieme workflow e `docs/ci.md`.

## Architettura

Due target SwiftPM: `SocialCore` (libreria, motore immagini senza UI) e `SocialFrame` (eseguibile SwiftUI). I test di `SocialFrameTests` importano l'eseguibile e lavorano su `EditorModel`, non su XCUITest.

### Motore (`Sources/SocialCore`)

- `ImageDocument` (`ImagePipeline.swift`) controlla peso del file, megapixel e lato massimo **prima** del decode, poi applica l'orientamento EXIF una sola volta nel `CIImage` interno. Tutto il resto lavora sull'immagine già orientata.
- `ImageRenderer.render(document:preset:edit:maxPixelSize:)` è l'unico percorso geometrico: l'anteprima lo chiama con `maxPixelSize: 1400`, l'export a piena risoluzione. Scala minima di riempimento, rotazione (quarti + raddrizzamento, antiorari), clamp del pan e timbri clone sono calcolati qui. `panned(...)` converte uno spostamento in coordinate schermo nel pan in coordinate sorgente con gli stessi limiti. Le due funzioni duplicano la matematica di scala/limiti: modificarle insieme.
- `EditState` è l'intera modifica non distruttiva (pan, zoom, raddrizzamento, quarti di giro, `cloneStrokes`). `Preset.all` è il catalogo delle dimensioni.
- `AutoLevelEstimator` (`AutoLevel.swift`) esegue `VNDetectHorizonRequest` su un render ridotto senza timbri; `HorizonRefinement` corregge il residuo su un bordo dominante. Soglie e motivazioni in ADR-009.

### App (`Sources/SocialFrame`)

- `EditorModel` (`@MainActor`) è lo stato dell'editor. Undo/redo **non** usa `UndoManager`: è uno stack personalizzato di `Snapshot(edit, preset)` (max 100), con `checkpoint()` prima di ogni modifica annullabile. `applyGeometry` azzera i timbri solo se la geometria cambia davvero. `preservedSnapshot` indica cosa è già stato importato/esportato e decide se chiedere conferma prima di sostituire la foto.
- Risultati asincroni obsoleti si scartano confrontando il contatore `revision` e l'identità del documento (`self.document === document`); `documentGeneration` distingue le riaperture dello stesso URL.
- L'anteprima (`requestPreview`) è un unico worker che consuma lo stato più recente finché `revision` non si stabilizza (ADR-008). Non introdurre debounce né cancellazione dei frame.
- Lo stimatore dell'orizzonte è iniettato nell'`init` di `EditorModel`: i test lo sostituiscono per provare concorrenza e undo senza Vision.
- `EditorView` contiene canvas, gesti, inspector, toolbar e guide della destinazione. `CompositionGrid` è geometria normalizzata di sola presentazione, mai esportata.

### Dati legati che vanno aggiornati insieme

- **Preset:** dimensioni in `Preset.swift`, stato della specifica e URL fonte in `PresetInfo.swift`, guide/data in `EditorView.swift`, catalogo e fonti in `docs/preset-e-fonti.md`.
- **Localizzazione:** due `Localizable.strings` (`Sources/SocialCore/Resources/it.lproj` per gli errori, `Sources/SocialFrame/Resources/it.lproj` per la UI). `L10n` legge `Bundle.module`; le etichette SwiftUI letterali leggono il bundle principale e si risolvono solo nel `.app`, perché `build-app.sh` vi copia le cartelle `.lproj`. Dettagli in `docs/localizzazione.md`.

## Documentazione e procedure

- `docs/adr.md` motiva le scelte (ADR-001…010); `docs/requisiti-prodotto.md` definisce i requisiti F-xx; `docs/scenari-test.md` gli scenari T-xx; `docs/verifica.md` registra le verifiche eseguite e i limiti.
- Le procedure in `.agents/skills/*/SKILL.md` non sono skill di Claude Code (lo Skill tool non le trova): leggere direttamente il file pertinente quando il compito riguarda pipeline immagini, interazione macOS o manutenzione dei preset.
