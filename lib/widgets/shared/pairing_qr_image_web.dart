import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:image_picker/image_picker.dart';

@JS('document')
external _Document get _document;
@JS('ZXingWASM')
external _Decoder? get _decoder;
extension type _Document(JSObject _) implements JSObject {
  external JSObject createElement(String tag);
  external _Element get head;
}
extension type _Element(JSObject _) implements JSObject {
  external void appendChild(JSObject child);
}
extension type _Script(JSObject _) implements JSObject {
  external set src(String value);
  external set onload(JSFunction value);
  external set onerror(JSFunction value);
  external void remove();
}
@JS('Image')
extension type _Image._(JSObject _) implements JSObject {
  external factory _Image();
  external set src(String value);
  external JSPromise<JSAny?> decode();
  external int get naturalWidth;
  external int get naturalHeight;
}
extension type _Canvas(JSObject _) implements JSObject {
  external set width(int value);
  external set height(int value);
  external _Context getContext(String kind);
}
extension type _Context(JSObject _) implements JSObject {
  external void drawImage(_Image image, int x, int y, int width, int height);
  external JSObject getImageData(int x, int y, int width, int height);
}
extension type _Decoder(JSObject _) implements JSObject {
  external JSPromise<JSArray<_Result>> readBarcodes(
    JSObject imageData,
    _Options options,
  );
}
extension type _Result(JSObject _) implements JSObject {
  external String? get text;
  external bool get isValid;
}
@JS()
extension type _Options._(JSObject _) implements JSObject {
  external factory _Options({
    JSArray<JSString> formats,
    bool tryHarder,
    bool tryRotate,
    bool tryInvert,
  });
}

Future<void>? _loading;
Future<void> _loadDecoder() async {
  if (_decoder != null) return;
  if (_loading != null) return _loading;
  final completer = Completer<void>();
  final script = _Script(_document.createElement('script'));
  // Same pinned reader/version as the installed mobile_scanner web decoder.
  script.src =
      'https://cdn.jsdelivr.net/npm/zxing-wasm@3.1.3/dist/iife/reader/index.js';
  script.onload = ((JSAny? _) {
    if (!completer.isCompleted) completer.complete();
  }).toJS;
  script.onerror = ((JSAny? _) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('QR decoder unavailable'));
    }
  }).toJS;
  _document.head.appendChild(script);
  _loading = completer.future.timeout(const Duration(seconds: 20));
  try {
    await _loading;
  } catch (_) {
    script.remove();
    rethrow;
  } finally {
    _loading = null;
  }
}

Future<List<String>> decodePairingImage(XFile file) async {
  await _loadDecoder();
  final image = _Image()
    ..src =
        'data:application/octet-stream;base64,${base64Encode(await file.readAsBytes())}';
  await image.decode().toDart.timeout(const Duration(seconds: 15));
  if (image.naturalWidth <= 0 ||
      image.naturalHeight <= 0 ||
      image.naturalWidth * image.naturalHeight > 40000000) {
    throw const FormatException('Choose a smaller, valid QR image.');
  }
  final canvas = _Canvas(_document.createElement('canvas'))
    ..width = image.naturalWidth
    ..height = image.naturalHeight;
  final context = canvas.getContext('2d');
  context.drawImage(image, 0, 0, image.naturalWidth, image.naturalHeight);
  final results = await _decoder!
      .readBarcodes(
        context.getImageData(0, 0, image.naturalWidth, image.naturalHeight),
        _Options(
          formats: ['QRCode'.toJS].toJS,
          tryHarder: true,
          tryRotate: true,
          tryInvert: true,
        ),
      )
      .toDart
      .timeout(const Duration(seconds: 20));
  return [
    for (final result in results.toDart)
      if (result.isValid && result.text != null) result.text!,
  ];
}
