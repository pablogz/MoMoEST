import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/map_layer.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/helpers/answers.dart';
import 'package:momoest/util/helpers/pair.dart';
import 'package:momoest/util/exceptions.dart';
import 'package:momoest/util/queries.dart';

class UserXEST {
  static UserXEST userXEST = UserXEST.guest();
  static bool allowNewUser = false;
  static bool allowManageUser = false;

  late String _id;
  late String? _alias, _email, _lang, _feedId;
  late Set<Rol> _rol;
  late List<PairLang>? _comment;
  late Rol _cRol;
  late bool _consentimientoInformado;
  List<Answer> answers = [];
  late LastPosition lastMapView;
  late Layers defaultMap;

  UserXEST.guest() {
    _id = '';
    _alias = null;
    _comment = null;
    _email = null;
    _lang = null;
    _feedId = null;
    _rol = {Rol.guest};
    _cRol = _rol.first;
    _consentimientoInformado = false;
    lastMapView = LastPosition.empty();
    defaultMap = Layers.carto;
  }

  UserXEST(dynamic data) {
    try {
      if (data != null && data is Map) {
        if (data.containsKey('id') &&
            data['id'] is String &&
            data['id'].toString().trim().isNotEmpty) {
          _id = data['id'].toString().trim();
        } else {
          throw UserXESTException("User data: problem with id");
        }

        if (data.containsKey('rol') &&
            (data['rol'] is String ||
                data['rol'] is Set ||
                data['rol'] is List)) {
          _rol = {};
          if (data['rol'] is String) {
            data['rol'] = {data['rol']};
          }
          for (String rS in data['rol']) {
            switch (rS) {
              case 'USER':
              case 'STUDENT':
                _rol.add(Rol.user);
                break;
              case 'TEACHER':
                _rol.add(Rol.teacher);
                break;
              case 'ADMIN':
                _rol.add(Rol.admin);
                break;
              default:
                throw UserXESTException('Rol not supported');
            }
          }
          _cRol = _rol.contains(Rol.admin)
              ? Rol.admin
              : _rol.contains(Rol.teacher)
                  ? Rol.teacher
                  : _rol.contains(Rol.user)
                      ? Rol.user
                      : throw UserXESTException('Problem with crol');
        } else {
          throw UserXESTException('Problem with rol');
        }

        // Opcionales
        _consentimientoInformado = data.containsKey('consentimientoInformado') &&
            data['consentimientoInformado'] == true;
        _alias = data.containsKey('alias') && data['alias'] is String
            ? trim(data['alias'])
            : null;
        _comment = null;
        if (data.containsKey('comment')) {
          if (data['comment'] is Map) {
            data['comment'] = [data['comment']];
          }
          if (data['comment'] is List) {
            for (Map<String, dynamic> d in data['comment']) {
              if (d.containsKey('value') && d.containsKey('lang')) {
                _comment ??= [];
                _comment!.add(PairLang(d['lang'], d['value']));
              } else if (d.containsKey('value')) {
                _comment ??= [];
                _comment!.add(PairLang.withoutLang(d['value']));
              }
            }
            if (_comment != null && _comment!.isEmpty) {
              _comment = null;
            }
          }
        }
        if (data.containsKey('lastMapView') &&
            data['lastMapView'] is Map &&
            (data['lastMapView'] as Map).containsKey('lat') &&
            (data['lastMapView'] as Map)['lat'] is double &&
            (data['lastMapView'] as Map).containsKey('long') &&
            (data['lastMapView'] as Map)['long'] is double &&
            (data['lastMapView'] as Map).containsKey('zoom') &&
            (data['lastMapView'] as Map)['zoom'] is num) {
          lastMapView = LastPosition(
              (data['lastMapView'] as Map)['lat'],
              (data['lastMapView'] as Map)['long'],
              (data['lastMapView'] as Map)['zoom']);
        } else {
          lastMapView = LastPosition.empty();
        }
        if (data.containsKey('defaultMap')) {
          switch (data['defaultMap']) {
            case 'satellite':
              defaultMap = Layers.satellite;
              break;
            default:
              defaultMap = Layers.carto;
              break;
          }
        } else {
          defaultMap = Layers.carto;
        }
        MapLayer.layer = defaultMap;
        // _email = data.containsKey('email') && data['email'] is String
        //     ? trim(data['email'])
        //     : null;

        if (data.containsKey('lang')) {
          _lang = data['lang'];
        } else {
          _lang = 'en';
        }

        if (data.containsKey('feed')) {
          _feedId = data['feed'];
        } else {
          _feedId = null;
        }
      } else {
        throw UserXESTException('User data is null or is not a Map');
      }
    } catch (e, stack) {
      if (ConfigXest.development) {
        debugPrint(e.toString());
        throw UserXESTException(e.toString());
      } else {
        FirebaseCrashlytics.instance.recordError(e, stack);
      }
    }
  }

  String get id => _id;
  String get iri => 'http://moult.gsic.uva.es/data/$_id';
  Rol get crol => _cRol;
  set crol(Rol rol) {
    if (_rol.contains(rol)) {
      _cRol = rol;
    } else {
      throw UserXESTException('Forbidden');
    }
  }

  Set<Rol> get rol => _rol;

  bool get consentimientoInformado => _consentimientoInformado;

  String? get alias => _alias;
  set alias(String? alias) {
    _alias = trim(alias);
  }

  List<PairLang>? get comment => _comment;
  // set comment(List<PairLang>? comment) {
  //   _comment = comment;
  // }
  bool addComment(PairLang pairLang) {
    if (_comment != null) {
      bool encontrado = false;
      for (PairLang c in _comment!) {
        if (c.hasLang && pairLang.lang == c.lang) {
          encontrado = true;
          break;
        }
      }
      if (!encontrado) {
        _comment ??= [];
        _comment!.add(pairLang);
      }
      return !encontrado;
    } else {
      _comment = [pairLang];
      return true;
    }
  }

  String? getComment(String lang) {
    if (_comment != null) {
      int index = _comment!
          .indexWhere((element) => element.hasLang && element.lang == lang);
      return index > -1 ? _comment!.elementAt(index).value : null;
    }
    return null;
  }

  String? get email => _email;
  set email(String? email) {
    _email = trim(email);
  }

  String? trim(String? s) {
    if (s == null) {
      return s;
    }
    String t = s.trim();
    return t.isNotEmpty ? t : '';
  }

  String get lang => _lang ?? 'en';
  set lang(String lang) {
    _lang = lang;
  }

  bool get isGuest => _rol.contains(Rol.guest);
  bool get isNotGuest => !_rol.contains(Rol.guest);

  bool get canEdit => _rol.contains(Rol.teacher) || _rol.contains(Rol.admin);
  bool get canEditNow => _cRol == Rol.teacher || _cRol == Rol.admin;

  bool get hasFeedEnable => _feedId != null && _feedId!.isNotEmpty;
  String get feed =>
      _feedId != null ? _feedId! : throw UserXESTException('No feed enabled');

  /// Activa el canal [feed] persistiéndolo en el servidor. Devuelve true si
  /// el servidor confirma el cambio; en caso contrario no muta el estado.
  Future<bool> enableFeed(String feed) async {
    if (feed.trim().isEmpty) {
      return false;
    }
    try {
      final response = await http.put(
        Queries.activeFeed(),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}',
        },
        body: json.encode({'idFeed': Auxiliar.id2shortId(feed.trim())}),
      );
      if (response.statusCode == 204) {
        _feedId = feed.trim();
        return true;
      }
      return false;
    } catch (error) {
      if (ConfigXest.development) {
        debugPrint(error.toString());
      }
      return false;
    }
  }

  /// Desactiva el canal activo persistiendo el cambio en el servidor.
  /// Devuelve true si el servidor confirma el cambio.
  Future<bool> disableFeed() async {
    try {
      final response = await http.put(
        Queries.activeFeed(),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}',
        },
        body: json.encode({'idFeed': null}),
      );
      if (response.statusCode == 204) {
        _feedId = null;
        return true;
      }
      return false;
    } catch (error) {
      if (ConfigXest.development) {
        debugPrint(error.toString());
      }
      return false;
    }
  }

  /// Limpia el canal activo solo en memoria. Útil cuando el servidor ya lo ha
  /// limpiado (p.ej. al darse de baja de un canal).
  void disableFeedLocal() {
    _feedId = null;
  }
}

enum Rol { user, teacher, admin, guest }

class LastPosition {
  late LatLng _point;
  late double _zoom;
  late bool _init;

  LastPosition.empty() {
    _init = false;
  }

  LastPosition(double lat, double long, num zoom) {
    _point = LatLng(lat, long);
    _zoom = zoom.toDouble();
    _init = true;
  }

  double? get lat => _init ? _point.latitude : null;
  double? get long => _init ? _point.longitude : null;
  LatLng? get point => _init ? _point : null;
  double? get zoom => _init ? _zoom : null;
  bool get init => _init;

  Map<String, dynamic>? toJSON() {
    return _init
        ? {
            'lat': lat,
            'long': long,
            'zoom': zoom,
          }
        : null;
  }
}
