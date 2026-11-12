# SocialFrame

Editor nativo macOS per preparare le proprie foto per Instagram, YouTube, Facebook, LinkedIn e X (Twitter). SwiftUI, elaborazione offline con ImageIO/Core Image, macOS 14 o successivo. Nome provvisorio.

## Avvio

Servono Xcode 16+ oppure Command Line Tools con Swift 6 e SDK macOS.

```sh
swift test --enable-code-coverage
./scripts/build-app.sh
open .build/SocialFrame.app
```

Puoi anche aprire `Package.swift` in Xcode, selezionare l’eseguibile SocialFrame e premere Run. Il bundle locale è firmato ad hoc: non è ancora una distribuzione notarizzata per altri Mac.

## Utilizzo

1. Apri una foto con ⌘O o trascinala nella finestra.
2. Scegli piattaforma e destinazione dalla barra laterale.
3. Trascina la foto per comporre il ritaglio, usa il gesto a pizzico o lo slider per lo zoom. Livella con lo slider oppure premi **Autolivella** per una stima locale dell’orizzonte; controlla il risultato e annullalo con ⌘Z se necessario. Scegli fra terzi, sezione aurea, centro, diagonali e griglia fitta, oppure nessuna guida; regola la visibilità delle linee. Ruota a passi di 90°.
4. Per piccole distrazioni attiva **Timbro clone**: primo clic sulla sorgente, poi clic sull’elemento da coprire. ⌥ clic sceglie una nuova sorgente; lo slider regola il raggio. Il timbro copia una zona con bordo sfumato, non ricostruisce automaticamente il contenuto. Cambiare inquadratura o preset azzera i timbri; ⌘Z ripristina lo stato precedente.
5. Scegli JPEG/PNG e salva una copia con ⇧⌘E. ⌘Z e ⇧⌘Z annullano/ripristinano anche i cambi di preset.

L’originale non viene sovrascritto. Le modifiche sono mantenute in memoria durante la sessione: prima di chiudere, esporta il risultato. L’export ha dimensioni esatte e colori sRGB; le trasparenze sono composte su bianco, anche in PNG. I metadati del sorgente, inclusa la posizione GPS, non sono copiati.

## Formati e limiti

Importazione dei formati decodificabili da ImageIO sul Mac in uso (JPEG, PNG, HEIC, TIFF e altri supportati dal sistema); non tutti i RAW o formati fotografici esistenti sono garantiti. Per file multipagina/animati viene elaborata la prima immagine. Limiti operativi: 512 MB e 120 milioni di pixel in ingresso; 40 milioni di pixel in uscita. L’anteprima è limitata a 1400 px sul lato lungo e usa la stessa composizione dell’export.

JPEG usa compressione con perdita. Ridimensionamento, ingrandimento e conversione colore possono modificare i pixel; i social possono applicare ulteriore compressione e ritagli. Le misure dei preset sono target pratici, non garanzie di caricamento universali. Profili mostrati con guida circolare indicativa, esportati quadrati. Storie/Reel/Shorts producono immagini statiche, non video.

## Qualità e documentazione

- [Requisiti di prodotto e funzionali](docs/requisiti-prodotto.md)
- [Decisioni architetturali](docs/adr.md)
- [Preset e fonti ufficiali](docs/preset-e-fonti.md)
- [Scenari e accettazione](docs/scenari-test.md)
- [Proposte icona](output/icons/concepts.png): scelta B, foto sovrapposte su blu.

`Sources/SocialCore` contiene il motore indipendente dalla UI; `Sources/SocialFrame` l’app SwiftUI. `Tests` include test di geometria, orientamento, codifica, timbro, protezione degli originali e scenari di annulla/ripristina. GitHub Actions esegue test e build su macOS a ogni push/PR. Le verifiche di interfaccia, VoiceOver e caricamento reale sui social restano elencate separatamente dagli scenari automatici.

Versione iniziale: nessun catalogo persistente, salvataggio progetti, export batch, pubblicazione social o servizio AI.
