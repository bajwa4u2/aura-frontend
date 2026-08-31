import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error_mapper.dart';
import '../../../core/navigation/canonical_destinations.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/ui/aura_bounded_editor.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/product_feedback_repository.dart';

/// TELLING US SOMETHING.
///
/// Not a support ticket. A support ticket is what you open when you need help
/// and are owed a reply; this is for when you have something to say about the
/// product and want it to reach the people building it.
///
/// The whole screen is one question, a box, and a button. Anything more asks
/// the person to do triage work on our behalf before we have earned it.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _controller = TextEditingController();
  FeedbackIntent _intent = FeedbackIntent.problem;
  bool _sending = false;
  FeedbackRecord? _sent;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final record = await ref.read(productFeedbackRepositoryProvider).submit(
            intent: _intent,
            message: message,
            context: FeedbackContext.from(
              identity: ref.read(feedbackClientIdentityProvider),
              // The PATTERN of where they came from, never the path. The
              // server normalises it again; this is not the place that
              // promise gets to be kept alone.
              surface: _referringPattern(),
              locale: Localizations.maybeLocaleOf(context)?.toLanguageTag(),
            ),
          );
      if (!mounted) return;
      _controller.clear();
      ref.invalidate(myFeedbackProvider);
      setState(() => _sent = record);
    } catch (e) {
      if (!mounted) return;
      final err = AppErrorMapper.from(e, feature: 'send that feedback');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// The screen the person was on before opening this, reduced to a pattern.
  ///
  /// Deliberately coarse: a populated path names a real conversation, so only
  /// the first segment is kept and anything that could be an identifier is
  /// dropped rather than cleverly masked.
  String? _referringPattern() {
    final uri = GoRouterState.of(context).uri;
    final from = uri.queryParameters['from'];
    if (from == null || !from.startsWith('/')) return null;
    final first = from.split('/').where((s) => s.isNotEmpty).firstOrNull;
    return first == null ? '/' : '/$first';
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      title: 'Send feedback',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _sent != null ? _Acknowledgement(record: _sent!) : _form(),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What would you like to tell us?',
          style: AuraText.title.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AuraSpace.s16),

        RadioGroup<FeedbackIntent>(
          groupValue: _intent,
          onChanged: (v) => setState(() => _intent = v ?? _intent),
          child: Column(
            children: [
              for (final intent in FeedbackIntent.values)
                RadioListTile<FeedbackIntent>(
                  value: intent,
                  contentPadding: EdgeInsets.zero,
                  title: Text(intent.label, style: AuraText.body),
                  subtitle: Text(
                    intent.hint,
                    style: AuraText.small.copyWith(color: AuraSurface.muted),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: AuraSpace.s12),
        AuraBoundedEditor(
          builder: (context, scrollController, physics) => TextField(
            scrollController: scrollController,
            scrollPhysics: physics,
            controller: _controller,
            minLines: 5,
            maxLines: 10,
            autofocus: true,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'In your own words',
              hintText: 'What happened, or what you would like to see',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),

        const SizedBox(height: AuraSpace.s16),
        const _ContextDisclosure(),

        const SizedBox(height: AuraSpace.s20),
        Row(
          children: [
            FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send'),
            ),
            const SizedBox(width: AuraSpace.s12),
            TextButton(
              onPressed: () => context.go(NavigationAuthority.myFeedbackRoute),
              child: const Text('What I have sent'),
            ),
          ],
        ),
      ],
    );
  }
}

/// What we attach, said plainly and before they send.
///
/// Disclosure after the fact is not disclosure. This is deliberately a plain
/// list rather than a link to a policy: the person deciding whether to write
/// something honest should be able to see the whole answer without leaving.
class _ContextDisclosure extends StatelessWidget {
  const _ContextDisclosure();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16),
              const SizedBox(width: AuraSpace.s8),
              Text(
                'Sent with your message',
                style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'The app version and build, your platform and OS version, the kind '
            'of screen you came from, and your language. Nothing you have '
            'written or read in Aura — no messages, documents, media or '
            'identity evidence — and no screenshot.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ],
      ),
    );
  }
}

class _Acknowledgement extends StatelessWidget {
  const _Acknowledgement({required this.record});

  final FeedbackRecord record;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: AuraSurface.accentText),
            const SizedBox(width: AuraSpace.s10),
            Text(
              'Thank you — it reached us',
              style: AuraText.title.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s12),
        SelectableText(
          'Your reference is ${record.ref}.',
          style: AuraText.body,
        ),
        const SizedBox(height: AuraSpace.s8),
        // Honest about what happens next, including the part where it might
        // be nothing. Promising a reply we do not always send would be worse
        // than saying so.
        Text(
          'Someone reads every one of these. You will hear back if it changes '
          'something, or when there is nothing further to do — not every piece '
          'of feedback gets a reply.',
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
        const SizedBox(height: AuraSpace.s20),
        Row(
          children: [
            FilledButton(
              onPressed: () => context.go(NavigationAuthority.myFeedbackRoute),
              child: const Text('What I have sent'),
            ),
            const SizedBox(width: AuraSpace.s12),
            TextButton(
              onPressed: () => context.go(memberHomeDestination()),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }
}
