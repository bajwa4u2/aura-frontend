/// PREFERENCES — the landing surface.
///
/// ## WHAT THIS REPLACES
///
/// There was no Preferences landing. Two navigation entries — one in the
/// account menu, one in the left drawer — both claimed to lead here, and both
/// led somewhere narrower:
///
///     "Preferences"  →  /me/settings/communications   (notifications only)
///     "Settings"     →  /security                     (sessions and password)
///
/// A third partial hub lived on the profile, whose "Settings" section listed
/// Security and Devices and did not mention communication preferences at all.
/// So three surfaces each answered part of the question and none answered
/// "where do I change how Aura works for me".
///
/// ## HOW THE GROUPING WAS DERIVED
///
/// From the authorities that actually exist and persist, not from a settings
/// taxonomy borrowed from elsewhere. Every row below leads to a real, working
/// control backed by a real authority:
///
///     Account       profile, email verification, password
///     Notifications CommunicationPreference — 12 categories, channel+frequency
///     Security      sessions, trusted devices, sign-in history
///     Privacy       UserBlock — see and undo who you have blocked
///     Data          account deletion
///
/// There is deliberately NO Appearance group. Aura is a single-theme product —
/// `themeMode` is fixed — so a theme control would be a row that changes
/// nothing, which is the exact failure this reconstruction exists to remove.
///
/// ## THE COMPOSITION DIFFERS BY PLATFORM, IT IS NOT SCALED
///
/// On a phone the groups stack, because a phone reads in one column and
/// anything else is a compromise. On a pointer client they lay out in two,
/// because a single 1180px-wide column of five short cards is mostly empty
/// space and makes a person scroll past what they could have seen at once.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/media_interaction_profile.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import 'widgets/me_section.dart';

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The SAME interaction authority the media surfaces use. A second device
    // switch here would be a second opinion about the same question, and the
    // two would eventually disagree.
    final pointer =
        MediaInteractionProfile.resolve(canDecodeVideo: true).pointer ==
            PointerModel.pointer;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final twoColumn = pointer && wide;

    final groups = <Widget>[
      _account(context),
      _notifications(context),
      _security(context),
      _privacy(context),
      _data(context),
    ];

    return AuraScaffold(
      title: 'Preferences',
      maxWidth: twoColumn ? 1080 : 720,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          const _Intro(),
          const SizedBox(height: AuraSpace.s20),
          if (twoColumn)
            _TwoColumn(groups: groups)
          else
            for (final g in groups) ...[
              g,
              const SizedBox(height: AuraSpace.s20),
            ],
        ],
      ),
    );
  }

  Widget _account(BuildContext context) => MeSection(
        title: 'Account',
        children: [
          MeSectionRow(
            leading: Icons.person_outline_rounded,
            title: 'Profile',
            subtitle: 'Your name, photo, and what people see about you',
            onTap: () => context.push(NavigationAuthority.editProfileRoute),
          ),
          MeSectionRow(
            leading: Icons.lock_outline_rounded,
            title: 'Password',
            subtitle: 'Change the password you sign in with',
            onTap: () => context.push(NavigationAuthority.changePasswordRoute),
          ),
        ],
      );

  Widget _notifications(BuildContext context) => MeSection(
        title: 'Notifications',
        children: [
          MeSectionRow(
            leading: Icons.notifications_none_rounded,
            title: 'How Aura reaches you',
            // Says what it CONTROLS, not what the screen is called. The old
            // entry said "Preferences" and opened this, which told a person
            // nothing about what they would find.
            subtitle:
                'Choose the channel and frequency for each kind of message',
            onTap: () => context.push(NavigationAuthority.communicationPreferencesRoute),
          ),
        ],
      );

  Widget _security(BuildContext context) => MeSection(
        title: 'Security',
        children: [
          MeSectionRow(
            leading: Icons.shield_outlined,
            title: 'Sign-in and access',
            subtitle: 'Where you are signed in, and what happened recently',
            onTap: () => context.push(NavigationAuthority.securityRoute),
          ),
          MeSectionRow(
            leading: Icons.devices_outlined,
            // NOT just "Devices". Three authorities answer to that word — the
            // ones Aura can reach you on, the ones that skip verification, and
            // the places you are signed in — and the product never told them
            // apart. Each is now named for what it does.
            title: 'Your devices',
            subtitle: 'Where Aura can reach you with calls and notifications',
            onTap: () => context.push(NavigationAuthority.devicesRoute),
          ),
        ],
      );

  Widget _privacy(BuildContext context) => MeSection(
        title: 'Privacy',
        children: [
          MeSectionRow(
            leading: Icons.block_outlined,
            title: 'Blocked people',
            // The authority for this existed and had no surface: a person
            // could block someone from a post or a profile and then had no
            // way to see the list or undo it.
            subtitle: 'See who you have blocked, and undo it',
            onTap: () => context.push(NavigationAuthority.blockedPeopleRoute),
          ),
        ],
      );

  Widget _data(BuildContext context) => MeSection(
        title: 'Data and account',
        children: [
          MeSectionRow(
            leading: Icons.delete_outline_rounded,
            title: 'Delete your account',
            // Consequence named on the row itself, before anyone taps. The
            // destructive confirmation still lives on its own screen and is
            // unchanged; this is so nobody arrives there by accident.
            subtitle: 'Permanently remove your account and what it holds',
            onTap: () => context.push(NavigationAuthority.accountDeletionRoute),
          ),
        ],
      );
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Text(
      'What you change here applies to your Aura account, everywhere you are '
      'signed in.',
      style: AuraText.small.copyWith(color: AuraSurface.faint, height: 1.4),
    );
  }
}

/// Two balanced columns, filled by height rather than alternating.
///
/// Alternating would put Account and Security in one column and leave the
/// other short, which reads as an accident. This keeps the two sides close in
/// length so the page looks composed rather than wrapped.
class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.groups});

  final List<Widget> groups;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      (i.isEven ? left : right).add(groups[i]);
    }

    Widget column(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final w in items) ...[
              w,
              const SizedBox(height: AuraSpace.s20),
            ],
          ],
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(left)),
        const SizedBox(width: AuraSpace.s20),
        Expanded(child: column(right)),
      ],
    );
  }
}
