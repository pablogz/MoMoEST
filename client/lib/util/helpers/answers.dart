import 'package:momoest/util/exceptions.dart';
import 'package:momoest/util/helpers/feature.dart';
import 'package:momoest/util/helpers/tasks.dart';

// import 'package:nest/util/helpers/auxiliar_mobile.dart'
//     if (dart.library.html) 'package:nest/util/helpers/auxiliar_web.dart';

class Answer {
  late String _id,
      _idContainer,
      _idTask,
      _labelContainer,
      _commentTask,
      _feedback;
  late AnswerType _answerType;
  late bool _hasId,
      _hasContainer,
      _hasTask,
      _hasAnswerType,
      _hasAnswer,
      _hasExtraText,
      _hasLabelContainer,
      _hasCommentTask,
      _hasCompleteTask,
      _hasCompleteFeature,
      _hasFeedback;
  final Map<String, dynamic> _answer = {};
  late int _timestamp, _time2Complete;
  late Task _task;
  late Feature _feature;

  Answer(dynamic data) {
    if (data is Map) {
      if (data.containsKey('id') &&
          data['id'] is String &&
          data['id'].trim().isNotEmpty) {
        _id = data['id'].trim();
        _hasId = true;
      } else {
        throw AnswerException('id');
      }

      if (data.containsKey('idContainer') &&
          data['idContainer'] is String &&
          data['idContainer'].trim().isNotEmpty) {
        _idContainer = data['idContainer'].trim();
        _hasContainer = true;
      } else {
        if (data.containsKey('idFeature') &&
            data['idFeature'] is String &&
            data['idFeature'].trim().isNotEmpty) {
          _idContainer = data['idFeature'].trim();
        } else {
          throw AnswerException('idContainer');
        }
      }

      if (data.containsKey('labelContainer') &&
          data['labelContainer'] is String &&
          data['labelContainer'].trim().isNotEmpty) {
        _labelContainer = data['labelContainer'].trim();
        _hasLabelContainer = true;
      } else {
        _hasLabelContainer = false;
      }

      if (data.containsKey('idTask') &&
          data['idTask'] is String &&
          data['idTask'].trim().isNotEmpty) {
        _idTask = data['idTask'].trim();
        _hasTask = true;
      } else {
        throw AnswerException('idTask');
      }

      if (data.containsKey('commentTask') &&
          data['commentTask'] is String &&
          data['commentTask'].trim().isNotEmpty) {
        _commentTask = data['commentTask'].trim();
        _hasCommentTask = true;
      } else {
        _hasCommentTask = false;
      }

      if (data.containsKey('answerType')) {
        if (data['answerType'] is AnswerType) {
          _answerType = data['answerType'];
          _hasAnswerType = true;
        } else {
          if (data['answerType'] is String) {
            for (AnswerType at in AnswerType.values) {
              if (data['answerType'] == at.name) {
                _answerType = at;
                _hasAnswerType = true;
                break;
              }
            }
            if (!hasAnswerType) {
              throw AnswerException('answerType not found');
            }
          } else {
            throw AnswerException(
                'answerType is not a String or an AnswerType');
          }
        }
      } else {
        throw AnswerException('answerType not found in data');
      }

      if (data.containsKey('answer')) {
        if (data['answer'] is bool) {
          _answer['answer'] = data['answer'];
          _answer['timestamp'] = DateTime.now().millisecondsSinceEpoch;
          _hasExtraText = false;
        } else {
          if (data['answer'] is String && data['answer'].trim().isNotEmpty) {
            _answer['answer'] = data['answer'].trim();
            _answer['timestamp'] = DateTime.now().millisecondsSinceEpoch;
            _hasExtraText = false;
          } else {
            if (data['answer'] is Map) {
              (data['answer'] as Map).forEach((k, v) => _answer[k] = v);
              if (data['extraText'] != null) {
                _answer['extraText'] = data['extraText'];
                _hasExtraText = true;
              } else {
                _hasExtraText = false;
              }
            } else {
              throw AnswerException("answer type");
            }
          }
        }
      }
      _hasAnswer = true;
      _time2Complete = -1;
      _timestamp = -1;
      _hasCompleteTask = false;
      _hasCompleteFeature = false;

      if (data.containsKey('feedback') &&
          data['feedback'] is String &&
          data['feedback'].trim().isNotEmpty) {
        _feedback = data['feedback'];
        _hasFeedback = true;
      } else {
        _hasFeedback = false;
      }
    } else {
      AnswerException('Data is not a Map');
    }
  }

  Answer.withoutAnswer(dynamic data) {
    if (data is Map) {
      if (data.containsKey('idContainer') &&
          data['idContainer'] is String &&
          data['idContainer'].trim().isNotEmpty) {
        _idContainer = data['idContainer'].trim();
        _hasContainer = true;
      } else {
        throw AnswerException('idContainer');
      }

      if (data.containsKey('idTask') &&
          data['idTask'] is String &&
          data['idTask'].trim().isNotEmpty) {
        _idTask = data['idTask'].trim();
        _hasTask = true;
      } else {
        throw AnswerException('idTask');
      }

      if (data.containsKey('answerType')) {
        if (data['answerType'] is AnswerType) {
          _answerType = data['answerType'];
          _hasAnswerType = true;
        } else {
          if (data['answerType'] is String) {
            for (AnswerType at in AnswerType.values) {
              if (data['answerType'] == at.name) {
                _answerType = at;
                _hasAnswerType = true;
                break;
              }
            }
            if (!hasAnswerType) {
              throw AnswerException('answerType not found');
            }
          } else {
            throw AnswerException(
                'answerType is not a String or an AnswerType');
          }
        }
      } else {
        throw AnswerException('answerType not found in data');
      }
      _hasFeedback = false;
      _feedback = '';
      _hasAnswer = false;
      _hasId = false;
      _hasExtraText = false;
      _time2Complete = -1;
      _timestamp = -1;
      _hasCompleteTask = false;
      _hasCompleteFeature = false;
      _hasLabelContainer = false;
      _hasCommentTask = false;
    } else {
      AnswerException('Data is not a Map');
    }
  }

  Answer.empty() {
    _hasLabelContainer = false;
    _hasCommentTask = false;
    _hasId = false;
    _hasContainer = false;
    _hasTask = false;
    _hasAnswerType = false;
    _hasAnswer = false;
    _hasExtraText = false;
    _time2Complete = -1;
    _timestamp = -1;
    _hasCompleteTask = false;
    _hasCompleteFeature = false;
    _hasFeedback = false;
    _feedback = '';
  }

  String get id =>
      _hasId ? _id : throw AnswerException('Answer does not have id!');
  set id(String idS) {
    if (idS.trim().isNotEmpty) {
      _id = idS.trim();
      _hasId = true;
    } else {
      throw AnswerException("Problem with idS");
    }
  }

  String get idContainer => _hasContainer
      ? _idContainer
      : throw AnswerException('Answer does not have idPoi!');
  set idContainer(String idPoiS) {
    if (idPoiS.trim().isNotEmpty) {
      _idContainer = idPoiS.trim();
      _hasContainer = true;
    } else {
      throw AnswerException("Problem with idPoiS");
    }
  }

  String get idTask => _hasTask
      ? _idTask
      : throw AnswerException('Answer does not have idTask!');
  set idTask(String idTaskS) {
    if (idTaskS.trim().isNotEmpty) {
      _idTask = idTaskS.trim();
      _hasTask = true;
    } else {
      throw AnswerException("Problem with idTaskS");
    }
  }

  AnswerType get answerType => _hasAnswerType
      ? _answerType
      : throw AnswerException('Problem with the AnswerType!');
  set answerType(AnswerType answerTypeS) {
    _answerType = answerTypeS;
    _hasAnswerType = true;
  }

  Map get answer =>
      _hasAnswer ? _answer : throw AnswerException('Problem with the answer');
  set answer(dynamic answerS) {
    if (answerS is bool) {
      _answer['answer'] = answerS;
      _answer['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      _hasAnswer = true;
      _hasExtraText = false;
    } else {
      if (answerS is String && answerS.trim().isNotEmpty) {
        _answer['answer'] = answerS.trim();
        _answer['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        _hasAnswer = true;
        _hasExtraText = false;
      } else {
        if (answerS is Map) {
          _answer.clear();
          answerS.forEach((k, v) => _answer[k] = v);
          _hasAnswer = true;
          _hasExtraText = _answer.containsKey('extraText');
        } else {
          throw AnswerException("Problem with answerS");
        }
      }
    }
  }

  String get labelContainer => _hasLabelContainer
      ? _labelContainer
      : throw AnswerException('Answer does not have labelPoi');
  set labelContainer(String labelPoi) {
    _labelContainer = labelPoi;
    _hasLabelContainer = true;
  }

  String get commentTask => _hasCommentTask
      ? _commentTask
      : throw AnswerException('Answer does not have commentTask');
  set commentTask(String commentTask) {
    _commentTask = commentTask;
    _hasCommentTask = true;
  }

  bool get hasId => _hasId;
  bool get hasContainer => _hasContainer;
  bool get hasTask => _hasTask;
  bool get hasAnswerType => _hasAnswerType;
  bool get hasAnswer => _hasAnswer;
  bool get hasExtraText => _hasExtraText;
  bool get hasLabelContainer => _hasLabelContainer;
  bool get hasCommentTask => _hasCommentTask;
  bool get hasFeedback => _hasFeedback;

  int get timestamp => _timestamp;
  set timestamp(int timestamp) {
    _timestamp = timestamp > 0
        ? timestamp
        : throw AnswerException('timestamp must be positive');
  }

  int get time2Complete => _time2Complete;
  set time2Complete(int time2Complete) {
    _time2Complete = time2Complete > 0
        ? time2Complete
        : throw AnswerException('time2Complete must be positive');
  }

  Task get task => _hasCompleteTask
      ? _task
      : Task.empty(idContainer: _hasContainer ? _feature.id : 'noId');
  set task(Task task) {
    _task = task;
    _hasCompleteTask = true;
  }

  Feature get feature => _hasCompleteFeature ? _feature : Feature.point(0, 0);
  set feature(Feature poi) {
    _feature = poi;
    _hasCompleteFeature = true;
  }

  String get feedback => _hasFeedback
      ? _feedback
      : throw AnswerException('Problem with the feedback');
  set feedback(String feedback) {
    _feedback = feedback.trim();
    _hasFeedback = _feedback.isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> body = {
      // 'idUser': Auxiliar.userCHEST.id,
      'idContainer': idContainer,
      'idTask': idTask,
      'answerType': answerType.name,
      'answerMetadata': {
        'hasOptionalText': hasExtraText,
        'finishClient': timestamp,
        'time2Complete': time2Complete
      }
    };
    if (hasAnswer) {
      body['answer'] = answer;
    }
    if (hasLabelContainer) {
      body['labelContainer'] = labelContainer;
    }
    if (hasCommentTask) {
      body['commentTask'] = commentTask;
    }
    if (hasFeedback) {
      body['feedback'] = feedback;
    }
    return body;
  }
}
