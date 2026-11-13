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

/// Vincolo CHECK su Pescata.meteo
enum Meteo {
  sereno,
  coperto,
  velato,
  variabile,
  plumbeo,
  pioggia,
  ventoso,
}

/// Vincolo CHECK su Pescata.trasparenza
enum Trasparenza {
  sporca,
  velata,
  chiara,
}

/// Vincolo CHECK su Pescata.fondo
enum Fondo {
  scuro,
  normale,
  pulito,
}

/// Vincolo CHECK su Pescata.livello
enum Livello {
  secca,
  magra,
  normale,
  morbida,
  piena,
}