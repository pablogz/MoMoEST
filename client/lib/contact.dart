import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/l10n/generated/app_localizations.dart';

class Contact extends StatefulWidget {
  const Contact({super.key});

  @override
  State<Contact> createState() => _Contact();
}

class _Contact extends State<Contact> {
  late String _email, _problem, _description;
  late GlobalKey<FormState> _gkForm;
  late bool _btEnable;

  @override
  void initState() {
    _email = "";
    _problem = "";
    _description = "";
    _gkForm = GlobalKey<FormState>();
    _btEnable = true;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    double mLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          title: Text(appLoca.politicaContactoTitulo),
          centerTitle: false,
          pinned: true,
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: mLateral,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                alignment: Alignment.centerLeft,
                child: Text(appLoca.datosNosotrosTitulo,
                    textAlign: TextAlign.start, style: textTheme.titleLarge),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: mLateral,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(appLoca.datosNosotros,
                      textAlign: TextAlign.start, style: textTheme.bodyMedium),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: mLateral,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Text(appLoca.formularioContactoTitulo,
                      textAlign: TextAlign.start, style: textTheme.titleLarge),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: mLateral,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(appLoca.formularioContacto,
                      textAlign: TextAlign.start, style: textTheme.bodyMedium),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: mLateral,
            vertical: 20,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                alignment: Alignment.centerLeft,
                child: Form(
                  key: _gkForm,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextFormField(
                          maxLines: 1,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: appLoca.emailContacto,
                            hintText: appLoca.emailContacto,
                            helperText: appLoca.requerido,
                            hintMaxLines: 1,
                            hintStyle: const TextStyle(
                                overflow: TextOverflow.ellipsis),
                          ),
                          textCapitalization: TextCapitalization.none,
                          keyboardType: TextInputType.emailAddress,
                          enabled: _btEnable,
                          initialValue: _email,
                          maxLength: 80,
                          onChanged: (String value) =>
                              setState(() => _email = value),
                          validator: (value) => value == null ||
                                  value.length > 80 ||
                                  value.trim().isEmpty ||
                                  !Auxiliar.validMail(value.trim())
                              ? appLoca.emailContactoError
                              : null,
                          autovalidateMode: AutovalidateMode.onUnfocus,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextFormField(
                          maxLines: 1,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: appLoca.problemaContacto,
                            hintText: appLoca.problemaContacto,
                            helperText: appLoca.requerido,
                            hintMaxLines: 1,
                            hintStyle: const TextStyle(
                                overflow: TextOverflow.ellipsis),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.text,
                          enabled: _btEnable,
                          initialValue: _problem,
                          maxLength: 120,
                          onChanged: (String value) =>
                              setState(() => _problem = value),
                          validator: (value) {
                            if (value == null ||
                                value.length > 120 ||
                                value.trim().isEmpty) {
                              return appLoca.problemaContacto;
                            } else {
                              return null;
                            }
                          },
                          autovalidateMode: AutovalidateMode.onUnfocus,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextFormField(
                          minLines: 5,
                          maxLines: 5,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: appLoca.descripContacto,
                            hintText: appLoca.descripContacto,
                            helperText: appLoca.requerido,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.text,
                          enabled: _btEnable,
                          initialValue: _description,
                          maxLength: 600,
                          onChanged: (String value) =>
                              setState(() => _description = value),
                          validator: (value) {
                            if (value == null ||
                                value.length > 600 ||
                                value.trim().isEmpty) {
                              return appLoca.descripContacto;
                            } else {
                              return null;
                            }
                          },
                          autovalidateMode: AutovalidateMode.onUnfocus,
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                      Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                              onPressed: _email.isNotEmpty &&
                                      _problem.isNotEmpty &&
                                      _description.isNotEmpty &&
                                      _btEnable
                                  ? () async {
                                      if (_gkForm.currentState!.validate()) {
                                        try {
                                          _btEnable = false;
                                          Uri uri = Uri(
                                            scheme: 'mailto',
                                            path: ConfigXest.correoSoporte,
                                            query: Auxiliar
                                                .encodeQueryParameters(<String,
                                                    String>{
                                              'subject': _problem,
                                              'body': '$_email\n\n$_description'
                                            }),
                                          );
                                          bool c = await launchUrl(uri);
                                          if (!c) {
                                            sMState.clearSnackBars();
                                            sMState.showSnackBar(
                                              SnackBar(
                                                backgroundColor:
                                                    colorScheme.errorContainer,
                                                content: Text(
                                                  appLoca.errorContacto,
                                                  style: textTheme.bodyMedium!
                                                      .copyWith(
                                                          color: colorScheme
                                                              .onErrorContainer),
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (error, stackTrace) {
                                          if (ConfigXest.development) {
                                            debugPrint(stackTrace.toString());
                                          } else {
                                            FirebaseCrashlytics.instance
                                                .recordError(error, stackTrace);
                                          }
                                          sMState.clearSnackBars();
                                          sMState.showSnackBar(
                                            SnackBar(
                                              backgroundColor:
                                                  colorScheme.errorContainer,
                                              content: Text(
                                                appLoca.errorContacto,
                                                style: textTheme.bodyMedium!
                                                    .copyWith(
                                                        color: colorScheme
                                                            .onErrorContainer),
                                              ),
                                            ),
                                          );
                                        } finally {
                                          _btEnable = true;
                                        }
                                      }
                                    }
                                  : null,
                              child: Text(appLoca.enviarPregunta)))
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
      ]),
    );
  }
}
