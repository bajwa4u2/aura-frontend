import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/institutions/institution_paths.dart';
import '../../../../core/navigation/navigation_authority.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_text.dart';
import '../../../identity/data/identity_verification_repository.dart';

/// The server's refusal code when a verified person holds no confirmed
/// authority for the institution they tried to speak for.
const String kInstitutionAuthorityRequired = 'INSTITUTION_AUTHORITY_REQUIRED';

/// WHY THIS PERSON CANNOT SPEAK FOR THIS INSTITUTION YET, AND THE ONE STEP.
///
/// Founder, 2026-09-19: identity and institution authority are separate
/// facts. A verified owner is told their identity is verified and that the
/// missing step is evidence of their relationship or authority — never "not
/// allowed", and never sent back to identity verification. Only somebody with
/// no current identity verification is told to verify it first.
///
/// Reads the person's own verification to say which of the two it is. While
/// that is unknown it says the authority sentence, which is true either way
/// about what this institution needs.
class SpeakingAuthorityNotice extends ConsumerWidget {
  const SpeakingAuthorityNotice({
    super.key,
    required this.institutionAddress,
    this.authorityState,
    this.compact = false,
  });

  /// The institution's canonical address (slug), for the Verification link.
  final String institutionAddress;

  /// The authority claim's state, where the caller knows it. A claim already
  /// with a reviewer must not be told to "provide evidence" again — that is
  /// how the same document gets sent twice.
  final String? authorityState;

  /// A single line and a button, for cards that already carry a heading.
  final bool compact;

  static const String authoritySentence =
      'Your identity is verified. To speak for this institution, provide '
      'evidence of your relationship or authority.';

  static const String identityFirstSentence =
      'Verify your identity first. Then provide evidence of your relationship '
      'or authority for this institution.';

  static const String pendingSentence =
      'Your evidence of authority for this institution is with a reviewer. '
      'You can speak for it once that is confirmed.';

  static const String needsInfoSentence =
      'A reviewer asked for more evidence of your authority for this '
      'institution.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified =
        ref.watch(identityVerificationStatusProvider).valueOrNull?.isVerified;
    final needsIdentity = verified == false;
    final state = (authorityState ?? '').toUpperCase();
    final pending = state == 'SUBMITTED' || state == 'UNDER_REVIEW';
    final needsInfo = state == 'NEEDS_INFO';

    final sentence = needsIdentity
        ? identityFirstSentence
        : pending
            ? pendingSentence
            : needsInfo
                ? needsInfoSentence
                : authoritySentence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(sentence, style: compact ? AuraText.small : AuraText.body),
        const SizedBox(height: AuraSpace.sm),
        AuraSecondaryButton(
          label: needsIdentity
              ? 'Verify my identity'
              : pending
                  ? 'See where it stands'
                  : needsInfo
                      ? 'Add what was asked for'
                      : 'Provide evidence',
          icon: needsIdentity ? Icons.badge_outlined : Icons.verified_outlined,
          onPressed: () => needsIdentity
              ? context.push(NavigationAuthority.identityVerificationRoute)
              : context.go(institutionWorkspacePath(
                  institutionAddress,
                  InstitutionSection.verification,
                )),
        ),
      ],
    );
  }
}
