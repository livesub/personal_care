import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart' as impl;

void downloadFile(List<int> bytes, String filename) {
  impl.downloadFile(bytes, filename);
}
