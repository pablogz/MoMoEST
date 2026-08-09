import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:momoest/answers.dart' show AuthImage;
import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/queries.dart';

/// Entrada anónima de la votación pública de fotografías de un lugar
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

/// Vista "votar fotos" de un lugar: cuadrícula anónima con las fotografías
/// enviadas y su recuento de votos. Cualquier usuario autenticado puede votar
/// una fotografía por lugar y cambiar su voto.
class PhotoVoteView extends StatefulWidget {
  final String shortIdFeature;
  final String? labelFeature;

  const PhotoVoteView(this.shortIdFeature, {this.labelFeature, super.key});

  @override
  State<StatefulWidget> createState() => _PhotoVoteView();
}

class _PhotoVoteView extends State<PhotoVoteView> {
  List<PhotoVoteEntry> _entries = [];
  late Future<List> _futureEntries;
  bool _loaded = false;
  bool _voting = false;

  @override
  void initState() {
    _futureEntries = _getEntries();
    super.initState();
  }

  Future<List> _getEntries() async {
    return http.get(Queries.photoVoteEntries(widget.shortIdFeature), headers: {
      'Authorization':
          'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
    }).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Future<void> _vote(PhotoVoteEntry entry, bool vote) async {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    setState(() => _voting = true);
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
            // Un único voto por lugar: retiro el anterior en local
            for (PhotoVoteEntry e in _entries) {
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
      if (mounted) setState(() => _voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              widget.labelFeature != null
                  ? '${appLoca.votarFotos} · ${widget.labelFeature}'
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
          FutureBuilder(
            future: _futureEntries,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(appLoca.sinFotosVotacion),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                );
              }
              Object? data = snapshot.data;
              if (data is List && !_loaded) {
                _entries = [];
                for (var ele in data) {
                  if (ele is Map) {
                    try {
                      _entries.add(PhotoVoteEntry.fromMap(ele));
                    } catch (error) {
                      if (ConfigXest.development) {
                        debugPrint(error.toString());
                      }
                    }
                  }
                }
                _loaded = true;
              }
              return _widgetGrid();
            },
          ),
        ],
      ),
    );
  }

  Widget _widgetGrid() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    if (_entries.isEmpty) {
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
          childAspectRatio: 0.78,
        ),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          PhotoVoteEntry entry = _entries.elementAt(index);
          return Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: entry.votedByMe
                    ? td.colorScheme.primary
                    : td.colorScheme.outline,
                width: entry.votedByMe ? 2 : 1,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AuthImage(
                    Queries.photoVoteFile(widget.shortIdFeature, entry.file),
                    fileName: entry.file,
                    maxHeight: double.infinity,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      entry.mine
                          ? Text(appLoca.tuFoto,
                              style: td.textTheme.labelMedium!
                                  .copyWith(color: td.colorScheme.primary))
                          : TextButton(
                              onPressed: _voting
                                  ? null
                                  : () async =>
                                      _vote(entry, !entry.votedByMe),
                              child: Text(entry.votedByMe
                                  ? appLoca.quitarVoto
                                  : appLoca.votar),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
