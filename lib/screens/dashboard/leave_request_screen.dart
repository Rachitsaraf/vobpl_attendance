import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_provider.dart';
import '../../models/leave_model.dart';
import '../../core/theme/app_theme.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  LeaveType _selectedType = LeaveType.leave;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final email = context.read<AuthProvider>().user?.email ?? '';
      context.read<LeaveProvider>().fetchLeaves(email);
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryOrange,
              onPrimary: Colors.white,
              onSurface: AppTheme.darkNavy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _submitRequest() async {
    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user?.email == null || user!.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User email not found. Please log in again.')),
      );
      return;
    }

    final leave = LeaveModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userEmail: user.email!,
      startDate: _startDate,
      endDate: _endDate,
      type: _selectedType,
      reason: _reasonController.text,
      requestedAt: DateTime.now(),
    );

    final String? error = await context.read<LeaveProvider>().requestLeave(leave);
    if (mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted successfully!'), backgroundColor: AppTheme.successGreen),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission Error: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveProvider = Provider.of<LeaveProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Leave Management', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkNavy)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Request Form
            _buildSectionHeader('Request New Leave'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  // Date Picker
                  GestureDetector(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range_rounded, color: AppTheme.primaryOrange),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date Range', style: TextStyle(fontSize: 10, color: AppTheme.secondaryText, fontWeight: FontWeight.bold)),
                              Text(
                                '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Leave Type Dropdown
                  DropdownButtonFormField<LeaveType>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Leave Type',
                      filled: true,
                      fillColor: AppTheme.bgLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: LeaveType.values.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type.displayName.toUpperCase()));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedType = val!),
                  ),
                  const SizedBox(height: 16),
                  
                  // Reason Text Field
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter reason for leave...',
                      filled: true,
                      fillColor: AppTheme.bgLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton(
                    onPressed: leaveProvider.isLoading ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: leaveProvider.isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SUBMIT REQUEST', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Previous Requests
            _buildSectionHeader('Recent Requests'),
            const SizedBox(height: 16),
            if (leaveProvider.isLoading && leaveProvider.leaves.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (leaveProvider.leaves.isEmpty)
              const Center(child: Text('No leave requests yet', style: TextStyle(color: AppTheme.secondaryText)))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: leaveProvider.leaves.length,
                itemBuilder: (context, index) {
                  final leave = leaveProvider.leaves[index];
                  return _buildLeaveCard(leave);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.darkNavy, letterSpacing: -0.5),
    );
  }

  Widget _buildLeaveCard(LeaveModel leave) {
    Color statusColor;
    switch (leave.status) {
      case LeaveStatus.approved: statusColor = AppTheme.successGreen; break;
      case LeaveStatus.rejected: statusColor = Colors.red; break;
      default: statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(
              leave.type == LeaveType.halfday ? Icons.hourglass_bottom_rounded : Icons.event_busy_rounded,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('MMM dd').format(leave.startDate)} - ${DateFormat('MMM dd').format(leave.endDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
                ),
                Text(leave.reason, style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(
              leave.status.name.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
