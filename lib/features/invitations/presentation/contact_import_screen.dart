import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/invitations_client.dart';

// Entry: { 'email': '...', 'name': '...' (optional) }
typedef _ContactEntry = Map<String, String?>;

class ContactImportScreen extends ConsumerStatefulWidget {
  const ContactImportScreen({super.key, this.spaceId, this.institutionId});

  final String? spaceId;
  final String? institutionId;

  @override
  ConsumerState<ContactImportScreen> createState() => _ContactImportScreenState();
}

enum _Step { input, preview, sending }

class _ContactImportScreenState extends ConsumerState<ContactImportScreen> {
  _Step _step = _Step.input;

  // Input state
  final _manualCtrl = TextEditingController();
  final _bulkCtrl = TextEditingController();
  String? _inputError;
  bool _csvLoading = false;

  // Preview state
  List<_ContactEntry> _parsed = [];
  final Set<int> _selected = {};

  // Sending state
  bool _sending = false;
  String? _sendError;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _manualCtrl.dispose();
    _bulkCtrl.dispose();
    super.dispose();
  }

  // ── Input helpers ────────────────────────────────────────────────

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  List<_ContactEntry> _parseRaw(String raw) {
    final lines = raw
        .split(RegExp(r'[\n,;]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final entries = <_ContactEntry>[];
    for (final line in lines) {
      // Attempt "Name <email>" or "email"
      final angleMatch = RegExp(r'^(.+)<([^>]+)>$').firstMatch(line);
      if (angleMatch != null) {
        final name = angleMatch.group(1)!.trim().replaceAll(RegExp(r'^"|"$'), '');
        final email = angleMatch.group(2)!.trim().toLowerCase();
        if (_emailRe.hasMatch(email)) {
          entries.add({'email': email, 'name': name.isEmpty ? null : name});
          continue;
        }
      }
      // Plain email
      final email = line.toLowerCase();
      if (_emailRe.hasMatch(email)) {
        entries.add({'email': email, 'name': null});
      }
    }
    return entries;
  }

  Future<void> _pickCsv() async {
    setState(() => _csvLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;
      final content = String.fromCharCodes(bytes);
      // Parse CSV lines — expect email[,name] or just email
      final entries = <_ContactEntry>[];
      for (final line in content.split('\n')) {
        final parts = line.split(',').map((p) => p.trim().replaceAll('"', '')).toList();
        if (parts.isEmpty) continue;
        final email = parts[0].toLowerCase();
        if (!_emailRe.hasMatch(email)) continue;
        final name = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
        entries.add({'email': email, 'name': name});
      }
      if (entries.isEmpty) {
        setState(() => _inputError = 'No valid emails found in the CSV file.');
        return;
      }
      _goToPreview(entries);
    } finally {
      if (mounted) setState(() => _csvLoading = false);
    }
  }

  void _goToPreview(List<_ContactEntry> entries) {
    // Deduplicate by email
    final seen = <String>{};
    final deduped = entries.where((e) {
      final email = (e['email'] ?? '').toLowerCase();
      return seen.add(email);
    }).toList();

    setState(() {
      _parsed = deduped;
      _selected
        ..clear()
        ..addAll(List.generate(deduped.length, (i) => i));
      _step = _Step.preview;
      _inputError = null;
    });
  }

  void _handleNext() {
    setState(() => _inputError = null);

    final manual = _manualCtrl.text.trim();
    final bulk = _bulkCtrl.text.trim();
    final combined = '$manual\n$bulk';
    final entries = _parseRaw(combined);
    if (entries.isEmpty) {
      setState(() => _inputError = 'Enter at least one valid email address.');
      return;
    }
    _goToPreview(entries);
  }

  // ── Send ─────────────────────────────────────────────────────────

  Future<void> _send() async {
    final selected = _selected.map((i) => _parsed[i]['email']!).toList();
    if (selected.isEmpty) {
      setState(() => _sendError = 'Select at least one contact.');
      return;
    }

    setState(() {
      _sending = true;
      _sendError = null;
    });

    try {
      final client = ref.read(invitationsClientProvider);

      // Save contacts to contact graph
      final toImport = _selected
          .map((i) => {'email': _parsed[i]['email']!, 'name': _parsed[i]['name']})
          .toList();
      await client.importContacts(toImport.cast<Map<String, String?>>());

      // Send batch
      final result = await client.sendBatch(
        emails: selected,
        spaceId: widget.spaceId,
        institutionId: widget.institutionId,
        platform: widget.spaceId == null && widget.institutionId == null,
      );

      setState(() {
        _result = result;
        _step = _Step.sending;
        _sending = false;
      });
    } catch (e) {
      setState(() {
        _sendError = 'Failed to send invitations. Please try again.';
        _sending = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import & Invite'),
        leading: _step == _Step.preview
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = _Step.input),
              )
            : null,
      ),
      body: switch (_step) {
        _Step.input => _buildInput(theme),
        _Step.preview => _buildPreview(theme),
        _Step.sending => _buildResult(theme),
      },
    );
  }

  Widget _buildInput(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Step 1 of 3 — Add contacts',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Enter email addresses manually, paste a list, or upload a CSV file.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _manualCtrl,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bulkCtrl,
            decoration: const InputDecoration(
              labelText: 'Paste multiple emails',
              hintText: 'Separate by comma, semicolon, or new line',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            keyboardType: TextInputType.multiline,
          ),
          if (_inputError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_inputError!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _handleNext,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Preview contacts'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _csvLoading ? null : _pickCsv,
            icon: _csvLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Upload CSV file'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step 2 of 3 — Review',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '${_selected.length} of ${_parsed.length} selected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _parsed.length,
            itemBuilder: (_, i) {
              final c = _parsed[i];
              return CheckboxListTile(
                value: _selected.contains(i),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(i);
                  } else {
                    _selected.remove(i);
                  }
                }),
                title: Text(c['email'] ?? ''),
                subtitle: c['name'] != null ? Text(c['name']!) : null,
                secondary: const Icon(Icons.person_outline),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              );
            },
          ),
        ),
        if (_sendError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_sendError!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: FilledButton.icon(
            onPressed: (_sending || _selected.isEmpty) ? null : _send,
            icon: _sending
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_outlined, size: 18),
            label: Text(_sending ? 'Sending...' : 'Send invitations'),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(ThemeData theme) {
    final sent = _result?['sent'] ?? 0;
    final failed = _result?['failed'] ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed == 0 ? Icons.check_circle_outline : Icons.info_outline,
              size: 64,
              color: failed == 0 ? Colors.green : theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              failed == 0 ? 'Invitations sent!' : 'Sent with some issues',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '$sent invitation${sent == 1 ? '' : 's'} sent successfully.'
              '${failed > 0 ? '\n$failed could not be delivered.' : ''}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
