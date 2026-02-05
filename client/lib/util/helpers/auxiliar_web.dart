import 'dart:html' as webFile;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:momoest/util/exceptions.dart';
import 'package:momoest/util/helpers/answers.dart';

class AuxiliarFunctions {
  // static const String _idUGuestUser = "";

  static void downloadAnswerWeb(Answer answer, {String titlePage = 'CHEST'}) {
    webFile.Blob contenido = webFile.Blob([
      '<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>{{{titlePage}}}</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet"integrity="sha384-GLhlTQ8iRABdZLl6O3oVMWSktQOp6b7In1Zl3/Jr59b6EGGoI1aFkw7cmDA6j6gD" crossorigin="anonymous"><link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link href="https://fonts.googleapis.com/css2?family=Open+Sans&display=swap" rel="stylesheet"><link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.3/dist/leaflet.css"integrity="sha256-kLaT2GOSpHechhsozzB+flnD+zUyjE2LlfWPgU04xyI=" crossorigin="" /><style>body {font-family: "Open Sans", sans-serif;font-display: swap;}nav {background-color: #673AB7;}#map {height: 180px;width: 100%;}</style></head><body><nav class="navbar sticky-top" data-bs-theme="dark"><div class="container-fluid"><span class="navbar-brand mb-0">$titlePage</span></div></nav><div class="container mt-4"><p class="display-6 text-center">${answer.hasLabelContainer ? answer.labelContainer : 'Feature'}</p><div class="card mt-3" id="map"></div><p class="mt-3 px-2">${answer.hasCommentTask ? answer.commentTask : 'Comment Task'}</p><hr class="mt-3 mx-5"></div><div class="container mt-4"><figure class="text-end"><blockquote class="blockquote"><p>${answer.answer['answer']}${answer.hasExtraText ? '. ${answer.answer["extraText"]}' : '.'}</p></blockquote><figcaption class="blockquote-footer">${DateFormat('H:mm d/M/y').format(DateTime.fromMillisecondsSinceEpoch(answer.answer['timestamp']))}</figcaption></figure></div><script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"integrity="sha384-w76AqPfDkMBDXo30jS1Sgez6pr3x5MlQ1ZAGC+nuZB+EYdgRZgiwxhTBTkF7CXvN"crossorigin="anonymous"></script><script src="https://unpkg.com/leaflet@1.9.3/dist/leaflet.js"integrity="sha256-WBkoXOwTeyKclOHuWtc+i2uENFpDZ9YPdf5Hf+D7ewM=" crossorigin=""></script><script>var map = L.map("map", {boxZoom: false,scrollWheelZoom: false,touchZoom: false,tapHold: false,dragging: false,zoomControl: false,}).setView([${answer.feature.lat}, ${answer.feature.long}], 17);L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {minZoom: 17,maxZoom: 17,attribution: "&copy; <a href=\\"https://www.openstreetmap.org/copyright\\">OpenStreetMap</a>s",}).addTo(map);L.circle([${answer.feature.lat}, ${answer.feature.long}], {color: "#673AB7",fillColor: "#673AB7",fillOpacity: 0.3,radius: 36}).addTo(map);</script></body></html>'
    ], 'text/html', 'native');
    // https://stackoverflow.com/a/63842948
    webFile.AnchorElement(href: webFile.Url.createObjectUrlFromBlob(contenido))
      ..setAttribute(
          'download', 'CHEST-${DateTime.now().millisecondsSinceEpoch}')
      ..click();
  }

  static String getIdUser() {
    String? cookies = webFile.document.cookie;
    if (cookies != null) {
      List<String> lstCookies = cookies.split(";");
      for (String cookie in lstCookies) {
        if (cookie.contains("idUserChest")) {
          return cookie.split("=")[1].trim();
        }
      }
    }
    String newId = const Uuid().v4();
    if (cookies == null) {
      webFile.document.cookie = "idUserChest=$newId";
    } else {
      webFile.document.cookie = webFile.document.cookie!.isEmpty
          ? "idUserChest=$newId"
          : "${webFile.document.cookie}; idUserChest=$newId";
    }
    return newId;
  }

  static Future<bool> writeFile(
          {required String fileName,
          required String toFile,
          FileMode mode = FileMode.write}) async =>
      false;
  static Future<String?> readFile({required String fileName}) async => null;

  /// Lectura de ficheros.
  /// Se puede indicar las extensiones válidas [validExtensions] para el filtrado.
  static Future<Object?> readExternalFile(
      {List<String>? validExtensions, bool uint8List = false}) async {
    FilePickerResult? result = validExtensions != null
        ? await FilePicker.platform.pickFiles(
            type: FileType.custom, allowedExtensions: validExtensions)
        : await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      PlatformFile platformFile = result.files.single;
      if (validExtensions != null) {
        if (validExtensions.contains(platformFile.extension)) {
          return platformFile.bytes != null
              ? uint8List
                  ? platformFile.bytes
                  : String.fromCharCodes(platformFile.bytes!)
              : null;
        } else {
          throw FileExtensionException(
            validExtension: validExtensions.toString(),
          );
        }
      } else {
        return platformFile.bytes != null
            ? String.fromCharCodes(platformFile.bytes!)
            : null;
      }
    } else {
      return null;
    }
  }
}
