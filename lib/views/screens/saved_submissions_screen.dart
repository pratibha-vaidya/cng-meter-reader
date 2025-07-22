import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:oce_poc/views/screens/captured_data_details_screen.dart';

class SavedSubmissionsScreen extends StatefulWidget {
  const SavedSubmissionsScreen({super.key});

  @override
  State<SavedSubmissionsScreen> createState() =>
      _SavedSubmissionsScreenState();
}

class _SavedSubmissionsScreenState extends State<SavedSubmissionsScreen> {
  late final Box box;

  @override
  void initState() {
    super.initState();
    box = Hive.box('offline_submissions');
  }

  @override
  Widget build(BuildContext context) {
    final keys = box.keys.toList().cast<String>().reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Submissions')),
      body: keys.isEmpty
          ? const Center(child: Text('No offline data available'))
          : ListView.builder(
        itemCount: keys.length,
        itemBuilder: (context, index) {
          final timestamp = keys[index];
          final rawData = box.get(timestamp);

          if (rawData is! Map) return const SizedBox();

          final lines = List<String>.from(rawData['lines'] ?? []);

          return ListTile(
            title: Text('Captured at: $timestamp'),
            subtitle: Text('Lines: ${lines.length}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CapturedDataDetailsScreen(
                    timestamp: timestamp,
                    data: rawData,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
