import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:momoest/answers.dart' show AuthImage;
import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/helpers/answers.dart';
import 'package:momoest/util/helpers/user_xest.dart';
import 'package:momoest/util/queries.dart';

/// Entrada anónima de la votación pública de fotografías de una tarea
class PhotoVoteEntry {
  final String entryId, file;
  int votes;
  bool votedByMe;
  final bool mine;

  PhotoVoteEntry({
    required this.entryId,
    required this.file,
    required this.votes,
    required this.votedByMe,
    required this.mine,
  });

  factory PhotoVoteEntry.fromMap(Map data) {
    return PhotoVoteEntry(
      entryId: data['entryId'].toString(),
      file: data['file'].toString(),
      votes: data['votes'] is int ? data['votes'] : 0,
      votedByMe: data['votedByMe'] == true,
      mine: data['mine'] == true,
    );
  }
}

/// Vista "votar fotos" de una tarea de fotografía con votación: cuadrícula
/// anónima con las fotografías enviadas y su recuento de votos. Cualquier
/// usuario autenticado puede votar una fotografía por tarea (también la suya)
/// y cambiar su voto. Cada persona puede retirar la fotografía que envió.
class PhotoVoteView extends StatefulWidget {
  final String shortIdFeature;
  final String idTask;
  final String? labelFeature, labelTask;

  const PhotoVoteView(
    this.shortIdFeature, {
    required this.idTask,
    this.labelFeature,
    this.labelTask,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _PhotoVoteView();
}

class _PhotoVoteView extends State<PhotoVoteView> {
  List<PhotoVoteEntry>? _entries;
  bool _busy = false;

  @override
  void initState() {
    _load();
    super.initState();
  }

  /// Recarga las fotografías de la tarea. Con [silent] se mantiene en pantalla
  /// lo que ya se está mostrando mientras llega la respuesta.
  Future<void> _load({bool silent = false}) async {
    if (!silent && _entries != null) {
      setState(() => _entries = null);
    }
    final List<PhotoVoteEntry> entries = await _getEntries();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<List<PhotoVoteEntry>> _getEntries() async {
    final List<PhotoVoteEntry> entries = [];
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final response = await http.get(
        Queries.photoVoteEntries(widget.shortIdFeature, idTask: widget.idTask),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is List) {
          for (var ele in data) {
            if (ele is Map) {
              try {
                entries.add(PhotoVoteEntry.fromMap(ele));
              } catch (error) {
                if (ConfigXest.development) debugPrint(error.toString());
              }
            }
          }
        }
      }
    } catch (error) {
      if (ConfigXest.development) debugPrint(error.toString());
    }
    return entries;
  }

  Future<void> _vote(PhotoVoteEntry entry, bool vote) async {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final response = await http.put(
        Queries.photoVoteVote(widget.shortIdFeature, entry.entryId),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'vote': vote}),
      );
      if (response.statusCode == 204 && mounted) {
        setState(() {
          if (vote) {
            // Un único voto por tarea: retiro el anterior en local
            for (PhotoVoteEntry e in _entries ?? []) {
              if (e.votedByMe) {
                e.votedByMe = false;
                e.votes = e.votes > 0 ? e.votes - 1 : 0;
              }
            }
            entry.votedByMe = true;
            entry.votes += 1;
          } else {
            entry.votedByMe = false;
            entry.votes = entry.votes > 0 ? entry.votes - 1 : 0;
          }
        });
      } else if (mounted) {
        smState.clearSnackBars();
        smState.showSnackBar(SnackBar(content: Text(appLoca.errorVotar)));
      }
    } catch (error) {
      if (ConfigXest.development) debugPrint(error.toString());
      smState.clearSnackBars();
      smState.showSnackBar(SnackBar(content: Text(appLoca.errorVotar)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Retira del servidor la fotografía propia. El borrado es simétrico: la foto
  /// desaparece de la votación con todos sus votos y la respuesta a la tarea
  /// deja de mostrarse en "Mis respuestas".
  Future<void> _delete(PhotoVoteEntry entry) async {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    final bool? confirmed = await Auxiliar.deleteDialog(
        context, appLoca.borrarFoto, appLoca.confirmarBorrarFoto);
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final response = await http.delete(
        Queries.photoVoteEntry(widget.shortIdFeature, entry.entryId),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      // Un 404 significa que la fotografía ya no está en la votación, así que
      // para quien borra el resultado es el mismo que un borrado correcto
      if (response.statusCode == 204 || response.statusCode == 404) {
        setState(() => _entries?.removeWhere((e) => e.entryId == entry.entryId));
        // El servidor oculta la respuesta enlazada, así que se quita también de
        // la copia en memoria: la tarea vuelve a aparecer como pendiente y deja
        // de ofrecer una respuesta cuya fotografía ya no existe. Se compara
        // también por el fichero, porque una respuesta recién creada en el
        // cliente puede no tener todavía el identificador de la entrada.
        UserXEST.userXEST.answers.removeWhere((Answer a) =>
            a.hasAnswer &&
            (a.answer['entryId']?.toString() == entry.entryId ||
                a.answer['file']?.toString() == entry.file));
        smState.clearSnackBars();
        smState.showSnackBar(SnackBar(content: Text(appLoca.fotoBorrada)));
      } else {
        if (ConfigXest.development) {
          debugPrint('photoVote delete: ${response.statusCode}');
        }
        smState.clearSnackBars();
        smState.showSnackBar(SnackBar(content: Text(appLoca.errorBorrarFoto)));
      }
      // En los dos casos se recarga: la pantalla debe enseñar lo que hay en el
      // servidor, no lo que creemos que ha pasado
      await _load(silent: true);
    } catch (error) {
      if (ConfigXest.development) debugPrint(error.toString());
      smState.clearSnackBars();
      smState.showSnackBar(SnackBar(content: Text(appLoca.errorBorrarFoto)));
      await _load(silent: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    final String? subtitle = widget.labelTask ?? widget.labelFeature;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              subtitle != null
                  ? '${appLoca.votarFotos} · $subtitle'
                  : appLoca.votarFotos,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            centerTitle: false,
            pinned: true,
          ),
          SliverSafeArea(
            minimum: const EdgeInsets.all(10),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Text(
                    appLoca.votarFotosExplica,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
          if (_entries == null)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
            )
          else
            _widgetGrid(_entries!),
        ],
      ),
    );
  }

  Widget _widgetGrid(List<PhotoVoteEntry> entries) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    if (entries.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Center(child: Text(appLoca.sinFotosVotacion)),
        ),
      );
    }
    ThemeData td = Theme.of(context);
    return SliverPadding(
      padding: const EdgeInsets.all(10),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.68,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) =>
            _widgetEntry(entries.elementAt(index), td, appLoca),
      ),
    );
  }

  Widget _widgetEntry(
      PhotoVoteEntry entry, ThemeData td, AppLocalizations appLoca) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color:
              entry.votedByMe ? td.colorScheme.primary : td.colorScheme.outline,
          width: entry.votedByMe ? 2 : 1,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AuthImage(
                    Queries.photoVoteFile(widget.shortIdFeature, entry.file),
                    fileName: entry.file,
                    maxHeight: double.infinity,
                  ),
                ),
                // La autoría no se muestra a nadie más: solo quien la envió ve
                // marcada su propia fotografía
                if (entry.mine)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Chip(
                      label: Text(appLoca.tuFoto,
                          style: td.textTheme.labelSmall),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.how_to_vote, size: 18),
                    const SizedBox(width: 4),
                    Text(appLoca.recuentoVotos(entry.votes),
                        style: td.textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      // Se puede votar cualquier fotografía, incluida la propia
                      child: entry.votedByMe
                          ? OutlinedButton.icon(
                              onPressed:
                                  _busy ? null : () async => _vote(entry, false),
                              icon: const Icon(Icons.how_to_vote, size: 18),
                              label: Text(appLoca.quitarVoto,
                                  overflow: TextOverflow.ellipsis),
                            )
                          : FilledButton.tonalIcon(
                              onPressed:
                                  _busy ? null : () async => _vote(entry, true),
                              icon: const Icon(Icons.how_to_vote, size: 18),
                              label: Text(appLoca.votar,
                                  overflow: TextOverflow.ellipsis),
                            ),
                    ),
                    if (entry.mine)
                      IconButton(
                        onPressed: _busy ? null : () async => _delete(entry),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: appLoca.borrarFoto,
                        color: td.colorScheme.error,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
