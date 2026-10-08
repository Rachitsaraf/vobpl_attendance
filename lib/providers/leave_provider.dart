import 'package:flutter/material.dart';
import '../models/leave_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants/app_constants.dart';

class LeaveProvider with ChangeNotifier {
  List<LeaveModel> _leaves = [];
  bool _isLoading = false;

  List<LeaveModel> get leaves => _leaves;
  bool get isLoading => _isLoading;

  Future<void> fetchLeaves(String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/attendance/get_leaves.php?email=${Uri.encodeComponent(email)}'),
      );

      debugPrint('Fetch Leaves Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List list = data['data'];
          final List<LeaveModel> fetchedLeaves = [];
          for (var item in list) {
            try {
              if (item is Map<String, dynamic>) {
                fetchedLeaves.add(LeaveModel.fromJson(item));
              }
            } catch (e) {
              debugPrint('Error parsing leave item $item: $e');
            }
          }
          _leaves = fetchedLeaves;
        }
      }
    } catch (e) {
      debugPrint('Error fetching leaves: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> requestLeave(LeaveModel leave) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/attendance/request_leave.php'),
        body: leave.toJson(),
      );

      debugPrint('Request Leave Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _leaves.insert(0, leave);
          return null; // null means success
        } else {
          return data['message'] ?? 'Server reported failure.';
        }
      } else {
        return 'Server (${response.statusCode}): ${response.body.isNotEmpty ? response.body : "Internal Server Error"}';
      }
    } catch (e) {
      debugPrint('Error requesting leave: $e');
      return 'Network connection error ($e)';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
