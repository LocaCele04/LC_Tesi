# Struttura e Architettura del Progetto *Diario di Pesca*

## 1. Panoramica Architetturale

**Diario di Pesca** è un'applicazione mobile sviluppata in **Flutter** (linguaggio **Dart**) con architettura **offline-first** basata su database relazionale locale **SQLite**.

Per mantenere il codice ordinato, leggibile e facilmente estendibile, il progetto è strutturato secondo un'**architettura a strati (Layered Architecture)** che separa le responsabilità in livelli distinti:

```
+-------------------------------------------------------------------+
|               LIVELLO DI PRESENTAZIONE (UI)                       |
|                  lib/screens/  |  lib/widgets/                    |
+-------------------------------------------------------------------+
                                 |
                                 v
+-------------------------------------------------------------------+
|               LIVELLO SERVIZI APPLICATIVI                         |
|                       lib/services/                               |
+-------------------------------------------------------------------+
                                 |
                                 v
+-------------------------------------------------------------------+
|               LIVELLO REPOSITORY (Accesso ai Dati)                |
|  TerritorioRepository | BattuteRepository | StatisticheRepository |
+-------------------------------------------------------------------+
                |                                   |
                v                                   v
+-------------------------------+   +-------------------------------+
|      MODELLO DI DOMINIO       |   |       LIVELLO DI MAPPING      |
|          lib/models/          |<->|        db_mappers.dart        |
+-------------------------------+   +-------------------------------+
                                                    |
                                                    v
                                    +-------------------------------+
                                    |     PERSISTENZA SQLITE        |
                                    |     database_helper.dart      |
                                    +-------------------------------+
```

* **Persistenza (`database`)**: gestisce la connessione a SQLite e lo schema relazionale a 16 tabelle.
* **Dominio (`models`)**: definisce le entità dell'applicazione tramite classi Dart immutabili, indipendenti dal database.
* **Mapping (`db_mappers.dart`)**: converte i dati tra le tabelle SQLite e gli oggetti Dart.
* **Accesso ai dati (`repositories`)**: espone alle schermate i metodi di lettura, salvataggio ed eliminazione, gestendo le transazioni.
* **Servizi e UI (`services`, `screens`, `widgets`)**: gestiscono le risorse locali (come le immagini) e l'interfaccia grafica.

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

La radice del progetto separa il codice sorgente dell'applicazione (`lib/`) dalla suite di test (`test/`):

```
diario_pesca/
├── lib/
│   ├── database/
│   │   ├── database_helper.dart       # Connessione SQLite e definizione delle 16 tabelle
│   │   └── db_mappers.dart            # Conversione bidirezionale tra Map SQL e classi Dart
│   ├── models/
│   │   ├── battute/
│   │   │   ├── cattura_memorabile.dart
│   │   │   ├── esca.dart
│   │   │   ├── foto.dart
│   │   │   ├── pescata.dart
│   │   │   └── pianificazione.dart
│   │   ├── statistiche/
│   │   │   ├── caratteristica.dart
│   │   │   ├── obiettivo.dart
│   │   │   ├── riepilogo_caratteristica.dart
│   │   │   ├── riepilogo_specie.dart
│   │   │   └── specie.dart
│   │   ├── territorio/
│   │   │   ├── ambiente.dart
│   │   │   ├── categoria.dart
│   │   │   ├── coordinata.dart
│   │   │   └── spot.dart
│   │   └── enums.dart                 # Tipi enumerativi del dominio
│   ├── repositories/
│   │   ├── battute_repository.dart
│   │   ├── statistiche_repository.dart
│   │   └── territorio_repository.dart
│   ├── screens/                       # Schermate dell'applicazione
│   ├── services/                      # Servizi applicativi (es. gestione file foto)
│   ├── widgets/                       # Componenti grafici riutilizzabili
│   └── main.dart                      # Punto di ingresso dell'applicazione
├── test/
│   ├── battute_repository_test.dart
│   ├── database_integrita_test.dart
│   ├── statistiche_repository_test.dart
│   └── territorio_repository_test.dart
└── pubspec.yaml
```

---

## 4. Descrizione dei Pacchetti e delle Classi

### 4.1 `lib/database/` — Persistenza e Mapping
* **`DatabaseHelper` (`database_helper.dart`)**: implementa il pattern *Singleton* per fornire un'unica istanza del database all'app (oltre a una variante in memoria per i test). Contiene lo schema relazionale composto da **16 tabelle** e **16 indici**, con vincoli di integrità referenziale attivi.
* **`DbMappers` (`db_mappers.dart`)**: classe di utilità che traduce le righe restituite da SQLite (`Map<String, Object?>`) nelle corrispondenti classi del modello di dominio e viceversa, mantenendo le classi modello completamente indipendenti dal database.

### 4.2 `lib/models/` — Modello di Dominio
Tutte le classi modello sono progettate come **oggetti immutabili** (campi `final`, metodo `copyWith` e uguaglianza strutturale) e sono suddivise in tre sotto-pacchetti tematici più un file comune per le enumerazioni:

* **`enums.dart`**: definisce i domini chiusi dell'applicazione (`Accessibilita`, `Difficolta`, `FasciaOraria`, `Meteo`, `Trasparenza`, `Fondo`, `Livello`).
* **Pacchetto `territorio/`**:
  * `Ambiente`: tipologia di corso o specchio d'acqua dello spot (di base *Torrente*, *Fiume*, *Lago*, *Mare*), estendibile dall'utente.
  * `Categoria`: classifica macroscopica delle regioni di pesca (es. *Basso Brembo*, *Val serina*, *Valle Imagna*).
  * `Spot`: rappresenta il luogo di pesca con le sue caratteristiche fisiche, logistiche e la lista delle coordinate.
  * `Coordinata`: singolo punto GPS (`latitudine`, `longitudine`, `ordine`) che compone il tracciato di uno spot.
* **Pacchetto `battute/`**:
  * `Pianificazione`: promemoria di una futura uscita di pesca con data, fascia oraria, spot e note.
  * `Esca`: rappresenta un artificiale o un'esca, corredata da descrizione ed eventuali fotografie.
  * `Foto`: riferimento a un'immagine salvata sul dispositivo (`percorso` e `percorsoThumbnail`), associabile in modo esclusivo a una pescata, a una cattura memorabile o a un'esca.
  * `CatturaMemorabile`: singola cattura rilevante registrata in una sessione, collegata a specie, esca, caratteristiche e foto.
  * `Pescata`: entità centrale che raccoglie data, condizioni meteo-ambientali, spot visitato, esche utilizzate, riepiloghi numerici, catture memorabili e foto.
* **Pacchetto `statistiche/`**:
  * `Specie`: anagrafica delle specie ittiche.
  * `Caratteristica`: tratto distintivo legato a una specie (es. livrea o taglia).
  * `RiepilogoSpecie` e `RiepilogoCaratteristica`: rappresentano rispettivamente il totale degli esemplari catturati per specie in una pescata e la loro suddivisione per caratteristica.
  * `Obiettivo`: traguardo numerico annuale impostato per una specie (generico o legato a una specifica caratteristica).

### 4.3 `lib/repositories/` — Logica di Accesso ai Dati
I repository fungono da unico punto di contatto tra la logica applicativa e il database:

* **`TerritorioRepository`**: gestisce categorie, ambienti, spot e relative coordinate GPS (includendo il calcolo automatico della lunghezza dello spot e lo stato di frequentazione).
* **`BattuteRepository`**: gestisce esche, pianificazioni, pescate complete e catture memorabili, assicurando il salvataggio atomico delle pescate e la pulizia dei file immagine non più utilizzati.
* **`StatisticheRepository`**: gestisce l'anagrafica delle specie, le caratteristiche, gli obiettivi annuali e le interrogazioni per i riepiloghi statistici.

### 4.4 Livelli Applicativo, UI e Test
* **`lib/services/`**: ospita i servizi di supporto alle funzionalità di sistema, in particolare la gestione fisica delle immagini sul dispositivo (`FotoService`).
* **`lib/screens/` e `lib/widgets/`**: raccolgono rispettivamente le schermate principali dell'app e i componenti grafici riutilizzabili, collegati all'entry-point **`lib/main.dart`**.
* **`test/`**: contiene quattro suite di test automatizzati (`database_integrita_test.dart`, `territorio_repository_test.dart`, `battute_repository_test.dart`, `statistiche_repository_test.dart`) che rispecchiano la suddivisione dei moduli di `lib/`.