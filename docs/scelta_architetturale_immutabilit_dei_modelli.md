# Scelta Architetturale: Immutabilità dei Modelli Dati (`final`)

## 1. Contesto e Decisione
Nella progettazione del livello di dominio dell'applicazione, si è scelto di dichiarare tutti gli attributi delle classi modello (come `Categoria`, `Spot`, `Pescata`, ecc.) con il modificatore **`final`**. 

In Dart, questa scelta rende le classi **immutabili**: una volta che un oggetto viene istanziato in memoria (ad esempio a seguito di una lettura dal database SQLite), il suo stato interno non può più essere alterato direttamente tramite assegnazioni o metodi *setter*. Qualsiasi modifica richiede la creazione di una nuova istanza aggiornata.

---

## 2. Motivazioni Tecniche

### A. Coerenza con la Persistenza (Database SQLite)
I modelli dati rappresentano una fotografia dello stato salvato su database. Se gli oggetti fossero mutabili, sarebbe possibile modificare una proprietà in un punto qualsiasi del codice (es. `categoria.note = "Nuova nota"`) senza aver effettivamente eseguito un'operazione di `UPDATE` su SQLite. Questo creerebbe un disallineamento silenzioso tra i dati in memoria e quelli persistiti.
L'immutabilità impone un flusso unidirezionale e controllato: per aggiornare un dato è necessario generare esplicitamente un nuovo oggetto e passarlo al `Repository` dedicato affinché venga salvato.

### B. Reattività dell'Interfaccia Utente in Flutter
Il framework Flutter determina quando aggiornare (ridisegnare) i widget confrontando lo stato precedente con quello attuale. Molti meccanismi di gestione dello stato verificano se il riferimento all'oggetto è cambiato oppure utilizzano l'operatore di uguaglianza (`==`).
Se un oggetto venisse mutato internamente, il suo riferimento in memoria rimarrebbe invariato, con il rischio che l'interfaccia grafica non rilevi il cambiamento e mostri dati obsoleti.

### C. Prevenzione di Effetti Collaterali (*Side Effects*)
In un'applicazione mobile, lo stesso oggetto viene spesso condiviso tra più schermate (ad esempio, passando un elemento da una lista generale a una schermata di dettaglio o di modifica).
Garantire che l'oggetto sia immutabile elimina il rischio di effetti collaterali indesiderati: se l'utente apre una schermata di modifica, altera alcuni campi e poi preme *"Annulla"*, l'oggetto originale presente nella schermata precedente rimane completamente intatto.

### D. Integrità nelle Collezioni (`Map` e `Set`)
Nel modulo dedicato alle statistiche e alle aggregazioni, gli oggetti di dominio vengono utilizzati per raggruppare o indicizzare dati all'interno di strutture come `Map` e `Set`.
Se un oggetto utilizzato come chiave in una `Map` venisse modificato dopo l'inserimento, cambierebbe il valore restituito dal suo metodo `hashCode`, rendendo l'elemento irrecuperabile all'interno della struttura dati. L'immutabilità garantisce che `hashCode` e `==` restino costanti per tutto il ciclo di vita dell'oggetto.

### E. Ottimizzazione della Memoria (`const`)
Una classe in cui tutti i campi sono dichiarati `final` può esporre un costruttore `const`. Questo consente al compilatore Dart di canonicalizzare le istanze identiche, riutilizzando lo stesso spazio di memoria anziché allocare nuovi oggetti duplicati.

---

## 3. Implementazione Pratica: L'esempio di `Categoria`

In linea con la separazione delle responsabilità adottata nei repository (dove i modelli sono completamente indipendenti dalla logica di database), la classe `Categoria` viene definita come un modello puro e immutabile.

Per sopperire all'assenza dei classici metodi *setter*, si implementa il pattern **`copyWith`**, che permette di clonare l'oggetto sostituendo esclusivamente i campi interessati dalla modifica.

```dart
class Categoria {
  final String nome;
  final String? note;

  // Costruttore const: possibile solo grazie ai campi final
  const Categoria({
    required this.nome,
    this.note,
  });

  // Metodo copyWith: sostituisce i setter mantenendo l'immutabilità
  Categoria copyWith({
    String? nome,
    String? note,
  }) {
    return Categoria(
      nome: nome ?? this.nome,
      note: note ?? this.note,
    );
  }

  @override
  String toString() => 'Categoria(nome: $nome, note: $note)';

  // Ridefinizione dell'uguaglianza per valore (utile nei test e nella UI)
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Categoria &&
        other.nome == nome &&
        other.note == note;
  }

  @override
  int get hashCode => Object.hash(nome, note);
}
```

### Esempio di flusso di aggiornamento
Quando si desidera modificare una categoria esistente, non si altera l'istanza corrente ma se ne produce una nuova da inviare al repository:

```dart
// 1. Istanza originale letta dal database
const categoriaOriginale = Categoria(
  nome: 'Val Taleggio',
  note: 'Torrente alpino',
);

// 2. Creazione di una nuova istanza aggiornata tramite copyWith
// (categoriaOriginale rimane invariata)
final categoriaAggiornata = categoriaOriginale.copyWith(
  note: 'Torrente alpino - acqua molto limpida',
);

// 3. Salvataggio esplicito tramite il repository
// await territorioRepository.updateCategoria(categoriaAggiornata);
```

---

## 4. Dove risiede la mutabilità?
Scegliere modelli immutabili non significa eliminare la mutabilità dall'applicazione, ma **confinarla esclusivamente nel livello di presentazione (UI)**. 

Durante la compilazione di un form da parte dell'utente, i valori temporanei vengono gestiti dai controller dei campi di testo (`TextEditingController`) o dalle variabili locali dello `State` del widget. Solo nel momento in cui l'utente conferma l'operazione (es. pressione del tasto *"Salva"*), i dati raccolti vengono consolidati in un nuovo oggetto immutabile e passati al livello di persistenza.