import 'package:flutter/material.dart';
import '../repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../core/services/biometric_service.dart';

enum AuthStatus { authenticated, unauthenticated, authenticating }

class AuthProvider with ChangeNotifier {
  final AuthRepository _repository = AuthRepository();
  final BiometricService _biometricService = BiometricService();
  UserModel? _user;
  AuthStatus _status = AuthStatus.authenticating;

  AuthProvider() {
    _repository.onAuthStateChanged.listen(_onAuthStateChanged);
  }

  UserModel? get user => _user;
  AuthStatus get status => _status;

  Future<bool> checkBiometricSupport() async {
    return await _biometricService.isBiometricAvailable();
  }

  void _onAuthStateChanged(UserModel? user) async {
    if (user == null) {
      // Don't logout if we just logged in via offline mode
      if (_user != null && _user!.uid.startsWith('offline_')) {
        return;
      }
      _status = AuthStatus.unauthenticated;
      _user = null;
    } else {
      _user = user;
      // Fetch profile (PIN/Unit) immediately after Firebase Auth succeeds
      final profile = await _repository.downloadProfile(user.email ?? '');
      if (profile != null) {
        _user = _user?.copyWith(
          pin: profile['pin'],
          unit: profile['unit'],
          name: profile['name'],
          mobileNumber: profile['mobile'],
        );
      }
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _status = AuthStatus.authenticating;
    notifyListeners();
    try {
      await _repository.login(email, password);
    } catch (e) {
      // Offline Login Support
      final profile = await _repository.downloadProfile(email);
      if (profile != null) {
        _user = UserModel(
          uid: 'offline_${email.hashCode}', 
          email: email,
          name: profile['name'],
          unit: profile['unit'],
          pin: profile['pin'],
          mobileNumber: profile['mobile'],
        );
        _status = AuthStatus.authenticated;
        notifyListeners();
        return;
      }
      
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String pin,
    required String name,
    required String mobile,
    required String unit,
  }) async {
    _status = AuthStatus.authenticating;
    notifyListeners();
    try {
      // Firebase requires at least 6 chars for password. 
      // We'll append a constant suffix to the 4-digit PIN for the Firebase password.
      final firebasePassword = "${pin}VOBPL"; 
      
      await _repository.register(
        email: email,
        password: firebasePassword,
        name: name,
        mobile: mobile,
        unit: unit,
      );
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loginWithGoogle() async {
    _status = AuthStatus.authenticating;
    notifyListeners();
    try {
      await _repository.loginWithGoogle();
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> biometricLogin() async {
    try {
      // 1. Check if biometrics available
      final isAvailable = await _biometricService.isBiometricAvailable();
      if (!isAvailable) throw 'Biometrics not available';

      // 2. Authenticate
      final authenticated = await _biometricService.authenticate();
      if (!authenticated) throw 'Authentication failed';

      // 3. Get stored credentials
      final credentials = await _repository.getStoredCredentials();
      if (credentials == null) throw 'No credentials stored. Please login with password once.';

      // 4. Perform login
      await login(credentials['email']!, credentials['password']!);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    // If we were in offline mode, we need to clear the local user manually
    if (_user != null && _user!.uid.startsWith('offline_')) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
    await _repository.logout();
  }

  // New Profile Methods
  Future<void> saveProfile({
    required String pin,
    required String unit,
    String? name,
    String? mobile,
  }) async {
    if (_user == null) return;
    
    final success = await _repository.uploadProfile(_user!.email!, pin, unit, name, mobile);
    if (success) {
      _user = _user!.copyWith(pin: pin, unit: unit, name: name, mobileNumber: mobile);
      notifyListeners();
    } else {
      throw 'Failed to save profile to server. Please check your connection.';
    }
  }

  Future<void> loginWithPin(String email, String pin) async {
    // 1. Fast Path: Verify PIN against secure local storage (< 10ms response)
    final localPin = await _repository.getStoredPin();
    if (localPin != null && localPin == pin) {
      _user = UserModel(
        uid: 'user_${email.hashCode}',
        email: email,
        name: await _repository.getStoredName() ?? 'Employee',
        unit: await _repository.getStoredUnit() ?? 'Unit 1',
        pin: pin,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();

      // Background Firebase Auth Sync (Non-blocking)
      _repository.getStoredCredentials().then((creds) {
        if (creds != null) {
          _repository.login(creds['email']!, creds['password']!).catchError((_) {});
        }
      });
      return;
    }

    // 2. Slow Path: Fallback to remote profile check if local PIN not found or new device
    final profile = await _repository.downloadProfile(email);
    if (profile == null) throw 'Account not found or profile not set up.';
    
    if (profile['pin'] != pin) throw 'Incorrect PIN';

    final credentials = await _repository.getStoredCredentials();
    if (credentials == null || credentials['email'] != email) {
      final firebasePassword = "${pin}VOBPL";
      await login(email, firebasePassword);
      return;
    }

    await login(credentials['email']!, credentials['password']!);
  }
}
