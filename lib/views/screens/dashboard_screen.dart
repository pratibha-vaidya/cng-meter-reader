import 'package:flutter/material.dart';
import 'package:oce_poc/view_model/dashboard_view_model.dart';
import 'package:oce_poc/view_model/saved_submission_view_model.dart';
import 'package:oce_poc/views/screens/gemini_camera.dart';
import 'package:provider/provider.dart';

import 'camera_capture_screen.dart';
import 'saved_submissions_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required String title});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardViewModel(),
      child: const DashboardBody(),
    );
  }
}

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text('Fuel Sales Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Saved Records',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => SavedSubmissionsViewModel(),
                  child: const SavedSubmissionsScreen(),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Icon(Icons.local_gas_station, size: 80, color: Colors.deepOrange),
            const SizedBox(height: 10),
            const Text(
              'Capture Daily Fuel Meter Readings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _buildScanCard(context),
            if (viewModel.selectedImage != null) ...[
              const SizedBox(height: 30),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(viewModel.selectedImage!, height: 150),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildButton(
              context,
              label: 'Scan Sales from Camera',
              icon: Icons.camera_alt,
              color: Colors.deepOrange,
              onPressed: () => _scanFromCamera(context),
            ),
            const SizedBox(height: 20),
            _buildButton(
              context,
              label: 'Upload Meter Photo',
              icon: Icons.photo_library,
              color: Colors.indigo,
              onPressed: () => _scanFromGallery(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context,
      {required String label,
        required IconData icon,
        required Color color,
        required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
    );
  }

  Future<void> _scanFromGallery(BuildContext context) async {
    final viewModel = context.read<DashboardViewModel>();
    final hasPermission = await viewModel.requestGalleryPermission();
    if (!hasPermission) {
      _showSnackBar(context, 'Gallery permission denied');
      return;
    }

    final imageFile = await viewModel.pickAndCropImageFromGallery();
    if (imageFile == null) return;

    final detectedLines = await viewModel.processImage(imageFile);
    _showDetectedLinesDialog(context, detectedLines);
  }

  Future<void> _scanFromCamera(BuildContext context) async {
    final result = await Navigator.push(
      context,
      // MaterialPageRoute(builder: (_) => const TesseractCamera()),
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );

    if (result is Map) {
      final lines = result['labeledValues'] as List<String>? ?? [];
      _showDetectedLinesDialog(context, lines);
    }
  }

  void _showDetectedLinesDialog(BuildContext context, List<String> rows) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detected Fuel Sales Data'),
        content: rows.isEmpty
            ? const Text('No data found.')
            : SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (_, index) => ListTile(title: Text(rows[index])),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (rows.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmSubmission(context, rows);
              },
              child: const Text('Submit'),
            ),
        ],
      ),
    );
  }

  void _confirmSubmission(BuildContext context, List<String> rows) {
    final dashboardVM = Provider.of<DashboardViewModel>(context, listen: false);
    final timestamp = DateTime.now().toIso8601String(); // ✅ Generate once

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Confirm Submission"),
          content: const Text("Are you sure you want to submit this data?"),
          actions: [
            FutureBuilder<bool>(
              future: dashboardVM.isInternetAvailable(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: CircularProgressIndicator(),
                  );
                }

                final hasInternet = snapshot.data!;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!hasInternet)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          dashboardVM.savePendingSubmission(context, rows, timestamp);
                          _showSnackBar(
                            context,
                            "Saved locally. Will submit when internet is available.",
                          );
                          dashboardVM.clearAfterSubmit(); // Optional cleanup
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                        ),
                        child: const Text('Submit Later'),
                      ),
                    const SizedBox(width: 10),
                    Visibility(

                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (hasInternet) {
                            dashboardVM.submitScannedData(context, rows, timestamp);
                            dashboardVM.clearAfterSubmit(); // Optional cleanup
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Yes, Submit'),
                      ),
                      visible: hasInternet,
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
