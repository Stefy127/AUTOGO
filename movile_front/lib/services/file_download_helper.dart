import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart'
    if (dart.library.io) 'file_download_helper_io.dart';

Future<String> saveReportFile(List<int> bytes, String fileName) {
  return saveReportFileImpl(bytes, fileName);
}
