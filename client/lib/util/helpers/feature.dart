import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/exceptions.dart';
import 'package:momoest/util/helpers/providers/dbpedia.dart';
import 'package:momoest/util/helpers/providers/docomomo.dart';
import 'package:momoest/util/helpers/providers/jcyl.dart';
import 'package:momoest/util/helpers/providers/local_repo.dart';
import 'package:momoest/util/helpers/providers/osm.dart';
import 'package:momoest/util/helpers/providers/wikidata.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:momoest/util/helpers/category.dart';
import 'package:momoest/util/helpers/pair.dart';

class Feature {
  late String _id, _author, _shortId, _original;
  final List<PairLang> _label = [], _comment = [];
  late PairImage _thumbnail;
  final List<PairImage> _image = [];
  late double _latitude, _longitude;
  late bool _hasThumbnail, inItinerary, _hasSource, _hasLocation, _hasRawImage;
  late String _source;
  final List<Category> _categories = [];
  final List<TagOSM> _tags = [];
  final List<LatLng> _geometry = [];
  final List<Provider> _providers = [];
  late bool ask4Resource;
  late Set<SpatialThingType>? _stt;
  late Uint8List _rawImage;

  Feature.empty(this._shortId) {
    _id = '';
    _shortId = '';
    _original = '';
    _author = '';
    _hasThumbnail = false;
    inItinerary = false;
    _hasSource = false;
    _hasLocation = false;
    ask4Resource = false;
    _hasRawImage = false;
    _stt = null;
  }

  Feature.point(this._latitude, this._longitude) {
    _id = '';
    _shortId = '';
    _author = '';
    _original = '';
    _hasThumbnail = false;
    inItinerary = false;
    _hasSource = false;
    _hasLocation = true;
    ask4Resource = false;
    _hasRawImage = false;
    _stt = null;
  }

  Feature.fromJSON(Map<String, dynamic> data) {
    Map<String, dynamic> st = {};
    data.forEach(
      (key, value) {
        switch (key) {
          case 'labels':
          case 'comments':
          case 'descriptions':
          case 'tags':
          case 'providers':
            st[key] = [];
            for (String s in value) {
              st[key].add(jsonDecode(s));
            }
            break;
          default:
            st[key] = value;
        }
      },
    );
    constructor(st);
  }

  Feature(dynamic data) {
    constructor(data);
  }

  void constructor(dynamic data) {
    try {
      if (data != null && data is Map) {
        if (data.containsKey('id') &&
            data['id'] is String &&
            data['id'].toString().isNotEmpty) {
          _id = data['id'];
        } else {
          throw FeatureException('id');
        }

        if (data.containsKey('shortId') &&
            data['shortId'] is String &&
            data['shortId'].toString().isNotEmpty) {
          _shortId = data['shortId'];
        } else {
          throw FeatureException('shortId');
        }

        if (data.containsKey('labels')) {
          if (data['labels'] is String) {
            data['labels'] = {'value': data['labels']};
          }
          setLabels(data['labels']);
        } else {
          throw FeatureException('labels');
        }

        if (data.containsKey('lat') && data['lat'] is double) {
          double latTemp = data['lat'];
          if (latTemp >= -90 && latTemp <= 90) {
            _hasLocation = true;
            _latitude = latTemp;
          } else {
            throw FeatureException('lat [-90, 90]');
          }
        } else {
          throw FeatureException('lat');
        }

        if (data.containsKey('long')) {
          double longTemp = data['long'];
          if (longTemp >= -180 && longTemp <= 180) {
            _longitude = longTemp;
          } else {
            throw FeatureException('long [-180, 180]');
          }
        } else {
          throw FeatureException('long');
        }

        //OPTIONALS
        if (data.containsKey('descriptions')) {
          data['comments'] = data['descriptions'];
        }
        if (data.containsKey('comment')) {
          data['comments'] = data['comment'];
        }
        if (data.containsKey('author')) {
          _author = data['author'].toString();
        } else {
          _author = (Random().nextDouble() * 256000).toString();
        }

        if (data.containsKey('comments')) {
          if (data['comments'] is String) {
            data['comments'] = {'value': data['comments']};
          }
          setComments(data['comments']);
        } else {
          setComments(data['labels']);
        }

        if (data.containsKey('original') &&
            data['original'] is String &&
            data['original'].isNotEmpty) {
          _original = data['original'].toString();
        } else {
          _original = '';
        }

        if (data.containsKey('thumbnailImg') &&
            data['thumbnailImg'].toString().isNotEmpty) {
          String imgTmp = data['thumbnailImg'].toString();
          String? licTmp;
          if (data.containsKey('thumbnailLic')) {
            licTmp = data['thumbnailLic'];
          } else {
            if (imgTmp.contains('commons.wikimedia.org/wiki/File:')) {
              licTmp = imgTmp;
              imgTmp = imgTmp
                  .replaceFirst('http://', 'https://')
                  .replaceFirst('File:', 'Special:FilePath/');
            }
          }
          setThumbnail(imgTmp, licTmp);
        } else {
          _hasThumbnail = false;
        }

        if (data.containsKey('tags')) {
          if (data['tags'] is Map) {
            for (var key in (data['tags'] as Map).keys) {
              _tags.add(TagOSM(key, data['tags'][key.toString()]));
            }
          }
        }

        if (_hasSource = data.containsKey('source')) {
          _source = data['source'];
          _hasSource = true;
        } else {
          _hasSource = false;
        }

        inItinerary = false;

        if (data.containsKey('categories')) {
          categories = data['categories'];
        }

        if (data.containsKey('geometry') && data['geometry'] is List) {
          bool sinErrores = true;
          List<LatLng> temp = [];
          for (int i = 0, tama = (data['geometry'] as List).length;
              i < tama;
              i++) {
            var ele = data['geometry'][i];
            if (ele is Map &&
                ele.containsKey('lat') &&
                ele['lat'] is double &&
                ele.containsKey('long') &&
                ele['long'] is double &&
                ele['lat'] <= 90 &&
                ele['lat'] >= -90 &&
                ele['long'] <= 180 &&
                ele['long'] >= -180) {
              temp.add(LatLng(ele['lat'], ele['long']));
            } else {
              sinErrores = false;
              break;
            }
          }
          if (sinErrores) {
            _geometry.addAll(temp);
          }
        }

        try {
          if (data.containsKey('provider')) {
            addProvider(data['provider'], data);
          } else {
            if (data.containsKey('providers') && data['providers'] is List) {
              for (Map<String, dynamic> provider in data['providers']) {
                if (provider.containsKey('provider')) {
                  providers.add(Provider(
                    provider['provider'],
                    provider['data'],
                    timestamp: provider['provider'] != null &&
                            provider['provider'] is int
                        ? DateTime.fromMicrosecondsSinceEpoch(
                            provider['provider'])
                        : null,
                  ));
                } else {
                  try {
                    providers.add(Provider(
                      provider['id'],
                      provider['data'].fromJSON(),
                      timestamp: DateTime.fromMicrosecondsSinceEpoch(
                          provider['timestamp']),
                    ));
                  } catch (error) {
                    // Voy a construir el Provedor a través de su tipo
                    switch (provider['id']) {
                      case 'osm':
                        providers.add(Provider(
                          provider['id'],
                          OSM(provider['data']),
                          timestamp: DateTime.fromMicrosecondsSinceEpoch(
                              provider['timestamp']),
                        ));
                        break;
                      case 'wikidata':
                        providers.add(Provider(
                          provider['id'],
                          Wikidata(provider['data']),
                          timestamp: DateTime.fromMicrosecondsSinceEpoch(
                              provider['timestamp']),
                        ));
                        break;
                      case 'esDBpedia':
                      case 'dbpedia':
                        providers.add(Provider(
                          provider['id'],
                          DBpedia(provider['data'], provider['id']),
                          timestamp: DateTime.fromMicrosecondsSinceEpoch(
                              provider['timestamp']),
                        ));
                        break;
                      case 'jcyl':
                        providers.add(Provider(
                          provider['id'],
                          JCyL(provider['data']),
                          timestamp: DateTime.fromMicrosecondsSinceEpoch(
                              provider['timestamp']),
                        ));
                        break;
                      case 'localRepo':
                        providers.add(Provider(
                          provider['id'],
                          LocalRepo(provider['data']),
                          timestamp: DateTime.fromMicrosecondsSinceEpoch(
                              provider['timestamp']),
                        ));
                        break;
                      case 'docomomo':
                        providers.add(
                          Provider(
                            provider['id'],
                            Docomomo(provider['data']),
                            timestamp: DateTime.fromMicrosecondsSinceEpoch(
                                provider['timestamp']),
                          ),
                        );
                        break;
                      default:
                        throw Exception('Provider?? ${provider['id']}');
                    }
                  }
                }
              }
            }
          }
        } catch (error, stackTrace) {
          if (ConfigXest.development) {
            debugPrint(error.toString());
          } else {
            FirebaseCrashlytics.instance.recordError(error, stackTrace);
          }
        }

        ask4Resource = false;

        if (data.containsKey('type') || data.containsKey('a')) {
          //Tipo de spatial thing
          _stt = {};
          if (data.containsKey('type')) {
            if (data['type'] is String) {
              data['type'] = [data['type']];
            }
            if (data['type'] is List) {
              for (dynamic ele in data['type']) {
                if (ele is String) {
                  ele = ele.split(ConfigXest.prefixApp).last;
                  if (ele != 'Feature') {
                    SpatialThingType? eleSTT = Auxiliar.getSpatialThing(ele);
                    if (eleSTT != null) {
                      _stt!.add(eleSTT);
                    } else {
                      throw FeatureException('$ele is not valid type');
                    }
                  }
                }
              }
            }
          }
          if (data.containsKey('a')) {
            if (data['a'] is String) {
              data['a'] = [data['a']];
            }
            if (data['a'] is List) {
              for (dynamic ele in data['a']) {
                if (ele is String) {
                  ele = ele.split(ConfigXest.prefixApp).last;
                  if (ele != 'Feature') {
                    SpatialThingType? eleSTT = Auxiliar.getSpatialThing(ele);
                    if (eleSTT != null) {
                      _stt!.add(eleSTT);
                    } else {
                      throw FeatureException('$ele is not valid type');
                    }
                  }
                }
              }
            }
          }
        } else {
          _stt = null;
        }
        _hasRawImage = false;
      }
    } catch (error) {
      throw FeatureException(error.toString());
    }
  }

  Feature.providers(this._shortId, List infoProviders) {
    _id = Auxiliar.shortId2Id(_shortId)!;
    _author = '';
    _hasThumbnail = false;
    inItinerary = false;
    _hasSource = false;
    _hasLocation = false;
    ask4Resource = false;
    _hasRawImage = false;
    _stt = null;
    for (int i = 0, tama = infoProviders.length; i < tama; i++) {
      Map provider = infoProviders[i];
      Map<String, dynamic>? data = provider['data'];
      switch (provider["provider"]) {
        case 'osm':
          OSM osm = OSM(data);
          for (PairLang l in osm.labels) {
            addLabelLang(l);
          }
          if (osm.image != null) {
            setThumbnail(osm.image!.image,
                osm.image!.hasLicense ? osm.image!.license : null);
          }
          lat = osm.lat;
          long = osm.long;
          for (PairLang d in osm.descriptions) {
            addCommentLang(d);
          }
          addProvider(provider['provider'], osm);
          break;
        case 'wikidata':
          Wikidata? wikidata = Wikidata(data);
          for (PairLang label in wikidata.labels) {
            addLabelLang(label);
          }
          for (PairLang comment in wikidata.descriptions) {
            addCommentLang(comment);
          }
          for (PairImage image in wikidata.images) {
            addImage(image.image,
                license: image.hasLicense ? image.license : null);
          }
          addProvider(provider['provider'], wikidata);
          break;
        case 'jcyl':
          JCyL jcyl = JCyL(data);
          addCommentLang(jcyl.description);
          addProvider(provider['provider'], jcyl);
          break;
        case 'esDBpedia':
        case 'dbpedia':
          DBpedia dbpedia = DBpedia(data, provider['provider']);
          for (PairLang comment in dbpedia.descriptions) {
            addCommentLang(comment);
          }
          for (PairLang label in dbpedia.labels) {
            addLabelLang(label);
          }
          addProvider(provider['provider'], dbpedia);
          break;
        case 'localRepo':
          LocalRepo localRepo = LocalRepo(data);
          lat = localRepo.lat;
          long = localRepo.long;
          for (PairLang l in localRepo.labels) {
            addLabelLang(l);
          }
          for (PairLang l in localRepo.comments) {
            addCommentLang(l);
          }
          author = localRepo.author;
          addProvider(provider['provider'], localRepo);
          break;
        default:
      }
    }
  }

  String get id => _id;
  set id(String idServer) {
    if (idServer.isNotEmpty) {
      _id = idServer;
    } else {
      throw FeatureException('idServer');
    }
  }

  String get shortId => _shortId;
  set shortId(String shortIdServer) {
    if (shortIdServer.isNotEmpty) {
      _shortId = shortIdServer;
    } else {
      throw FeatureException('hortIdServer');
    }
  }

  String get author => _author;
  set author(String authorServer) {
    if (authorServer.isNotEmpty) {
      _author = authorServer;
    } else {
      throw FeatureException('authorServer');
    }
  }

  List<PairLang> get labels => _label;
  void resetLabels() {
    _label.clear();
  }

  List<PairLang> get comments => _comment;
  void resetComments() {
    _comment.clear();
  }

  double get lat => _latitude;
  set lat(double lat) {
    if (lat <= 90 && lat >= -90) {
      _latitude = lat;
    } else {
      throw FeatureException('Latitude problem!!');
    }
  }

  double get long => _longitude;
  set long(double long) {
    if (long <= 180 && lat >= -180) {
      _longitude = long;
    } else {
      throw FeatureException('Longitude problem!!');
    }
  }

  Uint8List get rawImage =>
      _hasRawImage ? _rawImage : throw FeatureException('No rawImage');
  set rawImage(Uint8List rawImage) {
    _rawImage = rawImage;
    _hasRawImage = true;
  }

  void resetRawImage() {
    _hasRawImage = false;
  }

  bool get hasRawImage => _hasRawImage;

  String get original => _original;
  set original(String original) {
    if (original.trim().isNotEmpty) {
      _original = original.trim();
    }
  }

  bool get hasOriginal => _original.isNotEmpty;

  void resetOriginal() {
    _original = '';
  }

  LatLng get point => LatLng(_latitude, _longitude);
  bool get hasThumbnail => _hasThumbnail;
  List<PairImage> get image => _image;
  bool get hasSource => _hasSource;
  bool get hasLocation => _hasLocation;
  List<LatLng> get geometry => _geometry;

  String get source =>
      _hasSource ? _source : throw FeatureException('Feature has not source!!');
  set source(source) {
    _source = source;
    _hasSource = true;
  }

  Set<SpatialThingType>? get spatialThingTypes => _stt;
  set spatialThingTypes(dynamic stt) {
    if (stt is Set<SpatialThingType>) {
      _stt = stt;
    } else {
      if (stt is String) {
        stt = [stt];
      }
      if (stt is SpatialThingType) {
        stt = [stt];
      }
      if (stt is List) {
        _stt = {};
        for (dynamic ele in stt) {
          if (ele is String) {
            ele = ele.split('mo:').last;
            if (ele != 'SpatialThing') {
              SpatialThingType? eleSTT = Auxiliar.getSpatialThing(ele);
              if (eleSTT != null) {
                _stt!.add(eleSTT);
              } else {
                throw FeatureException('$ele is not valid type');
              }
            }
          } else {
            if (ele is SpatialThingType) {
              _stt!.add(ele);
            } else {
              throw FeatureException('stt element not valid');
            }
          }
        }
      } else {
        throw FeatureException('stt not valid');
      }
    }
  }

  PairImage get thumbnail => _hasThumbnail
      ? _thumbnail
      : throw FeatureException('Feature has not thumbnail');

  String? labelLang(String lang) => _objLang('label', lang);
  void addLabelLang(PairLang newLabel) {
    // if (newLabel.hasLang) {
    //   for (var e in _label) {
    //     if (e.hasLang && e.lang == newLabel.lang) {
    //       _label.remove(e);
    //       break;
    //     }
    //   }
    // }
    _label.add(newLabel);
  }

  void setLabels(labelS) {
    if (labelS is Map || labelS is PairLang) {
      labelS = [labelS];
    }
    if (labelS is List) {
      _label.clear();
      for (var element in labelS) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _label.removeWhere((lab) => lab.lang == element['lang']);
            _label.add(PairLang(element['lang'], element['value']));
          } else {
            _label.add(PairLang.withoutLang(element['value']));
          }
        } else {
          if (element is PairLang) {
            _label.add(element);
          } else {
            throw FeatureException('labelS');
          }
        }
      }
    } else {
      throw FeatureException('labelS');
    }
  }

  String? commentLang(String lang) => _objLang('comment', lang);
  void addCommentLang(PairLang newComment) {
    // if (newComment.hasLang) {
    //   for (var e in _comment) {
    //     if (e.hasLang && e.lang == newComment.lang) {
    //       _comment.remove(e);
    //       break;
    //     }
    //   }
    // }
    _comment.add(newComment);
  }

  void setComments(commentS) {
    if (commentS is Map || commentS is PairLang) {
      commentS = [commentS];
    }
    if (commentS is List) {
      _comment.clear();
      for (var element in commentS) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _comment.removeWhere((com) => com.lang == element['lang']);
            _comment.add(PairLang(element['lang'], element['value']));
          } else {
            _comment.add(PairLang.withoutLang(element['value']));
          }
        } else {
          if (element is PairLang) {
            _comment.add(element);
          } else {
            throw FeatureException('commentS');
          }
        }
      }
    } else {
      throw FeatureException('commentS');
    }
  }

  String getALabel({String? lang}) {
    String out = '';
    if (lang != null) {
      out = labelLang(lang) != null ? labelLang(lang)! : '';
    }
    if (out.isEmpty) {
      out = labelLang('en') != null
          ? labelLang('en')!
          : _label.isNotEmpty
              ? _label.first.value
              : '';
    }
    return out;
  }

  String getAComment({String? lang}) {
    String out = '';
    if (lang != null) {
      out = commentLang(lang) != null ? commentLang(lang)! : '';
    }
    if (out.isEmpty) {
      out = commentLang('en') != null
          ? commentLang('en')!
          : _comment.isNotEmpty
              ? _comment.first.value
              : '';
    }
    return out;
  }

  String? _objLang(String opt, String lang) {
    List<PairLang> pl;
    switch (opt) {
      case 'label':
        pl = _label;
        break;
      case 'comment':
        pl = _comment;
        break;
      default:
        throw FeatureException('switch _objLang');
    }
    String auxiliar = pl.isEmpty ? '' : pl[0].value;
    for (var e in pl) {
      if (e.hasLang) {
        if (e.lang == lang) {
          return e.value;
        }
      }
    }
    return auxiliar;
  }

  void setThumbnail(String image, String? license) {
    if (image.trim().isNotEmpty) {
      _hasThumbnail = true;
      if (license == null) {
        _thumbnail = PairImage.withoutLicense(image);
      } else {
        _thumbnail = PairImage(image, license);
      }
    } else {
      _hasThumbnail = false;
    }
  }

  void addImage(String urlImage, {String? license}) {
    if (urlImage.trim().isNotEmpty) {
      _image.add(license == null
          ? PairImage.withoutLicense(urlImage)
          : PairImage(urlImage, license));
      if (!_hasThumbnail) {
        setThumbnail(urlImage, license);
      }
    }
  }

  void setImage(String urlImage, {String? license}) {
    if (urlImage.trim().isNotEmpty) {
      _image.clear();
      _image.add(license != null
          ? PairImage(urlImage.trim(), license.trim())
          : PairImage.withoutLicense(urlImage.trim()));
      if (!_hasThumbnail) {
        setThumbnail(urlImage, license);
      }
    }
  }

  List<Map<String, String>> comments2List() => _object2List(comments);

  List<Map<String, String>> labels2List() => _object2List(labels);

  Map<String, dynamic> thumbnail2Map() => thumbnail.toMap(isThumb: true);

  List<Map<String, String>> _object2List(obj) {
    List<Map<String, String>> out = [];
    for (var element in obj) {
      out.add(element.toMap());
    }
    return out;
  }

  List<Category> get categories => _categories;
  set categories(categories) {
    if (categories is Map) {
      categories = [categories];
    }
    if (categories is List) {
      for (var category in categories) {
        addCategory(category);
      }
    }
  }

  void addCategory(category) {
    if (category is Category) {
      int index = _categories.indexWhere((Category c) => c.iri == category.iri);
      if (index == -1) {
        _categories.add(category);
      }
    } else {
      if (category['iri'] != null) {
        Category aux = Category(category['iri']);
        if (category['label'] != null) {
          aux.label = category['label'];
        }
        if (category['broader'] != null) {
          aux.broader = category['broader'];
        }
        _categories.add(aux);
      } else {
        throw FeatureException('No iri');
      }
    }
  }

  void deleteCategory(Category category) {
    int index = _categories.indexWhere((Category c) => c.iri == category.iri);
    if (index > -1) {
      _categories.removeWhere((element) => element.iri == category.iri);
    }
  }

  List<Map<String, dynamic>> categoriesToList() {
    List<Map<String, dynamic>> out = [];
    for (Category c in categories) {
      out.add(c.toMap());
    }
    return out;
  }

  set tags(listTags) {
    if (listTags is Map) {
      for (String key in listTags.keys) {
        _tags.add(TagOSM(key, listTags[key]));
      }
    } else {
      throw FeatureException('tags');
    }
  }

  List<TagOSM> get tags => _tags;

  List<Provider> get providers => _providers;

  addProvider(String providerId, dynamic data) {
    dynamic obj;
    switch (providerId) {
      case 'osm':
        obj = data is OSM ? data : OSM((data as Map<String, dynamic>));
        break;
      case 'wikidata':
        obj =
            data is Wikidata ? data : Wikidata((data as Map<String, dynamic>));
        break;
      case 'jcyl':
        obj = data is JCyL ? data : JCyL((data as Map<String, dynamic>));
        break;
      case 'dbpedia':
      case 'esDBpedia':
        obj = data is DBpedia
            ? data
            : DBpedia((data as Map<String, dynamic>), providerId);
        break;
      case 'localRepo':
        obj =
            data is LocalRepo ? data : LocalRepo(data as Map<String, dynamic>);
        break;
      case 'docomomo':
        obj = data is Docomomo ? data : Docomomo(data as Map<String, dynamic>);
        break;
      default:
        obj = null;
    }
    if (obj != null) {
      int index = _providers.indexWhere((Provider p) => p.id == providerId);
      if (index >= 0) {
        _providers.removeAt(index);
      }
      _providers.add(Provider(providerId, obj));
    } else {
      throw FeatureException('Provider unknown');
    }
  }

  Object? getProvider(String providerId) {
    int index =
        providers.indexWhere((Provider provider) => provider.id == providerId);
    return index < 0 ? null : providers.elementAt(index);
  }

  Map<String, dynamic> toJson() => toMap();
  Map<String, dynamic> toMap() {
    Map<String, dynamic> out = {
      'id': id,
      'shortId': shortId,
      'lat': lat,
      'long': long,
      'author': author,
    };
    List<String> lists = [];
    for (PairLang label in labels) {
      lists.add(jsonEncode(label.toMap()));
    }
    out['labels'] = lists;
    lists = [];
    for (PairLang comment in comments) {
      lists.add(jsonEncode(comment.toMap()));
    }
    out['descriptions'] = lists;

    if (hasThumbnail) {
      out['thumnailImg'] = thumbnail.image.toString();
      if (thumbnail.hasLicense) {
        out['thumbnailLic'] = thumbnail.license.toString();
      }
    }

    if (tags.isNotEmpty) {
      lists = [];
      for (TagOSM tag in tags) {
        lists.add(jsonEncode(tag.toMap()));
      }
      out['tags'] = lists;
    }

    if (hasSource) {
      out['source'] = source;
    }

    if (categories.isNotEmpty) {
      lists = [];
      for (Category category in categories) {
        lists.add(jsonEncode(category.toMap()));
      }
      out['categories'] = lists;
    }

    if (geometry.isNotEmpty) {
      lists = [];
      for (LatLng geo in geometry) {
        lists.add(jsonEncode({'lat': geo.latitude, 'long': geo.longitude}));
      }
      out['geometry'] = lists;
    }

    if (providers.isNotEmpty) {
      lists = [];
      for (Provider provider in providers) {
        // lists.add(jsonEncode(provider.toMap()));
        lists.add(jsonEncode(provider.toJson()));
      }
      out['providers'] = lists;
    }

    if (spatialThingTypes != null) {
      out['type'] = [];
      for (SpatialThingType stt in spatialThingTypes!) {
        out['type'].add(stt.name);
      }
    }

    if (_hasRawImage) {
      out['rawImage'] = _rawImage.toList();
    }

    if (_original.isNotEmpty) {
      out['original'] = _original;
    }

    return out;
  }
}

class NPOI {
  late String _id;
  late double _lat, _long;
  late int _npois;

  NPOI(idZoneServer, latServer, longServer, npoisServer) {
    if (idZoneServer is String && idZoneServer.isNotEmpty) {
      _id = idZoneServer;
    } else {
      throw Exception('Problem with idZoneServer');
    }
    if (latServer is double && latServer >= 0 && latServer <= 90) {
      _lat = latServer;
    } else {
      throw Exception('Problem with latitudeServer');
    }
    if (longServer is double && longServer >= -180 && longServer <= 180) {
      _long = longServer;
    } else {
      throw Exception('Problem with longServer');
    }
    if (npoisServer is int && npoisServer >= 0) {
      _npois = npoisServer;
    } else {
      throw Exception('Problem with npoisServer');
    }
  }

  String get id => _id;
  double get lat => _lat;
  double get long => _long;
  int get npois => _npois;
}

class TeselaFeature {
  static const double _lado = 0.1;
  final int _unDia = 1000 * 60 * 60 * 24;
  late List<Feature> _features;
  late double _north, _west;
  late DateTime _update;
  late LatLngBounds _bounds;
  late bool _onlyMoMo;

  static double get lado => _lado;
  bool get onlyMoMo => _onlyMoMo;

  TeselaFeature(this._north, this._west, features,
      {DateTime? update, bool onlyMoMo = false}) {
    _bounds = LatLngBounds(
        LatLng(_north, _west), LatLng(_north - _lado, _west + _lado));
    _update = update ?? DateTime.now();
    _features = [...features];
    _onlyMoMo = onlyMoMo;
  }

  TeselaFeature.withoutFeatures(double north, double west,
      {bool onlyMoMo = false})
      : this(north, west, <Feature>[], onlyMoMo: onlyMoMo);

  TeselaFeature.fromJSON(Map<String, dynamic> data) {
    if (data.containsKey('north') &&
        data['north'] is double &&
        data['north'] <= 90 &&
        data['north'] >= -90 &&
        data.containsKey('west') &&
        data['west'] is double &&
        data['west'] <= 180 &&
        data['west'] >= -180 &&
        data.containsKey('update') &&
        data.containsKey('features') &&
        data['features'] is List) {
      List<Feature> lstFeatures = [];
      // Map<String, dynamic> dataFeature;
      for (Map<String, dynamic> f in data['features']) {
        // dataFeature = jsonDecode(f) as Map<String, dynamic>;
        lstFeatures.add(Feature.fromJSON(f));
      }

      _north = data['north'];
      _west = data['west'];
      _bounds = LatLngBounds(
          LatLng(_north, _west), LatLng(_north - _lado, _west + _lado));
      _update = DateTime.parse(data['update']);
      _features = [...lstFeatures];
      _onlyMoMo = false;
    }
  }

  Map<String, dynamic> toJson() => {
        'north': north,
        'west': west,
        'update': update.toIso8601String(),
        'features': features
      };

  updateED() {
    _update = DateTime.now();
  }

  bool isValid() {
    return DateTime.now().isBefore(DateTime.fromMillisecondsSinceEpoch(
        _update.millisecondsSinceEpoch + _unDia));
  }

  List<Feature> get features => _features;
  double get north => _north;
  double get west => _west;
  DateTime get update => _update;

  // List<Feature> getPois() {
  //   return _pois;
  // }

  bool isEqualPoint(LatLng punto, {bool onlyMoMo = false}) {
    return punto.latitude == _north &&
        punto.longitude == _west &&
        _onlyMoMo == onlyMoMo;
  }

  bool checkIfContains(pointOrBound) {
    if (pointOrBound is LatLng) {
      return _bounds.contains(pointOrBound);
    } else {
      if (pointOrBound is LatLngBounds) {
        return _bounds.containsBounds(pointOrBound);
      } else {
        return false;
      }
    }
  }

  void addFeature(Feature feature) {
    if (indexFeature(feature) == -1) {
      _features.add(feature);
    }
  }

  void removeFeature(Feature feature) {
    int index = indexFeature(feature);
    if (index > -1) {
      _features.removeAt(index);
    }
  }

  int indexFeature(Feature feature) =>
      features.indexWhere((Feature f) => f.id == feature.id);

  Map<String, dynamic> toMap() {
    Map<String, dynamic> out = {
      'north': north,
      'west': west,
      'update': update.microsecondsSinceEpoch,
    };
    List<String> lstFeatures = [];
    for (Feature f in features) {
      lstFeatures.add(jsonEncode(f.toMap()));
    }
    out['features'] = lstFeatures;
    return out;
  }
}

class Provider {
  final String _id;
  late DateTime _timestamp;
  final dynamic _data;

  Provider(this._id, this._data, {DateTime? timestamp}) {
    _timestamp = timestamp ?? DateTime.now();
  }

  String get id => _id;
  DateTime get timestamp => _timestamp;
  dynamic get data => _data;

  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'data': data.toJson(),
      'timestamp': timestamp.microsecondsSinceEpoch
    };
  }
}

class FeatureDistance {
  final Feature _feature;
  final double _distance;
  FeatureDistance(this._feature, this._distance);

  Feature get feature => _feature;
  double get distance => _distance;
}

// TODO cambiar cuando sea otro dominio
enum SpatialThingType {
  factory,
  residential,
  hotel,
  education,
  goverment,
  placeOfWorship,
  cinema,
  square,
  feature
}
