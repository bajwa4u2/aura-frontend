import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/institutions/institution_access_provider.dart';
import '../core/ui/aura_platform_components.dart';
import '../core/ui/aura_scaffold.dart';
import '../core/ui/aura_space.dart';

// Authenticated-only entry point for the institution workspace.
// Reads the member's institution access state and redirects:
//   - has access  → /institution/dashboard
//   - no access   → /institutions/get-started (onboarding wizard)
// Unauthenticated users never reach this screen; the router guard
// redirects them to /login first.
class InstitutionsHubScreen extends ConsumerStatefulWidget {
  const InstitutionsHubScreen({super.key});

  @override
  ConsumerState<InstitutionsHubScreen> createState() =>
      _InstitutionsHubScreenState();
}

class _InstitutionsHubScreenState
    extends ConsumerState<InstitutionsHubScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Attempt immediate navigation if institution access is already cached.
    SchedulerBinding.instance.addPostFrameCallback((_) => _tryNavigate());
  }

  void _tryNavigate() {
    if (_navigated || !mounted) return;
    final access = ref.read(institutionAccessProvider).valueOrNull;
    if (access == null) return; // still loading — listener will fire
    _navigated = true;
    context.go(
      access.hasAccess
          ? '/institution/dashboard'
          : '/institutions/get-started',
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[ROUTE BUILD] InstitutionsHubScreen');
    ref.listen<AsyncValue<InstitutionAccess>>(
      institutionAccessProvider,
      (_, next) {
        if (_navigated || !mounted) return;
        next.whenData((access) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (_navigated || !mounted) return;
            _navigated = true;
            context.go(
              access.hasAccess
                  ? '/institution/dashboard'
                  : '/institutions/get-started',
            );
          });
        });
      },
    );

    return AuraScaffold(
      showHeader: false,
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(AuraSpace.s32),
          child: AuraLoadingState(message: 'Loading institution access…'),
        ),
      ),
    );
  }
}
