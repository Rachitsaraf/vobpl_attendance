import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/face_matching_service.dart';

enum ScanStatus { initial, matching, matched, mismatch, noFace }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isFlashOn = false;

  ScanStatus _scanStatus = ScanStatus.initial;
  String _statusTitle = 'Align Face Inside Frame';
  String _statusSubtitle = 'Hold still with good lighting for instant verification';

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  // Modern tech accent colors - Crisp Cyan instead of heavy yellow/orange
  static const Color _techCyan = Color(0xFF00E5FF);
  static const Color _techBlue = Color(0xFF2979FF);
  static const Color _successGreen = Color(0xFF00E676);
  static const Color _errorRed = Color(0xFFFF3366);

  @override
  void initState() {
    super.initState();

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    _initializeCamera();
  }

  Future<void> _initializeCamera({int cameraIndex = 0}) async {
    try {
      debugPrint('Initializing face camera...');
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        int targetIndex = cameraIndex;
        if (cameraIndex == 0) {
          final frontIndex = _cameras!.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
          );
          if (frontIndex != -1) targetIndex = frontIndex;
        }

        _selectedCameraIndex = targetIndex;

        await _controller?.dispose();
        // Medium resolution is 3x faster to capture and process than High
        _controller = CameraController(
          _cameras![targetIndex],
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera detected on device.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera Error: $e')),
        );
      }
    }
  }

  void _toggleCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    final nextIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    _initializeCamera(cameraIndex: nextIndex);
  }

  void _toggleFlash() async {
    if (_controller == null || !_isInitialized) return;
    try {
      _isFlashOn = !_isFlashOn;
      await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (e) {
      debugPrint('Flash toggle error: $e');
    }
  }

  Color get _statusColor {
    switch (_scanStatus) {
      case ScanStatus.matched:
        return _successGreen;
      case ScanStatus.mismatch:
      case ScanStatus.noFace:
        return _errorRed;
      case ScanStatus.matching:
        return _techBlue;
      case ScanStatus.initial:
        return _techCyan;
    }
  }

  IconData get _statusIcon {
    switch (_scanStatus) {
      case ScanStatus.matched:
        return Icons.verified_rounded;
      case ScanStatus.mismatch:
      case ScanStatus.noFace:
        return Icons.error_outline_rounded;
      case ScanStatus.matching:
        return Icons.center_focus_strong_rounded;
      case ScanStatus.initial:
        return Icons.face_retouching_natural_rounded;
    }
  }

  Future<void> _captureAndReturnImage() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) return;

    final userEmail = context.read<AuthProvider>().user?.email ?? '';

    setState(() {
      _isCapturing = true;
      _scanStatus = ScanStatus.matching;
      _statusTitle = 'Verifying Face Geometry...';
      _statusSubtitle = 'Processing landmarks with AI model';
    });

    try {
      final image = await _controller!.takePicture();
      final originalPath = image.path;

      // 1. Instant 1-to-1 Master Face Matching (Single Pass, Fast Mode)
      final matchResult = await FaceMatchingService.verifyOrEnrollMasterFace(
        currentImagePath: originalPath,
        userEmail: userEmail,
      );

      if (!matchResult.isMatch) {
        try {
          final rawFile = File(originalPath);
          if (await rawFile.exists()) await rawFile.delete();
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          _isCapturing = false;
          _scanStatus = matchResult.status == FaceMatchStatus.noFace ? ScanStatus.noFace : ScanStatus.mismatch;
          _statusTitle = matchResult.status == FaceMatchStatus.noFace ? 'No Face Detected' : 'Face Mismatch';
          _statusSubtitle = matchResult.errorMessage ?? 'Scanned face does not match account owner.';
        });
        return;
      }

      // MATCH SUCCESSFUL!
      if (mounted) {
        setState(() {
          _scanStatus = ScanStatus.matched;
          _statusTitle = matchResult.isFirstTimeEnrollment
              ? 'Master Face Enrolled!'
              : 'Identity Verified';
          _statusSubtitle = 'Match score: ${(matchResult.similarityScore * 100).round()}%. Saving attendance...';
        });
      }

      // Ultra short confirmation pause for visual feedback
      await Future.delayed(const Duration(milliseconds: 250));

      // 2. Compress image in background and return
      final compressedPath = originalPath.replaceAll('.jpg', '_compressed.jpg');
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        originalPath,
        compressedPath,
        quality: 60,
      );

      try {
        final rawFile = File(originalPath);
        if (await rawFile.exists()) await rawFile.delete();
      } catch (_) {}

      if (!mounted) return;
      if (compressedFile != null) {
        Navigator.pop(context, compressedFile.path);
      } else {
        Navigator.pop(context, originalPath);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _scanStatus = ScanStatus.mismatch;
        _statusTitle = 'Capture Failed';
        _statusSubtitle = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _laserController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(color: _techCyan, strokeWidth: 3),
              ),
              SizedBox(height: 18),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final currentColor = _statusColor;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Smart Face Scanner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isFlashOn ? _techCyan : Colors.white70,
            ),
            onPressed: _toggleFlash,
          ),
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white70),
              onPressed: _toggleCamera,
            ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Clean Full Camera Stream Preview
          SizedBox.expand(
            child: CameraPreview(_controller!),
          ),

          // 2. Dark Translucent Mask Overlay (Leaves oval cutout 100% natural and untinted)
          CustomPaint(
            size: Size.infinite,
            painter: _FaceScannerOverlayPainter(),
          ),

          // 3. Crisp Oval Outline & Corner Scanner Brackets
          Center(
            child: SizedBox(
              width: 270,
              height: 350,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Oval Border Line
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 260,
                    height: 340,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(170),
                      border: Border.all(
                        color: currentColor,
                        width: 3.0,
                      ),
                    ),
                  ),

                  // Laser Beam Scanning Line
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 20 + (_laserAnimation.value * 300),
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: currentColor,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: currentColor.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Top Glassmorphic Status Banner
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1829).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: currentColor.withValues(alpha: 0.7), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: currentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon, color: currentColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _statusTitle,
                          style: TextStyle(
                            color: currentColor == _errorRed ? const Color(0xFFFF8A80) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _statusSubtitle,
                          style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Bottom Modern Shutter Action Button
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _isCapturing ? null : _captureAndReturnImage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3.5),
                      gradient: LinearGradient(
                        colors: currentColor == _errorRed
                            ? [const Color(0xFFD50000), _errorRed]
                            : (currentColor == _successGreen
                                ? [const Color(0xFF00C853), _successGreen]
                                : [_techBlue, _techCyan]),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withValues(alpha: 0.4),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _isCapturing
                        ? const Padding(
                            padding: EdgeInsets.all(22.0),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 34),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isCapturing ? 'VERIFYING FACE...' : 'TAP TO CAPTURE ATTENDANCE',
                  style: TextStyle(
                    color: currentColor == _errorRed ? const Color(0xFFFF8A80) : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Translucent dark background overlay painter with transparent face oval cutout
class _FaceScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    const ovalWidth = 260.0;
    const ovalHeight = 340.0;
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: ovalWidth,
      height: ovalHeight,
    );

    final path = Path()
      ..addRect(rect)
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
