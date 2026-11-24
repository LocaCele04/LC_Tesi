import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/catalogo/caratteristica.dart';
import 'package:diario_pesca/models/catalogo/esca.dart';
import 'package:diario_pesca/models/catalogo/specie.dart';
import 'package:diario_pesca/models/catalogo/valore_condizione.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/foto.dart';
import 'package:diario_pesca/models/pescate/cattura_memorabile.dart';
import 'package:diario_pesca/models/pescate/pescata.dart';
import 'package:diario_pesca/models/pescate/pianificazione.dart';
import 'package:diario_pesca/models/pescate/riepilogo_caratteristica.dart';
import 'package:diario_pesca/models/pescate/riepilogo_specie.dart';
import 'package:diario_pesca/repositories/catalogo_repository.dart';
import 'package:diario_pesca/repositories/pescate_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late Database db;
  late PescateRepository pescateRepo;
  late CatalogoRepository catalogoRepo;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    db = await dbHelper.database;
    catalogoRepo = CatalogoRepository(dbHelper: dbHelper);
    pescateRepo = PescateRepository(dbHelper: dbHelper, catalogo: catalogoRepo);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  /// Valore di base di una condizione (es. Livello / Morbida), già salvato.
  Future<ValoreCondizione> valore(String condizione, String nome) async {
    final condizioni = await catalogoRepo.getCondizioni();
    return condizioni
        .firstWhere((c) => c.nome == condizione)
        .valori
        .firstWhere((v) => v.nome == nome);
  }

  Future<void> inserisciSpotDiProva(String nome, {String ambiente = 'Torrente'}) async {
    await db.insert(
      'Categoria',
      {'nome': 'Generica'},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert('Spot', {
      'nome': nome,
      'ambiente': ambiente,
      'categoria_nome': 'Generica',
    });
  }

  group('PescateRepository - Pianificazioni', () {
    test('salvaPianificazione, getPianificazioni con filtri ed eliminaPianificazione', () async {
      await inserisciSpotDiProva('Ponte Ruga', ambiente: 'Torrente');
      await inserisciSpotDiProva('Foce Nord', ambiente: 'Mare');

      final p1 = await pescateRepo.salvaPianificazione(
        Pianificazione(
          data: DateTime(2026, 11, 15),
          fasciaOraria: FasciaOraria.alba,
          spotNome: 'Ponte Ruga',
          note: 'Uscita mattutina',
        ),
      );
      final p2 = await pescateRepo.salvaPianificazione(
        Pianificazione(
          data: DateTime(2026, 11, 22),
          fasciaOraria: FasciaOraria.tramonto,
          spotNome: 'Foce Nord',
        ),
      );

      expect(p1.id, isNotNull);
      expect(p2.id, isNotNull);

      // Aggiornamento
      await pescateRepo.salvaPianificazione(
        p1.copyWith(fasciaOraria: FasciaOraria.mattina),
      );

      final perSpot = await pescateRepo.getPianificazioni(spotNome: 'Ponte Ruga');
      expect(perSpot.length, 1);
      expect(perSpot.first.fasciaOraria, FasciaOraria.mattina);

      final perData = await pescateRepo.getPianificazioni(
        daData: DateTime(2026, 11, 20),
        aData: DateTime(2026, 11, 30),
      );
      expect(perData.map((p) => p.spotNome), ['Foce Nord']);

      await pescateRepo.eliminaPianificazione(p2.id!);
      expect((await pescateRepo.getPianificazioni()).length, 1);
    });
  });

  group('PescateRepository - Pescate', () {
    test('salvaPescata (insert/update con esche, foto, condizioni e stato battuto) e getPescate con filtri combinati', () async {
      await inserisciSpotDiProva('Ponte Ruga');
      final esca1 = await catalogoRepo.salvaEsca(const Esca(nome: 'Minnow'));
      final esca2 = await catalogoRepo.salvaEsca(const Esca(nome: 'Ondulante'));
      final morbida = await valore('Livello', 'Morbida');
      final magra = await valore('Livello', 'Magra');
      final velata = await valore('Trasparenza', 'Velata');
      final chiara = await valore('Trasparenza', 'Chiara');
      final fondoNormale = await valore('Fondo', 'Normale');
      final velato = await valore('Meteo', 'Velato');
      final sereno = await valore('Meteo', 'Sereno');
      final coperto = await valore('Meteo', 'Coperto');

      // Prima pescata con condizioni, esche e foto
      final salvata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 10),
          fasciaOraria: FasciaOraria.alba,
          tempAcqua: 11.5,
          spotNome: 'Ponte Ruga',
          valoriCondizioni: [velato, velata, fondoNormale, morbida],
          esche: [esca1, esca2],
          foto: const [
            Foto(
              percorso: '/img/p1.jpg',
              percorsoThumbnail: '/img/thumb_p1.jpg',
            ),
          ],
        ),
      );

      expect(salvata.id, isNotNull);
      expect(salvata.foto.single.id, isNotNull);
      expect(salvata.foto.single.pescataId, salvata.id);

      // Spot aggiornato automaticamente a battuto = 1
      final spotDopoPescata = await db.query(
        'Spot',
        where: 'nome = ?',
        whereArgs: ['Ponte Ruga'],
      );
      expect(spotDopoPescata.first['battuto'], 1);

      // Seconda pescata con condizioni diverse
      await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 12),
          fasciaOraria: FasciaOraria.sera,
          spotNome: 'Ponte Ruga',
          valoriCondizioni: [sereno, chiara, magra],
        ),
      );

      // Aggiornamento prima pescata (riduco a 1 esca e cambio meteo)
      await pescateRepo.salvaPescata(
        salvata.copyWith(
          valoriCondizioni: [coperto, velata, fondoNormale, morbida],
          esche: [esca1],
        ),
      );

      // Rilettura: valori nell'ordine delle condizioni (Livello, Trasparenza, Fondo, Meteo)
      final completa = await pescateRepo.getPescataCompleta(salvata.id!);
      expect(
        completa!.valoriCondizioni.map((v) => v.nome),
        ['Morbida', 'Velata', 'Normale', 'Coperto'],
      );
      expect(completa.valorePer(coperto.condizioneId!)?.nome, 'Coperto');
      expect(await db.query('Pescata_Condizione'), hasLength(7));

      final filtrate = await pescateRepo.getPescate(
        spotNome: 'Ponte Ruga',
        fasciaOraria: FasciaOraria.alba,
        valoriCondizioni: [coperto.id!, velata.id!, morbida.id!],
      );
      expect(filtrate.length, 1);
      expect(filtrate.first.id, salvata.id);

      final conMagra = await pescateRepo.getPescate(valoriCondizioni: [magra.id!]);
      expect(conMagra.single.data, DateTime(2026, 11, 12));
      expect(
        await pescateRepo.getPescate(valoriCondizioni: [magra.id!, coperto.id!]),
        isEmpty,
      );

      final ultimeUna = await pescateRepo.getPescate(limit: 1);
      expect(ultimeUna.length, 1);
      expect(ultimeUna.first.data, DateTime(2026, 11, 12));
    });

    test('salvaPescata accetta un solo valore per condizione, già salvato e della condizione indicata', () async {
      await inserisciSpotDiProva('Ponte Ruga');
      final morbida = await valore('Livello', 'Morbida');
      final magra = await valore('Livello', 'Magra');
      final velata = await valore('Trasparenza', 'Velata');

      Pescata conValori(List<ValoreCondizione> valori) => Pescata(
            data: DateTime(2026, 11, 14),
            fasciaOraria: FasciaOraria.alba,
            spotNome: 'Ponte Ruga',
            valoriCondizioni: valori,
          );

      // Due valori per la stessa condizione
      await expectLater(
        () => pescateRepo.salvaPescata(conValori([morbida, magra])),
        throwsArgumentError,
      );
      // Valore non salvato
      await expectLater(
        () => pescateRepo.salvaPescata(conValori([
          ValoreCondizione(condizioneId: morbida.condizioneId, nome: 'Inventato'),
        ])),
        throwsArgumentError,
      );
      // Valore attribuito alla condizione sbagliata: rifiutato dalla FK composta
      await expectLater(
        () => pescateRepo.salvaPescata(conValori([
          velata.copyWith(condizioneId: morbida.condizioneId),
        ])),
        throwsA(isA<DatabaseException>()),
      );
      expect(await pescateRepo.getPescate(), isEmpty);
    });

    test('eliminaPescata rimuove i figli collegati, aggiorna battuto e preserva Spot ed Esche', () async {
      await inserisciSpotDiProva('Ponte Ruga');
      await db.insert('Specie', {'nome': 'Trota'});
      final esca = await catalogoRepo.salvaEsca(const Esca(nome: 'Minnow'));

      final pescata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 10),
          fasciaOraria: FasciaOraria.mattina,
          spotNome: 'Ponte Ruga',
          esche: [esca],
          foto: const [
            Foto(
              percorso: '/img/p.jpg',
              percorsoThumbnail: '/img/tp.jpg',
            ),
          ],
        ),
      );

      await pescateRepo.salvaCatturaMemorabile(
        CatturaMemorabile(
          pescataId: pescata.id!,
          specieNome: 'Trota',
          esca: esca,
        ),
      );

      await pescateRepo.eliminaPescata(pescata.id!);

      expect(await pescateRepo.getPescataCompleta(pescata.id!), isNull);
      expect(await pescateRepo.getCattureMemorabili(), isEmpty);

      final spot = await db.query('Spot', where: 'nome = ?', whereArgs: ['Ponte Ruga']);
      expect(spot, isNotEmpty);
      expect(spot.first['battuto'], 0);
      expect((await catalogoRepo.getEsche()).length, 1);
    });

    test('salvaPescata richiede lo spot, ma conserva nello storico le pescate di uno spot eliminato', () async {
      // Nuova pescata senza spot: rifiutata
      await expectLater(
        () => pescateRepo.salvaPescata(
          Pescata(
            data: DateTime(2026, 11, 14),
            fasciaOraria: FasciaOraria.alba,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        () => pescateRepo.salvaPescata(
          Pescata(
            data: DateTime(2026, 11, 14),
            fasciaOraria: FasciaOraria.alba,
            spotNome: '   ',
          ),
        ),
        throwsArgumentError,
      );
      expect(await pescateRepo.getPescate(), isEmpty);

      await inserisciSpotDiProva('Ponte Ruga');
      final pescata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 14),
          fasciaOraria: FasciaOraria.alba,
          spotNome: 'Ponte Ruga',
        ),
      );

      // Rimuovere lo spot da una pescata che lo ha: rifiutato
      await expectLater(
        () => pescateRepo.salvaPescata(
          Pescata(
            id: pescata.id,
            data: pescata.data,
            fasciaOraria: pescata.fasciaOraria,
          ),
        ),
        throwsArgumentError,
      );

      // Eliminando lo spot la pescata resta nello storico senza spot (SET NULL)
      await db.delete('Spot', where: 'nome = ?', whereArgs: ['Ponte Ruga']);
      final orfana = await pescateRepo.getPescataCompleta(pescata.id!);
      expect(orfana, isNotNull);
      expect(orfana!.spotNome, isNull);

      // ...e si può ancora modificare senza dover indicare uno spot
      await pescateRepo.salvaPescata(orfana.copyWith(note: 'spot eliminato'));
      final aggiornata = await pescateRepo.getPescataCompleta(pescata.id!);
      expect(aggiornata!.note, 'spot eliminato');
      expect(aggiornata.spotNome, isNull);
    });
  });

  group('PescateRepository - Catture Memorabili e Dettaglio Completo', () {
    test('salvaCatturaMemorabile (insert/update con cambio specie), getCattureMemorabili ed eliminaCatturaMemorabile', () async {
      await db.insert('Specie', {'nome': 'Trota'});
      await db.insert('Specie', {'nome': 'Spigola'});
      final carattId = await db.insert('Caratteristica', {
        'specie_nome': 'Trota',
        'nome': 'Livrea marmorata',
      });
      final marmorata = Caratteristica(
        id: carattId,
        specieNome: 'Trota',
        nome: 'Livrea marmorata',
      );
      final esca = await catalogoRepo.salvaEsca(const Esca(nome: 'Minnow 7cm'));
      await inserisciSpotDiProva('Ponte Ruga');

      final pescata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 11),
          fasciaOraria: FasciaOraria.tramonto,
          spotNome: 'Ponte Ruga',
        ),
      );

      final catturaTrota = await pescateRepo.salvaCatturaMemorabile(
        CatturaMemorabile(
          descrizione: 'Bellissima marmorata',
          pescataId: pescata.id!,
          specieNome: 'Trota',
          esca: esca,
          caratteristiche: [marmorata],
          foto: const [
            Foto(
              percorso: '/img/c1.jpg',
              percorsoThumbnail: '/img/tc1.jpg',
            ),
          ],
        ),
      );

      final catturaSpigola = await pescateRepo.salvaCatturaMemorabile(
        CatturaMemorabile(
          pescataId: pescata.id!,
          specieNome: 'Spigola',
        ),
      );

      expect(catturaTrota.id, isNotNull);
      expect(catturaTrota.foto.single.catturaMemorabileId, catturaTrota.id);

      final soloTrote = await pescateRepo.getCattureMemorabili(
        specieNome: 'Trota',
        escaId: esca.id,
      );
      expect(soloTrote.length, 1);
      expect(soloTrote.first.esca?.nome, 'Minnow 7cm');
      expect(soloTrote.first.caratteristiche.map((c) => c.nome), ['Livrea marmorata']);
      expect(soloTrote.first.foto.length, 1);

      // Cambio specie in modifica su cattura con caratteristiche precedenti
      final modificata = await pescateRepo.salvaCatturaMemorabile(
        catturaTrota.copyWith(
          specieNome: 'Spigola',
          caratteristiche: const [],
        ),
      );
      expect(modificata.specieNome, 'Spigola');
      expect(modificata.caratteristiche, isEmpty);

      await pescateRepo.eliminaCatturaMemorabile(catturaSpigola.id!);
      expect((await pescateRepo.getCattureMemorabili()).length, 1);
    });

    test('salvaPescata salva atomicamente anche nuove esche (con foto) e caratteristiche create al volo', () async {
      await inserisciSpotDiProva('Ponte Ruga');
      await db.insert('Specie', {'nome': 'Trota'});

      const nuovaEsca = Esca(
        nome: 'Jerk 9cm',
        descrizione: 'Creata al volo',
        foto: [
          Foto(
            percorso: '/img/esca_jerk.jpg',
            percorsoThumbnail: '/img/thumb_esca_jerk.jpg',
          ),
        ],
      );
      const nuovaCaratt = Caratteristica(
        specieNome: 'Trota',
        nome: 'Pinna bianca',
      );

      final pescata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 13),
          fasciaOraria: FasciaOraria.alba,
          spotNome: 'Ponte Ruga',
          esche: const [nuovaEsca],
          cattureMemorabili: const [
            CatturaMemorabile(
              descrizione: 'Over 45cm',
              specieNome: 'Trota',
              esca: nuovaEsca,
              caratteristiche: [nuovaCaratt],
              foto: [
                Foto(
                  percorso: '/img/cattura.jpg',
                  percorsoThumbnail: '/img/thumb_cattura.jpg',
                ),
              ],
            ),
          ],
          riepiloghiSpecie: const [
            RiepilogoSpecie(
              specieNome: 'Trota',
              quantita: 3,
              dettagli: [
                RiepilogoCaratteristica(
                  caratteristica: nuovaCaratt,
                  quantita: 1,
                ),
              ],
            ),
          ],
          foto: const [
            Foto(
              percorso: '/img/pescata.jpg',
              percorsoThumbnail: '/img/thumb_pescata.jpg',
            ),
          ],
        ),
      );

      final completa = await pescateRepo.getPescataCompleta(pescata.id!);

      expect(completa, isNotNull);
      expect(completa!.spotNome, 'Ponte Ruga');
      expect(completa.esche.map((e) => e.nome), ['Jerk 9cm']);
      expect(completa.esche.single.id, isNotNull);
      expect(
        completa.esche.single.foto.map((f) => f.percorso),
        ['/img/esca_jerk.jpg'],
      );
      expect(completa.foto.map((f) => f.percorso), ['/img/pescata.jpg']);
      expect(completa.cattureMemorabili.length, 1);
      expect(completa.cattureMemorabili.first.esca?.nome, 'Jerk 9cm');
      expect(
        completa.cattureMemorabili.first.esca?.foto.map((f) => f.percorso),
        ['/img/esca_jerk.jpg'],
      );
      expect(
        completa.cattureMemorabili.first.caratteristiche.map((c) => c.nome),
        ['Pinna bianca'],
      );
      expect(
        completa.cattureMemorabili.first.foto.map((f) => f.percorso),
        ['/img/cattura.jpg'],
      );
      expect(completa.riepiloghiSpecie.length, 1);
      expect(completa.riepiloghiSpecie.first.quantita, 3);
      expect(completa.riepiloghiSpecie.first.dettagli.single.quantita, 1);
      expect(
        completa.riepiloghiSpecie.first.dettagli.single.caratteristica.nome,
        'Pinna bianca',
      );
    });

    test('salvaCatturaMemorabile blocca caratteristiche appartenenti a specie diversa', () async {
      await db.insert('Specie', {'nome': 'Trota'});
      await db.insert('Specie', {'nome': 'Spigola'});
      final carattSpigolaId = await db.insert('Caratteristica', {
        'specie_nome': 'Spigola',
        'nome': 'Over 2 kg',
      });
      final carattSpigola = Caratteristica(
        id: carattSpigolaId,
        specieNome: 'Spigola',
        nome: 'Over 2 kg',
      );

      await inserisciSpotDiProva('Ponte Ruga');
      final pescata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 13),
          fasciaOraria: FasciaOraria.notte,
          spotNome: 'Ponte Ruga',
        ),
      );

      expect(
        () => pescateRepo.salvaCatturaMemorabile(
          CatturaMemorabile(
            pescataId: pescata.id!,
            specieNome: 'Trota',
            caratteristiche: [carattSpigola],
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('PescateRepository - Riepiloghi Specie e Dettagli', () {
    test('salvaPescata salva e aggiorna i riepiloghi con i dettagli per caratteristica', () async {
      await inserisciSpotDiProva('Ponte Ruga');
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      final marmorata = await catalogoRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Livrea marmorata'),
      );
      final ibrido = await catalogoRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Ibrido'),
      );

      // Inserimento iniziale con 2 dettagli per caratteristica
      final salvata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 10),
          fasciaOraria: FasciaOraria.alba,
          spotNome: 'Ponte Ruga',
          riepiloghiSpecie: [
            RiepilogoSpecie(
              specieNome: 'Trota',
              quantita: 4,
              dettagli: [
                RiepilogoCaratteristica(caratteristica: marmorata, quantita: 2),
                RiepilogoCaratteristica(caratteristica: ibrido, quantita: 1),
              ],
            ),
          ],
        ),
      );

      final riepilogo = salvata.riepiloghiSpecie.single;
      expect(riepilogo.id, isNotNull);
      expect(riepilogo.pescataId, salvata.id);
      expect(riepilogo.dettagli.length, 2);
      expect(
        riepilogo.dettagli.every((d) => d.riepilogoSpecieId == riepilogo.id),
        isTrue,
      );

      // Aggiornamento: cambio quantità e riduco a 1 dettaglio
      await pescateRepo.salvaPescata(
        salvata.copyWith(
          riepiloghiSpecie: [
            RiepilogoSpecie(
              specieNome: 'Trota',
              quantita: 5,
              dettagli: [
                RiepilogoCaratteristica(caratteristica: marmorata, quantita: 3),
              ],
            ),
          ],
        ),
      );

      final completa = await pescateRepo.getPescataCompleta(salvata.id!);
      final aggiornato = completa!.riepiloghiSpecie.single;
      expect(aggiornato.quantita, 5);
      expect(aggiornato.dettagli.single.quantita, 3);
      expect(aggiornato.dettagli.single.caratteristica.nome, 'Livrea marmorata');
      expect(await db.query('DettaglioRiepilogo'), hasLength(1));
    });

    test('salvaPescata crea nella stessa transazione le specie scritte al momento', () async {
      await inserisciSpotDiProva('Ponte Ruga');
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Trota'));

      final salvata = await pescateRepo.salvaPescata(
        Pescata(
          data: DateTime(2026, 11, 13),
          fasciaOraria: FasciaOraria.mattina,
          spotNome: 'Ponte Ruga',
          riepiloghiSpecie: const [
            // Esistente scritta con maiuscole e spazi diversi: usa quella
            RiepilogoSpecie(specieNome: ' trota ', quantita: 2),
            // Nuova: nasce con la pescata
            RiepilogoSpecie(specieNome: '  Salmerino ', quantita: 1),
          ],
        ),
      );

      expect((await catalogoRepo.getSpecie()).map((s) => s.nome), ['Salmerino', 'Trota']);
      final completa = await pescateRepo.getPescataCompleta(salvata.id!);
      expect(
        completa!.riepiloghiSpecie.map((r) => r.specieNome),
        containsAll(['Trota', 'Salmerino']),
      );
    });

    test('salvaPescata valida dettaglio <= totale e blocca caratteristiche o specie incoerenti', () async {
      await inserisciSpotDiProva('Ponte Ruga');
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Trota'));
      await catalogoRepo.inserisciSpecie(const Specie(nome: 'Spigola'));
      final carattTrota = await catalogoRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Trota', nome: 'Livrea marmorata'),
      );
      final carattSpigola = await catalogoRepo.salvaCaratteristica(
        const Caratteristica(specieNome: 'Spigola', nome: 'Over 2 kg'),
      );

      Pescata conRiepiloghi(List<RiepilogoSpecie> riepiloghi) => Pescata(
            data: DateTime(2026, 11, 13),
            fasciaOraria: FasciaOraria.mattina,
            spotNome: 'Ponte Ruga',
            riepiloghiSpecie: riepiloghi,
          );

      // Dettaglio superiore al totale -> ArgumentError
      await expectLater(
        () => pescateRepo.salvaPescata(conRiepiloghi([
          RiepilogoSpecie(
            specieNome: 'Trota',
            quantita: 2,
            dettagli: [
              RiepilogoCaratteristica(caratteristica: carattTrota, quantita: 3),
            ],
          ),
        ])),
        throwsArgumentError,
      );

      // Caratteristica di un'altra specie -> rifiutata dalla FK composta
      await expectLater(
        () => pescateRepo.salvaPescata(conRiepiloghi([
          RiepilogoSpecie(
            specieNome: 'Trota',
            quantita: 2,
            dettagli: [
              RiepilogoCaratteristica(caratteristica: carattSpigola, quantita: 1),
            ],
          ),
        ])),
        throwsA(isA<DatabaseException>()),
      );

      // Stessa specie due volte nella stessa pescata -> UNIQUE
      await expectLater(
        () => pescateRepo.salvaPescata(conRiepiloghi(const [
          RiepilogoSpecie(specieNome: 'Trota', quantita: 1),
          RiepilogoSpecie(specieNome: 'Trota', quantita: 2),
        ])),
        throwsA(isA<DatabaseException>()),
      );

      // Le transazioni fallite non lasciano dati parziali
      expect(await pescateRepo.getPescate(), isEmpty);

      // Una pescata valida e poi la rimozione dei suoi riepiloghi
      final valida = await pescateRepo.salvaPescata(conRiepiloghi(const [
        RiepilogoSpecie(specieNome: 'Trota', quantita: 2),
      ]));
      await pescateRepo.salvaPescata(valida.copyWith(riepiloghiSpecie: const []));
      final completa = await pescateRepo.getPescataCompleta(valida.id!);
      expect(completa!.riepiloghiSpecie, isEmpty);
    });
  });
}
