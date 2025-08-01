import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:oce_poc/view_model/camera_capture_view_model.dart';
import 'package:oce_poc/view_model/dashboard_view_model.dart';
import 'package:oce_poc/view_model/saved_submission_view_model.dart';
import 'package:oce_poc/views/screens/camera_capture_screen.dart';
import 'package:oce_poc/views/screens/saved_submissions_screen.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.title});
  final String title;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final _screens = [
    const DashboardBody(),
    ChangeNotifierProvider(
      create: (_) => SavedSubmissionsViewModel(),
      child: const SavedSubmissionsScreen(),
    ),
  ];

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardViewModel(),
      child: Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: SizedBox(
          height: 80, // 👈 Increased height here
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onTabTapped,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Submissions'),
            ],
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.grey,
            iconSize: 30,
            selectedFontSize: 16,
            unselectedFontSize: 14,
          ),
        ),

      ),
    );
  }
}

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text('📟 CNG Meter Reading'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(Icons.speed, size: 80, color: Colors.orange.shade700),
            const SizedBox(height: 12),
            const Text(
              'Capture Your Daily CNG DU Meter Readings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _buildScanCard(context),
            if (viewModel.selectedImage != null) ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(viewModel.selectedImage!, height: 180),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(BuildContext context) {

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildButton(
              context,
              label: 'Scan CNG DU Reading (Camera)',
              icon: Icons.camera_alt,
              color: Colors.teal.shade400,
              onPressed: () => _scanFromCamera(context),
            ),
            const SizedBox(height: 16),
            _buildButton(
              context,
              label: 'Upload DU Meter Image',
              icon: Icons.photo_library,
              color: Colors.lightGreen.shade400,
              onPressed: () => _scanFromGallery(context),
            ),
            const SizedBox(height: 16),
            _buildButton(
              context,
              label: 'Enter DU Reading Manually',
              icon: Icons.edit_note,
              color: Colors.grey.shade500,
              onPressed: () => _showManualEntryDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context,
      {required String label,
        required IconData icon,
        required Color color,
        required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
    );
  }

  void _scanFromCamera(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );



    if (result != null && result is Map<String, dynamic>) {
      final lines = result['labeledValues'] as List<String>;
      final location = result['location'] as String? ?? 'Not found';
      debugPrint('Locationnnn::::$location');

      _showDetectedLinesDialog(context, lines, location );
    }

  }

  void _scanFromGallery(BuildContext context) async {
    final viewModel = context.read<DashboardViewModel>();
    final hasPermission = await viewModel.requestGalleryPermission();
    if (!hasPermission) {
      _showSnackBar(context, 'Gallery permission denied');
      return;
    }

    final imageFile = await viewModel.pickAndCropImageFromGallery();
    if (imageFile == null) return;

    final detectedLines = await viewModel.processImage(imageFile);
    _showDetectedLinesDialog(context, detectedLines, '');
  }

  void _showManualEntryDialog(BuildContext context) {
    final priceController = TextEditingController();
    final volumeController = TextEditingController();
    final rateController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("✍️ Manual DU Reading Entry"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildInputField(priceController, "Total Price (₹)"),
              const SizedBox(height: 10),
              _buildInputField(volumeController, "Litres"),
              const SizedBox(height: 10),
              _buildInputField(rateController, "Price per Litre (₹)"),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final enteredData = {
                "total_price_rupees": priceController.text.trim(),
                "volume_litres": volumeController.text.trim(),
                "price_per_litre": rateController.text.trim(),
              };
              _showFormattedFuelDataDialog(context, enteredData,);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  void _showDetectedLinesDialog(BuildContext context, List<String> lines,String location) {
    final jsonString = _extractJsonFromLines(lines);

    Map<String, dynamic> _extractFuelDataFromText(String text) {
      final lower = text.toLowerCase();

      String extractValue(String keyword) {
        final regex = RegExp(r'([\d,.]+)\s*' + RegExp.escape(keyword), caseSensitive: false);
        final match = regex.firstMatch(lower);
        return match?.group(1)?.replaceAll(',', '') ?? '';
      }

      return {
        'total_price_rupees': extractValue('rupees'),
        'volume_litres': extractValue('litres'),
        'price_per_litre': extractValue('rs./litre') != ''
            ? extractValue('rs./litre')
            : extractValue('₹/litre'),
      };
    }

    Map<String, dynamic>? extractedData;

    if (jsonString != null) {
      try {
        final data = json.decode(jsonString);
        if (data is Map<String, dynamic>) {
          extractedData = data;
        }
      } catch (e) {
        debugPrint('❌ JSON parse error: $e');
      }
    }
    extractedData ??= _extractFuelDataFromText(lines.join('\n'));
    extractedData['location'] = location;
    debugPrint('extractedLocation::::: ${extractedData}');

    _showFormattedFuelDataDialog(context, extractedData, );
  }

  void _showFormattedFuelDataDialog(BuildContext context, Map<String, dynamic> data,) {

    debugPrint('data::::: $data');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('✅ CNG Meter Readings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildValueTile("Total Price", data["total_price_rupees"], "₹"),
            _buildValueTile("Litres", data["volume_litres"], "L"),
            _buildValueTile("Rate per Litre", data["price_per_litre"], "₹"),
            _buildValueTile("Location",data["location"], ""),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditableFuelDialog(context, data);
            },
            child: const Text('Edit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmSubmission(context, [
                'Total Price (₹): ${data["total_price_rupees"]}',
                'Litres: ${data["volume_litres"]}',
                'Price per Litre (₹): ${data["price_per_litre"]}',
                'Location: ${data["location"]}',
              ]);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildValueTile(String label, dynamic value, String unit) {
    final stringValue = (value ?? '').toString().trim();
    final isMissing = stringValue.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              isMissing ? 'Not found' : '$stringValue $unit',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMissing ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showEditableFuelDialog(BuildContext context, Map<String, dynamic> originalData,) {
    final priceController = TextEditingController(text: originalData["total_price_rupees"] ?? '');
    final volumeController = TextEditingController(text: originalData["volume_litres"] ?? '');
    final rateController = TextEditingController(text: originalData["price_per_litre"] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("✏️ Edit Meter Readings"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _buildInputField(priceController, "Total Price (₹)"),
              const SizedBox(height: 10),
              _buildInputField(volumeController, " Litres"),
              const SizedBox(height: 10),
              _buildInputField(rateController, "Price per Litre (₹)"),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final updatedData = {
                "total_price_rupees": priceController.text.trim(),
                "volume_litres": volumeController.text.trim(),
                "price_per_litre": rateController.text.trim(),
              };
              _showFormattedFuelDataDialog(context, updatedData,);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }


  void _confirmSubmission(BuildContext context, List<String> rows) {
    final dashboardVM = Provider.of<DashboardViewModel>(context, listen: false);
    final timestamp = DateTime.now().toIso8601String();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Confirm Submission"),
          content: const Text("Are you sure you want to submit this data?"),
          actions: [
            FutureBuilder<bool>(
              future: dashboardVM.isInternetAvailable(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: CircularProgressIndicator(),
                  );
                }

                final hasInternet = snapshot.data!;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!hasInternet)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          dashboardVM.savePendingSubmission(context, rows, timestamp);
                          _showSnackBar(
                            context,
                            "Data will be submitted once the internet is back!",
                          );
                          dashboardVM.clearAfterSubmit();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                        child: const Text('Submit Later'),
                      ),
                    const SizedBox(width: 10),
                    if (hasInternet)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          dashboardVM.submitScannedData(context, rows, timestamp);
                          dashboardVM.clearAfterSubmit();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('Yes, Submit'),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  String? _extractJsonFromLines(List<String> lines) {
    final cleanedLines = lines
        .where((line) => !line.trim().startsWith('```'))
        .map((line) => line.trim())
        .join();

    return cleanedLines.contains('{') && cleanedLines.contains('}')
        ? cleanedLines
        : null;
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
