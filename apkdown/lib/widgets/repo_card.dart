import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create_release_dialog.dart';

/// A visually rich card displaying a GitHub repository.
class RepoCard extends StatelessWidget {
  final Map<String, dynamic> repo;
  final VoidCallback onTap;

  const RepoCard({super.key, required this.repo, required this.onTap});

  /// Map of GitHub language names to their brand colors.
  static const Map<String, Color> _languageColors = {
    'Dart': Color(0xFF00B4AB),
    'JavaScript': Color(0xFFF1E05A),
    'TypeScript': Color(0xFF3178C6),
    'Python': Color(0xFF3572A5),
    'Java': Color(0xFFB07219),
    'Kotlin': Color(0xFFA97BFF),
    'Swift': Color(0xFFFF7F50),
    'C++': Color(0xFFF34B7D),
    'C#': Color(0xFF178600),
    'Go': Color(0xFF00ADD8),
    'Rust': Color(0xFFDEA584),
    'Ruby': Color(0xFF701516),
    'PHP': Color(0xFF4F5D95),
    'HTML': Color(0xFFE34C26),
    'CSS': Color(0xFF563D7C),
    'Shell': Color(0xFF89E051),
    'C': Color(0xFF555555),
  };

  Color _getLanguageColor(String? language) {
    if (language == null) return Colors.grey;
    return _languageColors[language] ?? const Color(0xFF8B8B8B);
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr);
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
    final name = repo['name'] ?? 'Unnamed';
    final description = repo['description'] as String?;
    final language = repo['language'] as String?;
    final stars = repo['stargazers_count'] ?? 0;
    final forks = repo['forks_count'] ?? 0;
    final isPrivate = repo['private'] ?? false;
    final updatedAt = repo['updated_at'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              // ── Repo name + visibility badge ──
              Row(
                children: [
                  Icon(
                    isPrivate ? Icons.lock_outline : Icons.book_outlined,
                    color: const Color(0xFF8B949E),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.vt323(
                        color: const Color(0xFF2EA043),
                        fontSize: 20,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF30363D),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isPrivate ? 'Private' : 'Public',
                      style: GoogleFonts.vt323(
                        color: const Color(0xFF8B949E),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.rocket_launch, color: Color(0xFF2EA043), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Create Release',
                    onPressed: () async {
                      final owner = repo['owner'] != null ? repo['owner']['login'] : '';
                      final success = await showDialog<bool>(
                        context: context,
                        builder: (context) => CreateReleaseDialog(
                          owner: owner ?? '',
                          repoName: name,
                        ),
                      );
                      if (success == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Release created successfully!')),
                        );
                      }
                    },
                  ),
                ],
              ),

              // ── Description ──
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.vt323(
                        color: const Color(0xFF8B949E),
                        fontSize: 16,
                        height: 1.3,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // ── Language, stars, forks, updated ──
              Row(
                children: [
                  if (language != null) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getLanguageColor(language),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      language,
                      style: GoogleFonts.vt323(
                        color: const Color(0xFF8B949E),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (stars > 0) ...[
                    const Icon(
                      Icons.star_outline,
                      color: Color(0xFF8B949E),
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$stars',
                      style: GoogleFonts.vt323(
                        color: const Color(0xFF8B949E),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (forks > 0) ...[
                    const Icon(
                      Icons.call_split,
                      color: Color(0xFF8B949E),
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$forks',
                      style: GoogleFonts.vt323(
                        color: const Color(0xFF8B949E),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  const Spacer(),
                  Text(
                    _timeAgo(updatedAt),
                    style: GoogleFonts.vt323(
                      color: const Color(0xFF8B949E),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
