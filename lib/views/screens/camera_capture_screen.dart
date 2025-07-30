import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  late CameraController _cameraController;
  final _textRecognizer = TextRecognizer();
  bool _isInitialized = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _cameraController.dispose();
    }
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) return;
    }

    final cameras = await availableCameras();
    final rear = cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.back);
    _cameraController = CameraController(
      rear,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController.initialize();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _captureAndProcess() async {
    try {
      setState(() => _isProcessing = true);

      await _cameraController.setFlashMode(FlashMode.off);
      await _cameraController.setFocusMode(FocusMode.auto);
      final file = await _cameraController.takePicture();
      final croppedFile = await _cropImageCenter(File(file.path));

      String fullText = '';
      List<String> lines = [];

      final isOnline = await _hasInternet();
      if (isOnline) {
        final geminiResult = await _analyzeWithGemini(croppedFile);
        if (geminiResult != null && geminiResult.contains('{')) {
          fullText = geminiResult;
          lines = [geminiResult];
        }
      }

      if (lines.isEmpty) {
        final inputImage = InputImage.fromFile(croppedFile);
        final result = await _textRecognizer.processImage(inputImage);
        fullText = result.text;
        lines = _extractLines(result);
      }

      if (!mounted) return;

      Navigator.pop(context, {
        'fullText': fullText,
        'labeledValues': lines,
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        _cameraController.dispose();
      });
    } catch (e) {
      debugPrint('❌ Error in capture & process: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture and process image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<File> _cropImageCenter(File file) async {
    final bytes = await file.readAsBytes();
    final img.Image? raw = img.decodeImage(bytes);
    if (raw == null) throw Exception('Invalid image');

    final img.Image fixed = img.bakeOrientation(raw);
    final int cropWidth = (fixed.width * 0.8).toInt();
    final int cropHeight = (fixed.height * 0.4).toInt();
    final int cropX = ((fixed.width - cropWidth) / 2).toInt();
    final int cropY = ((fixed.height - cropHeight) / 2).toInt();

    final img.Image cropped = img.copyCrop(
      fixed,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    final dir = await getTemporaryDirectory();
    final croppedFile = File('${dir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await croppedFile.writeAsBytes(img.encodeJpg(cropped));
    return croppedFile;
  }

  Future<String?> _analyzeWithGemini(File imageFile) async {
    try {
      const apiKey = 'AIzaSyCpeM-TKkt8AEUkedaJLxAvjn0MKJwHLr4';
      final model = GenerativeModel(
        model: 'gemini-1.5-pro',
        apiKey: apiKey,
      );
      final bytes = await imageFile.readAsBytes();
      final prompt = Content.multi([
        TextPart('''
You are looking at a CNG dispenser image. Extract these values:

{
  "total_price_rupees": "<value or empty string if not found>",
  "volume_litres": "<value or empty string if not found>",
  "price_per_litre": "<value or empty string if not found>"
}
Only return valid JSON. No text before or after it.
'''),
        DataPart('image/jpeg', bytes),
      ]);

      final response = await model.generateContent([prompt]);
      final raw = response.text?.trim();

      if (raw == null || !raw.contains('{')) return null;

      // Extract only the JSON portion
      final match = RegExp(r'{.*}', dotAll: true).firstMatch(raw);
      return match?.group(0);
    } catch (e) {
      debugPrint('Gemini error: $e');
      return null;
    }
  }

  List<String> _extractLines(RecognizedText recognizedText) {
    return recognizedText.blocks.expand((b) => b.lines.map((l) => l.text)).toList();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan CNG Meter'),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          if (!_isProcessing) CameraPreview(_cameraController),
          if (_isProcessing)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text(
                    "Processing...",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          if (!_isProcessing) Container(color: Colors.black.withOpacity(0.3)),
          if (!_isProcessing)
            Center(child: CustomPaint(size: Size.infinite, painter: RoundedCropBoxPainter())),
          if (!_isProcessing)
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Text(
                    "Align the CNG meter reading inside the box",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Make sure the values are clearly visible",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          if (!_isProcessing)
            Positioned(
              bottom: 40,
              left: 50,
              right: 50,
              child: ElevatedButton.icon(
                onPressed: _captureAndProcess,
                icon: const Icon(Icons.camera_alt_rounded, size: 24),
                label: const Text('Capture', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RoundedCropBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width * 0.8;
    final double height = size.height * 0.4;
    final Offset topLeft = Offset(
      (size.width - width) / 2,
      (size.height - height) / 2,
    );

    final Rect rect = topLeft & Size(width, height);
    final RRect roundedRect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    final Paint overlayPaint = Paint()..color = Colors.black.withOpacity(0.6);
    final Path fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path holePath = Path()..addRRect(roundedRect);
    final Path finalPath = Path.combine(PathOperation.difference, fullPath, holePath);

    canvas.drawPath(finalPath, overlayPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(roundedRect, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
