import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:oce_poc/helpers/location_services.dart';
import 'package:oce_poc/view_model/camera_capture_view_model.dart';
import 'package:oce_poc/view_model/dashboard_view_model.dart';
import 'package:provider/provider.dart';

class CameraCaptureScreen extends StatelessWidget {
  const CameraCaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CameraCaptureViewModel()..initializeCamera(),
      child: const CameraCaptureView(),
    );
  }
}

class CameraCaptureView extends StatefulWidget {
  const CameraCaptureView({super.key});

  @override
  State<CameraCaptureView> createState() => _CameraCaptureViewState();
}

class _CameraCaptureViewState extends State<CameraCaptureView> {

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onCapturePressed(CameraCaptureViewModel vm) async {
    try {
      vm.isProcessing = true;
      setState(() {});

      final file = await vm.captureAndCrop();
      final result = await vm.processImage(file);

      if (!mounted) return;

      final location = vm.locationName;

      Navigator.pop(context, {
        'fullText': result['fullText'],
        'labeledValues': result['labeledValues'],
        'location': location,
      });
    } catch (e) {
      debugPrint('Capture error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to process image")),
      );
    } finally {
      vm.isProcessing = false;
      setState(() {});
    }
  }

  @override
  void initState() {
    initVariables();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<CameraCaptureViewModel>(context);

    if (!vm.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan CNG Meter'),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          if (!vm.isProcessing) CameraPreview(vm.cameraController),
          if (vm.isProcessing)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text("Processing...", style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          if (!vm.isProcessing) Container(color: Colors.black.withOpacity(0.3)),
          if (!vm.isProcessing)
            Center(child: CustomPaint(size: Size.infinite, painter: RoundedCropBoxPainter())),
          if (!vm.isProcessing)
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Text(
                    "Align the CNG meter reading inside the box",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Make sure the values are clearly visible",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          if (!vm.isProcessing)
            Positioned(
              bottom: 40,
              left: 50,
              right: 50,
              child: ElevatedButton.icon(
                onPressed: () => _onCapturePressed(vm),
                icon: const Icon(Icons.camera_alt_rounded, size: 24),
                label: const Text('Capture', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> initVariables() async {
    final vm = Provider.of<CameraCaptureViewModel>(context, listen: false);
   await vm.getLocationName();
  }
}

class RoundedCropBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width * 0.8;
    final double height = size.height * 0.4;
    final Offset topLeft = Offset(
      (size.width - width) / 2,
      (size.height - height) / 2,
    );

    final Rect rect = topLeft & Size(width, height);
    final RRect roundedRect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    final Paint overlayPaint = Paint()..color = Colors.black.withOpacity(0.6);
    final Path fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path holePath = Path()..addRRect(roundedRect);
    final Path finalPath = Path.combine(PathOperation.difference, fullPath, holePath);

    canvas.drawPath(finalPath, overlayPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(roundedRect, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
