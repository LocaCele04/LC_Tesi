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