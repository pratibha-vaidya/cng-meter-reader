// import 'dart:io';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:hive/hive.dart';
// import 'package:dio/dio.dart';
//
// class OfflineSyncService {
//   final Box box = Hive.box('offline_submissions');
//   final Dio dio = Dio(); // Use your existing Dio setup
//
//   Future<void> syncIfConnected() async {
//     final connectivity = await Connectivity().checkConnectivity();
//     if (connectivity == ConnectivityResult.none) return;
//
//     final keys = box.keys.toList();
//     for (final key in keys) {
//       final data = box.get(key);
//       if (data == null) continue;
//
//       try {
//         final lines = data['lines'];
//         final imagePath = data['imagePath'];
//         final imageFile = File(imagePath ?? '');
//
//         // Send to server
//         final formData = FormData.fromMap({
//           'lines': lines.join(', '), // or send JSON
//           if (imageFile.existsSync())
//             'image': await MultipartFile.fromFile(imageFile.path),
//         });
//
//         final response = await dio.post(
//           'https://your.api/submit',
//           data: formData,
//         );
//
//         if (response.statusCode == 200) {
//           box.delete(key); // Remove only on success
//         }
//       } catch (e) {
//         print('Sync failed for $key: $e');
//       }
//     }
//   }
// }
