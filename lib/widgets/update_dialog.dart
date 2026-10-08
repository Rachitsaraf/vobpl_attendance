import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/services/update_service.dart';

import '../core/theme/app_theme.dart';
import '../models/update_model.dart';

enum UpdateDialogStatus { initial, downloading, completed, error }

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  final String currentVersion;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
  });

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    required String currentVersion,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (context) => UpdateDialog(
        updateInfo: updateInfo,
        currentVersion: currentVersion,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  UpdateDialogStatus _status = UpdateDialogStatus.initial;
  double _progress = 0.0;
  String _errorMessage = '';

  Future<void> _startUpdate() async {
    if (!Platform.isAndroid) {
      setState(() {
        _status = UpdateDialogStatus.error;
        _errorMessage = 'In-app update is supported on Android devices only.';
      });
      return;
    }

    setState(() {
      _status = UpdateDialogStatus.downloading;
      _progress = 0.0;
      _errorMessage = '';
    });

    try {
      // Check install permission for Android 8.0+
      final installPermission = await Permission.requestInstallPackages.status;
      if (installPermission.isDenied) {
        final requested = await Permission.requestInstallPackages.request();
        if (requested.isDenied || requested.isPermanentlyDenied) {
          setState(() {
            _status = UpdateDialogStatus.error;
            _errorMessage = 'Permission to install unknown apps is required. Please enable it in Settings.';
          });
          return;
        }
      }

      // Execute OTA Download and Trigger Installer
      OtaUpdate().execute(
        widget.updateInfo.apkUrl,
        destinationFilename: 'vobpl_attendance_update.apk',
      ).listen(
        (OtaEvent event) {
          if (!mounted) return;
          setState(() {
            switch (event.status) {
              case OtaStatus.DOWNLOADING:
                _status = UpdateDialogStatus.downloading;
                _progress = double.tryParse(event.value ?? '0') ?? 0.0;
                break;
              case OtaStatus.INSTALLING:
                _status = UpdateDialogStatus.completed;
                _progress = 100.0;
                break;
              case OtaStatus.ALREADY_RUNNING_ERROR:
                _status = UpdateDialogStatus.downloading;
                break;
              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                _status = UpdateDialogStatus.error;
                _errorMessage = 'Permission denied to install APK update.';
                break;
              case OtaStatus.DOWNLOAD_ERROR:
                _status = UpdateDialogStatus.error;
                _errorMessage = 'APK download failed. Please check your internet connection.';
                break;
              case OtaStatus.CHECKSUM_ERROR:
                _status = UpdateDialogStatus.error;
                _errorMessage = 'Downloaded file integrity validation failed.';
                break;
              case OtaStatus.INTERNAL_ERROR:
              default:
                _status = UpdateDialogStatus.error;
                _errorMessage = 'An error occurred during update: ${event.status}';
                break;
            }
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _status = UpdateDialogStatus.error;
            _errorMessage = 'Update failed: $e';
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = UpdateDialogStatus.error;
        _errorMessage = 'Failed to start update: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isForce = widget.updateInfo.forceUpdate;

    return PopScope(
      canPop: !isForce && _status != UpdateDialogStatus.downloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isForce
                      ? Colors.red.shade50
                      : AppTheme.primaryOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isForce ? Icons.system_update_rounded : Icons.system_update_alt_rounded,
                  size: 38,
                  color: isForce ? Colors.red.shade600 : AppTheme.primaryOrange,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                isForce ? 'Update Required' : 'New Update Available',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkNavy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Content based on state
              _buildDialogContent(),

              const SizedBox(height: 20),

              // Action Buttons
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogContent() {
    switch (_status) {
      case UpdateDialogStatus.initial:
        return Column(
          children: [
            Text(
              widget.updateInfo.forceUpdate
                  ? 'A new version of the Attendance App is required. Please update to continue.'
                  : 'A new version of the Attendance App is available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.darkNavy.withOpacity(0.75),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Current Version', style: TextStyle(fontSize: 11, color: AppTheme.secondaryText)),
                      const SizedBox(height: 2),
                      Text(widget.currentVersion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  Container(height: 24, width: 1, color: Colors.grey.shade300),
                  Column(
                    children: [
                      const Text('Latest Version', style: TextStyle(fontSize: 11, color: AppTheme.secondaryText)),
                      const SizedBox(height: 2),
                      Text(
                        widget.updateInfo.latestVersion,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryOrange),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Release Notes:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkNavy.withOpacity(0.8),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.updateInfo.releaseNotes,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkNavy.withOpacity(0.7),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        );

      case UpdateDialogStatus.downloading:
        return Column(
          children: [
            const Text(
              'Downloading Update...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkNavy,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress / 100.0,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.updateInfo.forceUpdate ? Colors.red.shade600 : AppTheme.primaryOrange,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_progress.toInt()}% downloaded',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryText,
              ),
            ),
          ],
        );

      case UpdateDialogStatus.completed:
        return const Column(
          children: [
            Text(
              'Download complete.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
            ),
            SizedBox(height: 6),
            Text(
              'The new version is ready to install.',
              style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
            ),
          ],
        );

      case UpdateDialogStatus.error:
        return Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text(
              _errorMessage.isNotEmpty ? _errorMessage : 'Update failed. Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        );
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    if (_status == UpdateDialogStatus.downloading) {
      return const SizedBox.shrink();
    }

    final bool isForce = widget.updateInfo.forceUpdate;

    if (_status == UpdateDialogStatus.completed) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _startUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text(
            'INSTALL UPDATE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
      );
    }

    if (_status == UpdateDialogStatus.error) {
      return Row(
        children: [
          if (!isForce)
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(color: AppTheme.secondaryText)),
              ),
            ),
          Expanded(
            child: ElevatedButton(
              onPressed: _startUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('RETRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    // Initial State
    return Row(
      children: [
        if (!isForce) ...[
          Expanded(
            child: TextButton(
              onPressed: () {
                UpdateService.dismissUpdate(widget.updateInfo.versionCode);
                Navigator.pop(context);
              },
              child: const Text(
                'LATER',
                style: TextStyle(
                  color: AppTheme.secondaryText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: isForce ? 1 : 1,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: isForce
                    ? [Colors.red.shade600, Colors.red.shade800]
                    : [AppTheme.primaryOrange, AppTheme.secondaryOrange],
              ),
            ),
            child: ElevatedButton(
              onPressed: _startUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'UPDATE NOW',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
