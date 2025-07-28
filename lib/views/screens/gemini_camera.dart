import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
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
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController.dispose();
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
    final rear = cameras.firstWhere(
            (cam) => cam.lensDirection == CameraLensDirection.back);
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
    final engine = await _showOCRChoiceDialog();
    if (engine == null) return;

    try {
      await _cameraController.setFlashMode(FlashMode.off);
      await _cameraController.setFocusMode(FocusMode.auto);
      final file = await _cameraController.takePicture();
      final croppedFile = await _cropImageCenter(File(file.path));

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

      String fullText = '';
      List<String> lines = [];

      if (engine == 'google_ml') {
        final inputImage = InputImage.fromFile(croppedFile);
        final result = await _textRecognizer.processImage(inputImage);
        fullText = result.text;
        lines = _extractLines(result);
      } else {
        final geminiResult = await _analyzeWithGemini(croppedFile);
        fullText = geminiResult ?? '';
        lines = fullText.split('\n');
      }

      if (!mounted) return;
      Navigator.pop(context, {
        'fullText': fullText,
        'labeledValues': lines,
      });
    } catch (e) {
      debugPrint('❌ Error in capture & process: $e');
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

  List<String> _extractLines(RecognizedText result) {
    final lines = <String>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) lines.add(text);
      }
    }
    return lines;
  }

  Future<String?> _analyzeWithGemini(File imageFile) async {
    try {
      const apiKey = 'AIzaSyCpeM-TKkt8AEUkedaJLxAvjn0MKJwHLr4';
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      final bytes = await imageFile.readAsBytes();

      final prompt = Content.multi([
        TextPart('''
This image shows a fuel dispenser. Extract the values as JSON only:
{
  "total_price_rupees": "<value>",
  "volume_litres": "<value>",
  "price_per_litre": "<value>"
}
'''),
        DataPart('image/jpeg', bytes),
      ]);

      final response = await model.generateContent([prompt]);
      return response.text?.trim();
    } catch (e) {
      debugPrint('Gemini error: $e');
      return null;
    }
  }

  Future<String?> _showOCRChoiceDialog() {
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Choose OCR Engine"),
        content: const Text("Select how to scan the fuel meter image:"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'google_ml'),
            child: const Text('Google ML Kit'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'gemini'),
            child: const Text('Gemini'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Capture Fuel Meter')),
      body: Stack(
        children: [
          CameraPreview(_cameraController),
          Center(child: CustomPaint(size: Size.infinite, painter: CropBoxPainter())),
          Positioned(
            bottom: 30,
            left: 50,
            right: 50,
            child: ElevatedButton.icon(
              onPressed: _captureAndProcess,
              icon: const Icon(Icons.camera),
              label: const Text('Capture & Extract'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
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

    canvas.drawRect(offset & Size(width, height), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
