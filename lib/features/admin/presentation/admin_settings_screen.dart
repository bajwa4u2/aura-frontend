import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(adminSettingsProvider);

    return AuraScaffold(
      title: 'Platform settings',
      showHomeAction: true,
      body: settingsAsync.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading settings…'),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Failed to load settings',
              body: adminErrorMessage(e),
              action: AuraSecondaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(adminSettingsProvider),
              ),
            ),
          ),
        ),
        data: (settings) {
          if (settings.isEmpty) {
            return const _SettingsEmptyState();
          }

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
                  constraints: const BoxConstraints(maxWidth: kWorkspaceWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AuraSurface.card,
                      borderRadius: BorderRadius.circular(AuraRadius.card),
                      border: Border.all(color: AuraSurface.divider),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < settings.length; i++) ...[
                          _SettingRow(setting: settings[i]),
                          if (i < settings.length - 1)
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
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsEmptyState extends StatelessWidget {
  const _SettingsEmptyState();

  static const _categories = [
    (Icons.security_outlined, 'Security policy', 'Login attempts, session timeouts, MFA enforcement.'),
    (Icons.mark_email_read_outlined, 'Communications policy', 'Email sender config, digest caps, unsubscribe behavior.'),
    (Icons.apartment_outlined, 'Institution policy', 'Verification requirements, domain allowlist rules.'),
    (Icons.flag_outlined, 'Feature policy', 'Rollout gates, beta opt-in, kill-switch overrides.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AuraSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.tune_outlined, size: 32, color: AuraSurface.faint),
              const SizedBox(height: AuraSpace.s12),
              Text(
                'Default platform policies active',
                style: AuraText.title.copyWith(color: AuraSurface.ink),
              ),
              const SizedBox(height: AuraSpace.s6),
              Text(
                'No custom settings have been pushed from the backend. '
                'Default policies are in effect. Use the Policies screen to configure:',
                style: AuraText.body.copyWith(color: AuraSurface.muted),
              ),
              const SizedBox(height: AuraSpace.s20),
              Container(
                decoration: BoxDecoration(
                  color: AuraSurface.card,
                  borderRadius: BorderRadius.circular(AuraRadius.card),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _categories.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AuraSpace.s16,
                          vertical: AuraSpace.s12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _categories[i].$1,
                              size: 18,
                              color: AuraSurface.faint,
                            ),
                            const SizedBox(width: AuraSpace.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _categories[i].$2,
                                    style: AuraText.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AuraSurface.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _categories[i].$3,
                                    style: AuraText.small.copyWith(
                                      color: AuraSurface.faint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                                'Default',
                                style: AuraText.micro.copyWith(
                                  color: AuraSurface.faint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < _categories.length - 1)
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTING ROW — typed structured renderer
// ─────────────────────────────────────────────────────────────────────────────
//
// Slice D admin-runtime hardening: previously every value was rendered as
// `setting.value.toString()` inside a fixed-width pill, which produced a
// vertical text wall when the value was a Map / List. The new renderer
// branches on the value's runtime type so:
//
//   string  → single-line text in the pill
//   bool    → ON/OFF chip with semantic color
//   number  → right-aligned monospace
//   null    → faint em-dash
//   Map/List → expandable pretty-printed JSON block, copyable, scroll-safe

class _SettingRow extends StatefulWidget {
  const _SettingRow({required this.setting});

  final AdminSetting setting;

  @override
  State<_SettingRow> createState() => _SettingRowState();
}

class _SettingRowState extends State<_SettingRow> {
  bool _expanded = false;

  bool get _isStructured =>
      widget.setting.value is Map || widget.setting.value is List;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.setting.key,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AuraSurface.ink,
                      ),
                    ),
                    if (widget.setting.description != null &&
                        widget.setting.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.setting.description!,
                        style:
                            AuraText.small.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s16),
              if (_isStructured)
                _StructuredToggle(
                  expanded: _expanded,
                  onTap: () => setState(() => _expanded = !_expanded),
                  summary: _structuredSummary(widget.setting.value),
                )
              else
                _InlineValueChip(value: widget.setting.value),
            ],
          ),
          if (_isStructured && _expanded) ...[
            const SizedBox(height: AuraSpace.s10),
            _StructuredValueBlock(value: widget.setting.value),
          ],
        ],
      ),
    );
  }
}

String _structuredSummary(Object? value) {
  if (value is Map) return '{${value.length}}';
  if (value is List) return '[${value.length}]';
  return '';
}

class _InlineValueChip extends StatelessWidget {
  const _InlineValueChip({required this.value});

  final Object? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const _Pill(
        label: '—',
        color: AuraSurface.elevated,
        textColor: AuraSurface.faint,
      );
    }
    if (value is bool) {
      final on = value as bool;
      return _Pill(
        label: on ? 'ON' : 'OFF',
        color: on
            ? AuraSurface.accent.withValues(alpha: 0.15)
            : AuraSurface.elevated,
        textColor: on ? AuraSurface.accentText : AuraSurface.muted,
        bold: true,
      );
    }
    if (value is num) {
      return _Pill(
        label: value.toString(),
        color: AuraSurface.elevated,
        textColor: AuraSurface.muted,
        mono: true,
      );
    }
    final text = value.toString();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: _Pill(
        label: text,
        color: AuraSurface.elevated,
        textColor: AuraSurface.muted,
        mono: true,
        ellipsis: true,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
    this.mono = false,
    this.bold = false,
    this.ellipsis = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final bool mono;
  final bool bold;
  final bool ellipsis;

  @override
  Widget build(BuildContext context) {
    final style = AuraText.small.copyWith(
      fontFamily: mono ? 'monospace' : null,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: textColor,
      letterSpacing: bold ? 0.4 : null,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AuraRadius.r10),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        label,
        maxLines: ellipsis ? 1 : null,
        overflow: ellipsis ? TextOverflow.ellipsis : TextOverflow.clip,
        style: style,
      ),
    );
  }
}

class _StructuredToggle extends StatelessWidget {
  const _StructuredToggle({
    required this.expanded,
    required this.onTap,
    required this.summary,
  });

  final bool expanded;
  final VoidCallback onTap;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.r10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10,
            vertical: AuraSpace.s6,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.elevated,
            borderRadius: BorderRadius.circular(AuraRadius.r10),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary,
                style: AuraText.small.copyWith(
                  fontFamily: 'monospace',
                  color: AuraSurface.muted,
                ),
              ),
              const SizedBox(width: AuraSpace.s6),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
                color: AuraSurface.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StructuredValueBlock extends StatelessWidget {
  const _StructuredValueBlock({required this.value});

  final Object? value;

  static const _encoder = JsonEncoder.withIndent('  ');

  String _safeJson() {
    try {
      return _encoder.convert(value);
    } catch (_) {
      // The value contains something JsonEncoder can't serialize. Fall back
      // to a plain string rather than rendering nothing — the operator
      // still wants to see SOMETHING. Wrapped in a code block by the
      // caller's monospace style, so the broken type is visible.
      return value?.toString() ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final json = _safeJson();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.r10),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s10,
              AuraSpace.s6,
              AuraSpace.s6,
              AuraSpace.s4,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.data_object_rounded,
                  size: 14,
                  color: AuraSurface.faint,
                ),
                const SizedBox(width: AuraSpace.s6),
                Text(
                  'json',
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.faint,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: 'Copy',
                  icon: const Icon(Icons.content_copy_rounded),
                  color: AuraSurface.faint,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: json));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Setting JSON copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.s12,
                  0,
                  AuraSpace.s12,
                  AuraSpace.s12,
                ),
                child: SelectableText(
                  json,
                  style: AuraText.small.copyWith(
                    fontFamily: 'monospace',
                    color: AuraSurface.muted,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
