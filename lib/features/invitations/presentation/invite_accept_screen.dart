import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../data/invitations_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

final _inviteInspectProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, token) async {
      return ref.watch(invitationsClientProvider).inspectToken(token);
    });

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class InviteAcceptScreen extends ConsumerWidget {
  const InviteAcceptScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStatusProvider);
    final trimmedToken = token.trim();

    return AuraScaffold(
      title: 'Invitation',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (trimmedToken.isEmpty)
            const AuraCard(
              child: _TerminalCard(
                icon: Icons.link_off_rounded,
                title: 'Invite link is incomplete',
                body: 'The token is missing from this invitation link.',
              ),
            )
          else if (auth != AuthStatus.authed)
            AuraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Review invitation', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s8),
                  const AuraTextBlock(
                    'Sign in or join Aura first, then this invitation will continue automatically.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      AuraPrimaryButton(
                        label: 'Sign in',
                        onPressed: () => context.push(
                          '/login?redirect=${Uri.encodeComponent('/invite/accept?token=$trimmedToken')}',
                        ),
                      ),
                      AuraSecondaryButton(
                        label: 'Join Aura',
                        onPressed: () => context.push(
                          '/register?redirect=${Uri.encodeComponent('/invite/accept?token=$trimmedToken')}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Consumer(
              builder: (context, ref, _) {
                final inspectAsync = ref.watch(
                  _inviteInspectProvider(trimmedToken),
                );
                return inspectAsync.when(
                  loading: () => const AuraCard(
                    child: _LoadingBlock(label: 'Reading invitation...'),
                  ),
                  error: (error, _) =>
                      AuraCard(child: _errorCard(error)),
                  data: (invite) =>
                      _InvitePreviewCard(invite: invite, token: trimmedToken),
                );
              },
            ),
        ],
      ),
    );
  }
}

// Resolve specific error states from DioException or message text.
Widget _errorCard(Object error) {
  String? body;
  if (error is DioException) {
    final status = error.response?.statusCode;
    final msg = _extractErrorMessage(error.response?.data);
    if (status == 404) {
      return const _TerminalCard(
        icon: Icons.search_off_rounded,
        title: 'Invite not found',
        body: 'This invite link is invalid or has already been removed.',
      );
    }
    if (status == 403) {
      if (msg.contains('expired')) {
        return const _TerminalCard(
          icon: Icons.timer_off_rounded,
          title: 'This invite has expired',
          body: 'Ask the person who invited you to send a new invite.',
        );
      }
      if (msg.contains('revoked')) {
        return const _TerminalCard(
          icon: Icons.block_rounded,
          title: 'This invite was revoked',
          body: 'This invitation is no longer active.',
        );
      }
      if (msg.contains('usage limit') || msg.contains('maxUses')) {
        return const _TerminalCard(
          icon: Icons.people_alt_rounded,
          title: 'This invite is full',
          body: 'The maximum number of people have already accepted this invite.',
        );
      }
      if (msg.contains('not for you') || msg.contains('different email')) {
        return const _TerminalCard(
          icon: Icons.mail_outline_rounded,
          title: 'This invite is for someone else',
          body: 'This invitation is bound to a different email address.',
        );
      }
      body = msg.isNotEmpty ? msg : 'You do not have permission to access this invitation.';
    }
  }
  return _TerminalCard(
    icon: Icons.error_outline_rounded,
    title: 'Could not open invitation',
    body: body ?? 'Something went wrong. Please try again or contact support.',
  );
}

String _extractErrorMessage(dynamic data) {
  if (data == null) return '';
  if (data is String) return data.trim();
  if (data is Map) {
    final msg = data['message'] ?? data['error'] ?? data['detail'] ?? '';
    return msg.toString().trim();
  }
  return '';
}

// ─────────────────────────────────────────────────────────────────────────────
// INVITE PREVIEW CARD (main state — valid invite, logged in)
// ─────────────────────────────────────────────────────────────────────────────

class _InvitePreviewCard extends ConsumerStatefulWidget {
  const _InvitePreviewCard({required this.invite, required this.token});

  final Map<String, dynamic> invite;
  final String token;

  @override
  ConsumerState<_InvitePreviewCard> createState() => _InvitePreviewCardState();
}

class _InvitePreviewCardState extends ConsumerState<_InvitePreviewCard> {
  bool _busy = false;

  Future<void> _respond(String action) async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(invitationsClientProvider)
          .respond(
            token: widget.token,
            inviteId: _s(widget.invite, const ['id', 'inviteId']),
            action: action,
          );
      if (!mounted) return;
      if (action.toUpperCase() == 'ACCEPT') {
        final route = _destinationRoute(
          result.isEmpty ? widget.invite : result,
        );
        context.go(route.isEmpty ? '/home' : route);
      } else {
        context.go('/me/invitations');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = _extractErrorMessage(e.response?.data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isNotEmpty ? msg : 'Something went wrong.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    final canRespond = invite['canRespond'] == true;
    final status = _s(invite, const ['status']).toUpperCase();

    // Terminal states
    if (status == 'REVOKED') {
      return const AuraCard(
        child: _TerminalCard(
          icon: Icons.block_rounded,
          title: 'This invite was revoked',
          body: 'This invitation is no longer active.',
        ),
      );
    }
    if (status == 'EXPIRED') {
      return const AuraCard(
        child: _TerminalCard(
          icon: Icons.timer_off_rounded,
          title: 'This invite has expired',
          body: 'Ask the person who invited you to send a new one.',
        ),
      );
    }
    if (status == 'ACCEPTED') {
      return const AuraCard(
        child: _TerminalCard(
          icon: Icons.check_circle_outline_rounded,
          title: 'Already accepted',
          body: 'You have already accepted this invitation.',
        ),
      );
    }
    if (status == 'DECLINED') {
      return const AuraCard(
        child: _TerminalCard(
          icon: Icons.do_not_disturb_alt_rounded,
          title: 'Invite declined',
          body: 'You previously declined this invitation.',
        ),
      );
    }

    final inviterName = _nested(invite, const [
      ['inviter', 'displayName'],
      ['invitedBy', 'displayName'],
      ['inviter', 'handle'],
      ['invitedBy', 'handle'],
    ]);
    final targetName = _resolveTargetName(invite);
    final role = _s(invite, const ['roleToGrant', 'role']);
    final message = _s(invite, const ['message']);
    final expiresAt = _parseDate(invite['expiresAt']);
    final maxUses = invite['maxUses'];
    final usageCount = invite['usageCount'] ?? 0;
    final destinationType = _s(invite, const ['destinationType']).toUpperCase();
    final outcomeLabel = _outcomeLabel(destinationType, role);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.sm),
                ),
                child: const Icon(
                  Icons.mail_rounded,
                  size: AuraIconSize.md,
                  color: AuraSurface.accentText,
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Review invite', style: AuraText.title),
                    if (inviterName.isNotEmpty)
                      Text(
                        'from $inviterName',
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s16),

          // What you're joining
          if (targetName.isNotEmpty || outcomeLabel.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.s12),
              decoration: BoxDecoration(
                color: AuraSurface.subtle,
                borderRadius: BorderRadius.circular(AuraRadius.sm),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (targetName.isNotEmpty)
                    Text(
                      targetName,
                      style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  if (outcomeLabel.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: targetName.isNotEmpty ? AuraSpace.s4 : 0),
                      child: Text(
                        outcomeLabel,
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
          ],

          // Optional message from inviter
          if (message.isNotEmpty) ...[
            AuraTextBlock('"$message"', style: AuraText.body),
            const SizedBox(height: AuraSpace.s12),
          ],

          // Meta pills
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (role.isNotEmpty) _Pill(label: role.toLowerCase()),
              if (expiresAt != null) _Pill(label: 'Expires ${_fmtDate(expiresAt)}'),
              if (maxUses != null) _Pill(label: '$usageCount / $maxUses uses'),
            ],
          ),

          if (canRespond) ...[
            const SizedBox(height: AuraSpace.s16),
            const AuraTextBlock(
              'Accepting will take you to your destination. No action happens automatically — you must confirm below.',
              style: AuraText.small,
            ),
            const SizedBox(height: AuraSpace.s16),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s10,
              children: [
                AuraPrimaryButton(
                  label: _busy ? 'Working…' : 'Accept invite',
                  onPressed: _busy ? null : () => _respond('ACCEPT'),
                ),
                AuraSecondaryButton(
                  label: 'Decline',
                  onPressed: _busy ? null : () => _respond('DECLINE'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AuraSpace.s12),
            const AuraTextBlock(
              'This invite can no longer be accepted.',
              style: AuraText.small,
            ),
          ],
        ],
      ),
    );
  }
}

String _resolveTargetName(Map<String, dynamic> invite) {
  final spaceName = _nested(invite, const [['space', 'title']]);
  if (spaceName.isNotEmpty) return spaceName;
  final threadName = _nested(invite, const [['thread', 'title']]);
  if (threadName.isNotEmpty) return threadName;
  final type = _s(invite, const ['destinationType']).toUpperCase();
  if (type == 'JOIN_AURA') return 'Aura';
  return '';
}

String _outcomeLabel(String destinationType, String role) {
  final roleLabel = role.isNotEmpty ? ' as ${role.toLowerCase()}' : '';
  switch (destinationType) {
    case 'JOIN_AURA':
      return 'Join the Aura platform$roleLabel';
    case 'JOIN_SPACE':
      return 'Join this space$roleLabel';
    case 'JOIN_THREAD':
      return 'Join this thread$roleLabel';
    case 'START_1_TO_1':
      return 'Start a conversation';
    default:
      return roleLabel.isNotEmpty ? 'Join$roleLabel' : '';
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

String _fmtDate(DateTime d) {
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _TerminalCard extends StatelessWidget {
  const _TerminalCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AuraIconSize.xl, color: AuraSurface.muted),
        const SizedBox(height: AuraSpace.s12),
        Text(title, style: AuraText.title),
        const SizedBox(height: AuraSpace.s8),
        AuraTextBlock(body, style: AuraText.body),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AuraSpace.s10),
        Text(label, style: AuraText.body),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return SubstrateChip(label: label, state: SubstrateChipState.mist);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _s(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _nested(Map<String, dynamic> map, List<List<String>> paths) {
  for (final path in paths) {
    dynamic current = map;
    for (final key in path) {
      if (current is Map && current[key] != null) {
        current = current[key];
      } else {
        current = null;
        break;
      }
    }
    final text = (current ?? '').toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _destinationRoute(Map<String, dynamic> invite) {
  final destinationType = _s(invite, const [
    'destinationType',
    'destination_type',
  ]).toUpperCase();
  final spaceId =
      _nested(invite, const [
        ['space', 'id'],
        ['destination', 'spaceId'],
      ]).isNotEmpty
      ? _nested(invite, const [
          ['space', 'id'],
          ['destination', 'spaceId'],
        ])
      : _s(invite, const ['spaceId', 'space_id']);

  final threadId =
      _nested(invite, const [
        ['thread', 'id'],
        ['destination', 'threadId'],
      ]).isNotEmpty
      ? _nested(invite, const [
          ['thread', 'id'],
          ['destination', 'threadId'],
        ])
      : _s(invite, const [
          'threadId',
          'thread_id',
          'destinationId',
          'destination_id',
        ]);

  switch (destinationType) {
    case 'JOIN_THREAD':
    case 'START_1_TO_1':
      if (spaceId.isNotEmpty && threadId.isNotEmpty) {
        return '/me/correspondence/$spaceId/thread/$threadId';
      }
      return '/me/invitations';
    case 'JOIN_SPACE':
      if (spaceId.isNotEmpty) return '/me/correspondence/$spaceId';
      return '/me/correspondence';
    case 'JOIN_AURA':
      return '/home';
    default:
      if (spaceId.isNotEmpty && threadId.isNotEmpty) {
        return '/me/correspondence/$spaceId/thread/$threadId';
      }
      if (spaceId.isNotEmpty) return '/me/correspondence/$spaceId';
      return '/home';
  }
}
