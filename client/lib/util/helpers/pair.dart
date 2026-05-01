class PairLang {
  late String _lang;
  final List<String> _value = [];
  PairLang(this._lang, value) {
    if (value is List) {
      for (String ele in value) {
        _value.add(ele);
      }
    } else {
      _value.add(value.toString());
    }
  }

  PairLang.withoutLang(value) {
    _lang = "";
    if (value is List) {
      for (String ele in value) {
        _value.add(ele);
      }
    } else {
      _value.add(value.toString());
    }
  }

  bool get hasLang => _lang.isNotEmpty;
  String get lang => _lang;
  //TODO CADA IDIOMA PUEDE TENER MÁS DE UN VALOR!!!
  String get value => _value.first;

  Map<String, dynamic> toJson() => toMap();

  Map<String, String> toMap() =>
      hasLang ? {'value': value, 'lang': lang} : {'value': value};
}

class PairImage {
  late final String _image;
  String _license = "";
  late bool hasLicense;
  PairImage(image, this._license) {
    _image = image.replaceFirst('http://', 'https://');
    hasLicense = (_license.trim().isNotEmpty);
  }

  PairImage.withoutLicense(image) {
    _image = image.replaceFirst('http://', 'https://');
    hasLicense = false;
  }

  String get image => _image;
  String get license => _license;

  Map<String, dynamic> toMap({bool? isThumb}) => isThumb != null
      ? hasLicense
          ? {'image': image, 'license': license, 'thumbnail': isThumb}
          : {'image': image, 'thumbnail': isThumb}
      : hasLicense
          ? {'image': image, 'license': license}
          : {'image': image};
}

class DocomomoMedia {
  final String id, link, urlDocomomo;
  final String? label;

  DocomomoMedia({
    required this.id,
    required this.link,
    required this.urlDocomomo,
    this.label,
  });

  factory DocomomoMedia.fromMap(Map<String, dynamic> data) {
    String? lbl;
    if (data.containsKey('label')) {
      final l = data['label'];
      lbl = l is Map ? l['value']?.toString() : l?.toString();
    }
    return DocomomoMedia(
      id: data['media'].toString(),
      link: data['link'].toString(),
      urlDocomomo: data['urlDocomomo'].toString(),
      label: lbl,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'link': link,
        'urlDocomomo': urlDocomomo,
        if (label != null) 'label': label,
      };

  Map<String, dynamic> toJson() => toMap();
}

class DocomomoArchitect {
  final String id;
  final String? name, link;

  DocomomoArchitect({required this.id, this.name, this.link});

  factory DocomomoArchitect.fromMap(Map<String, dynamic> data) {
    String? name;
    if (data.containsKey('label')) {
      final l = data['label'];
      name = l is Map ? l['value']?.toString() : l?.toString();
    }
    return DocomomoArchitect(
      id: data['arq'].toString(),
      name: name,
      link: data.containsKey('arqLink') ? data['arqLink'].toString() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        if (name != null) 'name': name,
        if (link != null) 'link': link,
      };

  Map<String, dynamic> toJson() => toMap();
}

class ElementLabels {
  final String idElement;
  late List<PairLang> _labels;
  ElementLabels(this.idElement, List sLabels) {
    _labels = [];
    if (sLabels.isNotEmpty) {
      for (dynamic label in sLabels) {
        if (label is PairLang) {
          _labels.add(label);
        } else {
          if (label is Map && label.containsKey('value')) {
            if (label.containsKey('lang')) {
              _labels.add(PairLang(label['lang'], label['value']));
            } else {
              _labels.add(PairLang.withoutLang(label['value']));
            }
          }
        }
      }
    }
  }

  List<PairLang> get labels => _labels;

  Map<String, dynamic> toJson() => toMap();
  Map<String, dynamic> toMap() {
    List<Map<String, dynamic>> l = [];
    for (PairLang pl in labels) {
      l.add(pl.toMap());
    }
    return {
      'id': idElement,
      'labels': l,
    };
  }
}
