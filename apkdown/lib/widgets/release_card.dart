import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import '../services/download_service.dart';
import '../services/api_service.dart';
import '../services/installed_apps_service.dart';

/// Download state for each APK asset.
enum ApkDownloadState { idle, downloading, ready, installing, error }

/// A premium card widget displaying a GitHub release with downloadable APK assets.
class ReleaseCard extends StatefulWidget {
  final Map<String, dynamic> release;
  final String repoFullName;

  const ReleaseCard({super.key, required this.release, required this.repoFullName});

  @override
  State<ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends State<ReleaseCard>
    with SingleTickerProviderStateMixin {
  bool _notesExpanded = false;

  // Track download state per asset index
  final Map<int, ApkDownloadState> _downloadStates = {};
  final Map<int, double> _downloadProgress = {};
  final Map<int, String> _downloadPaths = {};
  final Map<int, String> _errorMessages = {};

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  ApkDownloadState _getState(int index) =>
      _downloadStates[index] ?? ApkDownloadState.idle;

  double _getProgress(int index) => _downloadProgress[index] ?? 0.0;

  /// Filter assets to only show APK files.
  List<Map<String, dynamic>> get _apkAssets {
    final assets = (widget.release['assets'] as List<dynamic>?) ?? [];
    return assets
        .cast<Map<String, dynamic>>()
        .where((a) {
          final name = (a['name'] ?? '').toString().toLowerCase();
          return name.endsWith('.apk');
        })
        .toList();
  }

  Future<void> _downloadApk(Map<String, dynamic> asset, int index) async {
    if (_getState(index) == ApkDownloadState.downloading) return;

    setState(() {
      _downloadStates[index] = ApkDownloadState.downloading;
      _downloadProgress[index] = 0.0;
      _errorMessages.remove(index);
    });

    try {
      // Get the secure AWS S3 download URL from our backend to support private repos
      final parts = widget.repoFullName.split('/');
      final assetId = asset['id'] as int;
      final url = await ApiService.getAssetDownloadUrl(parts[0], parts[1], assetId);
      final filename = asset['name'] ?? 'app.apk';

      final filePath = await DownloadService.downloadApk(
        url: url,
        filename: filename,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress[index] =
                  total > 0 ? received / total : 0.0;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _downloadStates[index] = ApkDownloadState.ready;
          _downloadPaths[index] = filePath;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadStates[index] = ApkDownloadState.error;
          _errorMessages[index] = e.toString();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFF85149),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _installApk(int index) async {
    final path = _downloadPaths[index];
    if (path == null) return;

    setState(() {
      _downloadStates[index] = ApkDownloadState.installing;
    });

    try {
      final result = await DownloadService.installApk(path);
      if (mounted) {
        if (result.type == ResultType.done) {
          // Record successful installation
          final asset = _apkAssets[index];
          final filename = asset['name'] ?? 'unknown.apk';
          final size = asset['size'] as int? ?? 0;
          final releaseName = widget.release['name'] ?? widget.release['tag_name'] ?? 'Release';
          final tagName = widget.release['tag_name'] ?? '';

          await InstalledAppsService.recordInstall(
            apkName: filename,
            repoFullName: widget.repoFullName,
            tagName: tagName,
            releaseName: releaseName,
            sizeBytes: size,
          );

          setState(() {
            _downloadStates[index] = ApkDownloadState.idle;
          });
        } else {
          setState(() {
            _downloadStates[index] = ApkDownloadState.ready;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadStates[index] = ApkDownloadState.error;
          _errorMessages[index] = e.toString();
        });
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.release['name'] ?? widget.release['tag_name'] ?? 'Release';
    final tagName = widget.release['tag_name'] ?? '';
    final body = widget.release['body'] as String?;
    final publishedAt = widget.release['published_at'] as String?;
    final isPrerelease = widget.release['prerelease'] == true;
    final apkAssets = _apkAssets;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrerelease
              ? const Color(0xFFD29922).withValues(alpha: 0.4)
              : const Color(0xFF30363D),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Tag badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF238636), Color(0xFF2EA043)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sell_outlined,
                              color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            tagName,
                            style: GoogleFonts.vt323(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPrerelease) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFD29922), width: 1),
                        ),
                        child: Text(
                          'Pre-release',
                          style: GoogleFonts.vt323(
                            color: const Color(0xFFD29922),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatDate(publishedAt),
                      style: GoogleFonts.vt323(
                        color: const Color(0xFF484F58),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: GoogleFonts.vt323(
                    color: const Color(0xFFC9D1D9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                // ── Release notes ──
                if (body != null && body.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _notesExpanded = !_notesExpanded),
                    child: Row(
                      children: [
                        Icon(
                          _notesExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: const Color(0xFF58A6FF),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _notesExpanded ? 'Hide notes' : 'Show release notes',
                          style: GoogleFonts.vt323(
                            color: const Color(0xFF58A6FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_notesExpanded) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: const Color(0xFF21262D)),
                      ),
                      child: Text(
                        body.trim(),
                        style: GoogleFonts.vt323(
                          color: const Color(0xFF8B949E),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          // ── APK Assets ──
          if (apkAssets.isNotEmpty) ...[
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0xFF21262D),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.android,
                            color: Color(0xFF3FB950), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'APK Downloads',
                          style: GoogleFonts.vt323(
                            color: const Color(0xFF8B949E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...apkAssets.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final asset = entry.value;
                    return _buildApkRow(asset, idx);
                  }),
                ],
              ),
            ),
          ],

          // ── No APK assets ──
          if (apkAssets.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF484F58), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'No APK assets in this release',
                    style: GoogleFonts.vt323(
                      color: const Color(0xFF484F58),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApkRow(Map<String, dynamic> asset, int index) {
    final filename = asset['name'] ?? 'unknown.apk';
    final size = asset['size'] as int? ?? 0;
    final state = _getState(index);
    final progress = _getProgress(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        children: [
          // APK icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF238636).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.android,
              color: Color(0xFF3FB950),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Filename + size
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: GoogleFonts.vt323(
                    color: const Color(0xFFC9D1D9),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DownloadService.formatFileSize(size),
                  style: GoogleFonts.vt323(
                    color: const Color(0xFF484F58),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Action button / progress
          _buildActionWidget(index, state, progress),
        ],
      ),
    );
  }

  Widget _buildActionWidget(int index, ApkDownloadState state, double progress) {
    switch (state) {
      case ApkDownloadState.idle:
        return _actionButton(
          icon: Icons.download_rounded,
          color: const Color(0xFF58A6FF),
          onTap: () {
            final assets = _apkAssets;
            if (index < assets.length) {
              _downloadApk(assets[index], index);
            }
          },
        );

      case ApkDownloadState.downloading:
        return SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 2.5,
                backgroundColor: const Color(0xFF21262D),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF58A6FF)),
              ),
              Text(
                progress > 0 ? '${(progress * 100).toInt()}' : '...',
                style: GoogleFonts.vt323(
                  color: const Color(0xFF58A6FF),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

      case ApkDownloadState.ready:
        return _actionButton(
          icon: Icons.install_mobile,
          color: const Color(0xFF3FB950),
          onTap: () => _installApk(index),
        );

      case ApkDownloadState.installing:
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Opacity(
              opacity: 0.5 + (_pulseController.value * 0.5),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.install_mobile,
                  color: Color(0xFF3FB950),
                  size: 22,
                ),
              ),
            );
          },
        );

      case ApkDownloadState.error:
        return _actionButton(
          icon: Icons.refresh,
          color: const Color(0xFFF85149),
          onTap: () {
            final assets = _apkAssets;
            if (index < assets.length) {
              _downloadApk(assets[index], index);
            }
          },
        );
    }
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
