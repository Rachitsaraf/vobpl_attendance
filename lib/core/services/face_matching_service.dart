import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

enum FaceMatchStatus { success, noFace, headAngle, mismatch, fileError }

class FaceMatchResult {
  final bool isMatch;
  final bool isFirstTimeEnrollment;
  final double similarityScore;
  final String? errorMessage;
  final FaceMatchStatus status;

  FaceMatchResult({
    required this.isMatch,
    this.isFirstTimeEnrollment = false,
    required this.similarityScore,
    this.errorMessage,
    this.status = FaceMatchStatus.success,
  });
}

class FaceMatchingService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
  );

  // Fast detector mode with landmarks
  static final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
      enableClassification: false,
      enableContours: false,
    ),
  );

  /// Resolve valid email address
  static Future<String> _resolveEmail(String rawEmail) async {
    final clean = rawEmail.trim();
    if (clean.isNotEmpty) return clean;
    final stored = await _storage.read(key: 'email');
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    return 'default_user';
  }

  /// Get storage key for user master face image path
  static String _getStorageKey(String userEmail) {
    final cleanEmail = userEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'master_face_path_$cleanEmail';
  }

  /// Get storage key for user master face feature vector
  static String _getVectorStorageKey(String userEmail) {
    final cleanEmail = userEmail.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return 'master_face_vector_$cleanEmail';
  }

  /// Check if user already has an enrolled master face
  static Future<bool> hasMasterFace(String userEmail) async {
    final email = await _resolveEmail(userEmail);
    final key = _getStorageKey(email);
    final path = await _storage.read(key: key);
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      return await file.exists();
    }
    return false;
  }

  /// Save master face image file path & feature vector for user (Only called on enrollment/reset)
  static Future<void> setMasterFace(String userEmail, String imagePath, [List<double>? vector]) async {
    final email = await _resolveEmail(userEmail);
    final key = _getStorageKey(email);
    final vectorKey = _getVectorStorageKey(email);
    final appDir = await getApplicationDocumentsDirectory();
    final cleanEmail = email.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final targetPath = '${appDir.path}/master_face_$cleanEmail.jpg';

    final sourceFile = File(imagePath);
    if (await sourceFile.exists()) {
      if (sourceFile.path != targetPath) {
        await sourceFile.copy(targetPath);
      }
      await _storage.write(key: key, value: targetPath);

      final featureVector = vector ?? await _extractFaceFeatureVector(targetPath);
      if (featureVector != null) {
        await _storage.write(key: vectorKey, value: featureVector.join(','));
      }
      debugPrint('Enrolled Master Face Template for $email at: $targetPath');
    }
  }

  /// Get enrolled master face file path
  static Future<String?> getMasterFacePath(String userEmail) async {
    final email = await _resolveEmail(userEmail);
    final key = _getStorageKey(email);
    return await _storage.read(key: key);
  }

  /// Clear master face enrollment (e.g., when resetting profile)
  static Future<void> resetMasterFace(String userEmail) async {
    final email = await _resolveEmail(userEmail);
    final key = _getStorageKey(email);
    final vectorKey = _getVectorStorageKey(email);
    final path = await _storage.read(key: key);
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await _storage.delete(key: key);
    await _storage.delete(key: vectorKey);
    debugPrint('Cleared Master Face Template for $email');
  }

  /// Helper to compute Euclidean distance between two points
  static double _pointDistance(Point<int> p1, Point<int> p2) {
    return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2));
  }

  /// Helper to compute angle in radians at vertex B formed by points A-B-C
  static double _angleAtVertex(Point<int> a, Point<int> b, Point<int> c) {
    final double baX = (a.x - b.x).toDouble();
    final double baY = (a.y - b.y).toDouble();
    final double bcX = (c.x - b.x).toDouble();
    final double bcY = (c.y - b.y).toDouble();

    final double dotProduct = (baX * bcX) + (baY * bcY);
    final double magBA = sqrt((baX * baX) + (baY * baY));
    final double magBC = sqrt((bcX * bcX) + (bcY * bcY));

    if (magBA <= 0 || magBC <= 0) return 0.0;
    final double cosTheta = (dotProduct / (magBA * magBC)).clamp(-1.0, 1.0);
    return acos(cosTheta);
  }

  /// Extracts 20 scale-, rotation- & distance-invariant facial geometry features
  static Future<List<double>?> _extractFaceFeatureVector(String imagePath, {void Function(FaceMatchStatus status)? onStatusChange}) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        onStatusChange?.call(FaceMatchStatus.fileError);
        return null;
      }

      final inputImage = InputImage.fromFilePath(imagePath);
      final List<Face> faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) {
        onStatusChange?.call(FaceMatchStatus.noFace);
        return null;
      }

      final Face face = faces.first;

      // Check head turn angle (must be looking straight)
      if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() > 25) {
        onStatusChange?.call(FaceMatchStatus.headAngle);
        return null;
      }

      // Extract Landmark positions
      final leftEyePos = face.landmarks[FaceLandmarkType.leftEye]?.position;
      final rightEyePos = face.landmarks[FaceLandmarkType.rightEye]?.position;
      final nosePos = face.landmarks[FaceLandmarkType.noseBase]?.position;
      final mouthBottomPos = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
      final mouthLeftPos = face.landmarks[FaceLandmarkType.leftMouth]?.position;
      final mouthRightPos = face.landmarks[FaceLandmarkType.rightMouth]?.position;

      if (leftEyePos == null || rightEyePos == null || nosePos == null) {
        onStatusChange?.call(FaceMatchStatus.noFace);
        return null;
      }

      final Point<int> leftEye = Point<int>(leftEyePos.x, leftEyePos.y);
      final Point<int> rightEye = Point<int>(rightEyePos.x, rightEyePos.y);
      final Point<int> nose = Point<int>(nosePos.x, nosePos.y);

      // Inter-pupillary distance (Scale Base)
      final double eyeDistance = _pointDistance(leftEye, rightEye);
      if (eyeDistance <= 0) return null;

      final Point<int> eyeMidPoint = Point<int>(
        (leftEye.x + rightEye.x) ~/ 2,
        (leftEye.y + rightEye.y) ~/ 2,
      );

      final Point<int> mouthLeft = mouthLeftPos != null
          ? Point<int>(mouthLeftPos.x, mouthLeftPos.y)
          : Point<int>((nose.x - eyeDistance * 0.3).round(), (nose.y + eyeDistance * 0.45).round());

      final Point<int> mouthRight = mouthRightPos != null
          ? Point<int>(mouthRightPos.x, mouthRightPos.y)
          : Point<int>((nose.x + eyeDistance * 0.3).round(), (nose.y + eyeDistance * 0.45).round());

      final Point<int> mouthBottom = mouthBottomPos != null
          ? Point<int>(mouthBottomPos.x, mouthBottomPos.y)
          : Point<int>(nose.x, (nose.y + eyeDistance * 0.55).round());

      // 12 Normalized Distances
      final double d1 = _pointDistance(leftEye, nose) / eyeDistance;
      final double d2 = _pointDistance(rightEye, nose) / eyeDistance;
      final double d3 = _pointDistance(leftEye, mouthLeft) / eyeDistance;
      final double d4 = _pointDistance(rightEye, mouthRight) / eyeDistance;
      final double d5 = _pointDistance(leftEye, mouthRight) / eyeDistance; // Cross 1
      final double d6 = _pointDistance(rightEye, mouthLeft) / eyeDistance; // Cross 2
      final double d7 = _pointDistance(nose, mouthLeft) / eyeDistance;
      final double d8 = _pointDistance(nose, mouthRight) / eyeDistance;
      final double d9 = _pointDistance(nose, mouthBottom) / eyeDistance;
      final double d10 = _pointDistance(mouthLeft, mouthRight) / eyeDistance;
      final double d11 = _pointDistance(eyeMidPoint, nose) / eyeDistance;
      final double d12 = _pointDistance(eyeMidPoint, mouthBottom) / eyeDistance;

      // 3 Facial Asymmetry Features
      final double a1 = (d1 - d2).abs();
      final double a2 = (d3 - d4).abs();
      final double a3 = (d5 - d6).abs();

      // 5 Scale- & Distance-Invariant Landmark Angles in Radians
      final double ang1 = _angleAtVertex(leftEye, nose, rightEye);       // Eye-Nose-Eye angle
      final double ang2 = _angleAtVertex(leftEye, mouthBottom, rightEye); // Eye-Mouth-Eye angle
      final double ang3 = _angleAtVertex(mouthLeft, nose, mouthRight);   // Mouth-Nose-Mouth angle
      final double ang4 = _angleAtVertex(leftEye, nose, mouthLeft);      // LeftEye-Nose-LeftMouth angle
      final double ang5 = _angleAtVertex(rightEye, nose, mouthRight);    // RightEye-Nose-RightMouth angle

      return [
        d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12,
        a1, a2, a3,
        ang1, ang2, ang3, ang4, ang5
      ];
    } catch (e) {
      debugPrint('Error extracting face feature vector: $e');
      return null;
    }
  }

  /// Get cached master vector or compute & cache it once
  static Future<List<double>?> _getOrComputeMasterVector(String email, String masterPath) async {
    final vectorKey = _getVectorStorageKey(email);
    final cachedStr = await _storage.read(key: vectorKey);
    if (cachedStr != null && cachedStr.isNotEmpty) {
      try {
        final parts = cachedStr.split(',');
        if (parts.length == 20) {
          return parts.map((e) => double.parse(e)).toList();
        }
      } catch (_) {}
    }

    // Fallback: extract from master image file once
    final vector = await _extractFaceFeatureVector(masterPath);
    if (vector != null) {
      await _storage.write(key: vectorKey, value: vector.join(','));
    }
    return vector;
  }

  /// Computes weighted Euclidean distance between two feature vectors
  static double _computeWeightedDistance(List<double> v1, List<double> v2) {
    if (v1.length != v2.length) return 1.0;

    // Feature Weights: [Distances x1.2], [Asymmetry x1.8], [Landmark Angles x2.2]
    final List<double> weights = [
      1.2, 1.2, 1.2, 1.2, 1.5, 1.5, 1.2, 1.2, 1.2, 1.2, 1.2, 1.2,
      1.8, 1.8, 1.8,
      2.2, 2.2, 2.2, 2.2, 2.2
    ];

    double weightedSumSq = 0.0;
    double weightTotal = 0.0;

    for (int i = 0; i < v1.length; i++) {
      final double diff = v1[i] - v2[i];
      final double w = i < weights.length ? weights[i] : 1.0;
      weightedSumSq += w * (diff * diff);
      weightTotal += w;
    }

    return sqrt(weightedSumSq / weightTotal);
  }

  /// Compares current scanned face against user's locked Master Face
  static Future<FaceMatchResult> verifyOrEnrollMasterFace({
    required String currentImagePath,
    required String userEmail,
  }) async {
    final emailToUse = await _resolveEmail(userEmail);
    final bool hasMaster = await hasMasterFace(emailToUse);

    FaceMatchStatus statusReason = FaceMatchStatus.success;
    final currentVector = await _extractFaceFeatureVector(currentImagePath, onStatusChange: (s) {
      statusReason = s;
    });

    if (currentVector == null) {
      String msg = 'Unable to detect facial features clearly. Please look straight at camera.';
      if (statusReason == FaceMatchStatus.noFace) {
        msg = 'No face detected inside frame. Please center your face.';
      } else if (statusReason == FaceMatchStatus.headAngle) {
        msg = 'Face is turned away. Please look directly straight at the camera.';
      }
      return FaceMatchResult(
        isMatch: false,
        similarityScore: 0.0,
        errorMessage: msg,
        status: statusReason,
      );
    }

    // First time check-in / enrollment -> Lock Master Face Template
    if (!hasMaster) {
      await setMasterFace(emailToUse, currentImagePath, currentVector);
      return FaceMatchResult(
        isMatch: true,
        isFirstTimeEnrollment: true,
        similarityScore: 1.0,
        status: FaceMatchStatus.success,
      );
    }

    // Get Locked Master Face Vector
    final masterPath = await getMasterFacePath(emailToUse);
    if (masterPath == null) {
      await setMasterFace(emailToUse, currentImagePath, currentVector);
      return FaceMatchResult(
        isMatch: true,
        isFirstTimeEnrollment: true,
        similarityScore: 1.0,
        status: FaceMatchStatus.success,
      );
    }

    final masterVector = await _getOrComputeMasterVector(emailToUse, masterPath);
    if (masterVector == null) {
      return FaceMatchResult(
        isMatch: false,
        similarityScore: 0.0,
        errorMessage: 'Master face record unreadable. Please reset face profile in settings.',
        status: FaceMatchStatus.fileError,
      );
    }

    // Compute Weighted Multi-Feature Distance
    final double weightedDistance = _computeWeightedDistance(masterVector, currentVector);

    // Calibrated Similarity Score (0.0 to 1.0)
    final double similarityScore = (1.0 - (weightedDistance * 5.2)).clamp(0.0, 1.0);

    debugPrint('1-TO-1 FACE VERIFICATION for $emailToUse: ${(similarityScore * 100).toStringAsFixed(1)}% match (Distance: ${weightedDistance.toStringAsFixed(3)})');

    // Strict Threshold: >= 0.65 (65% match required)
    if (similarityScore >= 0.65) {
      return FaceMatchResult(
        isMatch: true,
        similarityScore: similarityScore,
        status: FaceMatchStatus.success,
      );
    } else {
      return FaceMatchResult(
        isMatch: false,
        similarityScore: similarityScore,
        errorMessage: 'Face Mismatch! Scanned face (${(similarityScore * 100).round()}% match) does not match account owner.',
        status: FaceMatchStatus.mismatch,
      );
    }
  }
}
