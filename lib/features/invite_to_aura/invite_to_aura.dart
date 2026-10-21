import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/session_providers.dart';
import '../../core/identity/person_identity_model.dart';
import '../../core/net/dio_provider.dart';
import '../../core/ui/aura_platform_components.dart';
import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';
import '../posts/presentation/widgets/post_card/post_card_utils.dart';

/// INVITE TO AURA — a member's personal link, `auraplatform.org/join/<handle>`.
///
/// Canon amendment 2026-10-20 (aura-backend
/// docs/2026-08-16-aura-invitation-system-canon.md). The link names who
/// invites, so the person invited knows who it is from. Each channel adds
/// `?via=<channel>` so Aura can keep a daily total per channel; nothing records
/// who invited whom, and members are never shown a count.

const String _kInviteBaseUrl = String.fromEnvironment(
  'AURA_SHARE_BASE_URL',
  defaultValue: 'https://auraplatform.org',
);

/// The member's personal link, optionally marked with the channel it travels
/// through.
String inviteToAuraUrl(String handle, {String? via}) {
  final base = _kInviteBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final h = Uri.encodeComponent(handle.trim().toLowerCase());
  final v = (via ?? '').trim();
  return v.isEmpty ? '$base/join/$h' : '$base/join/$h?via=$v';
}

/// The channels the server counts; anything else travels as no channel.
const kInviteChannels = {'link', 'facebook', 'whatsapp', 'linkedin', 'email', 'qr', 'share'};

String? normalizedInviteChannel(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  return kInviteChannels.contains(v) ? v : null;
}

/// Whether the invite sheet offers the device's own share sheet ("Share…").
///
/// iOS, Android and Windows have one (UIActivityViewController, ACTION_SEND,
/// Windows' DataTransferManager). On the web share_plus falls back to a
/// mailto: link wherever navigator.share is missing, which "Share by email"
/// already is, so the web keeps Copy link instead.
bool get inviteHasOsShareSheet =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows);

/// The share sheet behind "Share…"; replaced in tests.
@visibleForTesting
SharePlus inviteSharePlus = SharePlus.instance;

/// WhatsApp's own share page with the message prefilled; the member picks who.
String whatsappShareUrl(String text) =>
    'https://wa.me/?text=${Uri.encodeComponent(text)}';

/// Prompt surfaces, each offered once ever (server-recorded).
enum InvitePromptSurface { feedCard, afterPost, dialog }

extension on InvitePromptSurface {
  String get wire => switch (this) {
        InvitePromptSurface.feedCard => 'FEED_CARD',
        InvitePromptSurface.afterPost => 'AFTER_POST',
        InvitePromptSurface.dialog => 'DIALOG',
      };
}

class InvitePromptState {
  const InvitePromptState({required this.pending, required this.dialogEligible});

  /// Nothing pending: what a failed read means, so a broken request never
  /// shows a prompt twice.
  static const none = InvitePromptState(pending: {}, dialogEligible: false);

  final Set<InvitePromptSurface> pending;
  final bool dialogEligible;

  bool offers(InvitePromptSurface s) =>
      s == InvitePromptSurface.dialog ? dialogEligible : pending.contains(s);

  factory InvitePromptState.fromJson(Map<String, dynamic> json) {
    final raw = (json['pending'] as List?)?.map((e) => '$e').toSet() ?? {};
    return InvitePromptState(
      pending: InvitePromptSurface.values
          .where((s) => raw.contains(s.wire))
          .toSet(),
      dialogEligible: json['dialogEligible'] == true,
    );
  }
}

Map<String, dynamic> _unwrap(dynamic data) {
  if (data is Map && data['data'] is Map) {
    return Map<String, dynamic>.from(data['data'] as Map);
  }
  return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
}

class InviteToAuraClient {
  InviteToAuraClient(this._dio);

  final Dio _dio;

  Future<InvitePromptState> prompts() async {
    try {
      final res = await _dio.get('/invite-to-aura/prompts');
      return InvitePromptState.fromJson(_unwrap(res.data));
    } catch (_) {
      return InvitePromptState.none;
    }
  }

  /// SHOWN, DISMISSED or USED. The first outcome recorded stands.
  Future<void> record(InvitePromptSurface surface, String outcome) async {
    try {
      await _dio.post(
        '/invite-to-aura/prompts/${surface.wire}',
        data: {'outcome': outcome},
      );
    } catch (_) {
      // Best effort. The worst case is that a prompt is offered once more.
    }
  }
}

final inviteToAuraClientProvider = Provider<InviteToAuraClient>(
  (ref) => InviteToAuraClient(ref.watch(dioProvider)),
);

final invitePromptStateProvider = FutureProvider.autoDispose<InvitePromptState>(
  (ref) => ref.watch(inviteToAuraClientProvider).prompts(),
);

/// The signed-in member, as the invite surfaces need them.
AuraPersonIdentity inviterIdentity(WidgetRef ref) =>
    AuraPersonIdentity.fromJson(ref.read(authMeDataProvider).valueOrNull);

/// The invite sheet for whoever is signed in.
Future<void> showInviteToAuraSheetForMe(BuildContext context, WidgetRef ref) {
  final me = inviterIdentity(ref);
  return showInviteToAuraSheet(
    context,
    handle: me.handle,
    displayName: me.displayName,
  );
}

/// The invite sheet. [handle] and [displayName] are the inviting member's.
Future<void> showInviteToAuraSheet(
  BuildContext context, {
  required String handle,
  required String displayName,
}) async {
  if (!context.mounted || handle.trim().isEmpty) return;
  final name = displayName.trim().isEmpty ? '@$handle' : displayName.trim();
  String message(String via) =>
      'I would like you to join me on Aura. ${inviteToAuraUrl(handle, via: via)}';

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AuraSurface.card,
    // A sheet, not a full-height surface: it scrolls inside its own bounds.
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.r14)),
    ),
    builder: (sheetCtx) {
      Future<void> open(String url, String fallback) async {
        await openExternalUrl(sheetCtx, url, fallbackCopyMessage: fallback);
        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
      }

      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s12,
              AuraSpace.s16,
              AuraSpace.s16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AuraSurface.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                const Text('Invite to Aura', style: AuraText.subtitle),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  'Someone opening this link sees that $name invited them, '
                  'what Aura is, and how to join.',
                  style: AuraText.small,
                ),
                const SizedBox(height: AuraSpace.s12),
                SelectableText(
                  inviteToAuraUrl(handle),
                  style: AuraText.small.copyWith(
                    fontFamily: 'monospace',
                    color: AuraSurface.muted,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AuraSpace.s14),
                AuraSecondaryButton(
                  label: 'Copy link',
                  icon: Icons.link_outlined,
                  onPressed: () async {
                    await copyToClipboard(
                      sheetCtx,
                      inviteToAuraUrl(handle, via: 'link'),
                      message: 'Invite link copied',
                    );
                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                  },
                ),
                if (inviteHasOsShareSheet) ...[
                  const SizedBox(height: AuraSpace.s8),
                  // The device's own sheet: messages, mail, any app the member
                  // has. Same words as WhatsApp and email, marked via=share.
                  Builder(
                    builder: (buttonCtx) => AuraSecondaryButton(
                      label: 'Share…',
                      icon: defaultTargetPlatform == TargetPlatform.iOS
                          ? Icons.ios_share
                          : Icons.share_outlined,
                      onPressed: () async {
                        // An iPad shows the sheet as a popover, anchored here;
                        // without an origin it fails to appear at all.
                        final box = buttonCtx.findRenderObject() as RenderBox?;
                        final origin = box != null && box.hasSize
                            ? box.localToGlobal(Offset.zero) & box.size
                            : null;
                        try {
                          await inviteSharePlus.share(
                            ShareParams(
                              text: message('share'),
                              subject: '$name invited you to Aura',
                              sharePositionOrigin: origin,
                            ),
                          );
                        } catch (_) {
                          if (!sheetCtx.mounted) return;
                          await copyToClipboard(
                            sheetCtx,
                            inviteToAuraUrl(handle, via: 'share'),
                            message: 'Sharing is unavailable; invite link copied',
                          );
                        }
                        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                      },
                    ),
                  ),
                ],
                const SizedBox(height: AuraSpace.s8),
                AuraSecondaryButton(
                  label: 'Share to Facebook',
                  icon: Icons.people_outline,
                  onPressed: () => open(
                    facebookShareUrl(inviteToAuraUrl(handle, via: 'facebook')),
                    'Facebook share link copied',
                  ),
                ),
                const SizedBox(height: AuraSpace.s8),
                AuraSecondaryButton(
                  label: 'Share on WhatsApp',
                  icon: Icons.chat_outlined,
                  onPressed: () => open(
                    whatsappShareUrl(message('whatsapp')),
                    'WhatsApp share link copied',
                  ),
                ),
                const SizedBox(height: AuraSpace.s8),
                AuraSecondaryButton(
                  label: 'Share to LinkedIn',
                  icon: Icons.work_outline,
                  onPressed: () => open(
                    linkedInShareUrl(inviteToAuraUrl(handle, via: 'linkedin')),
                    'LinkedIn share link copied',
                  ),
                ),
                const SizedBox(height: AuraSpace.s8),
                AuraSecondaryButton(
                  label: 'Share by email',
                  icon: Icons.email_outlined,
                  onPressed: () => open(
                    'mailto:?subject=${Uri.encodeComponent('$name invited you to Aura')}'
                    '&body=${Uri.encodeComponent(message('email'))}',
                    'Email invite link copied',
                  ),
                ),
                const SizedBox(height: AuraSpace.s8),
                AuraSecondaryButton(
                  label: 'Show QR code',
                  icon: Icons.qr_code_2_outlined,
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    _showInviteQr(context, inviteToAuraUrl(handle, via: 'qr'), name);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _showInviteQr(BuildContext context, String url, String name) {
  if (!context.mounted) return;
  // A plain Dialog, not an AlertDialog: AlertDialog sizes its content by
  // intrinsic width, which the QR painter cannot answer, and the layout
  // failed outright.
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AuraSurface.card,
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Invite to Aura', style: AuraText.subtitle),
            const SizedBox(height: AuraSpace.s12),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AuraSpace.s12),
              child: SizedBox.square(
                dimension: 220,
                child: QrImageView(
                  data: url,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'QR code for $name invitation to Aura',
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s12),
            SizedBox(
              width: 244,
              child: Text(
                'Point a phone camera here to open $name’s invitation.',
                style: AuraText.small,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AuraSpace.s8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The one-time dialog (canon amendment: once ever, only to a member who uses
/// Aura, only on opening Home). Records the outcome whichever button is used.
Future<void> maybeShowInviteDialog(
  BuildContext context,
  WidgetRef ref, {
  required String handle,
  required String displayName,
}) async {
  final state = await ref.read(inviteToAuraClientProvider).prompts();
  if (!state.dialogEligible || !context.mounted) return;
  final client = ref.read(inviteToAuraClientProvider);
  // Recorded before it is shown: a dialog that is closed by leaving the app
  // still counts as its moment.
  await client.record(InvitePromptSurface.dialog, 'SHOWN');
  if (!context.mounted) return;
  final invite = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AuraSurface.card,
      title: const Text('Bring someone to Aura?', style: AuraText.subtitle),
      content: const Text(
        'If there is someone whose voice belongs here, you can share your '
        'personal invitation link with them.',
        style: AuraText.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Maybe later'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Invite'),
        ),
      ],
    ),
  );
  if (invite == true && context.mounted) {
    await showInviteToAuraSheet(context, handle: handle, displayName: displayName);
  }
}

/// The card on an empty or thin Following feed. Hides itself for good once
/// used or dismissed.
class InviteToAuraFeedCard extends ConsumerStatefulWidget {
  const InviteToAuraFeedCard({
    super.key,
    required this.handle,
    required this.displayName,
  });

  final String handle;
  final String displayName;

  @override
  ConsumerState<InviteToAuraFeedCard> createState() =>
      _InviteToAuraFeedCardState();
}

class _InviteToAuraFeedCardState extends ConsumerState<InviteToAuraFeedCard> {
  bool _gone = false;

  Future<void> _close(String outcome) async {
    setState(() => _gone = true);
    await ref
        .read(inviteToAuraClientProvider)
        .record(InvitePromptSurface.feedCard, outcome);
  }

  @override
  Widget build(BuildContext context) {
    if (_gone || widget.handle.trim().isEmpty) return const SizedBox.shrink();
    final state = ref.watch(invitePromptStateProvider).valueOrNull;
    if (state == null || !state.offers(InvitePromptSurface.feedCard)) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AuraSpace.s8),
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aura is better with people you know.', style: AuraText.subtitle),
          const SizedBox(height: AuraSpace.s4),
          const Text(
            'Share your personal link with someone you would like to read and hear here.',
            style: AuraText.small,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              AuraPrimaryButton(
                label: 'Invite someone',
                onPressed: () async {
                  await _close('USED');
                  if (!context.mounted) return;
                  await showInviteToAuraSheet(
                    context,
                    handle: widget.handle,
                    displayName: widget.displayName,
                  );
                },
              ),
              AuraSecondaryButton(
                label: 'Not now',
                onPressed: () => _close('DISMISSED'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The one quiet line after a public post. Shown once ever.
///
/// Takes the app-level [messenger] rather than a screen context: the composer
/// closes as it publishes, so the line and its sheet must outlive it.
Future<void> maybeOfferInviteAfterPost(
  ScaffoldMessengerState messenger,
  InviteToAuraClient client, {
  required String handle,
  required String displayName,
}) async {
  if (handle.trim().isEmpty) return;
  final state = await client.prompts();
  if (!state.offers(InvitePromptSurface.afterPost) || !messenger.mounted) return;
  await client.record(InvitePromptSurface.afterPost, 'SHOWN');
  if (!messenger.mounted) return;
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 8),
      behavior: SnackBarBehavior.floating,
      content: const Text('Know someone who should read this? Invite them to Aura.'),
      action: SnackBarAction(
        label: 'Invite',
        onPressed: () {
          if (messenger.mounted) {
            showInviteToAuraSheet(
              messenger.context,
              handle: handle,
              displayName: displayName,
            );
          }
        },
      ),
    ),
  );
}
