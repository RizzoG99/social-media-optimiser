# Verifica della versione 0.1

Data: 12 novembre 2026. Ambiente locale: Apple Silicon, macOS 27.2.1, Xcode 27.1 / Swift 6.4. Deployment target macOS 14. Il funzionamento sul minimo macOS 14 e su Intel richiede verifica separata.

## Automatici

`swift test --enable-code-coverage`: **14 test passati, zero errori** (8 SocialCore, 6 EditorModel).

- Catalogo: 27 preset, ID unici, tutte le cinque piattaforme.
- Ogni preset esportato sia in JPEG sia in PNG: formato effettivo, dimensioni decodificate e profilo colore.
- Otto orientamenti EXIF: dimensioni e posizioni dei pixel.
- Rotazione, livellamento e pan estremo: campione uniforme rimane uniforme ai quattro angoli; il fondo bianco non maschera buchi nel crop.
- Anteprima ridotta, timbro clone e spostamento sotto rotazione.
- Import corrotto, parametri invalidi, protezione dell’originale anche via hard link; dati sorgente invariati.
- Undo/redo, nuovo ramo di cronologia, reset, preset e ripristino dei timbri invalidati.
- Scenario asincrono completo: import, anteprima, modifica, export e successivo import fallito che conserva la foto già aperta.

I test generano fixture sintetiche deterministiche. Non costituiscono prova di ogni decoder disponibile in ImageIO né copertura completa dell’interfaccia. GitHub Actions configura gli stessi test e la build su macOS; l’esecuzione remota non è stata avviata in questa sessione.

## Manuali eseguiti nell’app

- Avvio del bundle `.app`, sidebar preset, inspector e toolbar nativi.
- Apertura di PNG tramite selettore; anteprima con griglia e dimensioni sorgente corrette.
- Rotazione di 90°, abilitazione del clone, selezione sorgente e applicazione di un timbro.
- ⌘Z rimuove il timbro e abilita ripristina.
- Salvataggio JPEG da dialogo: feedback `Esportato socialframe-gui-smoke.jpg · 1080 × 1350 px`; controllo indipendente delle dimensioni con ImageIO/sips.
- Icona B generata, scelta dall’utente e inclusa come `.icns` nel bundle.

Durante il collaudo sono stati sostituiti i dialoghi sincroni con dialoghi asincroni collegati alla finestra visibile ed è stata esplicitata la selezione dei file. È stata corretta una duplicazione dell’elemento accessibile nell’anteprima con il marcatore clone.

## Da verificare prima di una release pubblica

- Sessioni estese con JPEG Fujifilm reali da 40,2/102 MP; limiti 120 MP/512 MB sono implementati ma non provati con ogni modello di fotocamera.
- Gesto a pizzico e trascinamento fisico su trackpad, trascinamento da Finder, navigazione da tastiera, VoiceOver completo, dark mode e diverse dimensioni display.
- HEIC, TIFF e specifici RAW su ciascuna versione macOS supportata; il supporto dipende da ImageIO.
- Caricamento reale su tutti i social e verifica dei limiti in byte: l’app controlla dimensioni/formato, non impone ancora un limite di peso specifico per destinazione. JPEG a qualità inferiore può essere necessario. PNG e JPEG non possono garantire assenza di ricompressione.
- Firma Developer ID, hardened runtime e notarizzazione per distribuzione ad altri Mac. Il bundle locale è firmato ad hoc.
- UI end-to-end automatizzata con XCUITest: questa versione automatizza motore e scenari del model, con collaudo UI manuale separato.

## Aggiornamento animazioni

Build e 14 test automatici superati dopo l’introduzione delle transizioni. Collaudo UI: import campione PNG, selezione preset 3:4, apertura controlli clone, disattivazione griglia, passaggio JPEG→PNG, annullamento del cambio preset ed export `animation-smoke.png` 1080×1350. Le animazioni sono limitate alla presentazione; nessun cambiamento alla pipeline immagini. “Riduci movimento” è gestito tramite ambiente e transazione SwiftUI; la preferenza di sistema non è stata cambiata durante il collaudo e la temporizzazione delle animazioni non è misurata da un test automatico.

## Correzione anteprima continua

15 test passati (8 core, 7 model), build release riuscita. Nuovo test: 80 variazioni di zoom e livellamento a intervalli di 8 ms; verifica più fotogrammi già a metà del flusso, prima che lo slider si fermi, e confronto dei pixel finali con il renderer. Copre la regressione del precedente debounce di 35 ms.

Tentato collaudo UI su copia con bundle ID separato per preservare la sessione aperta dell’utente: avvio riuscito, ma selettore del campione PNG rimasto disabilitato. Copia chiusa; non dichiarare verificato il trascinamento fisico degli slider in questa sessione. La verifica continua e dei pixel finali è automatizzata a livello del model; nessuna misura FPS su originali Fujifilm reali.

### Riscontro utente dopo la correzione

L’utente segnala che l’interazione con zoom e livellamento non appare ancora reattiva. La correzione elimina il debounce e il test dimostra la produzione di fotogrammi durante un flusso di modifiche al model, ma non verifica la fluidità del trascinamento nel run loop AppKit né le prestazioni sulle foto reali. Il problema di reattività resta aperto e richiede una verifica durante il tracking effettivo degli slider; non considerarlo risolto sulla sola base dei test passati.
