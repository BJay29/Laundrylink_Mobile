import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation — walang "gallery" sa browser, kaya ang
/// katumbas na aksyon ay i-trigger ang normal na browser file download
/// (lalabas sa Downloads folder ng user, o ipapakita ang save dialog
/// depende sa browser settings).
Future<void> saveBytesToGallery(List<int> bytes, String fileName) async {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}