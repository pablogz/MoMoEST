import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/helpers/answers.dart';
import 'package:momoest/util/helpers/download_pdf_helper.dart';
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

  @override
  void initState() {
    _answers = [];
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
            future: _getAnswers(),
            builder: (context, snapshop) {
              if (!snapshop.hasError && snapshop.hasData) {
                Object? dataServer = snapshop.data;
                if (dataServer != null && dataServer is List) {
                  _answers = [];
                  for (var ele in dataServer) {
                    try {
                      Answer answer = Answer(ele);
                      _answers.add(answer);
                    } catch (error) {
                      if (ConfigXest.development) debugPrint(error.toString());
                    }
                  }
                  UserXEST.userXEST.answers = _answers;
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

  Future<void> _downloadPdf(Answer answer) async {
    final fileId = answer.answer['file']?.toString() ?? '';
    if (fileId.isEmpty) return;
    final originalName =
        answer.answer['originalName']?.toString() ?? 'file.pdf';
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
      if (ConfigXest.development) debugPrint('_downloadPdf: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al descargar el fichero')),
        );
      }
    }
  }

  Widget _widgetAnswers() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    List<Widget> lista = [];
    ThemeData td = Theme.of(context);
    for (Answer answer in UserXEST.userXEST.answers) {
      String? date;
      if (answer.hasAnswer) {
        date = DateFormat('H:mm d/M/y').format(
            DateTime.fromMillisecondsSinceEpoch(answer.answer['timestamp']));
      }

      String? labelPlace =
          answer.hasLabelContainer ? answer.labelContainer : null;

      ColorScheme colorScheme = td.colorScheme;
      TextStyle labelMedium = td.textTheme.labelMedium!
          .copyWith(color: colorScheme.onTertiaryContainer);
      TextStyle titleMedium = td.textTheme.titleMedium!
          .copyWith(color: colorScheme.onTertiaryContainer);
      TextStyle bodyMedium = td.textTheme.bodyMedium!
          .copyWith(color: colorScheme.onTertiaryContainer);
      TextStyle bodyMediumBold = td.textTheme.bodyMedium!.copyWith(
          color: colorScheme.onTertiaryContainer, fontWeight: FontWeight.bold);

      Widget respuesta;
      switch (answer.answerType) {
        case AnswerType.text:
          respuesta = answer.hasAnswer
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    answer.answer['answer'],
                    style: bodyMediumBold,
                  ),
                )
              : const SizedBox();
          break;
        case AnswerType.tf:
          respuesta = answer.hasAnswer
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${answer.answer['answer'] ? appLoca.rbVFVNTVLabel : appLoca.rbVFFNTLabel}${answer.hasExtraText ? "\n${answer.answer['extraText']}" : ""}',
                  ),
                )
              : const SizedBox();
          break;
        case AnswerType.mcq:
          respuesta = answer.hasAnswer
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(answer.answer['answer'].toString()),
                )
              : const SizedBox();
          break;
        case AnswerType.uploadFile:
          respuesta = answer.hasAnswer
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
                      onPressed: () => _downloadPdf(answer),
                    ),
                  ],
                )
              : const SizedBox();
          break;
        default:
          respuesta = const SizedBox();
      }
      lista.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: colorScheme.tertiaryContainer),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            date != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        date,
                        style: labelMedium,
                      ),
                    ),
                  )
                : Container(),
            labelPlace != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(labelPlace, style: titleMedium),
                    ),
                  )
                : Container(),
            answer.hasCommentTask
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: HtmlWidget(
                        answer.commentTask,
                        textStyle: bodyMedium,
                      ),
                    ),
                  )
                : Container(),
            respuesta,
          ],
        ),
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
