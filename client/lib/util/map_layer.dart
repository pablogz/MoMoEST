import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';

class MapLayer {
  static const double maxZoom = 22;
  static const double minZoom = 13;
  static bool onlyIconInfoMap = false;

  static Layers? _layer =
      ConfigXest.development ? Layers.openstreetmap : Layers.carto;

  static Layers? get layer => _layer;
  static set layer(Layers? layer) {
    if (!ConfigXest.development && layer != _layer) {
      onlyIconInfoMap = false;
      _layer = layer;
    }
  }

  static TileLayer tileLayerWidget({Brightness brightness = Brightness.light}) {
    TileLayer tileLayer;
    if (ConfigXest.development) {
      tileLayer = TileLayer(
        maxZoom: 22,
        minZoom: 1,
        maxNativeZoom: 18,
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: ConfigXest.namespace,
        tileProvider: NetworkTileProvider(),
      );
    } else {
      switch (layer) {
        case Layers.satellite:
          tileLayer = TileLayer(
            maxZoom: 22,
            minZoom: 1,
            maxNativeZoom: 19,
            urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: ConfigXest.namespace,
            tileProvider: NetworkTileProvider(),
          );
          break;
        case Layers.carto:
          tileLayer = TileLayer(
            maxZoom: 22,
            minZoom: 1,
            maxNativeZoom: 20,
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/${brightness == Brightness.light ? 'light_all' : 'dark_all'}/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: ConfigXest.namespace,
            tileProvider: NetworkTileProvider(),
            retinaMode: true,
          );
          break;
        case Layers.openstreetmap:
        default:
          tileLayer = TileLayer(
            maxZoom: 22,
            minZoom: 1,
            maxNativeZoom: 18,
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: ConfigXest.namespace,
            tileProvider: NetworkTileProvider(),
          );
      }
    }
    return tileLayer;
  }

  static IconButton _infoBt(BuildContext context) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<OutlinedButton> buttons = [
      OutlinedButton(
        child: Text(appLoca!.atribucionMapaCHEST),
        onPressed: () async {
          if (!await launchUrl(
            Uri.parse(
                '${ConfigXest.addClient}/sparql?default-graph-uri=&query=WITH <${ConfigXest.graphSpasql}> SELECT DISTINCT ?aliasAuthor WHERE {?author a <http://moult.gsic.uva.es/ontology/Person> . [] dc:creator ?author . ?author rdfs:label ?aliasAuthor .}&format=text/html'),
            mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppWebView,
          )) {
            if (ConfigXest.development)
              debugPrint('OSM copyright url problem!');
          }
        },
      ),
      OutlinedButton(
        child: Text(appLoca.atribucionMapaOSM),
        onPressed: () async {
          if (!await launchUrl(
              Uri.parse('https://www.openstreetmap.org/copyright'))) {
            if (ConfigXest.development)
              debugPrint('OSM copyright url problem!');
          }
        },
      ),
    ];
    switch (layer) {
      case Layers.mapbox:
        buttons.add(OutlinedButton(
          child: Text(appLoca.atribucionMapaMapbox),
          onPressed: () async {
            if (!await launchUrl(
                Uri.parse('https://www.mapbox.com/about/maps/'))) {
              if (ConfigXest.development) debugPrint('mapbox url problem!');
            }
          },
        ));
        break;
      case Layers.satellite:
        buttons.add(OutlinedButton(
          child: Text(appLoca.atribucionMapaEsri),
          onPressed: () async {
            if (!await launchUrl(Uri.parse(
                'https://www.arcgis.com/home/item.html?id=10df2279f9684e4a9f6a7f08febac2a9'))) {
              if (ConfigXest.development) debugPrint('Esri url problem!');
            }
          },
        ));
        break;
      case Layers.carto:
        buttons.add(OutlinedButton(
          child: Text(appLoca.atribucionMapaCarto),
          onPressed: () async {
            if (!await launchUrl(Uri.parse('https://carto.com/attributions'))) {
              if (ConfigXest.development) debugPrint('CARTO url problem!');
            }
          },
        ));
        break;
      default:
        break;
    }

    return IconButton(
      icon: const Icon(Icons.info_outline),
      color: Theme.of(context).colorScheme.onPrimaryContainer,
      tooltip: appLoca.mapInfoTitle,
      onPressed: () {
        Auxiliar.showMBS(
          title: appLoca.mapInfoTitle,
          context,
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: buttons,
          ),
        );
      },
    );
  }

  static Widget atributionWidget() {
    return Container(
      alignment: Alignment.bottomLeft,
      child: Builder(
        builder: (context) {
          if (onlyIconInfoMap) {
            return _infoBt(context);
          } else {
            String frase;
            switch (layer) {
              case Layers.carto:
                frase = AppLocalizations.of(context)!.atribucionMapaFraseCarto;
                break;
              case Layers.mapbox:
                frase = AppLocalizations.of(context)!.atribucionMapaFraseMapbox;
                break;
              case Layers.satellite:
                frase = AppLocalizations.of(context)!.atribucionMapaFraseEsri;
                break;
              default:
                frase = AppLocalizations.of(context)!.atribucionMapa;
            }
            return FutureBuilder(
                future: Future.delayed(const Duration(seconds: 5)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    ThemeData td = Theme.of(context);
                    ColorScheme colorScheme = td.colorScheme;
                    return Container(
                      color: colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Text(
                          frase,
                          style: td.textTheme.bodySmall!
                              .copyWith(color: colorScheme.onSurface),
                        ),
                      ),
                    );
                  } else {
                    onlyIconInfoMap = true;
                    return _infoBt(context);
                  }
                });
          }
        },
      ),
    );
  }
}

enum Layers { satellite, mapbox, openstreetmap, carto }
