/// Stub fallback — hindi dapat ma-reach ito sa totoong build (Flutter
/// web o mobile lang ang suportado ng conditional imports sa
/// gallery_download.dart).
Future<void> saveBytesToGallery(List<int> bytes, String fileName) async {
  throw UnsupportedError('Saving to gallery is not supported on this platform.');
}