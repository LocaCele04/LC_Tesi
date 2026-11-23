import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/ui/mappa/colori_mappa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Spot _spot({
  String nome = 'Valbrina',
  String ambiente = 'Torrente',
  String categoria = 'Valle',
  double? voto,
  bool battuto = false,
  Difficolta? difficolta,
}) =>
    Spot(
      nome: nome,
      ambiente: ambiente,
      categoriaNome: categoria,
      voto: voto,
      battuto: battuto,
      difficolta: difficolta,
    );

void main() {
  group('Colori della mappa - Voto e stato', () {
    test('le fasce del voto vanno dal rosso al blu, senza voto è grigio', () {
      expect(coloreVoto(null), coloreAssente);
      expect(coloreVoto(2), fasceVoto[0].colore);
      expect(coloreVoto(4.9), fasceVoto[0].colore);
      expect(coloreVoto(5), fasceVoto[1].colore);
      expect(coloreVoto(7), fasceVoto[2].colore);
      expect(coloreVoto(8), fasceVoto[3].colore);
      expect(coloreVoto(8.5), fasceVoto[4].colore);
      expect(coloreVoto(10), fasceVoto[4].colore);
      // Cinque colori diversi
      expect(fasceVoto.map((f) => f.colore).toSet(), hasLength(5));
    });

    test('lo stato distingue gli spot battuti da quelli mai pescati', () {
      expect(coloreSpot(_spot(battuto: true), Colorazione.stato), coloreBattuto);
      expect(coloreSpot(_spot(), Colorazione.stato), coloreNonBattuto);
    });

    test('la legenda del voto va dal migliore e segnala gli spot senza voto solo se ci sono', () {
      final conVoto = legenda(Colorazione.voto, [_spot(voto: 7)]);
      expect(conVoto.first.colore, fasceVoto.last.colore);
      expect(conVoto.map((v) => v.etichetta), isNot(contains('senza voto')));
      expect(legenda(Colorazione.voto, [_spot(voto: 7), _spot()]).last.etichetta, 'senza voto');
    });
  });

  group('Colori della mappa - Ambienti e categorie', () {
    test('gli ambienti di base hanno colori fissi e diversi tra loro', () {
      final base = ['Torrente', 'Fiume', 'Lago', 'Mare'].map(coloreAmbiente).toSet();
      expect(base, hasLength(4));
      expect(coloreAmbiente(' torrente '), coloreAmbiente('Torrente'));
    });

    test('il colore calcolato dal nome è stabile e non dipende dagli altri nomi', () {
      final prima = coloreDaNome('Val Sorbina');
      // Aggiungere categorie non cambia il colore di quelle esistenti
      legenda(Colorazione.categoria, [_spot(categoria: 'Val Bruna'), _spot(categoria: 'Val Torba')]);
      expect(coloreDaNome('Val Sorbina'), prima);
      expect(coloreDaNome('  val sorbina'), prima);
      expect(coloreDaNome('Val Bruna'), isNot(prima));
      // Un ambiente aggiunto dall'utente usa il colore dal nome
      expect(coloreAmbiente('Roggia'), coloreDaNome('Roggia'));
    });

    test('la legenda per categoria mostra solo quelle presenti, una volta sola, in ordine alfabetico', () {
      final voci = legenda(Colorazione.categoria, [
        _spot(categoria: 'Valle Ombrosa'),
        _spot(categoria: 'Fondopiano'),
        _spot(categoria: 'valle ombrosa'),
      ]);
      expect(voci.map((v) => v.etichetta), ['Fondopiano', 'Valle Ombrosa']);
      expect(voci.last.colore, coloreDaNome('Valle Ombrosa'));
    });

    test('difficoltà e accessibilità hanno legende fisse', () {
      expect(coloreSpot(_spot(difficolta: Difficolta.alta), Colorazione.difficolta), isNot(coloreAssente));
      expect(coloreSpot(_spot(), Colorazione.difficolta), coloreAssente);
      expect(legenda(Colorazione.difficolta, [_spot()]).last.etichetta, 'non indicata');
      expect(legenda(Colorazione.accessibilita, const []), hasLength(2));
      expect(coloreDivieto, isA<Color>());
    });
  });
}
