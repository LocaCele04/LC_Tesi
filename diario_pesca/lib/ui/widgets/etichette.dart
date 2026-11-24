import '../../models/enums.dart';

// Testi mostrati all'utente per i valori del dominio.

String etichettaFascia(FasciaOraria fascia) => switch (fascia) {
      FasciaOraria.alba => 'Alba',
      FasciaOraria.mattina => 'Mattina',
      FasciaOraria.pomeriggio => 'Pomeriggio',
      FasciaOraria.tramonto => 'Tramonto',
      FasciaOraria.sera => 'Sera',
      FasciaOraria.notte => 'Notte',
    };

const _giorni = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];

/// Data nel formato "sabato 4/10/2026".
String formattaData(DateTime data) =>
    '${_giorni[data.weekday - 1]} ${data.day}/${data.month}/${data.year}';

const _mesi = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];

/// Mese e anno, es. "Novembre 2026" (per i titoli degli elenchi).
String formattaMese(DateTime data) {
  final mese = _mesi[data.month - 1];
  return '${mese[0].toUpperCase()}${mese.substring(1)} ${data.year}';
}

/// Numero con la virgola decimale e al massimo [decimali] cifre dopo la
/// virgola, senza zeri inutili: 7 → "7", 7.25 → "7,3", 12.0 → "12".
String formattaNumero(double valore, {int decimali = 1}) {
  final testo = valore.toStringAsFixed(decimali);
  final senzaZeri = testo.contains('.') ? testo.replaceFirst(RegExp(r'\.?0+$'), '') : testo;
  return senzaZeri.replaceAll('.', ',');
}

const _puntiCardinali = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];

/// Punto cardinale (in italiano) da cui arriva il vento, dai gradi
/// meteorologici: 0 = nord, 90 = est, 180 = sud, 270 = ovest.
String puntoCardinale(int gradi) => _puntiCardinali[((gradi % 360) / 45).round() % 8];
