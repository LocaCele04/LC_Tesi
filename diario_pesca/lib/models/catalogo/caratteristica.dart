class Caratteristica {
  final int? id;
  final String specieNome;
  final String nome;
  final String? descrizione;

  const Caratteristica({
    this.id,
    required this.specieNome,
    required this.nome,
    this.descrizione,
  });

  /// `true` se l'oggetto non è ancora stato salvato nel database: l'id lo
  /// assegna SQLite all'inserimento. I repository restituiscono sempre
  /// oggetti con l'id valorizzato.
  bool get isNuovo => id == null;

  Caratteristica copyWith({
    int? id,
    String? specieNome,
    String? nome,
    String? descrizione,
  }) {
    return Caratteristica(
      id: id ?? this.id,
      specieNome: specieNome ?? this.specieNome,
      nome: nome ?? this.nome,
      descrizione: descrizione ?? this.descrizione,
    );
  }

  @override
  String toString() =>
      'Caratteristica(id: $id, specieNome: $specieNome, nome: $nome, descrizione: $descrizione)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Caratteristica &&
        other.id == id &&
        other.specieNome == specieNome &&
        other.nome == nome &&
        other.descrizione == descrizione;
  }

  @override
  int get hashCode => Object.hash(id, specieNome, nome, descrizione);
}