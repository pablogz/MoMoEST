import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/exceptions.dart';
import 'package:momoest/util/helpers/pair.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class Task {
  /// La tarea puede estar contenida en un spatial thing o en un itineario
  late ContainerTask? _container;
  late String _id, _author, _idContainer;
  final List<Space> _space = [];
  late AnswerType aT;
  late bool _hasLabel,
      _correctTF,
      _hasCorrectTF,
      _hasCorrectMCQ,
      _hasExpectedAnswer,
      singleSelection,
      isEmpty;
  final List<PairLang> _label = [],
      _comment = [],
      _distractors = [],
      _correctAnswer = [];
  late PairImage? _image;

  /// Constructor de una tarea vacía. Solo se necesista un identificador del contenedor [idContainer].
  Task.empty({ContainerTask? containerType, String? idContainer}) {
    _container = containerType;
    _idContainer = idContainer ?? '';
    _id = '';
    _author = '';
    aT = AnswerType.noAnswer;
    _hasLabel = false;
    _hasCorrectTF = false;
    _hasCorrectMCQ = false;
    _hasExpectedAnswer = false;
    _image = null;
    singleSelection = true;
    isEmpty = true;
  }

  /// Constructor de una tarea vacía. Se necesista un identificador del contenedor [idContainer] y un mapa [data] con los datos de la tarea.
  Task(dynamic data, {ContainerTask? containerType, String? idContainer}) {
    try {
      _container = containerType;
      _idContainer = idContainer ?? '';
      if (data != null && data is Map) {
        if (data.containsKey('task') &&
            data['task'] is String &&
            data['task'].toString().isNotEmpty) {
          _id = data['task'];
        } else {
          throw TaskException('task');
        }

        if (data.containsKey('comment')) {
          if (data['comment'] is String) {
            data['comment'] = {'value': data['comment']};
          }
          setComments(data['comment']);
        } else {
          throw TaskException('comment');
        }

        if (data.containsKey('author') &&
            data['author'] is String &&
            data['author'].toString().isNotEmpty) {
          _author = data['author'];
        } else {
          throw TaskException('author');
        }

        if (data.containsKey('space')) {
          if (data['space'] is String && data['space'].toString().isNotEmpty) {
            data['space'] = [data['space']];
          }
          if (data['space'] is List) {
            for (var s in data['space']) {
              switch (s) {
                case 'http://moult.gsic.uva.es/ontology/PhysicalSpace':
                  _space.add(Space.physical);
                  break;
                case 'http://moult.gsic.uva.es/ontology/VirtualSpace':
                  _space.add(Space.virtual);
                  break;
                case 'http://moult.gsic.uva.es/ontology/Web':
                  _space.add(Space.web);
                  break;
                default:
                  throw TaskException('space');
              }
            }
            _space.sort((Space a, Space b) => a.name.compareTo(b.name));
          } else {
            throw TaskException('space');
          }
        } else {
          throw TaskException('space');
        }

        if (data.containsKey('at') &&
            data['at'] is String &&
            data['at'].toString().isNotEmpty) {
          // TODO cambiar cuando se cambie de dominio
          switch (data['at']) {
            case 'http://moult.gsic.uva.es/ontology/mcq':
            case 'http://moult.gsic.uva.es/ontology/MCQ':
              aT = AnswerType.mcq;
              break;
            case 'http://moult.gsic.uva.es/ontology/tf':
            case 'http://moult.gsic.uva.es/ontology/TF':
              aT = AnswerType.tf;
              break;
            case 'http://moult.gsic.uva.es/ontology/photo':
            case 'http://moult.gsic.uva.es/ontology/Photo':
              aT = AnswerType.photo;
              break;
            case 'http://moult.gsic.uva.es/ontology/multiplePhotos':
            case 'http://moult.gsic.uva.es/ontology/MultiplePhotos':
              aT = AnswerType.multiplePhotos;
              break;
            case 'http://moult.gsic.uva.es/ontology/video':
            case 'http://moult.gsic.uva.es/ontology/Video':
              aT = AnswerType.video;
              break;
            case 'http://moult.gsic.uva.es/ontology/photoText':
            case 'http://moult.gsic.uva.es/ontology/PhotoText':
              aT = AnswerType.photoText;
              break;
            case 'http://moult.gsic.uva.es/ontology/videoText':
            case 'http://moult.gsic.uva.es/ontology/VideoText':
              aT = AnswerType.videoText;
              break;
            case 'http://moult.gsic.uva.es/ontology/multiplePhotosText':
            case 'http://moult.gsic.uva.es/ontology/MultiplePhotosText':
              aT = AnswerType.multiplePhotosText;
              break;
            case 'http://moult.gsic.uva.es/ontology/text':
            case 'http://moult.gsic.uva.es/ontology/Text':
              aT = AnswerType.text;
              break;
            case 'http://moult.gsic.uva.es/ontology/noAnswer':
            case 'http://moult.gsic.uva.es/ontology/NoAnswer':
              aT = AnswerType.noAnswer;
              break;
            case 'http://momoest.gsic.uva.es/ontology/UploadFile':
              aT = AnswerType.uploadFile;
              break;
            case 'http://momoest.gsic.uva.es/ontology/Draw':
              aT = AnswerType.draw;
              break;
            default:
              throw TaskException('at');
          }
        } else {
          throw TaskException('at');
        }
      } else {
        throw TaskException('Object is null or different of a Map');
      }

      // OPTIONALS
      if (data.containsKey('label')) {
        if (data['label'] is String) {
          data['label'] = {'value': data['label']};
        }
        try {
          setLabels(data['label']);
        } catch (error, stackTrace) {
          if (ConfigXest.development) {
            debugPrint(error.toString());
          } else {
            FirebaseCrashlytics.instance.recordError(error, stackTrace);
          }
          _hasLabel = false;
        }
      } else {
        _hasLabel = false;
      }
      switch (aT) {
        case AnswerType.tf:
          singleSelection = true;
          if (_hasCorrectTF =
              (data.containsKey('correct') && data['correct'] is bool)) {
            _correctTF = data['correct'];
          }
          break;
        case AnswerType.mcq:
          if (_hasCorrectMCQ = data.containsKey('correct')) {
            setCorrectMCQ(data['correct']);
          }
          if (data.containsKey('distractor')) {
            setDistractorMCQ(data['distractor']);
          }
          singleSelection = data.containsKey('singleSelection') &&
              data['singleSelection'] is bool &&
              data['singleSelection'];
          break;
        default:
          _hasCorrectTF = false;
          _hasCorrectMCQ = false;
          _hasExpectedAnswer = false;
          singleSelection = true;
      }

      if (data.containsKey('image')) {
        if (data['image'] is String) {
          data['image'] = {'image': data['image']};
        }
        if (data['image'] is Map) {
          if (data['image']['image'] is String) {
            _image = data['image'].containsKey('license') &&
                    data['image']['license'] is String
                ? PairImage(data['image']['image'], data['image']['license'])
                : PairImage.withoutLicense(data['image']['image']);
          } else {
            throw TaskException('Image is not valid');
          }
        } else {
          throw TaskException('Image is not valid');
        }
      } else {
        _image = null;
      }

      isEmpty = false;
    } on Exception catch (e) {
      throw TaskException(e.toString());
    }
  }

  String get id => _id;
  set id(String id) =>
      id.trim().isEmpty ? throw TaskException('id empty') : _id = id;
  String get author => _author;
  set author(String author) => author.trim().isEmpty
      ? throw TaskException('author empty')
      : _author = author;
  String get idContainer => _idContainer;
  set idContainer(String? idContainer) {
    if (_idContainer.isEmpty) {
      _idContainer = idContainer!;
    } else {
      throw TaskException('Id container previamente definido');
    }
  }

  ContainerTask? get containerType => _container;
  set containerType(ContainerTask? containerType) {
    if (_container == null && containerType != null) {
      _container = containerType;
    } else {
      throw TaskException('Tipo de contenedor previamente definido');
    }
  }

  List<Space> get spaces => _space;
  List<PairLang> get comments => _comment;
  List<PairLang> get labels =>
      _hasLabel ? _label : throw TaskException('Task has no labels!!');
  String? labelLang(String lang) => _hasLabel
      ? _objLang('label', lang)
      : throw TaskException('Task has no label!!');
  String? commentLang(String lang) => _objLang('comment', lang);
  bool get hasLabel => _hasLabel;
  bool get hasCorrectTF => _hasCorrectTF;
  bool get hasCorrectMCQ => _hasCorrectMCQ;
  bool get hasExpectedAnswer => _hasExpectedAnswer;

  bool get correctTF => _hasCorrectTF
      ? _correctTF
      : throw TaskException('it does not have correctTF');
  set correctTF(bool correcTF) {
    _hasCorrectTF = true;
    _correctTF = correcTF;
  }

  List<PairLang> get correctMCQ => _hasCorrectMCQ
      ? _correctAnswer
      : throw TaskException('it does not have correctMCQ');
  set correctMCQ(List<PairLang> correctMCQ) {
    if (correctMCQ.isNotEmpty) {
      for (PairLang cMCQ in correctMCQ) {
        if (_correctAnswer
                .indexWhere((PairLang element) => element.value == cMCQ.value) >
            -1) {
          _correctAnswer.add(cMCQ);
        }
      }
      _hasCorrectMCQ = _correctAnswer.isNotEmpty;
    }
  }

  void setCorrectMCQ(cMCQS) {
    if (cMCQS is String) {
      cMCQS = {'value': cMCQS};
    }
    if (cMCQS is Map) {
      cMCQS = [cMCQS];
    }
    if (cMCQS is List) {
      for (var element in cMCQS) {
        if (element is Map && element.containsKey('value')) {
          element.containsKey('lang')
              ? addCorrectMCQ(element['value'], lang: element['lang'])
              : addCorrectMCQ(element['value']);
        } else {
          if (element is String) {
            addCorrectMCQ(element);
          } else {
            throw TaskException('cMCQS');
          }
        }
      }
    } else {
      throw TaskException('cMCQS');
    }
  }

  void addCorrectMCQ(String value, {String? lang}) {
    String c = value.trim();
    if (c.isNotEmpty) {
      if (_correctAnswer.indexWhere((PairLang pl) => pl.value == c) == -1) {
        _correctAnswer.add(
            lang != null ? PairLang(lang, value) : PairLang.withoutLang(value));
        _hasCorrectMCQ = _correctAnswer.isNotEmpty;
      }
    }
  }

  removeCorrect(PairLang correctMCQ) {
    _correctAnswer.remove(correctMCQ);
    _hasCorrectMCQ = _correctAnswer.isNotEmpty;
  }

  List<PairLang> get expectedAnswer => _hasExpectedAnswer
      ? _correctAnswer
      : throw TaskException('it does not have expectedAnswer');
  set expectedAnswer(List<PairLang> expectedAnswer) {
    if (expectedAnswer.isNotEmpty) {
      for (PairLang eA in expectedAnswer) {
        if (_correctAnswer.indexWhere((PairLang ele) => ele.value == eA.value) >
            -1) {
          _correctAnswer.add(eA);
        }
      }
      _hasExpectedAnswer = _correctAnswer.isNotEmpty;
    }
  }

  void addSpace(spaceS) => setSpaces(spaceS);
  void setSpaces(spaceS) {
    if (spaceS is Space) {
      spaceS = [spaceS];
    }
    if (spaceS is String) {
      switch (spaceS) {
        case 'http://moult.gsic.uva.es/ontology/PhysicalSpace':
          spaceS = [Space.physical];
          break;
        case 'http://moult.gsic.uva.es/ontology/VirtualSpace':
          spaceS = [Space.virtual];
          break;
        case 'http://moult.gsic.uva.es/ontology/Web':
          spaceS = [Space.web];
          break;
        default:
          throw TaskException('spaceS');
      }
    }
    if (spaceS is List) {
      for (var element in spaceS) {
        if (!_space.contains(element)) {
          _space.add(element);
        }
      }
    } else {
      throw TaskException('spaceS');
    }
  }

  void addLabel(Map labelS) => setLabels(labelS);
  void setLabels(labelS) {
    if (labelS is Map) {
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
          throw TaskException('labelS');
        }
      }
      _hasLabel = true;
    } else {
      throw TaskException('labelS');
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

  void addComment(Map commentS) => setComments(commentS);
  void setComments(commentS) {
    if (commentS is Map) {
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
          throw TaskException('commentS');
        }
      }
    } else {
      throw TaskException('commentS');
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
        throw TaskException('switch _objLang');
    }
    for (var e in pl) {
      if (e.hasLang && e.lang == lang) {
        return e.value;
      } else {
        //Las generadas de manera semiauto no tienen idioma
        return e.value;
      }
    }
    return null;
  }

  List<PairLang> get distractors => _distractors;

  void setDistractorMCQ(dMCQS) {
    if (dMCQS is Map) {
      dMCQS = [dMCQS];
    }
    if (dMCQS is List) {
      for (var element in dMCQS) {
        if (element is Map && element.containsKey('value')) {
          element.containsKey('lang')
              ? addDistractor(PairLang(element['lang'], element['value']))
              : addDistractor(PairLang.withoutLang(element['value']));
        } else {
          if (element is String) {
            addDistractor(PairLang.withoutLang(element));
          } else {
            throw TaskException('dMCQS');
          }
        }
      }
    } else {
      throw TaskException('dMCQS');
    }
  }

  addDistractor(PairLang distractor) {
    if (_distractors.indexWhere(
            (PairLang element) => element.value == distractor.value) ==
        -1) {
      _distractors.add(distractor);
    }
  }

  removeDistractor(PairLang distractor) {
    _distractors.removeWhere((element) => element.value == distractor.value);
  }

  List<Map<String, String>> comments2List() => _object2List(comments);

  List<Map<String, String>> labels2List() => _object2List(labels);

  List<Map<String, String>> correctsMCQ2List() => _object2List(correctMCQ);

  List<Map<String, String>> distractorsMCQ2List() => _object2List(distractors);

  List<Map<String, String>> _object2List(obj) {
    List<Map<String, String>> out = [];
    for (var element in obj) {
      out.add(element.toMap());
    }
    return out;
  }

  PairImage? get image => _image;
  set image(dynamic image) {
    if (image is String) {
      image = {'image': image};
    }
    if (image is Map) {
      if (image['image'] is String) {
        _image = image.containsKey('license') && image['license'] is String
            ? PairImage(image['image'], image['license'])
            : PairImage.withoutLicense(image['image']);
      } else {
        throw TaskException('Image is not valid');
      }
    } else {
      //Null para borrar
      if (image is PairImage || image == null) {
        _image = image;
      } else {
        throw TaskException('Image is not valid');
      }
    }
  }

  Map<String, dynamic> toMap() {
    if (isEmpty) {
      return {};
    } else {
      Map<String, dynamic> out = {
        'id': id,
        'author': author,
        'idContainer': idContainer,
        'label': hasLabel ? labels2List() : '',
        'comment': comments2List(),
        'typeContainer': containerType!.name,
        'aT': aT.name,
      };
      out['inSpace'] = [];
      for (Space space in spaces) {
        out['inSpace'].add(space.name);
      }

      switch (aT) {
        case AnswerType.mcq:
          if (hasCorrectMCQ) {
            out['correct'] = correctsMCQ2List();
          }
          if (distractors.isNotEmpty) {
            out['distractors'] = distractorsMCQ2List();
          }
          out['singleSelection'] = singleSelection;
          break;
        case AnswerType.tf:
          if (hasCorrectTF) {
            out['correct'] = correctTF;
          }
          break;
        default:
      }

      if (image is PairImage) {
        out['image'] = image!.toMap();
      }

      return out;
    }
  }
}

enum Space { virtual, web, physical }

extension SpaceString on Space {
  String get rdf {
    switch (this) {
      case Space.physical:
        return 'http://moult.gsic.uva.es/ontology/PhysicalSpace';
      case Space.virtual:
        return 'http://moult.gsic.uva.es/ontology/VirtualSpace';
      case Space.web:
        return 'http://moult.gsic.uva.es/ontology/Web';
      default:
        throw SpaceException('Problem with rdf');
    }
  }
}

enum AnswerType {
  mcq,
  tf,
  photo,
  multiplePhotos,
  video,
  photoText,
  videoText,
  multiplePhotosText,
  text,
  noAnswer,
  uploadFile,
  draw
}

enum ContainerTask { spatialThing, itinerary }
