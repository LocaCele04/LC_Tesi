# Schema Logico Relazionale

---

## 1. Convenzioni di Notazione
* **`PK`**: Chiave Primaria (*Primary Key*)
* **`FK`**: Chiave Esterna (*Foreign Key*)
* **`NULL`**: Attributo facoltativo / opzionale
* **`NOT NULL`**: Attributo obbligatorio

---

## 2. Schema Logico Relazionale (Formato Testuale)

### **Categoria**
* **`nome`**: VARCHAR(100) **(PK)**
* `note`: TEXT *(NULL)*

### **Spot**
* **`nome`**: VARCHAR(100) **(PK)**
* `ambiente`: VARCHAR(100) **(NOT NULL)**
* `lunghezzaMetri`: DECIMAL(10,2) *(NULL)*
* `voto`: INT *(NULL)*
* `diffolta`: VARCHAR(50) *(NULL)*
* `esposizioneSole`: VARCHAR(50) *(NULL)*
* `noteOstacoli`: TEXT *(NULL)*
* `note`: TEXT *(NULL)*
* `accessibilita_battuto`: BOOLEAN *(NULL)*
* `accessibilita_linkParcheggio`: VARCHAR(255) *(NULL)*
* *`categoria_nome`*: VARCHAR(100) **(FK)** $\rightarrow$ `Categoria(nome)`

### **Coordinata**
* *`spot_nome`*: VARCHAR(100) **(PK, FK)** $\rightarrow$ `Spot(nome)`
* **`ordine`**: INT **(PK)** *(Indice posizionale del punto del tracciato)*
* `latitudine`: DECIMAL(9,6) **(NOT NULL)**
* `longitudine`: DECIMAL(9,6) **(NOT NULL)**

### **Pianificazione**
* **`id`**: INT **(PK)**
* `data`: DATE **(NOT NULL)**
* `fasciaOraria`: VARCHAR(50) **(NOT NULL)**
* `note`: TEXT *(NULL)*
* *`spot_nome`*: VARCHAR(100) **(FK)** $\rightarrow$ `Spot(nome)`

### **Pescata**
* **`id`**: INT **(PK)**
* `data`: DATE **(NOT NULL)**
* `fasciaOraria`: VARCHAR(50) **(NOT NULL)**
* `trasparenza`: VARCHAR(50) *(NULL)*
* `fondo`: VARCHAR(50) *(NULL)*
* `livello`: VARCHAR(50) *(NULL)*
* `temp_acqua`: DECIMAL(4,1) *(NULL)*
* `temp_aria`: DECIMAL(4,1) *(NULL)*
* `note`: TEXT *(NULL)*
* *`spot_nome`*: VARCHAR(100) **(FK)** $\rightarrow$ `Spot(nome)`

### **Esca**
* **`id`**: INT **(PK)**
* `nome`: VARCHAR(100) **(NOT NULL)**
* `descrizione`: TEXT *(NULL)*

### **Pescata_Esca** *(Relazione N:M "usa")*
* *`pescata_id`*: INT **(PK, FK)** $\rightarrow$ `Pescata(id)`
* *`esca_id`*: INT **(PK, FK)** $\rightarrow$ `Esca(id)`

### **Foto**
* **`id`**: INT **(PK)**
* `percorso`: VARCHAR(255) **(NOT NULL)**
* `percorsoThumbnail`: VARCHAR(255) **(NOT NULL)**
* *`pescata_id`*: INT *(FK, NULL)* $\rightarrow$ `Pescata(id)`
* *`cattura_memorabile_id`*: INT *(FK, NULL)* $\rightarrow$ `CatturaMemorabile(id)`

### **Specie**
* **`nome`**: VARCHAR(100) **(PK)**
* `informazioni`: TEXT *(NULL)*

### **CatturaMemorabile**
* **`id`**: INT **(PK)**
* `descrizione`: TEXT *(NULL)*
* *`pescata_id`*: INT **(FK)** $\rightarrow$ `Pescata(id)`
* *`specie_nome`*: VARCHAR(100) **(FK)** $\rightarrow$ `Specie(nome)`
* *`esca_id`*: INT *(FK, NULL)* $\rightarrow$ `Esca(id)`

### **RiepilogoSpecie** *(Entità debole)*
* *`pescata_id`*: INT **(PK, FK)** $\rightarrow$ `Pescata(id)`
* *`specie_nome`*: VARCHAR(100) **(PK, FK)** $\rightarrow$ `Specie(nome)`
* `quantita`: INT **(NOT NULL)**

### **Caratteristica** *(Entità debole)*
* *`specie_nome`*: VARCHAR(100) **(PK, FK)** $\rightarrow$ `Specie(nome)`
* **`nome`**: VARCHAR(100) **(PK)**
* `descrizione`: TEXT *(NULL)*

### **Cattura_Caratteristica** *(Relazione N:M "soddisfa")*
* *`cattura_memorabile_id`*: INT **(PK, FK)** $\rightarrow$ `CatturaMemorabile(id)`
* *`specie_nome`*: VARCHAR(100) **(PK, FK)** $\rightarrow$ `Caratteristica(specie_nome)`
* *`caratteristica_nome`*: VARCHAR(100) **(PK, FK)** $\rightarrow$ `Caratteristica(nome)`

### **Obiettivo**
* *`specie_nome`*: VARCHAR(100) **(PK, FK)** $\rightarrow$ `Specie(nome)`
* **`id`**: INT **(PK)**
* `anno`: INT **(NOT NULL)**
* `quantita`: INT **(NOT NULL)**
* *`caratteristica_nome`*: VARCHAR(100) *(FK, NULL)* $\rightarrow$ `Caratteristica(nome)`

### **DettaglioRiepilogo** *(Relazione N:M "dettaglio")*
* *`pescata_id`*: INT **(PK, FK)** $\rightarrow$ `RiepilogoSpecie(pescata_id)`
* *`specie_nome`*: VARCHAR(100) **(PK, FK)** $\rightarrow$ `RiepilogoSpecie(specie_nome)`
* *`caratteristica_nome`*: VARCHAR(100) **(PK, FK)** $\rightarrow$ `Caratteristica(nome)`
* `quantita`: INT **(NOT NULL)**

---

## 3. Vincoli d'Integrità non Esprimibili nelle Chiavi

1. **Esclusività Foto (XOR):**
   * Ogni tupla della tabella `Foto` deve riferirsi ad una pescata **oppure** ad una cattura memorabile, mai a entrambe e mai a nessuna delle due:
     $$\text{pescata\_id IS NOT NULL} \oplus \text{cattura\_memorabile\_id IS NOT NULL}$$

2. **Concordanza di Specie:**
   * In `Cattura_Caratteristica`, la specie della caratteristica deve coincidere con la specie della relativa `CatturaMemorabile`.
   * In `Obiettivo`, se è specificata una caratteristica, essa deve appartenere alla medesima specie dell'obiettivo.
   * In `DettaglioRiepilogo`, la caratteristica associata deve essere definita per la stessa specie del riepilogo.

3. **Vincolo di Quantità nel Dettaglio:**
   * La quantità indicata in `DettaglioRiepilogo` non può superare la quantità totale registrata in `RiepilogoSpecie` per la medesima specie e pescata:
     $$\text{quantità}(\text{DettaglioRiepilogo}) \le \text{quantità}(\text{RiepilogoSpecie})$$

---