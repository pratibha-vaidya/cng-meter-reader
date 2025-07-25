import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class SavedSubmissionsViewModel extends ChangeNotifier {
  final Box _box = Hive.box('offline_submissions');
  final Connectivity _connectivity = Connectivity();

  Map<String, Map<String, dynamic>> pendingSubmissions = {};
  Map<String, Map<String, dynamic>> submittedSubmissions = {};

  String? _selectedKey;
  bool _isSubmitting = false;
  bool _isLoading = true;

  String? get selectedKey => _selectedKey;
  bool get isSubmitting => _isSubmitting;
  bool get isLoading => _isLoading;

  SavedSubmissionsViewModel() {
    loadData();
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _submitPendingData();
      }
    });
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    final rawMap = _box.toMap();
    pendingSubmissions.clear();
    submittedSubmissions.clear();

    for (var entry in rawMap.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        final hasLines = value['lines'] != null && (value['lines'] as List).isNotEmpty;

        if (!hasLines) {
          await _box.delete(entry.key);
          continue;
        }

        final isSubmitted = value['isSubmitted'] ?? false;

        if (isSubmitted) {
          submittedSubmissions[key] = value;
        } else {
          pendingSubmissions[key] = value;
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Map<String, dynamic>? getSubmissionData(String key) {
    return pendingSubmissions[key] ?? submittedSubmissions[key];
  }

  void selectKey(String key) {
    _selectedKey = key;
    notifyListeners();
  }

  Future<void> handleSuccessfulSubmission(String key, Map<String, dynamic> data) async {
    final hasLines = data['lines'] != null && (data['lines'] as List).isNotEmpty;

    if (!hasLines) {
      debugPrint('Skipping save: Empty submission data.');
      await _box.delete(key);
      await loadData();
      return;
    }

    _isSubmitting = true;
    notifyListeners();

    final result = await Connectivity().checkConnectivity();
    final hasInternet = result != ConnectivityResult.none;

    final updatedRecord = {
      ...data,
      'isSubmitted': hasInternet,
    };

    await _box.put(key, updatedRecord);
    await loadData();

    _isSubmitting = false;
    notifyListeners();
  }

  Future<void> deleteSubmission(String key) async {
    await _box.delete(key);
    pendingSubmissions.remove(key);
    submittedSubmissions.remove(key);
    if (_selectedKey == key) _selectedKey = null;
    notifyListeners();
  }

  /// Auto-submit pending entries when back online
  Future<void> _submitPendingData() async {
    if (_isSubmitting || pendingSubmissions.isEmpty) return;

    _isSubmitting = true;
    notifyListeners();

    final pendingCopy = Map<String, Map<String, dynamic>>.from(pendingSubmissions);

    for (var entry in pendingCopy.entries) {
      try {
        final key = entry.key;
        final data = entry.value;

        // Simulate your actual submission logic
        await Future.delayed(const Duration(milliseconds: 500)); // Replace with real call
        final updated = {
          ...data,
          'isSubmitted': true,
        };

        await _box.put(key, updated);
      } catch (e) {
        debugPrint('Auto-submit failed for $entry.key: $e');
      }
    }

    await loadData();

    _isSubmitting = false;
    notifyListeners();
  }
}
