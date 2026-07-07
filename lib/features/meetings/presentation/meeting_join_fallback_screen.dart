import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/guest_shell.dart';

// Graceful recovery for a codeless `/meetings/join` link. Older reminder /
// reschedule / ICS emails shipped a join button WITHOUT the meeting code, which
// used to bounce guests into a login → 404/DioException trap. Those emails are
// already in inboxes, so this screen rescues them: it never login-traps and
// never surfaces a raw error. Because every meeting email prints the code as a
// text line ("Meeting code: XXXX"), the guest can type it here to reach the
// real pre-join flow at `/meetings/join/:code`.
class MeetingJoinFallbackScreen extends StatefulWidget {
  const MeetingJoinFallbackScreen({super.key});

  @override
  State<MeetingJoinFallbackScreen> createState() =>
      _MeetingJoinFallbackScreenState();
}

class _MeetingJoinFallbackScreenState extends State<MeetingJoinFallbackScreen> {
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final code = _codeCtrl.text.trim();
    context.go('/meetings/join/${Uri.encodeComponent(code)}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GuestShell(
      showBackButton: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AuraSpace.s24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.meeting_room_outlined,
                    size: 44,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  Text(
                    'Enter your meeting code',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Text(
                    'Type the meeting code from your invitation, confirmation, '
                    'or reminder email to join.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF9CA3AF),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s24),
                  TextFormField(
                    controller: _codeCtrl,
                    textInputAction: TextInputAction.go,
                    textCapitalization: TextCapitalization.characters,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Meeting code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Enter your meeting code'
                        : null,
                    onFieldSubmitted: (_) => _continue(),
                  ),
                  const SizedBox(height: AuraSpace.s16),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Continue'),
                      onPressed: _continue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
