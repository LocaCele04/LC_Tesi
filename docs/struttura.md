# Architettura e Struttura del Progetto — Diario di Pesca

Il progetto **Diario di Pesca** è sviluppato in **Flutter / Dart** con persistenza locale su **SQLite** (`sqflite`).  
Per garantire manutenibilità, testabilità e una chiara separazione delle responsabilità, il codice applicativo è organizzato secondo un'**architettura a livelli (Layered Architecture)** che separa l'interfaccia utente, la logica di accesso ai dati, i modelli di dominio e lo schema relazionale.

---

## 1. Organizzazione delle Directory

Tutto il codice sorgente risiede nella cartella `lib/`, mentre i test automatici sono collocati in `test/`:

```text
diario_pesca/
├── lib/
│   ├── main.dart                         # Entry point dell'applicazione
│   ├── models/                           # Modelli di dominio (15 classi UML + 6 enumerazioni)
│   │   ├── enums.dart                    # Ambiente, Difficolta, StatoAccessibilita, FasciaOraria, Fondo, Trasparenza, Livello, Meteo
│   │   ├── categoria.dart                # Package: Territorio e Spot
│   │   ├── spot.dart
│   │   ├── tratto.dart
│   │   ├── coordinata.dart
│   │   ├── pescata.dart                  # Package: Battute e Catture
│   │   ├── condizioni_meteo.dart
│   │   ├── pianificazione.dart
│   │   ├── esca.dart
│   │   ├── cattura_memorabile.dart
│   │   ├── foto.dart
│   │   ├── obiettivo.dart                # Package: Specie e Obiettivi
│   │   ├── specie.dart
│   │   ├── caratteristica.dart
│   │   ├── riepilogo_specie.dart
│   │   └── riepilogo_caratteristica.dart
│   ├── database/                         # Configurazione e schema del database SQLite
│   │   └── database_helper.dart          # Singleton: connessione, PRAGMA e istruzioni DDL
│   ├── repositories/                     # Data Access Layer (query CRUD e mapping)
│   │   ├── territorio_repository.dart    # Gestione Categorie, Spot, Tratti e Coordinate
│   │   ├── battute_repository.dart       # Gestione Pescate, Pianificazioni, Catture, Esche e Foto
│   │   └── obiettivi_repository.dart     # Gestione Specie, Caratteristiche e Obiettivi annuali
│   ├── screens/                          # Pagine principali dell'interfaccia utente (UI)
│   └── widgets/                          # Componenti grafici riutilizzabili
└── test/                                 # Test unitari e di integrità dei vincoli SQLite