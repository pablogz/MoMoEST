import 'package:momoest/util/helpers/pair.dart';
import 'package:latlong2/latlong.dart';

class LocalRepo {
  final String provider = 'localRepo';
  late String _id, _shortId, _author, _license;
  late double _lat, _long;
  late List<PairLang> _labels, _comments;
  late List<String> _type;

  LocalRepo(Map<String, dynamic>? data) {
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
          throw Exception('SorthId');
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
        if (data.containsKey('author')) {
          _author = data['author'].toString();
        } else {
          throw Exception('Author');
        }
        if (data.containsKey('license')) {
          _license = data['license'].toString();
        } else {
          throw Exception('License');
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
          for (dynamic label in data['comments']) {
            if (label is Map && label.containsKey('value')) {
              if (label.containsKey('lang')) {
                _comments.add(PairLang(label['lang'], label['value']));
              } else {
                _comments.add(PairLang.withoutLang(label['value']));
              }
            }
          }
        } else {
          throw Exception('Comments');
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
      }
    } catch (e) {
      throw Exception('Problem in LocalRepo constructor: ${e.toString()}');
    }
  }

  String get id => _id;
  String get shortId => _shortId;
  String get author => _author;
  String get license => _license;
  double get lat => _lat;
  double get long => _long;
  List<PairLang> get labels => _labels;
  List<PairLang> get comments => _comments;
  LatLng get point => LatLng(lat, long);
  List<String> get types => _type;

  Map<String, dynamic> toSourceInfo() {
    Map<String, dynamic> out = {
      'id': id,
      'shortId': shortId,
      'author': author,
      'license': license,
      'lat': lat,
      'long': long,
    };
    out['labels'] = [];
    for (PairLang lbl in labels) {
      out['labels'].add(lbl.toMap());
    }
    out['comments'] = [];
    for (PairLang lbl in comments) {
      out['comments'].add(lbl.toMap());
    }
    if (_type.isNotEmpty) {
      out['types'] = types.toString();
    }
    return out;
  }

  Map<String, dynamic> toJson() => toSourceInfo();
}
