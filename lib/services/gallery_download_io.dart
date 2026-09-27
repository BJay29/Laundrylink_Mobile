import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Mobile implementation — nagsusulat muna sa temp file, tapos
/// ginagamit ang `gal` para i-save sa aktwal na photo gallery ng device.
Future<void> saveBytesToGallery(List<int> bytes, String fileName) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/$fileName');
  await tempFile.writeAsBytes(bytes);

  final hasAccess = await Gal.hasAccess();
  if (!hasAccess) {
    final granted = await Gal.requestAccess();
    if (!granted) {
      throw Exception('Gallery access was denied. Please enable photo permissions in Settings.');
    }
  }

  await Gal.putImage(tempFile.path, album: 'Laundry App');
}