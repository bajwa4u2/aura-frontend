import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Map<String, dynamic>? _payload; // {ok,data} or {claims,...}
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
        _error = 'Paste text to review.';
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

      final m = _asMap(out);

      if (!mounted) return;
      setState(() {
        _payload = m;
      });
    } catch (e) {
      if (!mounted) return;
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
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return <String, dynamic>{'raw': v?.toString()};
  }

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final d = payload['data'];
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return d.map((k, val) => MapEntry(k.toString(), val));
    return payload; // already looks like {claims: ...}
  }

  @override
  Widget build(BuildContext context) {
    final input = _ctl.text.trim();
    final payload = _payload;
    final data = payload == null ? null : _data(payload);

    return AuraScaffold(
      title: 'Aura Editor',
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
                Text('Aura Editor', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'A calm editorial review for clarity, responsibility, and civic impact.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s14),
                TextField(
                  controller: _ctl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Draft to review',
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
                      child: Text(_busy ? 'Reviewing…' : 'Review with Aura Editor'),
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
                  Text('Note', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(_error!, style: AuraText.body),
                ],
              ),
            ),
          if (data != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraCard(
              child: _AuraEditorReport(
                inputText: input,
                data: data,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuraEditorReport extends StatelessWidget {
  const _AuraEditorReport({
    required this.inputText,
    required this.data,
  });

  final String inputText;
  final Map<String, dynamic> data;

  bool get _looksLikeQuestion {
    final t = inputText.trim();
    if (t.isEmpty) return false;
    if (t.endsWith('?')) return true;

    final lower = t.toLowerCase();
    const starters = ['who', 'what', 'where', 'when', 'why', 'how', 'is ', 'are ', 'do ', 'does '];
    for (final s in starters) {
      if (lower.startsWith(s)) return true;
    }
    return false;
  }

  List<Map<String, dynamic>> _claims() {
    final c = data['claims'];
    if (c is! List) return const [];
    return c.map((e) {
      if (e is Map<String, dynamic>) return e;
      if (e is Map) return e.map((k, v) => MapEntry(k.toString(), v));
      return <String, dynamic>{'text': e.toString()};
    }).toList();
  }

  List<dynamic> _listAny(String key) {
    final v = data[key];
    return v is List ? v : const [];
  }

  List<String> _topSuggestions({
    required bool hasClaims,
    required bool hasClarityIssues,
    required bool hasToneFlags,
    required bool isQuestion,
  }) {
    final out = <String>[];

    if (isQuestion) {
      out.add('If you are asking readers for help, add a little context (location, timeframe, or why you’re asking).');
      return out.take(3).toList();
    }

    if (hasClaims) {
      out.add('If this is intended as a factual claim, add a source or a brief context line to support it.');
    } else {
      out.add('If you want readers to respond thoughtfully, make your intent explicit in one clear sentence.');
    }

    if (hasClarityIssues) {
      out.add('Clarify the key term or reference that a new reader may not understand.');
    }

    if (hasToneFlags) {
      out.add('Consider softening the wording so the point lands without sounding accusatory.');
    }

    // Keep it limited.
    return out.where((s) => s.trim().isNotEmpty).take(3).toList();
  }

  String _whatItIsDoing({
    required bool hasClaims,
    required bool isQuestion,
  }) {
    if (isQuestion) return 'This reads as an informational question.';
    if (hasClaims) return 'This reads as a statement that includes factual claims.';
    return 'This reads as an opinion or a general statement.';
  }

  String _civicAwareness({
    required bool hasToneFlags,
    required bool hasClaims,
    required bool isQuestion,
  }) {
    if (isQuestion) return 'No civic concerns detected.';
    if (hasToneFlags) {
      return 'This may be read as charged or targeting. A small shift toward neutral wording can reduce harm and misunderstanding.';
    }
    if (hasClaims) {
      return 'If this touches public institutions, communities, or real-world events, context and sources help protect trust.';
    }
    return 'No civic concerns detected.';
  }

  @override
  Widget build(BuildContext context) {
    final claims = _claims();
    final assumptions = _listAny('assumptions');
    final clarity = _listAny('clarity_issues');
    final tone = _listAny('tone_flags');

    final hasClaims = claims.isNotEmpty;
    final hasClarity = clarity.isNotEmpty;
    final hasTone = tone.isNotEmpty;
    final isQuestion = _looksLikeQuestion;

    final what = _whatItIsDoing(hasClaims: hasClaims, isQuestion: isQuestion);

    final consider = <String>[
      if (hasClaims) 'Readers may interpret this as a factual assertion. If so, it benefits from evidence or context.',
      if (hasClarity) 'Some wording may be unclear to a reader who doesn’t know the background.',
      if (assumptions.isNotEmpty) 'There may be implicit assumptions. Making them explicit can improve fairness and clarity.',
      if (!hasClaims && !hasClarity && !isQuestion) 'If your goal is persuasion, add one concrete example to anchor the point.',
    ].where((s) => s.trim().isNotEmpty).take(3).toList();

    final suggestions = _topSuggestions(
      hasClaims: hasClaims,
      hasClarityIssues: hasClarity,
      hasToneFlags: hasTone,
      isQuestion: isQuestion,
    );

    final civic = _civicAwareness(
      hasToneFlags: hasTone,
      hasClaims: hasClaims,
      isQuestion: isQuestion,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aura Editor review', style: AuraText.title),
        const SizedBox(height: AuraSpace.s10),

        Text('What this piece is doing', style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(what, style: AuraText.body),

        const SizedBox(height: AuraSpace.s14),

        Text('Things to consider', style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (consider.isEmpty)
          Text('No concerns detected.', style: AuraText.body)
        else
          ...consider.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $s', style: AuraText.body),
              )),

        const SizedBox(height: AuraSpace.s14),

        Text('Ways to strengthen it', style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (suggestions.isEmpty)
          Text('No changes suggested.', style: AuraText.body)
        else
          ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $s', style: AuraText.body),
              )),

        const SizedBox(height: AuraSpace.s14),

        Text('Civic awareness', style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(civic, style: AuraText.body),

        // Keep internal analysis invisible. But we can show a calm “details” section with claims only.
        if (hasClaims) ...[
          const SizedBox(height: AuraSpace.s14),
          Text('Claims detected', style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...claims.take(5).map((c) {
            final text = (c['text']?.toString() ?? '').trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• ${text.isEmpty ? '—' : text}', style: AuraText.body),
            );
          }),
        ],

        // Optional: if we ever add "suggested_refinement" from backend, we render it here.
        if (data['suggested_refinement'] != null) ...[
          const SizedBox(height: AuraSpace.s14),
          Text('Suggested refinement', style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _CopySuggestionBox(text: data['suggested_refinement'].toString()),
        ] else if (hasTone || hasClarity || hasClaims) ...[
          const SizedBox(height: AuraSpace.s14),
          Text('Suggested refinement', style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'A refined version will appear here once the backend returns a single editorial rewrite. For now, use the guidance above.',
            style: AuraText.body,
          ),
        ],
      ],
    );
  }
}

class _CopySuggestionBox extends StatelessWidget {
  const _CopySuggestionBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cleaned = text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AuraSpace.s12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(cleaned.isEmpty ? '—' : cleaned, style: AuraText.body),
        ),
        const SizedBox(height: AuraSpace.s10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: cleaned.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: cleaned));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Suggestion copied')),
                    );
                  },
            child: const Text('Copy suggestion'),
          ),
        ),
      ],
    );
  }
}
