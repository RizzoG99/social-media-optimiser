# SocialFrame — istruzioni per contribuire

App macOS nativa SwiftUI, offline, macOS 14+, Swift 6 toolchain in modalità linguaggio Swift 5. Nessuna dipendenza esterna.

- Leggere `docs/requisiti-prodotto.md` e `docs/adr.md` prima di modificare il comportamento.
- `SocialCore` non dipende dalla UI. Le API di rendering devono usare la stessa geometria per anteprima/export.
- Non alterare gli originali. Applicare EXIF una volta; esportare sRGB, metadata originali esclusi e alpha su bianco.
- Pan è nel sistema del sorgente; usare `ImageRenderer.panned` per trascinamento nel sistema dello schermo. Clone: coordinate normalizzate del risultato con origine in basso a sinistra, raggio relativo al lato corto.
- Geometria/preset invalidano i timbri; l’intera modifica deve essere annullabile. Preset e timbri fanno parte dello snapshot di undo.
- Aggiornare insieme catalogo, fonti datate e documentazione. Distinguere raccomandazioni da requisiti ufficiali. Non promettere assenza di ricompressione da parte dei social.
- Import/render/export pesanti restano fuori dal MainActor; l’UI ignora risultati obsoleti. I dialoghi file sono asincroni e collegati alla finestra.
- Eseguire `swift test --enable-code-coverage` e `./scripts/build-app.sh` per cambi di codice. Aggiungere test che rilevino regressioni reali, non copie dell’implementazione.
- Per modifiche all’interazione verificare anche UI reale (apri, modifica, annulla, esporta). Non dichiarare i test model come XCUITest. Annotare limiti di verifiche in `docs/verifica.md`.
- Non introdurre rete, telemetria, account, AI remota o caricamento social senza una richiesta esplicita.
