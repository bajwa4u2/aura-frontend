part of 'external_area.dart';

// ── Actions ──────────────────────────────────────────────────────────────
//
// Every write goes through here, and every one ends by invalidating the list.
// A screen that repaints what it did BEFORE the server agreed is a screen that
// lies when the server refuses.

Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final webhook = TextEditingController();
  final scopes = <String>{'MEETINGS_READ', 'MEETINGS_WRITE'};
  var certification = false;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Admit an external system'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  helperText: 'What an operator will recognise it by',
                ),
              ),
              const SizedBox(height: AuraSpace.s12),
              TextField(
                controller: webhook,
                decoration: const InputDecoration(
                  labelText: 'Webhook URL (optional)',
                  helperText: 'Where Aura delivers signed events. HTTPS only.',
                ),
              ),
              const SizedBox(height: AuraSpace.s16),
              Text('Scopes', style: Theme.of(ctx).textTheme.labelLarge),
              // TENANTS_PROVISION is separate from MEETINGS_WRITE on purpose:
              // creating a meeting acts under an authority that already
              // exists, while creating a tenant CREATES the authority.
              for (final s in const [
                'MEETINGS_READ',
                'MEETINGS_WRITE',
                'TENANTS_PROVISION',
              ])
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: scopes.contains(s),
                  title: Text(s),
                  onChanged: (v) => setState(
                    () => v == true ? scopes.add(s) : scopes.remove(s),
                  ),
                ),
              const Divider(),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: certification,
                title: const Text('Controlled certification'),
                subtitle: const Text(
                  'Excluded from every commercial total. Not a customer, not '
                  'revenue, not adoption.',
                ),
                onChanged: (v) => setState(() => certification = v == true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Admit and issue credential'),
          ),
        ],
      ),
    ),
  );

  if (go != true || !context.mounted) return;
  if (name.text.trim().isEmpty || scopes.isEmpty) return;

  await _run(context, ref, () async {
    final created = await ref.read(operatorExternalRepositoryProvider).create(
          displayName: name.text.trim(),
          scopes: scopes.toList(),
          webhookUrl: webhook.text,
          isControlledCertification: certification,
        );
    if (context.mounted) await _showOnce(context, created.showOnce);
  });
}

Future<void> _openTenant(
  BuildContext context,
  WidgetRef ref,
  String consumerId,
) async {
  final externalRef = TextEditingController();
  final name = TextEditingController();

  final go = await _form(
    context,
    title: 'Provision a customer',
    confirm: 'Provision',
    fields: [
      TextField(
        controller: externalRef,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Reference',
          helperText: "The consumer's own identifier for this customer",
        ),
      ),
      TextField(
        controller: name,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
    ],
  );

  if (go != true || !context.mounted) return;
  if (externalRef.text.trim().isEmpty || name.text.trim().isEmpty) return;

  await _run(context, ref, () async {
    await ref.read(operatorExternalRepositoryProvider).provisionTenant(
          consumerId: consumerId,
          externalRef: externalRef.text.trim(),
          displayName: name.text.trim(),
        );
    ref.invalidate(operatorExternalTenantsProvider(consumerId));
  });
}

Future<void> _openIdentity(
  BuildContext context,
  WidgetRef ref,
  String consumerId,
  String tenantRef,
) async {
  final address = TextEditingController();
  final host = TextEditingController();
  final title = TextEditingController();

  final go = await _form(
    context,
    title: 'Add a bookable address',
    confirm: 'Provision address',
    fields: [
      TextField(
        controller: address,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Address',
          // Refused if taken, never silently suffixed: an address the consumer
          // did not ask for is one it will not recognise in its own records.
          helperText: 'e.g. acme-sales. Permanent, and never reissued.',
        ),
      ),
      TextField(
        controller: host,
        decoration: const InputDecoration(
          labelText: 'Assigned host user id',
          helperText: 'The Aura member who will actually hold these meetings',
        ),
      ),
      TextField(
        controller: title,
        decoration: const InputDecoration(labelText: 'Meeting title (optional)'),
      ),
    ],
  );

  if (go != true || !context.mounted) return;
  if (address.text.trim().isEmpty || host.text.trim().isEmpty) return;

  await _run(context, ref, () async {
    await ref.read(operatorExternalRepositoryProvider).provisionIdentity(
          consumerId: consumerId,
          tenantRef: tenantRef,
          address: address.text.trim(),
          assignedHostUserId: host.text.trim(),
          meetingTitle: title.text,
        );
    ref.invalidate(operatorExternalTenantsProvider(consumerId));
  });
}

Future<void> _openWebhook(
  BuildContext context,
  WidgetRef ref,
  String consumerId,
) async {
  final url = TextEditingController();

  final go = await _form(
    context,
    title: 'Webhook destination',
    confirm: 'Set and mint signing secret',
    fields: [
      TextField(
        controller: url,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'HTTPS URL',
          // Deliberate: a destination change is exactly when a signing secret
          // should not be carried over.
          helperText: 'Setting this mints a NEW signing secret, shown once.',
        ),
      ),
    ],
  );

  if (go != true || !context.mounted) return;

  await _run(context, ref, () async {
    final once = await ref.read(operatorExternalRepositoryProvider).setWebhook(
          consumerId: consumerId,
          webhookUrl: url.text.trim().isEmpty ? null : url.text.trim(),
        );
    if (context.mounted && once.hasAnything) await _showOnce(context, once);
  });
}

Future<void> _openRotate(
  BuildContext context,
  WidgetRef ref,
  ExternalConsumerRow consumer,
) async {
  final current = consumer.activeCredential;

  final go = await _form(
    context,
    title: 'Rotate credential',
    confirm: 'Issue new credential',
    fields: const [
      Text(
        'A new credential is issued with the same scopes. The current one KEEPS '
        'WORKING until you revoke it, so the customer can install the new one '
        'before the old one stops.',
      ),
    ],
  );

  if (go != true || !context.mounted) return;

  await _run(context, ref, () async {
    final once = await ref.read(operatorExternalRepositoryProvider).rotate(
          consumerId: consumer.id,
          scopes: current?.scopes ?? const ['MEETINGS_READ', 'MEETINGS_WRITE'],
          supersedesCredentialId: current?.id,
        );
    if (context.mounted) await _showOnce(context, once);
  });
}

Future<void> _confirmRevoke(
  BuildContext context,
  WidgetRef ref,
  ExternalConsumerRow consumer,
  ExternalCredentialRow credential,
) async {
  final go = await _form(
    context,
    title: 'Revoke this credential?',
    confirm: 'Revoke',
    fields: [
      Text(
        'The system holding ${credential.keyId} stops being able to create '
        'meetings or read participation, immediately. Meetings it already '
        'created are unaffected.',
      ),
    ],
  );

  if (go != true || !context.mounted) return;

  await _run(context, ref, () async {
    await ref.read(operatorExternalRepositoryProvider).revoke(
          consumerId: consumer.id,
          credentialId: credential.id,
        );
  });
}

Future<void> _setStatus(
  BuildContext context,
  WidgetRef ref,
  ExternalConsumerRow consumer,
  String status,
) async {
  await _run(context, ref, () async {
    await ref
        .read(operatorExternalRepositoryProvider)
        .setStatus(consumerId: consumer.id, status: status);
  });
}

// ── Plumbing ─────────────────────────────────────────────────────────────

/// Runs a write and reports what happened. The list is invalidated on SUCCESS
/// only — a failed write must not repaint the screen as if something changed.
Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  try {
    await action();
    ref.invalidate(operatorExternalConsumersProvider);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_message(e))),
    );
  }
}

/// The server's own words wherever it has them.
///
/// Its refusals are written to be read by whoever must act on them — "that
/// address belongs to someone else... choose another" — and replacing that
/// with "Request failed" throws away the only part that helps.
String _message(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
      if (data['message'] is String) return data['message'] as String;
    }
  }
  return 'That did not go through. Nothing was changed.';
}

Future<bool?> _form(
  BuildContext context, {
  required String title,
  required String confirm,
  required List<Widget> fields,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final f in fields) ...[f, const SizedBox(height: AuraSpace.s12)],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
}

/// THE ONE TIME THESE VALUES EXIST.
///
/// Aura keeps the API secret as a hash and seals the signing secret, so a
/// dialog closed early does not lose A copy — it loses the ONLY copy there
/// will ever be, and the remedy is a rotation that invalidates whatever the
/// customer was already given.
///
/// That was the case for making it undismissable, and the product rule
/// overrules it: the undismissable form is right exactly once, on the
/// terminal acknowledgement after an account has been deleted, where "did you
/// mean to dismiss that" is not a question worth asking. Here it is worth
/// asking — the remedy exists, it is one rotation away, and a trap is worse
/// than a re-issue. The prominent way out still says "I have copied these".
Future<void> _showOnce(BuildContext context, ExternalShowOnce once) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Copy these now'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              once.notice ?? 'These are shown once. Aura cannot show them again.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AuraSpace.s16),
            if (once.bearer != null)
              _Secret(label: 'API credential (Bearer)', value: once.bearer!),
            if (once.webhookSigningSecret != null) ...[
              const SizedBox(height: AuraSpace.s12),
              _Secret(
                label: 'Webhook signing secret',
                value: once.webhookSigningSecret!,
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('I have copied these'),
        ),
      ],
    ),
  );
}

class _Secret extends StatelessWidget {
  const _Secret({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: AuraSpace.s4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AuraSpace.s12),
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.r10),
          ),
          child: Row(
            children: [
              Expanded(
                // Selectable AS WELL AS copyable: a copy button that silently
                // fails leaves nothing behind, and this value cannot be
                // fetched again.
                child: SelectableText(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
