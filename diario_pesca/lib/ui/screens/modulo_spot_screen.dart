import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalogo/condizione.dart';
import '../../models/enums.dart';
import '../../models/territorio/coordinata.dart';
import '../../models/territorio/spot.dart';
import '../state/modulo_spot_state.dart';
import '../state/spot_state.dart';
import '../widgets/dialoghi.dart';
import '../widgets/dialogo_nome.dart';
import '../widgets/vista_asincrona.dart';

/// Apre il modulo per modificare lo spot [nome], dopo averlo caricato con
/// le coordinate.
class ModificaSpotScreen extends ConsumerStatefulWidget {
  const ModificaSpotScreen({super.key, required this.nome});

  final String nome;

  @override
  ConsumerState<ModificaSpotScreen> createState() => _ModificaSpotScreenState();
}

class _ModificaSpotScreenState extends ConsumerState<ModificaSpotScreen> {
  /// Spot caricato la prima volta. Il modulo continua a usare questo anche
  /// se, salvando o eliminando, il dettaglio cambia prima che la schermata
  /// si chiuda.
  Spot? _caricato;

  @override
  Widget build(BuildContext context) {
    if (_caricato != null) return ModuloSpotScreen(spot: _caricato);
    final dettaglio = ref.watch(dettaglioSpotProvider(widget.nome));
    return dettaglio.when(
      data: (spot) {
        if (spot == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Lo spot non esiste più.')),
          );
        }
        _caricato = spot;
        return ModuloSpotScreen(spot: spot);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(widget.nome)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(widget.nome)),
        body: VistaAsincrona<Spot?>(
          valore: dettaglio,
          dati: (_) => const SizedBox.shrink(),
          riprova: () => ref.invalidate(dettaglioSpotProvider(widget.nome)),
        ),
      ),
    );
  }
}

/// Modulo di uno spot: nuovo ([spot] nullo) o da modificare. Per ora i
/// punti del tratto si inseriscono come coordinate; il disegno sulla mappa
/// previsto da [REQ-FUN-01] arriverà con la mappa.
/// Alla fine si chiude restituendo lo spot salvato, così chi l'ha aperto
/// (es. il modulo della pescata) può usarlo subito.
class ModuloSpotScreen extends ConsumerStatefulWidget {
  const ModuloSpotScreen({super.key, this.spot});

  final Spot? spot;

  @override
  ConsumerState<ModuloSpotScreen> createState() => _ModuloSpotScreenState();
}

class _ModuloSpotScreenState extends ConsumerState<ModuloSpotScreen> {
  final _punto = TextEditingController();
  String? _errorePunto;

  /// Punto riconosciuto nel campo mentre l'utente scrive, prima di aggiungerlo.
  Coordinata? _anteprima;
  bool _salvataggioInCorso = false;

  /// Cambia quando l'utente annulla la scelta di un'altra categoria, per
  /// ridisegnare il menu con la categoria di prima.
  int _versioneCategoria = 0;

  ModuloSpotNotifier get _modulo => ref.read(moduloSpotProvider(widget.spot).notifier);

  @override
  void dispose() {
    _punto.dispose();
    super.dispose();
  }

  /// Aggiunge il punto scritto nel campo. Restituisce `false` (e mostra
  /// l'errore sotto il campo) se il testo non è un punto.
  bool _aggiungiPunto() {
    final ok = _modulo.aggiungiPunto(_punto.text);
    setState(() {
      _errorePunto = ok ? null : 'Punto non riconosciuto: incolla due coordinate.';
      if (ok) _anteprima = null;
    });
    if (ok) _punto.clear();
    return ok;
  }

  /// Se scegliendo [altra] si scarta una categoria nuova non ancora salvata,
  /// chiede conferma.
  Future<bool> _confermaScarto(String altra) async {
    final scartata = _modulo.categoriaScartata(altra);
    if (scartata == null) return true;
    return chiediConferma(
      context,
      titolo: 'Scartare la categoria "$scartata"?',
      messaggio: 'La categoria "$scartata" è nuova: viene creata solo salvando lo spot. '
          'Scegliendone un\'altra viene scartata.',
      conferma: 'Scarta',
    );
  }

  Future<void> _scegliCategoria(String nome) async {
    if (await _confermaScarto(nome)) {
      _modulo.impostaCategoria(nome);
    } else if (mounted) {
      setState(() => _versioneCategoria++);
    }
  }

  Future<void> _nuovaCategoria() async {
    final nome = await chiediNome(context, titolo: 'Nuova categoria', etichetta: 'Nome della categoria');
    if (nome == null || !mounted) return;
    if (!await _confermaScarto(nome)) return;
    final catalogo = ref.read(categorieProvider).value ?? const [];
    _modulo.aggiungiCategoriaNuova(nome, catalogo);
  }

  /// Chiede se collegare al nuovo ambiente le condizioni già usate nelle
  /// pescate dello spot. `null` se l'utente annulla il salvataggio.
  Future<bool?> _chiediCollegamento(List<Condizione> condizioni, String ambiente) {
    final nomi = condizioni.map((c) => c.nome).join(', ');
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Condizioni delle pescate'),
        content: Text(
          'Le pescate di questo spot usano condizioni non previste per l\'ambiente '
          '$ambiente: $nomi.\n\nVuoi collegarle a $ambiente? Così resteranno nel '
          'modulo delle pescate. I valori già salvati restano comunque.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non collegare'),
          ),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Collega')),
        ],
      ),
    );
  }

  Future<void> _salva() async {
    final modulo = ref.read(moduloSpotProvider(widget.spot).notifier);
    final messaggi = ScaffoldMessenger.of(context);
    final navigatore = Navigator.of(context);

    // Un punto scritto nel campo ma non ancora aggiunto viene aggiunto ora,
    // così non si perde.
    if (_punto.text.trim().isNotEmpty && !_aggiungiPunto()) {
      await mostraProblemi(context, [
        'Il testo nel campo "Nuovo punto" non è un punto: correggilo o cancellalo.',
      ]);
      return;
    }

    var collega = const <Condizione>[];
    try {
      final daCollegare = await modulo.condizioniDaCollegare();
      if (daCollegare.isNotEmpty) {
        if (!mounted) return;
        final scelta = await _chiediCollegamento(
          daCollegare,
          ref.read(moduloSpotProvider(widget.spot)).ambiente!,
        );
        if (scelta == null) return;
        if (scelta) collega = daCollegare;
      }
    } catch (e) {
      messaggi..clearSnackBars()..showSnackBar(SnackBar(content: Text('Salvataggio non riuscito: $e')));
      return;
    }

    List<String>? problemi;
    if (!mounted) return;
    setState(() => _salvataggioInCorso = true);
    try {
      final salvato = await modulo.salva(collega: collega);
      messaggi..clearSnackBars()..showSnackBar(const SnackBar(content: Text('Spot salvato')));
      navigatore.pop(salvato);
    } on BozzaNonValida catch (e) {
      problemi = e.problemi;
    } catch (e) {
      messaggi..clearSnackBars()..showSnackBar(SnackBar(content: Text('Salvataggio non riuscito: $e')));
    } finally {
      if (mounted) setState(() => _salvataggioInCorso = false);
    }
    if (problemi != null && mounted) await mostraProblemi(context, problemi);
  }

  Future<void> _elimina() async {
    final modulo = ref.read(moduloSpotProvider(widget.spot).notifier);
    final messaggi = ScaffoldMessenger.of(context);
    final navigatore = Navigator.of(context);
    final conferma = await chiediConferma(
      context,
      titolo: 'Eliminare lo spot?',
      messaggio: 'Lo spot "${widget.spot!.nome}" e i suoi punti verranno eliminati. '
          'Le sue pescate restano nello storico, senza spot. '
          'L\'operazione non si può annullare.',
      conferma: 'Elimina',
    );
    if (!conferma) return;
    try {
      await modulo.elimina();
      messaggi..clearSnackBars()..showSnackBar(const SnackBar(content: Text('Spot eliminato')));
      navigatore.pop();
    } catch (e) {
      messaggi..clearSnackBars()..showSnackBar(SnackBar(content: Text('Eliminazione non riuscita: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = moduloSpotProvider(widget.spot);
    final bozza = ref.watch(provider);
    final modulo = ref.read(provider.notifier);
    final testo = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(bozza.isNuovo ? 'Nuovo spot' : 'Modifica spot')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SizedBox(height: 8),
          TextFormField(
            initialValue: bozza.nome,
            decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.sentences,
            onChanged: modulo.impostaNome,
          ),
          _spazio,
          sezioneAsincrona(ref.watch(categorieProvider), (categorie) => DropdownMenu<String>(
                key: ValueKey('categoria-${bozza.categoriaNome}-$_versioneCategoria'),
                expandedInsets: EdgeInsets.zero,
                label: const Text('Categoria'),
                initialSelection: bozza.categoriaNome,
                dropdownMenuEntries: [
                  if (bozza.nuovaCategoria != null)
                    DropdownMenuEntry(
                      value: bozza.nuovaCategoria!,
                      label: '${bozza.nuovaCategoria} (nuova)',
                    ),
                  for (final c in categorie) DropdownMenuEntry(value: c.nome, label: c.nome),
                ],
                onSelected: (nome) {
                  if (nome != null && nome != bozza.categoriaNome) _scegliCategoria(nome);
                },
              )),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _nuovaCategoria,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuova categoria'),
            ),
          ),
          _spazio,
          sezioneAsincrona(ref.watch(ambientiProvider), (ambienti) => DropdownMenu<String>(
                expandedInsets: EdgeInsets.zero,
                label: const Text('Ambiente'),
                initialSelection: bozza.ambiente,
                dropdownMenuEntries: [
                  for (final a in ambienti) DropdownMenuEntry(value: a.nome, label: a.nome),
                ],
                onSelected: (nome) {
                  if (nome != null) modulo.impostaAmbiente(nome);
                },
              )),
          const _Titolo('Difficoltà'),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final (d, etichetta) in const [
                (Difficolta.bassa, 'Bassa'),
                (Difficolta.media, 'Media'),
                (Difficolta.alta, 'Alta'),
              ])
                ChoiceChip(
                  label: Text(etichetta),
                  selected: bozza.difficolta == d,
                  onSelected: (_) => modulo.impostaDifficolta(d),
                ),
            ],
          ),
          _spazio,
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Accessibile'),
            subtitle: const Text('Spegnilo se al momento lo spot non si raggiunge (frana, lavori…)'),
            value: bozza.accessibilita == Accessibilita.accessibile,
            onChanged: modulo.impostaAccessibile,
          ),
          _spazio,
          TextFormField(
            initialValue: bozza.voto,
            decoration: const InputDecoration(
              labelText: 'Voto (da 0 a 10)',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: modulo.impostaVoto,
          ),
          const _Titolo('Punti del tratto'),
          Text(
            'Incolla le coordinate da Google Maps (tieni premuto sul punto e '
            'copia i numeri, oppure incolla il link completo), poi premi "Aggiungi punto". '
            'Il primo punto è quello usato per il meteo; con due o più punti la lunghezza '
            'si calcola da sola.',
            style: testo.bodySmall,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < bozza.coordinate.length; i++)
            _RigaPunto(
              indice: i,
              punto: bozza.coordinate[i],
              ultimo: i == bozza.coordinate.length - 1,
              sposta: (verso) => modulo.spostaPunto(i, verso),
              rimuovi: () => modulo.rimuoviPunto(i),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _punto,
            decoration: InputDecoration(
              labelText: 'Nuovo punto',
              hintText: '45.7612, 9.6401',
              errorText: _errorePunto,
              errorMaxLines: 2,
              helperText: _anteprima == null
                  ? null
                  : 'Riconosciuto: ${_anteprima!.latitudine.toStringAsFixed(5)}, '
                      '${_anteprima!.longitudine.toStringAsFixed(5)}',
              border: const OutlineInputBorder(),
            ),
            onChanged: (testo) => setState(() {
              _anteprima = leggiCoordinata(testo);
              _errorePunto = null;
            }),
            onSubmitted: (_) => _aggiungiPunto(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _aggiungiPunto,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Aggiungi punto'),
            ),
          ),
          _spazio,
          if (bozza.coordinate.length >= 2)
            Text(
              'Lunghezza calcolata: ${bozza.lunghezzaCalcolata?.round() ?? 0} m',
              style: testo.titleSmall,
            )
          else
            TextFormField(
              initialValue: bozza.lunghezza,
              decoration: const InputDecoration(
                labelText: 'Lunghezza in metri (facoltativa)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: modulo.impostaLunghezza,
            ),
          const _Titolo('Altre informazioni'),
          _CampoTesto('Punti complicati', bozza.noteOstacoli, modulo.impostaNoteOstacoli, righe: 2),
          _CampoTesto('Note', bozza.note, modulo.impostaNote, righe: 3),
          _CampoTesto(
            'Link del parcheggio',
            bozza.linkParcheggio,
            modulo.impostaLinkParcheggio,
            tastiera: TextInputType.url,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _salvataggioInCorso ? null : _salva,
            icon: _salvataggioInCorso
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Salva spot'),
          ),
          if (!bozza.isNuovo) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _salvataggioInCorso ? null : _elimina,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Elimina spot'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Spazio tra un campo e il successivo.
const _spazio = SizedBox(height: 20);

class _Titolo extends StatelessWidget {
  const _Titolo(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 32, bottom: 12),
        child: Text(testo, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _CampoTesto extends StatelessWidget {
  const _CampoTesto(
    this.etichetta,
    this.valore,
    this.cambia, {
    this.righe = 1,
    this.tastiera,
  });

  final String etichetta;
  final String valore;
  final ValueChanged<String> cambia;
  final int righe;
  final TextInputType? tastiera;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: TextFormField(
          initialValue: valore,
          decoration: InputDecoration(labelText: etichetta, border: const OutlineInputBorder()),
          minLines: righe,
          maxLines: righe == 1 ? 1 : righe + 3,
          keyboardType: tastiera,
          textCapitalization:
              tastiera == TextInputType.url ? TextCapitalization.none : TextCapitalization.sentences,
          onChanged: cambia,
        ),
      );
}

class _RigaPunto extends StatelessWidget {
  const _RigaPunto({
    required this.indice,
    required this.punto,
    required this.ultimo,
    required this.sposta,
    required this.rimuovi,
  });

  final int indice;
  final Coordinata punto;
  final bool ultimo;
  final void Function(int verso) sposta;
  final VoidCallback rimuovi;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: CircleAvatar(radius: 14, child: Text('${indice + 1}')),
        title: Text(
          '${punto.latitudine.toStringAsFixed(5)}, ${punto.longitudine.toStringAsFixed(5)}',
        ),
        subtitle: indice == 0 ? const Text('Punto per il meteo') : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Sposta su',
              onPressed: indice == 0 ? null : () => sposta(-1),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: 'Sposta giù',
              onPressed: ultimo ? null : () => sposta(1),
              icon: const Icon(Icons.arrow_downward),
            ),
            IconButton(
              tooltip: 'Togli punto',
              onPressed: rimuovi,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
}
