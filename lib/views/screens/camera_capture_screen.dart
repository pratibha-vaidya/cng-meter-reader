import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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
  bool _isInitialized = false;
  late final TextRecognizer _textRecognizer;

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  Future<void> _initializeCamera() async {
    final cameraStatus = await Permission.camera.status;

    if (!cameraStatus.isGranted) {
      final result = await Permission.camera.request();

      if (!result.isGranted) {
        debugPrint('Camera permission denied');
        return;
      }
    }

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
    if (!mounted) return;
    setState(() => _isInitialized = true);
  }



  Future<void> _captureAndProcess() async {
    if (!_cameraController.value.isInitialized || _cameraController.value.isTakingPicture) return;

    try {
      await _cameraController.setFlashMode(FlashMode.off);
      await _cameraController.setFocusMode(FocusMode.auto);

      final file = await _cameraController.takePicture();
      final bytes = await File(file.path).readAsBytes();
      final img.Image? rawImage = img.decodeImage(bytes);

      if (rawImage == null) return;

      final img.Image originalImage = img.bakeOrientation(rawImage);

      // Center crop (80% width, 40% height)
      final int cropWidth = (originalImage.width * 0.8).toInt();
      final int cropHeight = (originalImage.height * 0.4).toInt();
      final int cropX = ((originalImage.width - cropWidth) / 2).toInt();
      final int cropY = ((originalImage.height - cropHeight) / 2).toInt();

      final img.Image cropped = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final File croppedFile = File('${tempDir.path}/cropped_$timestamp.jpg');
      await croppedFile.writeAsBytes(img.encodeJpg(cropped));

      // Optional preview
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cropped Preview'),
          content: Image.file(croppedFile),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            )
          ],
        ),
      );

      // OCR
      final inputImage = InputImage.fromFile(croppedFile);
      final result = await _textRecognizer.processImage(inputImage);
      final fullText = result.text;
      final lines = _extractLines(result);

      if (!mounted) return;
      Navigator.pop(context, {
        'fullText': fullText,
        'labeledValues': lines,
      });
    } catch (e) {
      debugPrint('Error during image capture & processing: $e');
    }
  }

  List<String> _extractLines(RecognizedText recognizedText) {
    final List<String> lines = [];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          lines.add(text);
        }
      }
    }

    return lines;
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
              icon: const Icon(Icons.camera_alt),
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
    final double height = size.height * 0.4;
    final Offset offset = Offset(
      (size.width - width) / 2,
      (size.height - height) / 2,
    );

    final rect = offset & Size(width, height);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
