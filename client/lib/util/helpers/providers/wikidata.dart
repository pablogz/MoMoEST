import 'package:momoest/util/helpers/pair.dart';

class Wikidata {
  final String provider = 'wikidata';
  late String _id, _shortId;
  late List<PairLang> _labels, _descriptions;
  late List<PairImage> _images;
  late List<String> _types;
  late List<ElementLabels> _arcStyles;
  DateTime? _inception;
  double? _lat, _long;
  String? idBIC;

  Wikidata(Map<String, dynamic>? data) {
    try {
      if (data == null) {
        throw Exception('Problem with data: it\'s null!! Wikidata constructor');
      } else {
        if (data.containsKey('id')) {
          _id = data['id'].toString();
        } else {
          throw Exception('Problem with id in Wikidata constructor');
        }
        if (data.containsKey('shortId')) {
          _shortId = data['shortId'].toString();
        } else {
          throw Exception('Problem with shortId in Wikidata constructor');
        }

        _types = [];
        if (data.containsKey('type')) {
          if (data['type'] is String) {
            data['type'] = [data['type']];
          }
          if (data['type'] is List) {
            for (dynamic t in data['type']) {
              _types.add(t.toString());
            }
          } else {
            throw Exception('Problem with type in Wikidata constructor');
          }
        } else {
          throw Exception('Problem with type in Wikidata constructor');
        }

        if (data.containsKey('lat')) {
          double tempLat = data['lat'];
          if (tempLat < -90 || tempLat > 90) {
            throw Exception('Problem with lat in Wikidata constructor');
          } else {
            _lat = tempLat;
          }
        }
        if (data.containsKey('long')) {
          double tempLong = data['long'];
          if (tempLong < -180 || tempLong > 180) {
            throw Exception('Problem with long in Wikidata constructor');
          } else {
            _long = tempLong;
          }
        }

        if (data.containsKey('inception')) {
          if (data['inception'] is List) {
            data['inception'] = (data['inception'] as List).first;
          }
          _inception = DateTime.fromMicrosecondsSinceEpoch(data['inception']);
        }

        List<String> labelDescription = ['label', 'description'];
        _labels = [];
        _descriptions = [];
        for (String key in labelDescription) {
          if (data.containsKey(key)) {
            if (data[key] is Map) {
              data[key] = [data[key]];
            }
            if (data[key] is List) {
              for (dynamic label in data[key]) {
                if (label is Map && label.containsKey('value')) {
                  switch (key) {
                    case 'label':
                      if (label.containsKey('lang')) {
                        _labels.add(PairLang(label['lang'], label['value']));
                      } else {
                        _labels.add(PairLang.withoutLang(label['value']));
                      }
                      break;
                    case 'description':
                      if (label.containsKey('lang')) {
                        _descriptions
                            .add(PairLang(label['lang'], label['value']));
                      } else {
                        _descriptions.add(PairLang.withoutLang(label['value']));
                      }
                      break;
                    default:
                  }
                }
              }
            } else {
              throw Exception('Problem with $key in Wikidata constructor');
            }
          }
        }

        _images = [];
        if (data.containsKey('image')) {
          if (data['image'] is Map) {
            data['image'] = [data['image']];
          }
          if (data['image'] is List) {
            for (dynamic img in data['image']) {
              if (img is Map && img.containsKey('f')) {
                if (img.containsKey('l')) {
                  _images.add(PairImage(img['f'], img['l']));
                } else {
                  _images.add(PairImage.withoutLicense(img['f']));
                }
              }
            }
          } else {
            throw Exception('Problem with image in Wikidata constructor');
          }
        }

        _arcStyles = [];
        if (data.containsKey('arcStyle')) {
          if (data['arcStyle'] is Map) {
            data['arcStyle'] = [data['arcStyle']];
          }
          if (data['arcStyle'] is List) {
            for (dynamic style in data['arcStyle']) {
              if (style is Map && style.containsKey('id')) {
                _arcStyles.add(ElementLabels(style['id'],
                    style.containsKey('labels') ? style['labels'] : []));
              }
            }
          } else {
            throw Exception('Problem with arcStyle in Wikidata constructor');
          }
        }

        if (data.containsKey('bicJCyL')) {
          idBIC = data['bicJCyL'];
        }
      }
    } catch (error) {
      throw Exception(error);
    }
  }

  String get id => _id;
  String get shortId => _shortId;
  List<PairLang> get labels => _labels;
  List<PairLang> get descriptions => _descriptions;
  List<PairImage> get images => _images;
  List<String> get types => _types;
  List<ElementLabels> get arcStyles => _arcStyles;
  DateTime? get inception => _inception;
  double? get lat => _lat;
  double? get long => _long;
  String get textProvider => "Wikidata";

  Map<String, dynamic> toSourceInfo() {
    Map<String, dynamic> out = {
      'id': id,
      'shortId': shortId,
      'type': types,
    };

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
    if (images.isNotEmpty) {
      out['image'] = [];
      for (PairImage img in images) {
        out['image'].add(img.toMap());
      }
    }
    if (arcStyles.isNotEmpty) {
      out['arcStyles'] = [];
      for (ElementLabels aS in arcStyles) {
        out['arcStyles'].add(aS.toMap());
      }
    }
    if (inception != null) {
      out['inception'] = inception!.microsecondsSinceEpoch;
    }
    if (lat != null) {
      out['lat'] = lat;
    }
    if (long != null) {
      out['long'] = long;
    }

    if (idBIC != null) {
      out['bicJCyL'] = idBIC;
    }

    return out;
  }

  Map<String, dynamic> toJson() => toSourceInfo();
}
