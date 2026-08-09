import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';

/// Temas sobre los que se puede opinar
enum OpinionTopic { general, lugares, itinerarios, tareas, notas, canales, otro }

/// Formulario para enviar una opinión sobre la aplicación. No guarda nada en el
/// servidor: prepara el mensaje y lo abre en el gestor de correo de la persona,
/// que decide qué envía y desde qué dirección.
class Opinion extends StatefulWidget {
  const Opinion({super.key});

  @override
  State<Opinion> createState() => _Opinion();
}

class _Opinion extends State<Opinion> {
  int _rating = 0;
  OpinionTopic _topic = OpinionTopic.general;
  String _comment = '';
  bool _sending = false;

  String _labelTopic(AppLocalizations appLoca, OpinionTopic topic) {
    switch (topic) {
      case OpinionTopic.general:
        return appLoca.opinionTemaGeneral;
      case OpinionTopic.lugares:
        return appLoca.opinionTemaLugares;
      case OpinionTopic.itinerarios:
        return appLoca.opinionTemaItinerarios;
      case OpinionTopic.tareas:
        return appLoca.opinionTemaTareas;
      case OpinionTopic.notas:
        return appLoca.opinionTemaNotas;
      case OpinionTopic.canales:
        return appLoca.opinionTemaCanales;
      case OpinionTopic.otro:
        return appLoca.opinionTemaOtro;
    }
  }

  /// Plataforma en la que se está usando la aplicación, para interpretar mejor
  /// el comentario. No identifica ni al dispositivo ni a la persona.
  String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// Cuerpo del correo: la valoración, el comentario y los datos técnicos
  String _body(AppLocalizations appLoca) {
    final StringBuffer body = StringBuffer();
    if (_rating > 0) {
      body.writeln('${appLoca.opinionValoracion} '
          '${appLoca.opinionEstrellas(_rating)}');
      body.writeln();
    }
    body.writeln(_comment.trim());
    body.writeln();
    body.writeln('---');
    body.writeln('${ConfigXest.nameApp} ${ConfigXest.version} · $_platform · '
        '${appLoca.localeName}');
    return body.toString();
  }

  Future<void> _send(AppLocalizations appLoca) async {
    ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
    ThemeData td = Theme.of(context);
    setState(() => _sending = true);
    try {
      final Uri uri = Uri(
        scheme: 'mailto',
        path: ConfigXest.correoSoporte,
        query: Auxiliar.encodeQueryParameters(<String, String>{
          'subject': '[${ConfigXest.nameApp}] ${appLoca.opinionTitulo} · '
              '${_labelTopic(appLoca, _topic)}',
          'body': _body(appLoca),
        }),
      );
      final bool opened = await launchUrl(uri);
      if (!opened) {
        _errorMail(sMState, td, appLoca);
      }
    } catch (error, stackTrace) {
      if (ConfigXest.development) {
        debugPrint(stackTrace.toString());
      } else {
        FirebaseCrashlytics.instance.recordError(error, stackTrace);
      }
      _errorMail(sMState, td, appLoca);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Si no hay gestor de correo se ofrece copiar la dirección
  void _errorMail(ScaffoldMessengerState sMState, ThemeData td,
      AppLocalizations appLoca) {
    sMState.clearSnackBars();
    sMState.showSnackBar(
      SnackBar(
        backgroundColor: td.colorScheme.errorContainer,
        duration: const Duration(seconds: 10),
        content: Text(
          appLoca.errorOpinion(ConfigXest.correoSoporte),
          style: td.textTheme.bodyMedium!
              .copyWith(color: td.colorScheme.onErrorContainer),
        ),
        action: SnackBarAction(
          label: appLoca.copiarCorreo,
          onPressed: () async {
            await Clipboard.setData(
                const ClipboardData(text: ConfigXest.correoSoporte));
            sMState.clearSnackBars();
            sMState.showSnackBar(
              SnackBar(content: Text(appLoca.correoCopiado)),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    double mLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(appLoca.opinionTitulo),
            centerTitle: false,
            pinned: true,
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: mLateral, vertical: 10),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(appLoca.opinionIntro, style: textTheme.bodyMedium),
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 5),
                        child: Text(appLoca.opinionValoracion,
                            style: textTheme.titleSmall),
                      ),
                      _widgetRating(td, appLoca),
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 5),
                        child: Text(appLoca.opinionTema,
                            style: textTheme.titleSmall),
                      ),
                      DropdownButtonFormField<OpinionTopic>(
                        initialValue: _topic,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: OpinionTopic.values
                            .map((OpinionTopic topic) => DropdownMenuItem(
                                  value: topic,
                                  child: Text(_labelTopic(appLoca, topic)),
                                ))
                            .toList(),
                        onChanged: _sending
                            ? null
                            : (OpinionTopic? value) {
                                if (value != null) {
                                  setState(() => _topic = value);
                                }
                              },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: TextFormField(
                          minLines: 5,
                          maxLines: 8,
                          maxLength: 1000,
                          enabled: !_sending,
                          initialValue: _comment,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: appLoca.opinionComentario,
                            hintText: appLoca.opinionComentario,
                            helperText: appLoca.requerido,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          onChanged: (String value) =>
                              setState(() => _comment = value),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5, bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Icon(Icons.info_outline,
                                  size: 18, color: td.colorScheme.outline),
                            ),
                            Expanded(
                              child: Text(
                                appLoca.opinionDatosTecnicos,
                                style: textTheme.bodySmall!
                                    .copyWith(color: td.colorScheme.outline),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _comment.trim().isEmpty || _sending
                              ? null
                              : () async => _send(appLoca),
                          icon: const Icon(Icons.send),
                          label: Text(appLoca.opinionEnviar),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _widgetRating(ThemeData td, AppLocalizations appLoca) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int index) {
        final int value = index + 1;
        return IconButton(
          onPressed:
              _sending ? null : () => setState(() => _rating = value),
          tooltip: appLoca.opinionEstrellas(value),
          icon: Icon(
            value <= _rating ? Icons.star : Icons.star_border,
            color: td.colorScheme.primary,
          ),
        );
      }),
    );
  }
}
