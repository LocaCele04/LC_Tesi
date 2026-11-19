/// Cella della griglia del modello meteo (circa 2 km) a cui Open-Meteo
/// associa un punto richiesto, alla quota di quel punto.
///
/// [latitudine] e [longitudine] sono quelle della cella restituite dal
/// servizio, non quelle dello spot. [elevazione] è la quota (m) del punto
/// richiesto, che Open-Meteo usa per correggere le temperature: per questo
/// fa parte dell'identità della cella, e due spot nella stessa cella della
/// griglia ma a quote diverse hanno celle (e temperature) distinte.
class CellaMeteo {
  final int? id;
  final double latitudine;
  final double longitudine;
  final double elevazione;

  const CellaMeteo({
    this.id,
    required this.latitudine,
    required this.longitudine,
    required this.elevazione,
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
