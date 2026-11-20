/// Pescata per cui scaricare il meteo: la sua data e il punto dello spot
/// a cui chiederlo (la coordinata con ordine minimo del tratto).
///
/// Vista di sola lettura prodotta dal `MeteoRepository`: non corrisponde a
/// una riga del database e non ha `copyWith`.
class RichiestaMeteo {
  final int pescataId;
  final DateTime data;
  final double latitudine;
  final double longitudine;

  const RichiestaMeteo({
    required this.pescataId,
    required this.data,
    required this.latitudine,
    required this.longitudine,
  });

  @override
  String toString() =>
      'RichiestaMeteo(pescataId: $pescataId, data: $data, latitudine: $latitudine, longitudine: $longitudine)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RichiestaMeteo &&
          other.pescataId == pescataId &&
          other.data == data &&
          other.latitudine == latitudine &&
          other.longitudine == longitudine;

  @override
  int get hashCode => Object.hash(pescataId, data, latitudine, longitudine);
}
