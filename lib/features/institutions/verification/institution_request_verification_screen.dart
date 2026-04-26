import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/document_scaffold.dart';

const String _institutionSignInRoute = '/institution/sign-in';

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

  String? _institutionType;

  bool _submitting = false;
  bool _submitted = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _statusMessage;

  static const _institutionTypes = <String>[
    'Government',
    'University or school',
    'Nonprofit or foundation',
    'Company',
    'Media organization',
    'Research institute',
    'Faith institution',
    'Other',
  ];

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

  String _normalizeDomain(String value) {
    final raw = value.trim().toLowerCase();
    if (raw.isEmpty) return '';

    var cleaned = raw;
    cleaned = cleaned.replaceFirst(RegExp(r'^https?://'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^www\.'), '');
    final slashIndex = cleaned.indexOf('/');
    if (slashIndex >= 0) {
      cleaned = cleaned.substring(0, slashIndex);
    }
    return cleaned.trim();
  }

  String _emailDomain(String email) {
    final clean = email.trim().toLowerCase();
    final at = clean.lastIndexOf('@');
    if (at < 0 || at == clean.length - 1) return '';
    return clean.substring(at + 1).trim();
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
    final institutionType = (_institutionType ?? '').trim();

    if (_submitting || _submitted) return;

    if (firstName.isEmpty || lastName.isEmpty || org.isEmpty || email.isEmpty) {
      setState(() {
        _statusMessage =
            'Representative first name, last name, institution name, and institution email are required.';
      });
      return;
    }

    if (institutionType.isEmpty) {
      setState(() {
        _statusMessage = 'Select an institution type.';
      });
      return;
    }

    if (!_looksLikeEmail(email)) {
      setState(() {
        _statusMessage = 'Enter a valid institution email.';
      });
      return;
    }

    if (website.isNotEmpty) {
      final websiteDomain = _normalizeDomain(website);
      final emailDomain = _emailDomain(email);

      if (websiteDomain.isEmpty) {
        setState(() {
          _statusMessage = 'Enter a valid official website.';
        });
        return;
      }

      if (emailDomain.isNotEmpty && websiteDomain != emailDomain) {
        setState(() {
          _statusMessage =
              'Institution email domain should match the official website domain.';
        });
        return;
      }
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
          'institutionType': institutionType,
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
          : 'Account submitted. Institutional review will proceed offline. Updates will be sent by email.';

      setState(() {
        _submitted = true;
        _statusMessage = message;
      });

      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      context.go(_institutionSignInRoute);
    } on DioException catch (e) {
      if (!mounted) return;

      String message = 'Could not create institutional account.';

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
      padding: EdgeInsets.only(bottom: AuraSpace.s12),
      child: AuraCard(
        child: Text(
          _statusMessage!,
          style: AuraText.body,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: AuraSpace.s10),
      child: Text(
        title,
        style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _formCard() {
    final enabled = !_submitting && !_submitted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Representative'),
        AuraCard(
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
              Divider(height: AuraSpace.s16),
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
              Divider(height: AuraSpace.s16),
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
            ],
          ),
        ),
        SizedBox(height: AuraSpace.s12),
        _sectionTitle('Institution'),
        AuraCard(
          child: Column(
            children: [
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
              Divider(height: AuraSpace.s16),
              DropdownButtonFormField<String>(
                value: _institutionType,
                items: _institutionTypes
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: enabled
                    ? (value) {
                        setState(() {
                          _institutionType = value;
                        });
                      }
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Institution type',
                  border: InputBorder.none,
                ),
              ),
              Divider(height: AuraSpace.s16),
              TextField(
                controller: _website,
                enabled: enabled,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.url,
                inputFormatters: [LengthLimitingTextInputFormatter(180)],
                decoration: const InputDecoration(
                  labelText: 'Official website',
                  hintText: 'https://institution.org',
                  border: InputBorder.none,
                ),
              ),
              Divider(height: AuraSpace.s16),
              TextField(
                controller: _workEmail,
                enabled: enabled,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [LengthLimitingTextInputFormatter(190)],
                decoration: const InputDecoration(
                  labelText: 'Official institution email',
                  hintText: 'name@institution.org',
                  border: InputBorder.none,
                ),
              ),
              Divider(height: AuraSpace.s16),
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
              Divider(height: AuraSpace.s16),
              TextField(
                controller: _purpose,
                enabled: enabled,
                maxLines: 5,
                inputFormatters: [LengthLimitingTextInputFormatter(900)],
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  hintText:
                      'Why is this institution seeking presence inside Aura?',
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AuraSpace.s12),
        _sectionTitle('Institution credentials'),
        AuraCard(
          child: Column(
            children: [
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
              Divider(height: AuraSpace.s16),
              TextField(
                controller: _confirmPassword,
                enabled: enabled,
                textInputAction: TextInputAction.done,
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
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
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
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonLabel = _submitted
        ? 'Account submitted'
        : (_submitting ? 'Submitting...' : 'Create institutional account');

    return DocumentScaffold(
      title: 'Create institutional account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Create institutional account'),
          SizedBox(height: AuraSpace.s10),
          Doc.meta('Institutional entry reviewed before activation.'),
          SizedBox(height: AuraSpace.s12),
          _statusBlock(),
          _formCard(),
          SizedBox(height: AuraSpace.s12),
          SizedBox(
            width: double.infinity,
            child: AuraPrimaryButton(
              label: buttonLabel,
              onPressed: (_submitting || _submitted) ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}