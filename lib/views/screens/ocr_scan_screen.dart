import 'package:flutter/material.dart';
import 'package:flutter_scalable_ocr/flutter_scalable_ocr.dart';
import 'package:permission_handler/permission_handler.dart';

class OcrScanScreen extends StatefulWidget {
  const OcrScanScreen({super.key, required this.getScannedText});

  @override
  State<OcrScanScreen> createState() => _OcrScanScreenState();
  final Function(String) getScannedText;
}

class _OcrScanScreenState extends State<OcrScanScreen> {
  final ValueNotifier<String> scannedText = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
  }

  void _onCapture() {
    final result = scannedText.value.trim();
    if (result.isNotEmpty) {
      Navigator.pop(context, {
        'fullText': result,
        'labeledValues':
            result.split('\n').where((line) => line.trim().isNotEmpty).toList(),
      });
    }
  }

  @override
  void dispose() {
    scannedText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan OCR')),
      body: Stack(
        children: [
          ScalableOCR(
            paintboxCustom: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white,
            boxLeftOff: 0.1,
            boxRightOff: 0.1,
            boxTopOff: 0.3,
            boxBottomOff: 0.3,
            getScannedText: widget.getScannedText,
          ),
          Positioned(
            bottom: 40,
            left: 50,
            right: 50,
            child: ElevatedButton.icon(
              onPressed: _onCapture,
              icon: const Icon(Icons.check),
              label: const Text('Use This Text'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
