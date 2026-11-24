import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/territorio/spot.dart';

// Colori della mappa: come si colora un tratto secondo la vista scelta e
// quale legenda mostrare. Solo funzioni pure, senza widget, così si
// provano con i test unitari.

/// Criterio con cui si colorano gli spot sulla mappa.
enum Colorazione {
  stato('Stato'),
  voto('Voto'),
  ambiente('Ambiente'),
  categoria('Categoria'),
  difficolta('Difficoltà'),
  accessibilita('Accessibilità');

  const Colorazione(this.etichetta);
  final String etichetta;
}

/// Una riga della legenda.
class VoceLegenda {
  const VoceLegenda(this.etichetta, this.colore);
  final String etichetta;
  final Color colore;

  @override
  bool operator ==(Object other) =>
      other is VoceLegenda && other.etichetta == etichetta && other.colore == colore;

  @override
  int get hashCode => Object.hash(etichetta, colore);

  @override
  String toString() => 'VoceLegenda($etichetta, $colore)';
}

/// Valore mancante (spot senza voto, senza difficoltà...).
const coloreAssente = Color(0xFF9E9E9E);

/// Divieti: sempre dello stesso colore, qualunque sia la colorazione.
const coloreDivieto = Color(0xFF8B0000);

const _blu = Color(0xFF1E88E5);
const _verde = Color(0xFF43A047);
const _giallo = Color(0xFFFDD835);
const _arancione = Color(0xFFFB8C00);
const _rosso = Color(0xFFE53935);

/// Stato: blu se ci hai pescato (*battuto*), bianco se no. Le linee hanno
/// un bordo scuro, così anche quelle bianche si vedono sulla mappa.
const coloreBattuto = Color(0xFF1565C0);
const coloreNonBattuto = Color(0xFFFFFFFF);

/// Fasce del voto, dalla più bassa: la stessa scala del file di Google
/// Earth (rosso il peggiore, blu il migliore). `soglia` è il voto minimo
/// della fascia.
const fasceVoto = <({double soglia, String etichetta, Color colore})>[
  (soglia: 0, etichetta: 'meno di 5', colore: _rosso),
  (soglia: 5, etichetta: 'da 5 a 6,5', colore: _arancione),
  (soglia: 6.5, etichetta: 'da 6,5 a 7,5', colore: _giallo),
  (soglia: 7.5, etichetta: 'da 7,5 a 8,5', colore: _verde),
  (soglia: 8.5, etichetta: '8,5 e oltre', colore: _blu),
];

Color coloreVoto(double? voto) {
  if (voto == null) return coloreAssente;
  var colore = fasceVoto.first.colore;
  for (final f in fasceVoto) {
    if (voto >= f.soglia) colore = f.colore;
  }
  return colore;
}

/// Gli ambienti di base hanno colori fissi, scelti per richiamarli.
const _coloriAmbientiDiBase = {
  'torrente': Color(0xFF29B6F6),
  'fiume': Color(0xFF1565C0),
  'lago': Color(0xFF00897B),
  'mare': Color(0xFF7B1FA2),
};

Color coloreAmbiente(String ambiente) =>
    _coloriAmbientiDiBase[ambiente.trim().toLowerCase()] ?? coloreDaNome(ambiente);

/// Colore calcolato dal nome (senza distinzione di maiuscole e spazi):
/// lo stesso nome ha sempre lo stesso colore, e aggiungere una categoria o
/// un ambiente non cambia i colori degli altri. La tinta viene da un
/// hash del nome (FNV-1a); saturazione e luminosità sono fisse, per
/// colori vivaci e leggibili sulla mappa. Nomi diversi possono avere tinte
/// vicine: la legenda li distingue.
Color coloreDaNome(String nome) {
  var hash = 0x811C9DC5;
  for (final unita in nome.trim().toLowerCase().codeUnits) {
    hash ^= unita;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.7, 0.45).toColor();
}

Color coloreDifficolta(Difficolta? d) => switch (d) {
      Difficolta.bassa => _verde,
      Difficolta.media => _arancione,
      Difficolta.alta => _rosso,
      null => coloreAssente,
    };

Color coloreAccessibilita(Accessibilita a) =>
    a == Accessibilita.accessibile ? _verde : coloreAssente;

/// Colore del tratto di [spot] nella [colorazione] scelta.
Color coloreSpot(Spot spot, Colorazione colorazione) => switch (colorazione) {
      Colorazione.stato => spot.battuto ? coloreBattuto : coloreNonBattuto,
      Colorazione.voto => coloreVoto(spot.voto),
      Colorazione.ambiente => coloreAmbiente(spot.ambiente),
      Colorazione.categoria => coloreDaNome(spot.categoriaNome),
      Colorazione.difficolta => coloreDifficolta(spot.difficolta),
      Colorazione.accessibilita => coloreAccessibilita(spot.accessibilita),
    };

/// Legenda della [colorazione] per gli [spot] visibili: per ambiente e
/// categoria solo i valori presenti, in ordine alfabetico; per le altre
/// colorazioni tutte le voci, più "senza voto" / "non indicata" se
/// qualche spot non ha il valore.
List<VoceLegenda> legenda(Colorazione colorazione, List<Spot> spot) {
  switch (colorazione) {
    case Colorazione.stato:
      return const [
        VoceLegenda('ci ho pescato', coloreBattuto),
        VoceLegenda('mai pescato', coloreNonBattuto),
      ];
    case Colorazione.voto:
      return [
        for (final f in fasceVoto.reversed) VoceLegenda(f.etichetta, f.colore),
        if (spot.any((s) => s.voto == null)) const VoceLegenda('senza voto', coloreAssente),
      ];
    case Colorazione.ambiente:
      return _perNome(spot.map((s) => s.ambiente), coloreAmbiente);
    case Colorazione.categoria:
      return _perNome(spot.map((s) => s.categoriaNome), coloreDaNome);
    case Colorazione.difficolta:
      return [
        VoceLegenda('bassa', coloreDifficolta(Difficolta.bassa)),
        VoceLegenda('media', coloreDifficolta(Difficolta.media)),
        VoceLegenda('alta', coloreDifficolta(Difficolta.alta)),
        if (spot.any((s) => s.difficolta == null)) const VoceLegenda('non indicata', coloreAssente),
      ];
    case Colorazione.accessibilita:
      return [
        VoceLegenda('accessibile', coloreAccessibilita(Accessibilita.accessibile)),
        VoceLegenda('non accessibile', coloreAccessibilita(Accessibilita.inaccessibile)),
      ];
  }
}

List<VoceLegenda> _perNome(Iterable<String> nomi, Color Function(String) colore) {
  final distinti = <String, String>{};
  for (final n in nomi) {
    distinti.putIfAbsent(n.trim().toLowerCase(), () => n.trim());
  }
  final ordinati = distinti.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return [for (final n in ordinati) VoceLegenda(n, colore(n))];
}
