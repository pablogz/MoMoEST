import 'package:momoest/util/exceptions.dart';
import 'package:momoest/util/helpers/pair.dart';

class Category {
  final String _iri;
  late List<PairLang> _label;
  late List<String> _broader;
  Category(this._iri) {
    _label = [];
    _broader = [];
  }

  String get iri => _iri;
  List<PairLang> get label => _label;
  set label(dynamic label) {
    if (label is String || label is Map || label is List) {
      if (label is String) {
        _label.add(PairLang.withoutLang(label));
      } else {
        if (label is Map) {
          label.forEach((key, value) => _label.add(PairLang(key, value)));
        } else {
          String langF = '';
          bool hasLangF = false;
          dynamic valueF = '';
          for (Map l in label) {
            l.forEach((key, value) {
              if (key == 'lang') {
                hasLangF = true;
                langF = value;
              } else {
                if (key == 'value') {
                  valueF = value;
                }
              }
            });
          }
          if (hasLangF) {
            _label.add(PairLang(langF, valueF));
          } else {
            _label.add(PairLang.withoutLang(valueF));
          }
        }
      }
    } else {
      throw CategoryException("label");
    }
  }

  List<String> get broader => _broader;
  set broader(dynamic broader) {
    if (broader is List) {
      for (var element in broader) {
        _broader.add(element.toString());
      }
    } else {
      _broader.add(broader.toString());
    }
  }

  int _findIndexBroader(String broader) {
    return _broader.indexOf("broader");
  }

  bool addBroader(String broader) {
    if (_findIndexBroader(broader) == -1) {
      _broader.add(broader);
      return true;
    }
    return false;
  }

  bool deleteBroader(String broader) {
    if (_findIndexBroader(broader) > -1) {
      _broader.removeWhere((element) => element == broader);
      return true;
    }
    return false;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> out = {};
    out['iri'] = iri;
    if (label.isNotEmpty) {
      List<Map<String, dynamic>> aux = [];
      for (PairLang l in label) {
        aux.add(l.toMap());
      }
      out['label'] = aux;
    }
    if (broader.isNotEmpty) {
      out['broader'] = broader;
    }
    return out;
  }
}
