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
  Map<String, dynamic>? _result;
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
        _result = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      final repo = ref.read(aiRepoProvider);
      final out = await repo.claimAudit(text: text);
      setState(() {
        _result = out;
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

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Claim audit',
      showHomeAction: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AuraSpace.s16, AuraSpace.s12, AuraSpace.s16, AuraSpace.s24),
        children: [
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI claim audit (beta)', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'This tool helps you test whether a statement is making a claim that needs evidence, definitions, or caution. It does not publish anything.',
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
                      child: _busy ? const Text('Running…') : const Text('Run audit'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _ctl.clear();
                                _result = null;
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
          if (_result != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Result', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(_pretty(_result!), style: AuraText.body),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _pretty(Map<String, dynamic> m) {
    // Simple stable pretty-print without adding a json dependency import.
    final lines = <String>[];
    void add(String k, dynamic v) {
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      lines.add('$k: $v');
    }

    // Try common keys
    add('risk', m['risk']);
    add('summary', m['summary']);
    add('notes', m['notes']);
    add('suggestions', m['suggestions']);
    add('raw', m['raw']);

    if (lines.isNotEmpty) return lines.join('\n');

    // Fallback
    return m.toString();
  }
}
