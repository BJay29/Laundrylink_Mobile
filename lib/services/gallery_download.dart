/// Pinipili ng Dart compiler mismo kung aling implementation ang
/// gagamitin base sa target platform — `dart:io` available (mobile) →
/// gallery_download_io.dart; `dart:html` available (web) →
/// gallery_download_web.dart. Isang function lang (`saveBytesToGallery`)
/// ang exposed papunta sa ibang files, kaya walang platform-check na
/// kailangan sa caller side.
export 'gallery_download_stub.dart'
    if (dart.library.io) 'gallery_download_io.dart'
    if (dart.library.html) 'gallery_download_web.dart';