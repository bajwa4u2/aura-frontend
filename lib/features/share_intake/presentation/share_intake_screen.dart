import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/authority/acting_context.dart';
import '../../../core/authority/authority_providers.dart';
import '../../../core/composition/attachment_lifecycle.dart';
import '../../../core/media/aura_composition_strip.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../application/share_destinations.dart';
import '../application/share_handoff.dart';
import '../application/share_intake_controller.dart';
import '../application/share_intake_inbox.dart';
import '../domain/share_destination.dart';

/// WHERE A SHARE FROM ANOTHER APPLICATION MEETS AURA'S RULES.
///
/// The one surface every operating system's share sheet lands on. It is
/// deliberately a full screen rather than a sheet: the person is deciding
/// where something goes and who it goes as, and that decision deserves the
/// whole display rather than a strip above a keyboard.
///
/// WHY THIS IS NOT `ShareScreen`. That surface is the in-app content-first
/// intention, and its audience is fixed by an explicit product decision —
/// "deliberately not a control". Content arriving from another application
/// carries no destination and no identity, so here both are questions and
/// neither may be defaulted. Threading a mode flag through one screen to
/// serve both would be the page-specific pipeline this track removes.
///
/// What the two entrances DO share is everything below the surface: the same
/// `ContentIntake` door, the same `Attachment`, the same composition strip,
/// and — because this screen publishes nothing — the destination's own
/// composer for the send.
///
/// IT ESTABLISHES, IN THIS ORDER, AND WILL NOT PROCEED WITHOUT ANY OF THEM:
///
///   1. an authenticated Human       — signed out, the share waits
///   2. what actually arrived        — read from the bytes, not the claim
///   3. where it may go              — resolved now, never remembered
///   4. whether that is allowed      — the destination's own capability
///   5. who it would be published as — the C1 authority's answer
///   6. what confirming does         — said in words, before the button
///   7. an explicit act              — and nothing happens before it
class ShareIntakeScreen extends ConsumerStatefulWidget {
  const ShareIntakeScreen({super.key});

  @override
  ConsumerState<ShareIntakeScreen> createState() => _ShareIntakeScreenState();
}

class _ShareIntakeScreenState extends ConsumerState<ShareIntakeScreen> {
  ShareIntakeController? _controller;
  final _bodyController = TextEditingController();
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    // Taken once. A share presented twice is a person publishing twice
    // without having asked to.
    final envelope = ref.read(shareIntakeInboxProvider.notifier).take();
    if (envelope == null) return;

    final controller = ShareIntakeController(envelope);
    _controller = controller;
    controller.addListener(_onControllerChanged);
    // Typing is the person's, so the field is the authority for the body and
    // the controller follows it.
    _bodyController.addListener(() => controller.editBody(_bodyController.text));
    controller.resolve();
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    // Seeded ONCE, when resolution finishes. Text a share carried is a
    // starting point; after that the field is theirs and must never be
    // overwritten mid-sentence.
    if (!_seeded && controller.isResolved) {
      _seeded = true;
      if (controller.body.isNotEmpty) _bodyController.text = controller.body;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _bodyController.dispose();
    super.dispose();
  }

  /// Hand the resolved content to the destination's ordinary composer.
  ///
  /// Note what this method does NOT do: send anything. It stages and
  /// navigates. The send button the person presses next is the same one they
  /// would have pressed had they never used a share sheet.
  void _continue() {
    final controller = _controller;
    if (controller == null || !controller.readyToConfirm) return;

    final destination = controller.destination!;
    ref.read(shareHandoffProvider.notifier).stage(
          StagedShare(
            destination: destination,
            actingIdentity: controller.actingIdentity!,
            attachments: controller.attachments,
            body: controller.body,
          ),
        );

    switch (destination.kind) {
      case ShareDestinationKind.conversation:
        context.go(NavigationAuthority.conversationRoute(destination.id));
      case ShareDestinationKind.publicPost:
      case ShareDestinationKind.space:
        context.go(NavigationAuthority.composeRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return AuraScaffold(
        title: 'Shared with Aura',
        body: const _NothingWaiting(),
      );
    }

    // GATE 1 — AN AUTHENTICATED HUMAN.
    //
    // The share is not discarded and the person is not dropped at a sign-in
    // screen with their content gone: the envelope survives in the inbox, and
    // signing in returns here. A share that vanishes because a session expired
    // looks exactly like a share that failed.
    final auth = ref.watch(authStatusProvider);
    if (auth == AuthStatus.loading) {
      return AuraScaffold(
        title: 'Shared with Aura',
        body: const AuraProductState(
          state: ProductState.loading,
          headline: 'Opening Aura',
        ),
      );
    }
    if (auth != AuthStatus.authed) {
      return AuraScaffold(
        title: 'Shared with Aura',
        body: _SignInFirst(
          onSignIn: () => context.go(
            NavigationAuthority.signInRoute(
              returnTo: NavigationAuthority.incomingShareRoute,
            ),
          ),
        ),
      );
    }

    return AuraScaffold(
      title: 'Shared with Aura',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s16,
          AuraSpace.s32,
        ),
        children: [
          _Preview(
            controller: controller,
            bodyController: _bodyController,
            onSeen: controller.markPreviewSeen,
          ),
          const SizedBox(height: AuraSpace.s20),
          _DestinationChoice(controller: controller),
          if (controller.destination != null) ...[
            const SizedBox(height: AuraSpace.s20),
            _IdentityChoice(controller: controller),
            const SizedBox(height: AuraSpace.s20),
            _Consequence(controller: controller),
          ],
          const SizedBox(height: AuraSpace.s20),
          _ConfirmBar(controller: controller, onContinue: _continue),
        ],
      ),
    );
  }
}

/// WHAT ACTUALLY ARRIVED — shown before anything is asked of the person.
///
/// The preview is not a courtesy. A share sheet gives no reliable indication
/// of what was selected, and a person who has not seen the content cannot
/// meaningfully choose where it goes. `markPreviewSeen` is called when this is
/// built, which is the only honest place to call it from.
class _Preview extends StatefulWidget {
  const _Preview({
    required this.controller,
    required this.bodyController,
    required this.onSeen,
  });

  final ShareIntakeController controller;
  final TextEditingController bodyController;
  final VoidCallback onSeen;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    if (controller.isResolving) {
      return const AuraProductState(
        state: ProductState.loading,
        headline: 'Reading what was shared',
        detail: 'Aura is checking what actually arrived.',
      );
    }

    if (controller.hasContent) {
      // Announced after this frame paints: the person has now been shown it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSeen();
      });
    }

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What was shared', style: AuraText.label),
          const SizedBox(height: AuraSpace.s12),
          if (controller.attachments.isNotEmpty) ...[
            AuraCompositionStrip(
              attachments: controller.attachments,
              // Already resolved; nothing here is uploading yet, because
              // nothing has been committed to a destination.
              phaseOf: (_) => AttachmentPhase.ready,
              onRemove: controller.removeAttachment,
            ),
            const SizedBox(height: AuraSpace.s12),
          ],
          AuraInput(
            controller: widget.bodyController,
            label: 'Message',
            hint: 'Say something about this',
            maxLines: 4,
          ),
          // REFUSALS ARE SHOWN, NOT SWALLOWED. A file that silently fails to
          // arrive is the worst outcome available, because the person believes
          // it is there.
          if (controller.refusals.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            for (final refusal in controller.refusals)
              Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AuraSurface.muted),
                    const SizedBox(width: AuraSpace.s8),
                    Expanded(child: Text(refusal, style: AuraText.small)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// WHERE IT MAY GO — resolved now, in the ledger's own order.
class _DestinationChoice extends ConsumerWidget {
  const _DestinationChoice({required this.controller});

  final ShareIntakeController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(shareDestinationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Where does this go?', style: AuraText.subtitle),
        const SizedBox(height: AuraSpace.s12),
        destinations.when(
          loading: () => const AuraProductState(
            state: ProductState.loading,
            headline: 'Finding where this can go',
          ),
          error: (_, __) => const AuraProductState(
            state: ProductState.retryableError,
            headline: 'Aura could not work out where you can send this',
          ),
          data: (items) {
            if (items.isEmpty) {
              return const AuraProductState(
                state: ProductState.empty,
                subject: ProductNoun.conversation,
                headline: 'Nowhere to send this yet',
                detail: 'Start a conversation, or publish this publicly.',
              );
            }
            return Column(
              children: [
                for (final destination in items)
                  _DestinationRow(
                    destination: destination,
                    selected: controller.destination?.kind == destination.kind &&
                        controller.destination?.id == destination.id,
                    onTap: destination.available
                        ? () => controller.chooseDestination(destination)
                        : null,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ShareDestination destination;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AuraSpace.s12),
          decoration: BoxDecoration(
            color: selected ? AuraSurface.elevated : AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(
              color: selected ? AuraSurface.accent : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                destination.isPublic ? Icons.public : Icons.forum_outlined,
                size: 20,
                color: destination.isPublic
                    ? AuraSurface.accentText
                    : AuraSurface.muted,
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(destination.title, style: AuraText.body),
                    if (destination.subtitle != null)
                      Text(destination.subtitle!, style: AuraText.small),
                    // A destination the person cannot use says why, rather
                    // than disappearing. A silently absent option is
                    // indistinguishable from a broken screen.
                    if (!destination.available &&
                        destination.unavailableReason != null)
                      Text(
                        destination.unavailableReason!,
                        style: AuraText.small,
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    size: 20, color: AuraSurface.accentText),
            ],
          ),
        ),
      ),
    );
  }
}

/// WHO IT WOULD BE PUBLISHED AS — asked of the C1 authority, never guessed.
///
/// Where the person has exactly one legitimate identity for this act, the
/// authority's answer is adopted and stated, with no chooser: C1 froze that a
/// single legitimate identity means no ceremony, and a control that changes
/// nothing is worse than no control. Where there is genuinely more than one,
/// the person picks, every time, for this act.
class _IdentityChoice extends ConsumerWidget {
  const _IdentityChoice({required this.controller});

  final ShareIntakeController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = controller.destination;
    if (destination == null) return const SizedBox.shrink();

    final resolution = ref.watch(
      actingResolutionWithPersonalAlternativeProvider(destination.act),
    );

    if (resolution == null || !resolution.isAvailable) {
      return const _Notice(
        icon: Icons.block,
        text: 'You cannot publish into this destination.',
      );
    }

    if (!resolution.requiresExplicitChoice) {
      final only = resolution.recommended!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.actingIdentity?.id != only.id) {
          controller.chooseIdentity(only);
        }
      });
      return _Notice(
        icon: only.isInstitution ? Icons.apartment : Icons.person_outline,
        text: 'Published as ${only.displayName}. '
            '${only.availability.explanation}',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Who is publishing this?', style: AuraText.subtitle),
        const SizedBox(height: AuraSpace.s12),
        for (final option in resolution.options)
          Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s8),
            child: InkWell(
              onTap: () => controller.chooseIdentity(option),
              borderRadius: BorderRadius.circular(AuraRadius.card),
              child: Container(
                padding: const EdgeInsets.all(AuraSpace.s12),
                decoration: BoxDecoration(
                  color: controller.actingIdentity?.id == option.id
                      ? AuraSurface.elevated
                      : AuraSurface.subtle,
                  borderRadius: BorderRadius.circular(AuraRadius.card),
                ),
                child: Row(
                  children: [
                    Icon(
                      option.isInstitution
                          ? Icons.apartment
                          : Icons.person_outline,
                      size: 20,
                      color: AuraSurface.muted,
                    ),
                    const SizedBox(width: AuraSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(option.displayName, style: AuraText.body),
                          Text(option.availability.explanation,
                              style: AuraText.small),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// WHAT CONFIRMING DOES, IN WORDS, BEFORE THE BUTTON.
class _Consequence extends StatelessWidget {
  const _Consequence({required this.controller});

  final ShareIntakeController controller;

  @override
  Widget build(BuildContext context) {
    final destination = controller.destination!;
    return _Notice(
      icon: destination.isPublic ? Icons.public : Icons.lock_outline,
      text: destination.kind.consequence,
      emphasised: destination.isPublic,
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.controller, required this.onContinue});

  final ShareIntakeController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final blocked = controller.blockedReason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (blocked != null) ...[
          Text(blocked, style: AuraText.small),
          const SizedBox(height: AuraSpace.s8),
        ],
        Row(
          children: [
            AuraPrimaryButton(
              // NOT "Send" and NOT "Publish", because this button does
              // neither. It opens the destination's own composer with the
              // content in it, where sending is still a separate act.
              label: 'Continue',
              onPressed: blocked == null ? onContinue : null,
            ),
            const SizedBox(width: AuraSpace.s12),
            AuraGhostButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.emphasised = false,
  });

  final IconData icon;
  final String text;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: emphasised ? AuraSurface.elevated : AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 18,
              color:
                  emphasised ? AuraSurface.accentText : AuraSurface.muted),
          const SizedBox(width: AuraSpace.s12),
          Expanded(child: Text(text, style: AuraText.body)),
        ],
      ),
    );
  }
}

class _NothingWaiting extends StatelessWidget {
  const _NothingWaiting();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AuraSpace.s24),
      child: AuraProductState(
        state: ProductState.empty,
        headline: 'Nothing was shared',
        detail: 'Share something to Aura from another application and it will '
            'arrive here.',
      ),
    );
  }
}

class _SignInFirst extends StatelessWidget {
  const _SignInFirst({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AuraSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sign in to continue', style: AuraText.title),
          const SizedBox(height: AuraSpace.s12),
          const Text(
            'What you shared is held here and nothing has been sent. Sign in '
            'and you will come straight back to it.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s20),
          AuraPrimaryButton(label: 'Sign in', onPressed: onSignIn),
        ],
      ),
    );
  }
}
