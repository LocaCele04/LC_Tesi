class Coordinata {
  final String? spotNome;
  final int ordine;
  final double latitudine;
  final double longitudine;

  const Coordinata({
    this.spotNome,
    required this.ordine,
    required this.latitudine,
    required this.longitudine,
  });

  Coordinata copyWith({
    String? spotNome,
    int? ordine,
    double? latitudine,
    double? longitudine,
  }) {
    return Coordinata(
      spotNome: spotNome ?? this.spotNome,
      ordine: ordine ?? this.ordine,
      latitudine: latitudine ?? this.latitudine,
      longitudine: longitudine ?? this.longitudine,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coordinata &&
          runtimeType == other.runtimeType &&
          spotNome == other.spotNome &&
          ordine == other.ordine &&
          latitudine == other.latitudine &&
          longitudine == other.longitudine;

  @override
  int get hashCode => Object.hash(spotNome, ordine, latitudine, longitudine);
}