import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/pairing_code.dart';

class PairingScannerPage extends StatefulWidget {
  const PairingScannerPage({super.key});
  @override
  State<PairingScannerPage> createState() => _PairingScannerPageState();
}

class _PairingScannerPageState extends State<PairingScannerPage> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _finished = false;
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan Navigator QR')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Point your camera at the QR code on the Navigator’s dashboard. You can also go back and enter the code.',
          ),
        ),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        Expanded(
          child: MobileScanner(
            controller: _controller,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Camera unavailable. Allow camera access in device settings, or enter the pairing code instead.',
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Enter code instead'),
                    ),
                  ],
                ),
              ),
            ),
            onDetect: (capture) {
              if (_finished) return;
              for (final barcode in capture.barcodes) {
                final code = parsePairingCode(barcode.rawValue ?? '');
                if (code != null) {
                  _finished = true;
                  Navigator.pop(context, code);
                  return;
                }
              }
              if (mounted) {
                setState(
                  () => _error =
                      'This is not an AKAY pairing QR. Scan the Navigator’s code.',
                );
              }
            },
          ),
        ),
      ],
    ),
  );
}
