import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

/// Handles APK downloading with progress tracking and installation.
class DownloadService {
  static final Dio _dio = Dio();

  /// Get (or create) the APK download directory inside the app's cache.
  static Future<Directory> _getApkDir() async {
    final cacheDir = await getTemporaryDirectory();
    final apkDir = Directory('${cacheDir.path}/apks');
    if (!await apkDir.exists()) {
      await apkDir.create(recursive: true);
    }
    return apkDir;
  }

  /// Download an APK file from [url] with progress reporting.
  ///
  /// [url] — The direct download URL (GitHub release asset URL).
  /// [filename] — The filename to save as (e.g., "app-release.apk").
  /// [onProgress] — Callback with (receivedBytes, totalBytes).
  /// [authToken] — Optional Bearer token for authenticated downloads.
  ///
  /// Returns the local file path of the downloaded APK.
  static Future<String> downloadApk({
    required String url,
    required String filename,
    required void Function(int received, int total) onProgress,
    String? authToken,
  }) async {
    final apkDir = await _getApkDir();
    final filePath = '${apkDir.path}/$filename';

    // Delete existing file if re-downloading
    final existing = File(filePath);
    if (await existing.exists()) {
      await existing.delete();
    }

    await _dio.download(
      url,
      filePath,
      options: Options(
        followRedirects: true,
        maxRedirects: 5,
      ),
      onReceiveProgress: (received, total) {
        onProgress(received, total);
      },
    );

    return filePath;
  }

  /// Open a downloaded APK to trigger the Android package installer.
  ///
  /// Returns the result of the open operation.
  static Future<OpenResult> installApk(String filePath) async {
    // Request install permission on Android 8+ (API 26+)
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        return OpenResult(
          type: ResultType.error,
          message: 'Install permission denied',
        );
      }
    }

    return await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
  }

  /// Clean up all cached APK files.
  static Future<void> clearCache() async {
    final apkDir = await _getApkDir();
    if (await apkDir.exists()) {
      await apkDir.delete(recursive: true);
    }
  }

  /// Format bytes into a human-readable string (e.g., "12.5 MB").
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
