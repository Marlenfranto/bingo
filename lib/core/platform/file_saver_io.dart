import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Mobile/desktop implementation — defers to the platform share sheet
/// (Save to Files on iOS, Save / Share on Android).
Future<void> saveQrPng(Uint8List bytes, {required String filename}) async {
  await Share.shareXFiles(
    [XFile.fromData(bytes, name: filename, mimeType: 'image/png')],
    fileNameOverrides: [filename],
    subject: 'My Namma Bingo QR',
  );
}
