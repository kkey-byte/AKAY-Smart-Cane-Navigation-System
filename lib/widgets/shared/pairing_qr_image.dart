import 'package:image_picker/image_picker.dart';
import '../../models/pairing_code.dart';
import 'pairing_qr_image_native.dart'
    if (dart.library.js_interop) 'pairing_qr_image_web.dart'
    as decoder;

/// Reads locally; only the validated invitation reaches the pairing API.
Future<String?> pickPairingQrImage() async {
  final image = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (image == null) return null;
  if (await image.length() > 20 * 1024 * 1024) {
    throw const FormatException('Choose an image smaller than 20 MB.');
  }
  final values = await decoder.decodePairingImage(image);
  final codes = values.map(parsePairingCode).whereType<String>().toSet();
  if (codes.length > 1) {
    throw const FormatException(
      'This image contains multiple pairing codes. Choose an image with just one Navigator QR.',
    );
  }
  if (codes.isEmpty) {
    throw const FormatException(
      'No valid AKAY pairing QR found. Choose a clear image of the Navigator’s QR code.',
    );
  }
  return codes.single;
}
