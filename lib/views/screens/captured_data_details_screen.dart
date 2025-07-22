import 'package:flutter/material.dart';

class CapturedDataDetailsScreen extends StatelessWidget {
  final String timestamp;
  final Map data;

  const CapturedDataDetailsScreen({
    super.key,
    required this.timestamp,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final lines = List<String>.from(data['lines'] ?? []);

    return Scaffold(
      appBar: AppBar(title: Text('Details - $timestamp')),
      body: lines.isEmpty
          ? const Center(child: Text('No lines found.'))
          : ListView.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) => ListTile(
          leading: Text('${index + 1}'),
          title: Text(lines[index]),
        ),
      ),
    );
  }
}
