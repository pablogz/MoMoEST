import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/exceptions.dart';
import 'package:momoest/util/helpers/pair.dart';
import 'package:momoest/util/helpers/feature.dart';
import 'package:momoest/util/helpers/tasks.dart';
import 'package:momoest/util/helpers/track.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class Itinerary {
  late String? _id, _author, _authorLbl;
  List<PairLang> _labels = [], _comments = [];
  late List<PointItinerary> _points;
  late ItineraryType? _type;
  late List<Task> _taskIt;
  late DateTime? _date;
  double? _maxLat, _minLat, _maxLong, _minLong;
  Track? _track;

  Itinerary(dynamic data) {
    if (data is Map) {
      if (data.containsKey('id') &&
          data['id'] is String &&
          (data['id'] as String).isNotEmpty) {
        _id = (data['id'] as String);
      } else {
        throw ItineraryException('id');
      }

      if (data.containsKey('type') && data['type'] is String) {
        data['type'] = [data['type']];
      }

      if (data.containsKey('type') && data['type'] is List) {
        for (var stype in data['type']) {
          if (stype is String) {
            ItineraryType? itT = _string2Type(stype);
            if (itT != null) {
              _type = itT;
              break;
            }
          }
        }
        if (_type == null) {
          throw ItineraryException('type');
        }
      } else {
        throw ItineraryException('type');
      }

      if (data.containsKey('label')) {
        if (data['label'] is Map) {
          data['label'] = [data['label']];
        }

        if (data['label'] is List) {
          for (var element in (data['label'] as List)) {
            if (element is Map && element.containsKey('value')) {
              if (element.containsKey('lang')) {
                _labels.add(PairLang(element['lang'], element['value']));
              } else {
                _labels.add(PairLang.withoutLang(element['value']));
              }
            } else {
              throw ItineraryException('label');
            }
          }
        } else {
          throw ItineraryException('label');
        }
      } else {
        throw ItineraryException('label');
      }

      if (data.containsKey('comment')) {
        if (data['comment'] is Map) {
          data['comment'] = [data['comment']];
        }
        if (data['comment'] is List) {
          for (var element in (data['comment'] as List)) {
            if (element is Map && element.containsKey('value')) {
              if (element.containsKey('lang')) {
                _comments.add(PairLang(element['lang'], element['value']));
              } else {
                _comments.add(PairLang.withoutLang(element['value']));
              }
            } else {
              throw ItineraryException('comment');
            }
          }
        } else {
          throw ItineraryException('comment');
        }
      } else {
        throw ItineraryException('comment');
      }

      if (data.containsKey('author') && data['author'] is String) {
        _author = data['author'];
      } else {
        throw ItineraryException('author');
      }

      if (data.containsKey('authorLbl') && data['authorLbl'] is String) {
        _authorLbl = data['authorLbl'];
      } else {
        debugPrint('authorLbl problem');
      }

      if (data.containsKey('update') && data['update'] is int) {
        _date = DateTime.fromMillisecondsSinceEpoch(data['update']);
      } else {
        debugPrint('update problem');
      }

      if (data.containsKey('points') && data['points'] is PointItinerary) {
        data['points'] = [data['points']];
      }

      if (data.containsKey('points') && data['points'] is List) {
        _points = [];
        for (var element in data['points']) {
          _points.add(PointItinerary(element));
        }
      } else {
        _points = [];
      }

      if (data.containsKey('track') && data['track'] is Map) {
        _track = Track.server(data['track']);
      } else {
        _track = null;
      }

      _taskIt = [];
      if (data.containsKey('tasksIt') && data['tasksIt'] is List) {
        for (var element in data['tasksIt']) {
          try {
            _taskIt.add(Task(
              element,
              containerType: ContainerTask.itinerary,
              idContainer: _id,
            ));
          } catch (error, stackTrace) {
            if (ConfigXest.development) {
              debugPrint(error.toString());
            } else {
              FirebaseCrashlytics.instance.recordError(error, stackTrace);
            }
          }
        }
      }

      if (data.containsKey('bounds') && data['bounds'] is Map) {
        Map<String, dynamic> bounds = data['bounds'];
        if (bounds.containsKey('maxLat') &&
            bounds['maxLat'] is double &&
            bounds.containsKey('minLat') &&
            bounds['minLat'] is double &&
            bounds['maxLat'] >= bounds['minLat'] &&
            bounds.containsKey('maxLong') &&
            bounds['maxLong'] is double &&
            bounds.containsKey('minLong') &&
            bounds['minLongs'] is double &&
            bounds['maxLong'] > bounds['minLong']) {
          _maxLat = bounds['maxLat'];
          _minLat = bounds['minLat'];
          _maxLong = bounds['maxLong'];
          _minLong = bounds['minLong'];
        }
      }
    } else {
      throw ItineraryException('it is not a Map');
    }
  }

  Itinerary.empty() {
    _id = null;
    _author = null;
    _authorLbl = null;
    _date = null;
    _type = null;
    _track = null;
    _points = [];
    _taskIt = [];
  }

  String? get id => _id;
  set id(String? idIt) {
    if (idIt is String && idIt.isNotEmpty) {
      _id = idIt;
    } else {
      throw ItineraryException('id');
    }
  }

  String? get author => _author;
  set author(String? authorIt) {
    if (authorIt is String && authorIt.isNotEmpty) {
      _author = authorIt;
    } else {
      throw ItineraryException('author');
    }
  }

  String? get authorLbl => _authorLbl;
  set authorLbl(String? authorLbl) {
    if (authorLbl is String && authorLbl.isNotEmpty) {
      _authorLbl = authorLbl;
    } else {
      throw ItineraryException('authorLbl');
    }
  }

  DateTime? get date => _date;
  set date(DateTime? date) {
    if (date is DateTime) {
      _date = date;
    } else {
      throw ItineraryException('date');
    }
  }

  List<PairLang> get labels => _labels;
  set labels(dynamic labelIt) {
    if (labelIt is Map) {
      labelIt = [labelIt];
    }
    if (labelIt is List) {
      _labels = [];
      for (var element in labelIt) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _labels.add(PairLang(element['lang'], element['value']));
          } else {
            _labels.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw ItineraryException('label');
        }
      }
    } else {
      throw ItineraryException('label');
    }
  }

  void addLabel(dynamic label) {
    if (label is Map && label.containsKey('value')) {
      if (label.containsKey('lang')) {
        _labels.add(PairLang(label['lang'], label['value']));
      } else {
        _labels.add(PairLang.withoutLang(label['value']));
      }
    } else {
      if (label is PairLang) {
        _labels.add(label);
      } else {
        throw ItineraryException('label');
      }
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
          : _labels.isNotEmpty
              ? _labels.first.value
              : '';
    }
    return out;
  }

  List<PairLang> get comments => _comments;
  set comments(dynamic commentsIt) {
    if (commentsIt is Map) {
      commentsIt = [commentsIt];
    }
    if (commentsIt is List) {
      _comments = [];
      for (var element in commentsIt) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _comments.add(PairLang(element['lang'], element['value']));
          } else {
            _comments.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw ItineraryException('comments');
        }
      }
    } else {
      throw ItineraryException('comments');
    }
  }

  void addComment(dynamic comment) {
    if (comment is Map && comment.containsKey('value')) {
      if (comment.containsKey('lang')) {
        _comments.add(PairLang(comment['lang'], comment['value']));
      } else {
        _comments.add(PairLang.withoutLang(comment['value']));
      }
    } else {
      if (comment is PairLang) {
        _comments.add(comment);
      } else {
        throw ItineraryException('comment');
      }
    }
  }

  String getAComment({String? lang}) {
    String out = '';
    if (lang != null) {
      out = commentLang(lang) != null ? commentLang(lang)! : '';
    }
    if (out.isEmpty) {
      out = commentLang('en') != null
          ? commentLang('en')!
          : _comments.isNotEmpty
              ? _comments.first.value
              : '';
    }
    return out;
  }

  void resetLabelComment() {
    _comments = [];
    _labels = [];
  }

  ItineraryType? get type => _type;
  set type(dynamic typeIt) {
    if (typeIt is String) {
      _type = _string2Type(typeIt);
    } else {
      if (typeIt is ItineraryType) {
        _type = typeIt;
      } else {
        throw ItineraryException("type");
      }
    }
  }

  List<PointItinerary> get points => _points;
  set points(dynamic pointsIt) {
    if (pointsIt is PointItinerary) {
      pointsIt = [pointsIt];
    }
    if (pointsIt is List) {
      _points = [];
      for (var element in pointsIt) {
        if (element is PointItinerary) {
          _points.add(element);
        } else {
          if (element is Map &&
              element.containsKey('id') &&
              element.containsKey('tasks')) {
            _points.add(PointItinerary(element));
          } else {
            throw ItineraryException('points map ${element.toString()}');
          }
        }
      }
    } else {
      throw ItineraryException('points');
    }
  }

  void addPoints(PointItinerary pit) {
    _points.add(pit);
  }

  bool removePoint(PointItinerary pit) {
    _points.removeWhere((element) => element.id == pit.id);
    bool existe = false;
    for (var point in _points) {
      if (point.id == pit.id) {
        existe = true;
        break;
      }
    }
    return !existe;
  }

  String? labelLang(String lang) => _objLang('label', lang);
  String? commentLang(String lang) => _objLang('comment', lang);
  String? _objLang(String opt, String lang) {
    List<PairLang> pl;
    switch (opt) {
      case 'label':
        pl = _labels;
        break;
      case 'comment':
        pl = _comments;
        break;
      default:
        throw Exception('Problem in switch _objLang');
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

  List<Map<String, String>> _comments2List() => _object2List(comments);

  List<Map<String, String>> _labels2List() => _object2List(labels);

  List<Map<String, String>> _object2List(obj) {
    List<Map<String, String>> out = [];
    for (var element in obj) {
      out.add(element.toMap());
    }
    return out;
  }

  List<Map<String, dynamic>> _points2List() {
    List<Map<String, dynamic>> out = [];
    for (PointItinerary point in points) {
      out.add(point.toMap());
    }
    return out;
  }

  Track? get track => _track;
  set track(Track? track) {
    _track = track;
  }

  void addTask(Task task) {
    int index = _taskIt.indexWhere((Task tInIt) => tInIt.id == task.id);
    if (index == -1) _taskIt.add(task);
  }

  bool removeTask(Task task) {
    return _taskIt.remove(task);
  }

  set tasks(List<Task> tasks) {
    _taskIt = tasks;
    // for (Task task in tasks) {
    //   addTask(task);
    // }
  }

  List<Task> get tasks => _taskIt;

  @override
  String toString() {
    return toMap().toString();
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> out = {
      'type': _type2String(type!),
      'label': _labels2List(),
      'comment': _comments2List(),
      'points': _points2List()
    };
    if (track != null) {
      out['track'] = track!.toMap()['track'];
    }
    if (tasks.isNotEmpty) {
      out['tasks'] = [];
      for (Task t in tasks) {
        (out['tasks'] as List).add(t.toMap());
      }
    }
    return out;
  }

  String _type2String(ItineraryType type) {
    Map<ItineraryType, String> lst = {
      ItineraryType.bag: 'Bag',
      ItineraryType.bagSTsListTasks: 'BagSTsListTasks',
      ItineraryType.list: 'List',
      ItineraryType.listSTsBagTasks: 'ListSTsBagTasks'
    };
    return lst.containsKey(type)
        ? '${lst[type]}Itinerary'
        : throw ItineraryException('ItineraryType not allow');
  }

  ItineraryType? _string2Type(String type) {
    Map<String, ItineraryType> lst = {
      'BagItinerary': ItineraryType.bag,
      'BagSTsListTasksItinerary': ItineraryType.bagSTsListTasks,
      'ListItinerary': ItineraryType.list,
      'ListSTsBagTasksItinerary': ItineraryType.listSTsBagTasks
    };
    type = type.split('/').last;
    type = type.split('mo:').last;
    return lst.containsKey(type) ? lst[type]! : null;
  }

  double get maxLat => _maxLat ?? 90;
  set maxLat(double maxLat) {
    if (maxLat <= 90 && maxLat > minLat) _maxLat = maxLat;
  }

  double get minLat => _minLat ?? -90;
  set minLat(double minLat) {
    if (minLat >= -90 && minLat <= maxLat) _minLat = minLat;
  }

  double get maxLong => _maxLong ?? 180;
  set maxLong(double maxLong) {
    if (maxLong <= 180 && maxLong > minLong) _maxLong = maxLong;
  }

  double get minLong => _minLong ?? -180;
  set minLong(double minLong) {
    if (minLong >= -180 && minLong <= maxLong) _minLong = minLong;
  }

  LatLngBounds get latLngBounds {
    if (track != null) {
      track!.calculateBounds();
      return LatLngBounds(track!.northWest, track!.southEast);
    } else {
      // Calculo los límites si el itineario tiene Spatial Things
      if (points.isNotEmpty) {
        List<LatLng> latLngs = [];
        for (PointItinerary point in points) {
          if (point.hasFeature) {
            latLngs.add(point.feature.point);
          }
        }
        return LatLngBounds.fromPoints(latLngs);
      }
      return LatLngBounds(LatLng(maxLat, maxLong), LatLng(minLat, minLong));
    }
  }
}

class PointItinerary {
  late String _id, _shortId;
  // late List<PairLang>? _comments, _labels;
  late List<String> _tasks;
  late Feature _feature;
  late List<Task> _lstTasks;
  late bool _hasFeature, _hasLstTasks, removeFromIt;

  PointItinerary(dynamic data) {
    if (data is Map) {
      if (data.containsKey('id') &&
          data['id'] is String &&
          (data['id'] as String).isNotEmpty) {
        _id = (data['id'] as String);
        String? shortId = Auxiliar.id2shortId(id);
        if (shortId != null) {
          _shortId = shortId;
        } else {
          throw PointItineraryException("Problem sortIdFeature");
        }
      } else {
        throw PointItineraryException('id');
      }

      if (data.containsKey('tasks') && data['tasks'] is String) {
        data['tasks'] = [data['tasks']];
      }
      if (data.containsKey('tasks') && data['tasks'] is List) {
        _tasks = [];
        for (var element in data['tasks']) {
          if (element is String && element.isNotEmpty) {
            _tasks.add(element);
          } else {
            throw PointItineraryException('task');
          }
        }
      } else {
        _tasks = [];
      }

      // if (data.containsKey('altComment')) {
      //   if (data['altComment'] is Map) {
      //     data['altComment'] = [data['altComment']];
      //   }
      //   if (data['altComment'] is List) {
      //     _comments = [];
      //     for (var element in data['altComment']) {
      //       if (element is Map && element.containsKey('value')) {
      //         if (element.containsKey('lang')) {
      //           _comments!.add(PairLang(element['lang'], element['value']));
      //         } else {
      //           _comments!.add(PairLang.withoutLang(element['value']));
      //         }
      //       } else {
      //         throw Exception('Problem with altComment');
      //       }
      //     }
      //   }
      // } else {
      //   _comments = null;
      // }

      // if (data.containsKey('altLabel')) {
      //   if (data['altLabel'] is Map) {
      //     data['altLabel'] = [data['altLabel']];
      //   }
      //   if (data['altLabel'] is List) {
      //     _labels = [];
      //     for (var element in data['altLabel']) {
      //       if (element is Map && element.containsKey('value')) {
      //         if (element.containsKey('lang')) {
      //           _labels!.add(PairLang(element['lang'], element['value']));
      //         } else {
      //           _labels!.add(PairLang.withoutLang(element['value']));
      //         }
      //       } else {
      //         throw Exception('Problem with altLabel');
      //       }
      //     }
      //   }
      // } else {
      //   _labels = null;
      // }

      _lstTasks = [];

      _hasFeature = false;
      _hasLstTasks = false;

      removeFromIt = false;
    } else {
      throw PointItineraryException('It is not a map');
    }
  }

  String get id => _id;
  String get shortId => _shortId;
  set id(dynamic id) {
    if (id is String && id.isNotEmpty) {
      _id = id;
      String? shortId = Auxiliar.id2shortId(id);
      if (shortId != null) {
        _shortId = shortId;
      } else {
        throw PointItineraryException("Problem sortIdFeature");
      }
    } else {
      throw PointItineraryException("Problem idFeature");
    }
  }

  // List<PairLang>? get altComments => _comments;
  List<String> get tasks => _tasks;

  bool get hasFeature => _hasFeature;
  bool get hasLstTasks => _hasLstTasks;

  Feature get feature => _hasFeature
      ? _feature
      : throw PointItineraryException("The itinerary does not have feature");
  set feature(Feature feature) {
    _feature = feature;
    _hasFeature = true;
  }

  List<Task> get tasksObj => _hasLstTasks
      ? _lstTasks
      : throw PointItineraryException("Itinerary does not have tasksObj");
  set tasksObj(List<Task> tasks) {
    _lstTasks = tasks;
    _hasLstTasks = true;
  }

  // set altComments(dynamic altComment) {
  //   if (altComment != null) {
  //     if (altComment is Map) {
  //       altComment = [altComment];
  //     }
  //     if (altComment is List) {
  //       _comments = [];
  //       for (var element in altComment) {
  //         if (element is Map && element.containsKey('value')) {
  //           if (element.containsKey('lang')) {
  //             _comments!.add(PairLang(element['lang'], element['value']));
  //           } else {
  //             _comments!.add(PairLang.withoutLang(element['value']));
  //           }
  //         } else {
  //           throw PointItineraryException('Problem with altComment');
  //         }
  //       }
  //     } else {
  //       throw PointItineraryException('Problem with commentServer');
  //     }
  //   } else {
  //     _comments = null;
  //   }
  // }

  set tasks(dynamic tasks) {
    if (tasks is String) {
      tasks = [tasks];
    }
    if (tasks is List) {
      _tasks = [];
      for (var element in tasks) {
        if (element is String && element.isNotEmpty) {
          _tasks.add(element);
        } else {
          throw PointItineraryException('Problem with tasks');
        }
      }
    } else {
      throw PointItineraryException('Problem with tasks');
    }
  }

  void addTaskId(String task) {
    _tasks.add(task);
  }

  void removeTaskId(String task) {
    _tasks.remove(task);
  }

  void addTask(Task t) {
    int index = _lstTasks.indexWhere((Task tInP) => t.id == tInP.id);
    if (index == -1) {
      _lstTasks.add(t);
      _hasLstTasks = _lstTasks.isNotEmpty;
      _tasks.add(t.id);
    }
  }

  void removeTask(Task t) {
    _lstTasks.removeWhere((Task task) => task.id == t.id);
    _hasLstTasks = _lstTasks.isNotEmpty;
    _tasks.remove(t.id);
  }

  // String? altCommentLang(String lang) {
  //   String? out;
  //   if (_comments != null) {
  //     for (var element in _comments!) {
  //       if (element.hasLang && element.lang == lang) {
  //         out = element.value;
  //         break;
  //       }
  //     }
  //   }
  //   return out;
  // }

  Map<String, dynamic> toMap() => {
        'id': id,
        'tasks': tasks,
        'comment': feature.comments.first.toMap(),
        'label': feature.labels.first.toMap()
      };

  // List<Map<String, String>> _comment2List() {
  //   List<Map<String, String>> out = [];
  //   for (var element in altComments!) {
  //     out.add(element.toMap());
  //   }
  //   return out;
  // }
}

enum ItineraryType { list, listSTsBagTasks, bag, bagSTsListTasks }
