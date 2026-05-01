import 'package:momoest/util/helpers/pair.dart';
import 'package:latlong2/latlong.dart';

class Docomomo {
  final String provider = 'docomomo';
  final String license = 'Fundación Docomomo Ibérico';
  late String _id, _shortId;
  late double _lat, _long;
  late List<PairLang> _labels;
  late List<PairLang> _comments;
  late List<String> _type;
  String? _startDate, _endDate, _thumb;
  late List<String> _seeAlso;
  late List<DocomomoMedia> _media;
  late List<DocomomoArchitect> _architects;

  Docomomo(Map<String, dynamic>? data) {
    try {
      if (data == null) {
        throw Exception('Data it\'s null!!');
      } else {
        if (data.containsKey('id')) {
          _id = data['id'].toString();
        } else {
          throw Exception('Id');
        }
        if (data.containsKey('shortId')) {
          _shortId = data['shortId'].toString();
        } else {
          throw Exception('ShortId');
        }
        if (data.containsKey('lat')) {
          double tempLat = data['lat'];
          if (tempLat < -90 || tempLat > 90) {
            throw Exception('Lat');
          } else {
            _lat = tempLat;
          }
        } else {
          throw Exception('Lat');
        }
        if (data.containsKey('long')) {
          double tempLong = data['long'];
          if (tempLong < -180 || tempLong > 180) {
            throw Exception('Long');
          } else {
            _long = tempLong;
          }
        } else {
          throw Exception('Long');
        }

        _labels = [];
        if (data.containsKey('labels') && data['labels'] is Map) {
          data['labels'] = [data['labels']];
        }
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
        } else {
          throw Exception('Labels');
        }

        _comments = [];
        if (data.containsKey('comments') && data['comments'] is Map) {
          data['comments'] = [data['comments']];
        }
        if (data.containsKey('comments') && data['comments'] is List) {
          for (dynamic comment in data['comments']) {
            if (comment is Map && comment.containsKey('value')) {
              if (comment.containsKey('lang')) {
                _comments.add(PairLang(comment['lang'], comment['value']));
              } else {
                _comments.add(PairLang.withoutLang(comment['value']));
              }
            }
          }
        }

        _type = [];
        if (data.containsKey('type')) {
          if (data['type'] is String) {
            data['type'] = [data['type']];
          }
          if (data['type'] is List) {
            for (dynamic d in data['type']) {
              _type.add(d.toString());
            }
          }
        }

        _startDate =
            data.containsKey('startDate') ? data['startDate']?.toString() : null;
        _endDate =
            data.containsKey('endDate') ? data['endDate']?.toString() : null;
        _thumb =
            data.containsKey('thumb') ? data['thumb']?.toString() : null;

        _seeAlso = [];
        if (data.containsKey('seeAlso')) {
          if (data['seeAlso'] is String) {
            data['seeAlso'] = [data['seeAlso']];
          }
          if (data['seeAlso'] is List) {
            for (dynamic url in data['seeAlso']) {
              _seeAlso.add(url.toString());
            }
          }
        }

        _media = [];
        if (data.containsKey('media') && data['media'] is List) {
          for (dynamic item in data['media']) {
            if (item is Map &&
                item.containsKey('media') &&
                item.containsKey('link') &&
                item.containsKey('urlDocomomo')) {
              _media.add(DocomomoMedia.fromMap(Map<String, dynamic>.from(item)));
            }
          }
        }

        _architects = [];
        if (data.containsKey('architects') && data['architects'] is List) {
          for (dynamic item in data['architects']) {
            if (item is Map && item.containsKey('arq')) {
              _architects.add(
                  DocomomoArchitect.fromMap(Map<String, dynamic>.from(item)));
            }
          }
        }
      }
    } catch (e) {
      throw Exception('Problem in Docomomo constructor: ${e.toString()}');
    }
  }

  String get id => _id;
  String get shortId => _shortId;
  double get lat => _lat;
  double get long => _long;
  List<PairLang> get labels => _labels;
  List<PairLang> get comments => _comments;
  LatLng get point => LatLng(lat, long);
  List<String> get types => _type;
  String? get startDate => _startDate;
  String? get endDate => _endDate;
  String? get thumb => _thumb;
  List<String> get seeAlso => _seeAlso;
  List<DocomomoMedia> get media => _media;
  List<DocomomoArchitect> get architects => _architects;

  Map<String, dynamic> toSourceInfo() {
    final Map<String, dynamic> out = {
      'id': id,
      'shortId': shortId,
      'provider': provider,
      'license': license,
      'lat': lat,
      'long': long,
    };
    out['labels'] = [for (PairLang lbl in labels) lbl.toMap()];
    out['comments'] = [for (PairLang c in comments) c.toMap()];
    if (_type.isNotEmpty) out['types'] = types;
    if (_startDate != null) out['startDate'] = _startDate;
    if (_endDate != null) out['endDate'] = _endDate;
    if (_thumb != null) out['thumb'] = _thumb;
    if (_seeAlso.isNotEmpty) out['seeAlso'] = _seeAlso;
    if (_media.isNotEmpty) out['media'] = [for (DocomomoMedia m in _media) m.toMap()];
    if (_architects.isNotEmpty) {
      out['architects'] = [for (DocomomoArchitect a in _architects) a.toMap()];
    }
    return out;
  }

  Map<String, dynamic> toJson() => toSourceInfo();
}
