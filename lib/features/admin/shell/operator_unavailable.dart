/// STATES WHERE NO OPERATOR NAVIGATION CAN HONESTLY BE DRAWN.
///
/// These are not decoration. "We do not know your authority yet", "we could
/// not establish it" and "you hold none" are three different facts, and a
/// console that renders the same blank panel for all three teaches an operator
/// to distrust it.
library;

import 'package:flutter/material.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';

/// Authority is being established. Deliberately quiet — this resolves in one
/// request and a spinner-heavy console reads as fragile.
class OperatorAuthorityLoading extends StatelessWidget {
  const OperatorAuthorityLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Centered(
      icon: Icons.shield_outlined,
      title: 'Establishing authority',
      body: 'Confirming what you are authorised to operate.',
      showProgress: true,
    );
  }
}

/// The probe failed. Distinct from "you hold none": this is OUR failure, and
/// saying so is what stops an operator concluding their access was revoked.
class OperatorAuthorityError extends StatelessWidget {
  const OperatorAuthorityError({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Centered(
      icon: Icons.cloud_off_rounded,
      title: 'Could not establish authority',
      body: 'Your authority could not be confirmed. This is a connection or '
          'service problem, not a change to your access.',
    );
  }
}

/// Confirmed: this account holds no operator authority.
class OperatorNoAuthority extends StatelessWidget {
  const OperatorNoAuthority({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Centered(
      icon: Icons.lock_outline_rounded,
      title: 'No operator authority',
      body: 'This account does not hold authority to operate Aura. If that is '
          'unexpected, an existing operator can review your grant.',
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    required this.body,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: AuraSurface.muted),
              const SizedBox(height: AuraSpace.s16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AuraSurface.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AuraSpace.s8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AuraSurface.muted,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (showProgress) ...[
                const SizedBox(height: AuraSpace.s20),
                const SizedBox(
                  width: 90,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: AuraSurface.divider,
                    color: AuraSurface.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
