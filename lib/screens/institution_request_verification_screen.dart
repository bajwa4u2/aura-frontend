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
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _orgName = TextEditingController();
  final _website = TextEditingController();
  final _workEmail = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _roleTitle = TextEditingController();
  final _jurisdiction = TextEditingController();
  final _purpose = TextEditingController();

  bool _submitting = false;
  bool _submitted = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _statusMessage;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _orgName.dispose();
    _website.dispose();
    _workEmail.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _roleTitle.dispose();
    _jurisdiction.dispose();
    _purpose.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String value) {
    final email = value.trim();
    return email.contains('@') && email.contains('.');
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final org = _orgName.text.trim();
    final website = _website.text.trim();
    final email = _workEmail.text.trim().toLowerCase();
    final password = _password.text;
    final confirmPassword = _confirmPassword.text;
    final roleTitle = _roleTitle.text.trim();
    final jurisdiction = _jurisdiction.text.trim();
    final purpose = _purpose.text.trim();

    if (_submitting || _submitted) return;

    if (firstName.isEmpty || lastName.isEmpty || org.isEmpty || email.isEmpty) {
      setState(() {
        _statusMessage =
            'First name, last name, institution name, and institution email are required.';
      });
      return;
    }

    if (!_looksLikeEmail(email)) {
      setState(() {
        _statusMessage = 'Enter a valid institution email.';
      });
      return;
    }

    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _statusMessage = 'Password and confirm password are required.';
      });
      return;
    }

    if (password.length < 8) {
      setState(() {
        _statusMessage = 'Password must be at least 8 characters.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _statusMessage = 'Password and confirm password do not match.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);

      final res = await dio.post(
        '/institutions/verification-request',
        data: {
          'firstName': firstName,
          'lastName': lastName,
          'organizationName': org,
          'websiteUrl': website.isEmpty ? null : website,
          'workEmail': email,
          'password': password,
          'confirmPassword': confirmPassword,
          'roleTitle': roleTitle.isEmpty ? null : roleTitle,
          'jurisdiction': jurisdiction.isEmpty ? null : jurisdiction,
          'purpose': purpose.isEmpty ? null : purpose,
        },
      );

      if (!mounted) return;

      final message = (res.data is Map && res.data['message'] is String)
          ? res.data['message'] as String
          : 'Institution account created and submitted for review.';

      setState(() {
        _submitted = true;
        _statusMessage = message;
      });
    } on DioException catch (e) {
      if (!mounted) return;

      String message = 'Could not create institution account.';

      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        message = data['message'] as String;
      } else if (data is Map &&
          data['message'] is List &&
          (data['message'] as List).isNotEmpty) {
        message = (data['message'] as List).first.toString();
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

  Widget _statusBlock() {
    if (_statusMessage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s12),
      child: Text(
        _statusMessage!,
        style: AuraText.body,
      ),
    );
  }

  Widget _formCard() {
    final enabled = !_submitting && !_submitted;

    return AuraCard(
      child: Column(
        children: [
          TextField(
            controller: _firstName,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            decoration: const InputDecoration(
              labelText: 'First name',
              hintText: 'John',
              border: InputBorder.none,
            ),
          ),
          const Divider(height: AuraSpace.s16),
          TextField(
            controller: _lastName,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            decoration: const InputDecoration(
              labelText: 'Last name',
              hintText: 'Smith',
              border: InputBorder.none,
            ),
          ),
          const Divider(height: AuraSpace.s16),
          TextField(
            controller: _orgName,
            enabled: enabled,
            textInputAction: TextInputAction.next,
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
            enabled: enabled,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.url,
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
            enabled: enabled,
            textInputAction: TextInputAction.next,
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
            controller: _password,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            obscureText: _obscurePassword,
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'At least 8 characters',
              border: InputBorder.none,
              suffixIcon: IconButton(
                onPressed: enabled
                    ? () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      }
                    : null,
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const Divider(height: AuraSpace.s16),
          TextField(
            controller: _confirmPassword,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            obscureText: _obscureConfirmPassword,
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            decoration: InputDecoration(
              labelText: 'Confirm password',
              hintText: 'Re-enter password',
              border: InputBorder.none,
              suffixIcon: IconButton(
                onPressed: enabled
                    ? () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      }
                    : null,
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
              ),
            ),
          ),
          const Divider(height: AuraSpace.s16),
          TextField(
            controller: _roleTitle,
            enabled: enabled,
            textInputAction: TextInputAction.next,
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
            enabled: enabled,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
            decoration: const InputDecoration(
              labelText: 'Jurisdiction or country',
              hintText: 'United States, UK, Pakistan',
              border: InputBorder.none,
            ),
          ),
          const Divider(height: AuraSpace.s16),
          TextField(
            controller: _purpose,
            enabled: enabled,
            maxLines: 5,
            inputFormatters: [LengthLimitingTextInputFormatter(900)],
            decoration: const InputDecoration(
              labelText: 'Purpose',
              hintText: 'Why is this institution joining Aura?',
              border: InputBorder.none,
            ),
          ),
        ],
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
          const SizedBox(height: AuraSpace.s12),
          _statusBlock(),
          _formCard(),
          const SizedBox(height: AuraSpace.s12),
          SizedBox(
            width: double.infinity,
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
    );
  }
}