import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hive/hive.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanViewModel extends ChangeNotifier {
  File? selectedImage;
  List<String> scannedLines = [];

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

  void submitScannedData(BuildContext context, List<String> lines) async {
    final box = Hive.box('offline_submissions');
    final timestamp = DateTime.now().toIso8601String();

    final data = {
      'timestamp': timestamp,
      'lines': lines,
    };

    await box.put(timestamp, data); // Use timestamp as key
    print('Saved to Hive: $data');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data submitted successfully!')),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
