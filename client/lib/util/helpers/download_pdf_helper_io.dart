import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadPdf(List<int> bytes, String fileName) async {
  final safeName = fileName
      .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${safeName.isNotEmpty ? safeName : 'document.pdf'}');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: fileName),
  );
}
