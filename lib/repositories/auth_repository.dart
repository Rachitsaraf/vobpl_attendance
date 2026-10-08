import '../core/services/auth_service.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants/app_constants.dart';
import '../core/utils/string_extensions.dart';

class AuthRepository {
  final AuthService _authService = AuthService();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
  );

  Stream<UserModel?> get onAuthStateChanged =>
      _authService.userStream.map((User? user) => user != null ? UserModel.fromFirebase(user) : null);

  Future<void> login(String email, String password) async {
    await _authService.signIn(email, password);
    // After successful login, save credentials for biometric use
    await saveCredentials(email, password);
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String mobile,
    required String unit,
  }) async {
    // 1. Upload profile first so it's ready when auth state changes
    await uploadProfile(email, password, unit, name, mobile);
    // 2. Then sign up in Firebase
    await _authService.signUp(email, password);
    // 3. Save credentials locally
    await saveCredentials(email, password);
  }

  Future<void> loginWithGoogle() async {
    await _authService.signInWithGoogle();
  }

  Future<void> logout() async {
    await _authService.signOut();
    // Optional: clear credentials on logout if you want to force password next time
    // await clearStoredCredentials();
  }

  // Save credentials securely
  Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: 'email', value: email);
    await _storage.write(key: 'password', value: password);
  }

  // Get stored credentials & profile fields
  Future<Map<String, String>?> getStoredCredentials() async {
    String? email = await _storage.read(key: 'email');
    String? password = await _storage.read(key: 'password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  Future<String?> getStoredPin() async => await _storage.read(key: 'pin');
  Future<String?> getStoredName() async => await _storage.read(key: 'name');
  Future<String?> getStoredUnit() async => await _storage.read(key: 'unit');

  Future<void> clearStoredCredentials() async {
    await _storage.delete(key: 'email');
    await _storage.delete(key: 'password');
    await _storage.delete(key: 'pin');
    await _storage.delete(key: 'unit');
  }

  // Profile Remote Storage
  Future<bool> uploadProfile(
    String email,
    String pin,
    String unit, [
    String? name,
    String? mobile,
  ]) async {
    final formattedName = name?.toTitleCase();
    // 1. Save locally first for offline support
    await _storage.write(key: 'pin', value: pin);
    await _storage.write(key: 'unit', value: unit);
    if (formattedName != null) await _storage.write(key: 'name', value: formattedName);
    if (mobile != null) await _storage.write(key: 'mobile', value: mobile);

    // 2. Try to sync with server
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.saveProfileEndpoint}'),
        body: {
          'email': email,
          'pin': pin,
          'unit': unit,
          'name': formattedName ?? '',
          'mobile': mobile ?? '',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      // Saved locally, server sync will happen later or return true for offline success
      return true;
    }
  }

  Future<Map<String, String>?> downloadProfile(String email) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.getProfileEndpoint}?email=$email'),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final profile = data['data'];
          final formattedName = profile['name']?.toString().toTitleCase() ?? '';
          // Save locally
          await _storage.write(key: 'pin', value: profile['pin'].toString());
          await _storage.write(key: 'unit', value: profile['unit'].toString());
          await _storage.write(key: 'name', value: formattedName);
          await _storage.write(key: 'mobile', value: profile['mobile']?.toString() ?? '');
          
          return {
            'pin': profile['pin'].toString(),
            'unit': profile['unit'].toString(),
            'name': formattedName,
            'mobile': profile['mobile']?.toString() ?? '',
          };
        }
      }
    } catch (e) {
      // Return local data if server fails
    }
    
    // Check local storage
    String? pin = await _storage.read(key: 'pin');
    String? unit = await _storage.read(key: 'unit');
    String? name = await _storage.read(key: 'name');
    String? mobile = await _storage.read(key: 'mobile');
    
    if (pin != null && unit != null) {
      return {
        'pin': pin,
        'unit': unit,
        'name': name?.toTitleCase() ?? '',
        'mobile': mobile ?? '',
      };
    }
    return null;
  }
}
