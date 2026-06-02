import 'dart:convert';
import 'dart:html' as html;

Future<String> saveReportFileImpl(List<int> bytes, String fileName) async {
  final mime = fileName.endsWith('.pdf')
      ? 'application/pdf'
      : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  final base64Data = base64Encode(bytes);
  final dataUrl = 'data:$mime;base64,$base64Data';
  final anchor = html.AnchorElement(href: dataUrl)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return 'Archivo descargado: $fileName';
}
