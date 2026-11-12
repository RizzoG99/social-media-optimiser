# Requisiti prodotto — Social Media Optimiser

**Stato:** baseline iniziale · **Prodotto:** SocialFrame · **Piattaforma:** macOS 14+ · **Lingua UI:** italiano · **Icona scelta:** concept B

## Scopo

App nativa offline per preparare una singola immagine sorgente in copie esportate adatte a formati social comuni. Il prodotto semplifica dimensionamento e composizione; non pubblica contenuti e non può garantire che una piattaforma accetti un file, lo mostri identico o non lo ricomprima.

## Utenti e flusso

Creator o operatore seleziona un’immagine, sceglie una piattaforma e un formato (post, profilo, copertina/banner), regola l’inquadratura, vede un’anteprima della tela e salva una copia.

## Requisiti funzionali

- **F-01 Importazione:** aprire JPEG e PNG tramite selettore file; conservare il sorgente intatto. Gestire errori di file illeggibile e dimensioni non supportate con messaggi comprensibili.
  Prima di sostituire una foto con modifiche non esportate, offrire esportazione, scarto esplicito o annullamento. Durante l'importazione sospendere le azioni di editing; un import fallito conserva immagine, modifiche e cronologia precedenti. L'esportazione preserva soltanto lo snapshot effettivamente renderizzato.
- **F-02 Preset:** elencare preset distinti per destinazione e rapporto d’aspetto. Ogni preset mostra pixel risultanti, rapporto, formato esportato e provenienza/ultimo controllo delle specifiche.
- **F-03 Modifica non distruttiva:** memorizzare trasformazioni separate dal sorgente: ritaglio, pan, zoom, raddrizzamento e rotazione a passi in senso antiorario. Modifiche aggiornano l’anteprima; “Ripristina” riporta allo stato iniziale. Il pan deve avere un helper robusto che rispetti i limiti dell’immagine e mantenga coerenti canvas, preview ed export. Nessun ritocco dei pixel originali.
- **F-04 Timbro clone offline:** l’utente sceglie lo strumento, clicca una volta sull’immagine per impostare la sorgente e clicca sulla destinazione per applicare un timbro discreto. Non è un pennello a tratto continuo. Il clone campiona i pixel dalla foto sorgente dell’utente; nessun modello generativo o servizio remoto. Dimensione del timbro regolabile; sorgente visibile e operazioni annullabili/ripristinabili.
- **F-05 Geometria coerente:** applicare il clone alla variante normalizzata risultante dal crop corrente. Un cambiamento di geometria del crop (rapporto/dimensioni, pan, zoom, rotazione o raddrizzamento) cancella sorgente e timbri clone. Una nota persistente informa l’utente di questa regola prima di modificare la geometria; non è richiesto un dialogo di conferma. Undo ripristina anche preset/geometria e timbri cancellati. La sola modifica dei parametri non geometrici non invalida il clone.
- **F-06 Esportazione:** renderizzare una copia alle dimensioni esatte del preset, JPEG o PNG, profilo sRGB; appiattire sempre il risultato su fondo bianco, anche per PNG. JPEG espone qualità selezionabile con valore predefinito documentato nell’interfaccia. Impedire la sovrascrittura del sorgente, anche tramite collegamenti simbolici o hard link.
- **F-07 Preview:** mostrare la tela e l’area che sarà esportata. Per profili e banner, indicare overlay/zone di sicurezza quando la piattaforma li documenta; sono guide, non anteprime fedeli di ogni dispositivo.
- **F-08 Privacy/offline:** elaborazione locale senza account, telemetria o rete necessaria. Le foto restano nelle posizioni scelte dall’utente.

## Limiti immagini

- Import: supportare immagini fino a **120 megapixel** e **512 MB** di file codificato. Controllare entrambi i limiti prima di decodificare; dimensioni eccessive devono produrre un errore spiegato, senza esaurire la memoria.
- Massimo **32.768 pixel per lato**: un'immagine lunga e sottile può superarlo anche sotto 120 MP; il messaggio deve indicare questo limite distinto.
- Export: massimo **40 megapixel** per immagine renderizzata. I preset attuali sono molto inferiori a questa soglia.
- Il limite d’importazione deve consentire immagini ad alta risoluzione come il file da circa 40,2 MP della Fujifilm citato come caso d’uso: non introdurre un tetto di 40 MP sull’input.

## Fuori dal perimetro della versione iniziale

La versione **v0.1** non include persistenza del progetto/sessione né elaborazione batch. Non include pubblicazione diretta, video, generazione AI, filtri creativi o ritocco colore avanzato. Il clone è uno strumento manuale applicato esclusivamente a varianti di foto fornite dall’utente.

## Vincoli e criteri di accettazione

- App SwiftUI nativa per macOS 14 o successivo; pipeline d’immagine basata su ImageIO e Core Image.
- L’app funziona senza rete dopo installazione e non invia immagini fuori dal dispositivo.
- Un export ha le dimensioni pixel e il formato scelti; l’orientamento EXIF è applicato correttamente e il risultato è sRGB.
- Clone: definizione della sorgente con click, applicazione alla destinazione, undo e invalidazione esplicita dei tratti al cambio di geometria del ritaglio.
- Ripetere, annullare o cambiare parametri non altera il file sorgente; l’export riflette sempre lo stato corrente.
- UI e documentazione distinguono **requisito ufficiale di upload**, **raccomandazione/preset pratico** e **dato non verificato**. Non promettere assenza di compressione o compatibilità universale.

## Ripartizione di lavoro

- **Agente app:** shell SwiftUI, flusso utente e presentazione dei preset; integra i contratti d’immagine documentati.
- **Test automatici:** 29 test passati (16 core, 13 UI/model/geometria), inclusi export JPEG/PNG di tutti i preset, profilo colore, otto orientamenti EXIF, mappe pixel e angoli RGB pieni. Lo scenario model copre apertura, anteprima, modifica, export e import fallito senza perdere il sorgente caricato. Le verifiche manuali eseguite sono riportate in `verifica.md`.
- **Agente core/test:** modello trasformazioni, pipeline ImageIO/Core Image, clone offline, export sRGB/JPEG/PNG e scenari di verifica.
- **Questo pacchetto docs:** definisce termini, preset documentati, ADR e casi di accettazione; i valori devono essere ricontrollati prima di release.

## Indicazioni UI macOS

Usare componenti e comportamenti standard SwiftUI/macOS: finestra ridimensionabile, scorciatoie per le azioni ricorrenti, supporto a puntatore/trackpad e precisione nel canvas. La sidebar dei preset è appropriata per la navigazione tra gruppi, ma deve potersi nascondere e non ospitare azioni critiche in fondo. Tenere pochi comandi frequenti nella toolbar e lasciare che il sistema gestisca l’overflow. Il nome prodotto è **SocialFrame** e l’icona scelta è il concept **B**. Riferimenti: [HIG macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars).

Zoom e livellamento offrono input numerico, piccoli incrementi e reset del singolo parametro. Pan e clone hanno controlli equivalenti senza puntatore: frecce sull'anteprima, pulsanti di spostamento e coordinate percentuali per sorgente/destinazione del timbro. Il contorno clone rappresenta il raggio effettivo. Le guide della destinazione sono indipendenti dalla griglia e non vengono esportate. Il comando di esportazione e le impostazioni principali rimangono fuori dall'area scorrevole dell'inspector.

Lingua supportata: italiano. Le risorse di UI e core sono localizzabili; il bundle dichiara le lingue per cui esistono risorse. Le traduzioni aggiuntive non sono incluse. La procedura per aggiungerle è in `localizzazione.md`.


## Animazioni

Transizioni brevi per anteprima iniziale, griglia, riepilogo preset, messaggi di stato e controlli espandibili clone/JPEG. Rispettare “Riduci movimento” di macOS. Pan, zoom e ritaglio devono restare precisi e immediati durante l’interazione.

## Autolivellamento e guide di composizione

- **F-09 Autolivellamento:** comando esplicito “Autolivella”, disponibile con foto caricata. Analizza l’inquadratura corrente sul Mac tramite Vision, senza inviare immagini; ignora i timbri clone durante l’analisi. Applica un angolo assoluto entro ±45° come unica modifica annullabile e azzera i timbri come ogni modifica geometrica. Se l’analisi non restituisce un riferimento accettabile, non modifica foto o cronologia. Una modifica dell’inquadratura o un import successivo invalida il risultato in corso. Il rilevamento è una stima da controllare visivamente, non una garanzia di orizzonte corretto in qualsiasi scena.
- **F-10 Griglie:** selettore Nessuna, Regola dei terzi, Sezione aurea, Centro, Diagonali e Griglia fitta (8×8). Visibilità regolabile 20–100%, tratto chiaro con bordo scuro. Guide esclusivamente nell’anteprima: non alterano pixel, ritocchi o cronologia, né vengono esportate.
