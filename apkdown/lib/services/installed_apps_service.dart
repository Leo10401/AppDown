import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents an app that was installed through AppRunner.
class InstalledApp {
  final String name;         // APK filename (e.g., "app-release.apk")
  final String repoFullName; // e.g., "user/repo"
  final String tagName;      // Release tag (e.g., "v1.2.0")
  final String releaseName;  // Release title
  final int sizeBytes;       // APK file size
  final DateTime installedAt;

  InstalledApp({
    required this.name,
    required this.repoFullName,
    required this.tagName,
    required this.releaseName,
    required this.sizeBytes,
    required this.installedAt,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'repoFullName': repoFullName,
    'tagName': tagName,
    'releaseName': releaseName,
    'sizeBytes': sizeBytes,
    'installedAt': installedAt.toIso8601String(),
  };

  factory InstalledApp.fromJson(Map<String, dynamic> json) => InstalledApp(
    name: json['name'] ?? '',
    repoFullName: json['repoFullName'] ?? '',
    tagName: json['tagName'] ?? '',
    releaseName: json['releaseName'] ?? '',
    sizeBytes: json['sizeBytes'] ?? 0,
    installedAt: DateTime.tryParse(json['installedAt'] ?? '') ?? DateTime.now(),
  );
}

/// Manages the local record of apps installed through AppRunner.
/// Persists data using SharedPreferences as a JSON string list.
class InstalledAppsService {
  static const _storageKey = 'installed_apps';

  /// Get all installed app records, sorted by most recent first.
  static Future<List<InstalledApp>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    final apps = jsonList
        .map((e) => InstalledApp.fromJson(e as Map<String, dynamic>))
        .toList();

    // Sort by install date, newest first
    apps.sort((a, b) => b.installedAt.compareTo(a.installedAt));
    return apps;
  }

  /// Record a new app installation.
  /// If the same app (same repo + apk name) was installed before, update it.
  static Future<void> recordInstall({
    required String apkName,
    required String repoFullName,
    required String tagName,
    required String releaseName,
    required int sizeBytes,
  }) async {
    final apps = await getAll();

    // Remove existing record for same app from same repo (update scenario)
    apps.removeWhere(
      (a) => a.repoFullName == repoFullName && a.name == apkName,
    );

    // Add new record
    apps.insert(0, InstalledApp(
      name: apkName,
      repoFullName: repoFullName,
      tagName: tagName,
      releaseName: releaseName,
      sizeBytes: sizeBytes,
      installedAt: DateTime.now(),
    ));

    await _save(apps);
  }

  /// Remove an installed app record.
  static Future<void> remove(String repoFullName, String apkName) async {
    final apps = await getAll();
    apps.removeWhere(
      (a) => a.repoFullName == repoFullName && a.name == apkName,
    );
    await _save(apps);
  }

  /// Get count of installed apps.
  static Future<int> getCount() async {
    final apps = await getAll();
    return apps.length;
  }

  /// Persist the apps list to SharedPreferences.
  static Future<void> _save(List<InstalledApp> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(apps.map((a) => a.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }
}
