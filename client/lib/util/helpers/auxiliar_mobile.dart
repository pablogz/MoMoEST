import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:momoest/util/exceptions.dart';
import 'package:momoest/util/helpers/answers.dart';

class AuxiliarFunctions {
  static void downloadAnswerWeb(Answer answer, {String titlePage = 'CHEST'}) {}
  // TODO
  static String getIdUser() => "";

  static Future<String> get _localPath async {
    final directory = await getApplicationCacheDirectory();
    return directory.path;
  }

  static Future<File> _localFile(localFileName) async {
    final path = await _localPath;
    return File('$path/$localFileName');
  }

  static Future<bool> writeFile(
      {required String fileName,
      required String toFile,
      FileMode mode = FileMode.write}) async {
    final file = await _localFile(fileName);
    final File f = await file.writeAsString(toFile, mode: mode);
    return await f.exists();
  }

  static Future<String?> readFile({required String fileName}) async {
    try {
      final file = await _localFile(fileName);
      final data = await file.readAsString();
      return data;
    } catch (error) {
      return null;
    }
  }

  /// Lectura de ficheros.
  /// Se puede indicar las extensiones válidas [validExtensions] para el filtrado.
  static Future<Object?> readExternalFile(
      {List<String>? validExtensions, bool uint8List = false}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      PlatformFile platformFile = result.files.single;
      if (validExtensions != null) {
        if (validExtensions.contains(platformFile.extension)) {
          File file = File(platformFile.path!);
          return uint8List
              ? await file.readAsBytes()
              : await file.readAsString();
        } else {
          throw FileExtensionException(
            validExtension: validExtensions.toString(),
          );
        }
      } else {
        File file = File(platformFile.path!);
        return await file.readAsString();
      }
    } else {
      return null;
    }
  }
}
