class Categoria {
  final String nome;        // i getter sono impliciti
  final String? note;       // il ? indica che è nullabile

  // Costruttore
  const Categoria({
    required this.nome,
    this.note,
  });

  // Crea una copia modificando solo i campi passati (sostituisce i setter)
  /**C'è un solo caso in cui copyWith può trarre in inganno: svuotare un campo facoltativo (riportare a null).
   Se scrivi categoria.copyWith(note: null), l'operatore ?? dentro note ?? this.note interpreta null come "non passato" e mantiene la vecchia nota. 
   Nei form di salvataggio conviene quindi istanziare direttamente il costruttore completo**/
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Categoria && other.nome == nome && other.note == note;
  }

  @override
  int get hashCode => Object.hash(nome, note);
}