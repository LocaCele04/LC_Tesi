import 'riepilogo_caratteristica.dart';

class RiepilogoSpecie {
  final int? id;
  final int pescataId;
  final String specieNome;
  final int quantita;
  final List<RiepilogoCaratteristica> dettagli;

  const RiepilogoSpecie({
    this.id,
    required this.pescataId,
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
  String toString() =>
      'RiepilogoSpecie(id: $id, pescataId: $pescataId, specieNome: $specieNome, quantita: $quantita)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RiepilogoSpecie &&
        other.id == id &&
        other.pescataId == pescataId &&
        other.specieNome == specieNome &&
        other.quantita == quantita &&
        _listEquals(other.dettagli, dettagli);
  }

  @override
  int get hashCode => Object.hash(
        id,
        pescataId,
        specieNome,
        quantita,
        Object.hashAll(dettagli),
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}