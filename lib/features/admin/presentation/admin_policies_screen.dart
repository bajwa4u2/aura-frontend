import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AdminPoliciesScreen extends ConsumerWidget {
  const AdminPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyAsync = ref.watch(adminPoliciesProvider);

    return AuraScaffold(
      title: 'Onboarding policies',
      showHomeAction: true,
      body: policyAsync.when(
        loading: () =>
            const Center(child: AuraLoadingState(message: 'Loading policies…')),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Failed to load policies',
              body: adminErrorMessage(e),
              action: AuraSecondaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(adminPoliciesProvider),
              ),
            ),
          ),
        ),
        data: (policy) => _PolicyEditor(policy: policy),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR (stateful — tracks unsaved edits)
// ─────────────────────────────────────────────────────────────────────────────

class _PolicyEditor extends ConsumerStatefulWidget {
  const _PolicyEditor({required this.policy});
  final AdminPolicy policy;

  @override
  ConsumerState<_PolicyEditor> createState() => _PolicyEditorState();
}

class _PolicyEditorState extends ConsumerState<_PolicyEditor> {
  late InstitutionPolicy _institution;
  late SecurityPolicy _security;
  late CommunicationsPolicy _communications;
  late FeaturePolicy _feature;

  bool _saving = false;
  String? _saveError;
  bool _savedOk = false;

  @override
  void initState() {
    super.initState();
    _institution = widget.policy.institution;
    _security = widget.policy.security;
    _communications = widget.policy.communications;
    _feature = widget.policy.feature;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
      _savedOk = false;
    });

    try {
      final updated = AdminPolicy(
        institution: _institution,
        security: _security,
        communications: _communications,
        feature: _feature,
      );
      await ref.read(adminRepositoryProvider).updatePolicies(updated);
      ref.invalidate(adminPoliciesProvider);
      if (mounted) {
        setState(() {
          _saving = false;
          _savedOk = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = adminErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s16,
        AuraSpace.s32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Default-policy notice (always visible)
                const _InfoBanner(
                  message:
                      'Default platform policies active. Changes take effect immediately.',
                ),
                const SizedBox(height: AuraSpace.s20),

                // Institution policy
                _PolicySection(
                  icon: Icons.apartment_outlined,
                  title: 'Institution policy',
                  subtitle:
                      'Verification requirements and auto-approval rules.',
                  children: [
                    _ToggleTile(
                      label: 'Require email verification',
                      description:
                          'Institution must match an email domain before activation.',
                      value: _institution.requireEmailVerification,
                      onChanged: (v) => setState(
                        () => _institution =
                            _institution.copyWith(requireEmailVerification: v),
                      ),
                    ),
                    _ToggleTile(
                      label: 'Require DNS verification',
                      description:
                          'DNS record must be confirmed — grants active status.',
                      value: _institution.requireDnsVerification,
                      onChanged: (v) => setState(
                        () => _institution =
                            _institution.copyWith(requireDnsVerification: v),
                      ),
                    ),
                    _ToggleTile(
                      label: 'Allow provisional active status',
                      description:
                          'Email-matched institutions may operate in provisional mode.',
                      value: _institution.allowProvisionalActive,
                      onChanged: (v) => setState(
                        () => _institution =
                            _institution.copyWith(allowProvisionalActive: v),
                      ),
                    ),
                    _ToggleTile(
                      label: 'Auto-approve DNS-verified institutions',
                      description:
                          'Skip manual review when DNS verification passes.',
                      value: _institution.autoApproveVerified,
                      onChanged: (v) => setState(
                        () => _institution =
                            _institution.copyWith(autoApproveVerified: v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s16),

                // Security policy
                _PolicySection(
                  icon: Icons.security_outlined,
                  title: 'Security policy',
                  subtitle:
                      'Login limits, session timeouts, and MFA enforcement.',
                  children: [
                    _ToggleTile(
                      label: 'Require MFA',
                      description:
                          'Enforce multi-factor authentication for all admin accounts.',
                      value: _security.requireMfa,
                      onChanged: (v) => setState(
                        () => _security = _security.copyWith(requireMfa: v),
                      ),
                    ),
                    _StepperTile(
                      label: 'Max login attempts',
                      description:
                          'Failed attempts before account is temporarily locked.',
                      value: _security.maxLoginAttempts,
                      min: 1,
                      max: 20,
                      onChanged: (v) => setState(
                        () => _security =
                            _security.copyWith(maxLoginAttempts: v),
                      ),
                    ),
                    _StepperTile(
                      label: 'Session timeout (minutes)',
                      description:
                          'Idle sessions expire after this many minutes.',
                      value: _security.sessionTimeoutMinutes,
                      min: 15,
                      max: 10080,
                      step: 60,
                      onChanged: (v) => setState(
                        () => _security =
                            _security.copyWith(sessionTimeoutMinutes: v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s16),

                // Communications policy
                _PolicySection(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Communications policy',
                  subtitle:
                      'Email sending limits, digest configuration, and opt-outs.',
                  children: [
                    _ToggleTile(
                      label: 'Enable digest emails',
                      description:
                          'Send periodic digest emails to active members.',
                      value: _communications.digestEnabled,
                      onChanged: (v) => setState(
                        () => _communications =
                            _communications.copyWith(digestEnabled: v),
                      ),
                    ),
                    _ToggleTile(
                      label: 'Allow unsubscribe',
                      description:
                          'Members may opt out of non-critical emails.',
                      value: _communications.unsubscribeEnabled,
                      onChanged: (v) => setState(
                        () => _communications =
                            _communications.copyWith(unsubscribeEnabled: v),
                      ),
                    ),
                    _DropdownTile(
                      label: 'Digest frequency',
                      description: 'How often digest emails are sent.',
                      value: _communications.digestFrequency,
                      options: const [
                        ('daily', 'Daily'),
                        ('weekly', 'Weekly'),
                        ('monthly', 'Monthly'),
                      ],
                      onChanged: (v) => setState(
                        () => _communications =
                            _communications.copyWith(digestFrequency: v),
                      ),
                    ),
                    _StepperTile(
                      label: 'Max emails per day',
                      description:
                          'Maximum transactional emails per user per day.',
                      value: _communications.maxEmailsPerDay,
                      min: 1,
                      max: 100,
                      onChanged: (v) => setState(
                        () => _communications =
                            _communications.copyWith(maxEmailsPerDay: v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s16),

                // Feature policy
                _PolicySection(
                  icon: Icons.flag_outlined,
                  title: 'Feature policy',
                  subtitle:
                      'Registration gates and beta access.',
                  children: [
                    _ToggleTile(
                      label: 'Public registration enabled',
                      description: 'Allow new users to sign up without an invite.',
                      value: _feature.publicRegistrationEnabled,
                      onChanged: (v) => setState(
                        () => _feature = _feature.copyWith(
                            publicRegistrationEnabled: v),
                      ),
                    ),
                    _ToggleTile(
                      label: 'Invite-only mode',
                      description:
                          'Restrict sign-ups to invited users only.',
                      value: _feature.inviteOnlyMode,
                      onChanged: (v) => setState(
                        () => _feature =
                            _feature.copyWith(inviteOnlyMode: v),
                      ),
                    ),
                    _ToggleTile(
                      label: 'Beta opt-in enabled',
                      description:
                          'Allow users to opt into early-access features.',
                      value: _feature.betaOptInEnabled,
                      onChanged: (v) => setState(
                        () => _feature =
                            _feature.copyWith(betaOptInEnabled: v),
                      ),
                    ),
                    // Maintenance toggle retired here. See
                    // docs/MAINTENANCE_MODE_POLICY.md — the canonical
                    // control is per-distribution/channel ClientPolicy at
                    // /admin/client-policies. The featurePolicy.maintenanceMode
                    // value still round-trips through this screen's save
                    // (preserved as part of the FeaturePolicy DTO) so that
                    // backward compatibility is not broken; we just no
                    // longer let an operator flip it from this surface.
                    _LegacyMaintenanceCard(
                      currentValue: _feature.maintenanceMode,
                    ),
                  ],
                ),
                const SizedBox(height: AuraSpace.s24),

                // Save bar
                if (_saveError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AuraSpace.s12),
                    decoration: BoxDecoration(
                      color: AuraSurface.dangerBg,
                      borderRadius: BorderRadius.circular(AuraRadius.md),
                      border: Border.all(
                        color:
                            AuraSurface.dangerInk.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _saveError!,
                      style: AuraText.small
                          .copyWith(color: AuraSurface.dangerInk),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                ],

                if (_savedOk) ...[
                  Container(
                    padding: const EdgeInsets.all(AuraSpace.s12),
                    decoration: BoxDecoration(
                      color: AuraSurface.goodBg,
                      borderRadius: BorderRadius.circular(AuraRadius.md),
                      border: Border.all(
                        color: AuraSurface.goodInk.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Policies saved successfully.',
                      style: AuraText.small
                          .copyWith(color: AuraSurface.goodInk),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s12),
                ],

                AuraPrimaryButton(
                  label: _saving ? 'Saving…' : 'Save policies',
                  icon: _saving ? null : Icons.save_rounded,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION WRAPPER
// ─────────────────────────────────────────────────────────────────────────────

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s14,
              AuraSpace.s16,
              AuraSpace.s12,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AuraSurface.accentText),
                const SizedBox(width: AuraSpace.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AuraSurface.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AuraText.small
                            .copyWith(color: AuraSurface.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AuraSurface.divider),
          // Rows
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s16,
                ),
                color: AuraSurface.divider,
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOGGLE TILE
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  // The previous `danger` opt-in was used only by the maintenance toggle
  // that has since been retired (see _LegacyMaintenanceCard below).
  // Removed to keep the API honest — no live caller wanted danger styling.

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AuraSurface.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AuraSurface.accent,
            activeTrackColor:
                AuraSurface.accent.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEPPER TILE
// ─────────────────────────────────────────────────────────────────────────────

class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1000,
    this.step = 1,
  });

  final String label;
  final String description;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AuraSurface.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s16),
          Row(
            children: [
              _StepBtn(
                icon: Icons.remove_rounded,
                onPressed: value > min
                    ? () => onChanged((value - step).clamp(min, max))
                    : null,
              ),
              Container(
                width: 56,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: AuraSpace.s6),
                decoration: BoxDecoration(
                  color: AuraSurface.elevated,
                  border: Border.all(color: AuraSurface.divider),
                  borderRadius: BorderRadius.circular(AuraRadius.r10),
                ),
                child: Text(
                  '$value',
                  style: AuraText.body.copyWith(
                    color: AuraSurface.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              _StepBtn(
                icon: Icons.add_rounded,
                onPressed: value < max
                    ? () => onChanged((value + step).clamp(min, max))
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16),
      onPressed: onPressed,
      color: onPressed != null ? AuraSurface.ink : AuraSurface.faint,
      style: IconButton.styleFrom(
        backgroundColor: AuraSurface.elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.r10),
          side: const BorderSide(color: AuraSurface.divider),
        ),
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DROPDOWN TILE
// ─────────────────────────────────────────────────────────────────────────────

class _DropdownTile extends StatelessWidget {
  const _DropdownTile({
    required this.label,
    required this.description,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String description;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AuraSurface.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s16),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.any((o) => o.$1 == value) ? value : options.first.$1,
              items: options
                  .map(
                    (o) => DropdownMenuItem<String>(
                      value: o.$1,
                      child: Text(
                        o.$2,
                        style: AuraText.small.copyWith(color: AuraSurface.ink),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              dropdownColor: AuraSurface.card,
              borderRadius: BorderRadius.circular(AuraRadius.card),
              style: AuraText.body.copyWith(color: AuraSurface.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO BANNER
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// LEGACY MAINTENANCE CARD
// ─────────────────────────────────────────────────────────────────────────────
//
// Replaces the old `_ToggleTile` for `featurePolicy.maintenanceMode`. The
// stored value is preserved on the backend (round-tripped through the
// FeaturePolicy DTO unchanged) so backward compatibility holds, but
// operators are no longer offered a flip on this screen — the canonical
// maintenance control is per-(distribution, channel) ClientPolicy at
// /admin/client-policies. See docs/MAINTENANCE_MODE_POLICY.md.

class _LegacyMaintenanceCard extends StatelessWidget {
  const _LegacyMaintenanceCard({required this.currentValue});

  final bool currentValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AuraSpace.s4),
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.history_toggle_off_rounded,
                size: 18,
                color: AuraSurface.faint,
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maintenance mode (legacy setting)',
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AuraSurface.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This stored flag is no longer the maintenance control. '
                      'Use Client policies for per-distribution/channel '
                      'maintenance and update governance.',
                      style: AuraText.small.copyWith(color: AuraSurface.faint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.elevated,
                  borderRadius: BorderRadius.circular(AuraRadius.pill),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Text(
                  'stored: ${currentValue ? "true" : "false"}',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s10),
          // The client-policies admin SCREEN is not yet built — only the
          // backend endpoints exist (`PUT /v1/admin/client-policies`, etc.).
          // Until the screen lands, point operators at the API + docs
          // rather than a button that would land on a 404 route.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s10,
              vertical: AuraSpace.s8,
            ),
            decoration: BoxDecoration(
              color: AuraSurface.elevated,
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where to look instead',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  'API: PUT /v1/admin/client-policies/:id  '
                  '(maintenanceMode field on a ClientPolicy row)\n'
                  'Doc: docs/MAINTENANCE_MODE_POLICY.md',
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s14,
        vertical: AuraSpace.s10,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.accentSoft,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(
          color: AuraSurface.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AuraSurface.accentText,
          ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Text(
              message,
              style: AuraText.small.copyWith(color: AuraSurface.accentText),
            ),
          ),
        ],
      ),
    );
  }
}
