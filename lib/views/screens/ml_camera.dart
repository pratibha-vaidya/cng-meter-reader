// import 'dart:convert';
// import 'dart:io';
//
// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import 'package:http/http.dart' as http;
// import 'package:image/image.dart' as img;
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class CameraCaptureScreen extends StatefulWidget {
//   const CameraCaptureScreen({super.key});
//
//   @override
//   State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
// }
//
// class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
//   late CameraController _cameraController;
//   bool _isInitialized = false;
//   bool _isProcessing = false;
//   late final TextRecognizer _textRecognizer;
//
//   @override
//   void initState() {
//     super.initState();
//     _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
//     _initializeCamera();
//   }
//
//   @override
//   void dispose() {
//     _cameraController.dispose();
//     _textRecognizer.close();
//     super.dispose();
//   }
//
//   Future<void> _initializeCamera() async {
//     final status = await Permission.camera.status;
//     if (!status.isGranted) {
//       final result = await Permission.camera.request();
//       if (!result.isGranted) return;
//     }
//
//     final cameras = await availableCameras();
//     final rearCamera = cameras.firstWhere(
//           (cam) => cam.lensDirection == CameraLensDirection.back,
//     );
//
//     _cameraController = CameraController(
//       rearCamera,
//       ResolutionPreset.high,
//       enableAudio: false,
//     );
//
//     await _cameraController.initialize();
//     if (mounted) {
//       setState(() => _isInitialized = true);
//     }
//   }
//
//   Future<void> _captureAndProcess() async {
//     setState(() => _isProcessing = true);
//
//     try {
//       await _cameraController.setFlashMode(FlashMode.off);
//       final file = await _cameraController.takePicture();
//       final croppedFile = await _cropImageCenter(File(file.path));
//
//       final hasInternet = await _checkInternet();
//       List<String> fuelData = [];
//
//       if (hasInternet) {
//         final geminiResult = await _analyzeWithGemini(croppedFile);
//         if (geminiResult != null) {
//           fuelData = geminiResult;
//         } else {
//           fuelData = await _analyzeWithMLKit(croppedFile);
//         }
//       } else {
//         fuelData = await _analyzeWithMLKit(croppedFile);
//       }
//
//       if (!mounted) return;
//
//       final confirmed = await _showConfirmationDialog(fuelData);
//       if (confirmed) {
//         Navigator.pop(context, {
//           'labeledValues': fuelData,
//         });
//       }
//     } catch (e) {
//       debugPrint('❌ Capture error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Failed to capture or process image.')),
//         );
//       }
//     } finally {
//       setState(() => _isProcessing = false);
//     }
//   }
//
//   Future<List<String>?> _analyzeWithGemini(File file) async {
//     try {
//       final bytes = await file.readAsBytes();
//       final base64Image = base64Encode(bytes);
//
//       final prompt = {
//         "contents": [
//           {
//             "parts": [
//               {
//                 "text":
//                 "Extract total price in Rupees, volume in Litres, and price per litre from this CNG meter image and return only JSON with keys: total_price_rupees, volume_litres, price_per_litre"
//               },
//               {
//                 "inline_data": {
//                   "mime_type": "image/jpeg",
//                   "data": base64Image,
//                 }
//               }
//             ]
//           }
//         ]
//       };
//
//       final uri = Uri.parse(
//         'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent?key=AIzaSyCpeM-TKkt8AEUkedaJLxAvjn0MKJwHLr4',
//       );
//
//
//       final response = await http.post(
//         uri,
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode(prompt),
//       );
//
//       if (response.statusCode == 200) {
//         final body = json.decode(response.body);
//         final text = body['candidates']?[0]?['content']?['parts']?[0]?['text'];
//         if (text != null) {
//           final jsonText = _extractJsonFromMarkdown(text);
//           final parsed = json.decode(jsonText);
//           return [
//             'Total Price (₹): ${parsed['total_price_rupees'] ?? ''}',
//             'Volume (Litres): ${parsed['volume_litres'] ?? ''}',
//             'Price per Litre (₹): ${parsed['price_per_litre'] ?? ''}',
//           ];
//         }
//       } else {
//         debugPrint('Gemini error: ${response.body}');
//       }
//     } catch (e) {
//       debugPrint('Gemini parsing failed: $e');
//     }
//     return null;
//   }
//
//   Future<List<String>> _analyzeWithMLKit(File file) async {
//     final inputImage = InputImage.fromFile(file);
//     final result = await _textRecognizer.processImage(inputImage);
//     final lines = _extractLines(result);
//     return _extractFuelData(lines);
//   }
//
//   List<String> _extractLines(RecognizedText result) {
//     final lines = <String>[];
//     for (final block in result.blocks) {
//       for (final line in block.lines) {
//         final text = line.text.trim();
//         if (text.isNotEmpty) lines.add(text);
//       }
//     }
//     return lines;
//   }
//
//   List<String> _extractFuelData(List<String> lines) {
//     String? totalPrice;
//     String? volume;
//     String? pricePerLitre;
//
//     final priceKeywords = ['rupees', 'rs', 'total', 'amount'];
//     final volumeKeywords = ['litre', 'litres', 'ltr'];
//     final rateKeywords = ['rs/litre', 'price per litre', 'rate'];
//
//     final numberPattern = RegExp(r'(\d{1,5}(?:[.,]\d{1,5})?)');
//
//     for (final rawLine in lines) {
//       final line = rawLine.toLowerCase();
//
//       if (totalPrice == null && priceKeywords.any((k) => line.contains(k))) {
//         final match = numberPattern.firstMatch(line);
//         if (match != null) totalPrice = match.group(1);
//       }
//
//       if (volume == null && volumeKeywords.any((k) => line.contains(k))) {
//         final match = numberPattern.firstMatch(line);
//         if (match != null) volume = match.group(1);
//       }
//
//       if (pricePerLitre == null && rateKeywords.any((k) => line.contains(k))) {
//         final match = numberPattern.firstMatch(line);
//         if (match != null) pricePerLitre = match.group(1);
//       }
//     }
//
//     return [
//       'Total Price (₹): ${totalPrice ?? ''}',
//       'Volume (Litres): ${volume ?? ''}',
//       'Price per Litre (₹): ${pricePerLitre ?? ''}',
//     ];
//   }
//
//   Future<File> _cropImageCenter(File file) async {
//     final bytes = await file.readAsBytes();
//     final img.Image? raw = img.decodeImage(bytes);
//     if (raw == null) throw Exception('Invalid image');
//
//     final fixed = img.bakeOrientation(raw);
//     final cropWidth = (fixed.width * 0.8).toInt();
//     final cropHeight = (fixed.height * 0.4).toInt();
//     final cropX = ((fixed.width - cropWidth) / 2).toInt();
//     final cropY = ((fixed.height - cropHeight) / 2).toInt();
//
//     final cropped = img.copyCrop(
//       fixed,
//       x: cropX,
//       y: cropY,
//       width: cropWidth,
//       height: cropHeight,
//     );
//
//     final dir = await getTemporaryDirectory();
//     final output = File('${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
//     await output.writeAsBytes(img.encodeJpg(cropped));
//     return output;
//   }
//
//   Future<bool> _checkInternet() async {
//     try {
//       final result = await InternetAddress.lookup('example.com');
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } catch (_) {
//       return false;
//     }
//   }
//
//   String _extractJsonFromMarkdown(String response) {
//     final regex = RegExp(r'```json([\s\S]*?)```');
//     final match = regex.firstMatch(response);
//     return match != null ? match.group(1)!.trim() : response.trim();
//   }
//
//   Future<bool> _showConfirmationDialog(List<String> lines) async {
//     return await showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text('Confirm Fuel Readings'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: lines.map((e) => Text(e)).toList(),
//         ),
//         actions: [
//           TextButton(
//             child: const Text('Cancel'),
//             onPressed: () => Navigator.pop(context, false),
//           ),
//           ElevatedButton(
//             child: const Text('Submit'),
//             onPressed: () => Navigator.pop(context, true),
//           ),
//         ],
//       ),
//     ) ??
//         false;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (!_isInitialized) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('Scan CNG Meter')),
//       body: Stack(
//         children: [
//           CameraPreview(_cameraController),
//           Container(color: Colors.black.withOpacity(0.4)),
//           Center(
//             child: CustomPaint(painter: RoundedCropBoxPainter(), size: Size.infinite),
//           ),
//           if (_isProcessing)
//             const Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
//           Positioned(
//             bottom: 40,
//             left: 50,
//             right: 50,
//             child: ElevatedButton.icon(
//               onPressed: _isProcessing ? null : _captureAndProcess,
//               icon: const Icon(Icons.camera_alt_rounded),
//               label: const Text('Capture'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.orange,
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class RoundedCropBoxPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final double width = size.width * 0.8;
//     final double height = size.height * 0.4;
//     final Offset topLeft = Offset(
//       (size.width - width) / 2,
//       (size.height - height) / 2,
//     );
//
//     final rect = topLeft & Size(width, height);
//     final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
//
//     final overlayPaint = Paint()..color = Colors.black.withOpacity(0.6);
//     final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
//     final hole = Path()..addRRect(rRect);
//     final shaded = Path.combine(PathOperation.difference, path, hole);
//     canvas.drawPath(shaded, overlayPaint);
//
//     final border = Paint()
//       ..color = Colors.white
//       ..strokeWidth = 3
//       ..style = PaintingStyle.stroke;
//     canvas.drawRRect(rRect, border);
//   }
//
//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) => false;
// }
