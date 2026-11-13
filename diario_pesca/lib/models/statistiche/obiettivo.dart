class Obiettivo {
  final int? id;
  final String specieNome;
  final int anno;
  final int quantita;
  final int? caratteristicaId;

  const Obiettivo({
    this.id,
    required this.specieNome,
    required this.anno,
    required this.quantita,
    this.caratteristicaId,
  });

  Obiettivo copyWith({
    int? id,
    String? specieNome,
    int? anno,
    int? quantita,
    int? caratteristicaId,
  }) {
    return Obiettivo(
      id: id ?? this.id,
      specieNome: specieNome ?? this.specieNome,
      anno: anno ?? this.anno,
      quantita: quantita ?? this.quantita,
      caratteristicaId: caratteristicaId ?? this.caratteristicaId,
    );
  }

  @override
  String toString() =>
      'Obiettivo(id: $id, specieNome: $specieNome, anno: $anno, quantita: $quantita, caratteristicaId: $caratteristicaId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Obiettivo &&
        other.id == id &&
        other.specieNome == specieNome &&
        other.anno == anno &&
        other.quantita == quantita &&
        other.caratteristicaId == caratteristicaId;
  }

  @override
  int get hashCode =>
      Object.hash(id, specieNome, anno, quantita, caratteristicaId);
}