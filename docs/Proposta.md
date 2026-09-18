# Proposta di Progetto: Diario di Pesca 🎣

**Studente:** Celeste Locatelli  
**Matricola:** 1092641  
**Email:** c.locatelli60@studenti.unibg.it  

---

## 1. Visione Generale e Obiettivi

### 1.1 Contesto e Problema
Il progetto si colloca nell'ambito della pesca sportiva e ricreativa effettuarla con canna da pesca, comprendendo diverse tecniche e specie ittiche. L'idea nasce da una necessità personale, ampiamente riscontrata anche tra altri appassionati: disporre di uno strumento centralizzato per tracciare i luoghi di pesca frequentati e le catture effettuate. 

Negli ultimi due anni ho utilizzato un foglio di calcolo personalizzato, ma questa soluzione ha evidenziato notevoli limiti operativi:
- Necessità di correggere e adattare frequentemente le formule.
- Difficoltà nel realizzare funzionalità complesse o personalizzate.
- Bassa visibilità degli errori di inserimento dati.
- Complessità nell'aggiornare la struttura dati senza compromettere lo storico passato.
- Lentezza nel caricamento a causa dell'elevato numero di formule.

Attualmente, per gestire appieno l'attività, è necessario combinare l'uso del foglio con Google Earth (per l'individuazione grafica degli spot), app meteo esterne e gallerie social/locali per conservare le foto. L'obiettivo del progetto è unificare tutte queste funzionalità in un'unica applicazione versatile, completa e idonea a qualsiasi tipologia di pesca.

### 1.2 Obiettivi Primari
- Fornire uno strumento semplice e intuitivo per registrare i dettagli delle sessioni di pesca.
- Garantire un'architettura **100% local-first** con totale riservatezza dei dati dell'utente.
- Offrire un'interfaccia chiara per la consultazione di statistiche e trend personali.
- Integrare strumenti a supporto della pianificazione delle battute (previsioni meteo, mappe, storico passato).
- Fornire strumenti per definire e monitorare obiettivi personali di pesca.
- Garantire una struttura dati estensibile (possibilità per l'utente di aggiungere parametri custom oltre a quelli di base).

---

## 2. Target e Scenario d'Uso Tipo

### 2.1 Destinatari
I destinatari dell'applicazione sono esclusivamente pescatori ricreativi e amatoriali. L'applicazione non è rivolta al settore agonistico, il quale presenta logiche, regolamenti ed esigenze strutturalmente differenti.

### 2.2 Scenario Operativo (Storytelling)
L'utilizzo tipico dell'applicazione può seguire la seguente scaletta:

1. **Pianificazione (Giorno precedente la battuta):** Il pescatore consulta l'app per selezionare lo spot da battere, scegliendone uno già censito o aggiungendone uno nuovo. Consulta la sezione previsioni/meteo e analizza i dati storici e le statistiche personali per valutare la fattibilità della sessione.
2. **Programmazione:** Una volta definita la meta, l'utente pianifica la battuta inserendo lo spot nel calendario integrato.
3. **Durante la Sessione:** Non dovrebbe servire, piena concentrazione sull'attività di pesca.
4. **Post-Pescata (Registrazione dati):** L'utente registra una o più battute (a seconda dei tratti/spot visitati). Per ciascuna battuta inserisce i dati obbligatori (es. data, numero di catture) ed eventuali dati facoltativi (es. note personali, foto dalla galleria).
5. **Manutenzione Dati:** L'utente può aggiornare le informazioni relative a uno spot (es. esposizione al sole, presenza di ostacoli o variazioni di accessibilità), utili per le scelte future.

---

## 3. Funzionalità Desiderate (Ambito Operativo, solo alcune)

### 3.1 Modulo Gestione Spot
#### 3.1.1 Creazione Spot
- Creazione e posizionamento di un tratto o segnaposto sulla mappa grafica.
- Inserimento informazioni obbligatorie: nome dello spot, valle/zona di appartenenza, tipologia di ambiente (torrente, fiume, lago, mare).
- Inserimento informazioni facoltative: lunghezza del tratto, valutazione personale, note su punti inaccessibili, parcheggi nelle vicinanze.
- Salvataggio dello spot nel database locale.

#### 3.1.2 Gestione e Consultazione Spot (CRUD)
- Ricerca e filtraggio degli spot in base a parametri multipli.
- Personalizzazione dell'interfaccia (possibilità di nascondere i campi facoltativi non utilizzati).
- Modifica ed eliminazione delle schede spot.

### 3.2 Modulo Registro Catture e Battute
- Creazione di una nuova battuta al termine della sessione.
- Selezione dello spot (con possibilità di crearne uno contestualmente).
- Registrazione del numero di catture e inserimento di materiale fotografico dalla galleria.
- Creazione della scheda singola cattura per pesci di rilievo (dettagli sul punto preciso, taglia, peso, esca utilizzata).

### 3.3 Modulo Sessioni e Statistiche
- **Statistiche Personali:** Numero di battute totali/settimanali, media pesci per sessione, stato di avanzamento degli obiettivi personali, confronti interannuali.
- **Statistiche Spot:** Frequenza di visite, categoria/ambiente, distanza, livello di difficoltà, frequentazione, valutazione sintetica.

### 3.4 Gestione Dati e Persistenza
- Funzionamento completamente offline
- Non prevede registrazione account.
- Database locale residente sul dispositivo.
- Funzionalità di export/import locale dei dati per migrazione o backup manuale su cloud personale.

---

## 4. Vincoli di Sistema e Desiderata Tecnologici

- **Connettività Offline-First:** L'applicazione deve garantire la piena operatività anche in assenza di segnale di rete.
- **Architettura Local Storage:** Totale assenza di tracciamento o invio dati verso server terzi per la massima privacy.
- **Supporto Mappe 2D:** Mappa interattiva leggera e consultabile in modo fluido.
- **Pianificazione Multipiattaforma:** Struttura predisposta per un'eventuale fruizione su dispositivi desktop.