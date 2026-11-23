import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/catalogo/caratteristica.dart';
import 'package:diario_pesca/models/catalogo/esca.dart';
import 'package:diario_pesca/models/catalogo/specie.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/pescate/pescata.dart';
import 'package:diario_pesca/models/pescate/riepilogo_caratteristica.dart';
import 'package:diario_pesca/models/pescate/riepilogo_specie.dart';
import 'package:diario_pesca/models/territorio/categoria.dart';
import 'package:diario_pesca/models/territorio/coordinata.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/services/meteo_service.dart';
import 'package:diario_pesca/ui/screens/elenco_pescate_screen.dart';
import 'package:diario_pesca/ui/state/catalogo_state.dart';
import 'package:diario_pesca/ui/state/dipendenze.dart';
import 'package:diario_pesca/ui/state/modulo_pescata_state.dart';
import 'package:diario_pesca/ui/state/pescate_state.dart';
import 'package:diario_pesca/ui/state/spot_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'supporto/open_meteo_finto.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late ProviderContainer container;
  late Caratteristica over30;
  final richieste = <http.Request>[];

  setUp(() async {
    richieste.clear();
    dbHelper = DatabaseHelper.inMemory();
    container = ProviderContainer.test(
      overrides: [
        databaseHelperProvider.overrideWith((ref) => dbHelper),
        orologioProvider.overrideWith((ref) => () => oggi),
        // Open-Meteo finto: nessuna richiesta esce dal test.
        meteoServiceProvider.overrideWith((ref) {
          final servizio = MeteoService(
            meteo: ref.watch(meteoRepositoryProvider),
            client: MockClient((r) async {
              richieste.add(r);
              return rispostaOpenMeteo(r);
            }),
            adesso: () => oggi,
          );
          ref.onDispose(servizio.chiudi);
          return servizio;
        }),
      ],
      retry: (tentativo, errore) => null,
    );

    final territorio = container.read(territorioRepositoryProvider);
    await territorio.inserisciCategoria(const Categoria(nome: 'Valle'));
    await territorio.salvaSpotConCoordinate(
      const Spot(
        nome: 'Valbrina',
        ambiente: 'Torrente',
        categoriaNome: 'Valle',
        coordinate: [Coordinata(ordine: 0, latitudine: 45.7612, longitudine: 9.6401)],
      ),
    );
    final catalogo = container.read(catalogoRepositoryProvider);
    await catalogo.inserisciSpecie(const Specie(nome: 'Trota'));
    await catalogo.inserisciSpecie(const Specie(nome: 'Temolo'));
    over30 = await catalogo.salvaCaratteristica(
      const Caratteristica(specieNome: 'Trota', nome: 'Over 30'),
    );
    await catalogo.salvaEsca(const Esca(nome: 'Gomma verde'));

    // Le schermate dell'elenco restano aperte per tutto il test.
    container.listen(elencoPescateProvider, (_, _) {});
    container.listen(totaliCattureProvider, (_, _) {});
    container.listen(pescateSenzaMeteoProvider, (_, _) {});
  });

  tearDown(() async {
    await dbHelper.close();
  });

  Future<Pescata> salva(DateTime data, {List<RiepilogoSpecie> catture = const []}) =>
      container.read(elencoPescateProvider.notifier).salva(
            Pescata(
              data: data,
              fasciaOraria: FasciaOraria.alba,
              spotNome: 'Valbrina',
              riepiloghiSpecie: catture,
            ),
          );

  group('Stato delle pescate - Elenco', () {
    test('totali delle catture e meteo da scaricare seguono salvataggi ed eliminazioni', () async {
      final conCatture = await salva(DateTime(2026, 2, 10), catture: const [
        RiepilogoSpecie(specieNome: 'Trota', quantita: 3),
        RiepilogoSpecie(specieNome: 'Temolo', quantita: 2),
      ]);
      final senzaCatture = await salva(DateTime(2026, 2, 12));

      final elenco = await container.read(elencoPescateProvider.future);
      // Dalla più recente
      expect(elenco.map((p) => p.id), [senzaCatture.id, conCatture.id]);
      expect(await container.read(totaliCattureProvider.future), {conCatture.id: 5});
      expect(
        await container.read(pescateSenzaMeteoProvider.future),
        {conCatture.id, senzaCatture.id},
      );

      await container.read(elencoPescateProvider.notifier).elimina(conCatture.id!);
      expect(await container.read(totaliCattureProvider.future), isEmpty);
      expect(await container.read(pescateSenzaMeteoProvider.future), {senzaCatture.id});
      expect((await container.read(elencoPescateProvider.future)).single.id, senzaCatture.id);
    });

    test('scaricare il meteo aggiorna elenco e scheda e descrive l\'esito', () async {
      final pescata = await salva(DateTime(2026, 2, 10));
      container.listen(meteoPescataProvider(pescata.id!), (_, _) {});
      expect((await container.read(meteoPescataProvider(pescata.id!).future)).stato, StatoMeteo.daScaricare);

      final esito = await container.read(aggiornamentoMeteoProvider.notifier).aggiorna();
      expect(esito!.completate, 1);
      expect(richieste, hasLength(1));
      expect(descriviEsitoMeteo(esito), 'Meteo scaricato per 1 pescata.');

      expect(await container.read(pescateSenzaMeteoProvider.future), isEmpty);
      expect((await container.read(meteoPescataProvider(pescata.id!).future)).stato, StatoMeteo.scaricato);
      // Pioggia finta: 1 mm al giorno
      expect(
        await container.read(pioggiaCumulataProvider((pescataId: pescata.id!, giorni: 3)).future),
        3.0,
      );

      // Un secondo aggiornamento non ha nulla da scaricare
      final secondo = await container.read(aggiornamentoMeteoProvider.notifier).aggiorna();
      expect(descriviEsitoMeteo(secondo!), 'Il meteo delle pescate passate è già tutto scaricato.');
      expect(richieste, hasLength(1));
    });
  });

  group('Stato delle pescate - Modifica', () {
    test('il modulo parte dalla pescata salvata e la aggiorna senza crearne un\'altra', () async {
      final catalogo = container.read(catalogoRepositoryProvider);
      final livello = (await catalogo.getCondizioni(ambienteNome: 'Torrente'))
          .firstWhere((c) => c.nome == 'Livello');
      final morbida = livello.valori.firstWhere((v) => v.nome == 'Morbida');
      final esca = (await catalogo.getEsche()).single;
      final salvata = await container.read(elencoPescateProvider.notifier).salva(
            Pescata(
              data: DateTime(2026, 2, 10),
              fasciaOraria: FasciaOraria.mattina,
              spotNome: 'Valbrina',
              tempAcqua: 8.5,
              note: 'Prima uscita',
              valoriCondizioni: [morbida],
              esche: [esca],
              riepiloghiSpecie: [
                RiepilogoSpecie(
                  specieNome: 'Trota',
                  quantita: 4,
                  dettagli: [RiepilogoCaratteristica(caratteristica: over30, quantita: 2)],
                ),
              ],
            ),
          );
      final completa = await container.read(dettaglioPescataProvider(salvata.id!).future);

      final apertura = (pescata: completa!, ambiente: 'Torrente');
      container.listen(moduloPescataProvider(apertura), (_, _) {});
      final modulo = container.read(moduloPescataProvider(apertura).notifier);
      final bozza = container.read(moduloPescataProvider(apertura));
      expect(bozza.isNuova, isFalse);
      expect(bozza.spotNome, 'Valbrina');
      expect(bozza.fasciaOraria, FasciaOraria.mattina);
      expect(bozza.tempAcqua, '8.5');
      expect(bozza.note, 'Prima uscita');
      expect(bozza.valori[livello.id]?.nome, 'Morbida');
      expect(bozza.esche.single.nome, 'Gomma verde');
      expect(bozza.catture.single.totale, 4);
      expect(bozza.catture.single.dettagli, {over30: 2});

      // Le condizioni del modulo includono quelle usate dalla pescata
      final condizioni = await container.read(
        condizioniPerFormProvider((ambiente: 'Torrente', pescataId: salvata.id)).future,
      );
      expect(condizioni.map((c) => c.nome), contains('Livello'));

      // Una riga aggiunta riceve una chiave nuova, diversa da quella caricata
      modulo.aggiungiCattura();
      final righe = container.read(moduloPescataProvider(apertura)).catture;
      expect(righe.map((c) => c.chiave).toSet(), hasLength(2));
      modulo.impostaSpecie(righe.last.chiave, 'Temolo');
      modulo.impostaTotale(righe.last.chiave, 1);
      modulo.impostaTotale(righe.first.chiave, 6);

      final aggiornata = await modulo.salva();
      expect(aggiornata.id, salvata.id);
      expect(await container.read(elencoPescateProvider.future), hasLength(1));
      final rilettura = await container.read(dettaglioPescataProvider(salvata.id!).future);
      expect(rilettura!.riepiloghiSpecie.map((r) => '${r.specieNome} ${r.quantita}'), containsAll(['Trota 6', 'Temolo 1']));
      expect(rilettura.riepiloghiSpecie.firstWhere((r) => r.specieNome == 'Trota').dettagli.single.quantita, 2);
      expect(rilettura.note, 'Prima uscita');
      expect(await container.read(totaliCattureProvider.future), {salvata.id: 7});
    });

    test('una pescata rimasta senza spot si modifica senza dover scegliere uno spot', () async {
      final salvata = await salva(DateTime(2026, 2, 10));
      await container.read(elencoSpotProvider.notifier).elimina('Valbrina');
      final completa = await container.read(dettaglioPescataProvider(salvata.id!).future);
      expect(completa!.spotNome, isNull);

      final apertura = (pescata: completa, ambiente: null);
      container.listen(moduloPescataProvider(apertura), (_, _) {});
      expect(container.read(moduloPescataProvider(apertura)).errori(oggi: oggi), isEmpty);

      container.read(moduloPescataProvider(apertura).notifier).impostaNote('Spot chiuso');
      await container.read(moduloPescataProvider(apertura).notifier).salva();
      final rilettura = await container.read(dettaglioPescataProvider(salvata.id!).future);
      expect(rilettura!.note, 'Spot chiuso');
      expect(rilettura.spotNome, isNull);
    });
  });
}
