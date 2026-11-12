# Preset iniziali e fonti

Le misure sotto sono **target di export consigliati**, salvo la colonna “Vincolo ufficiale”. Un target esatto è una scelta di prodotto per semplificare l’uso, non una condizione necessaria né garanzia di upload o di resa. Le piattaforme cambiano specifiche e interfacce: ricontrollare le pagine prima di rilasciare aggiornamenti.

## Catalogo attualmente nel core

Verificato in `Sources/SocialCore/Preset.swift` il 2026-11-12. Il core espone questi 27 preset. Le misure sono target di export; non tutte sono limiti ufficiali. Le schermate devono mostrare fonte e data ultimo controllo specifiche per il preset, con indicazione chiara quando si tratta di raccomandazione o dato pratico.

| ID core | Nome mostrato | Pixel |
|---|---|---:|
| `instagram-portrait` | Post verticale | 1080×1350 |
| `instagram-3-4` | Post verticale 3:4 | 1080×1440 |
| `instagram-landscape` | Post orizzontale | 1080×566 |
| `instagram-square` | Post quadrato | 1080×1080 |
| `instagram-story` | Storia / Copertina Reel | 1080×1920 |
| `instagram-profile` | Immagine profilo | 320×320 |
| `youtube-thumbnail` | Miniatura 4K | 3840×2160 |
| `youtube-shorts` | Copertina Shorts 4K | 2160×3840 |
| `youtube-profile` | Immagine profilo | 800×800 |
| `youtube-banner` | Copertina | 2560×1440 |
| `facebook-post` | Post orizzontale | 1200×630 |
| `facebook-portrait` | Post verticale | 1080×1350 |
| `facebook-square` | Post quadrato | 1080×1080 |
| `facebook-story` | Storia | 1080×1920 |
| `facebook-profile` | Immagine profilo | 320×320 |
| `facebook-cover` | Copertina | 1640×624 |
| `linkedin-post` | Post orizzontale | 1200×627 |
| `linkedin-portrait` | Post verticale | 1080×1350 |
| `linkedin-square` | Post quadrato | 1080×1080 |
| `linkedin-profile` | Immagine profilo | 400×400 |
| `linkedin-cover` | Copertina | 1584×396 |
| `linkedin-company-cover` | Copertina aziendale | 1512×256 |
| `x-portrait` | Post verticale | 1080×1350 |
| `x-square` | Post quadrato | 1080×1080 |
| `x-post` | Post orizzontale | 1200×675 |
| `x-profile` | Immagine profilo | 400×400 |
| `x-header` | Copertina | 1500×500 |

Nota: thumbnail e shorts YouTube, story/reel Instagram e storie Facebook sono immagini statiche per superfici o contenuti social; non implicano produzione video o caricamento diretto. Non cambiare i valori del core senza aggiornare insieme tabella, fonti e note di affidabilità.

**Limiti implementati:** input fino a 120 MP e 512 MB; massimo 32768 pixel per lato. Export fino a 40 MP. La pipeline appiattisce su bianco prima del timbro, quindi anche il PNG è opaco.

## Fonte per preset e data di verifica nell’interfaccia

### Riesame UX del 12 novembre 2026

La UI ora espone stato e data **per destinazione**, nel dettaglio espandibile “Fonte del formato”. È stata rimossa la dicitura globale “Fonti controllate” che poteva far apparire tutti i valori verificati. Dimensioni, nomi e ID dei 27 target di esportazione restano invariati.

| Destinazione | Stato delle dimensioni nella UI | Riscontro attuale |
|---|---|---|
| YouTube miniatura video / Shorts | Raccomandazione ufficiale | [Fonte](https://support.google.com/youtube/answer/72431) riaperta il 12/11/2026: 3840×2160 / 2160×3840; JPG/PNG, massimo 50 MB da desktop; video mobile 2 MB, podcast mobile 10 MB. Shorts da Studio su computer con account verificato. |
| YouTube banner | Raccomandazione ufficiale | [Fonte](https://support.google.com/youtube/answer/10456525) riaperta il 12/11/2026: raccomandato 2560×1440, minimo 2048×1152, area sicura al minimo 1235×338, massimo 6 MB. |
| YouTube profilo | Formato pratico | Stessa fonte verificata il 12/11/2026: resa a 98×98, massimo 15 MB; **800×800 non è prescritto**. |
| LinkedIn profilo | Requisito ufficiale | [Fonte](https://www.linkedin.com/help/linkedin/answer/a549049) riaperta il 12/11/2026: 400×400 è il minimo del range, non l'unica misura ammessa; JPG/PNG, massimo 8 MB. |
| LinkedIn copertina personale | Raccomandazione ufficiale | La medesima pagina `a549049`, riaperta il 12/11/2026, indica 1584×396. Il link UI ora punta alla pagina che espone effettivamente il dato. |
| X profilo / header | Raccomandazione ufficiale | [Fonte](https://help.x.com/en/managing-your-account/common-issues-when-uploading-profile-photo) riaperta il 12/11/2026: 400×400 / 1500×500; JPEG/GIF/PNG, profilo massimo 2 MB; ritaglio header variabile. |
| Instagram, Facebook, altri formati LinkedIn e post X | Formato pratico, da verificare | Nessuna nuova verifica positiva attribuita alle dimensioni. Instagram ha risposto HTTP 429; Facebook ha rimandato al login. Gli altri dati non sono stati ricontrollati in questo intervento. |

Le date precedenti nelle tabelle sottostanti documentano la ricerca iniziale, non una verifica nuova dell'intero catalogo. Le dimensioni non ricontrollate restano prudentemente pratiche nella UI. Il link della copertina aziendale LinkedIn è stato corretto al percorso `/help/lms/answer/a567368`, senza attribuirgli una verifica recente. I limiti di peso social citati sono informazioni: l'app non li impone all'export e lo dichiara nel dettaglio della fonte. Nessun caricamento sui social effettuato.

Mostrare un link specifico per la destinazione, una data **Ultima verifica** mantenuta insieme ai dati del preset e un’etichetta “Limite ufficiale”, “Raccomandato” o “Preset pratico”. Evitare un singolo link generico per tutti i preset di una piattaforma. Fonti applicabili: Instagram post [foto](https://help.instagram.com/1631821640426723); YouTube [miniatura video](https://support.google.com/youtube/answer/72431) e [branding canale](https://support.google.com/youtube/answer/10456525); Facebook [immagine profilo](https://www.facebook.com/help/125379114252045) (pagina può richiedere login; le altre specifiche restano da verificare); LinkedIn [post foto](https://www.linkedin.com/help/linkedin/answer/a527229), [foto profilo](https://www.linkedin.com/help/linkedin/answer/a549049), [cover profilo](https://www.linkedin.com/help/linkedin/answer/a568217); X [foto profilo e header](https://help.x.com/en/managing-your-account/common-issues-when-uploading-profile-photo.html), [foto nei post](https://help.x.com/en/using-x/posting-gifs-and-pictures).

`Sources/SocialFrame/PresetInfo.swift` seleziona le fonti specifiche per miniatura/branding YouTube, post/profilo/cover LinkedIn e post/profilo X. Per Instagram e Facebook le fonti disponibili sono generali: non tutte le superfici hanno specifiche verificate. La UI mostra una nota di affidabilità e la data del controllo.

| Piattaforma / uso | Preset export iniziale | Vincolo ufficiale documentato | Note |
|---|---:|---|---|
| Instagram post quadrato | 1080×1080 (1:1) | Il Centro assistenza dichiara per foto condivise larghezza 320–1080 e rapporto 1.91:1–3:4 per mantenere risoluzione; fuori intervallo può adattare/ritagliare. | Preset pratico. Il profilo griglia e altri contesti possono ritagliare. |
| Instagram post verticale | 1080×1350 (4:5) | Incluso nell’intervallo di rapporto sopra. | Target tradizionale 4:5; la pagina assistenza aggiornata indica anche 3:4. |
| Instagram post orizzontale | 1080×566 (circa 1.91:1) | Estremo del rapporto indicato dall’assistenza. | Il pixel arrotondato è una derivazione del rapporto. |
| Instagram immagine profilo | 320×320 (1:1) | Nessun limite/dimensione ufficiale individuato in fonte pubblica corrente. | Core disponibile; mostrare maschera circolare come simulazione. |
| YouTube miniatura video / Shorts | 3840×2160 (16:9) / 2160×3840 (9:16) | Pagina ufficiale consultata il 12/11/2026: raccomanda 4K, minimo 640 px sul lato pertinente; JPG/PNG; desktop fino a 50 MB, mobile video 2 MB. | Miniature Shorts caricabili da Studio desktop con account verificato. |
| YouTube immagine profilo canale | 800×800 (1:1) | Formati ammessi JPG/GIF non animata/BMP/PNG; max 15 MB; resa indicata 98×98. | Core disponibile; 800×800 è target pratico, non prescritto. |
| YouTube banner canale | 2560×1440 (16:9) | Minimo 2048×1152; area sicura al minimo 1235×338; file max 6 MB. | Core disponibile; 2560×1440 raccomandato soprattutto per TV. Crop varia per dispositivo. |
| Facebook post immagine | 1200×630 orizzontale; 1080×1350 verticale; 1080×1080 quadrato. | Non è stato possibile verificare da pagina pubblica ufficiale accessibile un requisito generale stabile per post organici. | Target pratici da verificare nel compositore della piattaforma. |
| Facebook foto profilo / copertina | 320×320 / 1640×624 | Nessun requisito attuale verificato in fonte ufficiale accessibile per queste dimensioni. | Core disponibile, valori pratici non verificati; profilo mostrato con crop circolare. |
| LinkedIn foto profilo | 400×400 (1:1) | Foto profilo: immagine tra 400×400 e 7680×4320; max 8 MB; JPG/PNG. | Core disponibile; 400×400 è il minimo ufficiale documentato. |
| LinkedIn cover profilo | 1584×396 (4:1) | JPG/PNG; meno di 8 MB; 1584×396 raccomandato. | Core disponibile; layout varia con viewport. |
| LinkedIn post foto | 1200×627 orizzontale; 1080×1350 verticale; 1080×1080 quadrato. | Minimo 552×276; max 5 MB; rapporti 3:1–4:5. | LinkedIn consiglia larghezza 1080. I preset core sono nel range documentato. |
| X post immagine | Core: 1200×675 (16:9). | La pagina Help descrive foto e GIF, ma non stabilisce qui un unico rapporto/dimensione raccomandata generale. | Core disponibile; target pratico, non requisito ufficiale universale. |
| X avatar / header profilo | 400×400 / 1500×500 | Formati JPEG/GIF/PNG; foto profilo max 2 MB; 400×400 e 1500×500 raccomandati. | Core disponibile; header può perdere fino a 60 px sopra/sotto in base a schermo/browser. |

## Coerenza del timbro clone

Il clone offline opera sulla variante normalizzata dal crop corrente, non direttamente sul sorgente originale. Un cambio di geometria (rapporto/dimensioni, pan, zoom, rotazione o raddrizzamento) rende non valide le coordinate della sorgente e dei timbri: la nota persistente spiega che saranno azzerati. Non serve conferma modale; Undo ripristina la modifica e i timbri precedenti. Questo è un vincolo funzionale di v0.1, non una proprietà dei preset social.

## Fonti ufficiali

- [YouTube Help — miniature video e Shorts](https://support.google.com/youtube/answer/72431) · accesso 2026-11-12, raccomandazioni 4K e limiti diversi desktop/mobile.

- [Instagram Help Center — risoluzione delle foto condivise](https://help.instagram.com/1631821640426723) · accesso 2026-11-12. Intervallo dichiarato 320–1080 px e 1.91:1–3:4.
- [YouTube Help — branding del canale](https://support.google.com/youtube/answer/10456525) · accesso 2026-11-12. Avatar, banner, area sicura, peso e raccomandazione banner.
- [LinkedIn Help — foto nei post](https://www.linkedin.com/help/linkedin/answer/a527229) · accesso 2026-11-12. Limiti, rapporti e larghezza raccomandata.
- [LinkedIn Help — foto profilo non caricabile](https://www.linkedin.com/help/linkedin/answer/a549049) · accesso 2026-11-12. Range avatar, peso e formati.
- [LinkedIn Help — cover profilo](https://www.linkedin.com/help/linkedin/answer/a568217) · accesso 2026-11-12. Peso, formati e misura raccomandata.
- [LinkedIn Marketing Solutions — specifiche immagini Pagine](https://www.linkedin.com/help/lms/answer/a567368) · accesso 2026-11-12. Cover Pagina e immagini personalizzate.
- [X Help — pubblicare foto o GIF](https://help.x.com/en/using-x/posting-gifs-and-pictures) · accesso 2026-11-12. Hub ufficiale per requisiti; pagina caricata non esponeva nel testo estratto i dettagli della sezione.
- [X Help — problemi di caricamento dell’immagine profilo](https://help.x.com/en/managing-your-account/common-issues-when-uploading-profile-photo.html) · accesso 2026-11-12. Formati, max 2 MB profilo, 400×400 raccomandato per profilo e 1500×500 per header; possibili crop del header su display/browser diversi.
- [X Business — specifiche creatività pubblicitarie](https://business.x.com/en/help/campaign-setup/creative-ad-specifications) · riferimento per creatività ads, non assimilabile ai requisiti dei post organici.
- [Apple HIG — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) · consultate 2026-11-12; input preciso, layout flessibile, sidebar e toolbar native.
- Facebook/Meta: pagine Help/Business reperite durante la ricerca richiedevano login o non esponevano la specifica. Di conseguenza i valori Facebook sopra sono marcati come **preset pratici non verificati**, non requisiti ufficiali.
