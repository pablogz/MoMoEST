import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:momoest/main.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/l10n/generated/app_localizations.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPage();
}

class _LandingPage extends State<LandingPage> {
  bool buscandoUbicion = false;

  @override
  Widget build(BuildContext context) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    Size size = MediaQuery.of(context).size;
    double widthContainer = min(size.width, Auxiliar.maxWidth);
    ScaffoldMessengerState sms = ScaffoldMessenger.of(context);
    List<Widget> contenidoLandingPage = [
      queEsChest(textTheme, colorScheme, appLoca, widthContainer),
      datosQueUsamos(textTheme, colorScheme, appLoca, widthContainer),
      quienesSomos(textTheme, colorScheme, appLoca, widthContainer),
    ];

    double desplazaAppBar = size.height * 0.35;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              primary: false,
              centerTitle: true,
              leadingWidth: 80,
              expandedHeight: max(152, desplazaAppBar),
              automaticallyImplyLeading: false,
              leading: Padding(
                padding: const EdgeInsets.only(
                  top: 5,
                  bottom: 5,
                  left: 16,
                  right: 16,
                ),
                child: SvgPicture.asset(
                  'images/logo.svg',
                  width: 48,
                  semanticsLabel: appLoca!.xest,
                ),
              ),
              title: Center(
                child: SearchAnchor.bar(
                  constraints: const BoxConstraints(
                      maxWidth: Auxiliar.maxWidth, minHeight: 56),
                  suggestionsBuilder: (context, controller) =>
                      Auxiliar.recuperaSugerencias(context, controller),
                  barHintText: appLoca.dondeQuiresEmpezar,
                  barTrailing: [
                    buscandoUbicion
                        ? const CircularProgressIndicator.adaptive()
                        : IconButton(
                            tooltip: appLoca.startInMyLocation,
                            icon: const Icon(Icons.my_location),
                            onPressed: () async {
                              if (!MyApp.locationUser.hasPermissions) {
                                bool hasPermissions = await MyApp.locationUser
                                    .checkPermissions(context);
                                if (hasPermissions) {
                                  Position? p = await MyApp
                                      .locationUser.currentLocationUser;
                                  setState(() => buscandoUbicion = false);
                                  if (p is Position) {
                                    if (mounted) {
                                      GoRouter.of(context).go(
                                          '/home?center=${p.latitude},${p.longitude}&zoom=15');
                                    }
                                  }
                                }
                              } else {
                                Position? p = await MyApp
                                    .locationUser.currentLocationUser;
                                setState(() => buscandoUbicion = false);
                                if (p is Position) {
                                  if (mounted) {
                                    GoRouter.of(context).go(
                                        '/home?center=${p.latitude},${p.longitude}&zoom=15');
                                  }
                                }
                              }
                            },
                          )
                  ],
                  // isFullScreen: false,
                ),
              ),
              actions: kIsWeb
                  ? [
                      IconButton(
                        onPressed: () async {
                          try {
                            if (!await launchUrl(Uri.parse(
                                "https://play.google.com/store/apps/details?id=es.uva.gsic.chest"))) {
                              throw Exception();
                            }
                          } catch (error) {
                            sms.clearSnackBars();
                            sms.showSnackBar(
                              SnackBar(
                                backgroundColor: colorScheme.error,
                                content: Text("Error",
                                    style: textTheme.bodyMedium!
                                        .copyWith(color: colorScheme.onError)),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.android),
                      ),
                      IconButton(
                        onPressed: () async {
                          try {
                            if (!await launchUrl(Uri.parse(
                                "https://apps.apple.com/us/app/chest-gsic/id6654914759"))) {
                              throw Exception();
                            }
                          } catch (error) {
                            sms.clearSnackBars();
                            sms.showSnackBar(
                              SnackBar(
                                backgroundColor: colorScheme.error,
                                content: Text("Error",
                                    style: textTheme.bodyMedium!
                                        .copyWith(color: colorScheme.onError)),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.apple),
                      ),
                    ]
                  : null,
            ),
            SliverList.builder(
              itemBuilder: (context, index) => Center(
                child: Container(
                  margin: index == 0
                      ? EdgeInsets.only(
                          top: desplazaAppBar / 2,
                          bottom: 40,
                          left: 20,
                          right: 20,
                        )
                      : const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 40,
                        ),
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: index.isOdd
                        ? colorScheme.secondaryContainer
                        : colorScheme.primaryContainer,
                  ),
                  child: contenidoLandingPage.elementAt(index),
                ),
              ),
              itemCount: contenidoLandingPage.length,
            ),
            descargaChest(textTheme, colorScheme, appLoca, widthContainer),
          ],
        ),
      ),
    );
  }

  Widget queEsChest(
    TextTheme textTheme,
    ColorScheme colorScheme,
    AppLocalizations? appLoca,
    double widthContainer,
  ) {
    double dosColum = (widthContainer / 2) - 45;
    bool ancho = widthContainer < Auxiliar.maxWidth;
    Color colorBackground = colorScheme.primary;
    Color colorText = colorScheme.onPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 40, top: 20),
          child: Text(
            appLoca!.lpPreguntaxest,
            style: textTheme.headlineSmall!.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.start,
          runAlignment: WrapAlignment.center,
          direction: Axis.horizontal,
          children: [
            _columnCard(
              textTheme,
              appLoca.lpxestEs,
              title: appLoca.lpxestEsTitle,
              width: widthContainer,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpNavegaMapa,
              title: appLoca.lpNavegaMapaTitle,
              width: ancho ? widthContainer : dosColum,
              image: 'images/landing/marcadores.png',
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpRealizaTareas,
              title: appLoca.lpRealizaTareasTitle,
              width: ancho ? widthContainer : (widthContainer / 2) - 45,
              image: 'images/landing/tareasDescripcion.png',
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpCreaTareas,
              title: appLoca.lpCreaTareasTitle,
              width: ancho ? widthContainer : dosColum,
              image: 'images/landing/creaTarea.png',
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpCreaItinerarios,
              title: appLoca.lpCreaItinerariosTitle,
              width: ancho ? widthContainer : dosColum,
              image: 'images/landing/itinerarios.png',
              colorBackground: colorBackground,
              colorText: colorText,
            ),
          ],
        ),
      ],
    );
  }

  Widget datosQueUsamos(
    TextTheme textTheme,
    ColorScheme colorScheme,
    AppLocalizations? appLoca,
    double widthContainer,
  ) {
    double dosColum = (widthContainer / 2) - 45;
    bool ancho = widthContainer < Auxiliar.maxWidth;
    Color colorBackground = colorScheme.secondary;
    Color colorText = colorScheme.onSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 40, top: 20),
          child: Text(
            appLoca!.lpQueDatosUsamos,
            style: textTheme.headlineSmall!.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.start,
          runAlignment: WrapAlignment.center,
          direction: Axis.horizontal,
          children: [
            _columnCard(
              textTheme,
              appLoca.lpQueEsLOD,
              title: appLoca.lpQueEsLODTitle,
              colorBackground: colorBackground,
              colorText: colorText,
              width: ancho ? widthContainer : dosColum,
            ),
            _columnCard(
              textTheme,
              appLoca.lpDatosPrivados,
              title: appLoca.lpDatosPrivadosTitle,
              colorBackground: colorBackground,
              colorText: colorText,
              width: ancho ? widthContainer : dosColum,
            ),
          ],
        ),
      ],
    );
  }

  Widget quienesSomos(TextTheme textTheme, ColorScheme colorScheme,
      AppLocalizations? appLoca, double widthContainer) {
    double tresColum = (widthContainer / 3) - 45;
    double dosColum = (widthContainer / 2) - 45;
    bool ancho = tresColum * 3 < 599;
    Color colorBackground = colorScheme.primary;
    Color colorText = colorScheme.onPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 40, top: 20),
          child: Text(
            appLoca!.lpQuienesSomos,
            style: textTheme.headlineSmall!.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.spaceEvenly,
          crossAxisAlignment: WrapCrossAlignment.start,
          runAlignment: WrapAlignment.center,
          direction: Axis.horizontal,
          children: [
            _columnCard(
              textTheme,
              appLoca.lpGSIC,
              title: appLoca.lpGSICTitle,
              width: widthContainer,
              image: 'images/landing/gsic.png',
              heightImg: 180,
              fitImage: BoxFit.fitWidth,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpBecaUVaSantander,
              title: appLoca.lpBecaUVaSantanderTitle,
              width: ancho ? widthContainer : dosColum,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
            _columnCard(
              textTheme,
              appLoca.lpGenieLearn,
              title: appLoca.lpGenieLearnTitle,
              width: ancho ? widthContainer : dosColum,
              colorBackground: colorBackground,
              colorText: colorText,
            ),
          ],
        ),
      ],
    );
  }

  Widget descargaChest(TextTheme textTheme, ColorScheme colorScheme,
      AppLocalizations? appLoca, double widthContainer) {
    ScaffoldMessengerState sms = ScaffoldMessenger.of(context);
    return SliverList.builder(
      itemBuilder: (context, index) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: colorScheme.tertiaryContainer,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RichText(
                    text: TextSpan(
                      text: appLoca!.descargaxest.replaceFirst(
                          appLoca.descargaxest.split(', ').last, ''),
                      style: textTheme.titleLarge!.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                      children: [
                        TextSpan(
                          text: appLoca.descargaxest.split(', ').last,
                          style: textTheme.titleLarge!.copyWith(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.spaceAround,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runAlignment: WrapAlignment.spaceAround,
                  runSpacing: 10,
                  spacing: 20,
                  children: [
                    InkWell(
                      onTap: () async {
                        try {
                          if (!await launchUrl(Uri.parse(
                              "https://play.google.com/store/apps/details?id=es.uva.gsic.chest"))) {
                            throw Exception();
                          }
                        } catch (error) {
                          sms.clearSnackBars();
                          sms.showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Error",
                              ),
                            ),
                          );
                        }
                      },
                      child: Tooltip(
                        message: appLoca.descargaxestAndroid,
                        child: SvgPicture.asset(
                          'images/landing/badges/google-play-badge-${MyApp.currentLang == 'es' ? 'es' : MyApp.currentLang == 'pt' ? 'pt' : 'en'}.svg',
                          width: 200,
                          semanticsLabel: appLoca.descargaxestAndroid,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        try {
                          if (!await launchUrl(Uri.parse(
                              "https://apps.apple.com/us/app/chest-gsic/id6654914759"))) {
                            throw Exception();
                          }
                        } catch (error) {
                          sms.clearSnackBars();
                          sms.showSnackBar(
                            SnackBar(
                              backgroundColor: colorScheme.error,
                              content: Text("Error",
                                  style: textTheme.bodyMedium!
                                      .copyWith(color: colorScheme.onError)),
                            ),
                          );
                        }
                      },
                      child: Tooltip(
                        message: appLoca.descargaxestIOS,
                        child: SvgPicture.asset(
                          'images/landing/badges/app-store-badge-${MyApp.currentLang == 'es' ? 'es' : MyApp.currentLang == 'pt' ? 'pt' : 'en'}.svg',
                          width: 200,
                          semanticsLabel: appLoca.descargaxestIOS,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '\u00a9 Google Play and the Google Play logo are trademarks of Google LLC.',
                  style: textTheme.labelMedium!
                      .copyWith(color: colorScheme.onTertiaryContainer),
                ),
              ),
              Text(
                '\u00a9 App Store and the App Store logo are trademarks of Apple Inc.',
                style: textTheme.labelMedium!
                    .copyWith(color: colorScheme.onTertiaryContainer),
              ),
            ],
          ),
        ),
      ),
      itemCount: kIsWeb ? 1 : 0,
    );
  }

  Widget _columnCard(
    TextTheme textTheme,
    String description, {
    String? title,
    String? image,
    BoxFit fitImage = BoxFit.cover,
    double width = 470,
    double? heightImg,
    Color colorBackground = Colors.white,
    Color colorText = Colors.black,
    String? uriString,
  }) {
    ScaffoldMessengerState sms = ScaffoldMessenger.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorBackground,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SelectableText(
                    title,
                    style: textTheme.titleLarge!.copyWith(
                      color: colorText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Container(),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: uriString != null
                ? TextButton.icon(
                    onLongPress: () async {
                      await Clipboard.setData(ClipboardData(text: uriString));
                      sms.clearSnackBars();
                      sms.showSnackBar(const SnackBar(
                        content: Text("Copy to clipboard"),
                        duration: Durations.extralong2,
                      ));
                    },
                    icon: InkWell(
                        child: Icon(Icons.link, color: colorText),
                        onTap: () async {
                          if (!await launchUrl(Uri.parse(uriString))) {
                            if (ConfigXest.development)
                              debugPrint('Uri problem');
                          }
                        }),
                    label: SelectableText(
                      description,
                      style: textTheme.titleMedium!.copyWith(color: colorText),
                    ),
                    onPressed: null,
                  )
                : SelectableText(
                    description,
                    style: textTheme.titleMedium!.copyWith(color: colorText),
                  ),
          ),
          image != null
              ? Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      image,
                      fit: fitImage,
                      height: heightImg ?? 500,
                    ),
                  ),
                )
              : Container(),
        ],
      ),
    );
  }
}
