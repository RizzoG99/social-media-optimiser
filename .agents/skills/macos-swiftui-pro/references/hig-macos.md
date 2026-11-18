# HIG macOS e Liquid Glass

Regole distillate dalle pagine Apple lette il 12 novembre 2026 (date di aggiornamento tra parentesi). Le pagine HIG sono renderizzate in JavaScript: per ricontrollarle usa un browser, non un fetch HTML. Se una regola qui sembra superata, apri la fonte e aggiorna questo file con la nuova data.

## Livelli: navigazione sopra, contenuto sotto

Fonti: [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) (9 set 2025), [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).

- Liquid Glass è il **livello funzionale** di controlli e navigazione (toolbar, sidebar, inspector, popover) che galleggia sopra il **livello contenuto**. Nel livello contenuto usa materiali standard o colori semantici, mai vetro.
- Eccezione prevista dal sistema: slider e toggle assumono l'aspetto vetro solo mentre li si usa. Succede da sé con i controlli standard; non replicarlo.
- I componenti di sistema adottano il vetro automaticamente. Applica `glassEffect` a un controllo personalizzato con parsimonia, solo per gli elementi funzionali più importanti.
- Variante **regular** per quasi tutto (blur e luminosità garantiscono la leggibilità); **clear** solo per elementi sopra media ricchi, eventualmente con un velo scuro al 35% se la foto sottostante è chiara.
- Niente vetro sopra vetro e niente controlli sovrapposti o affollati: usa le spaziature standard.
- Riduci gli sfondi personalizzati in toolbar, split view e barre: coprono vetro ed effetto bordo di scorrimento.
- Più effetti personalizzati vicini vanno in un `GlassEffectContainer` (prestazioni e morphing).

## Finestra

Fonti: [Windows](https://developer.apple.com/design/human-interface-guidelines/windows) (9 giu 2025), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) (16 dic 2025), [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) (28 ott 2026).

- **Non intitolare la finestra con il nome dell'app**: il titolo descrive il contenuto (qui il file aperto), breve, idealmente sotto 15 caratteri. Il sottotitolo porta il contesto secondario.
- Niente cornici o controlli finestra personalizzati; finestre ridimensionabili con contenuto che si adatta.
- **Barra inferiore:** evita informazioni o azioni critiche; ammessa solo per poche informazioni sul contenuto (stile barra di stato del Finder). Se serve di più, usa l'inspector.
- Sfrutta lo schermo grande per mostrare più contenuto con meno livelli e meno modalità; supporta schermo intero.
- Mac con schermo touch (ott 2026): target più ampi o controlli che si espandono al tocco, mantenendo dimensioni e densità ottimizzate per puntatore e tastiera.

## Toolbar

Fonte: [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) (16 dic 2025).

- Pochi elementi scelti; il sistema aggiunge da solo il menu di overflow quando non c'è spazio: **non crearne uno a mano** e non progettare layout che vadano in overflow di default.
- **Tre zone.** Leading: mostra/nascondi sidebar, titolo, eventuale menu documento (fissi, non personalizzabili). Centro: controlli comuni, collassano nell'overflow. Trailing: elementi sempre visibili, pulsanti che aprono inspector, ricerca, menu Altro, azione primaria.
- **Al massimo tre gruppi**, raggruppati per funzione e frequenza. Separare con lo spaziatore fisso di sistema, non con spazi manuali.
- Preferisci **simboli di sistema senza bordo**: la sezione è già un contenitore e il sistema gestisce hover e selezione. Non mescolare testo e icone nello stesso gruppo.
- **Una sola azione primaria con stile prominente**, sul lato trailing (Fine, Invia, nel nostro caso Esporta).
- Riduci sfondi e controlli tinti: lascia che il colore della toolbar venga dal contenuto; usa lo stile di effetto bordo quando serve separare toolbar e contenuto. Su contenuti colorati (foto) preferisci la toolbar monocromatica.
- Componenti standard: i raggi sono concentrici con la barra. Un componente personalizzato deve esserlo a sua volta.
- **macOS:** ogni elemento della toolbar deve esistere anche come comando nella barra dei menu, perché la toolbar si può personalizzare o nascondere. Valuta la personalizzazione della toolbar per un'app d'uso prolungato.
- Nascondere un elemento significa nascondere l'intero `ToolbarItem`, non la vista al suo interno (altrimenti resta una capsula vuota).
- Ogni icona ha un'etichetta accessibile.

## Sidebar

Fonte: [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars) (8 giu 2026).

- Navigazione tra aree o collezioni di primo livello; selezione evidenziata in modo persistente ([Split views](https://developer.apple.com/design/human-interface-guidelines/split-views)).
- Al massimo due livelli; gruppi con controlli di apertura ed etichette concise.
- Simboli SF familiari per le righe. **Dal 2026 le icone usano il colore di accento dell'app** e devono rispettare l'accento scelto dall'utente; colori fissi solo con un significato preciso.
- Contenuto visivamente ricco può estendersi sotto la sidebar con `backgroundExtensionEffect()`.
- Comandi Mostra/Nascondi sidebar nel menu Vista; non nascondere la sidebar di default; niente azioni critiche in fondo alla sidebar.

## Inspector e split view

Fonti: [Split views](https://developer.apple.com/design/human-interface-guidelines/split-views), [Panels](https://developer.apple.com/design/human-interface-guidelines/panels), [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).

- Layout sidebar + contenuto + inspector con `NavigationSplitView` e `inspector(isPresented:content:)`: il sistema applica il materiale corretto e l'inspector ha uno strato più sobrio della sidebar.
- L'inspector mostra i dettagli della selezione corrente e si aggiorna con essa. Preferisci controlli di regolazione diretta (slider, stepper) a passaggi multipli.
- Pannelli nascondibili: offri più modi per riaprirli (pulsante trailing in toolbar, comando di menu con scorciatoia). Nel menu: "Mostra inspector", senza la parola "pannello".
- Larghezze minime e massime ragionevoli; divisore sottile.
- Controlla le safe area accanto a sidebar e inspector perché il contenuto vi passi sotto correttamente.

## Liste, form, sezioni

Fonte: [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).

- Liste, tabelle e form hanno righe più alte e sezioni più arrotondate: usa `Form` con `.formStyle(.grouped)` invece di stack personalizzati.
- Le intestazioni di sezione non sono più in maiuscolo forzato: scrivile già nella forma finale (in italiano iniziale maiuscola, in inglese title case).

## Effetto bordo di scorrimento

Fonte: [Scroll views](https://developer.apple.com/design/human-interface-guidelines/scroll-views) (8 giu 2026).

- Preferisci lo stile **automatico**; usalo solo quando una scroll view passa sotto elementi fluttuanti; un effetto per vista. In uno split view ogni pannello può avere il proprio, di altezza coerente.
- Barre personalizzate con contenuto che scorre sotto: `safeAreaBar(edge:alignment:spacing:content:)`.

## Colore

Fonte: [Color — Liquid Glass color](https://developer.apple.com/design/human-interface-guidelines/color) (16 dic 2025).

- Il vetro non ha colore proprio: prende quello del contenuto. Colora con parsimonia, solo stato o azione primaria; per l'azione primaria colora lo **sfondo** (stile prominente), non simbolo o testo.
- Non tingere lo sfondo di più controlli. Con contenuti colorati (le foto dell'utente) mantieni toolbar monocromatiche.
- Colori di sistema o personalizzati con varianti chiaro/scuro e alto contrasto.

## Menu

Fonte: [Menus](https://developer.apple.com/design/human-interface-guidelines/menus) (8 giu 2026).

- Icone nei menu con parsimonia: azioni comuni e funzioni chiave, concetti visivi come ruotare o capovolgere. Icone per tutte le voci di un gruppo o per nessuna; nessuna icona se non ce n'è una chiara.
- Usa le icone standard per le azioni comuni; ellissi quando servono altre scelte; voci non disponibili attenuate ma menu sempre apribile.

## Accessibilità e impostazioni di sistema

- Il vetro si adatta da sé a Riduci trasparenza, Aumenta contrasto e alla preferenza di aspetto del vetro scelta dall'utente; gli elementi personalizzati vanno provati con ciascuna.
- Mostra bordi: leggi `accessibilityShowBorders` (vedi [liquid-glass-api.md](liquid-glass-api.md)) nei controlli personalizzati.
- Riduci movimento: nessun morphing o animazione ampia; dissolvenza.
- Icone sempre con etichetta testuale accessibile; nomi distinti per elementi raggruppati.

## Novità WWDC26 (macOS 27)

Fonte: trascrizione della [Platforms State of the Union 2026](https://developer.apple.com/videos/play/wwdc2026/102/), letta in parte. Comportamenti automatici con i componenti standard; verificali a schermo prima di basarci decisioni.

- Vetro rifinito (bordo scurito, riflessi più marcati) applicato automaticamente alle app che usano già Liquid Glass.
- Sidebar estese fino ai bordi della finestra; icone della sidebar colorate con l'accento tramite `List` e `Label`, con tinta per elemento personalizzabile.
- Tutte le finestre hanno lo stesso raggio d'angolo, più stretto.
- Quando il contenuto scorre sotto barre fluttuanti appare una toolbar uniforme in alto, regolabile con le API di effetto bordo esistenti.
- Le icone nei menu sono nascoste di default; un'API le mostra per le azioni chiave (nome non verificato: cercalo nell'SDK prima di usarlo).
- Non verificati per macOS: il cursore di tinta "da trasparente a coprente" annunciato per iOS e la rimozione dell'opzione di compatibilità con il vecchio design.
