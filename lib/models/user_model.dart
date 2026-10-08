import '../core/utils/string_extensions.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? pin;
  final String? unit;
  final String? name;
  final String? mobileNumber;

  UserModel({
    required this.uid,
    this.email,
    String? displayName,
    this.photoUrl,
    this.pin,
    this.unit,
    String? name,
    this.mobileNumber,
  })  : displayName = displayName?.toTitleCase(),
        name = name?.toTitleCase();

  /// Helper getter to get user's display name formatted with title case.
  String get formattedName {
    if (name != null && name!.trim().isNotEmpty) {
      return name!.toTitleCase();
    }
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.toTitleCase();
    }
    if (email != null && email!.contains('@')) {
      return email!.split('@')[0].toTitleCase();
    }
    return 'User';
  }

  // Factory to convert Firebase User to our App User
  factory UserModel.fromFirebase(dynamic firebaseUser) {
    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
    );
  }

  UserModel copyWith({
    String? pin,
    String? unit,
    String? name,
    String? mobileNumber,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      pin: pin ?? this.pin,
      unit: unit ?? this.unit,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
    );
  }
}
