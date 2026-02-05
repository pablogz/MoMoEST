import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:google_fonts/google_fonts.dart';
import 'package:momoest/util/helpers/widget_facto.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import 'package:momoest/util/helpers/feature.dart';
import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/helpers/tasks.dart';
import 'package:momoest/util/queries.dart';
import 'package:momoest/util/helpers/suggestion_solr.dart';
import 'package:momoest/main.dart';
import 'package:momoest/util/helpers/city.dart';

enum ImageSourceXEST { device, url }

class Auxiliar {
  static const double maxWidth = 1000;
  static const double compactMargin = 16;
  static const double mediumMargin = 24;
  static double getLateralMargin(double w) =>
      w > 599 ? mediumMargin : compactMargin;
  static String mainFabHero = "mainFabHero";
  static String searchHero = 'searchHero';

  static double distance(LatLng p0, LatLng p1) {
    const Distance d = Distance();
    return d.as(LengthUnit.Meter, p0, p1);
  }

  static String getIdFromIri(String iri) {
    List<String> parts = iri.split('/');
    return parts[parts.length - 1];
  }

  static const Map<String, String> _idToShortId = {
    'https://www.openstreetmap.org/node/': 'osmn:',
    'https://www.openstreetmap.org/relation/': 'osmr:',
    'https://www.openstreetmap.org/way/': 'osmw:',
    'http://www.wikidata.org/entity/': 'wd:',
    'http://dbpedia.org/resource/': 'dbpedia:',
    'http://es.dbpedia.org/resource/': 'esdbpedia:',
    'http://moult.gsic.uva.es/data/': 'md:',
    'http://moult.gsic.uva.es/ontology/': 'mo:',
  };

  /// Converts a long ID [id] to a short ID [shortId] by looking up the short ID prefix in a map and appending the end of the long ID.
  /// Returns null if the short ID prefix is not found in the map.
  static String? id2shortId(String id) {
    String? shortId;
    String end = id.split('/').last;
    String start = id.substring(0, id.length - end.length);
    shortId = _idToShortId[start];
    if (shortId != null) {
      shortId = '$shortId$end';
    }
    return shortId;
  }

  static const Map<String, String> _prefix2URI = {
    'osmn': 'https://www.openstreetmap.org/node/',
    'osmr': 'https://www.openstreetmap.org/relation/',
    'osmw': 'https://www.openstreetmap.org/way/',
    'wd': 'http://www.wikidata.org/entity/',
    'dbpedia': 'http://dbpedia.org/resource/',
    'esdbpedia': 'http://es.dbpedia.org/resource/',
    'chd': 'http://chest.gsic.uva.es/data/',
    'cho': 'http://chest.gsic.uva.es/ontology/',
    'md': 'http://moult.gsic.uva.es/data/',
    'mo': 'http://moult.gsic.uva.es/ontology/',
  };

  /// Converts a short ID to a full ID by appending the corresponding base URI.
  ///
  /// The short ID is expected to be in the format "prefix:id", where "prefix" is
  /// a key in the `_prefix2URI` map and "id" is the ID to be appended to the
  /// corresponding base URI. If the prefix is not found in the map, or if the
  /// short ID is not in the expected format, this function returns `null`.
  static String? shortId2Id(String shortId) {
    String? id;
    List<String> partsShortId = shortId.split(':');
    if (partsShortId.length == 2) {
      String? baseURI = _prefix2URI[partsShortId[0]];
      if (baseURI != null) {
        id = '$baseURI${partsShortId[1]}';
      }
    }
    return id;
  }

  /// Returns the label for the given [AnswerType] based on the provided [AppLocalizations].
  ///
  /// The [appLoca] parameter is an instance of [AppLocalizations] which contains localized strings for the different [AnswerType]s.
  ///
  /// The [aT] parameter is an instance of [AnswerType] for which the label is to be retrieved.
  ///
  /// Returns an empty string if the [AnswerType] is not found in the [mapAnswerTypeName].
  static String getLabelAnswerType(AppLocalizations? appLoca, AnswerType aT) {
    Map<AnswerType, String> mapAnswerTypeName = {
      AnswerType.mcq: appLoca!.mcqTitle,
      AnswerType.multiplePhotos: appLoca.multiplePhotosTitle,
      AnswerType.multiplePhotosText: appLoca.multiplePhotosTextTitle,
      AnswerType.noAnswer: appLoca.noAnswerTitle,
      AnswerType.photo: appLoca.photoTitle,
      AnswerType.photoText: appLoca.photoTextTitle,
      AnswerType.text: appLoca.textTitle,
      AnswerType.tf: appLoca.tfTitle,
      AnswerType.video: appLoca.videoTitle,
      AnswerType.videoText: appLoca.videoTextTitle,
    };

    return mapAnswerTypeName[aT] ?? '';
  }

  static Future<bool?> deleteDialog(
      BuildContext context, String title, String content) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog.adaptive(
          // contentPadding: EdgeInsets.zero,
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppLocalizations.of(context)!.borrar)),
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancelar)),
          ],
        );
      },
    );
  }

  static void showMBS(BuildContext context, Widget child,
      {String? title, String? comment, bool divider = false}) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      showDragHandle: true,
      isScrollControlled: true,
      // shape: const RoundedRectangleBorder(
      //     borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (context) => Padding(
        padding: const EdgeInsets.only(right: 10, left: 10, bottom: 20),
        child: _contentMBS(Theme.of(context), title, comment, divider, child),
      ),
    );
  }

  static Widget _contentMBS(
    ThemeData td,
    String? title,
    String? comment,
    bool divider,
    Widget child,
  ) {
    return title == null
        ? child
        : comment == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: td.textTheme.titleMedium,
                  ),
                  divider ? const Divider() : const SizedBox(height: 8),
                  child
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    comment,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  divider ? const Divider() : const SizedBox(height: 8),
                  child
                ],
              );
  }

  /// Returns the upper case of each word in [label]. The number of capital letters return can be controlled with [nCL] (default = 3). If [nCL] is 0 or less, all are returned.
  static String capitalLetters(String label, {int nCL = 3}) {
    List<String> parts = label.split(' ');
    String cL = '';
    late String c;
    late bool upper, lower;
    for (String part in parts) {
      for (int i = 0, tama = part.length; i < tama; i++) {
        c = part[i];
        upper = c.toUpperCase() == c;
        lower = c.toLowerCase() == c;
        if (upper && lower) {
          continue;
        } else {
          if (upper && !lower) {
            cL += c;
          }
          break;
        }
      }
      if (nCL > 0 && cL.length == nCL) {
        break;
      }
    }
    return cL;
  }

  static Future<Map?> _getSuggestions(String query) async {
    try {
      return http
          .get(
        Queries.getSuggestions(query, dict: MyApp.currentLang),
      )
          .then((response) {
        return response.statusCode == 200 ? json.decode(response.body) : null;
      });
    } catch (e) {
      return null;
    }
  }

  static Iterable<Widget> recuperaSugerencias(
      BuildContext context, SearchController controller,
      {MapController? mapController, bool moveWithUrl = true}) {
    AppLocalizations? appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    String userText = controller.text.trim();
    if (userText.isNotEmpty) {
      // El suggestionsBuilder no puede ser asíncrono.
      // Por eso tengo que hacer la chapuza de devolver un
      // FutureBuilder dentro de un array.
      return [
        FutureBuilder<Map?>(
            future: _getSuggestions(userText),
            builder: (context, snapshot) {
              if (snapshot.hasData && !snapshot.hasError) {
                var data = snapshot.data!;
                ReSug reSug = ReSug(data);
                ReSugDic reSugDic =
                    reSug.reSugData.getReSugDic(MyApp.currentLang) ??
                        reSug.reSugData.getReSugDic('en')!;
                List<Widget> lst = [];
                for (SuggestionSolr suggestion in reSugDic.suggestions) {
                  try {
                    String labelVal =
                        suggestion.label(MyApp.currentLang)?.value ??
                            suggestion.label('en')!.value;
                    List<String> splitLabel = labelVal.split(', ');
                    String country = splitLabel.last;
                    String city = labelVal.replaceFirst(', $country', '');
                    lst.add(
                      ListTile(
                        leading: Icon(
                          Icons.place_rounded,
                          color: colorScheme.primary,
                        ),
                        title: HtmlWidget(
                          city,
                          factoryBuilder: () => MyWidgetFactory(),
                        ),
                        subtitle: HtmlWidget(
                          country,
                          factoryBuilder: () => MyWidgetFactory(),
                        ),
                        onTap: () async {
                          try {
                            Map? response = await http
                                .get(Queries.getSuggestion(suggestion.id))
                                .then((value) => value.statusCode == 200
                                    ? json.decode(value.body)
                                    : null)
                                .onError((error, stackTrace) => null);
                            ReSug reSug = ReSug(response);
                            ReSelData reSelData = reSug.reSelData;
                            // Trabajando con el ID solamente debemos tener un resultado. Esto cambia si se utiliza otro campo (por ejemplo las etiquetas).
                            if (reSelData.numFound == 1) {
                              SuggestionSolr suggestion = reSelData.docs.first;
                              if (!context.mounted) return;
                              if (moveWithUrl) {
                                GoRouter.of(context).go(
                                    '/home?center=${suggestion.lat},${suggestion.long}&zoom=13');
                                GoRouter.of(context).refresh();
                              }
                              if (mapController != null) {
                                mapController.move(
                                    LatLng(suggestion.lat, suggestion.long),
                                    13);
                                context.pop();
                              }
                              if (!ConfigXest.development) {
                                FirebaseAnalytics.instance.logEvent(
                                    name: 'search_suggestion',
                                    parameters: {'id': suggestion.id});
                              }
                            }
                          } catch (e, stackTrace) {
                            if (ConfigXest.development) {
                              debugPrint('Error in suggestion: $e');
                            } else {
                              await FirebaseCrashlytics.instance
                                  .recordError(e, stackTrace);
                            }
                          }
                        },
                      ),
                    );
                  } catch (e, stackTrace) {
                    if (ConfigXest.development) {
                      debugPrint('Error in suggestion: $e');
                    } else {
                      FirebaseCrashlytics.instance.recordError(e, stackTrace);
                    }
                  }
                }

                return lst.isNotEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            ListTile.divideTiles(tiles: lst, context: context)
                                .toList(),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(appLoca.sinSugerencias),
                      );
              } else {
                if (snapshot.hasError) {
                  return const SizedBox();
                }
                return const LinearProgressIndicator();
              }
            })
      ];
    } else {
      List<Widget> lst = [];
      List<City> exCities = [
        City(appLoca.valladolid, appLoca.spain,
            LatLng(41.651980555, -4.728561111)),
        City(appLoca.madrid, appLoca.spain, LatLng(40.416944444, -3.703333333)),
        City(
            appLoca.atenas, appLoca.grecia, LatLng(37.984166666, 23.728055555)),
        City(appLoca.nuevaYork, appLoca.usa, LatLng(40.7, -74.0)),
        City(appLoca.palermo, appLoca.italia, LatLng(38.111111, 13.351667)),
        City(appLoca.turin, appLoca.italia, LatLng(45.079167, 7.676111)),
        City(appLoca.toulouse, appLoca.francia,
            LatLng(43.604444444, 1.443888888)),
        City(appLoca.aveiro, appLoca.portugal, LatLng(40.633333, -8.65)),
        City(appLoca.tokio, appLoca.japon, LatLng(35.689722222, 139.692222222)),
      ];
      for (City c in exCities) {
        lst.add(ListTile(
            leading: Icon(
              Icons.star_rounded,
              color: colorScheme.primary,
            ),
            title: Text(c.lblCity),
            subtitle: Text(c.lblCountry),
            onTap: () {
              if (moveWithUrl) {
                GoRouter.of(context).go(
                    '/home?center=${c.point.latitude},${c.point.longitude}&zoom=13');
                GoRouter.of(context).refresh();
              }
              if (mapController != null) {
                mapController.move(c.point, 13);
                context.pop();
              }
            }));
      }
      List<Widget> lst2 = [
        Padding(
          padding:
              const EdgeInsets.only(top: 15, bottom: 25, left: 10, right: 10),
          child: Text(appLoca.lugaresPopulares,
              style:
                  textTheme.titleSmall!.copyWith(fontWeight: FontWeight.bold)),
        ),
      ];
      lst2.addAll(
        ListTile.divideTiles(tiles: lst, context: context),
      );
      return [
        Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lst2)
      ];
    }
  }

  static Future<ShareResult> share(
      GlobalKey globalKey, String textToShare) async {
    bool isUri = Uri.parse(textToShare).isAbsolute;
    // iPad: https://pub.dev/packages/share_plus
    final RenderBox? box =
        globalKey.currentContext!.findRenderObject() as RenderBox?;
    Rect? rect = box!.localToGlobal(Offset.zero) & box.size;
    return isUri
        ? await Share.shareUri(
            Uri.parse(textToShare),
            sharePositionOrigin: rect,
          )
        : await Share.share(
            textToShare,
            sharePositionOrigin: rect,
          );
  }

  // TODO Cambiar cuando se cambie de dominio
  static String? getSpatialThingTypeNameLoca(
      AppLocalizations appLoca, SpatialThingType type) {
    Map<SpatialThingType, String> t = {
      SpatialThingType.artwork: appLoca.artwork,
      SpatialThingType.attraction: appLoca.attraction,
      SpatialThingType.castle: appLoca.castle,
      SpatialThingType.cathedral: appLoca.cathedral,
      SpatialThingType.church: appLoca.church,
      SpatialThingType.culturalHeritage: appLoca.culturalHeritage,
      SpatialThingType.fountain: appLoca.fountain,
      SpatialThingType.museum: appLoca.museum,
      SpatialThingType.palace: appLoca.palace,
      SpatialThingType.placeOfWorship: appLoca.placeOfWorship,
      SpatialThingType.square: appLoca.square,
      SpatialThingType.tower: appLoca.tower,
    };
    return t[type];
  }

  static String capitalize(String s) {
    if (s.isNotEmpty) {
      return '${s[0].toUpperCase()}${s.substring(1)}';
    } else {
      return s;
    }
  }

  static SpatialThingType? getSpatialThing(String s) {
    Map<String, SpatialThingType> t = {
      SpatialThingType.artwork.name: SpatialThingType.artwork,
      capitalize(SpatialThingType.artwork.name): SpatialThingType.artwork,
      SpatialThingType.attraction.name: SpatialThingType.attraction,
      capitalize(SpatialThingType.attraction.name): SpatialThingType.attraction,
      SpatialThingType.castle.name: SpatialThingType.castle,
      capitalize(SpatialThingType.castle.name): SpatialThingType.castle,
      SpatialThingType.cathedral.name: SpatialThingType.cathedral,
      capitalize(SpatialThingType.cathedral.name): SpatialThingType.cathedral,
      SpatialThingType.church.name: SpatialThingType.church,
      capitalize(SpatialThingType.church.name): SpatialThingType.church,
      SpatialThingType.culturalHeritage.name: SpatialThingType.culturalHeritage,
      capitalize(SpatialThingType.culturalHeritage.name):
          SpatialThingType.culturalHeritage,
      SpatialThingType.fountain.name: SpatialThingType.fountain,
      capitalize(SpatialThingType.fountain.name): SpatialThingType.fountain,
      SpatialThingType.museum.name: SpatialThingType.museum,
      capitalize(SpatialThingType.museum.name): SpatialThingType.museum,
      SpatialThingType.palace.name: SpatialThingType.palace,
      capitalize(SpatialThingType.palace.name): SpatialThingType.palace,
      SpatialThingType.placeOfWorship.name: SpatialThingType.placeOfWorship,
      capitalize(SpatialThingType.placeOfWorship.name):
          SpatialThingType.placeOfWorship,
      SpatialThingType.square.name: SpatialThingType.square,
      capitalize(SpatialThingType.square.name): SpatialThingType.square,
      SpatialThingType.tower.name: SpatialThingType.tower,
      capitalize(SpatialThingType.tower.name): SpatialThingType.tower,
    };
    return t[s];
  }

  static isUriResource(String s) {
    Uri? uri = Uri.tryParse(s);
    return uri != null ? uri.hasAbsolutePath && uri.hasScheme : false;
  }

  // TODO agregar los tipos!
  static IconData getIcon(dynamic spatialThingTypes) {
    return Icons.castle;
  }

  // static String stringDistance(double distance) {
  //   return distance < 1000
  //       ? Template('{{{metros}}} m')
  //           .renderString({"metros": distance.toInt().toString()})
  //       : Template('{{{km}}} km')
  //           .renderString({"km": (distance / 1000).toStringAsFixed(2)});
  // }

  // https://pub.dev/packages/url_launcher#encoding-urls
  static String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  /// Compruega si [mail] contiene una dirección de correo válido
  static bool validMail(String mail) {
    final RegExp regExp = RegExp(
        r"^(?!\.)[a-zA-Z0-9!#\$%&'\*\+\-/=\?\^_`{\|}~ñÑáéíóúÁÉÍÓÚüÜ\.]+(?<!\.)@[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)*\.[a-zA-Z]{2,}$");
    return regExp.hasMatch(mail.trim());
  }

  static bool validURL(String url) {
    final RegExp regex = RegExp(
      r"^(https?:\/\/)?([\w\-]+\.)+[\w\-]+(\/[\w\-._~:/?#[\]@!$&\'()%*+,;=]*)?$",
      caseSensitive: false,
    );
    return regex.hasMatch(url.trim());
  }

  /// Permite redondear [n] a los decimales que se indiquen
  /// con [numDecimales] (valor por defecto = 1)
  static double redondeo(double n, {int numDecimales = 1}) {
    int mul = pow(10, numDecimales).toInt();
    return ((n * mul).round()) / mul;
  }

  static QuillSimpleToolbar quillToolbar(QuillController quillcontroller) =>
      QuillSimpleToolbar(
        controller: quillcontroller,
        config: const QuillSimpleToolbarConfig(
          showAlignmentButtons: false,
          showBackgroundColorButton: false,
          showCenterAlignment: false,
          showClipboardCopy: false,
          showClipboardCut: false,
          showClipboardPaste: false,
          showCodeBlock: false,
          showColorButton: false,
          showDirection: false,
          showDividers: false,
          showFontFamily: false,
          showFontSize: false,
          showHeaderStyle: false,
          showIndent: false,
          showInlineCode: false,
          showJustifyAlignment: false,
          showLeftAlignment: false,
          showLineHeightButton: false,
          showListCheck: false,
          showQuote: false,
          showSearchButton: false,
          showSmallButton: false,
          showStrikeThrough: false,
          showRightAlignment: false,
          showSubscript: false,
          showSuperscript: false,
          multiRowsDisplay: true,
        ),
      );

  static String quillDelta2Html(Delta delta) =>
      QuillDeltaToHtmlConverter(delta.toJson())
          .convert()
          .replaceAll('<li><br/></li>', '<li></li>')
          .replaceAll('<p><br/></p>', '');

  static Future<Uint8List> comprimeImagen(Uint8List original) async {
    return original.length > 250000
        ? await FlutterImageCompress.compressWithList(
            original,
            quality: original.length < 500000
                ? 50
                : original.length < 1000000
                    ? 37
                    : 25,
            format: CompressFormat.jpeg,
            keepExif: false,
          )
        : original;
  }

  static TextTheme createTextTheme(
      BuildContext context, String bodyFontString, String displayFontString) {
    TextTheme baseTextTheme = Theme.of(context).textTheme;
    TextTheme bodyTextTheme =
        GoogleFonts.getTextTheme(bodyFontString, baseTextTheme);
    TextTheme displayTextTheme =
        GoogleFonts.getTextTheme(displayFontString, baseTextTheme);
    TextTheme textTheme = displayTextTheme.copyWith(
      bodyLarge: bodyTextTheme.bodyLarge,
      bodyMedium: bodyTextTheme.bodyMedium,
      bodySmall: bodyTextTheme.bodySmall,
      labelLarge: bodyTextTheme.labelLarge,
      labelMedium: bodyTextTheme.labelMedium,
      labelSmall: bodyTextTheme.labelSmall,
    );
    return textTheme;
  }
}
