// THE SHARED SHELL IS ONE SHELL, COMPOSED BY WHERE IT STANDS.
//
// The founder asked whether the wordmark, search, attention, Live and account
// controls belong in Admin, and instructed that the answer be expressed by
// making the SHARED shell context-aware rather than by building a second one.
// The console was rendering the member strip verbatim: `/search` over public
// discourse, a Live pill that offers to leave, an "Add your institution"
// onboarding action, and a door to the console it was already inside.
//
// These are source-level assertions rather than a pumped shell, deliberately.
// The realm decision is a small number of declarations spread across three
// shells and one strip, and what breaks it is a shell forgetting to declare
// or a control forgetting to ask. Both are visible here, and neither needs a
// signed-in operator identity to observe. This does not certify the rendered
// console: the reviewer account holds no operator capability, so ADMIN_DESKTOP
// stays physically unverified and is reported as such.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Source with `//` comments stripped. The doc comments here name the very
/// symbols being asserted, so prose would satisfy a check that code did not.
String _code(String path) => _read(path)
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    })
    .join('\n');

void main() {
  const shell = 'lib/app/shell/global_platform_shell.dart';
  const tools = 'lib/app/shell/shell_header_tools.dart';
  const memberShell = 'lib/app/shell/member_shell.dart';
  const operatorShell = 'lib/features/admin/shell/operator_shell.dart';

  group('every shell declares where it stands', () {
    test('the realm exists on the shared shell, defaulting to member', () {
      final s = _code(shell);
      expect(s, contains('enum AuraShellRealm'));
      expect(s, contains('this.realm = AuraShellRealm.member'));
    });

    test('the operator console declares the operator realm', () {
      expect(_code(operatorShell), contains('realm: AuraShellRealm.operator'));
    });

    test('the institution workspace declares the institution realm', () {
      expect(
        _code(memberShell),
        contains('realm: AuraShellRealm.institution'),
      );
    });
  });

  group('controls that are meaningless in a realm are absent from it', () {
    final t = _code(tools);

    test('Live is a member act', () {
      // It joins or starts a session AS THE PERSON. Outside the member realm
      // it is an offer to leave the surface being worked on.
      expect(t, contains('widget.realm == AuraShellRealm.member'));
      expect(
        t,
        contains('widget.showLive && widget.realm == AuraShellRealm.member'),
      );
    });

    test('acquiring an institution is a member act', () {
      expect(
        t,
        contains('widget.realm == AuraShellRealm.member &&'),
        reason: 'the onboarding offer was rendering on the operator console',
      );
    });

    test('the operator door is not drawn from inside the room', () {
      expect(
        t,
        contains('canOperate && widget.realm != AuraShellRealm.operator'),
      );
    });

    test('search is suppressed where it would answer the wrong corpus', () {
      // Both non-member shells pass null. `/search` is public discourse: in an
      // institution workspace it leaks member content into institution scope,
      // and in Admin it searches something else entirely.
      for (final path in const [memberShell, operatorShell]) {
        expect(
          _code(path),
          contains('searchPath: null'),
          reason: '$path must not offer member search',
        );
      }
    });
  });

  group('controls addressed to the PERSON survive every realm', () {
    test('attention and account are never realm-gated', () {
      final t = _code(tools);
      // A notification is addressed to the person, not to the surface they
      // happen to be standing on, and identity is never realm-scoped. Gating
      // either on realm would be the same category error the realm exists to
      // correct, pointed the other way.
      final activity = t.substring(
        t.indexOf('widget.activityPath != null'),
        t.indexOf('widget.showLive'),
      );
      expect(activity, isNot(contains('AuraShellRealm')));
    });

    test('no shell suppresses the attention bell', () {
      for (final path in const [memberShell, operatorShell]) {
        expect(
          _code(path),
          isNot(contains('activityPath: null')),
          reason: '$path must not bury the person\'s own notifications',
        );
      }
    });
  });
}
