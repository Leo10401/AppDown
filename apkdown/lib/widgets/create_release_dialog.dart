import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class CreateReleaseDialog extends StatefulWidget {
  final String owner;
  final String repoName;

  const CreateReleaseDialog({
    super.key,
    required this.owner,
    required this.repoName,
  });

  @override
  State<CreateReleaseDialog> createState() => _CreateReleaseDialogState();
}

class _CreateReleaseDialogState extends State<CreateReleaseDialog> {
  final _versionController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _versionController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final version = _versionController.text.trim();
    if (version.isEmpty) {
      setState(() => _error = 'Version tag is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ApiService.createRelease(
        widget.owner,
        widget.repoName,
        version,
        _bodyController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true); // Return true on success
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to create release. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF30363D), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch, color: Color(0xFF2EA043)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create Release',
                    style: GoogleFonts.vt323(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Trigger a new release for ${widget.repoName}.',
              style: GoogleFonts.vt323(
                color: const Color(0xFF8B949E),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _versionController,
              style: GoogleFonts.vt323(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Version Tag (e.g. v1.0.0)',
                labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              maxLines: 3,
              style: GoogleFonts.vt323(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Release Notes (optional)',
                labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: GoogleFonts.vt323(color: const Color(0xFFF85149), fontSize: 16),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.vt323(
                      color: const Color(0xFF8B949E),
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2EA043),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF2EA043).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Publish',
                          style: GoogleFonts.vt323(
                            fontSize: 18,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
