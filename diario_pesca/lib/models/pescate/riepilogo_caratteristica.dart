import '../catalogo/caratteristica.dart';

class RiepilogoCaratteristica {
  final int? riepilogoSpecieId;
  final Caratteristica caratteristica;
  final int quantita;

  const RiepilogoCaratteristica({
    this.riepilogoSpecieId,
    required this.caratteristica,
    required this.quantita,
  });

  RiepilogoCaratteristica copyWith({
    int? riepilogoSpecieId,
    Caratteristica? caratteristica,
    int? quantita,
  }) {
    return RiepilogoCaratteristica(
      riepilogoSpecieId: riepilogoSpecieId ?? this.riepilogoSpecieId,
      caratteristica: caratteristica ?? this.caratteristica,
      quantita: quantita ?? this.quantita,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiepilogoCaratteristica &&
          runtimeType == other.runtimeType &&
          riepilogoSpecieId == other.riepilogoSpecieId &&
          caratteristica == other.caratteristica &&
          quantita == other.quantita;

  @override
  int get hashCode =>
      Object.hash(riepilogoSpecieId, caratteristica, quantita);
}