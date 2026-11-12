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

## Autolivellamento e griglie — verifica finale

**29 test passati** (16 core, 13 UI/model/geometria), zero errori. Build release riuscita. I test coprono conversione del verso, soglia di confidenza, immagine uniforme senza orizzonte, una sola operazione di undo che ripristina anche i timbri, risultati asincroni invalidati da nuove modifiche e geometrie normalizzate di tutte le griglie.

Su richiesta dell’utente, aggiunta una fixture con orizzonte noto e varianti a ±8°. Il test iniziale ha rilevato una rotazione nel verso errato; la conversione delle coordinate e il successivo raffinamento sono stati corretti sulla base dei pixel, senza allargare la tolleranza del test. La sola stima Vision lasciava circa 2° di residuo. Il risultato finale misura 0° nei due scenari con angolo già nello stato; aprendo invece i file storti come nuovi originali misura circa 0,11° e 0°. Tolleranza di accettazione 1,5°; misure limitate dalla risoluzione. Artefatti prima/dopo in `output/fixtures/`.

Collaudo UI su copia separata: import del campione, menu con sei scelte, visualizzazione della griglia fitta e regolatore visibilità; Autolivella su immagine senza riferimento restituisce il messaggio previsto. Import del file `horizon-plus8-before.png`, comando Autolivella: angolo applicato circa −8,0°, orizzonte visivamente orizzontale anche nel preset verticale. Verificato a schermo con griglia dei terzi. L’undo del nuovo comando è verificato automaticamente; il collaudo export tramite dialogo non è stato completato in questa sessione (annullato il dialogo di prova), mentre pipeline ed export restano coperti dai test.

Restano necessari campioni fotografici reali con orizzonti irregolari, verticali dominanti, architettura e scarso contrasto. La confidenza Vision da sola non garantisce che l’orizzonte scelto sia quello desiderato; la correzione resta verificabile e annullabile.

## Correzioni audit UX/UI e testi — 12 novembre 2026

Piano in `piano-correzioni-ux.md`. Correzioni implementate e sottoposte a un nuovo agent per revisione indipendente dei sorgenti. Applicati tutti i cinque rilievi della revisione: blocco editing durante import anche nel model, contorno clone coerente passando alla tastiera/coordinate, pan nullo senza invalidazione dei timbri, reset sorgente clone alla nuova generazione del documento anche sullo stesso URL, copia di tutte le risorse linguistiche nel bundle. Al ricontrollo aggiunta anche una guardia nei callback di gesti già iniziati prima dell'import. La revisione dell'agent è statica, non un collaudo UI.

### Automatici e build

`swift test --enable-code-coverage`: **38 test passati**, zero errori (17 core, 21 model/geometria/UI di presentazione; nessun XCUITest). Log dell'ultima esecuzione in `.build/ux-final-tests.log`. `./scripts/build-app.sh`: build release finale riuscita; bundle `.build/SocialFrame.app` firmato ad hoc.

I nove nuovi test coprono: messaggio distinto per un PNG lungo 40.000×1 px sotto 120 MP; annullamento della sostituzione e conservazione della cronologia dopo un import fallito; snapshot effettivamente esportato rispetto alle modifiche successive; regolazioni numeriche con limiti, invalidazione e undo; pan tramite helper anche con rotazione; separazione griglia/guide; classificazione delle fonti; azioni bloccate durante import; pan senza movimento che conserva timbri e undo; nuova generazione riaprendo lo stesso URL. Alcuni scenari sono accorpati in un unico test.

`plutil -lint` riuscito sulle due risorse italiane `.strings` e sull'Info.plist. Verificata la presenza di `SocialFrame_SocialFrame.bundle` e `SocialFrame_SocialCore.bundle` nell'app, con risorse italiane; lingua di sviluppo e lingue supportate coerenti (`it`). Non è stata aggiunta né collaudata una seconda traduzione.

### App reale

Usate due copie isolate, `.build/SocialFrameUXReview.app` (`it.socialframe.uxreview`) e `.build/SocialFrameUXFinal.app` (`it.socialframe.uxfinal`), con nome riconoscibile e firma ad hoc. La sessione dell'app principale non è stata modificata. Campione: `Tests/SocialCoreTests/Fixtures/horizon-level.png`, 1024×768 px.

- Menu “Modifica”, “Vista”, “Finestra”, “Aiuto”, comando “Nascondi barra laterale” e pannelli “Apri”/“Salva” osservati in italiano. Il campo di ricerca nativo mantiene la propria etichetta AX di sistema “Search”.
- Apertura del PNG riuscita tramite pannello collegato alla finestra; il precedente limite del pulsante Apri disabilitato non si è ripresentato selezionando esplicitamente il file.
- Valore Livella digitato **0,3°**, slider coerente; Annulla riporta a 0°, Ripristina torna a 0,3°. Ripetuto nella build finale.
- Nella prima copia: attivazione clone, apertura “Posizione del timbro”, sorgente scelta con il pulsante, destinazione X impostata a 70%, applicazione senza clic sul canvas: compare “Elimina timbri (1)”. Etichette dei campi distinguono sorgente/destinazione e asse. Le azioni AX del canvas sono presenti; questo non certifica VoiceOver completo.
- Esportazione dalla prima copia completata nel pannello: `.build/ux-review-smoke.jpg`. Stato “Esportato … · 1080 × 1350 px”; controllo indipendente `sips`: **1080×1350, sRGB IEC61966-2.1**.
- Nell'inspector, impostazioni essenziali e comando Esporta restano visibili fuori dall'area scorrevole alla dimensione di finestra osservata. Fonti e dettagli esportazione sono espandibili.
- Nella build finale, tentativo di riaprire il campione dopo la modifica: compare la conferma con “Esporta e apri…”, “Scarta modifiche e apri”, “Annulla”. Annulla conserva foto e valore 0,3°.

Il secondo tentativo di completare “Esporta e apri” è stato interrotto dal cambio di sessione: alla ripresa la copia finale conteneva una diversa foto dell'utente. Nessuna ulteriore azione è stata inviata a quella sessione per preservarla. **Il ramo completo Esporta e apri attraverso entrambi i pannelli non è dichiarato verificato nella UI.** Export e protezione degli snapshot sono coperti dai test del model e dall'export UI precedente; la continuazione tra i due documenti richiede ancora un collaudo UI dedicato.

Restano da provare VoiceOver completo, navigazione esclusivamente da tastiera lungo l'intero flusso, il contorno clone nel passaggio puntatore→tastiera sulla build finale, guide YouTube con griglia disattivata a schermo, trackpad fisico e trascinamento continuo degli slider con una foto Fujifilm rappresentativa. Nessuna nuova misura di fluidità/FPS: il problema di reattività segnalato precedentemente resta aperto. Nessuna verifica aggiuntiva su macOS 14, Intel, dark mode o Riduci movimento.

## Compatibilità del compilatore CI — PR #1

Il runner `macos-15` con Xcode 16.4 interrompeva la compilazione di `HorizonRefinement.swift` prima dei test: la chiamata `pow` nel calcolo RMS era ambigua tra `CGFloat` e `Double`. La toolchain locale Xcode 27.1 non segnalava l'ambiguità. Il fit ora usa accumuli e coordinate convertiti esplicitamente in `Double`; i quadrati di varianza e residui usano moltiplicazione. Soglie, campionamento e algoritmo non sono stati cambiati. Anche `./scripts/build-app.sh` è riuscito dopo la correzione.

Rieseguiti `swift test --filter HorizonScenarioTests` e `swift test --enable-code-coverage`: tre scenari orizzonte e tutti i **38 test** passati. Residui: 0° nei due scenari con ±8° nello stato; circa 0,112° e 0° importando i campioni già inclinati. Stesse misure precedenti, tolleranza invariata a 1,5°. Campioni generati in `/private/tmp/socialframe-ci.rvpFk9`, senza sovrascrivere gli artefatti versionati; ispezionata visivamente la coppia +8° prima/dopo import, con orizzonte finale orizzontale. Nessun nuovo collaudo dell'interazione: questa correzione riguarda la risoluzione dei tipi nel calcolo numerico. L'esito remoto è consultabile nei check della PR.
