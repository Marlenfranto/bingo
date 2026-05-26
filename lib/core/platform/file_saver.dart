import 'dart:typed_data';

import 'file_saver_io.dart' if (dart.library.html) 'file_saver_web.dart'
    as impl;

/// Save (download on web, share-sheet on mobile/desktop) a PNG byte buffer.
/// One entry point so callers never touch `dart:html` or `dart:io`.
Future<void> saveQrPng(Uint8List bytes, {required String filename}) =>
    impl.saveQrPng(bytes, filename: filename);
