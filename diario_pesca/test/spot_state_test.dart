import 'package:diario_pesca/data/database_helper.dart';
import 'package:diario_pesca/models/enums.dart';
import 'package:diario_pesca/models/territorio/categoria.dart';
import 'package:diario_pesca/models/territorio/coordinata.dart';
import 'package:diario_pesca/models/territorio/spot.dart';
import 'package:diario_pesca/repositories/territorio_repository.dart';
import 'package:diario_pesca/ui/state/dipendenze.dart';
import 'package:diario_pesca/ui/state/spot_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Repository che non riesce a leggere gli spot, per verificare lo stato
/// di errore.
class _TerritorioGuasto extends TerritorioRepository {
  _TerritorioGuasto() : super(dbHelper: DatabaseHelper.inMemory());

  int letture = 0;

  @override
  Future<List<Spot>> getSpots({
    String? categoriaNome,
    String? ambiente,
    double? votoMinimo,
    double? lunghezzaMassima,
    Difficolta? difficolta,
    bool? battuto,
    Accessibilita? accessibilita,
  }) async {
    letture++;
    throw Exception('Database non leggibile');
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper dbHelper;
  late ProviderContainer container;

  setUp(() async {
    dbHelper = DatabaseHelper.inMemory();
    // Tutta l'app usa il database in memoria: basta sostituire un provider.
    container = ProviderContainer.test(
      overrides: [databaseHelperProvider.overrideWith((ref) => dbHelper)],
      retry: (tentativo, errore) => null,
    );
    await container
        .read(territorioRepositoryProvider)
        .inserisciCategoria(const Categoria(nome: 'Valle'));
  });

  tearDown(() async {
    await dbHelper.close();
  });

  const valsecca = Spot(
    nome: 'Valsecca',
    ambiente: 'Torrente',
    categoriaNome: 'Valle',
    coordinate: [
      Coordinata(ordine: 0, latitudine: 45.7612, longitudine: 9.6401),
      Coordinata(ordine: 1, latitudine: 45.7650, longitudine: 9.6450),
    ],
  );

  List<String> nomi(List<Spot> spot) => spot.map((s) => s.nome).toList();

  group('Stato degli spot - Lettura', () {
    test('l\'elenco si carica dal database in ordine alfabetico', () async {
      final repo = container.read(territorioRepositoryProvider);
      await repo.salvaSpotConCoordinate(valsecca);
      await repo.salvaSpotConCoordinate(
        const Spot(nome: 'Ambriola', ambiente: 'Torrente', categoriaNome: 'Valle'),
      );

      expect(nomi(await container.read(elencoSpotProvider.future)), ['Ambriola', 'Valsecca']);
      expect(container.read(elencoSpotProvider).hasValue, isTrue);
      // Ambienti di base e categorie sono disponibili per i moduli
      expect(await container.read(ambientiProvider.future), isNotEmpty);
      expect((await container.read(categorieProvider.future)).single.nome, 'Valle');
    });

    test('se la lettura fallisce lo stato è un errore e "Riprova" ricarica', () async {
      final repoGuasto = _TerritorioGuasto();
      final guasto = ProviderContainer.test(
        overrides: [territorioRepositoryProvider.overrideWith((ref) => repoGuasto)],
        retry: (tentativo, errore) => null,
      );
      guasto.listen(elencoSpotProvider, (_, _) {});

      await expectLater(guasto.read(elencoSpotProvider.future), throwsA(anything));
      expect(guasto.read(elencoSpotProvider).hasError, isTrue);
      // Nessun nuovo tentativo automatico
      expect(repoGuasto.letture, 1);

      // "Riprova" invalida il provider, che rilegge il database
      guasto.invalidate(elencoSpotProvider);
      await expectLater(guasto.read(elencoSpotProvider.future), throwsA(anything));
      expect(repoGuasto.letture, 2);
    });
  });

  group('Stato degli spot - Scrittura', () {
    test('salvare uno spot aggiorna da solo l\'elenco e il dettaglio', () async {
      // Una schermata aperta sull'elenco e una sul dettaglio
      container.listen(elencoSpotProvider, (_, _) {});
      container.listen(dettaglioSpotProvider('Valsecca'), (_, _) {});
      expect(await container.read(elencoSpotProvider.future), isEmpty);
      expect(await container.read(dettaglioSpotProvider('Valsecca').future), isNull);

      await container.read(elencoSpotProvider.notifier).salva(valsecca);

      expect(nomi(container.read(elencoSpotProvider).requireValue), ['Valsecca']);
      final dettaglio = await container.read(dettaglioSpotProvider('Valsecca').future);
      expect(dettaglio?.coordinate, hasLength(2));
      expect(dettaglio?.lunghezzaMetri, isNotNull);
    });

    test('rinominare ed eliminare uno spot aggiornano l\'elenco', () async {
      container.listen(elencoSpotProvider, (_, _) {});
      final notifier = container.read(elencoSpotProvider.notifier);
      await notifier.salva(valsecca);

      await notifier.salva(valsecca.copyWith(nome: 'Valsecca bassa'), nomeOriginale: 'Valsecca');
      expect(nomi(container.read(elencoSpotProvider).requireValue), ['Valsecca bassa']);

      await notifier.elimina('Valsecca bassa');
      expect(container.read(elencoSpotProvider).requireValue, isEmpty);
    });

    test('un errore di scrittura arriva a chi salva e l\'elenco resta com\'era', () async {
      container.listen(elencoSpotProvider, (_, _) {});
      final notifier = container.read(elencoSpotProvider.notifier);
      await notifier.salva(valsecca);

      // Ambiente inesistente: il database rifiuta lo spot
      await expectLater(
        notifier.salva(valsecca.copyWith(nome: 'Altro', ambiente: 'Inesistente')),
        throwsA(isA<DatabaseException>()),
      );
      expect(nomi(container.read(elencoSpotProvider).requireValue), ['Valsecca']);
    });
  });
}
