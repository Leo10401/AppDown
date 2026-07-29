import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';
import '../widgets/release_card.dart';

/// Repository detail screen with tabs for Branches, Commits, Issues, and Releases.
class RepoDetailScreen extends StatefulWidget {
  final String owner;
  final String repo;

  const RepoDetailScreen({
    super.key,
    required this.owner,
    required this.repo,
  });

  @override
  State<RepoDetailScreen> createState() => _RepoDetailScreenState();
}

class _RepoDetailScreenState extends State<RepoDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic>? _branches;
  List<dynamic>? _commits;
  List<dynamic>? _issues;
  List<dynamic>? _releases;
  bool _loadingBranches = true;
  bool _loadingCommits = true;
  bool _loadingIssues = true;
  bool _loadingReleases = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    _loadBranches();
    _loadCommits();
    _loadIssues();
    _loadReleases();
  }

  Future<void> _loadBranches() async {
    try {
      final data = await ApiService.getBranches(widget.owner, widget.repo);
      if (mounted) setState(() { _branches = data; _loadingBranches = false; });
    } catch (_) {
      if (mounted) setState(() { _branches = []; _loadingBranches = false; });
    }
  }

  Future<void> _loadCommits() async {
    try {
      final data = await ApiService.getCommits(widget.owner, widget.repo);
      if (mounted) setState(() { _commits = data; _loadingCommits = false; });
    } catch (_) {
      if (mounted) setState(() { _commits = []; _loadingCommits = false; });
    }
  }

  Future<void> _loadIssues() async {
    try {
      final data = await ApiService.getIssues(widget.owner, widget.repo);
      if (mounted) setState(() { _issues = data; _loadingIssues = false; });
    } catch (_) {
      if (mounted) setState(() { _issues = []; _loadingIssues = false; });
    }
  }

  Future<void> _loadReleases() async {
    try {
      final data = await ApiService.getReleases(widget.owner, widget.repo);
      if (mounted) setState(() { _releases = data; _loadingReleases = false; });
    } catch (_) {
      if (mounted) setState(() { _releases = []; _loadingReleases = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF8B949E), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.code_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              'GitDown',
              style: GoogleFonts.vt323(
                color: const Color(0xFF2EA043),
                fontSize: 24,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: const Color(0xFFF78166),
                indicatorWeight: 2,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF8B949E),
                labelStyle: GoogleFonts.vt323(
                  fontSize: 18,
                  letterSpacing: 1,
                ),
                unselectedLabelStyle: GoogleFonts.vt323(
                  fontSize: 18,
                  letterSpacing: 1,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_tree_outlined, size: 15),
                        const SizedBox(width: 6),
                        const Text('Branches'),
                        if (_branches != null) ...[
                          const SizedBox(width: 6),
                          _badge('${_branches!.length}'),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 15),
                        const SizedBox(width: 6),
                        const Text('Commits'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle_outlined, size: 15),
                        const SizedBox(width: 6),
                        const Text('Issues'),
                        if (_issues != null) ...[
                          const SizedBox(width: 6),
                          _badge('${_issues!.length}'),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.new_releases_outlined, size: 15),
                        const SizedBox(width: 6),
                        const Text('Releases'),
                        if (_releases != null) ...[
                          const SizedBox(width: 6),
                          _badge('${_releases!.length}'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Container(color: const Color(0xFF30363D), height: 1),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBranchesTab(),
          _buildCommitsTab(),
          _buildIssuesTab(),
          _buildReleasesTab(),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF30363D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.vt323(fontSize: 14, color: Colors.white),
      ),
    );
  }

  // ── Branches Tab ──────────────────────────────────────────────────────────

  Widget _buildBranchesTab() {
    if (_loadingBranches) return _shimmerList();
    if (_branches == null || _branches!.isEmpty) return _emptyState('No branches found');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _branches!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final branch = _branches![index];
        final name = branch['name'] ?? 'unknown';
        final isDefault = branch['protected'] == true;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: Color(0xFF58A6FF), size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.vt323(
                    color: const Color(0xFFC9D1D9),
                    fontSize: 18,
                  ),
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Text(
                    'protected',
                    style: GoogleFonts.vt323(
                      color: const Color(0xFF8B949E),
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Commits Tab ───────────────────────────────────────────────────────────

  Widget _buildCommitsTab() {
    if (_loadingCommits) return _shimmerList();
    if (_commits == null || _commits!.isEmpty) return _emptyState('No commits found');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _commits!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final commit = _commits![index];
        final commitData = commit['commit'] ?? {};
        final message = commitData['message'] ?? 'No message';
        final author = commitData['author']?['name'] ?? 'Unknown';
        final date = commitData['author']?['date'] as String?;
        final sha = (commit['sha'] ?? '').toString();
        final shortSha = sha.length >= 7 ? sha.substring(0, 7) : sha;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.toString().split('\n').first,
                style: GoogleFonts.vt323(
                  color: const Color(0xFFC9D1D9),
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, color: Color(0xFF8B949E), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    author,
                    style: GoogleFonts.vt323(
                      color: const Color(0xFF8B949E),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      shortSha,
                      style: GoogleFonts.vt323(
                        color: const Color(0xFF58A6FF),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (date != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(date),
                      style: GoogleFonts.vt323(
                        color: const Color(0xFF484F58),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Issues Tab ────────────────────────────────────────────────────────────

  Widget _buildIssuesTab() {
    if (_loadingIssues) return _shimmerList();
    if (_issues == null || _issues!.isEmpty) return _emptyState('No issues found');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _issues!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final issue = _issues![index];
        final title = issue['title'] ?? 'Untitled';
        final number = issue['number'] ?? 0;
        final state = issue['state'] ?? 'open';
        final labels = (issue['labels'] as List<dynamic>?) ?? [];
        final createdAt = issue['created_at'] as String?;

        final isOpen = state == 'open';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isOpen ? Icons.circle_outlined : Icons.check_circle_outline,
                    color: isOpen ? const Color(0xFF3FB950) : const Color(0xFFA371F7),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.vt323(
                        color: const Color(0xFFC9D1D9),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              if (labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: labels.map<Widget>((label) {
                    final colorHex = label['color'] ?? '333333';
                    final color = Color(int.parse('FF$colorHex', radix: 16));
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        label['name'] ?? '',
                        style: GoogleFonts.vt323(
                          color: color,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '#$number opened ${createdAt != null ? _formatDate(createdAt) : ''}',
                style: GoogleFonts.vt323(
                  color: const Color(0xFF484F58),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Releases Tab ─────────────────────────────────────────────────────────

  Widget _buildReleasesTab() {
    if (_loadingReleases) return _shimmerList();
    if (_releases == null || _releases!.isEmpty) return _emptyState('No releases found');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _releases!.length,
      itemBuilder: (context, index) {
        final release = _releases![index] as Map<String, dynamic>;
        return ReleaseCard(
          release: release,
          repoFullName: '${widget.owner}/${widget.repo}',
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(String dateStr) {
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

  Widget _shimmerList() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF21262D),
      highlightColor: const Color(0xFF30363D),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, color: Color(0xFF484F58), size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.vt323(color: const Color(0xFF8B949E), fontSize: 16),
          ),
        ],
      ),
    );
  }
}
