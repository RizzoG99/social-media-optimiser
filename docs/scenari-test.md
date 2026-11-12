# Scenari di test e accettazione

Questa matrice comprende scenari automatici e manuali. Lo stato di esecuzione è riportato sotto e in `verifica.md`.

| ID | Scenario | Risultato atteso |
|---|---|---|
| T-01 | Aprire JPEG e PNG in orientamento EXIF diverso | Anteprima orientata correttamente; sorgente invariato. |
| T-01a | Importare una foto Fujifilm da circa 40,2 MP | Import accettato se il file è entro 512 MB; un eventuale limite configurato a 40 MP non deve rifiutarlo. |
| T-01b | Tentare import oltre 120 MP o oltre 512 MB | Rifiuto prima della decodifica completa, messaggio esplicito e nessun crash/pressione memoria anomala. |
| T-02 | Selezionare ciascun preset e spostare/ingrandire l’immagine | Rapporto e tela rimangono costanti; pan/zoom influenzano solo la composizione. |
| T-03 | Raddrizzare con angolo e ruotare a passi antiorari | Preview coerente; bordi fuori tela non compaiono nell’export; parametri reversibili e direzione CCW coerente con il controllo UI. |
| T-04 | Annullare/ripristinare più modifiche | Stato torna al punto richiesto, senza degradare o riscrivere l’originale. |
| T-05 | Impostare sorgente clone con click e applicare timbri con click distinti sulla destinazione | Campioni provengono dalla sorgente corretta; ogni timbro è discreto e annullabile. Non si attende una pennellata continua. |
| T-06 | Cambiare ciascuno dei parametri geometrici del crop dopo clone | Una nota persistente comunica che sorgente/timbri clone saranno cancellati; il cambio procede senza dialogo. Undo ripristina geometria/preset e timbri. |
| T-07 | Salvare e riaprire la foto esportata | Il risultato clone è incluso nei pixel esportati. Non si promette di riaprire una sessione modificabile in v0.1. |
| T-08 | Esportare ogni preset in PNG e JPEG | Dimensioni esatte, formato corretto, profilo sRGB e fondo bianco opaco in entrambi i formati; JPEG decodificabile e qualità coerente col controllo. Output oltre 40 MP rifiutato. |
| T-09 | Riaprire export in ImageIO o strumento indipendente | Dimensioni, orientamento e spazio colore verificabili; metadata non necessari rimossi o gestiti con criterio documentato. |
| T-10 | Sorgente con alpha esportata in PNG e JPEG | Entrambi gli export appiattiti su bianco e visivamente coerenti in preview; PNG non contiene trasparenza. |
| T-11 | File corrotto, non supportato o enorme | Errore leggibile; nessun crash; memoria rilasciata. Definire limiti operativi prima dell’implementazione. |
| T-12 | File sorgente ed export con stesso nome | Salvataggio tramite dialogo; sorgente non sovrascritto accidentalmente. |
| T-13 | Preset con stato “raccomandato” o “non verificato” | UI non lo etichetta come requisito obbligatorio; mostra piattaforma, destinazione e fonte/stato. |
| T-14 | Verifica offline | Import, modifica, clone, preview ed export funzionano con rete disattivata; nessuna richiesta di rete per immagini. |
| T-15 | Crop profilo/banner e ridimensionamento finestra | Guide e safe area restano indicative; canvas si adatta senza presentare simulazione come identica a ogni vista social. |
| T-16 | Usare sidebar e toolbar a finestra stretta | Sidebar nascondibile; azioni essenziali accessibili; toolbar segue overflow di sistema. |

## Stato della verifica

14 test automatici passati: 8 core e 6 model, inclusi export JPEG e PNG per tutti i preset, profili colore, otto orientamenti EXIF, mappe pixel e angoli RGB pieni. Lo scenario model copre apertura, anteprima, modifica, export e import fallito. Le verifiche manuali eseguite e i controlli ancora da fare sono riportati in `verifica.md`.

## Verifiche manuali di prodotto

- Confrontare composizione export e preview per immagini landscape/portrait, soggetto vicino ai bordi e alpha trasparente.
- Controllare i preset contro i link ufficiali in `preset-e-fonti.md` a ogni release; aggiornare data e classificazione se cambiano le pagine.
- Caricare manualmente file campione sulle piattaforme solo come controllo empirico; annotare account/client/data. Non usare l’esito per promettere validità universale o assenza di compressione.

## Nuovi scenari — autolivellamento e griglie

- Orizzonte inclinato: Autolivella applica una sola modifica; ⌘Z ripristina angolo e timbri, ripristina riapplica l’angolo.
- Immagine uniforme, risultato assente/non affidabile o analisi fallita: foto e cronologia intatte, messaggio comprensibile.
- Modifica manuale durante l’analisi: il risultato precedente non sovrascrive la nuova inquadratura.
- Passaggio tra griglie: verificare linee e visibilità con foto verticali/orizzontali; nessuna modifica allo stato di editing. L’export non deve includere guide.
- Verificare fotografie reali con orizzonti inclinati nei due versi, un angolo manuale già presente e una rotazione di 90°: l’analisi Vision dipende dal contenuto e non è sostituibile dai soli test sulla conversione degli angoli.
