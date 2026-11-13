class RiepilogoCaratteristica {
  final int riepilogoSpecieId;
  final int caratteristicaId;
  final String specieNome;
  final int quantita;

  const RiepilogoCaratteristica({
    required this.riepilogoSpecieId,
    required this.caratteristicaId,
    required this.specieNome,
    required this.quantita,
  });

  RiepilogoCaratteristica copyWith({
    int? riepilogoSpecieId,
    int? caratteristicaId,
    String? specieNome,
    int? quantita,
  }) {
    return RiepilogoCaratteristica(
      riepilogoSpecieId: riepilogoSpecieId ?? this.riepilogoSpecieId,
      caratteristicaId: caratteristicaId ?? this.caratteristicaId,
      specieNome: specieNome ?? this.specieNome,
      quantita: quantita ?? this.quantita,
    );
  }

  @override
  String toString() =>
      'RiepilogoCaratteristica(riepilogoSpecieId: $riepilogoSpecieId, caratteristicaId: $caratteristicaId, specieNome: $specieNome, quantita: $quantita)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RiepilogoCaratteristica &&
        other.riepilogoSpecieId == riepilogoSpecieId &&
        other.caratteristicaId == caratteristicaId &&
        other.specieNome == specieNome &&
        other.quantita == quantita;
  }

  @override
  int get hashCode => Object.hash(
        riepilogoSpecieId,
        caratteristicaId,
        specieNome,
        quantita,
      );
}