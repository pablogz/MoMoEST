import 'package:momoest/util/exceptions.dart';
import 'package:momoest/util/helpers/pair.dart';

class SuggestionSolr {
  final String id;
  final List<PairLang> _labels = [];
  late bool _hasLat, _hasLong, _hasScore;
  late double _lat, _long;
  late int _score;

  SuggestionSolr(this.id) {
    _hasLat = false;
    _hasLong = false;
    _hasScore = false;
  }

  bool get hasLat => _hasLat;
  double get lat => _hasLat ? _lat : throw SuggestionException('No lat');
  set lat(double lat) {
    if (lat < -90 || lat > 90) throw SuggestionException('Invalid latitude');
    _lat = lat;
    _hasLat = true;
  }

  bool get hasLong => _hasLong;
  double get long => _hasLong ? _long : throw SuggestionException('No long');
  set long(double long) {
    if (long < -180 || long > 180) {
      throw SuggestionException('Invalid longitude');
    }
    _long = long;
    _hasLong = true;
  }

  bool get hasScore => _hasScore;
  int get score => _hasScore ? _score : throw SuggestionException('No score');
  set score(int score) {
    if (score < 0) throw SuggestionException('Invalid score');
    _score = score;
    _hasScore = true;
  }

  List<PairLang> get labels => _labels;
  PairLang? label(lang) {
    int index = _labels.indexWhere((p) => p.lang == lang);
    return index != -1 ? _labels[index] : null;
  }

  PairLang? addLabel(PairLang pairLang) {
    if (_labels.indexWhere((p) => p.lang == pairLang.lang) == -1) {
      _labels.add(pairLang);
      return pairLang;
    }
    return null;
  }
}

class ReSug {
  late ReSugHeader _reSugHeader;
  late bool _hasReSugData, _hasReSelData;
  late ReSugData _reSugData;
  late ReSelData _reSelData;

  ReSug(response) {
    if (response is Map) {
      _reSugHeader = response.containsKey('responseHeader')
          ? ReSugHeader(response['responseHeader'])
          : throw ReSugException('No responseHeader');
      if (response.containsKey('suggest')) {
        _reSugData = ReSugData(response['suggest']);
        _hasReSelData = false;
        _hasReSugData = true;
      } else {
        if (response.containsKey('response')) {
          _reSelData = ReSelData(response['response']);
          _hasReSelData = true;
          _hasReSugData = false;
        } else {
          throw ReSugException('No suggest or response');
        }
      }
    } else {
      throw ReSugException('Response is not a Map');
    }
  }

  ReSugHeader get reSugHeader => _reSugHeader;
  bool get hasReSugData => _hasReSugData;
  ReSugData get reSugData =>
      _hasReSugData ? _reSugData : throw ReSugException('No reSugData');
  bool get hasReSelData => _hasReSelData;
  ReSelData get reSelData =>
      _hasReSelData ? _reSelData : throw ReSugException('No reSelData');
}

class ReSugHeader {
  late int _status;
  late int _qTime;
  late Map<String, dynamic> _params;

  ReSugHeader(responseHeader) {
    if (responseHeader is Map) {
      _status = responseHeader.containsKey('status')
          ? responseHeader['status']
          : throw ReSugHeaderException('No status');
      _qTime = responseHeader.containsKey('QTime')
          ? responseHeader['QTime']
          : throw ReSugHeaderException('No QTime');
      _params =
          responseHeader.containsKey('params') ? responseHeader['params'] : {};
    } else {
      throw ReSugHeaderException('ResponseHeader is not a Map');
    }
  }

  int get status => _status;
  int get qTime => _qTime;
  Map<String, dynamic> get params => _params;
}

class ReSugData {
  late List<ReSugDic> _reSugDics;
  late List<String> _langDics;

  ReSugData(suggestData) {
    if (suggestData is Map) {
      _reSugDics = [];
      _langDics = [];
      for (var key in suggestData.keys) {
        String? langKey = key == 'chestEn'
            ? 'en'
            : key == 'chestEs'
                ? 'es'
                : key == 'chestPt'
                    ? 'pt'
                    : null;
        if (langKey != null && !_langDics.contains(langKey)) {
          _reSugDics.add(ReSugDic(suggestData[key], langKey));
          _langDics.add(langKey);
        }
      }
    } else {
      throw ReSugDataException('SuggestData is not a Map');
    }
  }

  List<String> get langDics => _langDics;
  ReSugDic? getReSugDic(String lang) =>
      _langDics.contains(lang) ? _reSugDics[_langDics.indexOf(lang)] : null;
}

class ReSelData {
  late int _numFound, _start;
  late bool _numFoundExact;
  late List<SuggestionSolr> _docs;

  ReSelData(responseData) {
    if (responseData is Map) {
      _numFound = responseData.containsKey('numFound')
          ? responseData['numFound']
          : throw ReSelDataException('No numFound');
      _start = responseData.containsKey('start')
          ? responseData['start']
          : throw ReSelDataException('No start');
      _numFoundExact = responseData.containsKey('numFoundExact')
          ? responseData['numFoundExact']
          : throw ReSelDataException('No numFoundExact');
      _docs = responseData.containsKey('docs')
          ? []
          : throw ReSelDataException('No docs');
      for (var docServer in responseData['docs']) {
        if (docServer is Map) {
          SuggestionSolr suggestion = docServer.containsKey('id')
              ? SuggestionSolr(docServer['id'])
              : throw ReSelDataException('No id');
          if (docServer.containsKey('labelEn')) {
            suggestion.addLabel(PairLang('en', docServer['labelEn']));
          }
          if (docServer.containsKey('labelEs')) {
            suggestion.addLabel(PairLang('es', docServer['labelEs']));
          }
          if (docServer.containsKey('labelPt')) {
            suggestion.addLabel(PairLang('pt', docServer['labelPt']));
          }
          if (docServer.containsKey('score')) {
            suggestion.score = docServer['score'];
          } else {
            throw ReSelDataException('No score');
          }
          if (docServer.containsKey('lat')) {
            suggestion.lat = docServer['lat'];
          } else {
            throw ReSelDataException('No lat');
          }
          if (docServer.containsKey('long')) {
            suggestion.long = docServer['long'];
          } else {
            throw ReSelDataException('No long');
          }
          _docs.add(suggestion);
        } else {
          throw ReSelDataException('Doc is not a Map');
        }
      }
    } else {
      throw ReSelDataException('ResponseData is not a Map');
    }
  }

  int get numFound => _numFound;
  int get start => _start;
  bool get numFoundExact => _numFoundExact;
  List<SuggestionSolr> get docs => _docs;
}

class ReSugDic {
  late int _numFound;
  late List<SuggestionSolr> _suggestions;
  final String lang;

  ReSugDic(suggestDict, this.lang) {
    if (suggestDict is Map) {
      if (suggestDict.keys.length == 1) {
        suggestDict = suggestDict[suggestDict.keys.first];
        if (suggestDict is Map) {
          _numFound = suggestDict.containsKey('numFound')
              ? suggestDict['numFound']
              : throw ReSugDicException('No numFound');
          _suggestions = suggestDict.containsKey('suggestions')
              ? []
              : throw ReSugDicException('No suggestions');
          for (var suggestionServer in suggestDict['suggestions']) {
            if (suggestionServer is Map) {
              SuggestionSolr suggestion =
                  suggestionServer.containsKey('payload')
                      ? SuggestionSolr(suggestionServer['payload'])
                      : throw ReSugDicException('No payload');
              if (suggestionServer.containsKey('term')) {
                suggestion.addLabel(PairLang(lang, suggestionServer['term']));
              } else {
                throw ReSugDicException('No term');
              }
              if (suggestionServer.containsKey('weight')) {
                suggestion.score = suggestionServer['weight'];
              } else {
                throw ReSugDicException('No weight');
              }
              _suggestions.add(suggestion);
            } else {
              throw ReSugDicException('Suggestion is not a Map');
            }
          }
        } else {
          throw ReSugDicException('SuggestDictData is not a Map');
        }
      } else {
        throw ReSugDicException('More than one key');
      }
    } else {
      throw ReSugDicException('It is not a Map');
    }
  }

  int get numFound => _numFound;
  List<SuggestionSolr> get suggestions => _suggestions;
}
