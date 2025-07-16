import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  late CameraController _cameraController;
  bool _isInitialized = false;
  late TextRecognizer _textRecognizer;

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameraPermission = await Permission.camera.request();
    if (!cameraPermission.isGranted) return;

    final cameras = await availableCameras();
    final rearCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
    );

    _cameraController = CameraController(
      rearCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController.initialize();
    setState(() => _isInitialized = true);
  }

  Future<void> _captureAndProcess() async {
    if (!_cameraController.value.isInitialized) return;

    final file = await _cameraController.takePicture();
    final bytes = await File(file.path).readAsBytes();
    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) return;

    // Crop to center rectangle
    final double cropWidth = decodedImage.width * 0.8;
    final double cropHeight = decodedImage.height * 0.3;
    final int cropX = ((decodedImage.width - cropWidth) / 2).round();
    final int cropY = ((decodedImage.height - cropHeight) / 2).round();

    final img.Image cropped = img.copyCrop(
      decodedImage,
      x: cropX,
      y: cropY,
      width: cropWidth.round(),
      height: cropHeight.round(),
    );


    final Directory tempDir = await getTemporaryDirectory();
    final File croppedFile = File('${tempDir.path}/cropped_image.jpg');
    await croppedFile.writeAsBytes(img.encodeJpg(cropped));

    final inputImage = InputImage.fromFile(croppedFile);
    final result = await _textRecognizer.processImage(inputImage);
    final fullText = result.text;

    final values = _extractNumericValues(result);

    await _textRecognizer.close();
    Navigator.pop(context, {
      'fullText': fullText,
      'labeledValues': values,
    });
  }

  List<MapEntry<String, String>> _extractNumericValues(RecognizedText recognizedText) {
    final List<MapEntry<String, String>> results = [];
    final RegExp numberRegex = RegExp(r'\b\d{1,7}(\.\d{1,2})?\b', caseSensitive: false);

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.toLowerCase().trim();
        final match = numberRegex.firstMatch(text);
        if (match != null) {
          final number = match.group(0)!;
          if (text.contains('rupees') || text.contains('litres') || text.contains('rs/litre')) {
            results.add(MapEntry('', number)); // only number, no label
          }
        }
      }
    }

    return results;
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Capture Image')),
      body: Stack(
        children: [
          CameraPreview(_cameraController),
          Center(
            child: CustomPaint(
              size: Size.infinite,
              painter: CropBoxPainter(),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 50,
            right: 50,
            child: ElevatedButton.icon(
              onPressed: _captureAndProcess,
              icon: const Icon(Icons.camera),
              label: const Text('Capture & Scan'),
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

class CropBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final double width = size.width * 0.8;
    final double height = size.height * 0.3;
    final Offset offset = Offset((size.width - width) / 2, (size.height - height) / 2);

    final rect = offset & Size(width, height);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
