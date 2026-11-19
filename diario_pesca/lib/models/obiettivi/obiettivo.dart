import '../catalogo/caratteristica.dart';

class Obiettivo {
  final int? id;
  final String specieNome;
  final int anno;
  final int quantita;
  final Caratteristica? caratteristica;

  const Obiettivo({
    this.id,
    required this.specieNome,
    required this.anno,
    required this.quantita,
    this.caratteristica,
  });

  Obiettivo copyWith({
    int? id,
    String? specieNome,
    int? anno,
    int? quantita,
    Caratteristica? caratteristica,
  }) {
    return Obiettivo(
      id: id ?? this.id,
      specieNome: specieNome ?? this.specieNome,
      anno: anno ?? this.anno,
      quantita: quantita ?? this.quantita,
      caratteristica: caratteristica ?? this.caratteristica,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Obiettivo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          specieNome == other.specieNome &&
          anno == other.anno &&
          quantita == other.quantita &&
          caratteristica == other.caratteristica;

  @override
  int get hashCode =>
      Object.hash(id, specieNome, anno, quantita, caratteristica);
}