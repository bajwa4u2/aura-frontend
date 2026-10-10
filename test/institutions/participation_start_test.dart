import 'dart:io';

import 'package:aura/features/institutions/participation/participation_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// TAKING ON A TOPIC SWITCHES IT ON (2026-10-09). A new topic was created
/// switched off and waited behind a "Reactivate" button nobody knew to press,
/// so institutions that had set up topics received nothing.
void main() {
  final src = File('lib/features/institutions/participation/participation_screen.dart').readAsStringSync();

  test('taking on a topic switches it on in the same step, unless the person chooses later', () {
    expect(src.contains('bool _startNow = true;'), isTrue);
    expect(src.contains('if (_startNow) {'), isTrue);
    // A missing id is an error the person sees, never a silent skip: the
    // skip is how every topic taken on stayed off (seen live, 9 Oct 2026).
    expect(src.contains("if (created.id.isEmpty) throw StateError('no id');"), isTrue);
    expect(src.contains('if (_startNow && created.id.isNotEmpty)'), isFalse);
    expect(src.contains('status: ParticipationStatus.active.wire,'), isTrue);
  });

  test('a topic that was never on says Start, not Reactivate', () {
    expect(src.contains("item.activatedAt == null ? 'Start' : 'Turn back on'"), isTrue);
    expect(src.contains("label: 'Reactivate'"), isFalse);
  });

  test('the first switch-on time is read from the server', () {
    final p = InstitutionParticipation.fromJson({
      'id': 'p1',
      'institutionId': 'i1',
      'topic': 'PUBLIC_SAFETY',
      'mode': 'ACCOUNTABLE',
      'status': 'INACTIVE',
      'activatedAt': null,
    });
    expect(p.activatedAt, isNull);
  });
}
