class Esca {
  final int? id;
  final String nome;
  final String? descrizione;

  const Esca({
    this.id,
    required this.nome,
    this.descrizione,
  });

  Esca copyWith({
    int? id,
    String? nome,
    String? descrizione,
  }) {
    return Esca(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descrizione: descrizione ?? this.descrizione,
    );
  }

  @override
  String toString() => 'Esca(id: $id, nome: $nome, descrizione: $descrizione)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Esca &&
        other.id == id &&
        other.nome == nome &&
        other.descrizione == descrizione;
  }

  @override
  int get hashCode => Object.hash(id, nome, descrizione);
}