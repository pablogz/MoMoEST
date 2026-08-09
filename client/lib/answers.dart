import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:momoest/full_screen.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/helpers/answers.dart';
import 'package:momoest/util/helpers/cache.dart';
import 'package:momoest/util/helpers/download_pdf_helper.dart';
import 'package:momoest/util/helpers/feed.dart';
import 'package:momoest/util/helpers/tasks.dart';
import 'package:momoest/util/helpers/user_xest.dart';
import 'package:momoest/util/queries.dart';
import 'package:momoest/l10n/generated/app_localizations.dart';

class InfoAnswers extends StatefulWidget {
  const InfoAnswers({super.key});

  @override
  State<StatefulWidget> createState() => _InfoAnswers();
}

class _InfoAnswers extends State<InfoAnswers> {
  late List<Answer> _answers;
  late Future<List> _futureAnswers;
  bool _loaded = false;

  @override
  void initState() {
    _answers = [];
    _futureAnswers = _getAnswers();
    super.initState();
  }

  Future<List> _getAnswers() async {
    return http.get(Queries.getAnswers(), headers: {
      'Authorization':
          'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
    }).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    return Scaffold(
        body: CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text(appLoca.misRespuestas),
          centerTitle: false,
        ),
        FutureBuilder(
            future: _futureAnswers,
            builder: (context, snapshop) {
              if (!snapshop.hasError && snapshop.hasData) {
                Object? dataServer = snapshop.data;
                if (dataServer != null && dataServer is List) {
                  if (!_loaded) {
                    _answers = [];
                    for (var ele in dataServer) {
                      try {
                        Answer answer = Answer(ele);
                        _answers.add(answer);
                      } catch (error) {
                        if (ConfigXest.development) {
                          debugPrint(error.toString());
                        }
                      }
                    }
                    UserXEST.userXEST.answers = _answers;
                    _loaded = true;
                  }
                  return _widgetAnswers();
                } else {
                  return SliverToBoxAdapter(
                    child: Container(),
                  );
                }
              } else {
                return snapshop.hasError
                    ? SliverToBoxAdapter(
                        child: Container(),
                      )
                    : SliverSafeArea(
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        ),
                      );
              }
            })
      ],
    ));
  }

  Widget _widgetAnswers() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    List<Widget> lista = [];
    for (Answer answer in _answers) {
      lista.add(AnswerCard(
        answer,
        onDelete: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(appLoca.borrarRespuesta),
              content: Text(appLoca.confirmarBorrarRespuesta),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(appLoca.cancelar),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(appLoca.borrar),
                ),
              ],
            ),
          );
          if (confirmed == true && mounted) {
            final token = await FirebaseAuth.instance.currentUser!.getIdToken();
            final response = await http.delete(
              Queries.deleteAnswer(answer.id),
              headers: {'Authorization': 'Bearer $token'},
            );
            if (response.statusCode == 204 && mounted) {
              setState(() {
                _answers.removeWhere((a) => a.id == answer.id);
                UserXEST.userXEST.answers = _answers;
              });
            } else if (mounted && response.statusCode != 204) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error ${response.statusCode}'),
                ),
              );
            }
          }
        },
      ));
    }

    return SliverPadding(
      padding: const EdgeInsets.all(10),
      sliver: SliverList(
        delegate: lista.isNotEmpty
            ? SliverChildBuilderDelegate((context, index) {
                return Center(
                  child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: lista.elementAt(index),
                  ),
                );
              }, childCount: lista.length)
            : SliverChildListDelegate(
                [
                  Text(
                    appLoca.sinRespuestas,
                    textAlign: TextAlign.left,
                  )
                ],
              ),
      ),
    );
  }
}

/// Pantalla de solo lectura con la respuesta guardada de una tarea. Se usa
/// desde la lista de tareas de un lugar cuando la tarea ya está completada.
class AnswerReadOnly extends StatelessWidget {
  final Answer answer;
  const AnswerReadOnly(this.answer, {super.key});

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    double margenLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    return Scaffold(
      appBar: AppBar(
        title: Text(appLoca.tareaCompletada),
        centerTitle: false,
      ),
      body: SafeArea(
        minimum: EdgeInsets.symmetric(horizontal: margenLateral),
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: AnswerCard(answer),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con la información de una respuesta: fecha, lugar, enunciado,
/// contenido según el tipo, canal al que se asoció y realimentación del
/// profesorado. Si [onDelete] es nulo no se muestra el botón de borrado.
class AnswerCard extends StatelessWidget {
  final Answer answer;
  final Future<void> Function()? onDelete;

  const AnswerCard(this.answer, {this.onDelete, super.key});

  /// Recupera la etiqueta del canal al que se asoció la respuesta. Si el canal
  /// no está en la caché local se devuelve su identificador corto.
  String _labelFeed() {
    if (FeedCache.feedsIsNotNull) {
      for (Feed feed in FeedCache.feeds) {
        if (feed.id == answer.idFeed) {
          String label = feed.getALabel();
          if (label.isNotEmpty) {
            return label;
          }
        }
      }
    }
    return Auxiliar.id2shortId(answer.idFeed) ?? answer.idFeed;
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextStyle labelMedium = td.textTheme.labelMedium!
        .copyWith(color: colorScheme.onTertiaryContainer);
    TextStyle titleMedium = td.textTheme.titleMedium!
        .copyWith(color: colorScheme.onTertiaryContainer);
    TextStyle bodyMedium = td.textTheme.bodyMedium!
        .copyWith(color: colorScheme.onTertiaryContainer);

    String? date;
    if (answer.hasAnswer && answer.answer['timestamp'] is int) {
      date = DateFormat('H:mm d/M/y').format(
          DateTime.fromMillisecondsSinceEpoch(answer.answer['timestamp']));
    }
    String? labelPlace = answer.hasLabelContainer ? answer.labelContainer : null;

    List<Widget> children = [
      if (date != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(date, style: labelMedium),
          ),
        ),
      if (labelPlace != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(labelPlace, style: titleMedium),
          ),
        ),
      if (answer.hasCommentTask)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: HtmlWidget(
              answer.commentTask,
              textStyle: bodyMedium,
            ),
          ),
        ),
      AnswerContent(answer),
    ];

    if (answer.hasIdFeed) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.podcasts,
                  size: 18, color: colorScheme.onTertiaryContainer),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  appLoca.respuestaEnCanal(_labelFeed()),
                  style: bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ));
      children.add(Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Align(
          alignment: Alignment.centerLeft,
          child: answer.hasFeedback
              ? Text(
                  '${appLoca.feedback}: ${answer.feedback}',
                  style: bodyMedium.copyWith(fontWeight: FontWeight.bold),
                )
              : Text(
                  appLoca.sinComentariosProfe,
                  style: bodyMedium.copyWith(fontStyle: FontStyle.italic),
                ),
        ),
      ));
    }

    if (onDelete != null) {
      children.add(Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          icon: Icon(Icons.delete_outline,
              color: colorScheme.onTertiaryContainer),
          tooltip: appLoca.borrarRespuesta,
          onPressed: () async => onDelete!(),
        ),
      ));
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.tertiaryContainer),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Contenido de una respuesta según su tipo. Cubre los tipos que se pueden
/// generar de extremo a extremo: texto, verdadero/falso, opción múltiple,
/// subida de fichero, dibujo y fotografía con votación.
class AnswerContent extends StatefulWidget {
  final Answer answer;
  const AnswerContent(this.answer, {super.key});

  @override
  State<StatefulWidget> createState() => _AnswerContent();
}

class _AnswerContent extends State<AnswerContent> {
  Future<void> _downloadFile() async {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    final fileId = widget.answer.answer['file']?.toString() ?? '';
    if (fileId.isEmpty) return;
    final originalName =
        widget.answer.answer['originalName']?.toString() ?? fileId;
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final response = await http.get(
        Queries.downloadAnswerFile(fileId),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await downloadPdf(response.bodyBytes, originalName);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (ConfigXest.development) debugPrint('_downloadFile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appLoca.errorDescargarFichero)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextStyle bodyMediumBold = td.textTheme.bodyMedium!.copyWith(
        color: colorScheme.onTertiaryContainer, fontWeight: FontWeight.bold);
    Answer answer = widget.answer;

    switch (answer.answerType) {
      case AnswerType.text:
        return answer.hasAnswer
            ? Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  answer.answer['answer'],
                  style: bodyMediumBold,
                ),
              )
            : const SizedBox();
      case AnswerType.tf:
        return answer.hasAnswer
            ? Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${answer.answer['answer'] ? appLoca.rbVFVNTVLabel : appLoca.rbVFFNTLabel}${answer.hasExtraText ? "\n${answer.answer['extraText']}" : ""}',
                ),
              )
            : const SizedBox();
      case AnswerType.mcq:
        return answer.hasAnswer
            ? Align(
                alignment: Alignment.centerLeft,
                child: Text(answer.answer['answer'].toString()),
              )
            : const SizedBox();
      case AnswerType.uploadFile:
        return answer.hasAnswer
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      answer.answer['originalName']?.toString() ?? '',
                      style: bodyMediumBold,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.download,
                      color: colorScheme.onTertiaryContainer,
                    ),
                    tooltip: appLoca.descargarPDF,
                    onPressed: _downloadFile,
                  ),
                ],
              )
            : const SizedBox();
      case AnswerType.draw:
        if (!answer.hasAnswer) return const SizedBox();
        final String file = answer.answer['file']?.toString() ?? '';
        if (file.toLowerCase().endsWith('.png')) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthImage(
                Queries.downloadAnswerFile(file),
                fileName: file,
                label: answer.hasLabelContainer ? answer.labelContainer : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(
                    Icons.download,
                    color: colorScheme.onTertiaryContainer,
                  ),
                  tooltip: appLoca.descargar,
                  onPressed: _downloadFile,
                ),
              ),
            ],
          );
        }
        // Dibujo exportado como PDF
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.draw, color: colorScheme.onTertiaryContainer),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                answer.answer['originalName']?.toString() ?? file,
                style: bodyMediumBold,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.download,
                color: colorScheme.onTertiaryContainer,
              ),
              tooltip: appLoca.descargarPDF,
              onPressed: _downloadFile,
            ),
          ],
        );
      case AnswerType.photoVote:
        if (!answer.hasAnswer) return const SizedBox();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthImage(
              Queries.photoVoteFile(
                Auxiliar.id2shortId(answer.idContainer) ?? answer.idContainer,
                answer.answer['file']?.toString() ?? '',
              ),
              fileName: answer.answer['file']?.toString() ?? 'photo.png',
              label: answer.hasLabelContainer ? answer.labelContainer : null,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: PhotoVoteCount(
                shortIdFeature: Auxiliar.id2shortId(answer.idContainer) ??
                    answer.idContainer,
                entryId: answer.answer['entryId']?.toString() ?? '',
              ),
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }
}

/// Imagen que requiere autenticación para su descarga. Muestra una vista
/// previa y permite abrirla a pantalla completa.
class AuthImage extends StatefulWidget {
  final Uri uri;
  final String fileName;
  final String? label;
  final double maxHeight;

  const AuthImage(
    this.uri, {
    required this.fileName,
    this.label,
    this.maxHeight = 220,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _AuthImage();
}

class _AuthImage extends State<AuthImage> {
  late Future<Uint8List?> _futureBytes;

  @override
  void initState() {
    _futureBytes = _fetch();
    super.initState();
  }

  Future<Uint8List?> _fetch() async {
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final response = await http.get(
        widget.uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      return null;
    } catch (error) {
      if (ConfigXest.development) debugPrint(error.toString());
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _futureBytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator.adaptive(),
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Icon(Icons.image_not_supported);
        }
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (BuildContext context) => FullScreenImageBytes(
                  bytes,
                  fileName: widget.fileName,
                  label: widget.label,
                ),
                fullscreenDialog: false,
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }
}

/// Recuento de votos de una entrada de la votación pública de fotografías de
/// un lugar. Consulta el listado público y localiza la entrada por su id.
class PhotoVoteCount extends StatefulWidget {
  final String shortIdFeature;
  final String entryId;
  const PhotoVoteCount(
      {required this.shortIdFeature, required this.entryId, super.key});

  @override
  State<StatefulWidget> createState() => _PhotoVoteCount();
}

class _PhotoVoteCount extends State<PhotoVoteCount> {
  late Future<int?> _futureVotes;

  @override
  void initState() {
    _futureVotes = _fetchVotes();
    super.initState();
  }

  Future<int?> _fetchVotes() async {
    if (widget.entryId.isEmpty) return null;
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final response = await http.get(
        Queries.photoVoteEntries(widget.shortIdFeature),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map && entry['entryId'] == widget.entryId) {
              return entry['votes'] is int ? entry['votes'] : 0;
            }
          }
        }
      }
      return null;
    } catch (error) {
      if (ConfigXest.development) debugPrint(error.toString());
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    return FutureBuilder<int?>(
      future: _futureVotes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final votes = snapshot.data;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.how_to_vote,
                size: 18, color: td.colorScheme.onTertiaryContainer),
            const SizedBox(width: 5),
            Text(
              votes != null
                  ? appLoca.recuentoVotos(votes)
                  : appLoca.votosNoDisponibles,
              style: td.textTheme.bodyMedium!
                  .copyWith(color: td.colorScheme.onTertiaryContainer),
            ),
          ],
        );
      },
    );
  }
}
