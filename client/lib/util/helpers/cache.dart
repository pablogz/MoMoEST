import 'dart:convert';
import 'dart:math';

import 'package:momoest/main.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/helpers/feed.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/helpers/feature.dart';
import 'package:momoest/util/map_layer.dart';
import 'package:momoest/util/queries.dart';
// import 'package:momoest/util/helpers/auxiliar_mobile.dart'
//     if (dart.libary.html) 'package:chest/util/helpers/auxiliar_web.dart';

class MapData {
  // static const double tileSide = 0.1;
  static final List<TeselaFeature> _teselaFeature = [];
  // static const LatLng _posRef = LatLng(41.66, -4.71);
  static const LatLng _posRef = LatLng(0, 0);
  static int pendingTiles = 0;
  static int totalTiles = 0;
  static ValueNotifier valueNotifier = ValueNotifier<double?>(0);

  /// Remove all cache data
  static void resetLocalCache() {
    _teselaFeature.clear();
    totalTiles = 0;
  }

  /// Recover all cache data
  static List<TeselaFeature> get teselaFeature => _teselaFeature;

  /// Split [mapBounds] and check the POIs inside each split. For this,
  /// First check the local cache [_teselaFeature]. If it does not have the
  /// POIs for the zone, or they are not valid, asks the server.
  static Future<List<Feature>> checkCurrentMapSplit(
    LatLngBounds mapBounds, {
    Set<SpatialThingType>? filters,
  }) async {
    try {
      LatLng pI = _startPointCHeck(mapBounds.northWest);
      NumberTile c = _buildTeselas(pI, mapBounds.southEast);
      _teselaFeature.removeWhere((TeselaFeature tp) => !tp.isValid());
      List<Feature> out = [];

      double pLng, pLat;
      LatLng puntoComprobacion;
      bool encontrado, guardaCache = false;
      List<Future<TeselaFeature?>> peticiones = [];
      pendingTiles = 0;
      totalTiles = 0;
      valueNotifier.value = 0.0;
      for (int i = 0; i < c.ch; i++) {
        pLng = pI.longitude + (i * TeselaFeature.lado);
        for (int j = 0; j < c.cv; j++) {
          pLat = pI.latitude - (j * TeselaFeature.lado);

          /// Chapuza debida a un error de redondeo.
          puntoComprobacion =
              LatLng(Auxiliar.redondeo(pLat), Auxiliar.redondeo(pLng));
          encontrado = false;
          late TeselaFeature tp;
          for (tp in _teselaFeature) {
            if (tp.isEqualPoint(puntoComprobacion,
                onlyMoMo: MapLayer.onlyMoMo)) {
              encontrado = true;
              break;
            }
          }
          ++totalTiles;
          if (!encontrado || !tp.isValid()) {
            ++pendingTiles;
            peticiones.add(_newZone(puntoComprobacion));
            guardaCache = true;
          } else {
            //Agrego para devolverselo al usuario
            ++valueNotifier.value;
            if (filters != null) {
              List<Feature> tpFeaturesFiltrado = [];
              for (Feature f in tp.features) {
                bool entra = false;
                if (f.spatialThingTypes != null) {
                  for (SpatialThingType stt in f.spatialThingTypes!) {
                    entra = filters.contains(stt);
                    if (entra) break;
                  }
                }
                if (entra) {
                  tpFeaturesFiltrado.add(f);
                }
              }
              out.addAll(tpFeaturesFiltrado);
            } else {
              out.addAll(tp.features);
            }
          }
        }
        //Cuando todos los futuros se hayan completado agrego y se lo devuelvo
      }
      List<TeselaFeature?> newTeselaFeatures = await Future.wait(peticiones);
      for (TeselaFeature? tp in newTeselaFeatures) {
        if (tp != null) {
          if (_teselaNotExist(tp)) {
            _teselaFeature.add(tp);
          }
          if (filters != null) {
            List<Feature> tpFeaturesFiltrado = [];
            for (Feature f in tp.features) {
              bool entra = false;
              if (f.spatialThingTypes != null) {
                for (SpatialThingType stt in f.spatialThingTypes!) {
                  entra = filters.contains(stt);
                  if (entra) break;
                }
              }
              if (entra) {
                tpFeaturesFiltrado.add(f);
              }
            }
            out.addAll(tpFeaturesFiltrado);
          } else {
            out.addAll(tp.features);
          }
        }
      }
      if (guardaCache) {
        await saveCacheTiles();
      }
      return out;
    } catch (e, stackTrace) {
      if (ConfigXest.development) {
        debugPrint(e.toString());
      } else {
        await FirebaseCrashlytics.instance.recordError(e, stackTrace);
      }
      return [];
    }
  }

  /// Check if [teselaFeature] was previously added to [_teselaFeature]
  static bool _teselaNotExist(TeselaFeature teselaFeature) {
    for (TeselaFeature tf in _teselaFeature) {
      if (tf.isEqualPoint(
        LatLng(teselaFeature.north, teselaFeature.west),
        onlyMoMo: teselaFeature.onlyMoMo,
      )) {
        return false;
      }
    }
    return true;
  }

  static LatLng _startPointCHeck(LatLng nW) {
    double esquina, gradosMax;
    var s = <double>[];

    for (var i = 0; i < 2; i++) {
      esquina = (i == 0)
          ? _posRef.latitude -
              (((_posRef.latitude - nW.latitude) / TeselaFeature.lado))
                      .floor() *
                  TeselaFeature.lado
          : _posRef.longitude -
              (((_posRef.longitude - nW.longitude) / TeselaFeature.lado))
                      .ceil() *
                  TeselaFeature.lado;
      gradosMax = (i + 1) * 90;
      if (esquina.abs() > gradosMax) {
        if (esquina > gradosMax) {
          esquina = gradosMax;
        } else {
          if (esquina < (-1 * gradosMax)) {
            esquina = (-1 * gradosMax);
          }
        }
      }
      s.add(esquina);
    }
    return LatLng(s[0], s[1]);
  }

  static NumberTile _buildTeselas(LatLng nw, LatLng se) {
    return NumberTile(((nw.latitude - se.latitude) / TeselaFeature.lado).ceil(),
        ((se.longitude - nw.longitude) / TeselaFeature.lado).ceil());
  }

  static Future<TeselaFeature?> _newZone(LatLng? point) async {
    final bool currentMode = MapLayer.onlyMoMo;

    try {
      return http
          .get(Queries.getFeatures({
        'north': point!.latitude,
        'south': point.latitude - TeselaFeature.lado,
        'west': point.longitude,
        'east': point.longitude + TeselaFeature.lado,
        'group': false
      }))
          .then((response) {
        switch (response.statusCode) {
          case 200:
            return json.decode(response.body);
          case 204:
            return <dynamic>[]; // FIX: tile vacía válida → lista vacía, no null
          default:
            return null; // Error real → null, no cachear
        }
      }).then((data) async {
        if (pendingTiles > 0) {
          pendingTiles = max(0, pendingTiles - 1);
          valueNotifier.value = (totalTiles - pendingTiles) / totalTiles;
        }
        if (data == null) {
          return null;
        } else {
          List<Feature> features = <Feature>[];
          for (var p in data) {
            try {
              features.add(Feature(p));
            } catch (e, stackTrace) {
              if (ConfigXest.development) {
                debugPrint(e.toString());
              } else {
                await FirebaseCrashlytics.instance.recordError(e, stackTrace);
              }
            }
          }
          return features.isNotEmpty
              ? TeselaFeature(point.latitude, point.longitude, features,
                  onlyMoMo: currentMode)
              : TeselaFeature.withoutFeatures(point.latitude, point.longitude,
                  onlyMoMo: currentMode);
        }
      });
    } catch (e) {
      return null;
    }
  }

  static void addFeature2Tile(Feature feature) {
    // Primero busco en las teselas existentes
    int index = _findFeatureTile(feature);
    if (index > -1) {
      _teselaFeature[index].addFeature(feature);
    } else {
      // Si ninguna de las que tengo está el POI la creo y la agrego a la caché
      LatLng pI = _startPointCHeck(feature.point);
      TeselaFeature nTp =
          TeselaFeature.withoutFeatures(pI.latitude, pI.longitude);
      nTp.addFeature(feature);
      _teselaFeature.add(nTp);
    }
  }

  static void removeFeatureFromTile(Feature feature) {
    int index = _findFeatureTile(feature);
    if (index > -1) {
      _teselaFeature[index].removeFeature(feature);
    }
  }

  static int _findFeatureTile(Feature feature) {
    return _teselaFeature.indexWhere((TeselaFeature t) {
      return t.checkIfContains(feature.point);
    });
  }

  static Feature? getFeatureCache(String shortId) {
    List<Feature> features;
    int index;
    for (TeselaFeature tp in _teselaFeature) {
      features = tp.features;
      index = features.indexWhere((Feature p) => p.shortId == shortId);
      if (index > -1) {
        return features[index];
      }
    }
    return null;
  }

  static bool updateFeatureCache(Feature feature) {
    List<Feature> features;
    int indexFeature;
    for (int indexTeselaFeature = 0, tamaTeselaPoi = _teselaFeature.length;
        indexTeselaFeature < tamaTeselaPoi;
        indexTeselaFeature++) {
      features = _teselaFeature[indexTeselaFeature].features;
      indexFeature = features.indexWhere((Feature f) => f.id == feature.id);
      if (indexFeature >= 0) {
        _teselaFeature[indexTeselaFeature]
            .removeFeature(features.elementAt(indexFeature));
        _teselaFeature[indexTeselaFeature].addFeature(feature);
        return true;
      }
    }
    return false;
  }

  /// Provide the list of features close to the [point]. You can set the max. features
  /// with [maxFeatures] and the distance with [maxDistance] (meters)
  static List<FeatureDistance> getNearCacheFeature(
    LatLng point, {
    double maxDistance = 1000,
    int maxFeatures = 20,
  }) {
    List<Feature> featuresInTeselasClose = _getCloseCacheTeselas(point);
    maxFeatures = featuresInTeselasClose.length > maxFeatures
        ? maxFeatures
        : featuresInTeselasClose.length;
    List<FeatureDistance> out = [];
    for (Feature f in featuresInTeselasClose) {
      out.add(FeatureDistance(f, Auxiliar.distance(point, f.point)));
    }
    out.sort((FeatureDistance a, FeatureDistance b) =>
        a.distance.compareTo(b.distance));
    out = out.sublist(0, maxFeatures);
    out.removeWhere((FeatureDistance fd) => fd.distance > maxDistance);
    return out;
  }

  static List<Feature> _getCloseCacheTeselas(LatLng point) {
    List<TeselaFeature> teselaFeatures = [];
    Set<LatLng> lstPoints = {};
    for (int i = -1; i < 2; i++) {
      for (int j = -1; j < 2; j++) {
        lstPoints.add(LatLng(
          point.latitude + i * TeselaFeature.lado,
          point.longitude + j * TeselaFeature.lado,
        ));
      }
    }
    for (TeselaFeature tf in _teselaFeature) {
      for (LatLng p in lstPoints) {
        if (tf.checkIfContains(p)) {
          teselaFeatures.add(tf);
          break;
        }
      }
      if (teselaFeatures.length == lstPoints.length) {
        break;
      }
    }
    List<Feature> out = [];
    for (TeselaFeature tf in teselaFeatures) {
      out.addAll(tf.features);
    }
    return out;
  }

  static Future<void> loadCacheTiles() async {
    resetLocalCache();
    List<String>? lst =
        (await MyApp.preferencesWithCache).getStringList(MyApp.TILES_KEY);
    if (lst != null && lst.isNotEmpty) {
      for (String l in lst) {
        Map<String, dynamic> tfJson2 = jsonDecode(l);
        TeselaFeature tf = TeselaFeature.fromJSON(tfJson2);
        _teselaFeature.add(tf);
      }
      totalTiles = _teselaFeature.length;
    }
  }

  static Future<void> saveCacheTiles() async {
    List<String> lst = [];
    for (TeselaFeature tf in _teselaFeature) {
      String tfJsonString = '';
      try {
        tfJsonString = jsonEncode(tf);
      } catch (error) {
        debugPrint(error.toString());
      }
      lst.add(tfJsonString);
    }
    (await MyApp.preferencesWithCache)
        .setStringList(MyApp.TILES_KEY, lst)
        .catchError((e) async {
      // Voy reduciendo el tamaño de la caché poco a poco
      if (_teselaFeature.isNotEmpty) {
        _teselaFeature.sort(
            (TeselaFeature a, TeselaFeature b) => b.update.compareTo(a.update));
        List<TeselaFeature> inter =
            _teselaFeature.getRange(0, _teselaFeature.length - 1).toList();
        _teselaFeature.clear();
        _teselaFeature.addAll(inter);
        (await MyApp.preferencesWithCache).clear();
        await saveCacheTiles();
      }
    });
  }
}

class NumberTile {
  late int cv, ch;
  NumberTile(this.cv, this.ch);
}

/// Clase que actuará como caché de los feeds
class FeedCache {
  /// Lista con todos los feeds cacheados en el cliente
  static List<Feed>? _feeds;

  /// Limpia la caché local de [Feed]
  static void resetCache() {
    _feeds = null;
  }

  /// Si [feed] no está incluido en la caché local se agrega al final de la lista.
  /// Devuelve verdadero si lo ha podido agregar
  static bool addFeed(Feed feed) {
    _feeds ??= [];
    int index = _feeds!.indexWhere((Feed f) => f.id == feed.id);
    if (index == -1) {
      _feeds!.add(feed);
    }
    return index == -1;
  }

  /// Agrega todos los nuevos [feed] que se envíen a través de [feeds] a la caché local
  static bool addAll(List<Feed> feeds) {
    bool out = true;
    if (feeds.isNotEmpty) {
      for (Feed feed in feeds) {
        out &= addFeed(feed);
      }
    } else {
      _feeds = [];
    }
    return out;
  }

  /// Elimina un [feed] de la caché
  static bool removeFeed(Feed feed) {
    if (_feeds != null) {
      int index = _feeds!.indexWhere((Feed f) => f.id == feed.id);
      if (index > -1) {
        _feeds!.removeAt(index);
      }
      return index > -1;
    }
    return false;
  }

  /// Elimina [feed] y lo vuelve a agregar
  static void updateFeed(Feed feed) {
    removeFeed(feed);
    addFeed(feed);
    return;
  }

  /// Recupera un [Feed] a través de su [shortId]. Si no se dispone del [Feed] en la
  /// caché se devuelve null
  static Feed? getFeed(String shortId) {
    if (_feeds != null) {
      int index = _feeds!.indexWhere((Feed f) => f.shortId == shortId);
      return index > -1 ? _feeds!.elementAt(index) : null;
    }
    return null;
  }

  static bool get feedsIsNull => _feeds == null;
  static bool get feedsIsNotNull => _feeds != null;

  /// Recupera todos los canales cacheados
  static List<Feed> get feeds =>
      feedsIsNotNull ? _feeds! : throw Exception('_feeds is null');
}
