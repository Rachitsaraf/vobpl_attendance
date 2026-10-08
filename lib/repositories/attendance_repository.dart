import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/attendance_model.dart';
import '../models/breadcrumb_model.dart';
import '../core/services/database_helper.dart';
import '../core/constants/app_constants.dart';

class AttendanceRepository {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
  );

  /// Fire-and-forget background server sync (Non-blocking for instant UI response)
  void syncAttendanceInBackground(AttendanceModel attendance, String userEmail) {
    submitAttendance(attendance, userEmail).catchError((e) {
      debugPrint('Background check-in sync error: $e');
      return false;
    });
  }

  /// Fire-and-forget background check-out server sync (Non-blocking for instant UI response)
  void syncCheckOutInBackground(AttendanceModel attendance, String userEmail) {
    submitCheckOut(attendance, userEmail).catchError((e) {
      debugPrint('Background check-out sync error: $e');
      return false;
    });
  }

  Future<bool> submitAttendance(AttendanceModel attendance, String userEmail) async {
    try {
      // 1. Save to local SQLite first (Offline Support)
      await DatabaseHelper.instance.insertAttendance(attendance);

      // 2. Attempt server sync
      final url = '${AppConstants.baseUrl}${AppConstants.checkInEndpoint}';
      debugPrint('Syncing to: $url');
      
      final uri = Uri.parse(url);
      var request = http.MultipartRequest('POST', uri);
      request.fields['email'] = userEmail;
      request.fields['latitude'] = attendance.latitude.toString();
      request.fields['longitude'] = attendance.longitude.toString();
      request.fields['check_in_time'] = attendance.checkInTime.toIso8601String();
      if (attendance.checkOutTime != null) {
        request.fields['check_out_time'] = attendance.checkOutTime!.toIso8601String();
      }
      request.fields['status'] = attendance.status;
      request.fields['unit'] = attendance.unit ?? '';
      request.fields['remark'] = attendance.remark ?? '';

      if (attendance.selfiePath != null) {
        debugPrint('Uploading selfie from: ${attendance.selfiePath}');
        request.files.add(await http.MultipartFile.fromPath('selfie', attendance.selfiePath!));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('Response Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        bool success = data['success'] ?? false;
        if (success) {
          await DatabaseHelper.instance.markAsSynced(attendance.id);
          debugPrint('Sync Successful');

          // Delete local selfie file to save storage since it's uploaded to server
          if (attendance.selfiePath != null && !attendance.selfiePath!.startsWith('http')) {
            try {
              final file = File(attendance.selfiePath!);
              if (await file.exists()) {
                await file.delete();
                debugPrint('Deleted local synced selfie: ${attendance.selfiePath}');
              }
            } catch (e) {
              debugPrint('Error deleting local selfie: $e');
            }
          }
        }
        return success;
      } else {
        return false;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> submitCheckOut(AttendanceModel attendance, String userEmail) async {
    try {
      // 1. Update SQLite locally
      await DatabaseHelper.instance.insertAttendance(attendance);

      // 2. Attempt server sync
      final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.checkOutEndpoint}');
      var request = http.MultipartRequest('POST', uri);
      request.fields['email'] = userEmail;
      request.fields['check_out_time'] = attendance.checkOutTime?.toIso8601String() ?? DateTime.now().toIso8601String();
      if (attendance.unit != null) {
        request.fields['unit'] = attendance.unit!;
      }
      request.fields['remark'] = attendance.remark ?? '';

      if (attendance.selfiePath != null) {
        debugPrint('Uploading check-out selfie from: ${attendance.selfiePath}');
        request.files.add(await http.MultipartFile.fromPath('selfie', attendance.selfiePath!));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        bool success = data['success'] ?? true;
        if (success) {
          await DatabaseHelper.instance.markAsSynced(attendance.id);

          // Delete local selfie file to save storage since it's uploaded to server
          if (attendance.selfiePath != null && !attendance.selfiePath!.startsWith('http')) {
            try {
              final file = File(attendance.selfiePath!);
              if (await file.exists()) {
                await file.delete();
                debugPrint('Deleted local synced checkout selfie: ${attendance.selfiePath}');
              }
            } catch (e) {
              debugPrint('Error deleting local checkout selfie: $e');
            }
          }
        }
        return success;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AttendanceModel>> fetchAttendanceHistory(String userEmail) async {
    try {
      String emailToUse = userEmail;
      if (emailToUse.isEmpty) {
        emailToUse = await _storage.read(key: 'email') ?? '';
      }
      if (emailToUse.isEmpty) {
        // Fallback email for testing / fresh reinstall state
        emailToUse = 'rachitsaraf@vobpl.com';
      }

      final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.historyEndpoint}?email=$emailToUse');
      debugPrint('Fetching history from: $uri');
      
      final response = await http.get(uri).timeout(const Duration(milliseconds: 2500));
      debugPrint('History Response Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        if (body['success'] == true) {
          List data = body['data'];
          final serverData = data.map((item) => AttendanceModel.fromJson(item)).toList();
          debugPrint('Fetched ${serverData.length} records from server for $emailToUse');
          return serverData;
        }
      }
      
      // Fallback to local if server fails or is empty
      debugPrint('Server history failed or empty, showing local data');
      return await DatabaseHelper.instance.getAllAttendance();
    } catch (e) {
      debugPrint('History Fetch Error: $e');
      return await DatabaseHelper.instance.getAllAttendance();
    }
  }

  Future<bool> submitBreadcrumbs(List<BreadcrumbModel> breadcrumbs, String userEmail) async {
    if (breadcrumbs.isEmpty) return true;
    try {
      final url = '${AppConstants.baseUrl}/attendance/save_breadcrumbs.php';
      final uri = Uri.parse(url);
      final payload = {
        'email': userEmail,
        'breadcrumbs': breadcrumbs.map((b) => b.toJson()).toList(),
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final ids = breadcrumbs.map((b) => b.id).toList();
        await DatabaseHelper.instance.markBreadcrumbsSynced(ids);
        debugPrint('Synced ${breadcrumbs.length} breadcrumbs successfully.');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Breadcrumb sync failed: $e');
      return false;
    }
  }
}
