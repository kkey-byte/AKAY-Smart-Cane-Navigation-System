import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<List<String>> decodePairingImage(XFile image) async {
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    throw UnsupportedError(
      'Image QR reading is unavailable on this device. Enter the pairing code instead.',
    );
  }
  final controller = MobileScannerController(
    autoStart: false,
    formats: [BarcodeFormat.qrCode],
  );
  try {
    final result = await controller.analyzeImage(
      image.path,
      formats: [BarcodeFormat.qrCode],
    );
    return result?.barcodes.map((code) => code.rawValue ?? '').toList() ?? [];
  } finally {
    await controller.dispose();
  }
}
