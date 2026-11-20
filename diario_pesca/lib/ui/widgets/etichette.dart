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
