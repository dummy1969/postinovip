# PostinoVip — brief di progetto

Client di posta desktop multipiattaforma (Windows, Linux, macOS): un'alternativa open source che riproduca il più possibile **Outlook classico** per la posta.
Progetto personale e di studio: si procede **per piccoli step, ognuno funzionante e verificabile**.

## Obiettivo e perimetro

- **Cambio di obiettivo (02/11/2026, decisione dell'utente):** il progetto era nato per assomigliare il più possibile a Outlook, ma dopo le fasi 1–2 è un client di posta essenziale. Da qui l'obiettivo è **riprodurre il più possibile Outlook, nell'aspetto e nelle funzioni**. Scelte: **1b** modello = **Outlook classico** per desktop (barra multifunzione a schede, riquadro cartelle con Preferiti, lista con raggruppamenti, riquadro di lettura, barra di stato, composizione in finestra con la sua barra multifunzione); **2a** solo la **posta**, completa come in Outlook (calendario e contatti restano esclusi); **3c** tappe **alternate**: ogni tappa un pezzo di aspetto e la funzione che lo riempie; **4a** si resta sui componenti **Material** di Flutter, ridisegnati in stile Office/Fluent (tema, colori, densità, icone), senza cambiare libreria.
- Vincoli: **ispirato, non copiato**: niente nome, logo o icone proprietarie di Microsoft (le icone Fluent sono pubblicate con licenza aperta: verificarla prima di usarle; Segoe UI non è ridistribuibile: su Linux un carattere aperto). Restano esclusi Exchange/MAPI, PST/OST, add-in, integrazione Office/Teams.
- Già fatto (fasi 1–2): IMAP + SMTP con password, più account, copia locale con ricerca e uso senza rete, Linux e Windows.
- Esclusi per ora: nessuno dei due. Contatti fatti (C1–C4c); **calendario scelto come prossima area il 06/11/2026** (cambia la scelta 2a «solo la posta»). (POP3 fatto nella fase 4; OAuth2: vedi «OAuth2».)

## Architettura (decisa)

Ibrida, con due processi sulla stessa macchina:

```
┌──────────────────────┐   HTTP/JSON su 127.0.0.1   ┌──────────────────────────┐
│  Flutter (UI)        │ ◄────────────────────────► │  Core C# (ASP.NET Web API)│
│  - cartelle, lista   │                            │  - MailKit IMAP / SMTP   │
│  - lettura messaggio │                            │  - (poi) cache SQLite    │
│  - composizione      │                            │  - (poi) IDLE / push     │
└──────────────────────┘                            └──────────────────────────┘
```

- **Core in C#** con **MailKit/MimeKit** per IMAP, SMTP e MIME.
- **UI in Flutter desktop**; interroga il core via REST/JSON (pacchetto `http`).
- Il core gira **in locale, sullo stesso PC**, come processo nascosto avviato dall'app Flutter. Nessun server esterno.
- Distribuzione finale: un normale installer (Windows: Inno Setup o MSIX; Linux: AppImage/.deb/Flatpak; macOS: .app/.dmg) che contiene sia l'app Flutter sia il core pubblicato `--self-contained` (l'utente non installa .NET).
- gRPC è un'evoluzione possibile del trasporto in futuro, **non** va usato ora.
- La logica mail (risposte, sanificazione HTML, allegati...) sta nel **core**; l'app la usa via API.

### Scelte tecniche fatte (fase 1)

| Ambito | Scelta | Motivo |
|---|---|---|
| Solution | `core/PostinoVip.slnx` (formato XML predefinito in .NET 10) | — |
| API | ASP.NET **controller** (non minimal API) | preferenza dell'utente |
| Errori API | `ProblemDetails` / `ValidationProblemDetails` via `MailExceptionHandler` | errori per campo (`to`, `cc`) mostrabili nella UI |
| Credenziali dev | `dotnet user-secrets`, **stesso `UserSecretsId`** per Cli e Api | impostate una volta sola |
| Stato Flutter | **Provider** (`ChangeNotifier`: `MailboxModel`; `ApiClient` via `Provider.value`) | preferenza dell'utente |
| HTML mail | **nessuna webview**: `flutter_widget_from_html_core` + sanificazione nel core (`HtmlSanitizer`) | webview desktop Flutter frammentate (nessuna ufficiale per Windows+Linux, overlay nativi); vedi step 5 |
| Immagini remote | bloccate di default (`SafeWidgetFactory`), pulsante "Mostra immagini" | privacy / pixel di tracciamento |
| HTML → testo (core) | `Html/HtmlText.cs` su AngleSharp | MimeKit 4.18 **non** ha `HtmlToText` |
| Org Flutter | `com.dumm1969` (application id `com.dumm1969.postinovip`) | — |
| Notifiche desktop | `flutter_local_notifications` (non `local_notifier`, fermo da 2 anni) | mantenuto, editore verificato, Linux + Windows |
| Impostazioni app | `shared_preferences` con `SharedPreferencesAsync` | pacchetto ufficiale; API consigliata |
| File (salva/apri) | `file_selector` | pacchetto ufficiale flutter.dev, Linux + Windows |
| Icone (fase 3) | `fluentui_system_icons` 1.1.273 | editore verificato microsoft.com, licenza MIT; stile Office senza icone proprietarie |
| Aspetto (fase 3) | Material 3 ridisegnato (`ui/theme.dart`, `OfficeTheme`): accento blu `#0F6CBD`, densità compatta, chiaro/scuro secondo il sistema | scelta 4a: niente nuova libreria di componenti; carattere di sistema (Segoe UI su Windows), nessun carattere distribuito |
| Carattere (tappa «Aspetto», V1) | **Inter 4.1** (rsms/inter, SIL OFL 1.1) incluso su Linux e macOS, **Segoe UI** del sistema su Windows (`OfficeTheme.fontFamily`) | scelta 2b dell'11/11/2026; Segoe UI non è ridistribuibile |

## Struttura del repository

```
postinovip/
├── CLAUDE.md
├── README.md
├── .gitignore
├── core/
│   ├── PostinoVip.slnx
│   ├── src/
│   │   ├── PostinoVip.Core/      # libreria: IMAP/SMTP (MailKit), modelli, Html/, Mime/, Compose/
│   │   ├── PostinoVip.Cli/       # console di prova (lettura + send)
│   │   └── PostinoVip.Api/       # ASP.NET Web API (controller)
│   └── tests/
│       ├── PostinoVip.Core.Tests/
│       └── PostinoVip.Api.Tests/ # WebApplicationFactory + servizi finti
└── app/                          # Flutter desktop (Linux, Windows)
    ├── lib/{api,models,state,compose,ui}/
    └── test/
```

Namespace radice: `PostinoVip`.

### Endpoint

Tabella completa in **`docs/api.md`** (leggerla prima di toccare l'API e aggiornarla quando cambia). In breve: ogni endpoint di cartelle, messaggi e invio esiste anche con il prefisso `/accounts/{id}` (senza prefisso = primo account); `GET /events` (SSE) per gli eventi; le operazioni che **modificano** la casella sono segnate lì in grassetto.

## Percorso a tappe

Ogni step deve terminare con un **traguardo verificabile** e un breve riepilogo di come verificarlo.
Non passare allo step successivo senza conferma dell'utente.

**Dettagli di ogni fase e step** (scelte dell'utente con le etichette, verifiche, implementazione, misure, test, limiti): **`docs/storia.md`**, testo completo. Qui solo lo stato in breve. A ogni step: i dettagli in `docs/storia.md`, qui una riga di stato.

### Stato (13/11/2026, 0.0.230) — codice pubblicato come alpha

| Parte | Stato | In `docs/storia.md` |
|---|---|---|
| Fase 1: console IMAP/SMTP, Web API, Flutter in lettura, composizione | ✅ | «Fase 1» |
| Fase 2: avvio del core, scritture, connessione persistente, IDLE e notifiche, allegati, pacchetti Linux (.deb, AppImage) e Windows (Inno Setup, 6d), multi-account (7a–7d), copia locale SQLite (8a–8e) | ✅ | «Fase 2» |
| Prova su Windows | ✅ | «Prova su Windows» |
| Fase 3 «Outlook classico» 3.1–3.9 | ✅ | «Fase 3» |
| Fase 4: crittografia e certificati (4.1), POP3 (4.2a–c) | ✅ | «Fase 4» |
| Regole R1–R3 | ✅ | «Regole» |
| Risposte automatiche | ✅ | «Risposte automatiche» |
| OAuth2 Microsoft: O1 core, O2 app | ✅ | «OAuth2» |
| OAuth2 Microsoft: O3 prova vera | **sospesa**: serve un tenant (account Azure con carta, rifiutato dall'utente); traccia per riprenderla lì | «OAuth2» |
| Gmail con OAuth2 | ✅, app Google in **Testing**: token di rinnovo che scade ogni 7 giorni (nuovo accesso con i contatti nell'app il 09/11/2026: prossima scadenza attesa intorno al 16/11/2026, ipotesi da 7 giorni dall'accesso); pubblicazione in produzione non fatta | «Gmail con OAuth2» |
| Temi di Office | ✅ | «Temi di Office» |
| Contatti C1 (core), C2 (Persone), C3 (composizione), Ccn | ✅ | «Contatti» |
| Contatti C4 CardDAV (server di prova e Gmail) | ✅ | «Contatti» |
| Calendario di Gmail (CalDAV) G1–G3 | ✅ | «Calendario di Gmail» |
| Posta: importanza, zoom, stampa (P1–P3) | ✅ | «Posta: importanza, zoom e stampa» |
| Posta: file .eml (E1–E2) e conferma di lettura (R1–R2) | ✅ | «Posta: file .eml e conferma di lettura» |
| Posta: finestra della mail | ✅ | «Posta: finestra della mail» |
| Posta: posta indesiderata (J1 core, J2 app) | ✅ | «Posta: posta indesiderata» |
| Posta: Archivia (A1 core, A2 app) | ✅ | «Posta: Archivia» |
| Posta: Ignora e Pulisci conversazione (C1 core, C2 app) | ✅ | «Posta: Ignora e Pulisci conversazione» |
| Opzioni a categorie (File → Opzioni), finestre Account con Annulla / OK | ✅ | «Opzioni a categorie» |
| Versione installata: prima sincronizzazione delle cartelle grandi (lista subito, resto in sottofondo), una sola copia dell'app | ✅ | «Versione installata: prima sincronizzazione…» |
| Calendario K1–K5 (CalDAV, vista, finestra Appuntamento, promemoria) | ✅ | «Calendario» |
| Aspetto come l'Outlook di oggi V0–V6 (con V3b) | ✅ chiusa il 12/11/2026 (decisioni di tutti i sotto-step confermate); provata su Windows dall'utente il 12/11/2026: tutto ok | «Aspetto come l'Outlook di oggi» |
| Pubblicazione su GitHub (repository pubblico nuovo da esportazioni ripulite) | ✅ 12/11/2026: `github.com/dummy1969/postinovip` pubblico (0.0.214, solo sorgente, segnalazione privata delle vulnerabilità attiva; ultima pubblicata: **0.0.224**, commit `70ddbbf`); sviluppo in `postinovip-dev` (privato) | «Pubblicazione su GitHub» |
| Posta in arrivo bloccata da una mail con BODYSTRUCTURE non valido (IceWarp): struttura chiesta a parte, mail difettosa isolata (`StructureGuard`, scelta 1a) | ✅ 0.0.218, verificata su Linux con l'account vero e dall'utente su Windows | «Posta in arrivo bloccata da una mail…» |
| Posta: tasti della lista e Svuota cartella (scelte 1a 2a 3a 4a) | ✅ S1 core (0.0.222), S2 app (0.0.223); verificata dall'utente il 13/11/2026, decisioni a–d confermate | «Posta: tasti della lista e Svuota cartella» |
| Posta: formato del messaggio HTML / testo normale (scelte 1a 2a 3a 4a) | ✅ T1 core (0.0.226), T2 app (0.0.227); verificata dall'utente il 13/11/2026, decisioni a–f confermate | «Posta: formato del messaggio» |
| Aggiornamento di `archive` 4.7.0 (1a) e di tre pacchetti (2a) | `archive` ✅ (0.0.229, stampa verificata); `flutter_local_notifications` 23.0.2 e `shared_preferences_android`/`_foundation` (0.0.230) **da verificare** (notifiche, impostazioni) | «Aggiornamento di archive e di tre pacchetti» |

### Aspetto come l'Outlook di oggi ✅ (11–12/11/2026)

Ripresa dopo la pausa (11/11/2026): uso reale con la 0.0.197 «per ora tutto ok». Spunto: MailCraft somiglia di più a Outlook perché imita l'**Outlook classico di Microsoft 365 nell'aspetto del 2023**, noi Outlook 2016/2019 (confronto completo in `docs/storia.md`, «Aspetto come l'Outlook di oggi»). Scelte dell'utente: **1a** quel modello; **2b** Inter (OFL) incluso su Linux e macOS, Segoe UI del sistema su Windows; **3a** i cinque temi restano, adattati; **4a** sotto-step **V0** schermate di confronto, **V1** basi del tema, **V2** cornice (moduli a sinistra, barra in alto con la ricerca), **V3** barra multifunzione, **V4** cartelle e lista, **V5** riquadro di lettura, **V6** composizione, calendario e finestre. Solo app.
- **V0** ✅ (0.0.198, verificato l'11/11/2026): `tools/schermate.sh` crea 5 PNG della casella d'esempio inventata (`app/test_screenshots/`, fuori dalla suite) in `dist/schermate/<data-ora>`; i testi che traboccano finiscono in `avvisi.txt`. Il carattere delle schermate è quello dell'app installata (verificato dall'utente).
- **V1** ✅ (0.0.199, verificato, decisioni a–e confermate): Inter 4.1 incluso (OFL, `app/assets/fonts/inter/`, licenza in «Visualizza licenze» e nel `.deb`), Segoe UI su Windows; schemi di colore scritti a mano con i grigi Fluent 2 (niente `fromSeed`); angoli di 4 px (8 le finestre di dialogo), niente onda al clic, pulsanti rettangolari alti 32, menu e finestre di dialogo bianchi, suggerimenti chiari. Corretto lo stile dei pulsanti piccoli del riquadro di lettura: sparito anche il trabocco a 640×480. Restano: «INBOX» invece di «Posta in arrivo» (V4), caselle di testo (V4/V6).
- **V2** (0.0.200, **da verificare**, decisioni a–e confermate il 12/11/2026): barra in alto (`ui/top_bar.dart`) con Invia/ricevi e la ricerca della posta al centro (`ui/search_box.dart`), blu nel tema Colorato (la banda delle schede ora è chiara); barra dei moduli verticale a sinistra sotto la barra multifunzione; a 640×480 HTML/Testo sotto la data e colonna Categorie solo da 480 px di lista. Corretto un difetto del V1 (pulsanti e titoli delle finestre senza carattere); `tools/schermate.sh` ora segnala anche i testi senza carattere. **0.0.201** (scelta **1c** del 12/11/2026): posizione della barra dei moduli a scelta in File → Opzioni → Generale (a sinistra, predefinita, o in basso nel riquadro di sinistra come prima del V2); suggerimento della barra verticale a destra delle icone (copriva l'icona sopra).
- **V3** ✅ (0.0.202, provato dall'utente, decisioni b–e confermate; (a) barra semplificata: scelta 1b, fatta nel V3b; Ctrl+F1 da riprovare fuori da VNC): barra multifunzione (`ui/ribbon_parts.dart`, vale anche per composizione, Appuntamento e finestra della mail): «File» scheda come le altre (niente blocco blu), barretta blu arrotondata sotto la scheda aperta, comandi in un riquadro chiaro con angoli di 8 px staccato dai bordi, icone grigie a linea sottile alla misura nativa, separatori dei gruppi corti. 
- **V4** (0.0.203, **da verificare**, decisioni a–d confermate): «Posta in arrivo» al posto di «INBOX» (`MailFolder.displayName`, solo ciò che si vede), righe delle cartelle alte 32 e staccate dai bordi (selezione arrotondata), «Tutti / Da leggere» vicine con la barretta come le schede. 
- **V3b** (0.0.204, **da verificare**, decisioni a–e confermate): barra multifunzione **semplificata** come opzione (scelta 1b del 12/11/2026) nelle «Opzioni di visualizzazione della barra multifunzione» (freccia in alto a destra, anche «Mostra solo le schede»); predefinita la classica; vale per tutte le barre (`RibbonStyle` in `ribbon_parts.dart`): una riga, comandi grandi con icona e nome, piccoli con la sola icona. 
- **V5** (0.0.205, **da verificare**, decisioni a–e confermate): riquadro di lettura (vale anche per la finestra della mail e i .eml): oggetto in semigrassetto, cerchio con le iniziali e il colore del mittente (`ui/sender_avatar.dart`), nome in grassetto e indirizzo senza «Da:», data a destra con il giorno, HTML/Testo sulla riga delle categorie, allegati come schede (`AttachmentCard`). 
- **V6** (0.0.206, decisioni a–e confermate): scala dei caratteri di Office nel tema (testo normale, caselle e menu a tendina a 14), caselle di testo basse (`isDense`, bordo scelto da ogni casella), comandi grandi della barra larghi secondo l'etichetta (60–100 px: «Nuovo appuntamento» andava a capo a metà parola). 
- **Tappa chiusa** il 12/11/2026 su richiesta dell'utente (0.0.207): decisioni di tutti i sotto-step confermate, guida dell'architettura alla versione 26. Pacchetti di rilascio rifatti dall'utente: «tutto ok». **0.0.208**: corretta la chiusura lenta dell'app (il core aspettava 30 s la fine della richiesta `/events`; ora esce in 0,1 s), da verificare con i pacchetti. Aspetto **provato su Windows** dall'utente il 12/11/2026 (Segoe UI, barra semplificata, Ctrl+F1): «tutto ok». **Prossimo passo: da scegliere con l'utente.**
- **Da tenere d'occhio:** Gmail in modalità Testing (token di rinnovo che scade ogni 7 giorni: «Accedi di nuovo» nella striscia rossa); O3 OAuth2 Microsoft sospesa (serve un tenant); gli 8 pacchetti Dart «newer versions incompatible» fissati da altri; l'elenco di `pub get` mostra anche versioni solo **aggiornabili** (`flutter pub outdated`, colonna Upgradable): il 13/11/2026 aggiornati `archive` 4.7.0, `flutter_local_notifications` 23.0.2, `shared_preferences_android` 2.5.5 e `shared_preferences_foundation` 2.6.2: restano solo gli 8 (scelta **2a** dell'11/11/2026: lasciarli, ricontrollare a ogni aggiornamento di Flutter; `dependency_overrides` provato e scartato).
- Ricreare i pacchetti: `packaging/linux/build-deb.sh` (poi `sudo apt install ./dist/linux/postinovip_<ver>_amd64.deb`), su Windows `packaging\windows\build-installer.ps1`. Nella versione installata una sola copia aperta; copia locale in `~/.local/share/postinovip` (sviluppo: `postinovip-dev`).

### Versione installata: prima sincronizzazione e una sola copia ✅ (11/11/2026)

Dettagli: `docs/storia.md`, «Versione installata: prima sincronizzazione delle cartelle grandi». In breve: con la copia locale vuota (versione installata: `~/.local/share/postinovip`, separata da `postinovip-dev`) la lista di una cartella grande andava oltre i 30 s dell'app; ora risponde con le 200 più recenti, il download in background completa a blocchi e l'evento `folder-synced` aggiorna la lista (scelta 1a); dalla 0.0.193 se il background sta completando la cartella la lista risponde subito dalla copia locale (prima regole e filtri all'avvio la mettevano in fondo alla fila). **Verificata** dall'utente con il `.deb` (0.0.193). Trovate anche due copie dell'app aperte insieme: dalla 0.0.194 una sola copia nella build di rilascio (scelta 2a; riaprendo viene in primo piano quella aperta), **verificata** su Linux e Windows; decisioni confermate. **Prossimo passo: da scegliere con l'utente.**

### Opzioni a categorie ✅ (10–11/11/2026)

Scelte (1a 2a 3a 4a) e implementazione: `docs/storia.md`, «Opzioni a categorie». In breve: File → Opzioni come le Opzioni di Outlook, elenco delle categorie a sinistra (Generale, Posta, Notifiche, Calendario) e una pagina per volta a destra, finestra di grandezza fissa; in Posta si riattivano le conferme di Ignora conversazione; Account e Nuovo / Modifica account come finestre con «Annulla / OK» (modifiche in sospeso fino a OK, 0.0.190). **Verificata** dall'utente l'11/11/2026, decisioni di dettaglio confermate. **Prossimo passo: da scegliere con l'utente.**

### Posta: Ignora e Pulisci conversazione ✅ (C1–C2, 10/11/2026)

Scelte (1b 2b 3b 4a 5b) e tappe: `docs/storia.md`, «Posta: Ignora e Pulisci conversazione». In breve: come Outlook classico, Ignora sposta in Posta eliminata le mail della conversazione nella cartella aperta e le future della Posta in arrivo (filtro nel core dopo la posta indesiderata, `ignore.json`), «Interrompi Ignora» da Posta eliminata; Pulisci conversazione e Pulisci cartella spostano in Posta eliminata le mail citate per intero da una risposta diretta, con le eccezioni fisse consigliate da Microsoft. C1 (core) verificata con `tools/verifica-ignora-pulisci.sh` (40/0), C2 (app) verificata nell'app: Home → Elimina con Ignora e Pulisci, Ignora nella finestra della mail, tasto destro sulla mail e sulla cartella, conferme con «Non visualizzare più»; tutte le decisioni di dettaglio confermate. Esclusi per ora: Pulisci cartella e sottocartelle, Opzioni di Pulisci (cartella di destinazione, eccezioni), riattivare le conferme. **Prossimo passo: da scegliere con l'utente.**

### Posta: Archivia ✅ (A1–A2, 10/11/2026)

Scelte (1a 2a 3a 4a 5a) e tappe: `docs/storia.md`, «Posta: Archivia». In breve: come Outlook per IMAP e POP3, la prima volta si sceglie (o si crea) la cartella di archiviazione con una proposta (\Archive del server, poi Archivio/Archive, per Gmail «Tutti i messaggi»); scelta per account nel core (`archive.json`), ruolo «archive» solo dal core; Archivia = sposta, letto/non letto invariato. A1 (core) verificata con `tools/verifica-archivia.sh` (25/0), A2 (app) verificata nell'app: pulsante in Home → Elimina, Backspace (non mentre si scrive, non nella finestra della mail), tasto destro, finestra della mail, «Imposta cartella di archiviazione» in Cartella → Archivio; tutte le decisioni di dettaglio confermate. **Prossimo passo: da scegliere con l'utente.**

### Posta: posta indesiderata ✅ (J1–J2, 10/11/2026)

Scelte (1a 2a 3b 4a 5a), implementazione e verifiche: `docs/storia.md`, «Posta: posta indesiderata». In breve: comandi e Opzioni come Outlook (menu «Posta indesiderata» in Home → Elimina, finestra della mail e tasto destro; Opzioni con le quattro schede), filtro nel core sulle mail nuove della Posta in arrivo (prima di risposte automatiche e regole) con i livelli di Outlook sul giudizio del server (SpamAssassin, rspamd), cartella scelta per account (ruolo «junk» solo dal core), collegamenti disattivati e immagini sempre bloccate nella posta indesiderata, parole chiave `$Junk`/`$NotJunk`, elenchi per account (`junk.json`); mai il proprio indirizzo tra i bloccati. J1 verificata con `tools/verifica-posta-indesiderata.sh` (26/0), J2 nell'app. Durante la verifica corretti Nuova cartella/Rinomina (Invio preso dalle scorciatoie della pagina, casella chiusa con la finestra in secondo piano) e il testo dei rifiuti del core. Esclusi per ora: «Elimina definitivamente invece di spostare», scheda Internazionale, esame delle mail già arrivate, importazione/esportazione degli elenchi. **Prossimo passo: da scegliere con l'utente.**

### Calendario ✅ (K1–K5, 06/11/2026)

Scelte, divisione K1–K5, implementazione e verifiche: `docs/storia.md`, «Calendario». In breve: CalDAV nei due sensi (codice `Core/Dav/` comune con il CardDAV), copia `.ics` per calendario in `calendars/`, Ical.Net 5.2.4 + NodaTime 3.3.7 (fusi orari scritti male risolti da `Calendars/TimeZones.cs`), vista Calendario (Ctrl+2) con Giorno / Settimana lavorativa / Settimana / Mese, finestra Appuntamento con ricorrenze e «solo questa occorrenza», promemoria con notifica e finestra «Promemoria» (`state/reminder_model.dart`, spenti nei test da `test/flutter_test_config.dart`). Esclusi per ora: riunioni e inviti, attività (VTODO), calendari condivisi, CalDAV con Microsoft (Gmail fatto: vedi sotto). **Prossimo passo: da scegliere con l'utente.**

### Calendario di Gmail (CalDAV) ✅ (G1–G3, 09/11/2026)

Scelte, implementazione e verifiche: `docs/storia.md`, «Calendario di Gmail». In breve: CalDAV di Google con OAuth2 (permesso `https://www.googleapis.com/auth/calendar` chiesto solo accendendo il calendario sull'account Gmail, un solo accesso con i contatti; API «CalDAV» attivata nella console Google Cloud), indirizzo `https://apidata.googleusercontent.com/caldav/v2/<email>/user` (nessun `.well-known`); tutti i calendari elencati, quelli di sola lettura (festività) da `current-user-privilege-set`: sincronizzati solo dal server, 409 sulle scritture, lucchetto e finestra senza modifiche nell'app. Appuntamenti nuovi su Google: PUT 201 senza ETag né `Location`. Esclusi per ora: CalDAV e CardDAV con Microsoft, riunioni e inviti. **Prossimo passo: da scegliere con l'utente.**

### Posta: importanza, zoom e stampa ✅ (P1–P3, 09/11/2026)

Scelte, implementazione e verifiche: `docs/storia.md`, «Posta: importanza, zoom e stampa». In breve: **importanza** da `Importance`/`X-Priority`/`Priority` (come Outlook), letta con le altre intestazioni (copia locale schema 8, le mail già salvate una volta in sottofondo), «!» rosso e freccia blu nella lista, avviso nella lettura, «Priorità alta/bassa» nella composizione; **zoom** del solo corpo 50–200% (Ctrl+rotella, Ctrl++/-/0, cursore nella barra di stato, ricordato); **stampa** = PDF (pacchetto `pdf`, solo Dart; niente `printing`, che scarica una pdfium precompilata) con intestazioni come testo e corpo disegnato fuori schermo e diviso tra le righe, aperto nel visualizzatore PDF del sistema (Ctrl+P) o salvato. Restano tra i pezzi di Outlook non fatti: Archivia, posta indesiderata, `.eml`, conferma di lettura, Ignora/Pulisci conversazione, Passi rapidi, S/MIME. **Prossimo passo: da scegliere con l'utente.**

### Posta: file .eml e conferma di lettura ✅ (E1–E2, R1–R2, 09/11/2026)

Scelte, implementazione e verifiche: `docs/storia.md`, «Posta: file .eml e conferma di lettura». In breve: File → «Salva con nome… (F12)» salva i byte originali della mail (`GET …/raw`), File → «Apri file .eml…» e le mail allegate si aprono in una finestra di sola lettura con Rispondi/Inoltra (file tenuti in memoria nel core, `POST /eml`); «Richiedi conferma di lettura» nella composizione (`Disposition-Notification-To`), striscia «Invia / Non inviare» o risposta da sola secondo File → Opzioni («Chiedi ogni volta» / «Invia sempre» / «Non inviare mai»), conferma RFC 8098 e parola chiave `$MDNSent` (anche `$MDNReceived` del server vale come trattata); l'EHLO SMTP usa `[127.0.0.1]` invece del nome del PC. Restano tra i pezzi di Outlook non fatti: Archivia, posta indesiderata, Ignora/Pulisci conversazione, Passi rapidi, S/MIME, associazione dei file .eml con il sistema, conferma ricevuta mostrata in modo più pulito. **Prossimo passo: da scegliere con l'utente.**

### Posta: finestra della mail ✅ (09/11/2026)

Scelte, implementazione e verifiche: `docs/storia.md`, «Posta: finestra della mail». In breve: doppio clic o Invio aprono la mail a tutta finestra dentro l'app (`ui/message_window.dart`) con la barra «Messaggio» (Elimina, Rispondi, Sposta, Regole, Tag, Zoom), il menu File (Salva con nome, Stampa, PDF), ↑ ↓ per la precedente e la successiva, dopo Elimina/Sposta la successiva; finestra vera del sistema rinviata a quando quella ufficiale di Flutter sarà stabile (`desktop_multi_window` scartato: crash su Linux chiudendo una finestra, flutter/flutter#194399). Intestazioni compatte (Rispondi/Inoltra sulla riga «Da:», HTML/Testo sulla riga «Data:»). Finestre piccole (0.0.172–0.0.173, **verificate** dall'utente il 10/11/2026 su Linux e Windows): niente trabocchi da 640×480 in su (barra di ricerca, filtri sopra la lista, date della lista, gruppi, schede della barra), dimensione minima della finestra 640×480 (Linux sulla vista; Windows con `WM_GETMINMAXINFO`, compilato e provato). **Prossimo passo: da scegliere con l'utente.**

### Contatti C4 CardDAV ✅ (C4a–C4d, 05–09/11/2026)

Scelte, implementazione e verifiche: `docs/storia.md`, «Contatti» (C4). In breve: CardDAV nei due sensi per account (codice `Core/Dav/` comune con il CalDAV), server di prova IceWarp con la password e **Gmail con OAuth2** (permesso `https://www.googleapis.com/auth/carddav` chiesto solo per gli account con i contatti sincronizzati, API «CardDAV» attivata nella console Google Cloud, token Bearer; contatti nuovi su Google: PUT con 201 e `Location` = il suo id). Esclusi per ora: CardDAV e CalDAV con Microsoft. **Prossimo passo: da scegliere con l'utente.**

## Vincoli e sicurezza

- **Credenziali mai nel repository.** In sviluppo usare `dotnet user-secrets` (oppure variabili d'ambiente). `appsettings.example.json` senza valori reali.
- Connessioni cifrate di default: IMAP SSL/TLS (993) o STARTTLS (143), SMTP STARTTLS (587/25) o SSL/TLS (465). **Dalla 4.1** (scelta dell'utente 2a) "Nessuna" crittografia è possibile solo come scelta esplicita per un account, con avviso e conferma. Mai disabilitare la validazione dei certificati: l'unica eccezione è il **singolo** certificato accettato dall'utente (impronta SHA-256, 4.1 6a).
- Il core deve ascoltare **solo su `127.0.0.1`**, mai su `0.0.0.0` (impostato nel codice in Kestrel; `AllowedHosts` limitato a `localhost;127.0.0.1`).
- Ogni richiesta al core richiede `Authorization: Bearer <token>`; il token passa solo per variabile d'ambiente (mai argomenti, mai log).
- La casella è **reale**. Le letture non la modificano (`BODY.PEEK`, cartelle aperte in sola lettura quando basta, es. origine di una copia). Dalla fase 2 l'app la modifica (letto, contrassegni, categorie, sposta, copia, elimina, cartelle, bozze, invio, regole, risposte automatiche) solo per un comando dell'utente o una regola da lui attivata; ciò che non si recupera (eliminazione definitiva, invio, attivazione delle risposte automatiche) chiede conferma. Nello sviluppo, prove e script che modificano la casella o inviano mail vanno **dichiarati e confermati dall'utente prima** (come gli script di `tools/` con conferma).
- L'invio (`POST /send`) ha effetti esterni: nell'app c'è sempre una conferma con riepilogo.
- Non loggare password, token o contenuto completo delle mail.
- Mail HTML: niente JavaScript, immagini remote bloccate di default, link aperti solo se `http`/`https`/`mailto`, file locali mai caricati.

## Ambiente di sviluppo

- Sviluppo attuale su **Linux: Zorin OS 18 (base Ubuntu 24.04)**, in una VM con rendering OpenGL software (`llvmpipe`). Previsti anche **Windows** e, più avanti, macOS.
- Versioni verificate (29/10/2026; Flutter aggiornato l'11/11/2026): .NET SDK 10.0.115 (LTS; era 10.0.113, aggiornato dal sistema, visto l'11/11/2026), **Flutter 3.47.9 / Dart 3.13.7** (era 3.47.5 / 3.13.4; ripristino: `cd ~/development/flutter && git checkout 3.47.5 && flutter --version`), MailKit 4.18.2, HtmlSanitizer 9.2.1039, AngleSharp 1.7.2, provider 6.1.5, http 1.6.0, flutter_widget_from_html_core 0.17.4, url_launcher 6.3.3.
- Prima di iniziare un lavoro: **verificare le versioni effettivamente installate** (`dotnet --info`, `flutter doctor -v`); verificare sulla documentazione ufficiale le API che dipendono dalla versione.
- Dipendenze Dart (30/10/2026, richiesta dell'utente): `flutter pub upgrade` ha aggiornato 9 dipendenze transitive in `pubspec.lock` (tra cui `code_assets` 2.1.0, `record_use` 1.1.1, `hooks` 2.2.0, `objective_c` 9.6.2); le dirette erano già aggiornate. `flutter run`/`build` eseguono `pub get` solo quando serve (dopo `flutter clean` o se cambiano `pubspec.yaml`/`pubspec.lock`); in quei casi resta il messaggio informativo "3 packages have newer versions incompatible with dependency constraints": `material_color_utilities` e `test_api` sono fissati dal Flutter SDK, `cross_file` (0.3.x) dai plugin `file_selector_*`; non eliminabile da noi, sparirà con nuove versioni di Flutter e del plugin. Nessun altro avviso nella build Linux completa (C++/CMake) né in `flutter analyze`. Ripristino: `git checkout app/pubspec.lock && flutter pub get`. Le righe `libEGL warning: DRI3 error…` all'avvio vengono dalla VM senza GPU (`llvmpipe`), non dall'app. Verificato dall'utente: build senza avvisi, app funzionante.
- Dipendenze Dart (11/11/2026, richiesta dell'utente, con Flutter 3.47.9): `flutter_local_notifications` 22.3.3 → **23.0.1** (le modifiche incompatibili riguardano Android/iOS; su Windows il plugin chiede CMake ≥ 3.14 e C++20, che imposta da sé: da confermare con la build Windows) e `flutter pub upgrade` (code_assets 2.2.0, jni 1.1.2, objective_c 9.6.4). Il messaggio di `pub get` «N packages have newer versions incompatible with dependency constraints» **non è un avviso** di compilazione: elenca versioni più nuove che i vincoli non ammettono. Ne restano 8, tutti fissati da altri pacchetti già all'ultima versione (verificato su pub.dev l'11/11/2026): `cross_file` 0.3 dai `file_selector_*`; i quattro `flutter_keyboard_visibility_*` da `flutter_keyboard_visibility_temp_fork` 0.1.6 (di flutter_quill); `qr` 3 da `barcode` 2.2.9 (di pdf); `material_color_utilities` e `test_api` dal Flutter SDK. Spariranno con nuove versioni di quei pacchetti. Compaiono solo quando `pub get` ricalcola i pacchetti (prima build dopo un cambio di `pubspec.*` o dopo `flutter clean`): due build di rilascio di fila non li stampano. Forzarli con `dependency_overrides` è stato provato e scartato (scelta 2a): `pub get` stampa al loro posto 8 righe «(overridden)» e le versioni nuove hanno cambi incompatibili (`cross_file` 0.4 diviso in 5 pacchetti, `qr` 4, `flutter_keyboard_visibility` 2/3; `test_api` e `material_color_utilities` fissati dall'SDK). Ripristino: `git checkout app/pubspec.yaml app/pubspec.lock && flutter pub get`.
- Dipendenze di sistema per compilare l'app su Linux: `libsecret-1-dev` (portachiavi, `flutter_secure_storage`).
- Server di prova: IceWarp (IMAP 993, SMTP 587); username = indirizzo email. **Server, indirizzi e destinatario di prova veri non stanno nel repository** (preparazione alla pubblicazione, 12/11/2026): server negli user-secrets (`Imap:Host`, `Smtp:Host`, letti anche dagli script di `tools/`), elenco dei dati reali da non pubblicare in `tools/dati-privati.txt` (non versionato). Nei documenti si usano `mail.example.com`, `utente@example.com`, `destinatario@example.com`.

### Comandi di sviluppo

```bash
cd core && dotnet build && dotnet test          # compila il core (necessario prima di avviare l'app) + test
cd app && flutter analyze && flutter test
cd app && flutter run -d linux                  # l'app avvia da sola il core compilato
packaging/linux/build-bundle.sh                 # build di rilascio in dist/linux/postinovip/
packaging/linux/build-deb.sh                    # pacchetto .deb in dist/linux/
packaging/linux/build-appimage.sh               # AppImage in dist/linux/ (scarica appimagetool verificato)
tools/esporta-pubblico.sh <clone-pubblico> [--commit]  # esportazione ripulita verso il repository pubblico (mai push; --commit in un terminale vero, non con «!»)
tools/schermate.sh                              # schermate della casella d'esempio in dist/schermate/<data-ora> (tappa «Aspetto»)
powershell -ExecutionPolicy Bypass -File packaging\windows\build-installer.ps1   # su Windows: dist\windows\PostinoVip-Setup-<ver>.exe
```

- L'app avvia `core/src/PostinoVip.Api/bin/Debug/net10.0/PostinoVip.Api` (o `POSTINOVIP_CORE`) con token casuale (`POSTINOVIP_TOKEN` in ambiente), porta 0 e `POSTINOVIP_MANAGED=1`; il core annuncia `POSTINOVIP_READY {"port":N}` e si ferma quando l'app chiude il suo stdin (anche in caso di crash).
- Dopo una modifica al C#: `dotnet build` e **riavviare l'app** (`q` e di nuovo `flutter run`). Con l'hot restart (`R`) il core vecchio resta attivo fino alla chiusura dell'app.
- Avvio manuale del core (curl, debug):
  ```bash
  export POSTINOVIP_TOKEN=$(openssl rand -hex 32)
  cd core && dotnet run --project src/PostinoVip.Api        # porta 5080
  curl -sS -H "Authorization: Bearer $POSTINOVIP_TOKEN" http://127.0.0.1:5080/folders | jq
  # app collegata a questo core invece di avviarne uno:
  POSTINOVIP_CORE_URL=http://127.0.0.1:5080 flutter run -d linux   # stesso terminale con POSTINOVIP_TOKEN
  ```
- Un core vecchio con un'app nuova produce errori di formato (gestiti come `ApiException` con suggerimento).

## Documentazione

- `docs/architettura.html`: guida per chi entra nel progetto, con schema interattivo dei componenti e percorsi passo per passo. Aggiornarla quando cambia l'architettura e ripubblicarla allo stesso URL (artifact privato «Architettura PostinoVip», ultima: versione 27 del 12/11/2026, alla pubblicazione del codice): https://claude.ai/artifact/GX8HnzybXuJArXLNaPUUxC. Elenco degli aggiornamenti in `docs/storia.md`.
- `docs/api.md`: endpoint del core. `docs/storia.md`: storia dettagliata di fasi e step.
- Repository GitHub **privato** di sviluppo: `dummy1969/postinovip-dev` (era `dummy1969/postinovip`, rinominato il 12/11/2026, scelta 1a; remote locale aggiornato). Repository **pubblico**: `dummy1969/postinovip` (P4), clone locale in `~/sources/postinovip-pubblico`, aggiornato solo con `tools/esporta-pubblico.sh`. Dal 12/11/2026 (scelte 1a e 2b) i file versionati non contengono più dati reali; la **cronologia** sì (mail vere, server, indirizzi): questo repository resta privato. La versione pubblica sarà un repository **nuovo**, riempito solo da esportazioni ripulite di questo (script con ricerca dei dati vietati e conferma), un commit per pubblicazione; lo sviluppo resta qui.

## Lezioni apprese

- Gli script dei pacchetti riusavano un bundle già presente: un `.deb` creato dopo il punto 7 conteneva ancora la versione a un account. Ora `build-deb.sh` e `build-appimage.sh` ricompilano **sempre** il bundle; dopo una build controllare comunque la data dei file in `dist/linux/postinovip/`.

- Un processo figlio eredita l'ambiente del padre: il core avviato da `flutter run` riceveva variabili di configurazione rimaste nel terminale. L'ambiente del core va costruito esplicitamente.

- Incollare in bash un blocco che contiene `read`: `read` prende come input la riga incollata successiva. Per chiedere password usare uno script (o incollare una riga alla volta).
- Server di prova: un arrivo in INBOX genera **due** notifiche IDLE uguali (stesso conteggio): l'app le raggruppa con l'attesa di 300 ms.

- Le telecamere IP (e altri dispositivi) inviano immagini come `application/octet-stream`: il tipo va ricavato dall'estensione (`MimeTypes.GetMimeType`).
- Il parser indirizzi di MimeKit è permissivo di default: usare `RfcComplianceMode.Strict` per l'input utente.
- HtmlSanitizer codifica le virgolette dentro `style` come `&quot;` (rilevamento `url(...)` remoti).
- Nei widget test Flutter `enterText` non ricostruisce il widget: serve `pump()` prima di azioni che dipendono dallo stato.
- Dopo modifiche all'app chiudere e riavviare l'istanza in esecuzione: il primo tentativo di notifica è probabilmente fallito perché l'app aperta era stata avviata prima del codice delle notifiche (ipotesi, non più verificabile).
- Funzioni che possono fallire "in silenzio" (es. notifiche) devono scrivere il motivo nel terminale: senza diagnostica il problema non era distinguibile.
- Server di prova IceWarp: `SEARCH TEXT` restituisce **sempre zero risultati** (anche per parole nell'oggetto), mentre `SUBJECT`, `FROM`, `TO`, `BODY` funzionano (misurato il 30/10/2026): la ricerca sul server usa `SUBJECT OR FROM OR TO OR CC OR BODY`. Ipotesi non verificata: `TEXT` dipende da un indice full-text del server non attivo.
- Server di prova IceWarp: `UIDPLUS` sì, `MOVE` standard no (solo `X-MOVE`): gli spostamenti usano COPY + `\Deleted` + `UID EXPUNGE` del solo UID. Mai `EXPUNGE` dell'intera cartella.
- Windows non permette di rinominare o cancellare un file aperto (Linux sì): i difetti di "file lasciato aperto" si vedono solo lì. Ogni oggetto che apre un file (anche una `SqliteConnection` il cui setup fallisce) va chiuso anche nei percorsi d'errore; su Linux si controlla contando i descrittori in `/proc/self/fd`.
- MailKit 4.18.2: `ImapClient.Timeout` di serie è **120 000 ms** (2 minuti) per ogni lettura/scrittura; con la rete staccata a connessione aperta un comando resta fermo fino ad allora, poi `TimeoutException` e connessione chiusa (verificato: `MailKitTimeoutTests`). Le prove "senza rete" vanno fatte anche staccando la rete a connessione aperta, non solo con un server che rifiuta o non risponde al collegamento.
- MailKit 4.18.2: se il tempo massimo (annullamento) scade durante la cifratura TLS, l'errore arriva come `SslHandshakeException`, non come `OperationCanceledException`. Lo scadere del tempo va riconosciuto dal proprio `CancellationTokenSource` (`limit.IsCancellationRequested`), non dal tipo di eccezione (trovato con un server che accetta la connessione e non risponde).
- Avviare un processo in background in uno script: `(cd dir && exec comando) &` e poi `kill $PID; wait $PID`. Senza `exec` il PID è quello della sotto-shell e `kill` non chiude il programma; senza `wait` il controllo successivo lo trova ancora acceso. E non scrivere `a && b && (comando) &`: va in background **tutta** la catena, comprese le assegnazioni di variabili.
- Nelle prove a riga di comando non usare `pkill -f <testo>`: il testo compare anche nella riga di comando della shell che lo esegue, che viene uccisa. Chiudere il processo per PID (es. quello in ascolto sulla porta, `ss -ltnp`).
- Google CardDAV (verificato il 06/11/2026): il PUT di un contatto nuovo su `<UID>.vcf` risponde **201 con `Location`** = il suo id, ed è lì che il contatto resta; ignorando `Location` il contatto «sparisce» al giro dopo e torna come nuovo. Dopo un PUT di creazione leggere sempre `Location`. Serve anche l'API «CardDAV» attivata nella console (qualche minuto per attivarsi).
- Google CalDAV (verificato il 09/11/2026): al contrario dei contatti il PUT di un appuntamento nuovo risponde 201 **senza `Location`** (resta `<UID>.ics`), e GET/PUT **non mandano l'ETag** nelle intestazioni: l'ETag va letto da `getetag` nei report. Nei conteggi di uno script sui file iCalendar contare `BEGIN:<COMPONENTE>`, non il nome della riga (lo script del G1 diceva «nessun VTIMEZONE» e le RRULE dell'ora legale sembravano ricorrenze).
- Server di prova IceWarp (verificato il 09/11/2026): ricevuta una conferma di lettura (MDN) nella casella che contiene la mail originale, il server la segna `$MDNReceived` e le **toglie `$MDNSent`**. Nelle prove a sé stessi una mail «già trattata» può quindi perdere `$MDNSent`: il core considera trattate tutte e due le parole chiave.
- Outlook classico non mostra la domanda della conferma di lettura se in File → Opzioni → Posta → Rilevamento è scelto «Non inviare mai una conferma di lettura» (09/11/2026): la richiesta c'è (Proprietà della mail: «Richiedi conferma di lettura per il messaggio» spuntata). Prima di cercare un errore nel proprio codice controllare le opzioni del programma che riceve.
- MailKit 4.18.2: senza `SmtpClient.LocalDomain` l'EHLO usa il **nome del PC** (la documentazione dice l'indirizzo IP locale; misurato con il server SMTP finto il 09/11/2026), e il server lo scrive nella riga `Received:` di ogni mail inviata. Il core lo imposta a `[127.0.0.1]`.
- Il Message-ID predefinito di MimeKit contiene il nome del PC: generarlo con il dominio del mittente.
- HtmlSanitizer toglie lo stile `white-space`: per mostrare gli a capo di un testo in HTML usare `<br>` (trovato da un test della 3.7b).
- flutter_quill 11.6.0: le scorciatoie passate con `customShortcuts` **non** prevalgono su quelle del pacchetto (`mergeMaps(custom, predefinite)` fa vincere le seconde, al contrario del commento nel codice); Esc nell'editor è associato a `HideSelectionToolbarIntent` (non esportato). Per intercettare un tasto prima delle scorciatoie del pacchetto: `QuillEditorConfig.onKeyPressed`.
- Prima di aggiungere un pacchetto con parti native, aprirne l'archivio e guardare cosa contiene: `quill_native_bridge_linux` include un eseguibile precompilato, non dichiarato nella pagina del pacchetto.
- Distribuire un programma GPL già compilato obbliga a offrire il sorgente **corrispondente** (quello da cui è stato compilato, con gli script): se non si sa come è stato compilato, non basta allegare il sorgente ufficiale della stessa versione.
- Appunti X11: chiuso il programma che li possiede, il gestore degli appunti del desktop ne conserva solo alcuni formati (`SAVE_TARGETS`: immagini sì, `text/html` no). Nelle prove il programma che copia deve restare aperto, come un browser.
- Flutter: `Image.memory(bytes)` con byte decodificati di nuovo a ogni `build` è per Flutter un'immagine nuova (`MemoryImage` confronta i byte per identità): viene ridecodificata e sparisce a ogni ricostruzione. Nell'editor (ricostruito a ogni tasto) le immagini incollate sparivano mentre si scriveva: ora `dataImage` in `compose/rich_text.dart` tiene lo stesso `MemoryImage` per URL, più `gaplessPlayback`.
- Prove "senza crittografia" su un server vero: usare sempre una **password finta** ("Autenticazione rifiutata" basta a dimostrare che il collegamento in chiaro funziona). Nella prima esecuzione di `verifica-crittografia.sh` (04/11/2026) la password vera dell'account di prova è passata in chiaro verso il server di prova sulla 143: script corretto subito.
- flutter_widget_from_html_core 0.17.4: un `display` (es. `display: block`) su `td`/`tr`/`table` fa sparire **tutta la tabella**, cioè di solito l'intera mail (trovato il 04/11/2026 con la mail di benvenuto di IceWarp, vista in POP3: problema di visualizzazione, non del POP3). Il core lo toglie dalle parti delle tabelle in `HtmlBodySanitizer` (`PostProcessNode`). Per indagare un HTML che non si vede: sanificarlo con il core e disegnarlo in un widget test con `buildAsync: false` (sopra 10 000 caratteri il pacchetto lo costruisce in un isolate con `compute`, che nei test non finisce), poi togliere le proprietà a metà finché ricompare.
- I test Api girano in `Development` e quindi **caricano gli user-secrets reali**: servizi che si collegano al server (IDLE) vanno disattivati nei test (`Watch:Enabled=false`).
- Il core gira con `InvariantGlobalization` (6b): lì `string.Normalize(FormD)` non toglie gli accenti, e i test non se ne accorgono perché il progetto dei test non è in modalità invariante (trovato il 05/11/2026 con `tools/verifica-contatti.sh`: «nicolo» non trovava «Nicolò»). Per confronti senza accenti usare `Contacts/TextFold` (tabella esplicita); provare con il core vero ciò che dipende dalla cultura o da Unicode.
- Ical.Net 5.2.4 (trovati dai test del K2b): `Calendar.Children.Remove(evento)` confronta gli eventi **per UID**, e una serie e le sue occorrenze modificate hanno lo stesso UID: toglieva la serie invece dell'eccezione. Per togliere un componente preciso si ricostruiscono i figli confrontando per riferimento. `CalendarEvent.Duration = null` lancia un'eccezione se c'è DTEND (anche per azzerarlo): toccarlo solo se non è già nullo. `cal.Events` è una vista: non si toglie da lì.
- CalDAV/CardDAV: i dati (`calendar-data`, `address-data`) dentro una risposta XML arrivano con gli a capo **LF**, perché la specifica XML normalizza CRLF; iCalendar e vCard vogliono CRLF: normalizzare all'ingresso (`CalendarText.Normalize`).
- Calendari veri: i TZID non sono sempre nomi validi (`TZID=TZID`, `/freeassociation.sourceforge.net/Europe/Rome`, nomi di Windows); Ical.Net 5 di serie lancia un'eccezione e, senza protezione, un solo appuntamento blocca tutto. Provare il codice dei calendari anche con una copia dei dati veri (solo le righe dei fusi per indagare, mai i contenuti).
- Nei test della sincronizzazione non mescolare un'«ora adesso» fissa (`Now`) con l'ora vera usata dall'archivio (`SaveLocal`, `ContactStore.Update`): un conflitto deciso dall'ora cambia esito secondo l'ora in cui gira il test (trovato il 06/11/2026: un test del K2a passava fino alle 12 e falliva dopo). Usare sempre l'ora vera più o meno un margine.
- Flutter 3.47.5: `CallbackShortcuts` considera **gestito** il tasto anche se la funzione non fa niente, e la pagina principale sta sotto le scorciatoie di testo di Flutter (`DefaultTextEditingShortcuts`, in `WidgetsApp`): Invio, Canc, frecce e Ctrl+A non arrivavano alle caselle di testo (Nuova cartella «non creava nulla», 10/11/2026). Le scorciatoie da ignorare mentre si scrive devono restituire `KeyEventResult.ignored` (`_onKey` in `home_page.dart`). Nei test `receiveAction(TextInputAction.done)` salta tutto questo: provare anche con `sendKeyEvent`.
- Flutter sul desktop: con la finestra dell'app in secondo piano il `FocusManager` toglie il fuoco a tutto e lo ridà al ritorno; chi chiude qualcosa «quando perde il fuoco» deve ignorarlo se `lifecycleState` non è `resumed`. Nei test (che girano come Android) non succede.
- Il carattere dei widget test è più stretto di uno vero: `window_sizes_test` non vedeva un trabocco di 46 px a 640×480 che `tools/schermate.sh` (caratteri veri) mostra subito (11/11/2026). Le prove di misura vanno fatte anche con un carattere vero.
- Un `ButtonStyle.textStyle` (o un `TextStyle` dato al posto di quello del tema) **sostituisce** lo stile del tema invece di unirsi: senza `fontFamily` il testo prende il carattere predefinito del motore, non quello dell'app (nei test esce come rettangoli). Partire da `Theme.of(context).textTheme…copyWith(...)`. Vale anche dentro `ThemeData`: `fontFamily` arriva al `textTheme`, **non** agli stili dati ai temi dei componenti (`filledButtonTheme`, `dialogTheme`…): il V1 è uscito con i pulsanti nel carattere sbagliato, trovato dalle schermate del V2. `tools/schermate.sh` ora segnala i testi senza carattere.
- Una richiesta che resta aperta (SSE `/events`) va chiusa anche all'arresto del core (`IHostApplicationLifetime.ApplicationStopping`), non solo quando il client se ne va: Kestrel aspetta la fine delle richieste fino al tempo massimo di arresto (30 s in .NET 10) e l'app, che dava al core 5 s, si chiudeva lentamente (trovato il 12/11/2026). Misurare l'arresto con un client collegato, non a vuoto.
- Uno script che lavora su una versione committata va riprovato **dopo** il commit, sulla versione appena creata: `tools/esporta-pubblico.sh` provato sulla 0.0.210 è uscito in silenzio sulla 0.0.211, che aggiungeva un file di soli commenti (`grep -v` senza righe = codice 1, fatale con `set -e` + `pipefail`; trovato dall'utente il 12/11/2026). Negli script con `set -e` mettere un `trap … ERR` che dica la riga: niente uscite mute.
- Server di prova IceWarp (12/11/2026): per una parte di testo vuota il BODYSTRUCTURE ha il numero di righe `NIL` (RFC 3501 vuole un numero); MailKit 4.18.2 e 5.0.0 la rifiutano con `ImapProtocolException` e **chiudono la connessione**: una sola mail bloccava la cartella. Mai chiedere la struttura insieme alle intestazioni: passa da `StructureGuard`.
- Un `finally` che usa la connessione (CLOSE della cartella) dopo un errore che l'ha fatta cadere lancia un'eccezione nuova e **nasconde quella vera** («The ImapClient is not connected»). E `ServiceNotConnectedException` è una `InvalidOperationException`: nei `switch` sulle eccezioni va messa prima.
- Leggere una password o un indirizzo con il semplice `read` in uno script: un tasto accentato cancellato lascia mezzo carattere UTF-8 invisibile. Usare `read -e` e controllare i caratteri.
- Dopo aver rinominato un repository su GitHub, **ogni clone** (anche quello su Windows) va puntato al nome nuovo (`git remote set-url origin …/postinovip-dev.git`): il vecchio nome `dummy1969/postinovip` ora è il repository pubblico, e `git pull` dà `refusing to merge unrelated histories` (12/11/2026). Mai `--allow-unrelated-histories`.
- I test Api devono fare `Dispose` della `WebApplicationFactory`: ogni host apre file watcher e Linux ha un limite di 128 inotify.

## Punti aperti da verificare (non dare per scontati)

- Appunti su Linux: letti con GTK dal programma nativo (`linux/runner/clipboard_channel.cc`), lo xclip GPL del pacchetto è tolto dal bundle (risolto il 03/11/2026; dettagli in `docs/storia.md`, «Punti aperti risolti»).

- ~~Supporto desktop delle webview in Flutter~~ → valutato allo step 5: scelto rendering senza webview.
- **Chiusura improvvisa dell'app su Linux (05/11/2026, una volta)**: provando il Ccn, al clic sulla scheda Opzioni della composizione l'app si è chiusa («Lost connection to device»), senza errori Dart né segfault nei log; subito prima l'avviso «Timed out waiting for OpenGL frame of size 2014x1097 (have 1280x720)». Rilanciata sotto `gdb` con gli stessi clic: nessun problema, uscita normale. Ipotesi **non verificata**: disegno software della VM (llvmpipe) durante un cambio di dimensione della finestra. Se ricapita: `cd app && gdb -q -batch -ex "handle SIGSEGV nostop noprint pass" -ex "handle SIGPROF nostop noprint pass" -ex "handle SIGPIPE nostop noprint pass" -ex run -ex bt --args build/linux/x64/debug/bundle/postinovip 2>&1 | tee ~/postinovip-crash.txt`.
- Se `dart:io` supporti i socket Unix anche su Windows (rilevante solo se in futuro si cambia trasporto).
- ~~Comportamento del firewall di Windows con un processo in ascolto solo su loopback~~ → nessuna richiesta del firewall (verificato dall'utente il 02/11/2026).
- Credenziali in produzione: `user-secrets` vale solo in sviluppo; serve un archivio sicuro (keyring di sistema) prima del packaging.

## Versione, copyright e licenza

- **Versione `0.0.N`, N = numero progressivo del commit** (scelta dell'utente del 30/10/2026). Si parte da `0.0.54`. **A ogni commit** (anche di sola documentazione) va aumentata, nello stesso commit, in **tre punti**: `app/pubspec.yaml` (`version: 0.0.N+N`), `app/lib/app_info.dart` (`appVersion`), `core/Directory.Build.props` (`<Version>`). `app/test/version_test.dart` fallisce se non coincidono. N = `git rev-list --count HEAD` + 1 prima di committare.
- **© 2026 Marcello Anderlini**, licenza **AGPL-3.0-or-later** (testo ufficiale gnu.org in `LICENSE`, copiato in `app/assets/licenses/AGPL-3.0.txt`; il test controlla che siano uguali).
- Finestra **"Informazioni su PostinoVip"** (menu ⋮ in alto): versione dell'app e del core (`GET /version`, avviso se diverse), runtime .NET e sistema operativo, copyright e note legali richieste dalla AGPL (sez. 5d: assenza di garanzia, licenza, come leggerla); "Visualizza licenze" elenca PostinoVip, le librerie del core (`app/lib/about/licenses.dart`, testi in `app/assets/licenses/`: tutte MIT) e i pacchetti Dart (aggiunti da Flutter). **Se si aggiunge una libreria al core, aggiungerne la licenza lì.**
- Testi standard di Flutter in italiano (`flutter_localizations`, locale `it`).
- Pacchetti: `LICENSE` in `/opt/postinovip/`, avvisi del runtime .NET in `core/THIRD-PARTY-NOTICES-dotnet.txt`, `.deb` con `/usr/share/doc/postinovip/copyright`.

## Stile di lavoro richiesto

- Rispondere in **italiano**, in modo sintetico ma con tutti i passaggi necessari.
- Prima di modificare: verificare lo stato reale dei file/progetto, spiegare rischi ed effetti collaterali e come tornare indietro.
- Distinguere fatti verificati da ipotesi; chiedere conferma quando un'ipotesi porta a scelte diverse o rischiose.
- Codice e comandi pronti all'uso, spiegando cosa fanno e quale output aspettarsi.
- In caso di errori, fornire il **file completo corretto**, non diff parziali.
- L'utente ha conoscenze di base/intermedie di C# e Flutter e non conosce gRPC: spiegare i concetti nuovi brevemente quando compaiono.
- Usare git con commit piccoli, uno per step o sotto-step, con messaggi chiari.
- **Dopo ogni commit, subito `git push`** su GitHub e verifica (`git status -sb` senza "ahead"). Richiesta dell'utente del 30/10/2026.
- **A ogni commit aumentare la versione** (vedi "Versione, copyright e licenza").
