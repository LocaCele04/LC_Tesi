import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/import_service.dart';
import '../state/catalogo_state.dart';
import '../state/dipendenze.dart';
import '../state/mappa_state.dart';
import '../state/pescate_state.dart';
import '../state/spot_state.dart';

/// Sceglie un file sul telefono e ne restituisce il testo, `null` se
/// l'utente annulla. Nei test si sostituisce con una funzione finta.
typedef SceltaFile = Future<String?> Function();

Future<String?> _scegliFileDalTelefono() async {
  final file = await FilePicker.pickFile();
  if (file == null) return null;
  return utf8.decode(await file.readAsBytes());
}

/// Import dei dati da un file preparato fuori dall'app (lo storico):
/// scelta del file, riepilogo di cosa contiene (o dei problemi trovati),
/// import con avanzamento ed esito. Funziona solo su un diario vuoto.
class ImportaScreen extends ConsumerStatefulWidget {
  const ImportaScreen({super.key, this.scegliFile = _scegliFileDalTelefono});

  final SceltaFile scegliFile;

  @override
  ConsumerState<ImportaScreen> createState() => _ImportaScreenState();
}

class _ImportaScreenState extends ConsumerState<ImportaScreen> {
  DatiImport? _dati;
  List<String> _problemi = const [];
  bool _lettura = false;
  bool _importInCorso = false;
  ({String fase, int fatti, int totale})? _avanzamento;
  EsitoImport? _esito;
  String? _errore;

  Future<void> _scegli() async {
    setState(() {
      _lettura = true;
      _dati = null;
      _problemi = const [];
      _errore = null;
    });
    try {
      final testo = await widget.scegliFile();
      if (testo == null) return;
      final dati = await ref.read(importServiceProvider).leggi(testo);
      if (mounted) setState(() => _dati = dati);
    } on ImportNonValido catch (e) {
      if (mounted) setState(() => _problemi = e.problemi);
    } catch (e) {
      if (mounted) setState(() => _problemi = ['File non leggibile: $e']);
    } finally {
      if (mounted) setState(() => _lettura = false);
    }
  }

  Future<void> _importa() async {
    final dati = _dati!;
    setState(() => _importInCorso = true);
    try {
      final esito = await ref.read(importServiceProvider).importa(
            dati,
            avanzamento: (fase, fatti, totale) {
              if (mounted) setState(() => _avanzamento = (fase: fase, fatti: fatti, totale: totale));
            },
          );
      if (mounted) setState(() => _esito = esito);
    } catch (e) {
      if (mounted) setState(() => _errore = e.toString());
    } finally {
      // Anche dopo un errore una parte dei dati può essere stata salvata.
      ref
        ..invalidate(elencoSpotProvider)
        ..invalidate(elencoPescateProvider)
        ..invalidate(divietiProvider)
        ..invalidate(categorieProvider)
        ..invalidate(ambientiProvider)
        ..invalidate(specieProvider)
        ..invalidate(escheProvider)
        ..invalidate(nomiCondizioniProvider)
        ..invalidate(caratteristicheProvider);
      if (mounted) setState(() => _importInCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final dati = _dati;
    final avanzamento = _avanzamento;

    return Scaffold(
      appBar: AppBar(title: const Text('Importa dati')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Importa spot, divieti e pescate da un file preparato fuori dall\'app. '
            'Il file viene letto solo sul telefono. L\'import si può fare solo su un '
            'diario vuoto.',
            style: testo.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (_esito == null)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _lettura || _importInCorso ? null : _scegli,
                icon: const Icon(Icons.file_open_outlined),
                label: Text(dati == null ? 'Scegli il file' : 'Scegli un altro file'),
              ),
            ),
          if (_lettura) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
          ],
          if (_problemi.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Il file non si può importare', style: testo.titleMedium),
            const SizedBox(height: 8),
            for (final p in _problemi)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $p')),
          ],
          if (dati != null && _esito == null) ...[
            const SizedBox(height: 24),
            Text('Contenuto del file', style: testo.titleMedium),
            const SizedBox(height: 8),
            Text('${dati.spot.length} spot (${dati.spotConTratto} con il tratto)'),
            Text('${dati.divieti.length} divieti'),
            Text('${dati.pescate.length} pescate, ${dati.catture} catture'),
            if (dati.ambienti.isNotEmpty) Text('Ambienti nuovi: ${dati.ambienti.map((a) => a.nome).join(', ')}'),
            const SizedBox(height: 24),
            if (avanzamento != null && _importInCorso) ...[
              Text('${avanzamento.fase}: ${avanzamento.fatti} di ${avanzamento.totale}'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: avanzamento.totale == 0 ? null : avanzamento.fatti / avanzamento.totale,
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _importInCorso ? null : _importa,
              icon: const Icon(Icons.download_done),
              label: const Text('Importa'),
            ),
          ],
          if (_errore != null) ...[
            const SizedBox(height: 24),
            Text('Import interrotto', style: testo.titleMedium),
            const SizedBox(height: 8),
            Text(_errore!),
            const SizedBox(height: 8),
            const Text(
              'Una parte dei dati potrebbe essere già stata salvata: prima di riprovare '
              'cancella i dati dell\'app per ripartire da un diario vuoto.',
            ),
          ],
          if (_esito != null) ...[
            const SizedBox(height: 24),
            Text('Import completato', style: testo.titleMedium),
            const SizedBox(height: 8),
            Text('${_esito!.spot} spot, ${_esito!.divieti} divieti e ${_esito!.pescate} pescate importati.'),
            const SizedBox(height: 8),
            const Text(
              'Il meteo delle pescate è da scaricare: usa il pulsante con la nuvola '
              'nell\'elenco delle pescate. Ora puoi cancellare il file dal telefono.',
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
