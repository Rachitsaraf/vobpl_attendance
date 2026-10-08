import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityProvider with ChangeNotifier {
  bool _isOnline = true;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    try {
      final List<ConnectivityResult> result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Connectivity Init Error: $e');
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // connectivity_plus 6.0.0+ returns a list
    final bool hasConnection = results.any((result) => result != ConnectivityResult.none);
    
    if (_isOnline != hasConnection) {
      _isOnline = hasConnection;
      if (_isOnline) {
        // We could call a callback here or use another mechanism to sync
        debugPrint('Internet Restored - Ready to Sync');
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
