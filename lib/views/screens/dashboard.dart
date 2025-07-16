import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required String title});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  late CameraController _cameraController;
  late TextRecognizer _textRecognizer;
  bool _isDetecting = false;
  bool _cameraInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      _showMessage('Camera permission denied');
      return;
    }

    final cameras = await availableCameras();
    final rearCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
    );

    _cameraController = CameraController(
      rearCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController.initialize();
      _cameraInitialized = true;

      _cameraController.startImageStream((CameraImage image) async {
        if (_isDetecting) return;
        _isDetecting = true;

        try {
          final inputImage = _buildInputImage(image);

          final recognizedText = await _textRecognizer.processImage(inputImage);
          final fullText = recognizedText.text.trim();

          if (fullText.isNotEmpty) {
            await _cameraController.stopImageStream();
            await _cameraController.dispose();
            await _textRecognizer.close();

            if (mounted) {
              Navigator.pop(context, fullText);
            }
          }
        } catch (e) {
          debugPrint('OCR error: $e');
        }

        _isDetecting = false;
      });

      if (mounted) setState(() {});
    } catch (e) {
      _showMessage('Failed to initialize camera');
    }
  }

  InputImage _buildInputImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final rotation = InputImageRotationValue.fromRawValue(
      _cameraController.description.sensorOrientation,
    ) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraInitialized || !_cameraController.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_cameraController.value.isInitialized) {
      _cameraController.dispose();
    }
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanning...')),
      body: _cameraInitialized && _cameraController.value.isInitialized
          ? CameraPreview(_cameraController)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
