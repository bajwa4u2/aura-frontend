import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/canonical_destinations.dart';
import '../../../core/product/product_language.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/guest_shell.dart';
import '../application/meetings_provider.dart';

/// `/meetings/invitation/:token/decline` — THE DECLINE LINK IN AN INVITATION
/// EMAIL (6 Nov 2026).
///
/// An invited person had no way to say no: DECLINED existed on the
/// invitation and was honoured at the door, but nothing could set it. The
/// server's route is a POST, so the email links here. Opening the link does
/// nothing by itself (a mail scanner or a preview must not decline for
/// anyone); the person confirms first. No sign-in: the token is the
/// invitation.
class InvitationDeclineScreen extends ConsumerStatefulWidget {
  const InvitationDeclineScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<InvitationDeclineScreen> createState() =>
      _InvitationDeclineScreenState();
}

enum _Stage { asking, sending, declined, notFound, failed }

class _InvitationDeclineScreenState
    extends ConsumerState<InvitationDeclineScreen> {
  _Stage _stage = _Stage.asking;

  Future<void> _decline() async {
    setState(() => _stage = _Stage.sending);
    try {
      await ref
          .read(meetingsRepositoryProvider)
          .declineInvitationByToken(widget.token);
      if (!mounted) return;
      setState(() => _stage = _Stage.declined);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _stage = e.response?.statusCode == 404
          ? _Stage.notFound
          : _Stage.failed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _Stage.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GuestShell(
      body: ListView(
        padding: const EdgeInsets.all(AuraSpace.s24),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(AuraSpace.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _body(theme),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(ThemeData theme) {
    Widget home() => TextButton(
          onPressed: () => context.go(publicRootDestination()),
          child: const Text('Back to home'),
        );

    switch (_stage) {
      case _Stage.declined:
        return [
          Text('Invitation declined', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AuraSpace.s12),
          Text(
            'The host has been told you will not attend.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AuraSpace.s24),
          home(),
        ];
      case _Stage.notFound:
        return [
          Text('We could not find this invitation',
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: AuraSpace.s12),
          Text(
            'The link may be incomplete, or the invitation no longer exists.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AuraSpace.s24),
          home(),
        ];
      case _Stage.failed:
        return [
          Text('Your answer was not sent', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AuraSpace.s12),
          Text(
            'Check your connection and try again.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AuraSpace.s24),
          FilledButton(
            onPressed: _decline,
            child: Text(ProductLabels.of(ProductAction.retry)),
          ),
          const SizedBox(height: AuraSpace.s8),
          home(),
        ];
      case _Stage.asking:
      case _Stage.sending:
        final sending = _stage == _Stage.sending;
        return [
          Text('Decline this invitation?',
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: AuraSpace.s12),
          Text(
            'The host will be told you will not attend. Your invitation link '
            'will no longer let you join.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AuraSpace.s24),
          FilledButton(
            onPressed: sending ? null : _decline,
            child: sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Decline invitation'),
          ),
          const SizedBox(height: AuraSpace.s8),
          TextButton(
            onPressed: sending ? null : () => context.go(publicRootDestination()),
            child: const Text('Keep my invitation'),
          ),
        ];
    }
  }
}
