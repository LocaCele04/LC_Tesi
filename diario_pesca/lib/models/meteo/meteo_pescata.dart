import '../enums.dart';
import '../uguaglianza.dart';
import 'cella_meteo.dart';
import 'meteo_giorno.dart';
import 'meteo_ora.dart';

/// Meteo di una pescata: lo stato dei dati, la cella usata, i giorni
/// precedenti (dal più vecchio al giorno della pescata) e le ore del giorno
/// prima e del giorno della pescata.
///
/// Vista di sola lettura prodotta dal `MeteoRepository`: non ha `copyWith`.
class MeteoPescata {
  final StatoMeteo stato;
  final CellaMeteo? cella;
  final List<MeteoGiorno> giorni;
  final List<MeteoOra> ore;

  const MeteoPescata({
    required this.stato,
    this.cella,
    this.giorni = const [],
    this.ore = const [],
  });

  @override
  String toString() =>
      'MeteoPescata(stato: $stato, cella: $cella, giorni: ${giorni.length}, ore: ${ore.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeteoPescata &&
          other.stato == stato &&
          other.cella == cella &&
          listeUguali(other.giorni, giorni) &&
          listeUguali(other.ore, ore);

  @override
  int get hashCode =>
      Object.hash(stato, cella, Object.hashAll(giorni), Object.hashAll(ore));
}
