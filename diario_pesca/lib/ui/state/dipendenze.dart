import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/archivio_foto.dart';
import '../../data/database_helper.dart';
import '../../repositories/catalogo_repository.dart';
import '../../repositories/meteo_repository.dart';
import '../../repositories/obiettivi_repository.dart';
import '../../repositories/pescate_repository.dart';
import '../../repositories/territorio_repository.dart';
import '../../services/backup_service.dart';
import '../../services/import_service.dart';
import '../../services/meteo_service.dart';
import '../../services/posizione_service.dart';
import '../../services/statistiche_service.dart';

// Provider delle dipendenze: rendono disponibili all'interfaccia il
// database, i repository e i servizi, ognuno creato una sola volta.
//
// Le schermate e i notifier non costruiscono mai un repository con `new`:
// lo chiedono al provider. Così nei test basta sostituire
// [databaseHelperProvider] con un database in memoria (o un repository con
// una versione finta) e tutto il resto lo userà, senza modificare il codice.
// Vedi `docs/scelta_architetturale_gestione_dello_stato.md`.

/// Data e ora attuali. Nei test si sostituisce con un "oggi" fisso.
final orologioProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Database dell'app. Nei test si sostituisce con `DatabaseHelper.inMemory()`.
final databaseHelperProvider = Provider<DatabaseHelper>(
  (ref) => DatabaseHelper.instance,
);

/// Accesso ai file delle foto sul dispositivo.
final archivioFotoProvider = Provider<ArchivioFoto>(
  (ref) => const ArchivioFoto(),
);

final catalogoRepositoryProvider = Provider<CatalogoRepository>(
  (ref) => CatalogoRepository(
    dbHelper: ref.watch(databaseHelperProvider),
    archivioFoto: ref.watch(archivioFotoProvider),
  ),
);

final territorioRepositoryProvider = Provider<TerritorioRepository>(
  (ref) => TerritorioRepository(dbHelper: ref.watch(databaseHelperProvider)),
);

final pescateRepositoryProvider = Provider<PescateRepository>(
  (ref) => PescateRepository(
    dbHelper: ref.watch(databaseHelperProvider),
    catalogo: ref.watch(catalogoRepositoryProvider),
    archivioFoto: ref.watch(archivioFotoProvider),
  ),
);

final obiettiviRepositoryProvider = Provider<ObiettiviRepository>(
  (ref) => ObiettiviRepository(
    dbHelper: ref.watch(databaseHelperProvider),
    catalogo: ref.watch(catalogoRepositoryProvider),
  ),
);

final meteoRepositoryProvider = Provider<MeteoRepository>(
  (ref) => MeteoRepository(dbHelper: ref.watch(databaseHelperProvider)),
);

final statisticheServiceProvider = Provider<StatisticheService>(
  (ref) => StatisticheService(
    dbHelper: ref.watch(databaseHelperProvider),
    meteo: ref.watch(meteoRepositoryProvider),
  ),
);

/// Servizio meteo. Il client HTTP viene chiuso quando il provider viene
/// eliminato (alla chiusura dell'app o alla fine di un test).
final meteoServiceProvider = Provider<MeteoService>((ref) {
  final servizio = MeteoService(meteo: ref.watch(meteoRepositoryProvider));
  ref.onDispose(servizio.chiudi);
  return servizio;
});

/// Posizione del telefono (GPS). Nei test si sostituisce con una finta.
final posizioneServiceProvider = Provider<PosizioneService>(
  (ref) => const PosizioneService(),
);

/// Backup e ripristino di tutti i dati.
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(dbHelper: ref.watch(databaseHelperProvider)),
);

/// Import dello storico da un file JSON. Strumento di migrazione dei dati
/// per lo sviluppatrice: la voce di menu compare solo in modalità debug.
final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(
    territorio: ref.watch(territorioRepositoryProvider),
    catalogo: ref.watch(catalogoRepositoryProvider),
    pescate: ref.watch(pescateRepositoryProvider),
  ),
);
