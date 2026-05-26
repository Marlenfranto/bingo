import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation — synthesises a hidden <a download> link and clicks it.
/// This is the same trick the old QrGeneratorScreen used inline; here it's
/// isolated behind the conditional import so non-web targets compile.
Future<void> saveQrPng(Uint8List bytes, {required String filename}) async {
  final dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';
  final anchor = html.AnchorElement(href: dataUrl)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}
