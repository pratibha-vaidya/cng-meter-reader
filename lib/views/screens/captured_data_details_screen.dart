import 'package:flutter/material.dart';
import 'package:oce_poc/view_model/captured_data_view_model.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class CapturedDataDetailsScreen extends StatelessWidget {
  final String timestamp;
  final Map data;

  final void Function(String timestamp, Map data)? onSubmitted;

  const CapturedDataDetailsScreen({
    super.key,
    required this.timestamp,
    required this.data,
    this.onSubmitted,
  });



  Future<bool> _isInternetAvailable() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  void _showNoInternetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("No Internet"),
        content: const Text("Please turn on internet to submit the meter reading."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = List<String>.from(data['lines'] ?? []);
    final meterReading = lines.join('\n');

    return ChangeNotifierProvider(
      create: (_) => CapturedDataViewModel(),
      child: Consumer<CapturedDataViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            appBar: AppBar(title: Text('Details - $timestamp')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: const Text("Meter Reading"),
                      subtitle: Text(meterReading),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: viewModel.isSubmitting
                        ? null
                        : () async {
                      final hasInternet = await _isInternetAvailable();
                      if (!hasInternet) {
                        _showNoInternetDialog(context);
                        return;
                      }

                      viewModel.submitMeterData(
                        timestamp: timestamp,
                        onSuccess: () {
                          if (lines.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No meter readings found to submit.')),
                            );
                            return;
                          }

                          final validData = {
                            ...data,
                            'timestamp': timestamp,
                            'lines': lines,
                          };

                          onSubmitted?.call(timestamp, validData);
                          Navigator.pop(context);
                        },
                        onError: (msg) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.cloud_upload),
                    label: viewModel.isSubmitting
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text("Submit"),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
