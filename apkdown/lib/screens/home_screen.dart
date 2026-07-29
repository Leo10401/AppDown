import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/repo_card.dart';
import 'login_screen.dart';
import 'repo_detail_screen.dart';
import 'my_apps_screen.dart';

/// Home screen showing user info and repository list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _user;
  List<dynamic> _repos = [];
  bool _isLoading = true;
  String? _error;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getMe(),
        ApiService.getRepositories(),
      ]);
      if (mounted) {
        setState(() {
          _user = results[0] as Map<String, dynamic>;
          _repos = results[1] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await ApiService.logout();
    } catch (_) {
      // Even if backend call fails, clear local token
      await AuthService.deleteToken();
    }
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = _user?['user'];

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: _selectedIndex == 0
            ? Row(
                children: [
                  if (userData != null && userData['avatarUrl'] != null)
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(userData['avatarUrl']),
                      backgroundColor: const Color(0xFF30363D),
                    ),
                  if (userData != null && userData['avatarUrl'] != null)
                    const SizedBox(width: 10),
                  Text(
                    'GitDown',
                    style: GoogleFonts.vt323(
                      color: const Color(0xFF2EA043),
                      fontSize: 24,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              )
            : Text(
                'My Installed Apps',
                style: GoogleFonts.vt323(
                  color: const Color(0xFF2EA043),
                  fontSize: 24,
                  letterSpacing: 1.5,
                ),
              ),
        actions: [
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF8B949E)),
            tooltip: 'Logout',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFF30363D),
            height: 1,
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildBody(),
          const MyAppsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF161B22),
        selectedItemColor: const Color(0xFFF78166),
        unselectedItemColor: const Color(0xFF8B949E),
        selectedLabelStyle: GoogleFonts.vt323(fontSize: 16),
        unselectedLabelStyle: GoogleFonts.vt323(fontSize: 16),
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dns_rounded),
            label: 'Repositories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.android_rounded),
            label: 'My Apps',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildShimmerList();
    if (_error != null) return _buildError();
    if (_repos.isEmpty) return _buildEmpty();
    return _buildRepoList();
  }

  Widget _buildRepoList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF2EA043),
      backgroundColor: const Color(0xFF161B22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search Bar Dummy ──
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF8B949E), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Find a repository...',
                    style: GoogleFonts.vt323(
                      color: const Color(0xFF8B949E),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Repositories',
                  style: GoogleFonts.vt323(
                    color: Colors.white,
                    fontSize: 22,
                    letterSpacing: 1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2EA043),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'New',
                        style: GoogleFonts.vt323(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _repos.length,
              itemBuilder: (context, index) {
                final repo = _repos[index];
                return RepoCard(
                  repo: repo,
                  onTap: () {
                    final fullName = repo['full_name'] ?? '';
                    final parts = fullName.split('/');
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF21262D),
      highlightColor: const Color(0xFF30363D),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFF85149),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.inter(
                color: const Color(0xFFC9D1D9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF8B949E),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF21262D),
                foregroundColor: const Color(0xFF58A6FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inbox_outlined,
            color: Color(0xFF484F58),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No repositories found',
            style: GoogleFonts.inter(
              color: const Color(0xFF8B949E),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
