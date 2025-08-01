import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hive/hive.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardViewModel extends ChangeNotifier {
  File? selectedImage;
  List<String> scannedLines = [];

  List<Map<String, dynamic>> submittedList = [];
  List<Map<String, dynamic>> pendingList = [];

  bool isSubmitting = false;

  void setSubmitting(bool value) {
    isSubmitting = value;
    notifyListeners();
  }

  Future<bool> requestGalleryPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return (androidInfo.version.sdkInt >= 33)
          ? (await Permission.photos.request()).isGranted
          : (await Permission.storage.request()).isGranted;
    } else if (Platform.isIOS) {
      return (await Permission.photos.request()).isGranted;
    }
    return false;
  }

  Future<bool> isInternetAvailable() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<String> getAreaNameFromCoordinates(Position position) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      final p = placemarks.first;
      return '${p.subLocality}, ${p.locality}, ${p.administrativeArea}, ${p.country}';
    }

    return 'Unknown Area';
  }

  Future<File?> pickAndCropImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatioPresets: [
        CropAspectRatioPreset.original,
        CropAspectRatioPreset.ratio4x3,
        CropAspectRatioPreset.ratio16x9,
      ],
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );

    if (cropped == null) return null;
    selectedImage = File(cropped.path);
    notifyListeners();
    return selectedImage;
  }

  Future<List<String>> processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final result = await recognizer.processImage(inputImage);
    await recognizer.close();
    return _extractLinesWithNumbers(result);
  }

  List<String> _extractLinesWithNumbers(RecognizedText recognizedText) {
    final List<String> lines = [];
    final numberRegex = RegExp(r'\b\d{1,3}(?:[.,]?\d{1,3}){1,2}\b');

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (numberRegex.hasMatch(text)) {
          lines.add(text);
        }
      }
    }

    scannedLines = lines;
    notifyListeners();
    return lines;
  }

  Future<void> savePendingSubmission(
      BuildContext context, List<String> lines, String timestamp) async {
    final box = await Hive.openBox('offline_submissions');

    final data = {
      'timestamp': timestamp,
      'lines': lines,
      'isSubmitted': false,
    };

    await box.put(timestamp, data);
    print('Saved pending submission: $data');
  }

  void submitScannedData(
      BuildContext context, List<String> lines, String timestamp) async {
    final box = Hive.box('offline_submissions');
    // final timestamp = DateTime.now().toIso8601String();

    final data = {
      'timestamp': timestamp,
      'lines': lines,
      'isSubmitted': true,
    };

    await box.put(timestamp, data); // Use timestamp as key
    print('Saved to Hive: $data');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data submitted successfully!')),
    );
  }


  void clear() {
    selectedImage = null;
    scannedLines = [];
    notifyListeners();
  }

  void setScannedLines(List<String> lines) {
    scannedLines = lines;
    notifyListeners();
  }

  void clearAfterSubmit() {
    Future.delayed(const Duration(seconds: 1), () {
      clear();
    });
  }
}
