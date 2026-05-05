import 'dart:convert';

import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/exceptions.dart';
import 'package:momoest/util/helpers/answers.dart';
import 'package:momoest/util/helpers/pair.dart';
import 'package:flutter/widgets.dart';

class FeedTeacher {
  final String uid;
  final String alias;
  const FeedTeacher({required this.uid, required this.alias});
}

/// Clase que define un canal
class Feed {
  late String _id, _shortId, _iri, _pass, _owner;
  late List<PairLang> _labels, _comments;
  late List<String> _subscribersId;
  late List<Subscriber> _subscribers;
  late List<FeedTeacher> _teachers;
  // late List<String> _lstStLt, _lstItineraries;
  // late List<PointItinerary> _stLt;
  // late List<Task> _tasks;
  // late List<Itinerary> _itineraries;
  // late Feeder _feeder;
  // late List<Subscriber> _subscribers;

  /// Constructor de un [Feed]. Útil para recuperar
  /// datos del servidor.
  Feed.json(Map<String, dynamic> data) {
    if (data.containsKey('id') &&
        data['id'] is String &&
        data['id'].trim().isNotEmpty) {
      _id = data['id'].trim();
      _shortId = Auxiliar.id2shortId(_id)!;
      _iri =
          '${ConfigXest.addClient}/home/feeds/md:${Auxiliar.getIdFromIri(id)}';
    } else {
      FeedException('Problem with the id');
    }

    if (data.containsKey('owner') &&
        data['owner'] is String &&
        data['owner'].trim().isNotEmpty) {
      _owner = data['owner'].trim();
    } else {
      FeedException('Problem with the owner of the feed');
    }

    _labels = [];
    if (data.containsKey('labels') && data['labels'] is List) {
      for (Map<String, dynamic> label in data['labels']) {
        _labels.add(PairLang(label['lang'], label['value']));
      }
    }

    _comments = [];
    if (data.containsKey('comments') && data['comments'] is List) {
      for (Map<String, dynamic> comment in data['comments']) {
        _comments.add(PairLang(comment['lang'], comment['value']));
      }
    }

    if (data.containsKey('password') && data['password'] is String) {
      _pass = data['password'];
    } else {
      _pass = '';
    }

    _teachers = [];
    if (data.containsKey('teachers') && data['teachers'] is List) {
      for (final t in data['teachers']) {
        if (t is Map) {
          final uid = t['uid']?.toString() ?? '';
          final alias = t['alias']?.toString() ?? uid;
          if (uid.isNotEmpty) _teachers.add(FeedTeacher(uid: uid, alias: alias));
        } else if (t is String && t.isNotEmpty) {
          _teachers.add(FeedTeacher(uid: t, alias: t));
        }
      }
    }

    _subscribersId = [];
    _subscribers = [];
    if (data.containsKey('subscribers')) {
      if (data['subscribers'] is List<String>) {
        for (String subscriber in data['subscribers']) {
          if (_subscribersId.indexWhere((String ele) => ele == subscriber) ==
              -1) {
            _subscribersId.add(subscriber);
          }
        }
      } else {
        if (data['subscribers'] is List<Map>) {
          for (Map subscriber in data['subscribers']) {
            try {
              Subscriber s = Subscriber(subscriber);
              if (_subscribersId.indexWhere((String ele) => ele == s.id) ==
                  -1) {
                _subscribers.add(s);
                _subscribersId.add(s.id);
              }
            } catch (error) {
              if (ConfigXest.development) {
                debugPrint(error.toString());
              }
            }
          }
        }
      }
    }

    // _feeders = [];
    // if (data.containsKey('feeder') && data['feeder'] is List) {
    //   for (Object ele in data['feeder']) {
    //     try {
    //       if (ele is Map<String, dynamic>) {
    //         _feeders.add(Feeder.json(ele));
    //       }
    //     } catch (error) {
    //       if (ConfigXest.development) {
    //         debugPrint(error.toString());
    //       }
    //     }
    //   }
    // } else {
    //   FeedException('No feeder');
    // }

    // if (_feeders.isEmpty) {
    //   FeedException('No feeder');
    // }

    // _subscribers = [];
    // if (data.containsKey('subscribers') && data['subscribers'] is List) {
    //   for (Object ele in data['subscribers']) {
    //     try {
    //       if (ele is Map<String, dynamic>) {
    //         _subscribers.add(Subscriber.json(ele));
    //       }
    //     } catch (error) {
    //       if (ConfigXest.development) {
    //         debugPrint(error.toString());
    //       }
    //     }
    //   }
    // }

    // _lstStLt = [];
    // _stLt = [];
    // if (data.containsKey('listFeatures')) {
    //   if (data['listFeatures'] is String) {
    //     data['listFeatures'] = [data['listFeatures']];
    //   }
    //   if (data['listFeatures'] is List<String>) {
    //     _lstFeatures.addAll(data['listFeatures']);
    //   } else {
    //     FeedException('Problem with the list of features');
    //   }
    // }
    // if (data.containsKey('listStLt')) {
    //   if (data['listStLt'] is Map) {
    //     data['listStLt'] = [data['listStLt']];
    //   }
    //   for (Map<String, dynamic> mapa in data['listStLt']) {
    //     PointItinerary pointItinerary = PointItinerary(mapa);
    //     if (mapa.containsKey('feature')) {
    //       pointItinerary.feature = Feature(mapa['feature']);
    //     }
    //     if (mapa.containsKey('lstTasks') && mapa['lstTasks'] is List) {
    //       for (Map<String, dynamic> mapaTarea in mapa['lstTasks']) {
    //         pointItinerary.addTask(Task(mapaTarea));
    //       }
    //     }
    //   }
    // }

    // _lstTasks = [];
    // _tasks = [];
    // if (data.containsKey('listTask')) {
    //   if (data['listTask'] is String) {
    //     data['listTask'] = [data['listTask']];
    //   }
    //   if (data['listTask'] is List<String>) {
    //     _lstTasks.addAll(data['listTask']);
    //   } else {
    //     FeedException('Problem with the list of tasks');
    //   }
    // }

    // _lstItineraries = [];
    // _itineraries = [];
    // if (data.containsKey('listItineraries')) {
    //   if (data['listItineraries'] is String) {
    //     data['listItineraries'] = [data['listItineraries']];
    //   }
    //   if (data['listItineraries'] is List<String>) {
    //     _lstItineraries.addAll(data['listItineraries']);
    //   } else {
    //     FeedException('Problem with the list of itineraries');
    //   }
    // }
  }

  // /// Constructor del [Feed] proporcionando únicamente su [feeder]. Puede ser
  // /// utilizado para cuando se vaya a crear un nuevo [Feed].
  // Feed.feeder(Feeder feeder) {
  //   _id = '';
  //   _iri = '';
  //   _shortId = '';
  //   _pass = '';
  //   _labels = [];
  //   _comments = [];
  //   _subscribers = [];
  //   // _feeders = [feeder];
  //   // _lstFeatures = [];
  //   // _features = [];
  //   // _lstTasks = [];
  //   // _tasks = [];
  //   // _lstStLt = [];
  //   // _stLt = [];
  //   // _lstItineraries = [];
  //   // _itineraries = [];
  // }

  /// Constructor vacio de un [Feed]. Puede ser
  /// utilizado para cuando se vaya a crear un nuevo [Feed].
  Feed() {
    _id = '';
    _iri = '';
    _shortId = '';
    _pass = '';
    _labels = [];
    _comments = [];
    _subscribersId = [];
    _subscribers = [];
    _teachers = [];
    _owner = '';
    // _feeders = [feeder];
    // _lstFeatures = [];
    // _features = [];
    // _lstTasks = [];
    // _tasks = [];
    // _lstStLt = [];
    // _stLt = [];
    // _lstItineraries = [];
    // _itineraries = [];
  }

  /// Identificador del [Feed]
  String get id => _id;

  /// Permite modificar el [id] del [Feed]
  set id(String id) {
    if (id.trim().isNotEmpty) {
      _id = id;
      _shortId = Auxiliar.id2shortId(_id)!;
      _iri = '${ConfigXest.addClient}/feeds/md:${Auxiliar.getIdFromIri(id)}';
    }
  }

  /// Identificador del [Feed]
  String get shortId => _shortId;

  /// Contraseña para apuntarse al [Feed]
  String get pass => _pass;

  /// Permite modificar la [pass] del [Feed]
  set pass(String pass) {
    _pass = pass;
  }

  String get owner => _owner;
  set owner(String owner) {
    _owner = owner;
  }

  List<FeedTeacher> get teachers => _teachers;

  bool addTeacher(String uid, String alias) {
    if (!_teachers.any((t) => t.uid == uid)) {
      _teachers.add(FeedTeacher(uid: uid, alias: alias));
      return true;
    }
    return false;
  }

  bool removeTeacher(String uid) {
    final before = _teachers.length;
    _teachers.removeWhere((t) => t.uid == uid);
    return _teachers.length < before;
  }

  List<Subscriber> get subscribers => _subscribers;

  /// IRI para solicitar el recurso al servidor
  String get iri => _iri;

  List<String> get subscribersId => _subscribersId;

  bool addSubscriberId(String subscriber) {
    int index = _subscribersId.indexWhere((String ele) => ele == subscriber);
    if (index == -1) {
      _subscribersId.add(subscriber);
    }
    return index == -1;
  }

  bool removeSubscriberId(String subscriber) {
    int index = _subscribersId.indexWhere((String ele) => ele == subscriber);
    if (index > -1) {
      _subscribersId.removeAt(index);
    }
    return index > -1;
  }

  List<Subscriber> get lstSubscribers => _subscribers;
  bool addSubscriber(Subscriber subscriber) {
    bool agregaId = addSubscriberId(subscriber.id);
    if (agregaId) {
      _subscribers.add(subscriber);
    }
    return agregaId;
  }

  bool removeSubscriber(Subscriber subscriber) {
    bool borraId = removeSubscriberId(subscriber.id);
    if (borraId) {
      _subscribers.removeWhere((Subscriber ele) => ele.id == subscriber.id);
    }
    return borraId;
  }

  // /// Recupera un [Feeder] del [Feed]. Si el [Feed] tiene más de un [Feeder] se
  // /// debe indicar su identificador
  // Feeder feeder({String? idFeeder}) {
  //   if (_feeders.length == 1) {
  //     return _feeders.first;
  //   } else {
  //     if (idFeeder != null) {
  //       int indexFeeder = _feeders.indexWhere((Feeder f) => f.id == idFeeder);
  //       if (indexFeeder > -1) {
  //         return _feeders.elementAt(indexFeeder);
  //       } else {
  //         throw FeedException('No feeder with this ID or null ID');
  //       }
  //     } else {
  //       throw FeedException('No feeder with this ID or null ID');
  //     }
  //   }
  // }

  // bool addFeeder(Feeder feeder) {
  //   int indexFeeder = _feeders.indexWhere((Feeder f) => f.id == feeder.id);
  //   if (indexFeeder == -1) {
  //     _feeders.add(feeder);
  //     return true;
  //   }
  //   return false;
  // }

  // bool removeFeeder(Feeder feeder) {
  //   int indexFeeder = _feeders.indexWhere((Feeder f) => f.id == feeder.id);
  //   if (indexFeeder > -1) {
  //     _feeders.removeAt(indexFeeder);
  //     return true;
  //   }
  //   return false;
  // }

  // /// Recupera todos los [Feeder] del canal
  // List<Feeder> get feeders => _feeders;

  // /// Establece el autor del canal. Solo puede haber un [Feeder] en cada canal
  // set feeders(List<Feeder> feeders) {
  //   _feeders = feeders;
  // }

  /// Recupera todas las etiquetas del [Feed]
  List<PairLang> get labels => _labels;

  /// Establece todas las etiquetas del [Feed]
  set labels(List<PairLang> labels) {
    _labels = labels;
  }

  /// Recupera una etiqueta del [Feed]. Si se indica el [lang] se intenta
  /// obtener la etiqueta en ese idioma. Si no se dispone la etiqueta en ese
  /// idioma o no se proporciona [lang] se devuelve la etiqueta en inglés. Si
  /// no se dispone de la etiqueta en inglés se devuelve la primera disponible.
  String getALabel({String? lang}) {
    try {
      if (labels.isEmpty) return '';
      if (lang is String) {
        return labels
            .firstWhere((PairLang p) => p.hasLang && p.lang == lang)
            .value;
      } else {
        return labels
            .firstWhere((PairLang p) => p.hasLang && p.lang == "en")
            .value;
      }
    } catch (e) {
      return labels.first.value;
    }
  }

  /// Recupera una descripción del [Feed]. Si se indica el [lang] se intenta
  /// obtener la descripción en ese idioma. Si no se dispone una descripción en
  /// ese idioma o no se proporciona [lang] se devuelve la descripción en
  /// inglés. Si no se dispone de la descripción en inglés se devuelve la
  /// primera disponible.
  String getAComment({String? lang}) {
    try {
      if (comments.isEmpty) return '';
      if (lang is String) {
        return comments
            .firstWhere((PairLang p) => p.hasLang && p.lang == lang)
            .value;
      } else {
        return comments
            .firstWhere((PairLang p) => p.hasLang && p.lang == "en")
            .value;
      }
    } catch (e) {
      return comments.first.value;
    }
  }

  /// Recupera todas las descripciones del [Feed]
  List<PairLang> get comments => _comments;

  /// Establece las descripciones del [Feed]
  set comments(List<PairLang> comments) {
    _comments = comments;
  }

  /// Permite agregar un [comment] al [Feed]. Si el idioma de la descripción no se
  /// encuentra disponible se agrega a las descripciones del [Feed] devolviendo
  /// verdadero.
  bool addComment(PairLang comment) {
    Iterable<PairLang> coincidencias = _comments.where((PairLang p) => p.hasLang
        ? comment.hasLang
            ? comment.lang == p.lang && p.value == comment.value
            : false
        : comment.hasLang
            ? false
            : p.value == comment.value);
    if (coincidencias.isEmpty) {
      _comments.add(comment);
      return true;
    }
    return false;
  }

  // /// Recupera la lista de suscriptores del [Feed].
  // List<Subscriber> get subscribers => _subscribers;

  // /// Establece la lista de abonados del [Feed].
  // set subscribers(List<Subscriber> subscribers) {
  //   _subscribers = subscribers;
  // }

  // /// Agrega un [subscriber] al [Feed]. Devuelve true si lo agrega.
  // bool addSubscriber(Subscriber subscriber) {
  //   Iterable<Subscriber> coincidencias =
  //       _subscribers.where((Subscriber p) => p.id == subscriber.id);
  //   if (coincidencias.isEmpty) {
  //     _subscribers.add(subscriber);
  //     return true;
  //   }
  //   return false;
  // }

  // /// Borra un [subscriber] del [Feed]. Devuelve verdadero si borra un abonado.
  // bool removeSubscriber(Subscriber subscriber) {
  //   int initialLength = subscribers.length;
  //   _subscribers.removeWhere((Subscriber p) => subscriber.id == p.id);
  //   return initialLength > subscribers.length;
  // }

  // /// Devuelve la lista de identificadores de las [Feature] del [Feed]
  // List<String> get listFeatures => _lstFeatures;

  // /// Devuelve la lista de identificadores de la [Task] del [Feed]
  // List<String> get listTasks => _lstTasks;

  // /// Devuelve la lista de identificadores de los [Itinerary] del [Feed]
  // List<String> get listItineraries => _lstItineraries;

  // /// Recupera una [Feature] del [Feed] utilizando el [id] del recurso. La
  // /// instancia de la feature debe estar en el [Feed] para evitar excepciones.
  // Feature? getAFeature(String id) {
  //   if (listFeatures.contains(id)) {
  //     int index = _features.indexWhere((Feature feature) => feature.id == id);
  //     return index > -1 ? _features.elementAt(index) : null;
  //   } else {
  //     throw FeedException('No feature with that ID');
  //   }
  // }

  // /// Recupera todas las instancias [Feature] del canal que estén en el objeto
  // List<Feature> get features => _features;

  // /// Recupera todas las instancias [Task] del canal
  // List<Task> get tasks => _tasks;

  // /// Recupera todas las instancias [Itinerary] del canal
  // List<Itinerary> get itineraries => _itineraries;

  // /// Establece todas las instancias de tipo [Itinerary] del canal
  // set itineraries(List<Itinerary> itineraries) {
  //   _itineraries = itineraries;
  //   _lstItineraries = [];
  //   for (Itinerary it in itineraries) {
  //     _lstItineraries.add(it.id!);
  //   }
  // }

  // List<PointItinerary> get lstStLt => _stLt;
  // set lstStLt(List<PointItinerary> lstStLt) {
  //   _stLt = lstStLt;
  // }

  // bool addStLt(PointItinerary stLt) {
  //   Iterable<PointItinerary> coincidencias =
  //       _stLt.where((PointItinerary pit) => pit.id == stLt.id);
  //   if (coincidencias.isEmpty) {
  //     _stLt.add(stLt);
  //     _lstStLt.add(stLt.id);
  //     return true;
  //   }
  //   return false;
  // }

  // bool removeStLt(PointItinerary stLt) {
  //   Iterable<PointItinerary> coincidencias =
  //       _stLt.where((PointItinerary pit) => pit.id == stLt.id);
  //   if (coincidencias.isEmpty) {
  //     _stLt.removeWhere((PointItinerary pit) => pit.id == stLt.id);
  //     _lstStLt.remove(stLt.id);
  //     return true;
  //   }
  //   return false;
  // }

  // List<String> get lstSt {
  //   List<String> sts = [];
  //   for (PointItinerary pit in lstStLt) {
  //     if (pit.hasFeature) {
  //       sts.add(pit.feature.id);
  //     }
  //   }
  //   return sts;
  // }

  // List<String> get lstLt {
  //   List<String> lts = [];
  //   for (PointItinerary pit in lstStLt) {
  //     if (pit.hasLstTasks) {
  //       for (Task task in pit.tasksObj) {
  //         lts.add(task.id);
  //       }
  //     }
  //   }
  //   return lts;
  // }

  // /// Recupera un [Itinerary] del [Feed] a través de su [id]. Una instancia del
  // /// itinerario debe estar dispoible en el [Feed] para evitar que se lance la
  // /// excepción [FeedException]
  // Itinerary? getAItinerary(String id) {
  //   if (listItineraries.contains(id)) {
  //     int index =
  //         _itineraries.indexWhere((Itinerary itinerary) => itinerary.id == id);
  //     return index > -1 ? _itineraries.elementAt(index) : null;
  //   } else {
  //     throw FeedException('No itinerary with that ID');
  //   }
  // }

  // /// Agrega un [Itinerary] al [Feed]. Devuelve verdadero si se consigue agregar
  // bool addItinerary(Itinerary itinerary) {
  //   Iterable<Itinerary> coincidencias =
  //       _itineraries.where((Itinerary it) => it.id == itinerary.id);
  //   if (coincidencias.isEmpty) {
  //     _itineraries.add(itinerary);
  //     _lstItineraries.add(itinerary.id!);
  //     return true;
  //   }
  //   return false;
  // }

  // /// Borra un [Itinerary] del [Feed]. Devuelve verdadero si se consigue borrar
  // bool removeItinerary(Itinerary itinerary) {
  //   Iterable<Itinerary> coincidencias =
  //       _itineraries.where((Itinerary it) => it.id == itinerary.id);
  //   if (coincidencias.isEmpty) {
  //     _itineraries.removeWhere((Itinerary it) => it.id == itinerary.id);
  //     _lstItineraries.remove(itinerary.id);
  //     return true;
  //   }
  //   return false;
  // }

  Map<String, dynamic> toJson() => toMap();

  Map<String, dynamic> toMap() {
    Map<String, dynamic> out = {};
    if (id.isNotEmpty) {
      out['id'] = id;
      out['shortId'] = shortId;
      out['iri'] = iri;
    }

    if (pass.isNotEmpty) {
      out['password'] = pass;
    }

    out['labels'] = labels.first.toMap();
    out['comments'] = comments.first.toMap();

    // out['feeders'] = [];
    // for (Feeder feeder in _feeders) {
    //   out['feeders'].add(feeder.toJson());
    // }

    // if (lstStLt.isNotEmpty) {
    //   List<Map<String, dynamic>> stlt = [];
    //   for (PointItinerary pit in lstStLt) {
    //     stlt.add(pit.toMap());
    //   }
    //   if (stlt.isNotEmpty) {
    //     out['stlt'] = stlt;
    //   }
    // }

    // if (itineraries.isNotEmpty) {
    //   List<Map<String, dynamic>> its = [];
    //   for (Itinerary it in itineraries) {
    //     its.add(it.toMap());
    //   }
    //   if (its.isNotEmpty) {
    //     out['itineraries'] = its;
    //   }
    // }

    // if (subscribers.isNotEmpty) {
    //   List<Map<String, dynamic>> sbs = [];
    //   for (Subscriber sb in subscribers) {
    //     sbs.add(sb.toMap());
    //   }
    //   if (sbs.isNotEmpty) {
    //     out['subscribers'] = sbs;
    //   }
    // }

    return out;
  }
}

// /// Clase en la que se define los parámetros del creador de un canal
// class Feeder {
//   late String _id, _alias;
//   late List<PairLang> comments;

//   /// Constructor con el que se define al autor. Es necesario proporcionar
//   /// un [id] y el [alias] del usuario para el canal.
//   Feeder(String id, String alias) {
//     _id = id;
//     _alias = alias;
//     comments = [];
//   }

//   /// Constructor de la persona autora del canal. Extrae los datos de [data],
//   /// un objeto clave-valor. Es necesario que [data] disponga de las claves
//   /// id y alias. Opcionalmente también se pueden proporcionar descripciones
//   /// personalizadas para este autor y su canal a través de la clave comments.
//   Feeder.json(Map<String, dynamic> data) {
//     if (data.containsKey('id') && data['id'] is String) {
//       _id = data['id'];
//     } else {
//       throw FeederException('No found id');
//     }

//     if (data.containsKey('alias') && data['alias'] is String) {
//       _alias = data['alias'];
//     } else {
//       throw FeederException('No found alias');
//     }

//     comments = [];
//     if (data.containsKey('comments')) {
//       if (data['comments'] is String) {
//         data['comments'] = {'value': comments};
//       }
//       if (data['comments'] is Map<String, dynamic>) {
//         data['comments'] = [data['comments']];
//       }
//       if (data['comments'] is List) {
//         for (Map<String, dynamic> comment in data['comments']) {
//           if (comment.containsKey('value')) {
//             comments.add(comment.containsKey('lang')
//                 ? PairLang(comment['lang'], comment['value'])
//                 : PairLang.withoutLang(comment['value']));
//           } else {
//             throw FeederException(
//                 'Problem with comment: ${comment.toString()}');
//           }
//         }
//       } else {
//         throw FeederException('Problem with comments');
//       }
//     }
//   }

//   /// Identificador del usuario en el canal
//   String get id => _id;

//   /// Alias del usuario en el canal
//   String get alias => _alias;

//   /// Recupera la descripción del usuario en el canal. Se puede indicar
//   /// el idioma deseado a través del parámetro [lang]
//   String getAComment({String? lang}) {
//     String out = '';
//     if (lang != null) {
//       out = _objLang(lang) != null ? _objLang(lang)! : '';
//     }
//     if (out.isEmpty) {
//       out = _objLang('en') != null
//           ? _objLang('en')!
//           : comments.isNotEmpty
//               ? comments.first.value
//               : '';
//     }
//     return out;
//   }

//   String? _objLang(String lang) {
//     String auxiliar = comments.isEmpty ? '' : comments[0].value;
//     for (var e in comments) {
//       if (e.hasLang) {
//         if (e.lang == lang) {
//           return e.value;
//         }
//       }
//     }
//     return auxiliar;
//   }

//   /// Tansforma el usuario del canal en un mapa
//   Map<String, dynamic> toJson() => toMap();

//   /// Tansforma el usuario del canal en un mapa
//   Map<String, dynamic> toMap() {
//     Map<String, dynamic> out = {'id': id, 'alias': alias};
//     List<String> lst = [];
//     for (PairLang comment in comments) {
//       lst.add(jsonEncode(comment.toJson()));
//     }
//     if (lst.isNotEmpty) {
//       out['comments'] = lst;
//     }
//     return out;
//   }
// }

/// Clase para definir los usuarios que se han apuntado a un canal
class Subscriber {
  late String _id, _alias;
  late DateTime _date;
  late int _nAnswers;
  late List<Answer> _answers;

  /// Constructor del participante en el canal
  Subscriber(data) {
    if (data is Map) {
      if (data.containsKey('id') &&
          data['id'] is String &&
          data['id'].isNotEmpty) {
        _id = data['id'];
      } else {
        throw SubscriberException('No ID');
      }

      if (data.containsKey('date') &&
          data['date'] is String &&
          data['date'].trim().isNotEmpty) {
        _date = DateTime.parse(data['date'].trim());
      } else {
        throw SubscriberException('No date');
      }

      if (data.containsKey('alias') &&
          data['alias'] is String &&
          data['alias'].trim().isNotEmpty) {
        _alias = data['alias'].trim();
      } else {
        _alias = 'Student';
      }

      _answers = [];
      if (data.containsKey('answers') && data['answers'] is List) {
        for (Map<String, dynamic> answer in data['answers']) {
          _answers.add(Answer(answer));
        }
        _nAnswers = _answers.length;
      } else {
        if (data.containsKey('nAnswers') && data['nAnswers'] is int) {
          _nAnswers = data['nAnswers'];
        } else {
          throw SubscriberException('No nAnswer');
        }
      }
    } else {
      throw SubscriberException(
          'Problem with the data retrieve from the server');
    }
    _answers = [];
  }

  /// Recupera las respuestas del usuario asociadas al canal
  List<Answer> get answers => _answers;

  /// Borra todas las respuestas del usuario asociadas al canal
  void resetAnsers() {
    _answers = [];
  }

  /// Agrega una respuesta al participante
  bool addAnswer(Answer answer) {
    Iterable<Answer> coincidencias =
        _answers.where((Answer a) => a.id == answer.id);
    if (coincidencias.isEmpty) {
      _answers.add(answer);
      return true;
    }
    return false;
  }

  /// Elimina una respuesta del participante
  bool removeAnswer(Answer answer) {
    int initialLength = _answers.length;
    _answers.removeWhere((Answer a) => a.id == answer.id);
    return initialLength > _answers.length;
  }

  String get id => _id;
  String get alias => _alias;
  DateTime get date => _date;
  int get nAnswers => _nAnswers;

  Map<String, dynamic> toMap() => toJson();

  Map<String, dynamic> toJson() {
    Map<String, dynamic> out = {};
    out['id'] = _id;
    out['date'] = _date.toIso8601String();
    if (_alias != 'Student') {
      out['alias'] = _alias;
    }
    out['nAnswers'] = _nAnswers;
    List<String> lst = [];
    for (Answer answer in answers) {
      lst.add(jsonEncode(answer.toMap()));
    }
    if (lst.isNotEmpty) {
      out['answers'] = lst;
    }
    return out;
  }
}
