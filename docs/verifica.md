# Verifica della versione 0.1

## Shell HIG (ADR-013) — 12 novembre 2026

Shell riscritta secondo la skill `macos-swiftui-pro`: titolo = nome del file, preset nel sottotitolo, toolbar di sistema (selettore segmentato; Ruota 90° e inspector; spaziatore fisso; Esporta prominente), sidebar `List` con `Section(isExpanded:)` e simboli del rapporto, inspector `Form` raggruppato, comandi vista e strumenti nei menu Vista e Immagine, barra di stato solo testuale. Le voci successive sulla shell (da "Liquid Glass" a "Controlli vista nella barra inferiore") sono resoconti storici della shell superata.

### Automatici e build

- `swift test --enable-code-coverage`: **50 test passati** (22 core, 28 SocialFrame; il 17 novembre, dopo la correzione del ritaglio), zero errori; log in `.build/shell-tests.log`. `./scripts/build-app.sh`: build release riuscita, bundle firmato ad hoc. Nessun avviso con `-warn-long-expression-type-checking=150` e `-warn-long-function-bodies=300`, usati come indizio per il limite del type checker. Toolchain locale Swift 6.4 / SDK MacOSX27.0, la stessa fissata dalla CI (Xcode 27.1, `docs/ci.md`): il ramo `#if compiler(>=6.2)` è quello compilato sia qui sia in CI. Il ramo per toolchain precedenti a Swift 6.2 non è compilato da nessun controllo.
- Nuovi test in `EditorShellTests`: passi della scala vista con limiti 10–400% e Adatta che azzera l'offset; simboli della sidebar coerenti col rapporto ed esistenti nel sistema; titolo finestra = file aperto (mai "SocialFrame") e sottotitolo con formato e pixel; ogni chiave passata a `L10n.text`/`L10n.format` presente in `it` ed `en`. Sono test del model e delle risorse, non XCUITest.
- `plutil -lint` riuscito sulle due risorse UI; parità chiavi/argomenti it/en coperta dal test esistente. Rimosse le chiavi rimaste senza uso con la vecchia shell.
- Identificatori accessibili rimossi con i rispettivi controlli: `open-image`, `undo-image`, `redo-image`, `view-zoom` (nessun test li usava). `editor-mode` è ora sul `Picker` segmentato.

### App reale

Copie isolate `.build/SocialFrameHIGShell.app` (`it.socialframe.higshell`, tema di sistema) e `.build/SocialFrameHIGShellLight.app` (`it.socialframe.higshelllight`, `NSRequiresAquaSystemAppearance` solo nella copia, per il tema chiaro con sistema in scuro), firma ad hoc, avviate dall'eseguibile con `-AppleLanguages` senza toccare le sessioni aperte dell'utente né le sue preferenze.

**Liquid Glass assente nelle build SwiftPM (13 novembre 2026).** Gli screenshot reali mostravano toolbar, sidebar e inspector con il design precedente a macOS 26. Causa: `swift build` (anche nelle copie precedenti, per esempio `SocialFrameGlassAudit.app`) registra in `LC_BUILD_VERSION` `sdk 14.0`, cioè il deployment target, invece dell'SDK usato (27.0); un binario compilato con `swiftc` sulla stessa macchina registra `sdk 27.0`. AppKit tratta quindi l'app come collegata prima di macOS 26 e ne disattiva il design di sistema. Correzione in `scripts/build-app.sh`: dopo la copia dell'eseguibile, `vtool -set-build-version macos <LSMinimumSystemVersion> <xcrun --show-sdk-version> -replace`, poi firma. Verificato con `vtool -show-build`: `minos 14.0`, `sdk 27.0`; `codesign --verify --strict` riuscito. Le build `swift build`/`swift test` senza lo script restano con `sdk 14.0` e non mostrano il vetro di sistema.

Osservato a schermo prima della correzione SDK (Retina 1020×732, it/en, tema scuro di sistema, finestra attiva): titolo "Nessuna foto"/"No Photo", selettore segmentato al centro, inspector in `Form` raggruppato senza etichette doppie e con etichetta "Opacità griglia", barra di stato solo testuale. Corretti due difetti: con tutti i gruppi chiusi la selezione della sidebar non era visibile (ora all'avvio si apre il gruppo del formato attivo) e in inglese l'inspector mostrava "1.080 × 1.350 px" con i separatori di locale (ora pixel senza separatore delle migliaia anche in barra di stato e messaggio di export).

**Screenshot con il vetro di sistema (13 novembre 2026, dopo la correzione SDK).** Tema chiaro (sistema in chiaro; `-AppleInterfaceStyle`/`-NSAppearanceName` non forzano lo scuro), italiano e inglese, 1020×732 e dimensione iniziale 1280×820. Senza Accessibilità la foto è stata aperta con un aggancio temporaneo (`SF_PROBE_OPEN`/`SF_PROBE_TOOL` in `SocialFrameApp`, rimosso subito dopo e assente dal codice finale) che chiamava `model.open` e impostava lo strumento: le schermate mostrano gli stati Inquadratura, Ritaglia e Strumenti con `horizon-level.png` caricato, non un'interazione dell'utente.

- Toolbar: con l'inspector dopo Esporta il pulsante prominente formava una capsula propria, quindi i gruppi erano quattro. Ora Ruota 90° e inspector condividono una capsula, Esporta (blu, `.glassProminent`) è da solo sul bordo trailing: tre gruppi con il selettore. Nessun vetro doppio sul pulsante prominente.
- Titolo e sottotitolo: con la piattaforma il sottotitolo era troncato anche a 1280 pt. Ora "Post verticale · 1080 × 1350" è intero alla dimensione iniziale 1280×820; alla minima 1020 il sistema lo tronca ("Post verticale · 1080 × 13…"), con formato e pixel completi nell'inspector.
- Sidebar con vetro di sistema, icone del rapporto colorate con l'accento e selezione persistente; inspector raggruppato con vetro sobrio; ritaglio con Annulla/Applica di sistema (Applica pulsante predefinito); timbro clone come interruttore; barra di stato "Originale caricato · 1024 × 768 px · Vista 77% · sRGB".

**Collaudo interattivo parziale (16 novembre 2026).** Copia isolata `.build/SocialFrameUITest.app` (`it.socialframe.uitest`, firma ad hoc), avviata dall'eseguibile con `-AppleLanguages '(it)'`, Accessibilità concessa. Eseguito nell'app reale, in italiano:

- pannello Apri con `Tests/SocialCoreTests/Fixtures/horizon-level.png`: la foto si carica e il titolo della finestra diventa il nome del file;
- abilitazione delle voci dei menu senza documento e con il documento aperto; nel menu Vista compare una sola voce per la barra laterale (il dubbio sul duplicato dopo `SidebarCommands` è chiuso);
- ⌃⌘I nasconde e mostra l'inspector e il titolo della voce di menu si aggiorna;
- in Ritaglia compaiono le 8 maniglie e i pulsanti Annulla/Applica.

**Correzione "Inspector Hide".** `InspectorCommands` aggiungeva al menu Vista la voce di sistema "Inspector Hide", non tradotta in italiano. Sostituita da un comando proprio in `EditorCommands`, "Mostra inspector"/"Nascondi inspector" (it/en) con la stessa scorciatoia ⌃⌘I; la visibilità dell'inspector è ora `EditorViewState.inspectorVisible`, letta dalla finestra, dalla toolbar e dal menu. Verificato a schermo come sopra.

**Collaudo con computer use (17 novembre 2026).** Stessa copia `.build/SocialFrameUITest.app`, campione `horizon-level.png` (1024×768), preset Post verticale 1080×1350, finestra 1280×820. Trascinamenti con eventi reali del mouse sulle maniglie.

- **Maniglie del ritaglio (it/en): nessun difetto.** Trascinando la maniglia in alto a sinistra e quella in basso a destra il rettangolo si ridimensiona e l'app resta in Ritaglia. Il ritorno in Inquadratura del 16 novembre non si è riprodotto: era causato dagli eventi simulati, non dall'app.
- **Applica → annulla/ripristina (it/en).** Applica porta il campo Zoom a 123% (lato selezionato 0,81 del riquadro, rapporto atteso 1,23); Modifica › Annulla (⌘Z) lo riporta a 100%, Ripristina (⇧⌘Z) a 123%. Riaprendo Ritaglia la selezione parte dall'inquadratura corrente dentro il contesto più ampio.
- **Invio/Esc.** Esc annulla (Zoom invariato), Invio applica (Zoom 123% → 143%), anche con il focus nel campo numerico Livella dell'inspector (Esc annulla, Invio applica: 143% → 165%). ⌘2 apre Ritaglia.
- **Esporta (⇧⌘E)**, pannello nativo, dopo un ritaglio: `uitest-it.jpg` e `uitest-en.jpg` risultano 1080×1350, profilo `sRGB IEC61966-2.1` (`sips`). Il pannello parte dalla cartella della foto; per salvare fuori dalla cartella nascosta `.worktrees` la foto è stata aperta da una copia in una cartella temporanea. Prima della sostituzione compare la conferma "Esportare le modifiche prima di aprire un'altra immagine?".
- **Inglese** (`-AppleLanguages '(en)'`): toolbar Composition/Crop/Tools, inspector, Cancel/Apply, menu View, pannelli Open/Save in inglese; nessuna chiave italiana visibile.
- **Dimensione minima**: trascinando l'angolo la finestra si ferma a **1020×732**, non 1020×680. A questa dimensione titolo e sottotitolo ("horizon-level.png", "Portrait Post · 1080 × 1350") sono interi in inglese, il ritaglio mostra maniglie e Cancel/Apply, l'inspector scorre.
- **Difetto trovato e corretto — Livella durante il ritaglio.** Dopo aver trascinato una maniglia, un passo di Livella (+0,1°) scartava il rettangolo trascinato e mostrava il riquadro intero senza contesto attorno. Cause: `onChange(of: model.edit)` ricreava il ritaglio dall'inquadratura corrente; con un angolo diverso da zero `ImageRenderer.cropContext` ripiegava quasi sempre su "nessun contesto" (sul campione a 0,1° in 350–408 posizioni di pan su 441, a 0° mai), perché la vista più ampia veniva centrata sull'inquadratura e poi spostata dal limite del pan, calcolato sul riquadro di ingombro ruotato. Correzione: per ogni zoom, dal più ampio, `cropContext` prova prima la vista centrata e limitata (il comportamento precedente, esatto quando contiene la selezione) e, se la selezione ne esce, l'inquadratura ingrandita attorno a punti fissi dal centro verso gli angoli, accettando solo viste che il limite non sposta (contro un bordo, con rotazione, l'unico ingrandimento valido è attorno all'angolo che tocca il bordo); quando cambia solo la rotazione la vista passa a `EditorModel.beginCrop(keeping:)` l'inquadratura della selezione trascinata, riportata nel nuovo contesto (spostata dentro se ne esce entro lo 0,5%). Test: `testCropContextStaysWiderWithSmallStraightenAgainstEdges` (0,1°/1°/5°, pan contro ciascun bordo, contesto più ampio e ritorno esatto all'inquadratura; per inquadrature interne il contesto resta a zoom 1 anche a 0°) e `testStraightenDuringCropKeepsDraggedSelection`. Verificato nell'app ricompilata con la versione finale: selezione trascinata, Livella 0,1° e 0,2°: rettangolo e contesto restano, Invio applica Zoom 148% con l'orizzonte nella stessa posizione del rettangolo trascinato. Annulla esce dal ritaglio ma, come prima, non annulla il passo di Livella (si annulla con ⌘Z).
- **Da controllare**: il menu letto via accessibilità senza aprirlo riporta "Mostra barra laterale"/"Show Sidebar" con la barra laterale visibile (il pulsante in toolbar dice correttamente "Nascondi barra laterale"); può essere un titolo aggiornato solo all'apertura del menu. Il comando Annulla del menu Modifica si chiama "Annulla", non "Annulla modifica".

Non sono stati provati con la UI: slider trascinati con continuità, VoiceOver, flusso completo da tastiera (Tab tra i controlli), tema scuro, Riduci trasparenza/movimento (preferenze di sistema non modificate).

### Quality gate della skill

- Verificati nel codice: nessun `glassEffect`, `sharedBackgroundVisibility` o `.glass` sui comandi; tre gruppi in toolbar; una sola azione prominente trailing; ogni elemento della toolbar anche nei menu con stessa disabilitazione; titolo/sottotitolo; nessuna intestazione nel canvas e nessun controllo nella barra inferiore; `List` + `Label`; `Form` `.grouped` con un'etichetta per ogni controllo; ramo macOS 14/15 completo (stili `.borderedProminent` e gruppi senza spaziatore).
- Verificati a schermo: livelli (vetro solo su toolbar, sidebar e inspector; foto senza effetti), tre gruppi in toolbar, unica azione prominente trailing senza vetro doppio, titolo/sottotitolo, sidebar, inspector, tema chiaro, italiano e inglese, larghezza minima e dimensione iniziale.
- **Verificati nell'app reale (16 novembre 2026)**: pannello Apri e titolo, abilitazione dei menu, una sola voce barra laterale nel menu Vista, ⌃⌘I con titolo aggiornato, 8 maniglie del ritaglio.
- **Verificati nell'app reale (17 novembre 2026)**: trascinamento delle maniglie; ritaglio applicato → ⌘Z/⇧⌘Z con il campo Zoom; Invio/Esc del ritaglio, anche con il focus nel campo Livella; Esporta (⇧⌘E) con file 1080×1350 sRGB; inglese; dimensione minima (1020×732).
- **Aperti**: Autolivella durante il ritaglio (stesso percorso di Livella, non provato a schermo); altezza minima 732 invece dei 680 di ADR-013; titolo della voce barra laterale nel menu Vista; tema scuro con il vetro (solo screenshot precedenti alla correzione SDK); Riduci trasparenza, Aumenta contrasto, Mostra bordi, Riduci movimento; VoiceOver; flusso completo da tastiera; scorciatoia ⌘+ su layout di tastiera USA (dichiarata come "+").

### Audit `macos-ui-audit` — rilievi rimasti

Sugli screenshot con il vetro (Inquadratura 1280×820 e 1020×732, Ritaglia, Strumenti; chiaro, it/en). Nessun rilievo critico o alto: gli anti-pattern della tabella in `editor-shell.md` non compaiono più.

- **Media — Sottotitolo troncato alla larghezza minima.** A 1020 pt il selettore centrale lascia circa 135 pt a titolo e sottotitolo. Regola: [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), non progettare layout che vanno in overflow di default. Opzioni: larghezza minima intorno a 1120 pt oppure accettare il troncamento di sistema (dati completi nell'inspector).
- **Media — Righe Zoom/Livella composte a mano.** Campo, unità, reset e −/+ su due righe; i pulsanti −/+ hanno larghezze diverse. Regola: Adopting Liquid Glass, liste e form con controlli di sistema; giudizio in parte di gusto. Correzione: `LabeledContent` con `TextField` e `Stepper`, slider sotto, reset con doppio clic sullo slider (già presente) o menu contestuale.
- **Bassa — Due controlli colorati durante il ritaglio.** Applica (pulsante predefinito) ed Esporta (prominente) sono entrambi blu. Regola: [Color](https://developer.apple.com/design/human-interface-guidelines/color), colorare solo l'azione primaria. Accettabile perché Applica è l'azione predefinita del contesto modale del ritaglio.
- **Bassa — Icona personalizzata dello strumento clone.** `CloneToolIcon` appare grigia accanto a simboli SF. Regola: [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)/[Menus](https://developer.apple.com/design/human-interface-guidelines/menus), simboli familiari. Scelta di prodotto documentata nei requisiti; nessun simbolo SF equivalente al timbro clone.
- **Non verificabile dagli screenshot:** tema scuro con il vetro, Riduci trasparenza, Aumenta contrasto, Mostra bordi, Riduci movimento, VoiceOver, focus da tastiera, contenuto dei menu Vista e Immagine.

## Liquid Glass — 12 novembre 2026 (storico, superato da ADR-013)

Shell aggiornata con toolbar unificata e tre capsule per zoom, modalità e comandi; selezione delle modalità arrotondata, gruppo inferiore per controlli vista e pulsanti d’azione glass nativi. Sidebar di sistema; inspector con fondo semantico opaco. Il titolo della finestra rimane SocialFrame ma non occupa la toolbar sui sistemi che consentono di rimuoverne il solo elemento visivo.

`swift test --enable-code-coverage`: **44 test passati**, zero errori; `./scripts/build-app.sh`: release riuscita, target minimo macOS 14 invariato. Log `/tmp/socialframe-glass-tests.log`, `/tmp/socialframe-glass-build.log`. Nessun test duplicativo per la sola resa dei materiali. Nuove API glass protette da availability macOS 26 e guardia compilatore Swift 6.2; fallback material/bordered sui sistemi precedenti. Fallback e Riduci trasparenza verificati nel codice, non su un secondo sistema o cambiando le preferenze dell’utente.

UI reale nelle copie isolate `.build/SocialFrameGlassReview.app` e `.build/SocialFrameGlassFinal.app` (`it.socialframe.glassreview`, `it.socialframe.glassfinal`), Retina/inglese/tema scuro. Nessuna sessione preesistente modificata. Nella prima copia è stato individuato un problema di nomi AX ereditati dal gruppo toolbar: risolto con etichette esplicite. Nella copia finale osservati nomi distinti Open, Undo, Redo, Rotate 90°, Export e nome finestra SocialFrame.

Campione `horizon-level.png`, 1024×768: apertura tramite pannello riuscita; attivata Crop, osservate maniglie e capsule glass; trascinata la maniglia superiore sinistra e applicato il ritaglio (zoom circa 112%); Undo torna a 100%. Export dalla capsula toolbar completato tramite pannello nativo in `.build/liquid-glass-review.jpg`; stato di successo osservato, file controllato con `sips`: **1080×1350, sRGB IEC61966-2.1**. La barra inferiore si dispone su due righe quando il messaggio di export è lungo, mantenendo i controlli leggibili.

Restano da provare tema chiaro, Riduci trasparenza/Riduci movimento a schermo, VoiceOver completo, navigazione completa da tastiera, macOS 14/15 e toolchain precedente. Le transizioni rispettano la policy Riduci movimento esistente; nessun valore di FPS o fluidità è certificato. I materiali UI non modificano i pixel esportati.

## Schede e toolbar ispirate a Foto — 12 novembre 2026

Questa revisione supera la precedente collocazione di crop/rotazione come pulsanti dell’inspector. Ora le modalità Inquadratura/Ritaglia/Strumenti sono nella toolbar; lo slider della vista è in alto a sinistra e Ruota 90° è una sola icona a destra. Sfondo/Adatta/100% restano sotto l’immagine. La scheda Ritaglia ha controlli contestuali e nasconde lo slider della vista; la scheda Strumenti ospita il clone on/off.

`swift test --enable-code-coverage`: **44 test passati**, nessun errore; `./scripts/build-app.sh`: release riuscita. Log `/tmp/socialframe-tabs-tests.log` e `/tmp/socialframe-tabs-build.log`. Parità delle nuove risorse IT/EN inclusa nella suite.

Collaudo reale in `.build/SocialFrameTabsReview.app` (`it.socialframe.tabsreview`), Retina/inglese/tema scuro, fixture `horizon-level.png`:

- Selezionata Crop nella barra: maniglie e Apply/Cancel compaiono, inspector dedicato, slider della vista nascosto e Fit/100% disabilitati mentre il crop è provvisorio.
- Passaggio a Tools: maniglie rimosse, clone inizialmente off; attivato il clone e verificati contorno e istruzioni. Tornando a Composition, il clone si disattiva e l’inspector mostra le regolazioni geometriche.
- Trascinato lo slider superiore della vista fino a circa 225%: zoom di composizione ancora 100%, Undo disabilitato. Fit torna alla scala adattata di circa 74%.
- Clic sull’icona Rotate 90°: orizzonte ruotato visibilmente e Undo abilitato. ⌘Z annulla la rotazione e disabilita nuovamente Undo.

Nessun nuovo export in questo ciclo di riordino UI. Restano da provare toolbar in overflow alla finestra minima, VoiceOver completo, monitor multipli e tutti i limiti elencati nei resoconti precedenti. Il crop resta vincolato al preset; non sono stati introdotti i rapporti liberi, filtri o correzioni prospettiche presenti nell’app di riferimento.

## Icona ritaglio e pulsante clone — 12 novembre 2026

Ritaglia ora è un pulsante con simbolo SF `crop`, tooltip, nome accessibile e stato selezionato durante il ritaglio. Clone usa un unico toggle in stile pulsante, con icona e testo, che sostituisce titolo duplicato e checkbox.

`swift test --enable-code-coverage`: **44 test passati**; `./scripts/build-app.sh`: release riuscita. Log `/tmp/socialframe-tools-tests.log`, `/tmp/socialframe-tools-build.log`. Nessun nuovo test per la sola presentazione.

UI reale nella copia isolata `.build/SocialFrameToolReview.app` (`it.socialframe.toolreview`), inglese/Retina/tema scuro: aperta `horizon-level.png`; clic sull’icona Crop mostra otto maniglie, Apply/Cancel e stato AX selezionato. Cancel ritorna all’editor. Primo clic Clone Tool: pulsante blu e valore AX on, compaiono istruzioni e raggio; secondo clic: valore off, controlli e contorno del timbro scompaiono. Undo resta disabilitato, perché attivare/disattivare strumenti non modifica l’immagine. Nessun nuovo export o test VoiceOver completo in questo ciclo; restano validi i limiti riportati sotto.

## Controlli vista nella barra inferiore — 12 novembre 2026

Sfondo, Adatta e 100% spostati dall’inspector alla barra sotto la foto, insieme allo stato dell’operazione e sRGB. Layout adattivo su due righe quando il messaggio e i controlli non entrano affiancati. Ritaglia resta nell’inspector.

Rieseguiti `swift test --enable-code-coverage` (**44 test passati**) e `./scripts/build-app.sh` (release riuscita). Log `/tmp/socialframe-status-tests.log` e `/tmp/socialframe-status-build.log`. Nessun nuovo test per il solo spostamento dei controlli.

UI reale nella copia isolata `.build/SocialFrameStatusReview.app` (`it.socialframe.statusreview`), inglese/Retina/tema scuro: aperta fixture `horizon-level.png`; osservati i tre controlli nella barra, 100% ingrandisce la vista senza cambiare il campo Zoom, Adatta ripristina l’immagine intera; selezionato White e sfondo bianco osservato. Nessuna nuova modifica geometrica: Undo resta disabilitato. Non ripetuto l’export per questa modifica di sola presentazione; il pannello ed export del ciclo precedente restano documentati sotto. Layout a due righe verificato nel codice, non in una nuova prova di ridimensionamento.

## Editor, ritaglio e inglese — 12 novembre 2026

Lavoro isolato in `.worktrees/editor-upgrade`, branch `feat/editor-upgrade`, base `c162d69`. Nessuna modifica ai sorgenti del checkout principale.

`swift test --enable-code-coverage`: **44 test passati**, zero errori (23 app/model/presentazione e 21 core; nessun XCUITest). Sei nuovi test coprono crop decentrato sui pixel con quattro rotazioni e livellamento, selezioni invalide, ricostruzione dal contesto allargato, nitidezza, undo/clone/cancel e parità chiavi/placeholder inglesi. `./scripts/build-app.sh`: release riuscita, bundle `.build/SocialFrame.app` firmato ad hoc. Log della sessione: `/tmp/socialframe-tests.log`, `/tmp/socialframe-build.log`. Risorse inglesi e Info.plist passano `plutil -lint`.

Collaudo reale tramite copie isolate `SocialFrameEditorReview.app` e `SocialFrameEditorFinal.app`, con identificatori distinti. Sessioni preesistenti non toccate. Campione del repository `horizon-level.png`, 1024×768. Ambiente osservato: Apple Silicon, Retina, tema scuro, app inglese e numeri con locale italiana.

- Accordion inizialmente chiusi; Instagram aperto e preset corrente evidenziato.
- Maniglia superiore sinistra trascinata verso l’interno; oscuramento esterno e proporzioni conservate. Applica porta zoom a circa 116%; Undo torna a 100%.
- Doppio clic foto modifica la vista; zoom di composizione invariato a 100%.
- Il primo collaudo ha rilevato reset del model con indicatore slider fuori sincronia. Corretto il tracking AppKit; sulla build finale doppio clic da 101% riporta campo a 100% e slider a 1. Undo torna direttamente a 101% senza valore intermedio.
- Sfondi White e Black selezionati; Black osservato a schermo. Gray è il default. Screen Sharpening selezionato su Low.
- Export completato nel pannello nativo: `.build/editor-upgrade-review.jpg`. Stato finale di successo e controllo indipendente `sips`: **1080×1350, sRGB IEC61966-2.1**.
- Pulsanti geometrici con larghezza/stile uniformi e unità zoom percentuale separata dal reset. Corretta la traduzione Undo, distinta da Cancel dei dialoghi.

Limiti: non certificati VoiceOver completo, tutti gli otto handle via UI, cursori in ogni transizione, Spazio+drag su monitor multipli, trackpad fisico, Riduci movimento, tema chiaro, macOS 14/Intel e foto Fujifilm ad alta risoluzione. Italiano verificato nelle risorse e nei placeholder, senza un nuovo giro UI completo in italiano. Clone verificato nei nuovi scenari model; il suo intero flusso UI non è stato ripetuto. Nessuna misura FPS/latency: la precedente segnalazione di fluidità resta aperta. I campioni sintetici non sostituiscono la valutazione della nitidezza su fotografie reali.

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

### Secondo errore di compilazione: canvas SwiftUI

Con il fit numerico compilato, entrambi i job successivi sono arrivati a `EditorView.canvas`, fermandosi sul limite del type checker di Xcode 16.4. Il canvas è stato scomposto in viste opache per livelli, guide, decorazione, interazioni e accessibilità; anche i tre gesti sono definiti separatamente. Nessun uso di `AnyView`; coordinate, ordine dei modificatori, stato e azioni rimangono quelli precedenti. Le conversioni `CGFloat` del diametro del timbro sono esplicite.

Verifiche locali dopo il refactoring: **38 test passati**, `swift test --enable-code-coverage`, build release `./scripts/build-app.sh` e `git diff --check` riusciti. Non è installata localmente la toolchain Xcode 16.4: la conferma con quella versione richiede il check remoto.

Collaudo su nuova copia isolata `.build/SocialFrameCICanvas.app`, ID `it.socialframe.cicanvas`, senza modificare la sessione `SocialFrame UX Final` dell'utente. Aperto `horizon-level.png` 1024×768; zoom digitato a 2×, spostamento tramite azione accessibile del canvas e due undo distinti fino a 1×; clone attivato, scelta sorgente, spostamento destinazione e applicazione tramite azioni accessibili, con contatore di un timbro. Export dal dialogo completato in `.build/ci-canvas-smoke.jpg`, stato 1080×1350 px. Restano i limiti già elencati per trackpad fisico, fluidità, VoiceOver completo e macOS minimo; questa prova non è un XCUITest.

## Blocco all'apertura di più foto dalla scheda SD

Segnalazione: dopo la nuova shell (cb7cf1c) l'app si bloccava aprendo più foto dalla scheda SD Fujifilm (exFAT, JPG 4160×6240 e RAF). Il motore non è la causa: misurati circa 0,1–0,2 s per decodificare un JPG da 17 MB e 0,8 s per un RAF, con il main thread mai fermo oltre 130 ms nel test del model.

Causa riprodotta nell'app reale aprendo più file insieme (`open -a … file…`, equivalente a Apri con / trascinamento sull'icona nel Dock): `WindowGroup` creava una finestra per ogni file, tutte sullo stesso `EditorModel`/`EditorViewState`, ripristinate anche al riavvio. Con 20 file: 4+ finestre, CPU ~50% per oltre 20 s, campione del main thread occupato per circa il 90% in aggiornamenti del grafo SwiftUI e layout delle finestre; con una modifica non esportata, una finestra di conferma per finestra, sovrapposte. Inoltre `importTask?.cancel()` non fermava la decodifica in `Task.detached`: ogni richiesta leggeva l'intero file.

Correzione: scena `Window` unica; un solo worker di import che decodifica l'ultima richiesta (come l'anteprima, ADR-008), scarta i risultati e gli errori già superati. Test `ImportBurstTests`: 20 aperture consecutive producono al più 2 decodifiche, mostrano solo l'ultimo file e nessun errore di un file sostituito.

Collaudo nella build `.build/SocialFrame.app` con 20 file della scheda: una sola finestra, CPU a riposo entro ~2 s; con modifica pendente una sola conferma, “Scarta modifiche e apri” carica la nuova foto. Con la scena `Window`, SwiftUI consegna a `onOpenURL` un solo URL per apertura multipla: si apre una foto, le altre sono ignorate. Non provato il trascinamento diretto di più file sul canvas (usa già solo il primo URL) né il pannello Apri, che non consente selezione multipla. Non è un XCUITest.

## Reattività del trascinamento della foto

Segnalazione: trascinando la foto l'inquadratura segue in ritardo e accanto a “Originale caricato” lampeggia l'indicatore di attività.

Misure (JPG Fujifilm 4160×6240 dalla scheda SD, zoom 200%, copia isolata `.build/SocialFramePerf.app`, ID `it.socialframe.perf`, trascinamenti sintetici con computer use e `sample`):

- Il rendering non è il collo di bottiglia per i JPG: nel model 120 eventi di pan a 120 Hz producono 120 fotogrammi; un fotogramma 1400 px costa circa 1,6–3 ms.
- Il main thread era occupato quasi sempre (76 campioni liberi su 3857). L'indicatore nella barra di stato compariva e scompariva a ogni fotogramma, cambiando l'altezza del canvas (739↔742 pt), quindi `fitScale`, `viewState` e il layout dell'intera finestra (`NSDisplayCycleFlush` 1199 campioni).
- `EditorCommands` osservava l'intero `EditorModel`: ogni evento ricostruiva scena e barra dei menu.

Correzioni: posto fisso per l'indicatore; `isRendering` non è più pubblicato e l'indicatore (`showsRenderProgress`) compare solo per rendering oltre 200 ms; i menu leggono `EditorMenuState`, che pubblica solo quando cambiano i valori che usano. Dopo: 2157 campioni liberi su 4575 nella stessa sequenza, layout 272 campioni. Test `PanResponsivenessTests`: nessun lampeggio dell'indicatore con rendering veloci; i menu non pubblicano a ogni evento ma seguono annulla/ripristina.

Limiti: la latenza evento→fotogramma con i trascinamenti sintetici (5–10 eventi) è troppo rumorosa per un confronto (~135 ms mediana in entrambe le build) e non è un dato di trackpad fisico. Resta il ricalcolo di `EditorView` a ogni modifica del model (circa 420 campioni), che richiede di separare canvas, sidebar e inspector. La build con la filmstrip in uso dall'utente non è stata misurata.

RAF (stesso scatto, 6240×4160): ogni fotogramma ricompone il RAW, circa 760 ms. Misurate le alternative: `kCGImageSourceShouldCacheImmediately` 500 ms (inutile); proxy 2048 px 2 ms (1 s di preparazione, qualità limitata oltre circa 1,5× di zoom); RAW sviluppato una volta in bitmap a piena risoluzione 12 ms (1,1 s e 103 MB all'import). Implementate entrambe (ADR-014). Con lo stesso RAF, trascinamento simulato a 120 Hz nel model (build release): 120 fotogrammi su 120 eventi sia a zoom 1 (proxy) sia a zoom 3 (originale sviluppato), contro circa 15 prima. Import: JPG 0,12–0,15 s, RAF 2–3,3 s (sviluppo 1,1 s, proxy 0,24 s). Test `PreviewProxyTests`: proxy solo oltre 3072 px, stessa inquadratura dell'originale (differenza media sotto 1,5 livelli su un gradiente), originale oltre la densità del proxy (byte identici), export identico all'originale e diverso dal proxy su un campione a righe di un pixel.

Collaudo nella copia isolata con `DSCF0898.RAF` e `DSCF0899.RAF`: anteprima corretta all'apertura, sostituzione senza conferma quando non ci sono modifiche. In un primo avvio la stessa copia ha mostrato per un istante una fascia bianca irregolare in basso e una modifica non esportata che nessuna azione di collaudo aveva prodotto; tre riaperture pulite e il controllo dei pixel nel model (nessuna fascia, nessuna modifica dopo l'import) non l'hanno riprodotta. Tre ulteriori avvii con la stessa sequenza dello script (build, avvio diretto del binario, `open -a` con il RAF) sono risultati puliti. La causa non è stata identificata; la finestra di collaudo compare davanti sullo schermo dell'utente e un clic involontario è possibile ma non dimostrato. Da ricontrollare se ricompare.

Nella stessa copia, con `DSCF0898.RAF`: zoom 200%, trascinamento, Modifica ▸ Annulla dalla barra dei menu riporta l'inquadratura precedente (comandi guidati da `EditorMenuState`). Export dal pannello File ▸ Esporta… in `~/Documents/socialframe-raf-export-check.jpg`: controllo `sips` **1080×1350, sRGB IEC61966-2.1**, stato “Esportato …”. Confronto export RAF prima/dopo in ADR-014. Non verificati: trackpad fisico, memoria con più RAF aperti in sequenza.
