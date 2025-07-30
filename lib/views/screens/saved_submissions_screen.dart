import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oce_poc/view_model/saved_submission_view_model.dart';
import 'package:oce_poc/views/screens/captured_data_details_screen.dart';
import 'package:provider/provider.dart';

class SavedSubmissionsScreen extends StatelessWidget {
  const SavedSubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SavedSubmissionsViewModel()..loadData(),
      child: const _SavedSubmissionsView(),
    );
  }
}

class _SavedSubmissionsView extends StatelessWidget {
  const _SavedSubmissionsView();

  void _confirmDelete(
      BuildContext context, String key, SavedSubmissionsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Submission"),
        content: const Text("Are you sure you want to delete this entry?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              viewModel.deleteSubmission(key);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Map<String, Map> submissions,
    required BuildContext context,
    required SavedSubmissionsViewModel viewModel,
    required bool isSubmitted,
  }) {
    if (submissions.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: submissions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final timestamp = submissions.keys.elementAt(index);
            final data = submissions[timestamp]!;
            final lines = List<String>.from(data['lines'] ?? []);
            final isSelected = viewModel.selectedKey == timestamp;

            return GestureDetector(
              onTap: isSubmitted
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CapturedDataDetailsScreen(
                      timestamp: timestamp,
                      data: data,
                      onSubmitted: (submittedKey, submittedData) {
                        context
                            .read<SavedSubmissionsViewModel>()
                            .handleSuccessfulSubmission(
                          submittedKey,
                          Map<String, dynamic>.from(submittedData),
                        );
                      },
                    ),
                  ),
                ).then((_) {
                  context
                      .read<SavedSubmissionsViewModel>()
                      .loadData();
                });
              },
              onLongPress: () =>
                  _confirmDelete(context, timestamp, viewModel),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSubmitted
                      ? Colors.green.shade50
                      : isSelected
                      ? Colors.green.shade700
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? Colors.green : Colors.grey.shade300,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    formatTimestamp(timestamp),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    'Data captured: ${lines.length}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  trailing: isSubmitted
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () =>
                        _confirmDelete(context, timestamp, viewModel),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SavedSubmissionsViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Submissions'),
        backgroundColor: Colors.green,
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (viewModel.pendingSubmissions.isEmpty &&
          viewModel.submittedSubmissions.isEmpty)
          ? const Center(
        child: Text(
          'No submissions available.',
          style: TextStyle(fontSize: 16),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            if (viewModel.pendingSubmissions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // ✅ Implement sync logic in ViewModel
                      viewModel.submitAllPending();
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ),
            _buildSection(
              title: '🕒 Pending Submissions',
              submissions: viewModel.pendingSubmissions,
              context: context,
              viewModel: viewModel,
              isSubmitted: false,
            ),
            _buildSection(
              title: '✅ Submitted Data',
              submissions: viewModel.submittedSubmissions,
              context: context,
              viewModel: viewModel,
              isSubmitted: true,
            ),
          ],
        ),
      ),
    );
  }

  String formatTimestamp(String raw) {
    try {
      final date = DateTime.parse(raw);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (_) {
      return raw;
    }
  }
}
