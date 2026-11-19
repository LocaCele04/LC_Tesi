# Struttura e Architettura del Progetto *Diario di Pesca*

## 1. Panoramica Architetturale

**Diario di Pesca** è un'applicazione mobile sviluppata in **Flutter** (linguaggio **Dart**) con architettura **offline-first** basata su database relazionale locale **SQLite**.

Per mantenere il codice ordinato, leggibile e facilmente estendibile, il progetto è strutturato secondo un'**architettura a strati (Layered Architecture)**. Ogni livello usa solo i livelli sottostanti, mai quelli superiori.

```
+-----------------------------------------------------------------------+
|  PRESENTAZIONE (UI)                                        [previsto]  |
|  lib/ui/   screens/ · widgets/ · state/                                |
+-----------------------------------------------------------------------+
            |                                   |
            | operazioni semplici               | operazioni composte
            v                                   v
+----------------------------------+  +---------------------------------+
|  REPOSITORY                      |  |  SERVIZI                        |
|  lib/repositories/               |<-|  lib/services/                  |
|  Territorio · Pescate ·          |  |  Statistiche                    |
|  Catalogo · Obiettivi            |  |  Foto · Backup · Meteo [prev.]  |
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
* **Presentazione (`ui`)**: schermate, componenti grafici e gestione dello stato dell'interfaccia (non ancora implementata).

### 1.1 Regola d'uso: repository o servizi?
* Per le **operazioni semplici** di lettura e salvataggio (creare uno spot, modificare un'esca, elencare le pescate) l'interfaccia chiama **direttamente il repository**.
* I **servizi** esistono solo dove la logica tocca più cose insieme e non appartiene a un singolo aggregato: acquisizione e compressione di una foto prima del salvataggio (file system + repository), backup su Google Drive (database + file + rete), previsioni meteo (rete), statistiche (query di aggregazione su più tabelle).
* Un servizio può usare i repository e il livello dati; un repository non usa mai un servizio.

### 1.2 Regola di scrittura: ogni tabella ha un solo proprietario
Ogni tabella è scritta da **un solo repository**. Così ogni regola di validazione esiste in un solo punto e non può divergere tra due copie.

| Repository | Tabelle che scrive |
| :--- | :--- |
| `TerritorioRepository` | `Categoria`, `Ambiente`, `Spot`, `Coordinata` |
| `PescateRepository` | `Pescata`, `Pescata_Esca`, `RiepilogoSpecie`, `DettaglioRiepilogo`, `CatturaMemorabile`, `Cattura_Caratteristica`, `Pianificazione`, `Foto` di pescate e catture |
| `CatalogoRepository` | `Specie`, `Caratteristica`, `Esca`, `Foto` delle esche |
| `ObiettiviRepository` | `Obiettivo` |

Quando una pescata, una cattura memorabile o un obiettivo devono creare **al volo** un'esca o una caratteristica (es. l'utente scrive un'esca nuova mentre registra la pescata), il repository chiamante non scrive la tabella `Esca` o `Caratteristica`: chiama i metodi `assicuraEscaSalvata` / `assicuraCaratteristicaSalvata` del `CatalogoRepository`, passando la propria transazione. La creazione resta atomica con il resto del salvataggio e la logica sta in un solo punto.

Le dipendenze tra repository sono quindi:
```
PescateRepository  ──usa──>  CatalogoRepository  <──usa──  ObiettiviRepository
TerritorioRepository        (indipendente)
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
│   │   ├── database_helper.dart       # Connessione SQLite, schema (16 tabelle, 16 indici)
│   │   ├── db_mappers.dart            # Conversione tra righe SQL e classi Dart
│   │   ├── query_condivise.dart       # Query usate da più componenti (stato battuto, riepiloghi)
│   │   └── archivio_foto.dart         # Accesso ai file immagine sul dispositivo
│   ├── models/
│   │   ├── territorio/
│   │   │   ├── ambiente.dart
│   │   │   ├── categoria.dart
│   │   │   ├── coordinata.dart
│   │   │   └── spot.dart
│   │   ├── pescate/
│   │   │   ├── cattura_memorabile.dart
│   │   │   ├── pescata.dart
│   │   │   ├── pianificazione.dart
│   │   │   ├── riepilogo_caratteristica.dart
│   │   │   └── riepilogo_specie.dart
│   │   ├── catalogo/
│   │   │   ├── caratteristica.dart
│   │   │   ├── esca.dart
│   │   │   └── specie.dart
│   │   ├── obiettivi/
│   │   │   └── obiettivo.dart
│   │   ├── enums.dart                 # Domini chiusi
│   │   ├── foto.dart                  # Condivisa da pescate, catture ed esche
│   │   └── uguaglianza.dart           # Confronto tra liste per gli operator ==
│   ├── repositories/
│   │   ├── catalogo_repository.dart
│   │   ├── obiettivi_repository.dart
│   │   ├── pescate_repository.dart
│   │   └── territorio_repository.dart
│   ├── services/
│   │   ├── statistiche_service.dart
│   │   ├── foto_service.dart          # [previsto]
│   │   ├── backup_service.dart        # [previsto]
│   │   └── meteo_service.dart         # [previsto]
│   ├── ui/                            # [previsto] screens/ · widgets/ · state/
│   └── main.dart                      # Punto di ingresso dell'applicazione
├── test/
│   ├── catalogo_repository_test.dart
│   ├── database_integrita_test.dart
│   ├── obiettivi_repository_test.dart
│   ├── pescate_repository_test.dart
│   ├── statistiche_service_test.dart
│   └── territorio_repository_test.dart
├── scriptCopiaDB.bat                  # Copia il database dal telefono al PC (per DBeaver)
└── pubspec.yaml
```

---

## 4. Descrizione dei Pacchetti e delle Classi

### 4.1 `lib/data/` — Livello dati
* **`DatabaseHelper`**: implementa il pattern *Singleton* per fornire un'unica istanza del database all'app (oltre a una variante in memoria per i test). Contiene lo schema relazionale composto da **16 tabelle** e **16 indici**, con vincoli di integrità referenziale attivi, e inserisce gli ambienti di base alla creazione.
* **`DbMappers`**: traduce le righe restituite da SQLite (`Map<String, Object?>`) nelle classi del modello di dominio e viceversa. Contiene solo conversioni, nessuna query.
* **`QueryCondivise`**: query usate da più componenti, scritte in un solo punto: l'aggiornamento di `Spot.battuto` (usato da `TerritorioRepository` e `PescateRepository`) e la lettura dei riepiloghi con i dettagli per caratteristica (usata da `PescateRepository` e `StatisticheService`).
* **`ArchivioFoto`**: accesso ai file immagine sul dispositivo. I repository lo usano per cancellare i file rimasti senza riferimento, sempre dopo il commit della transazione.

### 4.2 `lib/models/` — Modello di Dominio
Tutte le classi modello sono **oggetti immutabili** (campi `final`, metodo `copyWith` e uguaglianza strutturale, vedi `scelta_architetturale_immutabilit_dei_modelli.md`). Sono suddivise in quattro sotto-pacchetti, uno per area del dominio, più tre file comuni:

* **`enums.dart`**: domini chiusi (`Accessibilita`, `Difficolta`, `FasciaOraria`, `Meteo`, `Trasparenza`, `Fondo`, `Livello`). Sono salvati nel database con il nome del valore (`.name`): **i nomi dei valori non vanno rinominati**, altrimenti i dati già salvati non vengono più letti.
* **`foto.dart`**: `Foto`, riferimento a un'immagine salvata sul dispositivo (`percorso` e `percorsoThumbnail`), associabile in modo esclusivo a una pescata, a una cattura memorabile o a un'esca. Sta fuori dai sotto-pacchetti perché è usata da più aree.
* **`uguaglianza.dart`**: funzione `listeUguali`, usata dagli `operator ==` dei modelli che contengono liste.
* **Pacchetto `territorio/`**:
  * `Ambiente`: tipologia di corso o specchio d'acqua dello spot (di base *Torrente*, *Fiume*, *Lago*, *Mare*), estendibile dall'utente.
  * `Categoria`: raggruppamento di spot scelto dall'utente, come una cartella (es. *Fondovalle*, *Val Serina*, *Valle Imagna*).
  * `Spot`: luogo di pesca con le sue caratteristiche fisiche e logistiche e la lista delle coordinate.
  * `Coordinata`: singolo punto GPS (`latitudine`, `longitudine`, `ordine`) che compone il tracciato di uno spot.
* **Pacchetto `pescate/`**:
  * `Pescata`: entità centrale che raccoglie data, condizioni meteo-ambientali, spot visitato, esche utilizzate, riepiloghi, catture memorabili e foto.
  * `RiepilogoSpecie` e `RiepilogoCaratteristica`: totale degli esemplari catturati per specie in una pescata e loro suddivisione per caratteristica.
  * `CatturaMemorabile`: singola cattura da ricordare, collegata a una pescata, con specie, esca, caratteristiche e foto.
  * `Pianificazione`: pescata futura prevista, con data, fascia oraria, spot e note.
* **Pacchetto `catalogo/`** (anagrafiche personali del pescatore):
  * `Specie`: specie ittiche.
  * `Caratteristica`: tratto distintivo definito dall'utente per una specie (es. livrea o taglia).
  * `Esca`: esca o artificiale, con descrizione ed eventuali foto.
* **Pacchetto `obiettivi/`**:
  * `Obiettivo`: traguardo numerico annuale per una specie, generico o legato a una caratteristica.

#### Regola sui riferimenti tra modelli
* Un modello **contiene come oggetti** i propri componenti interni: `Pescata` contiene `RiepilogoSpecie`, `CatturaMemorabile` e `Foto`; `Spot` contiene le `Coordinata`; `Esca` contiene le sue `Foto`.
* Il riferimento al **genitore** è sempre una chiave: `Foto.pescataId`, `CatturaMemorabile.pescataId`, `Coordinata.spotNome`, `RiepilogoCaratteristica.riepilogoSpecieId`.
* Il riferimento a un'entità di **un altro pacchetto** dipende dal tipo di chiave:
  * se la chiave è **naturale** (il nome stesso), basta la chiave, perché è già il dato da mostrare: `spotNome`, `specieNome`, `categoriaNome`, `ambiente`;
  * se la chiave è un **id numerico**, il modello porta l'oggetto, così l'interfaccia ha il nome senza query aggiuntive: `Pescata.esche`, `CatturaMemorabile.esca`, `CatturaMemorabile.caratteristiche`, `Obiettivo.caratteristica`, `RiepilogoCaratteristica.caratteristica`.

### 4.3 `lib/repositories/` — Repository
Un repository per area del dominio; la tabella in §1.2 indica quali tabelle scrive ciascuno.

* **`TerritorioRepository`**: categorie, ambienti, spot e coordinate GPS, con il calcolo automatico della lunghezza del tratto (formula di Haversine) e lo spostamento degli spot tra categorie.
* **`PescateRepository`**: pescate complete (salvate in modo atomico con esche, foto, riepiloghi, dettagli e catture memorabili), catture memorabili e pianificazioni. Garantisce lo spot obbligatorio, il vincolo dettaglio ≤ totale e la pulizia dei file immagine non più usati.
* **`CatalogoRepository`**: specie, caratteristiche ed esche; offre agli altri repository la creazione al volo di esche e caratteristiche dentro una transazione esistente.
* **`ObiettiviRepository`**: obiettivi annuali.

Tutti i repository ricevono il `DatabaseHelper` (e, dove serve, gli altri repository e l'`ArchivioFoto`) dal costruttore: in produzione si usano le istanze predefinite, nei test un database in memoria.

### 4.4 `lib/services/` — Servizi
* **`StatisticheService`** *(implementato)*: statistiche di sola lettura sullo storico. Oggi espone la lettura dei riepiloghi per pescata o per specie; accoglierà medie, conteggi, confronti tra anni e progresso degli obiettivi.
* **`FotoService`** *(previsto)*: acquisizione da fotocamera o galleria, compressione, generazione delle anteprime e salvataggio con percorso relativo alla cartella documenti dell'app (REQ-DES-03), tramite `ArchivioFoto`.
* **`BackupService`** *(previsto)*: creazione e ripristino dell'archivio ZIP (dati in JSON + foto) su Google Drive (REQ-FUN-14, REQ-FUN-15).
* **`MeteoService`** *(previsto)*: interrogazione dell'API meteo con le coordinate dello spot (REQ-FUN-13).

### 4.5 `lib/ui/` — Presentazione *(previsto)*
* **`screens/`** e **`widgets/`**: schermate principali e componenti grafici riutilizzabili.
* **`state/`**: gestione dello stato dell'interfaccia (soluzione da definire, es. Provider). È l'unico punto in cui lo stato è mutabile: i modelli restano immutabili e ogni modifica confermata dall'utente passa da un repository o da un servizio.

### 4.6 `test/` — Test automatici
Una suite per componente, descritte nel `registro_dei_test_automatici.md`:
`database_integrita_test.dart` (schema), `territorio_repository_test.dart`, `pescate_repository_test.dart`, `catalogo_repository_test.dart`, `obiettivi_repository_test.dart`, `statistiche_service_test.dart`.

---

## 5. Evoluzione dello schema
Il database è alla **versione 1** e, durante lo sviluppo, uno schema modificato si applica ricreando il database con `DatabaseHelper.resetPerSviluppo()`. Prima di usare l'app con dati reali va introdotta la gestione delle migrazioni (`onUpgrade` con incremento della versione), perché il reset cancella tutti i dati. Lo stesso numero di versione sarà scritto nel file JSON del backup, per sapere da quale versione dello schema provengono i dati da ripristinare.
