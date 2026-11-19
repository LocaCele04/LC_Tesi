/// Vincolo CHECK su Spot.difficolta
enum Difficolta {
  bassa,
  media,
  alta,
}

/// Vincolo CHECK su Pescata.fasciaOraria e Pianificazione.fasciaOraria
enum FasciaOraria {
  alba,
  mattina,
  pomeriggio,
  tramonto,
  sera,
  notte,
}

/// Vincolo CHECK su Spot.accessibilita
enum Accessibilita {
  accessibile,
  inaccessibile,
}

// Meteo, livello, trasparenza e fondo non sono enum: sono condizioni
// personalizzabili dall'utente (tabelle Condizione e ValoreCondizione).

/// Vincolo CHECK su MeteoGiornaliero.fonte e MeteoOrario.fonte
enum FonteMeteo {
  /// Rianalisi storica (Open-Meteo Historical Weather API), definitiva.
  archivio,

  /// Modello di previsione (Open-Meteo Forecast API con `past_days`), usato
  /// per i giorni più recenti non ancora disponibili in archivio.
  previsione,
}

/// Stato dei dati meteo di una pescata. Non è salvato: lo calcola il
/// `MeteoRepository` confrontando la pescata con l'ultima richiesta fatta.
enum StatoMeteo {
  /// Lo spot ha coordinate ma i dati non sono ancora stati scaricati, oppure
  /// la data della pescata o il punto dello spot sono cambiati.
  daScaricare,

  /// Dati scaricati e corrispondenti alla data e al punto attuali.
  scaricato,

  /// Lo spot non ha coordinate (o la pescata non ha più uno spot): non si
  /// può sapere dove chiedere il meteo.
  nonDisponibile,
}
