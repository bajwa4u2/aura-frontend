import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/net/dio_provider.dart';
import '../core/ui/aura_card.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class InstitutionRequestVerificationScreen extends StatefulWidget {
  const InstitutionRequestVerificationScreen({super.key});

  @override
  State<InstitutionRequestVerificationScreen> createState() =>
      _InstitutionRequestVerificationScreenState();
}

class _InstitutionRequestVerificationScreenState
    extends State<InstitutionRequestVerificationScreen> {
  final _orgName = TextEditingController();
  final _website = TextEditingController();
  final _workEmail = TextEditingController();
  final _roleTitle = TextEditingController();
  final _jurisdiction = TextEditingController();
  final _purpose = TextEditingController();

  bool _submitting = false;
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

  Future<void> _submit() async {
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

    if (_submitting || _submitted) return;

    setState(() {
      _submitting = true;
    });

    try {
      final dio = createDio();

      final res = await dio.post(
        '/institutions/verification-request',
        data: {
          'organizationName': org,
          'websiteUrl': _website.text.trim().isEmpty ? null : _website.text.trim(),
          'workEmail': email,
          'roleTitle':
              _roleTitle.text.trim().isEmpty ? null : _roleTitle.text.trim(),
          'jurisdiction': _jurisdiction.text.trim().isEmpty
              ? null
              : _jurisdiction.text.trim(),
          'purpose': _purpose.text.trim().isEmpty ? null : _purpose.text.trim(),
        },
      );

      if (!mounted) return;

      final message =
          (res.data is Map && res.data['message'] is String)
              ? res.data['message'] as String
              : 'Verification request saved. We will respond by email.';

      setState(() {
        _submitted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;

      String message = 'Could not submit verification request.';

      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        message = data['message'] as String;
      } else if (data is Map && data['message'] is List && data['message'].isNotEmpty) {
        message = data['message'].first.toString();
      } else if (e.response?.statusCode == 401) {
        message = 'Please sign in before submitting a verification request.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonLabel = _submitted
        ? 'Submitted'
        : (_submitting ? 'Submitting...' : 'Submit request');

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
                  enabled: !_submitting && !_submitted,
                  inputFormatters: [LengthLimitingTextInputFormatter(120)],
                  decoration: const InputDecoration(
                    labelText: 'Organization name',
                    border: InputBorder.none,
                  ),
                ),
                Divider(height: AuraSpace.s16),
                TextField(
                  controller: _website,
                  enabled: !_submitting && !_submitted,
                  inputFormatters: [LengthLimitingTextInputFormatter(180)],
                  decoration: const InputDecoration(
                    labelText: 'Website (optional)',
                    border: InputBorder.none,
                  ),
                ),
                Divider(height: AuraSpace.s16),
                TextField(
                  controller: _workEmail,
                  enabled: !_submitting && !_submitted,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [LengthLimitingTextInputFormatter(190)],
                  decoration: const InputDecoration(
                    labelText: 'Work email (required)',
                    border: InputBorder.none,
                  ),
                ),
                Divider(height: AuraSpace.s16),
                TextField(
                  controller: _roleTitle,
                  enabled: !_submitting && !_submitted,
                  inputFormatters: [LengthLimitingTextInputFormatter(120)],
                  decoration: const InputDecoration(
                    labelText: 'Your role/title (optional)',
                    border: InputBorder.none,
                  ),
                ),
                Divider(height: AuraSpace.s16),
                TextField(
                  controller: _jurisdiction,
                  enabled: !_submitting && !_submitted,
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
              enabled: !_submitting && !_submitted,
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
                  onPressed: (_submitting || _submitted) ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s14,
                      vertical: AuraSpace.s12,
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: AuraText.body.copyWith(color: Colors.white),
                  ),
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