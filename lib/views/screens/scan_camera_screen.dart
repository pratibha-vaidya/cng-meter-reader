import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'camera_capture_screen.dart';

class ScanCameraScreen extends StatefulWidget {
  const ScanCameraScreen({super.key, required String title});

  @override
  State<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends State<ScanCameraScreen> {
  File? _selectedImage;

  Future<void> _scanFromGallery() async {
    final permissionStatus = await Permission.photos.request();
    if (!permissionStatus.isGranted) {
      _showSnackBar('Photo permission denied');
      return;
    }

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final cropped = await _cropImage(pickedFile.path);
    if (cropped == null) return;

    final detectedLines = await _processImage(File(cropped.path));
    if (!mounted) return;

    setState(() => _selectedImage = File(cropped.path));
    _showDetectedLinesDialog(detectedLines);
  }

  Future<void> _scanFromCamera() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );

    if (result is Map) {
      final labeledValues = result['labeledValues'] as List<String>? ?? [];
      _showDetectedLinesDialog(labeledValues);
    }
  }

  Future<CroppedFile?> _cropImage(String path) {
    return ImageCropper().cropImage(
      sourcePath: path,
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
  }

  Future<List<String>> _processImage(File imageFile) async {
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

    return lines;
  }

  void _showDetectedLinesDialog(List<String> rows) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detected Rows'),
        content: rows.isEmpty
            ? const Text('No data found.')
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: rows.map((line) => Text(line)).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (rows.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showSubmitConfirmation(rows);
              },
              child: const Text('Submit'),
            ),
        ],
      ),
    );
  }

  void _showSubmitConfirmation(List<String> rows) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: const Text('Are you sure you want to submit the scanned data?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitScannedData(rows);
            },
            child: const Text('Yes, Submit'),
          ),
        ],
      ),
    );
  }

  void _submitScannedData(List<String> rows) {
    // TODO: Replace this with your real API logic
    debugPrint('Scanned data submitted: ${rows.join(', ')}');
    _showSnackBar('Scanned data submitted successfully');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Text or Numbers')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.document_scanner, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text(
                'Scan Fuel Meter or Image Text',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _scanFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scan Using Camera'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.blue,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _scanFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Upload from Gallery'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.green,
                ),
              ),
              if (_selectedImage != null) ...[
                const SizedBox(height: 20),
                Image.file(_selectedImage!, height: 150),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
