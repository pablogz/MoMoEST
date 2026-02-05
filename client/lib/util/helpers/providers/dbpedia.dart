import 'package:momoest/util/helpers/pair.dart';

class DBpedia {
  final String provider;
  late String _id, _shortId;
  late List<PairLang> _labels, _descriptions;
  late List<String> _types;

  DBpedia(Map<String, dynamic>? data, this.provider) {
    try {
      if (data == null) {
        throw Exception(
            'Problem with data: it\'s null!! $provider constructor');
      } else {
        if (data.containsKey('id')) {
          _id = data['id'].toString();
        } else {
          throw Exception('Problem with id in $provider constructor');
        }
        if (data.containsKey('shortId')) {
          _shortId = data['shortId'].toString();
        } else {
          throw Exception('Problem with shortId in $provider constructor');
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
            throw Exception('Problem with type in $provider constructor');
          }
        } else {
          throw Exception('Problem with type in $provider constructor');
        }

        List<String> labelDescription = ['label', 'comment'];
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
                    case 'comment':
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
              throw Exception('Problem with $key in $provider constructor');
            }
          }
        }
      }
    } catch (error) {
      throw Exception(error);
    }
  }

  String get id => _id;
  String get shortId => _shortId;
  List<PairLang> get labels => _labels;
  List<String> get types => _types;
  List<PairLang> get descriptions => _descriptions;
  String get textProvider => provider;

  Map<String, dynamic> toSourceInfo() {
    Map<String, dynamic> out = {
      'id': id,
      'shortId': shortId,
      'type': types,
    };

    if (labels.isNotEmpty) {
      out['labels'] = [];
      for (PairLang l in labels) {
        out['labels'].add(l.toMap());
      }
    }
    if (descriptions.isNotEmpty) {
      out['descriptions'] = [];
      for (PairLang l in descriptions) {
        out['descriptions'].add(l.toMap());
      }
    }

    return out;
  }

  Map<String, dynamic> toJson() => toSourceInfo();
}
