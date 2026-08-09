import 'dart:convert';
import 'dart:typed_data';

import 'package:momoest/util/exceptions.dart';

/// Nota privada del estudiante. Puede tener título, texto y/o un dibujo, y
/// opcionalmente estar vinculada a un lugar.
///
/// El dibujo se guarda como fichero en el servidor: la nota solo conserva su
/// nombre ([drawingFile]) y su tamaño ([drawingSize]). [drawingLegacy] es el
/// PNG en base64 de las notas creadas antes de ese cambio, que se siguen
/// mostrando; [pendingDrawing] es un dibujo recién hecho todavía sin subir.
class Note {
  late String _id;
  String? title, text, idPlace, labelPlace;
  String? drawingFile, drawingLegacy;
  int? drawingSize;
  Uint8List? pendingDrawing;
  bool removeDrawing = false;
  late int creation, lastUpdate;
  Uint8List? _legacyBytes;

  Note.empty() {
    _id = '';
    creation = DateTime.now().millisecondsSinceEpoch;
    lastUpdate = creation;
  }

  Note(dynamic data) {
    if (data is Map) {
      if (data.containsKey('id') &&
          data['id'] is String &&
          data['id'].toString().trim().isNotEmpty) {
        _id = data['id'].toString().trim();
      } else {
        throw NoteException('id');
      }
      title = data['title'] is String && data['title'].trim().isNotEmpty
          ? data['title'].trim()
          : null;
      text = data['text'] is String && data['text'].trim().isNotEmpty
          ? data['text'].trim()
          : null;
      drawingFile =
          data['drawingFile'] is String && data['drawingFile'].trim().isNotEmpty
              ? data['drawingFile'].trim()
              : null;
      drawingSize = data['drawingSize'] is int ? data['drawingSize'] : null;
      drawingLegacy = data['drawing'] is String && data['drawing'].isNotEmpty
          ? data['drawing']
          : null;
      idPlace = data['idPlace'] is String && data['idPlace'].trim().isNotEmpty
          ? data['idPlace'].trim()
          : null;
      labelPlace =
          data['labelPlace'] is String && data['labelPlace'].trim().isNotEmpty
              ? data['labelPlace'].trim()
              : null;
      creation = data['creation'] is int
          ? data['creation']
          : DateTime.now().millisecondsSinceEpoch;
      lastUpdate = data['lastUpdate'] is int ? data['lastUpdate'] : creation;
      if (title == null && text == null && !hasDrawing) {
        throw NoteException('empty note');
      }
    } else {
      throw NoteException('Data is not a Map');
    }
  }

  String get id => _id;
  bool get hasId => _id.isNotEmpty;
  bool get hasPlace => idPlace != null;

  /// True si la nota tiene dibujo: uno nuevo sin subir, uno guardado como
  /// fichero o uno heredado en base64.
  bool get hasDrawing =>
      pendingDrawing != null ||
      (!removeDrawing && (drawingFile != null || drawingLegacy != null));

  /// True si el dibujo está guardado en el servidor y hay que descargarlo.
  bool get hasDrawingFile =>
      pendingDrawing == null && !removeDrawing && drawingFile != null;

  /// True si el dibujo es uno heredado, incrustado en el propio documento.
  bool get hasDrawingLegacy =>
      pendingDrawing == null && !removeDrawing && drawingLegacy != null;

  bool get isEmpty => title == null && text == null && !hasDrawing;

  /// Bytes del dibujo heredado, decodificados (con caché local)
  Uint8List? get legacyBytes {
    if (drawingLegacy == null) return null;
    _legacyBytes ??= base64Decode(drawingLegacy!);
    return _legacyBytes;
  }

  /// Registra un dibujo nuevo pendiente de subir; con null se quita el dibujo.
  void setDrawing(Uint8List? bytes) {
    pendingDrawing = bytes;
    removeDrawing = bytes == null;
  }

  /// Bytes que ocupa la nota, para poder mostrar el consumo antes de guardar.
  int get size {
    int size = pendingDrawing?.lengthInBytes ??
        (removeDrawing
            ? 0
            : drawingSize ?? (drawingLegacy != null ? drawingLegacy!.length : 0));
    if (title != null) size += utf8.encode(title!).length;
    if (text != null) size += utf8.encode(text!).length;
    return size;
  }

  /// Campos de la nota para el cuerpo de la petición. El campo `drawing` le
  /// dice al servidor si conserva o descarta el dibujo que ya tuviera guardado
  /// (se ignora cuando se envía un dibujo nuevo como fichero).
  Map<String, String> toFields() {
    return {
      if (title != null) 'title': title!,
      if (text != null) 'text': text!,
      if (idPlace != null) 'idPlace': idPlace!,
      if (labelPlace != null) 'labelPlace': labelPlace!,
      'drawing': removeDrawing ? 'remove' : 'keep',
    };
  }

  set id(String id) {
    if (id.trim().isNotEmpty) {
      _id = id.trim();
    }
  }
}
