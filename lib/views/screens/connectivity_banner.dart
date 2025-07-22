import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:overlay_support/overlay_support.dart';

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key, required this.child});
  final Widget child;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  final Connectivity _connectivity = Connectivity();
  bool _isOffline = false;
  OverlaySupportEntry? _bannerEntry;

  @override
  void initState() {
    super.initState();

    // Initial connectivity check
    _checkInitialConnection();

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((status) {
      _handleConnectivityChange(status);
    });
  }

  void _checkInitialConnection() async {
    final status = await _connectivity.checkConnectivity();
    _handleConnectivityChange(status);
  }

  void _handleConnectivityChange(ConnectivityResult status) {
    final hasInternet = status != ConnectivityResult.none;

    if (!hasInternet && !_isOffline) {
      _isOffline = true;

      _bannerEntry = showOverlayNotification(
            (context) {
          return Material(
            color: Colors.red,
            child: SafeArea(
              top: false,
              bottom: true,
              child: ListTile(
                title: const Text(
                  'No Internet Connection',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        },
        duration: Duration.zero, // Show indefinitely
        position: NotificationPosition.bottom,
      );
    } else if (hasInternet && _isOffline) {
      _isOffline = false;
      _bannerEntry?.dismiss(); // Remove the bottom banner
      _bannerEntry = null;

      // Optional: show "Restored" message briefly
      showSimpleNotification(
        const Text('Connected to Internet'),
        background: Colors.green,
        position: NotificationPosition.bottom,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
