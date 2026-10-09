import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// HOW EACH KIND OF INSTITUTION IS COMPOSED (DD-42 phase 3, 2026-10-09).
///
/// Served by the server (`GET /institution-kinds`) so wording ships without a
/// store release; this file carries the same catalogue for when the server
/// cannot be reached. The kind decides words and emphasis — never authority.
class KindGuard {
  const KindGuard(this.key, this.text);
  final String key;
  final String text;
}

class KindComposition {
  const KindComposition({
    required this.kind,
    required this.publicWord,
    required this.unitSingular,
    required this.unitPlural,
    required this.todayOrder,
    this.lead = const [],
    this.recede = const [],
    this.guards = const [],
  });

  /// InstitutionCategory wire value, or '' for the neutral composition.
  final String kind;

  /// The public it serves, as a plural noun inside a sentence.
  final String publicWord;
  final String unitSingular;
  final String unitPlural;

  /// Today's blocks after "verification" and "waiting": 'public',
  /// 'meetings', 'announcement'.
  final List<String> todayOrder;

  /// Workspace tools that lead or recede within their section.
  final List<String> lead;
  final List<String> recede;
  final List<KindGuard> guards;

  /// "Residents", "Families and students", "The congregation".
  String get publicWordCapitalized =>
      publicWord.isEmpty ? publicWord : publicWord[0].toUpperCase() + publicWord.substring(1);

  factory KindComposition.fromJson(Map<String, dynamic> j) {
    List<String> list(dynamic v) => v is List ? [for (final e in v) '$e'] : const [];
    final unit = j['unit'] is Map ? Map<String, dynamic>.from(j['unit'] as Map) : const <String, dynamic>{};
    return KindComposition(
      kind: '${j['kind'] ?? ''}',
      publicWord: '${j['publicWord'] ?? 'the public'}',
      unitSingular: '${unit['singular'] ?? 'Unit'}',
      unitPlural: '${unit['plural'] ?? 'Units'}',
      todayOrder: list(j['todayOrder']).isEmpty ? const ['public', 'meetings', 'announcement'] : list(j['todayOrder']),
      lead: list(j['lead']),
      recede: list(j['recede']),
      guards: [
        if (j['guards'] is List)
          for (final g in (j['guards'] as List).whereType<Map>()) KindGuard('${g['key'] ?? ''}', '${g['text'] ?? ''}'),
      ],
    );
  }

  /// No kind known: plain words, no emphasis, no guards.
  static const neutral = KindComposition(
    kind: '',
    publicWord: 'the public',
    unitSingular: 'Unit',
    unitPlural: 'Units',
    todayOrder: ['public', 'meetings', 'announcement'],
  );
}

/// The catalogue as shipped. Mirrors the server's `KIND_CATALOGUE`; the
/// server's copy wins whenever it can be reached.
const kBundledKindCatalogue = <String, KindComposition>{
  'GOVERNMENT_CIVIC': KindComposition(
    kind: 'GOVERNMENT_CIVIC',
    publicWord: 'residents',
    unitSingular: 'Department',
    unitPlural: 'Departments',
    todayOrder: ['public', 'announcement', 'meetings'],
    lead: ['questions', 'announcements', 'meetings', 'booking'],
    recede: ['live'],
    guards: [
      KindGuard(
        'official_speech',
        'You are writing as the institution. This is official speech and stays on the public record; '
            'keep personal views to your own account.',
      ),
    ],
  ),
  'EDUCATIONAL': KindComposition(
    kind: 'EDUCATIONAL',
    publicWord: 'families and students',
    unitSingular: 'Campus',
    unitPlural: 'Campuses',
    todayOrder: ['announcement', 'public', 'meetings'],
    lead: ['announcements', 'spaces', 'meetings', 'booking'],
    recede: ['live'],
    guards: [
      KindGuard('minors', 'Students may read this. Never name or picture a student without their family’s consent.'),
    ],
  ),
  'NONPROFIT_COMMUNITY': KindComposition(
    kind: 'NONPROFIT_COMMUNITY',
    publicWord: 'members and supporters',
    unitSingular: 'Chapter',
    unitPlural: 'Chapters',
    todayOrder: ['public', 'meetings', 'announcement'],
    lead: ['spaces', 'meetings', 'announcements', 'members'],
  ),
  'RELIGIOUS': KindComposition(
    kind: 'RELIGIOUS',
    publicWord: 'the congregation',
    unitSingular: 'Branch',
    unitPlural: 'Branches',
    todayOrder: ['announcement', 'public', 'meetings'],
    lead: ['announcements', 'spaces', 'live', 'meetings'],
    recede: ['booking'],
  ),
  'CORPORATE_BUSINESS': KindComposition(
    kind: 'CORPORATE_BUSINESS',
    publicWord: 'customers',
    unitSingular: 'Branch',
    unitPlural: 'Branches',
    todayOrder: ['public', 'meetings', 'announcement'],
    lead: ['questions', 'booking', 'explore'],
    recede: ['live'],
  ),
  'MEDIA': KindComposition(
    kind: 'MEDIA',
    publicWord: 'readers and viewers',
    unitSingular: 'Desk',
    unitPlural: 'Desks',
    todayOrder: ['public', 'announcement', 'meetings'],
    lead: ['explore', 'questions', 'live'],
    recede: ['booking'],
    guards: [KindGuard('corrections_on_record', 'Corrections stay on the record: say what changed and why.')],
  ),
  'HEALTHCARE': KindComposition(
    kind: 'HEALTHCARE',
    publicWord: 'patients and the public',
    unitSingular: 'Site',
    unitPlural: 'Sites',
    todayOrder: ['announcement', 'public', 'meetings'],
    lead: ['announcements', 'booking', 'questions'],
    recede: ['live', 'spaces'],
    guards: [
      KindGuard(
        'no_health_information',
        'Never include anyone’s health information — a condition, an appointment or a result. '
            'Answer in general terms and invite them to contact you privately.',
      ),
    ],
  ),
};

/// The catalogue: the server's when reachable, else the bundled one.
final kindCatalogueProvider = FutureProvider<Map<String, KindComposition>>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get('/institution-kinds');
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : const <String, dynamic>{};
    final list = body['kinds'] is List ? body['kinds'] as List : const [];
    final out = <String, KindComposition>{
      for (final k in list.whereType<Map>())
        '${k['kind']}': KindComposition.fromJson(Map<String, dynamic>.from(k)),
    };
    return out.isEmpty ? kBundledKindCatalogue : out;
  } catch (_) {
    return kBundledKindCatalogue;
  }
});

/// The composition for one kind (wire value), without waiting: the server's
/// catalogue once loaded, the bundled one until then.
KindComposition compositionForKind(WidgetRef ref, String? kind) {
  final k = (kind ?? '').trim().toUpperCase();
  if (k.isEmpty) return KindComposition.neutral;
  final catalogue = ref.watch(kindCatalogueProvider).valueOrNull ?? kBundledKindCatalogue;
  return catalogue[k] ?? kBundledKindCatalogue[k] ?? KindComposition.neutral;
}

/// The composition for the institution at [address] (its id or slug), as far
/// as the signed-in person's own institution identity says. An institution
/// the identity does not describe gets the neutral composition.
KindComposition compositionForInstitution(WidgetRef ref, String address) {
  final idn = ref.watch(institutionIdentityProvider);
  final a = address.trim();
  final matches = idn != null && a.isNotEmpty && (idn.id == a || idn.slug == a || idn.workspaceAddress == a);
  return compositionForKind(ref, matches ? idn.kind : null);
}

/// The guards a kind writes under, shown where the institution speaks in its
/// own voice. Renders nothing when the kind has none.
class KindGuardNotice extends StatelessWidget {
  const KindGuardNotice({super.key, required this.composition});

  final KindComposition composition;

  @override
  Widget build(BuildContext context) {
    if (composition.guards.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.coSun.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AuraRadius.md),
        border: Border.all(color: AuraSurface.coSun.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final g in composition.guards)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: AuraSurface.coSun),
                  const SizedBox(width: AuraSpace.s8),
                  Expanded(child: Text(g.text, style: AuraText.small.copyWith(height: 1.45))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
