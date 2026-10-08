class AppUpdateInfo {
  final String latestVersion;
  final int versionCode;
  final String apkUrl;
  final bool forceUpdate;
  final String releaseNotes;

  AppUpdateInfo({
    required this.latestVersion,
    required this.versionCode,
    required this.apkUrl,
    required this.forceUpdate,
    required this.releaseNotes,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['latest_version']?.toString() ?? '1.0.0',
      versionCode: int.tryParse(json['version_code']?.toString() ?? '1') ?? 1,
      apkUrl: json['apk_url']?.toString() ?? '',
      forceUpdate: json['force_update'] == true ||
          json['force_update']?.toString() == '1' ||
          json['force_update']?.toString().toLowerCase() == 'true',
      releaseNotes: json['release_notes']?.toString() ?? 'Bug fixes and new features',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latest_version': latestVersion,
      'version_code': versionCode,
      'apk_url': apkUrl,
      'force_update': forceUpdate,
      'release_notes': releaseNotes,
    };
  }
}
