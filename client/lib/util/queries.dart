import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:momoest/util/config_xest.dart';
import 'package:momoest/util/auxiliar.dart';
import 'package:momoest/util/map_layer.dart';

class Queries {
  /*+++++++++++++++++++++++++++++++++++
  + USERS                             +
  +++++++++++++++++++++++++++++++++++*/
  // GET info user
  static Uri signIn() => Uri.parse('${ConfigXest.addServer}/users/user');
  static Uri getUser() => signIn();
  // PUT user: new user or edit user.
  static Uri putUser() => signIn();
  // DELETE user
  static Uri deleteUser() => signIn();
  // POST answer: new answer
  static Uri newAnswer() =>
      Uri.parse('${ConfigXest.addServer}/users/user/answers');
  static Uri getAnswers() => newAnswer();
  // POST uploadFile answer / GET download PDF
  static Uri uploadAnswerFile() =>
      Uri.parse('${ConfigXest.addServer}/users/user/answers/files');
  static Uri downloadAnswerFile(String fileId) =>
      Uri.parse('${ConfigXest.addServer}/users/user/answers/files/$fileId');
  // GET/PUT PREFERENCES
  static Uri preferences() =>
      Uri.parse('${ConfigXest.addServer}/users/user/preferences');

  /*+++++++++++++++++++++++++++++++++++
  + Features                          +
  +++++++++++++++++++++++++++++++++++*/

  static LayerType get layerType => LayerType.ch;

  //GET info features bounds
  static Uri getFeatures(Map<String, dynamic> parameters) {
    // String lType;
    // switch (layerType) {
    //   case LayerType.forest:
    //   case LayerType.schools:
    //     lType = '&type=${layerType.name}';
    //     break;
    //   default:
    //     lType = '';
    // }
    String bounds =
        'north=${parameters['north']}&west=${parameters['west']}&south=${parameters['south']}&east=${parameters['east']}';
    return Uri.parse(MapLayer.onlyMoMo
        ? '${ConfigXest.addServer}/features?$bounds&interval=${MapLayer.startYear}-${MapLayer.endYear}'
        : '${ConfigXest.addServer}/features?$bounds');
  }

  //POST
  static Uri newFeature() => Uri.parse('${ConfigXest.addServer}/features');

  /*+++++++++++++++++++++++++++++++++++
  + Features                          +
  +++++++++++++++++++++++++++++++++++*/
  //DELETE
  static Uri deleteFeature(idFeature) => Uri.parse(
      '${ConfigXest.addServer}/features/${Auxiliar.getIdFromIri(idFeature)}');

  static Uri getFeatureInfo(idFeature) => Uri.parse(
      '${ConfigXest.addServer}/features/${Auxiliar.getIdFromIri(idFeature)}');

  /*+++++++++++++++++++++++++++++++++++
  + Learning tasks
  +++++++++++++++++++++++++++++++++++*/
  //GET
  static Uri getTasks(String shortIdFeature) => Uri.parse(
      '${ConfigXest.addServer}/features/$shortIdFeature/learningTasks');

  /*+++++++++++++++++++++++++++++++++++
  + Learning task
  +++++++++++++++++++++++++++++++++++*/
  static Uri deleteTask(String shortIdFeature, String shortIdTask) => Uri.parse(
      '${ConfigXest.addServer}/features/$shortIdFeature/learningTasks/$shortIdTask');

  static Uri newTask(String shortIdFeature) => Uri.parse(
      '${ConfigXest.addServer}/features/$shortIdFeature/learningTasks');

  static Uri getTask(String shortIdFeature, String shortIdTask) => Uri.parse(
      '${ConfigXest.addServer}/features/$shortIdFeature/learningTasks/$shortIdTask');

  /*+++++++++++++++++++++++++++++++++++
  + Info POI LOD
  +++++++++++++++++++++++++++++++++++*/
  //GET
  static Uri getFeaturesLod(LatLng point, LatLngBounds bounds) => Uri.parse(
      '${ConfigXest.addServer}/features/lod?lat=${point.latitude}&long=${point.longitude}&incr=${max(0.2, min(1, max(bounds.north - bounds.south, (bounds.east - bounds.west).abs())))}');

  /*+++++++++++++++++++++++++++++++++++
  + Itineraries                       +
  +++++++++++++++++++++++++++++++++++*/
  //GET
  static Uri getItineraries() =>
      Uri.parse('${ConfigXest.addServer}/itineraries');

  //POST
  static Uri newItinerary() => Uri.parse('${ConfigXest.addServer}/itineraries');

  /*+++++++++++++++++++++++++++++++++++
  + Itinerary                         +
  +++++++++++++++++++++++++++++++++++*/
  //GET
  static Uri getItinerary(String idIt) => Uri.parse(
      '${ConfigXest.addServer}/itineraries/${Auxiliar.getIdFromIri(idIt)}');

  static Uri getItineraryFeatures(String idIt) => Uri.parse(
      '${ConfigXest.addServer}/itineraries/${Auxiliar.getIdFromIri(idIt)}/features');

  static Uri getItineraryTask(String idIt) => Uri.parse(
      '${ConfigXest.addServer}/itineraries/${Auxiliar.getIdFromIri(idIt)}/learningTasks');

  static Uri getItineraryTrack(String idIt) => Uri.parse(
      '${ConfigXest.addServer}/itineraries/${Auxiliar.getIdFromIri(idIt)}/track');

  //DELETE
  static Uri deleteIt(String idIt) => getItinerary(idIt);

  //Tasks Feature It
  static Uri getTasksFeatureIt(String idIt, String idFeature) => Uri.parse(
      '${ConfigXest.addServer}/itineraries/${Auxiliar.getIdFromIri(idIt)}/features/$idFeature/learningTasks');

  static Uri getSuggestions(String q, {Object? dict}) {
    if (dict == null) {
      return Uri.parse('${ConfigXest.addSolr}/suggest?q=$q');
    } else {
      if (dict is String) {
        dict = [dict];
      }
      if (dict is List) {
        String suggestDict = '';
        for (String d in dict) {
          String lbl;
          switch (d.toLowerCase()) {
            case 'es':
              lbl = 'chestEs';
              break;
            case 'pt':
              lbl = 'chestPt';
              break;
            default:
              lbl = 'chestEn';
          }
          if (suggestDict.isEmpty) {
            suggestDict = 'suggest.dictionary=$lbl';
          } else {
            suggestDict = '$suggestDict&suggest.dictionary=$lbl';
          }
        }
        return Uri.parse('${ConfigXest.addSolr}/suggest?$suggestDict&q=$q');
      }
      return Uri.parse('${ConfigXest.addSolr}/suggest?q=$q');
    }
  }

  static Uri getSuggestion(String id) =>
      Uri.parse('${ConfigXest.addSolr}/select?q=id:"$id"');

  /*+++++++++++++++++++++++++++++++++++
  + Feeds                             +
  +++++++++++++++++++++++++++++++++++*/
  // GET, POST
  static Uri feeds() => Uri.parse('${ConfigXest.addServer}/feeds/');
  // GET, PUT, DELETE
  static Uri feed(String idFeed) =>
      Uri.parse('${ConfigXest.addServer}/feeds/$idFeed/');
  // GET
  static Uri feedSubscribers(String idFeed) =>
      Uri.parse('${ConfigXest.addServer}/feeds/$idFeed/subscribers/');
  // GET, PUT, DELETE
  static Uri feedSubscriber(String idFeed, String idSubscriber) => Uri.parse(
      '${ConfigXest.addServer}/feeds/$idFeed/subscribers/$idSubscriber');
  // GET
  static Uri feedAnswers(String idFeed, String idSubscriber) => Uri.parse(
      '${ConfigXest.addServer}/feeds/$idFeed/subscribers/$idSubscriber/answers/');
  // GET, PUT, DELETE
  static Uri feedAnswer(String idFeed, String idSubscriber, String idAnswer) =>
      Uri.parse(
          '${ConfigXest.addServer}/feeds/$idFeed/subscribers/$idSubscriber/answers/$idAnswer/');
  // GET download PDF (teacher or student via feed context)
  static Uri feedAnswerFile(String idFeed, String idSubscriber, String fileId) =>
      Uri.parse(
          '${ConfigXest.addServer}/feeds/$idFeed/subscribers/$idSubscriber/answers/files/$fileId');
  // PUT, DELETE
  static Uri feedTeacher(String idFeed, String idTeacher) =>
      Uri.parse('${ConfigXest.addServer}/feeds/$idFeed/teachers/$idTeacher');
}

enum ActionSubcription { unsubscribe }

enum LayerType { ch, schools, forest }
