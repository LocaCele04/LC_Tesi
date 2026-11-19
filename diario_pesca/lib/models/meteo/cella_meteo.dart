/// Cella della griglia del modello meteo (circa 10 km) a cui Open-Meteo
/// associa un punto richiesto. [latitudine] e [longitudine] sono quelle della
/// cella restituite dal servizio, non quelle dello spot; [elevazione] è la
/// quota media della cella, utile per capire quanto il dato è
/// rappresentativo di un fondovalle.
class CellaMeteo {
  final int? id;
  final double latitudine;
  final double longitudine;
  final double? elevazione;

  const CellaMeteo({
    this.id,
    required this.latitudine,
    required this.longitudine,
    this.elevazione,
  });

  /// `true` se l'oggetto non è ancora stato salvato nel database: l'id lo
  /// assegna SQLite all'inserimento. I repository restituiscono sempre
  /// oggetti con l'id valorizzato.
  bool get isNuovo => id == null;

  CellaMeteo copyWith({
    int? id,
    double? latitudine,
    double? longitudine,
    double? elevazione,
  }) {
    return CellaMeteo(
      id: id ?? this.id,
      latitudine: latitudine ?? this.latitudine,
      longitudine: longitudine ?? this.longitudine,
      elevazione: elevazione ?? this.elevazione,
    );
  }

  @override
  String toString() =>
      'CellaMeteo(id: $id, latitudine: $latitudine, longitudine: $longitudine, elevazione: $elevazione)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellaMeteo &&
          other.id == id &&
          other.latitudine == latitudine &&
          other.longitudine == longitudine &&
          other.elevazione == elevazione;

  @override
  int get hashCode => Object.hash(id, latitudine, longitudine, elevazione);
}
