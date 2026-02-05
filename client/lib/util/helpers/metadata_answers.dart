class MetadataAnswers {
  late String _idPoi, _idTask;
  final List<SlotMetadataAnswer> _history = [];

  MetadataAnswers(idPoi, idTask, history) {
    _idPoi = idPoi is String && idPoi.trim().isNotEmpty
        ? idPoi.trim()
        : throw Exception("idPoi problem");
    _idTask = idTask is String && idTask.trim().isNotEmpty
        ? idTask.trim()
        : throw Exception("idTask problem");
    if (history is! List) {
      history = [history];
    }

    for (dynamic element in history) {
      if (element is Map) {
        _history.add(SlotMetadataAnswer(element["hasOptionalText"],
            element["finishClient"], element["time2Complete"]));
      } else {
        if (element is SlotMetadataAnswer) {
          _history.add(element);
        } else {
          throw Exception('history problem');
        }
      }
    }
  }

  String get idPoi => _idPoi;
  String get idTask => _idTask;
  List<SlotMetadataAnswer> get history => _history;
}

class SlotMetadataAnswer {
  late bool _hasOptionalText;
  late int _finishClient, _time2Complete;
  SlotMetadataAnswer(hasOptionalText, finishClient, time2Complete) {
    _hasOptionalText = hasOptionalText is bool
        ? hasOptionalText
        : throw Exception("hasOptionalText problem");
    _finishClient = finishClient is int && finishClient > 0
        ? finishClient
        : throw Exception("finishClient problem");
    _time2Complete = time2Complete is int && time2Complete > 0
        ? time2Complete
        : throw Exception("time2Complete problem");
  }

  bool get hasOptionalText => _hasOptionalText;
  int get finishClient => _finishClient;
  int get time2Complete => _time2Complete;
}
