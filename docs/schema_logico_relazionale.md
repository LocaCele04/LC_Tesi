# Schema Logico Relazionale

Lo schema descritto in questo documento corrisponde a quello effettivamente creato da `DatabaseHelper.onCreate` (`lib/data/database_helper.dart`): 16 tabelle e 16 indici su SQLite.

---

## 1. Convenzioni di Notazione
* **`PK`**: Chiave Primaria (*Primary Key*)
* **`FK`**: Chiave Esterna (*Foreign Key*)
* **`UQ`**: Vincolo di unicità (*Unique*)
* **`NULL`**: Attributo facoltativo / opzionale
* **`NOT NULL`**: Attributo obbligatorio
* Tipi: SQLite usa affinità di tipo; si riportano i tipi effettivi `TEXT`, `INTEGER`, `REAL`. Le date sono `TEXT` in formato ISO `AAAA-MM-GG`, i booleani `INTEGER` (0/1).
* Azioni referenziali: `ON DELETE` / `ON UPDATE` indicate accanto a ogni FK (default SQLite: `NO ACTION`).

---

## 2. Schema Logico Relazionale (Formato Testuale)

### **Categoria**
* **`nome`**: TEXT **(PK)** — non vuoto
* `note`: TEXT *(NULL)*

### **Ambiente**
* **`nome`**: TEXT **(PK)** `COLLATE NOCASE` — non vuoto; unico senza distinzione tra maiuscole e minuscole
* Popolata alla creazione del database con i valori di base `Torrente`, `Fiume`, `Lago`, `Mare`; l'utente può aggiungerne altri.

### **Spot**
* **`nome`**: TEXT **(PK)** — non vuoto
* *`ambiente`*: TEXT `COLLATE NOCASE` **(FK, NOT NULL)** $\rightarrow$ `Ambiente(nome)` — `ON DELETE RESTRICT`, `ON UPDATE CASCADE`
* `lunghezzaMetri`: REAL *(NULL)* — > 0; calcolata automaticamente dalle coordinate se presenti almeno 2 punti
* `voto`: REAL *(NULL)* — tra 0 e 10, ammessi decimali (es. 4.5)
* `difficolta`: TEXT *(NULL)* — `bassa | media | alta`
* `esposizioneSole`: TEXT *(NULL)*
* `noteOstacoli`: TEXT *(NULL)*
* `note`: TEXT *(NULL)*
* `battuto`: INTEGER **(NOT NULL)**, default 0 — 1 se esiste almeno una pescata nello spot (mantenuto dai repository)
* `accessibilita`: TEXT **(NOT NULL)**, default `accessibile` — `accessibile | inaccessibile`
* `linkParcheggio`: TEXT *(NULL)*
* *`categoria_nome`*: TEXT **(FK, NOT NULL)** $\rightarrow$ `Categoria(nome)` — `ON DELETE RESTRICT`, `ON UPDATE CASCADE`

### **Coordinata**
* *`spot_nome`*: TEXT **(PK, FK)** $\rightarrow$ `Spot(nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`
* **`ordine`**: INTEGER **(PK)** — ≥ 0, indice posizionale del punto nel tracciato
* `latitudine`: REAL **(NOT NULL)** — tra -90 e 90
* `longitudine`: REAL **(NOT NULL)** — tra -180 e 180

### **Pianificazione**
* **`id`**: INTEGER **(PK, autoincrement)**
* `data`: TEXT **(NOT NULL)** — data ISO valida
* `fasciaOraria`: TEXT **(NOT NULL)** — `alba | mattina | pomeriggio | tramonto | sera | notte`
* `note`: TEXT *(NULL)*
* *`spot_nome`*: TEXT *(FK, NULL)* $\rightarrow$ `Spot(nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`

### **Pescata**
* **`id`**: INTEGER **(PK, autoincrement)**
* `data`: TEXT **(NOT NULL)** — data ISO valida
* `fasciaOraria`: TEXT **(NOT NULL)** — `alba | mattina | pomeriggio | tramonto | sera | notte`
* `meteo`: TEXT **(NOT NULL)** — `sereno | coperto | velato | variabile | plumbeo | pioggia | ventoso`
* `trasparenza`: TEXT *(NULL)* — `sporca | velata | chiara`
* `fondo`: TEXT *(NULL)* — `scuro | normale | pulito`
* `livello`: TEXT *(NULL)* — `secca | magra | normale | morbida | piena`
* `temp_acqua`: REAL *(NULL)* — tra 0 e 35 °C
* `temp_aria`: REAL *(NULL)* — tra -30 e 45 °C
* `note`: TEXT *(NULL)*
* *`spot_nome`*: TEXT *(FK, NULL)* $\rightarrow$ `Spot(nome)` — `ON DELETE SET NULL`, `ON UPDATE CASCADE`. Nullable solo per consentire il `SET NULL` quando uno spot viene eliminato: alla creazione lo spot è obbligatorio (vedi §3.4)

### **Esca**
* **`id`**: INTEGER **(PK, autoincrement)**
* `nome`: TEXT **(NOT NULL)** — non vuoto
* `descrizione`: TEXT *(NULL)*

### **Pescata_Esca** *(Relazione N:M "usa")*
* *`pescata_id`*: INTEGER **(PK, FK)** $\rightarrow$ `Pescata(id)` — `ON DELETE CASCADE`
* *`esca_id`*: INTEGER **(PK, FK)** $\rightarrow$ `Esca(id)` — `ON DELETE CASCADE`

### **Specie**
* **`nome`**: TEXT **(PK)** — non vuoto
* `informazioni`: TEXT *(NULL)*

### **CatturaMemorabile**
* **`id`**: INTEGER **(PK, autoincrement)**
* `descrizione`: TEXT *(NULL)*
* *`pescata_id`*: INTEGER **(FK, NOT NULL)** $\rightarrow$ `Pescata(id)` — `ON DELETE CASCADE`
* *`specie_nome`*: TEXT **(FK, NOT NULL)** $\rightarrow$ `Specie(nome)` — `ON DELETE RESTRICT`, `ON UPDATE CASCADE`
* *`esca_id`*: INTEGER *(FK, NULL)* $\rightarrow$ `Esca(id)` — `ON DELETE SET NULL`
* **UQ** (`id`, `specie_nome`) — chiave candidata usata dalle FK composte (vedi §3.2)

### **Foto**
* **`id`**: INTEGER **(PK, autoincrement)**
* `percorso`: TEXT **(NOT NULL)** — percorso relativo alla cartella documenti dell'app
* `percorsoThumbnail`: TEXT **(NOT NULL)** — percorso relativo alla cartella documenti dell'app
* *`pescata_id`*: INTEGER *(FK, NULL)* $\rightarrow$ `Pescata(id)` — `ON DELETE CASCADE`
* *`cattura_memorabile_id`*: INTEGER *(FK, NULL)* $\rightarrow$ `CatturaMemorabile(id)` — `ON DELETE CASCADE`
* *`esca_id`*: INTEGER *(FK, NULL)* $\rightarrow$ `Esca(id)` — `ON DELETE CASCADE`

### **RiepilogoSpecie**
* **`id`**: INTEGER **(PK, autoincrement)**
* *`pescata_id`*: INTEGER **(FK, NOT NULL)** $\rightarrow$ `Pescata(id)` — `ON DELETE CASCADE`
* *`specie_nome`*: TEXT **(FK, NOT NULL)** $\rightarrow$ `Specie(nome)` — `ON DELETE RESTRICT`, `ON UPDATE CASCADE`
* `quantita`: INTEGER **(NOT NULL)** — ≥ 0
* **UQ** (`pescata_id`, `specie_nome`) — una sola riga per specie in ogni pescata
* **UQ** (`id`, `specie_nome`) — chiave candidata usata dalle FK composte

### **Caratteristica**
* **`id`**: INTEGER **(PK, autoincrement)**
* *`specie_nome`*: TEXT **(FK, NOT NULL)** $\rightarrow$ `Specie(nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`
* `nome`: TEXT **(NOT NULL)** — non vuoto
* `descrizione`: TEXT *(NULL)*
* **UQ** (`specie_nome`, `nome`) — nomi unici all'interno della stessa specie
* **UQ** (`id`, `specie_nome`) — chiave candidata usata dalle FK composte

### **Cattura_Caratteristica** *(Relazione N:M "soddisfa")*
* *`cattura_memorabile_id`*: INTEGER **(PK)**
* *`caratteristica_id`*: INTEGER **(PK)**
* `specie_nome`: TEXT **(NOT NULL)**
* **FK** (`cattura_memorabile_id`, `specie_nome`) $\rightarrow$ `CatturaMemorabile(id, specie_nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`
* **FK** (`caratteristica_id`, `specie_nome`) $\rightarrow$ `Caratteristica(id, specie_nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`

### **Obiettivo**
* **`id`**: INTEGER **(PK, autoincrement)**
* *`specie_nome`*: TEXT **(FK, NOT NULL)** $\rightarrow$ `Specie(nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`
* `anno`: INTEGER **(NOT NULL)** — tra 2000 e 2100
* `quantita`: INTEGER **(NOT NULL)** — > 0
* `caratteristica_id`: INTEGER *(NULL)* — se NULL l'obiettivo riguarda l'intera specie
* **FK** (`caratteristica_id`, `specie_nome`) $\rightarrow$ `Caratteristica(id, specie_nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`

### **DettaglioRiepilogo** *(Relazione N:M "dettaglio")*
* *`riepilogo_specie_id`*: INTEGER **(PK)**
* *`caratteristica_id`*: INTEGER **(PK)**
* `specie_nome`: TEXT **(NOT NULL)**
* `quantita`: INTEGER **(NOT NULL)** — ≥ 0
* **FK** (`riepilogo_specie_id`, `specie_nome`) $\rightarrow$ `RiepilogoSpecie(id, specie_nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`
* **FK** (`caratteristica_id`, `specie_nome`) $\rightarrow$ `Caratteristica(id, specie_nome)` — `ON DELETE CASCADE`, `ON UPDATE CASCADE`

---

## 3. Vincoli d'Integrità

### 3.1 Esclusività Foto (XOR) — *garantito da CHECK*
Ogni tupla di `Foto` appartiene esattamente a uno tra pescata, cattura memorabile ed esca: una sola delle tre colonne `pescata_id`, `cattura_memorabile_id`, `esca_id` è valorizzata, mai due o tre insieme e mai nessuna.

### 3.2 Concordanza di Specie — *garantito da FK composte*
* In `Cattura_Caratteristica` la caratteristica deve appartenere alla stessa specie della `CatturaMemorabile`.
* In `Obiettivo`, se è indicata una caratteristica, essa deve appartenere alla specie dell'obiettivo.
* In `DettaglioRiepilogo` la caratteristica deve appartenere alla specie del `RiepilogoSpecie`.

Tutti e tre i casi sono garantiti dal database: la colonna `specie_nome` è ripetuta nella tabella figlia e partecipa a entrambe le chiavi esterne composte, che puntano alle coppie `UNIQUE (id, specie_nome)` delle tabelle padre. Una caratteristica di una specie diversa viola quindi una delle due FK.

### 3.3 Quantità nel Dettaglio — *garantito dai repository*
La quantità di un `DettaglioRiepilogo` non può superare la quantità del `RiepilogoSpecie` a cui appartiene:
$$\text{quantità}(\text{DettaglioRiepilogo}) \le \text{quantità}(\text{RiepilogoSpecie})$$
Il vincolo coinvolge due tabelle e non è esprimibile con un `CHECK`: è verificato in `PescateRepository.salvaPescata` prima del salvataggio, che è l'unico punto in cui si scrivono i riepiloghi.

### 3.4 Spot obbligatorio per le pescate — *garantito dai repository*
Una nuova pescata deve avere uno spot, e a una pescata esistente non si può togliere lo spot. La colonna `Pescata.spot_nome` non può essere `NOT NULL`, perché deve poter diventare NULL per effetto di `ON DELETE SET NULL` quando lo spot viene eliminato: il vincolo è quindi verificato in `PescateRepository.salvaPescata`. Una pescata rimasta senza spot dopo l'eliminazione dello spot resta modificabile.

### 3.5 Domini estendibili — *garantiti da FK*
L'ambiente di uno spot non è un dominio chiuso ma una tabella di dominio (`Ambiente`) che l'utente può ampliare: la chiave esterna impedisce valori non registrati o scritti in modo diverso, e la collation `NOCASE` evita duplicati che differiscono solo per maiuscole e minuscole (`Torrente` / `torrente`). Le altre enumerazioni (difficoltà, fascia oraria, meteo, trasparenza, fondo, livello, accessibilità) restano domini chiusi, perché sono scale con un ordine e sono usate in filtri e statistiche.

### 3.6 Domini chiusi e formati — *garantiti da CHECK*
Stringhe non vuote per i nomi, intervalli numerici (voto, temperature, coordinate, anno, quantità), valori ammessi delle enumerazioni, date di calendario valide. In SQLite un valore `NULL` supera sempre un `CHECK`, quindi i campi facoltativi restano facoltativi.

---

## 4. Politiche di Eliminazione e Aggiornamento

| Operazione | Effetto |
| :--- | :--- |
| Eliminare una **Categoria** | Bloccata (`RESTRICT`) se contiene spot: prima vanno spostati in un'altra categoria (`TerritorioRepository.spostaSpot`). |
| Eliminare un **Ambiente** | Bloccata (`RESTRICT`) se usato da almeno uno spot. |
| Rinominare una **Categoria** / **Ambiente** / **Spot** / **Specie** | Il nuovo nome si propaga a tutte le tabelle figlie (`ON UPDATE CASCADE`). |
| Eliminare uno **Spot** | Elimina coordinate (tratto) e pianificazioni (`CASCADE`); le pescate restano nello storico con `spot_nome = NULL` (`SET NULL`). |
| Eliminare una **Pescata** | Elimina legami con le esche, riepiloghi, dettagli, catture memorabili e foto (`CASCADE`); il repository cancella anche i file immagine dal disco e ricalcola `Spot.battuto`. |
| Eliminare un'**Esca** | Elimina i legami con le pescate e le sue foto (`CASCADE`); nelle catture memorabili il riferimento diventa NULL (`SET NULL`). |
| Eliminare una **Specie** | Bloccata (`RESTRICT`) se usata in riepiloghi o catture memorabili; altrimenti elimina caratteristiche e obiettivi (`CASCADE`). |
| Eliminare una **Caratteristica** | Elimina obiettivi, dettagli e associazioni con le catture che la usano (`CASCADE`). |

---

## 5. Indici

| Indice | Tabella (colonne) |
| :--- | :--- |
| `idx_spot_categoria` | Spot (categoria_nome) |
| `idx_spot_ambiente` | Spot (ambiente) |
| `idx_pescata_data` | Pescata (data) |
| `idx_pescata_spot` | Pescata (spot_nome) |
| `idx_pianificazione_spot` | Pianificazione (spot_nome) |
| `idx_pescata_esca_esca` | Pescata_Esca (esca_id) |
| `idx_cattura_pescata` | CatturaMemorabile (pescata_id) |
| `idx_cattura_specie` | CatturaMemorabile (specie_nome) |
| `idx_cattura_esca` | CatturaMemorabile (esca_id) |
| `idx_foto_pescata` | Foto (pescata_id) |
| `idx_foto_esca` | Foto (esca_id) |
| `idx_foto_cattura` | Foto (cattura_memorabile_id) |
| `idx_riepilogo_specie` | RiepilogoSpecie (specie_nome) |
| `idx_cattcar_caratteristica` | Cattura_Caratteristica (caratteristica_id) |
| `idx_dettaglio_caratteristica` | DettaglioRiepilogo (caratteristica_id) |
| `idx_obiettivo_anno` | Obiettivo (anno) |
