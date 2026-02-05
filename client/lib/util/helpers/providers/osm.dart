import 'package:momoest/util/helpers/pair.dart';
import 'package:latlong2/latlong.dart';

class OSM {
  final String provider = 'osm';
  late TypeOSM _typeOSM;
  late String _id, _shortId;
  late double _lat, _long;
  late List<TagOSM> _tags;
  String? _author, _license, _wikipedia;
  late List<Map<String, double>> _geometry;
  late List<PairLang> _labels, _descriptions;
  PairImage? _image;

  OSM(Map<String, dynamic>? data) {
    try {
      if (data == null) {
        throw Exception('Problem with data: it\'s null!! OSM constructor');
      } else {
        if (data.containsKey('id')) {
          _id = data['id'].toString();
        } else {
          throw Exception('Problem with id in OSM constructor');
        }
        if (data.containsKey('shortId')) {
          _shortId = data['shortId'].toString();
        } else {
          throw Exception('Problem with shortId in OSM constructor');
        }
        switch (shortId.split(':')[0]) {
          case 'osmn':
            _typeOSM = TypeOSM.node;
            break;
          case 'osmw':
            _typeOSM = TypeOSM.way;
            break;
          case 'osmr':
            _typeOSM = TypeOSM.relation;
            break;
          default:
            throw Exception('Problem with OSMType in OSM constructor');
        }
        if (data.containsKey('lat')) {
          double tempLat = data['lat'];
          if (tempLat < -90 || tempLat > 90) {
            throw Exception('Problem with lat in OSM constructor');
          } else {
            _lat = tempLat;
          }
        } else {
          throw Exception('Problem with lat in class OSM');
        }
        if (data.containsKey('long')) {
          double tempLong = data['long'];
          if (tempLong < -180 || tempLong > 180) {
            throw Exception('Problem with long in OSM constructor');
          } else {
            _long = tempLong;
          }
        } else {
          throw Exception('Problem with long in OSM constructor');
        }
        if (data.containsKey('author')) {
          _author = data['author'].toString().replaceAll('OSM - ', '');
        }
        if (data.containsKey('license')) {
          _license = data['license'].toString();
        }
        if (data.containsKey('wikipedia')) {
          _wikipedia = data['wikipedia'].toString();
        }

        try {
          Map tagsServer = data['tags'];
          _tags = [];
          for (String key in tagsServer.keys) {
            _tags.add(TagOSM(key, tagsServer[key]));
          }
          int indexImage =
              _tags.indexWhere((TagOSM element) => element.key == 'image');
          if (indexImage > -1) {
            String imageTmp =
                _tags[indexImage].value.replaceFirst('http://', 'https://');
            if (imageTmp.contains('commons.wikimedia.org/wiki/File:')) {
              _image = PairImage(imageTmp,
                  imageTmp.replaceFirst('File:', 'Special:FilePath/'));
            } else {
              _image = PairImage.withoutLicense(imageTmp);
            }
          }
        } catch (error) {
          throw Exception('Tags problem in OSM constructor');
        }

        _geometry = [];
        if (data.containsKey('geometry') && data['geometry'] is List) {
          double geoLat, geoLong;
          for (dynamic geo in data['geometry']) {
            if (geo is Map &&
                geo.containsKey('lat') &&
                geo.containsKey('long')) {
              geoLat = geo['lat'] is double
                  ? geo['lat']
                  : throw Exception(
                      'Problem with geoLat ${geo['lat']} in OSM constructor');
              geoLong = geo['long'] is double
                  ? geo['long']
                  : throw Exception(
                      'Problem with geoLong ${geo['long']} in OSM constructor');
              if (geoLat <= 90 &&
                  geoLat >= -90 &&
                  geoLong <= 180 &&
                  geoLong >= -180) {
                _geometry.add({'lat': geoLat, 'long': geoLong});
              }
            }
          }
        }

        _labels = [];
        if (data.containsKey('labels') && data['labels'] is List) {
          for (dynamic label in data['labels']) {
            if (label is Map && label.containsKey('value')) {
              if (label.containsKey('lang')) {
                _labels.add(PairLang(label['lang'], label['value']));
              } else {
                _labels.add(PairLang.withoutLang(label['value']));
              }
            }
          }
        }
        _descriptions = [];
        if (data.containsKey('descriptions') && data['descriptions'] is List) {
          for (dynamic label in data['descriptions']) {
            if (label is Map && label.containsKey('value')) {
              if (label.containsKey('lang')) {
                _descriptions.add(PairLang(label['lang'], label['value']));
              } else {
                _descriptions.add(PairLang.withoutLang(label['value']));
              }
            }
          }
        }
      }
    } catch (error) {
      throw Exception(error.toString());
    }
  }

  TypeOSM get type => _typeOSM;
  String get id => _id;
  String get shortId => _shortId;
  double get lat => _lat;
  double get long => _long;
  LatLng get point => LatLng(_lat, _long);
  List get geometry => _geometry;
  List get tags => _tags;
  String? get wikipedia => _wikipedia;
  String? get author => _author;
  String? get license => _license;
  List<PairLang> get labels => _labels;
  List<PairLang> get descriptions => _descriptions;
  PairImage? get image => _image;
  String get textProvider => "OpenStreetMap";

  Map<String, dynamic> toSourceInfo() {
    Map<String, dynamic> out = {
      'id': id,
      'shortId': shortId,
      'typeOSM': type.name,
      'lat': lat,
      'long': long
    };
    if (author != null) {
      out['author'] = author;
    }
    if (wikipedia != null) {
      out['wikipedia'] = wikipedia;
    }
    if (license != null) {
      out['license'] = license;
    }
    if (labels.isNotEmpty) {
      out['labels'] = [];
      for (PairLang lbl in labels) {
        out['labels'].add(lbl.toMap());
      }
    }
    if (descriptions.isNotEmpty) {
      out['descriptions'] = [];
      for (PairLang lbl in descriptions) {
        out['descriptions'].add(lbl.toMap());
      }
    }
    if (tags.isNotEmpty) {
      out['tags'] = {};
      for (TagOSM tag in tags) {
        out['tags'][tag.key] = tag.value;
      }
    }
    if (image != null) {
      out['image'] = image!.toMap();
    }
    return out;
  }

  Map<String, dynamic> toJson() => toSourceInfo();
}

enum TypeOSM { node, way, relation }

class TagOSM {
  late final String _key;
  late final dynamic _value;
  TagOSM(this._key, this._value);
  String get key => _key;
  dynamic get value => _value;
  Map<String, dynamic> toMap() {
    return {key: value};
  }
}
