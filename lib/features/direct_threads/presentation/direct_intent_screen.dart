import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/interactions/follows_repository.dart';
import '../../../core/interactions/interaction_service.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';

/// Direct-thread login-resume bridge.
///
/// `/direct-intent?targetType=USER|INSTITUTION&targetUserId|targetInstitutionId=...`
///
/// Mounted INSIDE the post-login redirect chain. Rebuilds when auth flips
/// to authed, then re-runs `InteractionService.openDirectThread` so the
/// user lands on the actual thread instead of `/home`.
///
/// While auth is settling, renders a small spinner. If auth never settles
/// (e.g. credentials revoked), the screen surfaces an explicit error
/// rather than redirecting silently.
class DirectIntentScreen extends ConsumerStatefulWidget {
  const DirectIntentScreen({
    super.key,
    required this.targetType,
    this.targetUserId,
    this.targetInstitutionId,
  });

  final String targetType;
  final String? targetUserId;
  final String? targetInstitutionId;

  @override
  ConsumerState<DirectIntentScreen> createState() =>
      _DirectIntentScreenState();
}

class _DirectIntentScreenState extends ConsumerState<DirectIntentScreen> {
  bool _started = false;
  String? _error;

  ActorRef? _target() {
    final t = widget.targetType.trim().toUpperCase();
    if (t == 'INSTITUTION') {
      final id = (widget.targetInstitutionId ?? '').trim();
      if (id.isEmpty) return null;
      return ActorRef.institution(id);
    }
    final id = (widget.targetUserId ?? '').trim();
    if (id.isEmpty) return null;
    return ActorRef.user(id);
  }

  Future<void> _resume() async {
    if (_started) return;
    _started = true;
    final target = _target();
    if (target == null) {
      setState(() => _error = 'Direct-thread target is missing.');
      return;
    }
    try {
      await ref
          .read(interactionServiceProvider)
          .openDirectThread(context: context, ref: ref, target: target);
    } on InteractionError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open thread: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStatusProvider);
    if (auth == AuthStatus.authed && _error == null) {
      // Schedule the resume after this frame so navigation calls land on
      // a settled router state.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resume();
      });
    }

    return AuraScaffold(
      showHeader: false,
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(AuraSpace.s16),
                child: AuraErrorState(
                  title: 'Could not open thread',
                  body: _error!,
                  action: AuraSecondaryButton(
                    label: 'Go home',
                    onPressed: () => context.go('/home'),
                  ),
                ),
              )
            : auth == AuthStatus.authed
                ? const AuraLoadingState(message: 'Opening thread…')
                : const AuraLoadingState(message: 'Resuming…'),
      ),
    );
  }
}
