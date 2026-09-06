import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

import 'package:momoest/util/config_xest.dart';

/// Dónde ha acabado el fichero que pidió guardar el usuario.
enum SaveResult {
  /// Carpeta de Descargas del dispositivo (Android 10 o superior).
  downloads,

  /// Carpeta de la aplicación, visible en Archivos (iOS).
  appFiles,

  /// El usuario eligió destino en la hoja de compartir.
  shared,

  /// No se ha podido guardar por ninguna vía.
  error,
}

/// Guardado de ficheros que el usuario pide descargar.
///
/// La aplicación no escribe en la galería del dispositivo a propósito: hacerlo
/// obliga a pedir un permiso de fotografías que el alumnado percibe como
/// invasivo y que no se necesita para nada más. En su lugar el fichero va a la
/// carpeta de Descargas en Android y a la carpeta de la aplicación (visible en
/// Archivos) en iOS, ninguna de las dos sujeta a permisos. Si ninguna vía está
/// disponible se ofrece la hoja de compartir, donde el usuario elige destino.
class SaveFile {
  static const MethodChannel _channel =
      MethodChannel('es.uva.gsic.momoest/descargas');

  /// Guarda [bytes] con el nombre [fileName].
  ///
  /// [sharePositionOrigin] es necesario para que la hoja de compartir se ancle
  /// correctamente en iPad; [subject] es el asunto que se propone al compartir.
  static Future<SaveResult> save({
    required Uint8List bytes,
    required String fileName,
    String mime = 'image/jpeg',
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          final String? uri = await _channel.invokeMethod<String>(
            'guardarEnDescargas',
            {'bytes': bytes, 'nombre': fileName, 'mime': mime},
          );
          // Por debajo de Android 10 el canal devuelve null: allí no hay
          // Descargas sin permiso de almacenamiento, así que se comparte.
          if (uri != null) return SaveResult.downloads;
        } else if (Platform.isIOS) {
          final Directory dir = await getApplicationDocumentsDirectory();
          final File file = await _freeName(dir, fileName);
          await file.writeAsBytes(bytes);
          return SaveResult.appFiles;
        }
      } catch (error, stackTrace) {
        _report(error, stackTrace);
      }
    }
    return _share(
      bytes: bytes,
      fileName: fileName,
      mime: mime,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Descarga la misma imagen dos veces no debe pisar la primera. Android ya
  /// resuelve las colisiones dentro de MediaStore; aquí se cubre iOS.
  static Future<File> _freeName(Directory dir, String fileName) async {
    final int dot = fileName.lastIndexOf('.');
    final String base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final String ext = dot > 0 ? fileName.substring(dot) : '';
    File file = File('${dir.path}/$fileName');
    int n = 1;
    while (await file.exists()) {
      file = File('${dir.path}/$base ($n)$ext');
      n++;
    }
    return file;
  }

  static Future<SaveResult> _share({
    required Uint8List bytes,
    required String fileName,
    required String mime,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mime)],
          subject: subject ?? '',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return SaveResult.shared;
    } catch (error, stackTrace) {
      _report(error, stackTrace);
      return SaveResult.error;
    }
  }

  static void _report(Object error, StackTrace stackTrace) {
    if (ConfigXest.development) {
      debugPrint(error.toString());
    } else {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }
}
