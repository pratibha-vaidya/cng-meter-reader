import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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

    final labeledValues = _extractLabeledValues(result);

    setState(() {
      _selectedImage = file;
    });

    _showLabeledResults(labeledValues);
  }

  Future<void> _scanFromCamera() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );

    if (result != null && result is Map) {
      final fullText = result['fullText'] ?? '';
      final labeledValues = _extractLabeledValuesFromText(fullText);
      _showLabeledResults(labeledValues);
    }
  }

  List<MapEntry<String, String>> _extractLabeledValues(RecognizedText recognizedText) {
    final List<MapEntry<String, String>> results = [];
    final RegExp numberRegex = RegExp(r'\b\d{1,6}(\.\d{1,2})?\b');
    final List<MapEntry<String, Offset>> allLines = [];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        final position = line.boundingBox?.topLeft ?? Offset.zero;
        allLines.add(MapEntry(text, position));
      }
    }

    allLines.sort((a, b) => a.value.dy.compareTo(b.value.dy));

    for (final entry in allLines) {
      final text = entry.key.trim();
      final position = entry.value;
      final match = numberRegex.firstMatch(text);

      if (match != null) {
        final number = match.group(0)!;

        final labelEntry = allLines.firstWhere(
              (e) {
            final labelText = e.key.toLowerCase().replaceAll(' ', '');
            final labelPos = e.value;
            final distance = (labelPos.dy - position.dy).abs();
            return distance < 30 &&
                (labelText.contains('rupees') ||
                    labelText.contains('litres') ||
                    labelText.contains('rs/litre'));
          },
          orElse: () => const MapEntry('', Offset.zero),
        );

        if (labelEntry.key.isNotEmpty) {
          final normalizedLabel = labelEntry.key.toUpperCase().trim();
          results.add(MapEntry(normalizedLabel, number));
        }
      }
    }

    return results;
  }

  List<MapEntry<String, String>> _extractLabeledValuesFromText(String fullText) {
    final List<MapEntry<String, String>> results = [];
    final RegExp numberRegex = RegExp(r'\b\d{1,6}(\.\d{1,2})?\b');
    final List<MapEntry<String, int>> allLines = [];

    final lines = fullText.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].trim();
      allLines.add(MapEntry(text, i));
    }

    allLines.sort((a, b) => a.value.compareTo(b.value));

    for (final entry in allLines) {
      final text = entry.key.trim();
      final index = entry.value;
      final match = numberRegex.firstMatch(text);

      if (match != null) {
        final number = match.group(0)!;

        final labelEntry = allLines.firstWhere(
              (e) {
            final labelText = e.key.trim();
            final lineDiff = (e.value - index).abs();
            final hasNoNumber = !numberRegex.hasMatch(labelText);
            return lineDiff <= 1 && hasNoNumber;
          },
          orElse: () => const MapEntry('', 0),
        );

        if (labelEntry.key.isNotEmpty) {
          final normalizedLabel = labelEntry.key.toUpperCase().trim();
          results.add(MapEntry(normalizedLabel, number));
        }
      }
    }

    return results;
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
