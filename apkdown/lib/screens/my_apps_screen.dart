import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/installed_apps_service.dart';
import '../services/download_service.dart';
import 'repo_detail_screen.dart';

class MyAppsScreen extends StatefulWidget {
  const MyAppsScreen({super.key});

  @override
  State<MyAppsScreen> createState() => _MyAppsScreenState();
}

class _MyAppsScreenState extends State<MyAppsScreen> {
  List<InstalledApp> _installedApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final apps = await InstalledAppsService.getAll();
    if (mounted) {
      setState(() {
        _installedApps = apps;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeApp(InstalledApp app) async {
    await InstalledAppsService.remove(app.repoFullName, app.name);
    _loadApps();
  }

  String _timeAgo(DateTime date) {
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
      );
    }

    if (_installedApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.install_mobile, color: Color(0xFF484F58), size: 64),
            const SizedBox(height: 16),
            Text(
              'No apps installed yet',
              style: GoogleFonts.vt323(
                color: const Color(0xFFC9D1D9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Install apps from GitHub releases\nto see them here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.vt323(
                color: const Color(0xFF8B949E),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApps,
      color: const Color(0xFF58A6FF),
      backgroundColor: const Color(0xFF161B22),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _installedApps.length,
        itemBuilder: (context, index) {
          final app = _installedApps[index];
          return _buildAppCard(app);
        },
      ),
    );
  }

  Widget _buildAppCard(InstalledApp app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF238636).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.android,
                    color: Color(0xFF3FB950),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: GoogleFonts.vt323(
                          color: const Color(0xFFC9D1D9),
                          fontSize: 20,
                          letterSpacing: 1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.repoFullName,
                        style: GoogleFonts.vt323(
                          color: const Color(0xFF8B949E),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFF85149)),
                  onPressed: () => _showDeleteDialog(app),
                  tooltip: 'Remove record',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFF30363D)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Release',
                      style: GoogleFonts.vt323(
                        color: const Color(0xFF8B949E),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.tagName.isNotEmpty ? app.tagName : 'Latest',
                      style: GoogleFonts.vt323(
                        color: const Color(0xFF58A6FF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Installed',
                      style: GoogleFonts.vt323(
                        color: const Color(0xFF8B949E),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _timeAgo(app.installedAt),
                      style: GoogleFonts.vt323(
                        color: const Color(0xFFC9D1D9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openRepo(app.repoFullName),
                icon: const Icon(Icons.update, size: 18),
                label: Text('Check for Updates', style: GoogleFonts.vt323(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2EA043),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(InstalledApp app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          'Remove record?',
          style: GoogleFonts.vt323(color: Colors.white),
        ),
        content: Text(
          'This will only remove the install record from this list. It will not uninstall the app from your device.',
          style: GoogleFonts.vt323(color: const Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.vt323(color: const Color(0xFF8B949E))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _removeApp(app);
            },
            child: Text('Remove', style: GoogleFonts.vt323(color: const Color(0xFFF85149))),
          ),
        ],
      ),
    );
  }

  void _openRepo(String repoFullName) {
    final parts = repoFullName.split('/');
    if (parts.length == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RepoDetailScreen(
            owner: parts[0],
            repo: parts[1],
          ),
        ),
      );
    }
  }
}
