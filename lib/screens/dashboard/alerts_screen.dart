import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AlertItem {
  final String id;
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color color;
  bool isRead;

  AlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
    this.isRead = false,
  });
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final List<AlertItem> _alerts = [
    AlertItem(
      id: '1',
      title: 'Offline Sync Successful',
      message: 'Your offline check-in and check-out records have been synced to the server.',
      time: '10 mins ago',
      icon: Icons.sync_rounded,
      color: AppTheme.successGreen,
      isRead: false,
    ),
    AlertItem(
      id: '2',
      title: 'Shift Checkout Reminder',
      message: 'Remember to mark your Check-out at the end of your workday.',
      time: '2 hours ago',
      icon: Icons.access_time_filled_rounded,
      color: AppTheme.primaryOrange,
      isRead: false,
    ),
    AlertItem(
      id: '4',
      title: 'Profile Updated',
      message: 'Your personal information and unit details were updated successfully.',
      time: '2 days ago',
      icon: Icons.verified_user_rounded,
      color: Colors.purple,
      isRead: true,
    ),
  ];

  void _markAllAsRead() {
    setState(() {
      for (var alert in _alerts) {
        alert.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All alerts marked as read'),
        backgroundColor: AppTheme.successGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text(
          'Notifications & Alerts',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkNavy),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: AppTheme.primaryOrange),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: _alerts.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20.0),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return _buildAlertCard(alert);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_rounded, size: 60, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Alerts Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkNavy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You are all caught up with your notifications!',
            style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertItem alert) {
    return GestureDetector(
      onTap: () {
        if (!alert.isRead) {
          setState(() {
            alert.isRead = true;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkNavy.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: alert.isRead ? null : Border.all(color: alert.color.withOpacity(0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: alert.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(alert.icon, color: alert.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: alert.isRead ? AppTheme.darkNavy : alert.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        alert.time,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.secondaryText.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alert.message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppTheme.darkNavy.withOpacity(0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
