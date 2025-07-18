import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'camera_capture_screen.dart';

class ScannerLauncherScreen extends StatefulWidget {
  const ScannerLauncherScreen({super.key, required String title});

  @override
  State<ScannerLauncherScreen> createState() => _ScannerLauncherScreenState();
}

class _ScannerLauncherScreenState extends State<ScannerLauncherScreen> {
  File? _selectedImage;

  Future<void> _scanFromGallery() async {
    final permission = await Permission.photos.request();
    if (!permission.isGranted) return;

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Crop the image
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: picked.path,
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
        IOSUiSettings(
          title: 'Crop Image',
        ),
      ],
    );

    if (croppedFile == null) return;

    final file = File(croppedFile.path);
    final inputImage = InputImage.fromFile(file);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final result = await recognizer.processImage(inputImage);
    await recognizer.close();

    final fullLines = _extractFullLines(result);

    setState(() {
      _selectedImage = file;
    });

    _showScannedRows(fullLines);

  }

  Future<void> _scanFromCamera() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );

    if (result != null && result is Map) {
      final fullText = result['fullText'] ?? '';
      final labeledValues = result['labeledValues'] as List<String>? ?? [];

      _showScannedRows(labeledValues);
    }
  }


  List<String> _extractFullLines(RecognizedText recognizedText) {
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

  void _showLabeledResults(List<MapEntry<String, String>> values) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detected Values'),
        content: values.isEmpty
            ? const Text('No values found.')
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: values.map((e) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    e.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(e.value),
              ],
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showScannedRows(List<String> rows) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detected Rows'),
        content: rows.isEmpty
            ? const Text('No rows found.')
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: rows.map((text) => Text(text)).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
