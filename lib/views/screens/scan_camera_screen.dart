import 'package:flutter/material.dart';
import 'package:oce_poc/view_model/scan_view_model.dart';
import 'package:provider/provider.dart';

import 'camera_capture_screen.dart';
import 'saved_submissions_screen.dart'; // Make sure this import exists

class ScanCameraScreen extends StatelessWidget {
  const ScanCameraScreen({super.key, required String title});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScanViewModel(),
      child: const _ScanCameraScreenBody(),
    );
  }
}

class _ScanCameraScreenBody extends StatefulWidget {
  const _ScanCameraScreenBody();

  @override
  State<_ScanCameraScreenBody> createState() => _ScanCameraScreenBodyState();
}

class _ScanCameraScreenBodyState extends State<_ScanCameraScreenBody> {
  Future<void> _scanFromGallery() async {
    final viewModel = context.read<ScanViewModel>();
    final hasPermission = await viewModel.requestGalleryPermission();

    if (!hasPermission) {
      _showSnackBar('Gallery permission denied');
      return;
    }

    final imageFile = await viewModel.pickAndCropImageFromGallery();
    if (imageFile == null) return;

    final detectedLines = await viewModel.processImage(imageFile);
    if (!mounted) return;
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

  void _showDetectedLinesDialog(List<String> rows) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detected Data'),
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

              final viewModel = Provider.of<ScanViewModel>(context, listen: false);
              viewModel.setScannedLines(rows); // <-- Store the lines first
              viewModel.submitScannedData(context, rows); // <-- Then submit them
            },

            child: const Text('Yes, Submit'),
          ),
        ],
      ),
    );
  }



  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ScanViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Text or Numbers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Saved Submissions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedSubmissionsScreen()),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
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
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _scanFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Upload from Gallery'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
              if (viewModel.selectedImage != null) ...[
                const SizedBox(height: 20),
                Image.file(viewModel.selectedImage!, height: 150),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
