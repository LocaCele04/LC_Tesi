import 'package:diario_pesca/models/territorio/coordinata.dart';
import 'package:diario_pesca/ui/mappa/tratto_in_modifica.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Arrotondate: la media di due coordinate non è sempre esatta in virgola mobile.
  double r(double v) => (v * 1e6).roundToDouble() / 1e6;
  List<(double, double)> coppie(TrattoInModifica t) =>
      [for (final p in t.punti) (r(p.latitudine), r(p.longitudine))];

  group('Tratto in modifica', () {
    test('aggiungere, inserire in mezzo e togliere punti, con ordine sempre aggiornato', () {
      final t = TrattoInModifica();
      expect(t.lunghezzaMetri, isNull);
      t.aggiungi(46.0, 9.0);
      t.aggiungi(46.2, 9.4);
      expect(t.puntoMedio(0).latitudine, closeTo(46.1, 1e-9));
      t.inserisciInMezzo(0);
      expect(coppie(t), [(46.0, 9.0), (46.1, 9.2), (46.2, 9.4)]);
      expect(t.punti.map((p) => p.ordine), [0, 1, 2]);
      expect(t.lunghezzaMetri, greaterThan(0));

      t.rimuovi(0);
      expect(coppie(t), [(46.1, 9.2), (46.2, 9.4)]);
      expect(t.punti.first.ordine, 0);
    });

    test('un trascinamento si annulla in un colpo solo, come ogni altra operazione', () {
      final t = TrattoInModifica()
        ..aggiungi(46.0, 9.0)
        ..aggiungi(46.1, 9.1);

      t.iniziaSpostamento();
      t.sposta(1, 46.11, 9.11);
      t.sposta(1, 46.12, 9.12);
      t.sposta(1, 46.13, 9.13);
      expect(coppie(t).last, (46.13, 9.13));

      t.annulla();
      expect(coppie(t).last, (46.1, 9.1));
      t.annulla();
      expect(coppie(t), [(46.0, 9.0)]);
      t.annulla();
      expect(t.punti, isEmpty);
      expect(t.puoAnnullare, isFalse);
      // Annullare senza cronologia non fa nulla
      t.annulla();
      expect(t.punti, isEmpty);
    });

    test('svuotare si può annullare; modificato confronta con i punti di partenza', () {
      const iniziali = [
        Coordinata(ordine: 0, latitudine: 46.0, longitudine: 9.0, spotNome: 'Valbrina'),
        Coordinata(ordine: 1, latitudine: 46.1, longitudine: 9.1, spotNome: 'Valbrina'),
      ];
      final t = TrattoInModifica(iniziali);
      expect(t.modificato, isFalse);
      expect(t.numeroPunti, 2);
      // I punti restituiti non portano lo spot: lo assegna chi salva
      expect(t.punti.first.spotNome, isNull);

      t.svuota();
      expect(t.punti, isEmpty);
      expect(t.modificato, isTrue);
      t.annulla();
      expect(t.modificato, isFalse);

      t.iniziaSpostamento();
      t.sposta(0, 46.05, 9.0);
      expect(t.modificato, isTrue);
    });
  });
}
