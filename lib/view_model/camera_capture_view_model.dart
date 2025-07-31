// lib/view_model/camera_capture_view_model.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraCaptureViewModel extends ChangeNotifier {
  final TextRecognizer _textRecognizer = TextRecognizer();

  late CameraController cameraController;
  bool isInitialized = false;
  bool isProcessing = false;

  String _locationName = '';
  String get locationName => _locationName;


  set setLocationName(String value) {
    _locationName = value;
    debugPrint('locationName::::::::$locationName');
    notifyListeners();
  } // Prefer method over custom setter
  void updateLocationName(String name) {
    _locationName = name;
    notifyListeners();
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    final rear = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
    cameraController = CameraController(rear, ResolutionPreset.high, enableAudio: false);
    await cameraController.initialize();
    isInitialized = true;
    notifyListeners();
  }

  Future<void> disposeCamera() async {
    if (isInitialized) {
      await cameraController.dispose();
      isInitialized = false;
    }
    await _textRecognizer.close();
  }

  Future<File> captureAndCrop() async {
    final file = await cameraController.takePicture();
    return _cropImageCenter(File(file.path));
  }

  Future<Map<String, dynamic>> processImage(File imageFile) async {
    final isOnline = await _hasInternet();
    String fullText = '';
    List<String> lines = [];

    if (isOnline) {
      final geminiResult = await _analyzeWithGemini(imageFile);
      if (geminiResult != null) {
        fullText = geminiResult;
        lines = [geminiResult];
      }
    }

    if (lines.isEmpty) {
      final inputImage = InputImage.fromFile(imageFile);
      final result = await _textRecognizer.processImage(inputImage);
      fullText = result.text;
      lines = result.blocks.expand((b) => b.lines.map((l) => l.text)).toList();
    }

    final name = await getLocationName();
    updateLocationName(name ?? "Unknown Location");
    setLocationName = name!;
    debugPrint('📍 LocationName: $locationName');

    return {
      'fullText': fullText,
      'labeledValues': lines,
      'location': locationName,
    };
  }

  Future<String?> getLocationName() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        return "${place.street}, ${place.locality}, ${place.administrativeArea}";
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Location error: $e');
      return null;
    }
  }

  Future<File> _cropImageCenter(File file) async {
    final bytes = await file.readAsBytes();
    final img.Image? raw = img.decodeImage(bytes);
    final img.Image fixed = img.bakeOrientation(raw!);
    final int cropWidth = (fixed.width * 0.8).toInt();
    final int cropHeight = (fixed.height * 0.4).toInt();
    final int cropX = ((fixed.width - cropWidth) / 2).toInt();
    final int cropY = ((fixed.height - cropHeight) / 2).toInt();

    final img.Image cropped = img.copyCrop(fixed, x: cropX, y: cropY, width: cropWidth, height: cropHeight);
    final dir = await getTemporaryDirectory();
    final croppedFile = File('${dir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await croppedFile.writeAsBytes(img.encodeJpg(cropped));
    return croppedFile;
  }

  Future<String?> _analyzeWithGemini(File imageFile) async {
    try {
      const apiKey = 'AIzaSyCpeM-TKkt8AEUkedaJLxAvjn0MKJwHLr4'; // 🔐 Consider moving to secure storage
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
      final match = RegExp(r'{.*}', dotAll: true).firstMatch(raw);
      return match?.group(0);
    } catch (e) {
      debugPrint('Gemini error: $e');
      return null;
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
