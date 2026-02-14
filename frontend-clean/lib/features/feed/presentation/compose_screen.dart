import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/auth/session_providers.dart';
import 'login_screen.dart';

enum ComposeKind { post, note }

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _text = TextEditingController();
  ComposeKind _kind = ComposeKind.post;

  bool _busy = false;
  bool _loadingDraft = false;
  String? _error;

  bool _authGateChecked = false;

  Timer? _debounce;
  DateTime? _lastSavedAt;
  String _lastSavedText = '';

  @override
  void initState() {
    super.initState();

    _text.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureAuthed();
      if (!mounted) return;
      if (ref.read(isAuthedProvider)) {
        await _loadDraft();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.removeListener(_onTextChanged);
    _text.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted) return;
      if (!ref.read(isAuthedProvider)) return;

      final t = _text.text.trim();
      if (t.isEmpty) return;
      if (t == _lastSavedText) return;

      await _saveDraft(quiet: true);
    });
  }

  Future<void> _ensureAuthed() async {
    if (!mounted) return;
    if (_authGateChecked) return;
    _authGateChecked = true;

    final authed = ref.read(isAuthedProvider);
    if (authed) return;

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (!mounted) return;

    if (ok == true) {
      ref.read(isAuthedProvider.notifier).state = true;
      return;
    }

    Navigator.of(context).maybePop();
  }

  String get _kindLabel => _kind == ComposeKind.note ? 'NOTE' : 'POST';
  String get _hintText => _kind == ComposeKind.note ? 'Write a note.' : 'Write a post.';

  Future<void> _loadDraft() async {
    setState(() {
      _loadingDraft = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/posts/draft');

      final draft = res.data is Map ? (res.data as Map)['draft'] : null;
      if (draft is Map) {
        final text = (draft['text'] ?? '').toString();
        final updatedAt = (draft['updatedAt'] ?? draft['updatedAt'] ?? '').toString();

        if (text.trim().isNotEmpty && mounted) {
          _text.text = text;
          _text.selection = TextSelection.collapsed(offset: _text.text.length);
          _lastSavedText = text.trim();

          // updatedAt may not be present depending on serializer; handle softly.
          final parsed = DateTime.tryParse(updatedAt);
          if (parsed != null) _lastSavedAt = parsed.toLocal();
        }
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        _authGateChecked = false;
        await _ensureAuthed();
      } else {
        setState(() => _error = 'Could not load draft (${status ?? 'no status'}).');
      }
    } catch (e) {
      setState(() => _error = 'Could not load draft. $e');
    } finally {
      if (mounted) setState(() => _loadingDraft = false);
    }
  }

  Future<void> _saveDraft({bool quiet = false}) async {
    if (!ref.read(isAuthedProvider)) {
      await _ensureAuthed();
      if (!mounted || !ref.read(isAuthedProvider)) return;
    }

    final t = _text.text.trim();
    if (t.isEmpty) {
      if (!quiet && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to save.')),
        );
      }
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.put('/posts/draft', data: {'text': t});

      // Server returns { draft }, but we only need confirmation.
      _lastSavedText = t;
      _lastSavedAt = DateTime.now();

      if (!quiet && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved.')),
        );
      }

      if (mounted) setState(() {});
      // ignore: unused_local_variable
      final _ = res.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(() {
        _error = status == 401 ? 'Not authorized. Please login again.' : 'Save failed (${status ?? 'no status'}).';
      });

      if (status == 401) {
        _authGateChecked = false;
        await _ensureAuthed();
      }
    } catch (e) {
      setState(() => _error = 'Save failed. $e');
    }
  }

  Future<void> _discardDraft({bool clearEditor = false}) async {
    if (!ref.read(isAuthedProvider)) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/posts/draft');

      _lastSavedAt = null;
      _lastSavedText = '';

      if (clearEditor) _text.clear();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft discarded.')),
        );
      }
    } catch (_) {
      // quiet by design
    }
  }

  Future<void> _publishDraft() async {
    if (!ref.read(isAuthedProvider)) {
      await _ensureAuthed();
      if (!mounted || !ref.read(isAuthedProvider)) return;
    }

    final t = _text.text.trim();
    if (t.isEmpty) {
      setState(() => _error = 'Write something first.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Ensure the current text is saved to the draft first (so publish always matches the editor).
      await _saveDraft(quiet: true);

      final dio = ref.read(dioProvider);

      // Publish the latest draft server-side
      final res = await dio.post('/posts/draft/publish');

      if (!mounted) return;

      _text.clear();
      _lastSavedAt = null;
      _lastSavedText = '';

      Navigator.of(context).maybePop(res.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final msg = e.response?.data;

      setState(() {
        _error = status == 401
            ? 'Not authorized. Please login again.'
            : 'Publish failed (${status ?? 'no status'}). ${msg is String ? msg : ''}'.trim();
      });

      if (status == 401) {
        _authGateChecked = false;
        await _ensureAuthed();
      }
    } catch (e) {
      setState(() => _error = 'Publish failed. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _savedLine() {
    if (_lastSavedAt == null) return 'Not saved yet.';
    final t = _lastSavedAt!;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return 'Saved at $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isAuthed = ref.watch(isAuthedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAuthed ? 'Compose' : 'Login required'),
        actions: [
          TextButton(
            onPressed: (_busy || _loadingDraft) ? null : () => _saveDraft(),
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: (_busy || _loadingDraft) ? null : _publishDraft,
            child: _busy
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Publish'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<ComposeKind>(
              segments: const [
                ButtonSegment(value: ComposeKind.post, label: Text('Post')),
                ButtonSegment(value: ComposeKind.note, label: Text('Note')),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 12),
            if (_loadingDraft) ...[
              const Text('Loading draft…', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
            ],
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
            ],
            Expanded(
              child: TextField(
                controller: _text,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: _hintText,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Type: $_kindLabel', style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                Text(_savedLine(), style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: (_busy || _loadingDraft) ? null : () => _discardDraft(clearEditor: true),
              child: const Text('Discard draft'),
            ),
          ],
        ),
      ),
    );
  }
}
