import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/net/dio_provider.dart';
import '../core/ui/aura_card.dart';
import '../core/ui/aura_space.dart';
import '../core/ui/aura_text.dart';
import '../core/ui/document_scaffold.dart';

class InstitutionRequestVerificationScreen extends ConsumerStatefulWidget {
  const InstitutionRequestVerificationScreen({super.key});

  @override
  ConsumerState<InstitutionRequestVerificationScreen> createState() =>
      _InstitutionRequestVerificationScreenState();
}

class _InstitutionRequestVerificationScreenState
    extends ConsumerState<InstitutionRequestVerificationScreen> {
  final _orgName = TextEditingController();
  final _website = TextEditingController();
  final _workEmail = TextEditingController();
  final _roleTitle = TextEditingController();
  final _jurisdiction = TextEditingController();
  final _purpose = TextEditingController();

  bool _submitting = false;
  bool _submitted = false;
  String? _statusMessage;

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
    FocusScope.of(context).unfocus();

    final org = _orgName.text.trim();
    final email = _workEmail.text.trim().toLowerCase();

    if (org.isEmpty || email.isEmpty) {
      setState(() {
        _statusMessage = 'Institution name and institution email are required.';
      });
      return;
    }

    if (!email.contains('@')) {
      setState(() {
        _statusMessage = 'Enter a valid institution email.';
      });
      return;
    }

    if (_submitting || _submitted) return;

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);

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
              : 'Institution account request submitted.';

      setState(() {
        _submitted = true;
        _statusMessage = message;
      });
    } on DioException catch (e) {
      if (!mounted) return;

      String message = 'Could not submit institution request.';

      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        message = data['message'] as String;
      } else if (data is Map &&
          data['message'] is List &&
          (data['message'] as List).isNotEmpty) {
        message = (data['message'] as List).first.toString();
      } else if (e.response?.statusCode == 401) {
        message = 'Please sign in before creating an institution account.';
      }

      setState(() {
        _statusMessage = message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _statusMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
    }
  }

  Widget _statusCard() {
    if (_statusMessage == null) return const SizedBox.shrink();

    return Column(
      children: [
        AuraCard(
          child: Text(_statusMessage!, style: AuraText.body),
        ),
        const SizedBox(height: AuraSpace.s12),
      ],
    );
  }

  Widget _identityCard() {
    return AuraCard(
      child: Column(
        children: [
          TextField(
            controller: _orgName,
            enabled: !_submitting && !_submitted,
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            decoration: const InputDecoration(
              labelText: 'Institution name',
              hintText: 'Aura Platform LLC',
              border: InputBorder.none,
            ),
          ),
          const Divider(height: AuraSpace.s16),
          TextField(
            controller: _website,
            enabled: !_submitting && !_submitted,
            inputFormatters: [LengthLimitingTextInputFormatter(180)],
            decoration: const InputDecoration(
              labelText: 'Website',
              hintText: 'https://institution.org',
              border: InputBorder.none,
            ),
          ),
          const Divider(height: AuraSpace.s16),
          TextField(
            controller: _workEmail,
            enabled: !_submitting && !_submitted,
            keyboardType: TextInputType.emailAddress,
            inputFormatters: [LengthLimitingTextInputFormatter(190)],
            decoration: const InputDecoration(
              labelText: 'Institution email',
              hintText: 'name@institution.org',
              border: InputBorder.none,
            ),
          ),
          const Divider(height: AuraSpace.s16),
          TextField(
            controller: _roleTitle,
            enabled: !_submitting && !_submitted,
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            decoration: const InputDecoration(
              labelText: 'Role or title',
              hintText: 'Founder, Director, Policy Lead',
              border: InputBorder.none,
            ),
          ),
          const Divider(height: AuraSpace.s16),
          TextField(
            controller: _jurisdiction,
            enabled: !_submitting && !_submitted,
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            decoration: const InputDecoration(
              labelText: 'Jurisdiction or country',
              hintText: 'United States, UK, Pakistan',
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _purposeCard() {
    return AuraCard(
      child: TextField(
        controller: _purpose,
        enabled: !_submitting && !_submitted,
        maxLines: 5,
        inputFormatters: [LengthLimitingTextInputFormatter(900)],
        decoration: const InputDecoration(
          labelText: 'Purpose',
          hintText: 'Why should this institution participate here?',
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonLabel = _submitted
        ? 'Submitted'
        : (_submitting ? 'Submitting...' : 'Create institution account');

    return DocumentScaffold(
      title: 'Create institution account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Create institution account'),
          const SizedBox(height: 10),
          Doc.meta('Institution registration and review.'),
          Doc.lede(
            'Institutions enter through a separate lane.',
          ),
          const SizedBox(height: AuraSpace.s12),
          _statusCard(),
          _identityCard(),
          const SizedBox(height: AuraSpace.s12),
          _purposeCard(),
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
            'Submission starts review and verification.',
          ),
        ],
      ),
    );
  }
}