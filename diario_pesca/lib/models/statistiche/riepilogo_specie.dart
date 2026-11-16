import 'riepilogo_caratteristica.dart';

class RiepilogoSpecie {
  final int? id;
  final int? pescataId;
  final String specieNome;
  final int quantita;
  final List<RiepilogoCaratteristica> dettagli;

  const RiepilogoSpecie({
    this.id,
    this.pescataId,
    required this.specieNome,
    required this.quantita,
    this.dettagli = const [],
  });

  RiepilogoSpecie copyWith({
    int? id,
    int? pescataId,
    String? specieNome,
    int? quantita,
    List<RiepilogoCaratteristica>? dettagli,
  }) {
    return RiepilogoSpecie(
      id: id ?? this.id,
      pescataId: pescataId ?? this.pescataId,
      specieNome: specieNome ?? this.specieNome,
      quantita: quantita ?? this.quantita,
      dettagli: dettagli ?? this.dettagli,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiepilogoSpecie &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          pescataId == other.pescataId &&
          specieNome == other.specieNome &&
          quantita == other.quantita;

  @override
  int get hashCode => Object.hash(id, pescataId, specieNome, quantita);
}