import 'package:flutter/material.dart';
import 'package:oce_poc/views/screens/dashboard.dart';
import 'package:oce_poc/views/screens/select_image_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: ScannerLauncherScreen(title: 'Fuel Meter reading'),
    );
  }
}
