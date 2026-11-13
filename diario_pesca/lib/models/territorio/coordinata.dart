class Coordinata {
  final String spotNome;
  final int ordine;
  final double latitudine;
  final double longitudine;

  const Coordinata({
    required this.spotNome,
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
  String toString() =>
      'Coordinata(spotNome: $spotNome, ordine: $ordine, latitudine: $latitudine, longitudine: $longitudine)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Coordinata &&
        other.spotNome == spotNome &&
        other.ordine == ordine &&
        other.latitudine == latitudine &&
        other.longitudine == longitudine;
  }

  @override
  int get hashCode => Object.hash(spotNome, ordine, latitudine, longitudine);
}