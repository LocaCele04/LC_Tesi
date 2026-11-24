import 'dart:convert';

import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/territorio/coordinata.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/repositories/catalogo_repository.dart';
import 'package:diario_pesca/repositories/pescate_repository.dart';
import 'package:diario_pesca/repositories/territorio_repository.dart';
import 'package:diario_pesca/services/import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Dati di prova inventati: i dati veri da importare non devono mai finire
// nel repository.
Map<String, Object?> _file() => {
      'formato': 'diario-pesca-import',
      'versione': 1,
      'ambienti': [
        {'nome': 'Ruscello', 'condizioniCome': 'Torrente'},
      ],
      'specie': [
        {'nome': 'Trota', 'caratteristiche': ['Over 30', 'Over 40']},
      ],
      'spot': [
        {
          'nome': 'Rio Chiaro',
          'categoria': 'Valle Ombrosa',
          'ambiente': 'Torrente',
          'voto': 7.5,
          'difficolta': 'media',
          'note': 'Località: Borgo Alto',
          'linkParcheggio': 'https://example.com/p',
          'punti': [
            [44.50, 8.40],
            [44.51, 8.41],
          ],
        },
        {
          'nome': 'Fosso Piccolo',
          'categoria': 'Fondopiano',
          'ambiente': 'Ruscello',
          'lunghezzaMetri': 300,
          'punti': [
            [44.52, 8.42],
          ],
        },
        {'nome': 'Lago Smeraldo', 'categoria': 'Fondopiano', 'ambiente': 'Lago'},
      ],
      'divieti': [
        {
          'nome': 'Divieto',
          'note': 'Fino al ponte',
          'punti': [
            [44.53, 8.43],
            [44.54, 8.44],
          ],
        },
      ],
      'pescate': [
        {
          'data': '2025-03-01',
          'fascia': 'alba',
          'spot': 'rio chiaro',
          'condizioni': {'Meteo': 'Sereno'},
          'catture': [
            {'specie': 'Trota', 'totale': 3, 'caratteristiche': {'Over 30': 1, 'Over 40': 1}},
          ],
          'note': 'Prima uscita · Voto giornata 7',
        },
        {'data': '2025-03-02', 'fascia': 'sera', 'spot': 'Fosso Piccolo', 'catture': []},
      ],
    };

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late TerritorioRepository territorio;
  late CatalogoRepository catalogo;
  late PescateRepository pescate;
  late ImportService servizio;

  setUp(() {
    dbHelper = DatabaseHelper.inMemory();
    territorio = TerritorioRepository(dbHelper: dbHelper);
    catalogo = CatalogoRepository(dbHelper: dbHelper);
    pescate = PescateRepository(dbHelper: dbHelper, catalogo: catalogo);
    servizio = ImportService(territorio: territorio, catalogo: catalogo, pescate: pescate);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  Future<List<String>> problemi(Map<String, Object?> file) async {
    try {
      await servizio.leggi(jsonEncode(file));
      return const [];
    } on ImportNonValido catch (e) {
      return e.problemi;
    }
  }

  group('ImportService - Import', () {
    test('importa ambienti, specie, spot, divieti e pescate collegati tra loro', () async {
      final dati = await servizio.leggi(jsonEncode(_file()));
      expect(dati.spot, hasLength(3));
      expect(dati.spotConTratto, 2);
      expect(dati.catture, 3);

      final avanzamenti = <String>[];
      final esito = await servizio.importa(dati, avanzamento: (fase, fatti, totale) => avanzamenti.add(fase));
      expect((esito.spot, esito.divieti, esito.pescate), (3, 1, 2));
      expect(avanzamenti, containsAll(['Spot', 'Divieti', 'Pescate']));

      // Ambiente nuovo con le condizioni del torrente
      final condizioni = await catalogo.getCondizioni(ambienteNome: 'Ruscello');
      expect(condizioni.map((c) => c.nome), containsAll(['Livello', 'Meteo']));

      // Spot: categorie create, lunghezza calcolata dal tratto o presa dal file
      final rio = (await territorio.getSpotConCoordinate('Rio Chiaro'))!;
      expect(rio.categoriaNome, 'Valle Ombrosa');
      expect(rio.voto, 7.5);
      expect(rio.difficolta, Difficolta.media);
      expect(rio.coordinate.map((c) => c.latitudine), [44.50, 44.51]);
      expect(rio.lunghezzaMetri, greaterThan(1000));
      expect(rio.battuto, isTrue);
      final fosso = (await territorio.getSpotConCoordinate('Fosso Piccolo'))!;
      expect(fosso.lunghezzaMetri, 300);
      expect((await territorio.getSpotConCoordinate('Lago Smeraldo'))!.coordinate, isEmpty);
      expect((await territorio.getCategorie()).map((c) => c.nome), containsAll(['Valle Ombrosa', 'Fondopiano']));

      final divieto = (await territorio.getDivieti()).single;
      expect(divieto.note, 'Fino al ponte');
      expect(divieto.coordinate, hasLength(2));

      // Pescate: spot trovato senza distinzione di maiuscole, condizione,
      // catture con le caratteristiche
      final elenco = await pescate.getPescate();
      final prima = (await pescate.getPescataCompleta(elenco.firstWhere((p) => p.data == DateTime(2025, 3, 1)).id!))!;
      expect(prima.spotNome, 'Rio Chiaro');
      expect(prima.fasciaOraria, FasciaOraria.alba);
      expect(prima.valoriCondizioni.single.nome, 'Sereno');
      expect(prima.note, 'Prima uscita · Voto giornata 7');
      final trota = prima.riepiloghiSpecie.single;
      expect(trota.quantita, 3);
      expect({for (final d in trota.dettagli) d.caratteristica.nome: d.quantita}, {'Over 30': 1, 'Over 40': 1});
      final seconda = elenco.firstWhere((p) => p.data == DateTime(2025, 3, 2));
      expect(seconda.fasciaOraria, FasciaOraria.sera);
    });
  });

  group('ImportService - Controlli', () {
    test('un file non valido o di un altro formato viene rifiutato prima di scrivere', () async {
      await expectLater(servizio.leggi('non è json'), throwsA(isA<ImportNonValido>()));
      expect(await problemi({'formato': 'altro'}), ['Il file non è un file di import del Diario di pesca.']);
      expect((await problemi({..._file(), 'versione': 2})).single, contains('Versione del file 2'));
    });

    test('segnala spot ripetuti, riferimenti sconosciuti e catture incoerenti', () async {
      final file = _file();
      (file['spot'] as List).add({'nome': 'RIO CHIARO', 'categoria': 'X', 'ambiente': 'Torrente'});
      (file['spot'] as List).add({'nome': 'Senza ambiente', 'categoria': 'X', 'ambiente': 'Palude'});
      (file['divieti'] as List).add({'nome': 'Vuoto', 'punti': <Object>[]});
      (file['pescate'] as List).addAll(<Map<String, Object>>[
        {'data': '1 marzo', 'fascia': 'merenda', 'spot': 'Inesistente'},
        {
          'data': '2025-04-01',
          'fascia': 'alba',
          'spot': 'Rio Chiaro',
          'condizioni': {'Meteo': 'Grandine', 'Umore': 'Alto'},
          'catture': [
            {'specie': 'Trota', 'totale': 1, 'caratteristiche': {'Over 30': 1, 'Over 40': 1}},
            {'specie': 'Luccio', 'totale': 2},
            {'specie': 'Trota', 'totale': 2, 'caratteristiche': {'Over 99': 1}},
          ],
        },
      ]);
      final elenco = await problemi(file);
      expect(elenco, contains('Spot "RIO CHIARO" ripetuto.'));
      expect(elenco, contains('Spot Senza ambiente: ambiente "Palude" sconosciuto.'));
      expect(elenco, contains('Divieto Vuoto: servono il nome e almeno un punto.'));
      expect(elenco.where((p) => p.startsWith('Pescata 3')), hasLength(3));
      final quarta = elenco.where((p) => p.startsWith('Pescata 4')).join('\n');
      expect(quarta, contains('valore "Grandine" inesistente per Meteo'));
      expect(quarta, contains('condizione "Umore" inesistente'));
      expect(quarta, contains('contano più catture del totale'));
      expect(quarta, contains('specie "Luccio" non dichiarata'));
      expect(quarta, contains('caratteristica "Over 99" non dichiarata'));
      // Nulla è stato scritto
      expect(await territorio.getSpots(), isEmpty);
    });

    test('su un diario che contiene già dei dati l\'import non si fa', () async {
      await territorio.salvaSpotConCoordinate(const Spot(
        nome: 'Già presente',
        ambiente: 'Torrente',
        categoriaNome: 'Valle',
        coordinate: [Coordinata(ordine: 0, latitudine: 44.5, longitudine: 8.4)],
      ));
      expect(await problemi(_file()), contains('Il diario non è vuoto: l\'import si può fare solo su un diario nuovo.'));
    });
  });
}
