import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> saveReportFileImpl(List<int> bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return 'Archivo guardado en: ${file.path}';
}
