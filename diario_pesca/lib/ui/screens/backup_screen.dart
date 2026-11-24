import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database_helper.dart';
import '../../services/backup_service.dart';
import '../state/catalogo_state.dart';
import '../state/dipendenze.dart';
import '../state/mappa_state.dart';
import '../state/pescate_state.dart';
import '../state/spot_state.dart';

/// Salva [byte] in un file chiamato [nome] scelto dall'utente; `false` se
/// l'utente annulla. Nei test si sostituisce con una funzione finta.
typedef SalvataggioFile = Future<bool> Function(String nome, Uint8List byte);

/// Fa scegliere un file all'utente e ne restituisce i byte, `null` se
/// annulla. Nei test si sostituisce con una funzione finta.
typedef SceltaFile = Future<Uint8List?> Function();

/// La finestra di sistema per salvare permette di scegliere la memoria del
/// telefono o, se è installata l'app, una cartella di Google Drive.
Future<bool> _salvaSulTelefono(String nome, Uint8List byte) async {
  final destinazione = await FilePicker.saveFile(
    dialogTitle: 'Salva il backup',
    fileName: nome,
    bytes: byte,
  );
  return destinazione != null;
}

Future<Uint8List?> _scegliDalTelefono() async {
  final file = await FilePicker.pickFile();
  if (file == null) return null;
  return Uint8List.fromList(await file.readAsBytes());
}

String _due(int n) => n.toString().padLeft(2, '0');

String _dataOra(DateTime d) => '${_due(d.day)}/${_due(d.month)}/${d.year} alle ${_due(d.hour)}:${_due(d.minute)}';

/// Backup di tutti i dati in un file (REQ-FUN-14) e ripristino da un file
/// di backup (REQ-FUN-15), con riepilogo e conferma prima di sostituire i
/// dati.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({
    super.key,
    this.salvaFile = _salvaSulTelefono,
    this.scegliFile = _scegliDalTelefono,
  });

  final SalvataggioFile salvaFile;
  final SceltaFile scegliFile;

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _occupato = false;

  DateTime? _backupSalvato;
  String? _erroreBackup;

  ContenutoBackup? _scelto;
  String? _problemaFile;
  bool _ripristinato = false;
  String? _erroreRipristino;

  Future<void> _creaBackup() async {
    setState(() {
      _occupato = true;
      _backupSalvato = null;
      _erroreBackup = null;
    });
    try {
      final servizio = ref.read(backupServiceProvider);
      final nome = servizio.nomeFile();
      final byte = await servizio.crea();
      final salvato = await widget.salvaFile(nome, byte);
      if (salvato && mounted) setState(() => _backupSalvato = ref.read(orologioProvider)());
    } catch (e) {
      if (mounted) setState(() => _erroreBackup = e.toString());
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  Future<void> _scegliBackup() async {
    setState(() {
      _occupato = true;
      _scelto = null;
      _problemaFile = null;
      _erroreRipristino = null;
    });
    try {
      final byte = await widget.scegliFile();
      if (byte == null) return;
      final contenuto = await ref.read(backupServiceProvider).leggi(byte);
      if (mounted) setState(() => _scelto = contenuto);
    } on BackupNonValido catch (e) {
      if (mounted) setState(() => _problemaFile = e.messaggio);
    } catch (e) {
      if (mounted) setState(() => _problemaFile = 'File non leggibile: $e');
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  Future<void> _ripristina(ContenutoBackup contenuto) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (contesto) => AlertDialog(
        title: const Text('Sostituire tutti i dati?'),
        content: Text(
          'Spot, divieti, pescate e tutti gli altri dati dell\'app verranno '
          'cancellati e sostituiti con quelli del backup del ${_dataOra(contenuto.creatoIl)}. '
          'L\'operazione non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contesto).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contesto).pop(true),
            child: const Text('Sostituisci'),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;

    setState(() {
      _occupato = true;
      _erroreRipristino = null;
    });
    try {
      await ref.read(backupServiceProvider).ripristina(contenuto);
      if (mounted) setState(() => _ripristinato = true);
    } catch (e) {
      if (mounted) setState(() => _erroreRipristino = e.toString());
    } finally {
      _ricaricaDati();
      if (mounted) setState(() => _occupato = false);
    }
  }

  /// Dopo il ripristino tutte le schermate devono rileggere il database.
  void _ricaricaDati() {
    ref
      ..invalidate(elencoSpotProvider)
      ..invalidate(dettaglioSpotProvider)
      ..invalidate(categorieProvider)
      ..invalidate(ambientiProvider)
      ..invalidate(spotSullaMappaProvider)
      ..invalidate(divietiProvider)
      ..invalidate(elencoPescateProvider)
      ..invalidate(totaliCattureProvider)
      ..invalidate(pescateSenzaMeteoProvider)
      ..invalidate(dettaglioPescataProvider)
      ..invalidate(meteoPescataProvider)
      ..invalidate(pioggiaCumulataProvider)
      ..invalidate(escheProvider)
      ..invalidate(specieProvider)
      ..invalidate(caratteristicheProvider)
      ..invalidate(condizioniPerFormProvider)
      ..invalidate(nomiCondizioniProvider);
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final colori = Theme.of(context).colorScheme;
    final scelto = _scelto;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup e ripristino')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_occupato) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          Text('Backup', style: testo.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Salva in un file tutti i dati dell\'app: spot, divieti, pescate, catture, '
            'meteo scaricato e cataloghi. Puoi salvarlo nella memoria del telefono o, '
            'se hai l\'app Google Drive, direttamente su Drive.',
          ),
          const SizedBox(height: 8),
          Text(
            'Il file contiene i tuoi dati personali: conservalo in un posto solo tuo.',
            style: testo.bodySmall,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _occupato || _ripristinato ? null : _creaBackup,
              icon: const Icon(Icons.save_alt),
              label: const Text('Crea backup'),
            ),
          ),
          if (_backupSalvato != null) ...[
            const SizedBox(height: 12),
            Text('Backup salvato il ${_dataOra(_backupSalvato!)}.'),
          ],
          if (_erroreBackup != null) ...[
            const SizedBox(height: 12),
            Text('Backup non riuscito: $_erroreBackup', style: TextStyle(color: colori.error)),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(),
          ),
          Text('Ripristino', style: testo.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Sostituisce tutti i dati dell\'app con quelli di un file di backup, anche '
            'creato su un altro telefono. I dati attuali vengono cancellati: se vuoi '
            'conservarli, crea prima un backup.',
          ),
          const SizedBox(height: 16),
          if (!_ripristinato)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _occupato ? null : _scegliBackup,
                icon: const Icon(Icons.file_open_outlined),
                label: Text(scelto == null ? 'Scegli un backup' : 'Scegli un altro backup'),
              ),
            ),
          if (_problemaFile != null) ...[
            const SizedBox(height: 12),
            Text(_problemaFile!, style: TextStyle(color: colori.error)),
          ],
          if (scelto != null && !_ripristinato) ...[
            const SizedBox(height: 20),
            Text('Backup del ${_dataOra(scelto.creatoIl)}', style: testo.titleSmall),
            const SizedBox(height: 8),
            Text('${scelto.spot} spot, ${scelto.divieti} divieti'),
            Text('${scelto.pescate} pescate, ${scelto.catture} catture'),
            if (scelto.foto.isNotEmpty) Text('${scelto.foto.length} foto'),
            if (scelto.versioneSchema < DatabaseHelper.versioneSchema) ...[
              const SizedBox(height: 8),
              Text(
                'Creato con una versione precedente dell\'app: i dati verranno '
                'aggiornati durante il ripristino.',
                style: testo.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colori.error,
                foregroundColor: colori.onError,
              ),
              onPressed: _occupato ? null : () => _ripristina(scelto),
              icon: const Icon(Icons.restore),
              label: const Text('Ripristina'),
            ),
          ],
          if (_erroreRipristino != null) ...[
            const SizedBox(height: 12),
            Text('Ripristino non riuscito: $_erroreRipristino', style: TextStyle(color: colori.error)),
            const SizedBox(height: 4),
            const Text('I dati dell\'app sono rimasti quelli di prima.'),
          ],
          if (_ripristinato && scelto != null) ...[
            const SizedBox(height: 4),
            Text('Ripristino completato', style: testo.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Ora l\'app contiene i dati del backup del ${_dataOra(scelto.creatoIl)}: '
              '${scelto.spot} spot, ${scelto.divieti} divieti, ${scelto.pescate} pescate.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fine'),
            ),
          ],
        ],
      ),
    );
  }
}
