import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:oce_poc/view_model/camera_capture_view_model.dart';
import 'package:oce_poc/view_model/dashboard_view_model.dart';
import 'package:oce_poc/views/screens/connectivity_banner.dart';
import 'package:oce_poc/views/screens/dashboard_screen.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);

  await Hive.openBox('offline_submissions');

  runApp(
    OverlaySupport.global(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.green.shade50,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: ConnectivityBanner(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => DashboardViewModel()),
            ChangeNotifierProvider(create: (_) => CameraCaptureViewModel()),
          ],
          child: DashboardScreen(title: 'Fuel Meter Reading'),
        ),
      ),
    );
  }
}
