import 'package:momoest/util/exceptions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';

import 'package:momoest/util/config_xest.dart';

/// Clase para almacenar recorridos (posición más instante)
class Track {
  late List<LatLngCHEST> _points;
  late LatLng _northWest, _southEast;

  /// Constructor de la clase. La entrada [input] debe ser una cadena de texto. La idea es introducir el contendio de un fichero GPX. El GPX de su interior tiene que tener el formato de la versión 1.1 para que sea compatible con el paquete GPX
  Track.gpx(dynamic input) {
    if (input is String) {
      try {
        Gpx gpx = GpxReader().fromString(input);
        _points = [];
        if (gpx.trks.length == 1 && gpx.trks.first.trksegs.length == 1) {
          for (Wpt wpt in gpx.trks.first.trksegs.first.trkpts) {
            try {
              _points.add(LatLngCHEST(
                lat: wpt.lat!,
                long: wpt.lon!,
                alt: wpt.ele,
                timestamp: wpt.time,
              ));
            } catch (e, stackTrace) {
              if (ConfigXest.development) {
                debugPrint(e.toString());
              } else {
                FirebaseCrashlytics.instance.recordError(e, stackTrace);
              }
            }
          }
        } else {
          if (gpx.rtes.length == 1 && gpx.rtes.first.rtepts.length == 1) {
            for (Wpt wpt in gpx.rtes.first.rtepts) {
              try {
                _points.add(LatLngCHEST(
                  lat: wpt.lat!,
                  long: wpt.lon!,
                  alt: wpt.ele,
                  timestamp: wpt.time,
                ));
              } catch (e, stack) {
                if (ConfigXest.development) {
                  debugPrint(e.toString());
                } else {
                  FirebaseCrashlytics.instance.recordError(e, stack);
                }
              }
            }
          } else {
            throw TrackException('It is not a track and neither a route');
          }
        }
      } catch (e) {
        throw TrackException('Problem with the input. Is it GPX1.1?');
      }
    } else {
      throw TrackException('Problem with the input');
    }
  }

  /// Constructor de la clase para cuando los datos vienen del servidor. [data] tiene que ser un mapa.
  Track.server(dynamic data) {
    if (data is Map && data.containsKey('track') && data['track'] is List) {
      _points = [];
      try {
        for (var point in data['track']) {
          _points.add(LatLngCHEST.server(point));
        }
      } catch (e) {
        throw TrackException(e.toString());
      }
    } else {
      throw TrackException('data is not valid');
    }
  }

  /// Constructor de un Track vacío. Puede servir si en algún momento vamos a querer recuerar los recorridos que hacen los estudiantes
  Track() {
    _points = [];
  }

  /// Devuelve todos los puntos del track
  List<LatLngCHEST> get points => _points;

  /// Límite superior izquierda del [Track]
  LatLng get northWest => _northWest;

  /// Límite inferior derecha del [Track]
  LatLng get southEast => _southEast;

  /// Permite agregar un nuevo punto al track
  void addPoint(LatLngCHEST point) {
    _points.add(point);
  }

  /// Devuelve el Track en un mapa
  Map<String, dynamic> toMap() {
    Map<String, dynamic> out = {};
    List<Map<String, dynamic>> puntos = [];
    for (LatLngCHEST point in _points) {
      puntos.add(point.toMap());
    }
    out['track'] = puntos;
    return out;
  }

  /// Cálcula los límites del [Track] a partir de sus [points]
  void calculateBounds() {
    double sup = -90;
    double inf = 90;
    double izq = 180;
    double der = -180;

    for (LatLngCHEST p in points) {
      sup = p.lat > sup ? p.lat : sup;
      inf = p.lat < inf ? p.lat : inf;
      izq = p.long < izq ? p.long : izq;
      der = p.long > der ? p.long : der;
    }

    _northWest = LatLng(sup, izq);
    _southEast = LatLng(inf, der);
  }
}

/// Clase que permite registrar las coordenadas de un evento (instante temporal)
class LatLngCHEST {
  late double _lat, _long;
  late double? _alt;
  late DateTime? _timestamp;

  /// Constructor de la clase. Es obligaotrio que tenga latitud [lat] y longitud [long]. Opcionalmente, se puede agregar una altura [alt] y el instante de recogida [timestamp]
  LatLngCHEST(
      {required double lat,
      required double long,
      double? alt,
      DateTime? timestamp}) {
    if (lat >= -90 || lat <= 90) {
      _lat = lat;
    } else {
      throw LatLngCHESTException('lat < -90 || lat > 90');
    }
    if (long >= -180 || long <= 180) {
      _long = long;
    } else {
      throw LatLngCHESTException('long < -180 || long > 180');
    }
    if (alt != null) {
      _alt = alt;
    } else {
      _alt = null;
    }
    if (timestamp != null) {
      _timestamp = timestamp;
    } else {
      _timestamp = null;
    }
  }

  LatLngCHEST.server(dynamic data) {
    if (data is Map &&
        data.containsKey('lat') &&
        data['lat'] is double &&
        data.containsKey('long') &&
        data['long'] is double) {
      if (data['lat'] >= -90 || data['lat'] <= 90) {
        _lat = data['lat'];
      } else {
        throw LatLngCHESTException('lat < -90 || lat > 90');
      }
      if (data['long'] >= -180 || data['long'] <= 180) {
        _long = data['long'];
      } else {
        throw LatLngCHESTException('long < -180 || long > 180');
      }
      _alt = null;
      // if (data.containsKey('alt')) {
      //   if (data[alt] is double) {
      //     _alt = alt;
      //   } else {
      //     if (data['alt'] is String) {
      //       try {
      //         _alt = alt;
      //       } catch (e) {
      //         _alt = null;
      //       }
      //     } else {
      //       _alt = null;
      //     }
      //   }
      // } else {
      //   _alt = null;
      // }
      if (data.containsKey('timestamp') && data['timestamp'] is DateTime) {
        _timestamp = timestamp;
      } else {
        _timestamp = null;
      }
    } else {
      LatLngCHESTException('data is not valid');
    }
  }

  /// Devuelve la latitud
  double get lat => _lat;

  /// Devuelve la longitud
  double get long => _long;

  /// Devuelve la altura. Puede ser null si no se ha proporcionado previamente
  double? get alt => _alt;

  /// Permite establecer la altura
  set alt(double? alt) {
    if (alt != null) {
      _alt = alt;
    }
  }

  /// Permite recuerar el instante del evento. Puede ser null si no se ha inicializado
  DateTime? get timestamp => _timestamp;

  /// Establece el instante temporal del evento
  set timestamp(DateTime? timestamp) {
    if (timestamp != null) {
      _timestamp = timestamp;
    }
  }

  /// Recupera las coordenadas en un objeto [LatLng]
  LatLng get toLatLng => LatLng(lat, long);

  /// Devuelve el contenido del objeto en un mapa
  Map<String, dynamic> toMap() {
    Map<String, dynamic> out = {
      'lat': lat,
      'long': long,
    };
    if (alt != null) {
      out['alt'] = alt!;
    }
    if (timestamp != null) {
      out['timestamp'] = timestamp!.toIso8601String();
    }
    return out;
  }
}
