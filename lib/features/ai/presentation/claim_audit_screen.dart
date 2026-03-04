import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../providers.dart';

class ClaimAuditScreen extends ConsumerStatefulWidget {
  const ClaimAuditScreen({super.key});

  @override
  ConsumerState<ClaimAuditScreen> createState() => _ClaimAuditScreenState();
}

class _ClaimAuditScreenState extends ConsumerState<ClaimAuditScreen> {
  final _ctl = TextEditingController();
  bool _busy = false;

  Map<String, dynamic>? _payload; // full response we got back (either {ok,data} or {claims...})
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) {
      setState(() {
        _error = 'Paste a claim or paragraph to audit.';
        _payload = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _payload = null;
    });

    try {
      final repo = ref.read(aiRepoProvider);
      final out = await repo.claimAudit(text: text);

      // Ensure we store a map for rendering (some repos might return dynamic).
      final m = _asMap(out);

      setState(() {
        _payload = m;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return <String, dynamic>{'raw': v?.toString()};
  }

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final d = payload['data'];
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return d.map((k, val) => MapEntry(k.toString(), val));
    return payload; // already looks like {claims: ...}
  }

  List<Map<String, dynamic>> _claims(Map<String, dynamic> data) {
    final c = data['claims'];
    if (c is List) {
      return c.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  List<String> _stringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    final data = payload == null ? null : _data(payload);

    return AuraScaffold(
      title: 'Claim audit',
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s12,
          AuraSpace.s16,
          AuraSpace.s24,
        ),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI claim audit (beta)', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'This tool checks whether your text contains claims that need evidence, definitions, or caution. It does not publish anything.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s14),
                TextField(
                  controller: _ctl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Text to audit',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _run,
                      child: Text(_busy ? 'Running…' : 'Run audit'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _ctl.clear();
                                _payload = null;
                                _error = null;
                              });
                            },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AuraSpace.s12),

          if (_error != null)
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Error', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(_error!, style: AuraText.body),
                ],
              ),
            ),

          if (data != null) ...[
            AuraCard(
              child: _ResultView(
                data: data,
                rawPayload: payload!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultView extends StatefulWidget {
  const _ResultView({
    required this.data,
    required this.rawPayload,
  });

  final Map<String, dynamic> data;
  final Map<String, dynamic> rawPayload;

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final claims = (data['claims'] is List)
        ? (data['claims'] as List).map((e) => e is Map ? e : {'text': e.toString()}).toList()
        : const [];

    final assumptions = (data['assumptions'] is List) ? data['assumptions'] as List : const [];
    final clarityIssues =
        (data['clarity_issues'] is List) ? data['clarity_issues'] as List : const [];
    final toneFlags = (data['tone_flags'] is List) ? data['tone_flags'] as List : const [];

    final meta = data['meta'] is Map ? data['meta'] as Map : null;
    final contextStr = meta?['context']?.toString();
    final modeStr = meta?['mode']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Result', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),

        if (contextStr != null || modeStr != null)
          Text(
            [
              if (contextStr != null && contextStr.trim().isNotEmpty) 'Context: $contextStr',
              if (modeStr != null && modeStr.trim().isNotEmpty) 'Mode: $modeStr',
            ].join(' • '),
            style: AuraText.meta,
          ),

        if (contextStr != null || modeStr != null) const SizedBox(height: AuraSpace.s10),

        Text(
          claims.isEmpty ? 'No clear claims detected.' : 'Claims found: ${claims.length}',
          style: AuraText.body,
        ),

        if (claims.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s10),
          ...claims.map((c) {
            final m = c is Map ? c : <String, dynamic>{'text': c.toString()};
            final text = m['text']?.toString().trim() ?? '';
            final type = m['type']?.toString().trim();
            final conf = m['confidence'];

            String confStr = '';
            if (conf is num) {
              confStr = '${(conf * 100).round()}%';
            } else if (conf != null) {
              confStr = conf.toString();
            }

            final tail = [
              if (type != null && type.isNotEmpty) type,
              if (confStr.isNotEmpty) confStr,
            ].join(' • ');

            return Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.s10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text.isEmpty ? '—' : text, style: AuraText.body),
                  if (tail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(tail, style: AuraText.meta),
                  ],
                ],
              ),
            );
          }),
        ],

        if (assumptions.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          Text('Assumptions', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          ...assumptions.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${e.toString()}', style: AuraText.body),
              )),
        ],

        if (clarityIssues.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          Text('Clarity issues', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          ...clarityIssues.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${e.toString()}', style: AuraText.body),
              )),
        ],

        if (toneFlags.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          Text('Tone flags', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          ...toneFlags.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${e.toString()}', style: AuraText.body),
              )),
        ],

        const SizedBox(height: AuraSpace.s12),

        OutlinedButton(
          onPressed: () => setState(() => _showRaw = !_showRaw),
          child: Text(_showRaw ? 'Hide raw' : 'Show raw'),
        ),

        if (_showRaw) ...[
          const SizedBox(height: AuraSpace.s10),
          Text(
            const JsonEncoder.withIndent('  ').convert(widget.rawPayload),
            style: AuraText.body,
          ),
        ],
      ],
    );
  }
}