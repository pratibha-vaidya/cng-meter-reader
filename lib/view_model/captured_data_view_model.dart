import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class CapturedDataViewModel extends ChangeNotifier {
  bool isSubmitting = false;
  final _box = Hive.box('offline_submissions');

  List<Map<String, dynamic>> submittedData = [];
  List<Map<String, dynamic>> pendingData = [];

  Future<void> submitMeterData({
    required String timestamp,
    required void Function() onSuccess,
    required void Function(String) onError,
  }) async {
    isSubmitting = true;
    notifyListeners();

    try {
      final hasInternet = await Connectivity().checkConnectivity() != ConnectivityResult.none;

      final existing = _box.get(timestamp);
      if (existing == null) {
        onError("Data not found for submission.");
        isSubmitting = false;
        notifyListeners();
        return;
      }

      // Update isSubmitted flag
      final updated = {
        ...Map<String, dynamic>.from(existing),
        'isSubmitted': hasInternet,
      };

      await _box.put(timestamp, updated);
      await loadData();

      onSuccess();
    } catch (e) {
      onError("Submission failed: ${e.toString()}");
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> loadData() async {
    submittedData.clear();
    pendingData.clear();

    for (var key in _box.keys) {
      final item = _box.get(key);
      if (item is Map && item.containsKey('isSubmitted')) {
        final data = Map<String, dynamic>.from(item);
        if (data['isSubmitted'] == true) {
          submittedData.add({...data, 'timestamp': key});
        } else {
          pendingData.add({...data, 'timestamp': key});
        }
      }
    }

    notifyListeners();
  }

  Map<String, dynamic>? getDataForKey(String key) {
    final item = _box.get(key);
    return item != null ? Map<String, dynamic>.from(item) : null;
  }
}
