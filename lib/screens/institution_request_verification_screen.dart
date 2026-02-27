import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ui/aura_card.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class InstitutionRequestVerificationScreen extends StatefulWidget {
  const InstitutionRequestVerificationScreen({super.key});

  @override
  State<InstitutionRequestVerificationScreen> createState() => _InstitutionRequestVerificationScreenState();
}

class _InstitutionRequestVerificationScreenState extends State<InstitutionRequestVerificationScreen> {
  final _orgName = TextEditingController();
  final _website = TextEditingController();
  final _workEmail = TextEditingController();
  final _roleTitle = TextEditingController();
  final _jurisdiction = TextEditingController();
  final _purpose = TextEditingController();

  bool _submitted = false;

  @override
  void dispose() {
    _orgName.dispose();
    _website.dispose();
    _workEmail.dispose();
    _roleTitle.dispose();
    _jurisdiction.dispose();
    _purpose.dispose();
    super.dispose();
  }

  void _submit() {
    final org = _orgName.text.trim();
    final email = _workEmail.text.trim();

    if (org.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization name and work email are required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitted = true);

    // NOTE: This is intentionally UI-first.
    // We will wire to a backend endpoint once the institutions verification module is finalized.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification request saved. We will respond by email.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Request verification',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Request verification'),
          const SizedBox(height: 10),
          Doc.meta('For institutions that want to participate as themselves.'),
          Doc.lede(
              'Verification is not a badge. It is a structural commitment to visible correction, continuity of record, and accountable institutional speech.',
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraCard(
            child: Column(
              children: [
                TextField(
                  controller: _orgName,
                  inputFormatters: [LengthLimitingTextInputFormatter(120)],
                  decoration: const InputDecoration(
                    labelText: 'Organization name',
                    border: InputBorder.none,
                  ),
                ),
                Divider(height: AuraSpace.s16),
                TextField(
                  controller: _website,
                  inputFormatters: [LengthLimitingTextInputFormatter(180)],
                  decoration: const InputDecoration(
                    labelText: 'Website (optional)',
                    border: InputBorder.none,
                  ),
                ),
                Divider(height: AuraSpace.s16),
                TextField(
                  controller: _workEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Work email (required)',
                    border: InputBorder.none,
                  ),
                ),
                Divider(height: AuraSpace.s16),
                TextField(
                  controller: _roleTitle,
                  inputFormatters: [LengthLimitingTextInputFormatter(120)],
                  decoration: const InputDecoration(
                    labelText: 'Your role/title (optional)',
                    border: InputBorder.none,
                  ),
                ),
                Divider(height: AuraSpace.s16),
                TextField(
                  controller: _jurisdiction,
                  inputFormatters: [LengthLimitingTextInputFormatter(120)],
                  decoration: const InputDecoration(
                    labelText: 'Jurisdiction / country (optional)',
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          AuraCard(
            child: TextField(
              controller: _purpose,
              maxLines: 6,
              inputFormatters: [LengthLimitingTextInputFormatter(900)],
              decoration: const InputDecoration(
                labelText: 'What draws you to participate here (optional)',
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _submitted ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text(_submitted ? 'Submitted' : 'Submit request', style: AuraText.body.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Doc.p(
            'This is an application lane, not a marketing lane. Verification may take time. Requests that read like PR pitches will not be accepted.',
          ),
        ],
      ),
    );
  }
}
