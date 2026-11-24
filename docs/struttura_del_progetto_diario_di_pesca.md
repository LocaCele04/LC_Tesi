# Struttura e Architettura del Progetto *Diario di Pesca*

## 1. Panoramica Architetturale

**Diario di Pesca** è un'applicazione mobile sviluppata in **Flutter** (linguaggio **Dart**) con architettura **offline-first** basata su database relazionale locale **SQLite**.

Per mantenere il codice ordinato, leggibile e facilmente estendibile, il progetto è strutturato secondo un'**architettura a strati (Layered Architecture)**. Ogni livello usa solo i livelli sottostanti, mai quelli superiori.

```
+-----------------------------------------------------------------------+
|  PRESENTAZIONE (UI)                                        [in corso]  |
|  lib/ui/   screens/ · widgets/ · state/ (Riverpod)                     |
+-----------------------------------------------------------------------+
            |                                   |
            | operazioni semplici               | operazioni composte
            v                                   v
+----------------------------------+  +---------------------------------+
|  REPOSITORY                      |  |  SERVIZI                        |
|  lib/repositories/               |<-|  lib/services/                  |
|  Territorio · Pescate ·          |  |  Statistiche                    |
|  Catalogo · Obiettivi            |  |  Backup · Meteo · Foto [prev.]  |
+----------------------------------+  +---------------------------------+
            |                                   |
            v                                   v
+-----------------------------------------------------------------------+
|  DATI   lib/data/                                                      |
|  DatabaseHelper (SQLite) · DbMappers · QueryCondivise · ArchivioFoto   |
+-----------------------------------------------------------------------+

     MODELLO DI DOMINIO   lib/models/   (usato da tutti i livelli)
```

* **Dati (`data`)**: le due sorgenti dati dell'app, il database SQLite e il file system delle foto, più la traduzione tra righe SQL e oggetti Dart.
* **Dominio (`models`)**: entità dell'applicazione come classi Dart immutabili, indipendenti dal database e da Flutter.
* **Repository (`repositories`)**: lettura, salvataggio ed eliminazione degli aggregati del dominio, con le relative transazioni.
* **Servizi (`services`)**: logica che coinvolge più sorgenti o più aggregati (database + file, database + rete, aggregazioni statistiche).
* **Presentazione (`ui`)**: schermate, componenti grafici e gestione dello stato dell'interfaccia con **Riverpod** (in corso; vedi `scelta_architetturale_gestione_dello_stato.md`).

### 1.1 Regola d'uso: repository o servizi?
* Per le **operazioni semplici** di lettura e salvataggio (creare uno spot, modificare un'esca, elencare le pescate) l'interfaccia usa **direttamente il repository**, attraverso i provider di Riverpod (`lib/ui/state/`), che dopo una modifica aggiornano tutte le schermate interessate.
* I **servizi** esistono solo dove la logica tocca più cose insieme e non appartiene a un singolo aggregato: acquisizione e compressione di una foto prima del salvataggio (file system + repository), backup e ripristino (database + file delle foto), previsioni meteo (rete), statistiche (query di aggregazione su più tabelle).
* Un servizio può usare i repository e il livello dati; un repository non usa mai un servizio.

### 1.2 Regola di scrittura: ogni tabella ha un solo proprietario
Ogni tabella è scritta da **un solo repository**. Così ogni regola di validazione esiste in un solo punto e non può divergere tra due copie.

| Repository | Tabelle che scrive |
| :--- | :--- |
| `TerritorioRepository` | `Categoria`, `Ambiente`, `Spot`, `Coordinata`, `Divieto`, `CoordinataDivieto` |
| `PescateRepository` | `Pescata`, `Pescata_Condizione`, `Pescata_Esca`, `RiepilogoSpecie`, `DettaglioRiepilogo`, `CatturaMemorabile`, `Cattura_Caratteristica`, `Pianificazione`, `Foto` di pescate e catture |
| `CatalogoRepository` | `Specie`, `Caratteristica`, `Esca`, `Foto` delle esche, `Condizione`, `ValoreCondizione`, `Ambiente_Condizione` |
| `ObiettiviRepository` | `Obiettivo` |
| `MeteoRepository` | `CellaMeteo`, `MeteoGiornaliero`, `MeteoOrario`, `PescataMeteo` |

Quando una pescata, una cattura memorabile o un obiettivo devono creare **al volo** un'esca, una specie o una caratteristica (es. l'utente scrive un'esca nuova mentre registra la pescata), il repository chiamante non scrive la tabella `Esca`, `Specie` o `Caratteristica`: chiama i metodi `assicuraEscaSalvata` / `assicuraSpecieSalvata` / `assicuraCaratteristicaSalvata` del `CatalogoRepository`, passando la propria transazione. La creazione resta atomica con il resto del salvataggio e la logica sta in un solo punto. Allo stesso modo `salvaSpotConCoordinate` crea, nella sua transazione, la categoria scritta al momento nel modulo dello spot. Se il nome corrisponde a un elemento esistente (senza distinzione di maiuscole e spazi), si usa quello.

**Regola dell'interfaccia:** ciò che l'utente scrive al momento in un modulo (esca, specie, categoria) resta *in sospeso* nella bozza e nasce nel catalogo solo salvando il modulo; un modulo abbandonato non lascia nulla. Togliere dalla bozza un elemento in sospeso lo scarta, e prima di farlo l'interfaccia chiede conferma.

Se il nome scritto dall'utente è già usato da un'esca o da una caratteristica esistente (senza distinzione di maiuscole e spazi):
* se l'elemento nuovo ha solo il nome, o dati già presenti in quello esistente, viene **riusato l'elemento esistente**: non si crea un doppione e non si perde nulla;
* se porta dati diversi (una descrizione diversa, foto che l'esistente non ha), il salvataggio viene **annullato** con una `NomeDuplicatoException`, che indica l'id dell'elemento esistente. Riusarlo farebbe perdere quei dati senza avvisare, quindi la scelta spetta all'utente: usare l'elemento esistente oppure cambiare nome.

Per avvisare l'utente già durante l'inserimento, prima di salvare, l'interfaccia può usare `getEscaPerNome` e `getCaratteristicaPerNome` del `CatalogoRepository`.

Le dipendenze tra repository sono quindi:
```
PescateRepository  ──usa──>  CatalogoRepository  <──usa──  ObiettiviRepository
TerritorioRepository        (indipendente)
MeteoRepository             (indipendente; usato da StatisticheService e dal futuro MeteoService)
```

Lo `StatisticheService` è di **sola lettura**: interroga direttamente il livello dati con query di aggregazione e non scrive mai.

---

## 2. Pacchetti e Dipendenze (`pubspec.yaml`)

Il progetto utilizza l'SDK **Dart `^3.11.1`** e integra un insieme essenziale di pacchetti per la persistenza locale, la gestione dei percorsi e il collaudo:

| Pacchetto | Versione | Ruolo nel progetto |
| :--- | :--- | :--- |
| **`flutter`** | SDK | Framework principale per lo sviluppo dell'interfaccia utente multipiattaforma. |
| **`sqflite`** | `^2.4.2` | Plugin nativo per la creazione e gestione del database SQLite su Android e iOS. |
| **`path`** | `^1.9.1` | Libreria per comporre in modo sicuro i percorsi dei file su disco (database e immagini). |
| **`sqflite_common_ffi`** | `^2.4.0` | Driver SQLite basato su FFI che consente di eseguire il motore relazionale su desktop durante i test automatici. |
| **`http`** | `^1.2.2` | Client HTTP per le richieste a Open-Meteo (dati meteo storici e previsioni); nei test viene sostituito da un client simulato (`MockClient`). |
| **`flutter_localizations`** | SDK | Traduzioni italiane dei componenti di Flutter (calendario, dialoghi, menu). |
| **`flutter_riverpod`** | `^3.4.1` | Gestione dello stato dell'interfaccia: rende disponibili repository e servizi alle schermate e le aggiorna quando i dati cambiano (vedi `scelta_architetturale_gestione_dello_stato.md`). |
| **`flutter_map`** | `^8.3.2` | Mappa degli spot: tessere OpenTopoMap e OpenStreetMap (con cache su disco integrata, per le zone già viste senza rete), linee dei tratti con tocco riconosciuto, segnaposto. |
| **`latlong2`** | `^0.9.1` | Tipo `LatLng` delle coordinate usato da `flutter_map`. |
| **`file_picker`** | `^13.4.1` | Finestre di sistema per salvare il file di backup e scegliere quello da ripristinare, nella memoria del telefono o su Google Drive (`BackupScreen`). |
| **`archive`** | `^4.0.7` | Creazione e lettura dell'archivio ZIP del backup. |
| **`geolocator`** | `^14.0.2` | Posizione del telefono (GPS) per il pulsante *La mia posizione*; il permesso viene chiesto solo al primo uso. |
| **`cupertino_icons`** | `^1.0.8` | Raccolta standard di icone in stile iOS affiancata alle Material Icons di Flutter. |
| **`flutter_test`** | SDK | Framework ufficiale per l'esecuzione dei test automatizzati. |
| **`flutter_lints`** | `^6.0.0` | Regole di analisi statica per mantenere coerenza stilistica e qualità del codice Dart. |

---

## 3. Organizzazione delle Directory

La radice del progetto separa il codice sorgente dell'applicazione (`lib/`) dalla suite di test (`test/`). Le voci marcate *[previsto]* non sono ancora state create.

```
diario_pesca/
├── lib/
│   ├── data/
│   │   ├── database_helper.dart       # Connessione SQLite, schema (26 tabelle, 19 indici), versione
│   │   ├── migrazioni.dart            # Passaggi di aggiornamento dello schema tra versioni
│   │   ├── db_mappers.dart            # Conversione tra righe SQL e classi Dart
│   │   ├── query_condivise.dart       # Query usate da più componenti (stato battuto, riepiloghi)
│   │   └── archivio_foto.dart         # Accesso ai file immagine sul dispositivo
│   ├── models/
│   │   ├── territorio/
│   │   │   ├── ambiente.dart
│   │   │   ├── categoria.dart
│   │   │   ├── coordinata.dart
│   │   │   ├── divieto.dart
│   │   │   └── spot.dart
│   │   ├── pescate/
│   │   │   ├── cattura_memorabile.dart
│   │   │   ├── pescata.dart
│   │   │   ├── pianificazione.dart
│   │   │   ├── riepilogo_caratteristica.dart
│   │   │   └── riepilogo_specie.dart
│   │   ├── catalogo/
│   │   │   ├── caratteristica.dart
│   │   │   ├── condizione.dart
│   │   │   ├── esca.dart
│   │   │   ├── specie.dart
│   │   │   └── valore_condizione.dart
│   │   ├── meteo/
│   │   │   ├── cella_meteo.dart
│   │   │   ├── meteo_giorno.dart
│   │   │   ├── meteo_ora.dart
│   │   │   ├── meteo_pescata.dart     # Vista di sola lettura
│   │   │   └── richiesta_meteo.dart   # Vista di sola lettura
│   │   ├── obiettivi/
│   │   │   └── obiettivo.dart
│   │   ├── enums.dart                 # Domini chiusi
│   │   ├── foto.dart                  # Condivisa da pescate, catture ed esche
│   │   └── uguaglianza.dart           # Confronto tra liste per gli operator ==
│   ├── repositories/
│   │   ├── catalogo_repository.dart
│   │   ├── eccezioni.dart             # NomeDuplicatoException
│   │   ├── meteo_repository.dart
│   │   ├── obiettivi_repository.dart
│   │   ├── pescate_repository.dart
│   │   └── territorio_repository.dart
│   ├── services/
│   │   ├── statistiche_service.dart
│   │   ├── posizione_service.dart     # Posizione del telefono (GPS)
│   │   ├── foto_service.dart          # [previsto]
│   │   ├── backup_service.dart        # Backup in un file ZIP e ripristino
│   │   └── meteo_service.dart         # Open-Meteo: storico e previsioni
│   ├── ui/
│   │   ├── state/
│   │   │   ├── dipendenze.dart        # Provider di database, repository, servizi, orologio
│   │   │   ├── spot_state.dart        # Stato degli spot (schema di riferimento)
│   │   │   ├── pescate_state.dart     # Pescate: elenco, dettaglio, totali, meteo
│   │   │   ├── catalogo_state.dart    # Esche, specie, caratteristiche, condizioni
│   │   │   ├── modulo_pescata_state.dart  # Bozza del modulo "Registra pescata"
│   │   │   ├── modulo_spot_state.dart # Bozza del modulo dello spot, lettura dei punti
│   │   │   ├── mappa_state.dart       # Spot e divieti sulla mappa, colorazione, filtri, sfondo
│   │   │   └── bozza_non_valida.dart  # Errore comune dei moduli
│   │   ├── screens/
│   │   │   ├── home_screen.dart       # Barra in basso: Pescate | Spot | Mappa
│   │   │   ├── elenco_pescate_screen.dart
│   │   │   ├── backup_screen.dart     # Backup e ripristino
│   │   │   ├── scheda_pescata_screen.dart
│   │   │   ├── elenco_spot_screen.dart
│   │   │   ├── modulo_spot_screen.dart
│   │   │   └── registra_pescata_screen.dart
│   │   ├── mappa/
│   │   │   ├── mappa_screen.dart      # Mappa: colori, legenda, filtri, schede, "Disegna"
│   │   │   ├── disegna_tratto_screen.dart  # Disegno del tratto di uno spot o divieto
│   │   │   ├── modulo_divieto_screen.dart  # Nome, note e tratto di un divieto
│   │   │   ├── tratto_in_modifica.dart     # Punti in disegno con annulla (senza widget)
│   │   │   ├── colori_mappa.dart      # Colori e legende delle viste (senza widget)
│   │   │   └── strati_mappa.dart      # Sfondi, crediti, linee e segnaposto comuni
│   │   └── widgets/
│   │       ├── vista_asincrona.dart   # Caricamento / errore / dati
│   │       ├── dialoghi.dart          # Problemi del modulo, conferma
│   │       ├── dialogo_nome.dart
│   │       └── etichette.dart
│   └── main.dart                      # Punto di ingresso dell'applicazione
├── test/
│   ├── backup_screen_test.dart
│   ├── backup_service_test.dart
│   ├── catalogo_repository_test.dart
│   ├── database_integrita_test.dart
│   ├── elenco_pescate_screen_test.dart
│   ├── elenco_spot_screen_test.dart
│   ├── modulo_pescata_test.dart
│   ├── modulo_spot_screen_test.dart
│   ├── modulo_spot_test.dart
│   ├── meteo_repository_test.dart
│   ├── meteo_service_test.dart
│   ├── migrazioni_test.dart
│   ├── obiettivi_repository_test.dart
│   ├── pescate_repository_test.dart
│   ├── pescate_state_test.dart
│   ├── registra_pescata_screen_test.dart
│   ├── spot_state_test.dart
│   ├── statistiche_service_test.dart
│   ├── territorio_repository_test.dart
│   ├── schemi/
│   │   ├── schema_v1.json             # Fotografia dello schema della versione 1
│   │   └── schema_v2.json             # ... e della versione 2 (divieti)
│   └── supporto/
│       ├── fotografia_schema.dart     # Scatta, ricarica e confronta le fotografie dello schema
│       └── open_meteo_finto.dart      # Risposta finta di Open-Meteo per i test
├── scriptCopiaDB.bat                  # Copia il database dal telefono al PC (per DBeaver)
└── pubspec.yaml
```

---

## 4. Descrizione dei Pacchetti e delle Classi

### 4.1 `lib/data/` — Livello dati
* **`DatabaseHelper`**: implementa il pattern *Singleton* per fornire un'unica istanza del database all'app (oltre a una variante in memoria per i test). Contiene lo schema relazionale composto da **26 tabelle** e **19 indici**, con vincoli di integrità referenziale attivi, e inserisce alla creazione gli ambienti e le condizioni di base. Dichiara la versione dello schema (`versioneSchema`) e all'apertura aggiorna un database di una versione precedente con i passaggi di `migrazioni.dart`, con le chiavi esterne spente durante l'aggiornamento e accese subito dopo.
* **`migrazioni.dart`**: i passaggi di aggiornamento, uno per versione, e `ricostruisciTabella` per le modifiche che `ALTER TABLE` non permette (vedi `scelta_architetturale_migrazioni_del_database.md`).
* **`DbMappers`**: traduce le righe restituite da SQLite (`Map<String, Object?>`) nelle classi del modello di dominio e viceversa. Contiene solo conversioni, nessuna query.
* **`QueryCondivise`**: query usate da più componenti, scritte in un solo punto: l'aggiornamento di `Spot.battuto` (usato da `TerritorioRepository` e `PescateRepository`) e la lettura dei riepiloghi con i dettagli per caratteristica (usata da `PescateRepository` e `StatisticheService`).
* **`ArchivioFoto`**: accesso ai file immagine sul dispositivo. I repository lo usano per cancellare i file rimasti senza riferimento, sempre dopo il commit della transazione.

### 4.2 `lib/models/` — Modello di Dominio
Tutte le classi modello sono **oggetti immutabili** (campi `final`, metodo `copyWith` e uguaglianza strutturale, vedi `scelta_architetturale_immutabilit_dei_modelli.md`). Sono suddivise in quattro sotto-pacchetti, uno per area del dominio, più tre file comuni:

* **`enums.dart`**: domini chiusi (`FasciaOraria`, `Difficolta`, `Accessibilita`) e `StatoMeteo`, che non è salvato ma calcolato. Meteo, livello, trasparenza e fondo non sono enum ma condizioni personalizzabili (`catalogo/condizione.dart`). Sono salvati nel database con il nome del valore (`.name`): **i nomi dei valori non vanno rinominati**, altrimenti i dati già salvati non vengono più letti.
* **`foto.dart`**: `Foto`, riferimento a un'immagine salvata sul dispositivo (`percorso` e `percorsoThumbnail`), associabile in modo esclusivo a una pescata, a una cattura memorabile o a un'esca. Sta fuori dai sotto-pacchetti perché è usata da più aree.
* **`uguaglianza.dart`**: funzione `listeUguali`, usata dagli `operator ==` dei modelli che contengono liste.
* **Pacchetto `territorio/`**:
  * `Ambiente`: tipologia di corso o specchio d'acqua dello spot (di base *Torrente*, *Fiume*, *Lago*, *Mare*), estendibile dall'utente.
  * `Categoria`: raggruppamento di spot scelto dall'utente, come una cartella (es. *Fondopiano*, *Val Sorbina*, *Valle Ombrosa*).
  * `Spot`: luogo di pesca con le sue caratteristiche fisiche e logistiche e la lista delle coordinate.
  * `Coordinata`: singolo punto GPS (`latitudine`, `longitudine`, `ordine`) che compone il tracciato di uno spot o di un divieto.
  * `Divieto`: tratto in cui la pesca è vietata, con nome, note e punti. Non è uno spot: si vede solo sulla mappa; l'identità è l'`id`, perché più divieti possono avere lo stesso nome.
* **Pacchetto `pescate/`**:
  * `Pescata`: entità centrale che raccoglie data, condizioni meteo-ambientali, spot visitato, esche utilizzate, riepiloghi, catture memorabili e foto.
  * `RiepilogoSpecie` e `RiepilogoCaratteristica`: totale degli esemplari catturati per specie in una pescata e loro suddivisione per caratteristica.
  * `CatturaMemorabile`: singola cattura da ricordare, collegata a una pescata, con specie, esca, caratteristiche e foto.
  * `Pianificazione`: pescata futura prevista, con data, fascia oraria, spot e note.
* **Pacchetto `catalogo/`** (anagrafiche personali del pescatore):
  * `Specie`: specie ittiche.
  * `Caratteristica`: tratto distintivo definito dall'utente per una specie (es. livrea o taglia).
  * `Esca`: esca o artificiale, con descrizione ed eventuali foto.
  * `Condizione` e `ValoreCondizione`: condizioni che il pescatore registra nelle pescate (es. Livello, Meteo, Stato del mare) con i loro valori ordinati in una scala. Sono definite dall'utente e collegate agli ambienti per cui hanno senso; la `Pescata` contiene i valori scelti (`valoriCondizioni`, al massimo uno per condizione).
* **Pacchetto `obiettivi/`**:
  * `Obiettivo`: traguardo numerico annuale per una specie, generico o legato a una caratteristica.
* **Pacchetto `meteo/`** (dati meteo storici scaricati da Open-Meteo):
  * `CellaMeteo`: cella della griglia del modello meteo (circa 2 km) a cui appartiene il punto di uno spot, alla quota di quel punto. La quota fa parte dell'identità della cella perché Open-Meteo corregge le temperature in base alla quota.
  * `MeteoGiorno` e `MeteoOra`: dati giornalieri e orari di una cella (pioggia, temperature, pressione, vento). Le ore sono in UTC.
  * `RichiestaMeteo` e `MeteoPescata`: viste di sola lettura, cioè una pescata da scaricare con il punto a cui chiedere i dati, e il meteo completo di una pescata (stato, cella, 31 giorni, ore del giorno prima e del giorno stesso).

#### Identità degli oggetti: id nullable e chiavi naturali
I modelli identificano le righe del database in due modi.

* **Id numerico generato da SQLite** (`Pescata`, `CatturaMemorabile`, `RiepilogoSpecie`, `Pianificazione`, `Foto`, `Esca`, `Caratteristica`, `Condizione`, `ValoreCondizione`, `Obiettivo`, `CellaMeteo`): il campo è `int? id`.
  * `id == null` significa **oggetto non ancora salvato**: l'id lo assegna SQLite all'inserimento, quindi prima non esiste. Il getter `isNuovo` rende esplicito il controllo.
  * Grazie a questa convenzione una sola classe rappresenta sia l'oggetto nuovo sia quello salvato, e i repository decidono se inserire o aggiornare in base a `isNuovo`. È anche ciò che permette la **creazione al volo** (§1.2): un'esca con `isNuovo == true` dentro una cattura viene creata nella stessa transazione.
  * I repository **restituiscono sempre oggetti con l'id valorizzato**. L'interfaccia deve continuare a lavorare sull'oggetto restituito dal salvataggio, non su quello che ha passato.
  * Dentro un aggregato non ancora salvato anche gli id dei genitori sono `null` (es. le foto di una pescata nuova hanno `pescataId == null`): li assegna il repository al salvataggio.
  * Il salvataggio produce un oggetto diverso (con l'id), quindi per `==` e `hashCode` l'oggetto prima e dopo il salvataggio non sono uguali. Un oggetto nuovo non va usato come chiave di una `Map` o di un `Set` da ritrovare dopo il salvataggio.
* **Chiave naturale**, cioè il nome (`Spot`, `Categoria`, `Ambiente`, `Specie`): il nome è sia l'identità sia il dato da mostrare. Da solo l'oggetto non dice se è nuovo o già salvato, per questo i repository hanno metodi distinti per inserire e aggiornare, e l'aggiornamento riceve il `nomeOriginale` (necessario anche per rinominare).

#### Regola sui riferimenti tra modelli
* Un modello **contiene come oggetti** i propri componenti interni: `Pescata` contiene `RiepilogoSpecie`, `CatturaMemorabile` e `Foto`; `Spot` contiene le `Coordinata`; `Esca` contiene le sue `Foto`.
* Il riferimento al **genitore** è sempre una chiave: `Foto.pescataId`, `CatturaMemorabile.pescataId`, `Coordinata.spotNome`, `RiepilogoCaratteristica.riepilogoSpecieId`.
* Il riferimento a un'entità di **un altro pacchetto** dipende dal tipo di chiave:
  * se la chiave è **naturale** (il nome stesso), basta la chiave, perché è già il dato da mostrare: `spotNome`, `specieNome`, `categoriaNome`, `ambiente`;
  * se la chiave è un **id numerico**, il modello porta l'oggetto, così l'interfaccia ha il nome senza query aggiuntive: `Pescata.esche`, `Pescata.valoriCondizioni`, `CatturaMemorabile.esca`, `CatturaMemorabile.caratteristiche`, `Obiettivo.caratteristica`, `RiepilogoCaratteristica.caratteristica`.

### 4.3 `lib/repositories/` — Repository
Un repository per area del dominio; la tabella in §1.2 indica quali tabelle scrive ciascuno.

* **`TerritorioRepository`**: categorie, ambienti, spot e coordinate GPS, con il calcolo automatico della lunghezza del tratto (formula di Haversine), lo spostamento degli spot tra categorie, i divieti con i loro punti (`getDivieti`, `salvaDivieto`, `eliminaDivieto`) e, prima di cambiare l'ambiente di uno spot, l'elenco delle condizioni usate dalle sue pescate e non previste dal nuovo ambiente (`getCondizioniNonPreviste`).
* **`PescateRepository`**: pescate complete (salvate in modo atomico con valori delle condizioni, esche, foto, riepiloghi, dettagli e catture memorabili), catture memorabili e pianificazioni, con il filtro delle pescate per valori di condizione e i totali delle catture di ogni pescata per gli elenchi (`getTotaliCatture`). Garantisce lo spot obbligatorio, un solo valore per condizione, il vincolo dettaglio ≤ totale e la pulizia dei file immagine non più usati.
* **`CatalogoRepository`**: specie, caratteristiche, esche e condizioni (con valori, attivazione, collegamenti agli ambienti, copia dei collegamenti da un altro ambiente e le condizioni da mostrare nel form di una pescata, `getCondizioniPerForm`); offre agli altri repository la creazione al volo di esche, specie e caratteristiche dentro una transazione esistente, con il controllo dei nomi già usati (`NomeDuplicatoException`), e all'interfaccia la ricerca per nome (`getEscaPerNome`, `getCaratteristicaPerNome`).
* **`ObiettiviRepository`**: obiettivi annuali.
* **`MeteoRepository`**: archivio dei dati meteo storici. Indica quali pescate sono da scaricare e con quale punto, quale cella è già nota per un punto e quali giorni e ore mancano in archivio; salva i dati scaricati (un dato riscaricato sostituisce il precedente); calcola lo stato del meteo di una pescata e ne restituisce i dati. Non accede alla rete.

Tutti i repository ricevono il `DatabaseHelper` (e, dove serve, gli altri repository e l'`ArchivioFoto`) dal costruttore: in produzione si usano le istanze predefinite, nei test un database in memoria.

### 4.4 `lib/services/` — Servizi
* **`StatisticheService`** *(implementato)*: statistiche di sola lettura sullo storico. Oggi espone la lettura dei riepiloghi per pescata o per specie e la pioggia cumulata nei giorni precedenti una pescata (`getPioggiaCumulata`, con finestra da 1 a 30 giorni); accoglierà medie, conteggi, confronti tra anni e progresso degli obiettivi.
* **`FotoService`** *(previsto)*: acquisizione da fotocamera o galleria, compressione, generazione delle anteprime e salvataggio con percorso relativo alla cartella documenti dell'app (REQ-DES-03), tramite `ArchivioFoto`.
* **`BackupService`** *(implementato)*: backup e ripristino di tutti i dati (REQ-FUN-14, REQ-FUN-15). Il backup è un archivio ZIP con `manifesto.json` (formato `diario-pesca-backup`, versione del formato, data di creazione, versione dello schema), `diario_pesca.db` (copia coerente del database fatta con `VACUUM INTO`, o copia del file con SQLite precedente alla 3.27) e `foto/` (i file delle foto con i percorsi relativi registrati nel database; la cartella arriverà con il `FotoService`). Il servizio produce e legge solo byte: la destinazione la sceglie l'utente nella finestra di sistema. `leggi` controlla il file senza toccare i dati (archivio, manifesto, versioni non più recenti dell'app, `PRAGMA integrity_check`, percorsi delle foto interni alla cartella) e restituisce un riepilogo (`ContenutoBackup`) o un `BackupNonValido` con il motivo in parole; `ripristina` sostituisce il file del database tramite `DatabaseHelper.sostituisciCon`, che lo apre applicando le migrazioni e, se l'apertura fallisce, rimette al suo posto il database precedente. Motivazioni in `scelta_architetturale_backup_e_ripristino.md`. **Il file di backup contiene dati personali: il `.gitignore` esclude `*backup*.zip`.**
* **`MeteoService`** *(implementato)*: comunicazione con Open-Meteo tramite il pacchetto `http`, in due ruoli:
  * **previsioni** per un punto nei giorni e nelle ore successive (`getPrevisioni`, REQ-FUN-13), solo da mostrare, senza salvarle;
  * **scaricamento dei dati storici** delle pescate (`aggiornaStorico`, REQ-FUN-17):
    * considera solo le pescate di giorni già conclusi;
    * le raggruppa per punto e, nello stesso punto, per intervalli di date che si sovrappongono;
    * se la cella del punto è già nota e l'archivio contiene tutto, collega la pescata senza nessuna chiamata (`assegnaCella`);
    * altrimenti scarica con una sola chiamata i giorni e le ore mancanti dall'archivio delle previsioni passate (*Historical Forecast API*, modello scelto da Open-Meteo: sulle Alpi ICON-D2, circa 2 km), con un giorno di margine per lato (Open-Meteo calcola i confini delle ore con uno scarto fisso che ignora l'ora legale), e salva con `salvaDati` solo i giorni già conclusi e le ore necessarie;
    * collega una pescata alla cella solo quando i suoi dati sono completi; giorni ancora vuoti nella risposta restano mancanti e vengono richiesti al tentativo successivo;
    * un errore di rete o del servizio non interrompe l'aggiornamento: il gruppo resta da scaricare. Il risultato (`EsitoAggiornamentoMeteo`) riporta pescate completate, incomplete, errori e chiamate.

  Le richieste usano `timeformat=unixtime`, così le ore arrivano come istanti UTC esatti. La pressione media giornaliera è calcolata dalla pressione oraria, perché il nome della variabile giornaliera non è documentato. Il servizio va avviato quando c'è rete (all'apertura dell'app o dello storico) e non blocca mai la registrazione di una pescata. Dove l'app mostra i dati deve comparire `MeteoService.attribuzione` (licenza CC BY 4.0).

  La fonte è stata scelta con una prova sui 164 spot dello storico con coordinate (stagione 2025): la rianalisi storica (circa 10 km) li riduceva a 15 celle, l'archivio delle previsioni passate a 36, e arriva fino a ieri senza ritardo, così tutto lo storico ha un'unica fonte coerente con le previsioni.

  **Limiti noti:** la cella di un punto è quella della prima risposta; l'archivio delle previsioni passate è completo dalla metà del 2021: per date più vecchie mancano alcune variabili, e i giorni senza nessun valore restano mancanti (la pescata resta incompleta e viene ritentata).

### 4.5 `lib/ui/` — Presentazione *(in corso)*
La gestione dello stato usa **Riverpod 3**; motivazioni, alternative e regole d'uso sono in `scelta_architetturale_gestione_dello_stato.md`.
* **`state/`**: i provider. È l'unico punto in cui lo stato è mutabile: i modelli restano immutabili e ogni modifica confermata dall'utente passa da un repository o da un servizio.
  * `dipendenze.dart`: un provider per il database, ogni repository e ogni servizio, creati una sola volta. Nei test basta sostituire `databaseHelperProvider` con un database in memoria.
  * `spot_state.dart`: stato degli spot ed **esempio di riferimento** per le altre aree. `elencoSpotProvider` (elenco con i metodi `salva` ed `elimina`, che chiamano il repository e invalidano elenco, dettagli e pescate), `dettaglioSpotProvider` (spot con coordinate, `autoDispose`), `categorieProvider` e `ambientiProvider`. Le categorie si aggiungono solo salvando uno spot (vedi la regola sulla creazione al volo, §1.2).
  * `pescate_state.dart`: `elencoPescateProvider`, con `salva` ed `elimina`. Salvare una pescata ricarica anche gli spot (lo spot diventa *battuto*), le esche e le specie (quelle scritte al momento entrano nel catalogo), il dettaglio e il meteo della pescata. `totaliCattureProvider` e `pescateSenzaMeteoProvider` *dipendono* dall'elenco: si ricalcolano da soli quando l'elenco viene ricaricato, senza invalidazioni esplicite. `dettaglioPescataProvider`, `meteoPescataProvider` e `pioggiaCumulataProvider` (pioggia dei giorni precedenti, dallo `StatisticheService`) servono la scheda. `aggiornamentoMeteoProvider` scarica il meteo mancante con il `MeteoService` e ne tiene l'esito; mentre scarica è in caricamento.
  * `catalogo_state.dart`: esche, specie, caratteristiche di una specie, condizioni del modulo per un ambiente (`condizioniPerFormProvider`, che per una pescata già salvata include anche le condizioni che usa) e nomi delle condizioni per id.
  * `modulo_spot_state.dart`: il modulo dello spot, nuovo o da modificare. `BozzaSpot` (nome, categoria con l'eventuale categoria nuova in sospeso, ambiente, difficoltà, accessibilità, voto, punti del tratto, lunghezza scritta a mano usata solo con meno di due punti, note e link del parcheggio) con `errori()` e `inSpot()`; `ModuloSpotNotifier` (`autoDispose`, una bozza per spot) con un metodo per ogni modifica, `salva()` ed `elimina()`. `aggiungiCategoriaNuova()` sceglie una categoria esistente con lo stesso nome o ne tiene una nuova in sospeso; `categoriaScartata()` dice se sceglierne un'altra la scarterebbe, per chiedere conferma. Se cambia l'ambiente di uno spot, `condizioniDaCollegare()` restituisce le condizioni già usate nelle sue pescate ma non previste per il nuovo ambiente, che l'utente può collegare al salvataggio. `leggiCoordinata()` riconosce un punto incollato da Google Maps: due numeri (con punto o virgola decimale), gradi-primi-secondi o un link completo; i link brevi `maps.app.goo.gl` non contengono le coordinate.
  * `mappa_state.dart`: `spotSullaMappaProvider` (tutti gli spot con le loro coordinate, lette con una sola query; *dipende* dall'elenco degli spot, quindi segue da solo salvataggi, eliminazioni e pescate che rendono uno spot *battuto*), `divietiProvider` (divieti con `salva` ed `elimina`) e `vistaMappaProvider` (`VistaMappa`: colorazione, mappa di sfondo e filtri per stato, ambienti, categorie e divieti). Ambienti e categorie si filtrano per esclusione, così quelli creati dopo sono visibili senza doverli attivare.
  * `bozza_non_valida.dart`: l'errore `BozzaNonValida`, comune ai moduli, con i problemi in parole per l'utente.
  * `modulo_pescata_state.dart`: il modulo della pescata, nuova o da modificare. `moduloPescataProvider` è una *family*: `null` per una pescata nuova, `(pescata: …, ambiente: …)` per modificarne una; in modifica la bozza parte dai dati salvati e conserva id, foto e catture memorabili, che il modulo non tocca. Una pescata rimasta senza spot (spot eliminato) si modifica senza doverne scegliere uno. `BozzaPescata` è la bozza immutabile (spot e ambiente, data, fascia oraria, valori delle condizioni, esche, catture per specie con le caratteristiche, specie nuove in sospeso, temperatura dell'acqua e note); `errori()` restituisce i problemi in parole per l'utente, `inPescata()` la pescata da salvare. `ModuloPescataNotifier` (`autoDispose`) ha un metodo per ogni modifica e `salva()`. Cambiando lo spot verso un altro ambiente i valori delle condizioni si tolgono; cambiando la specie di una riga si tolgono le sue caratteristiche; un'esca o una specie nuova con il nome di una esistente seleziona quella. Una specie nuova resta in sospeso finché qualche riga la usa; `specieScartata()` dice se togliere o cambiare una riga la scarterebbe.
* **`widgets/`**: componenti riutilizzabili. `VistaAsincrona` mostra un dato asincrono nei suoi tre stati: caricamento, errore con pulsante *Riprova*, dati; `sezioneAsincrona` è la versione compatta per una sezione di un modulo. `mostraProblemi` e `chiediConferma` sono i dialoghi comuni; `chiediNome` chiede un nome in un dialogo; `etichette.dart` contiene i testi per l'utente (fasce orarie, date in italiano).
* **`screens/`**: le schermate.
  * `HomeScreen`: schermata iniziale, con la barra in basso che passa tra *Pescate*, *Spot* e *Mappa*; le sezioni restano in memoria e non perdono la posizione o l'inquadratura. La mappa viene creata solo alla prima apertura della sua sezione.
  * `ElencoPescateScreen`: pescate dalla più recente, divise per mese, con data, fascia, spot (o *Spot eliminato*), totale delle catture e l'icona del meteo da scaricare. *Nuova pescata* apre il modulo; il pulsante in alto scarica il meteo mancante e ne descrive l'esito; dal menu si apre *Backup e ripristino*.
  * `BackupScreen`: *Crea backup* propone un nome con data e ora e apre la finestra di sistema per salvarlo (memoria del telefono o Google Drive), poi conferma data e ora del salvataggio. *Scegli un backup* controlla il file e ne mostra il riepilogo (data, spot, divieti, pescate, catture, foto; un avviso se viene da una versione precedente dell'app) o il motivo per cui non si può usare; *Ripristina* chiede conferma prima di sostituire i dati, poi fa rileggere il database a tutte le schermate. Se il ripristino fallisce dice che i dati sono rimasti quelli di prima.
  * `SchedaPescataScreen`: spot, data e fascia, catture per specie con le caratteristiche e il totale, condizioni, temperatura dell'acqua, esche, note e meteo. Il meteo mostra lo stato: *non disponibile* (spot senza coordinate), *da scaricare* (con il pulsante per scaricarlo, solo per giornate concluse) o i dati del giorno (temperatura minima e massima, pioggia, vento e raffiche massimi della giornata intera a 10 m dal suolo con la direzione, pressione) con la pioggia dei 3, 7 e 14 giorni precedenti, la quota della zona e l'attribuzione richiesta da Open-Meteo. Dalla barra in alto si modifica (riapre il modulo con i dati salvati) o si elimina, con conferma.
  * `ElencoSpotScreen` mostra gli spot con ambiente, categoria e stato *battuto*, e si aggiorna trascinando verso il basso: toccando uno spot lo si modifica, *Nuovo spot* ne crea uno.
  * `ModuloSpotScreen` (nuovo spot o modifica, aperto per nome con `ModificaSpotScreen`): nome, categoria (con una categoria nuova scritta al momento, che nasce salvando lo spot; sceglierne un'altra chiede conferma prima di scartarla), ambiente, difficoltà, accessibilità, voto, punti del tratto (disegnati sulla mappa con *Disegna sulla mappa*, oppure incollati e confermati con il pulsante *Aggiungi punto*, con riordino e rimozione; il primo è quello del meteo; un punto rimasto nel campo viene aggiunto salvando), lunghezza calcolata o scritta a mano, punti complicati, note e link del parcheggio. Cambiando l'ambiente propone di collegare le condizioni già usate nelle pescate; l'eliminazione chiede conferma. Si chiude restituendo lo spot salvato. Uno spot nuovo può partire dai punti appena disegnati sulla mappa (`puntiIniziali`).
  * `RegistraPescataScreen` ([REQ-FUN-06], [REQ-FUN-07]), per una pescata nuova o da modificare: spot con ricerca per nome, data (non futura), fascia oraria, condizioni dell'ambiente dello spot, temperatura dell'acqua (quella dell'aria viene dal meteo), esche (con ricerca e aggiunta di un'esca nuova), catture per specie con totale e caratteristiche (con aggiunta di una specie nuova), totale della pescata e note. Esche e specie nuove nascono salvando la pescata; togliere un'esca nuova o l'ultima riga che usa una specie nuova chiede conferma. Salvando, i problemi vengono elencati in un dialogo. Il pulsante *Nuovo spot* apre il modulo dello spot e sceglie subito lo spot creato. Aperta dalla scheda di uno spot sulla mappa, parte con quello spot già scelto (`spotIniziale`). Mancano ancora le foto e le catture memorabili (servono il `FotoService`).

* **`mappa/`**: la mappa ([REQ-FUN-01], [REQ-FUN-02], [REQ-FUN-03], [REQ-FUN-18]). Le parti senza widget (`colori_mappa.dart`, `tratto_in_modifica.dart`) sono separate dalle schermate, così si provano con test unitari.
  * `MappaScreen`: spot e divieti su una mappa topografica (OpenTopoMap, con curve di livello e corsi d'acqua) o stradale (OpenStreetMap), con i crediti richiesti dalle licenze. Gli spot si colorano per **stato** (blu se ci hai pescato, bianco se no), **voto** (cinque fasce dal rosso al blu, come nel file di Google Earth dell'utente; grigio senza voto), **ambiente**, **categoria**, **difficoltà** o **accessibilità**, con la legenda dei soli valori presenti; tutte le linee hanno un bordo scuro, così anche quelle chiare si vedono. Gli ambienti di base hanno colori fissi; gli altri ambienti e le categorie hanno un colore calcolato dal nome, che non cambia quando se ne aggiungono altri. I divieti sono sempre rosso scuro tratteggiati. Uno spot con un solo punto è un segnaposto. Toccando una linea si apre la scheda dello spot (*Registra pescata qui*, *Modifica*) o del divieto (*Modifica*). *Filtri* nasconde spot per stato, ambiente o categoria e i divieti; *La mia posizione* centra la mappa sul GPS; *Disegna* crea uno spot (si disegna il tratto, poi si apre il modulo con i punti) o un divieto. Mentre i dati si ricaricano la mappa resta quella di prima, così non perde l'inquadratura.
  * `DisegnaTrattoScreen`: disegno del tratto, usato da mappa, modulo dello spot e modulo del divieto. Tocco sulla mappa: punto in fondo; trascinamento: sposta il punto (mentre si trascina la mappa resta ferma); "+" a metà di un segmento: inserisce un punto; pressione lunga: lo elimina; *Annulla* torna indietro di un'operazione (un trascinamento intero conta come una). Mostra numero di punti e lunghezza, sullo sfondo gli altri spot e i divieti più chiari, e chiede conferma prima di uscire senza salvare. Restituisce i punti con *Fatto*.
  * `ModuloDivietoScreen`: nome, note e tratto di un divieto, con salvataggio ed eliminazione (con conferma).

L'interfaccia è in italiano anche nei componenti di Flutter (calendario, dialoghi) grazie a `flutter_localizations`.

Nell'app e nei test i nuovi tentativi automatici di Riverpod sono disattivati: un errore viene mostrato subito e l'utente può riprovare.

Il manifesto Android dichiara il permesso `INTERNET`, necessario alla versione di rilascio per scaricare il meteo e le tessere della mappa (la versione di debug lo ha già), e i permessi di posizione (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) per il pulsante *La mia posizione*.

### 4.6 `test/` — Test automatici
Una suite per componente, descritte nel `registro_dei_test_automatici.md`:
`database_integrita_test.dart` (schema), `migrazioni_test.dart` (aggiornamento dello schema tra versioni), `territorio_repository_test.dart`, `pescate_repository_test.dart`, `catalogo_repository_test.dart`, `obiettivi_repository_test.dart`, `meteo_repository_test.dart`, `meteo_service_test.dart`, `statistiche_service_test.dart`, `spot_state_test.dart`, `pescate_state_test.dart`, `modulo_pescata_test.dart` e `modulo_spot_test.dart` (stato dell'interfaccia), `elenco_spot_screen_test.dart`, `elenco_pescate_screen_test.dart`, `registra_pescata_screen_test.dart` e `modulo_spot_screen_test.dart` (schermate), `backup_service_test.dart` e `backup_screen_test.dart` (backup e ripristino). La risposta finta di Open-Meteo usata da più suite e gli strumenti per le fotografie dello schema stanno in `test/supporto/`; le fotografie in `test/schemi/`.

---

## 5. Evoluzione dello schema
Il database è alla **versione 2**: la prima migrazione ha aggiunto i divieti (tabelle `Divieto` e `CoordinataDivieto`). Ogni modifica allo schema alza la versione e aggiunge in `lib/data/migrazioni.dart` il passaggio che aggiorna i database esistenti senza perdere i dati; i test di `test/migrazioni_test.dart`, con le fotografie dello schema in `test/schemi/`, segnalano una modifica a `onCreate` senza migrazione e verificano che ogni versione precedente, aggiornata, coincida con un database nuovo. Motivazioni e funzionamento sono in `scelta_architetturale_migrazioni_del_database.md`. Lo stesso numero di versione è scritto nel manifesto del backup (ed è nel database copiato): un backup di una versione precedente viene aggiornato dalle migrazioni durante il ripristino, uno di una versione più recente viene rifiutato.
