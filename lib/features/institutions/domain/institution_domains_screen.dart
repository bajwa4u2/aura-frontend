import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../ui/institution_ds.dart';
import 'institution_domains_providers.dart';
import 'institution_domains_repository.dart';

class InstitutionDomainsScreen extends ConsumerStatefulWidget {
  const InstitutionDomainsScreen({super.key});

  @override
  ConsumerState<InstitutionDomainsScreen> createState() =>
      _InstitutionDomainsScreenState();
}

class _InstitutionDomainsScreenState
    extends ConsumerState<InstitutionDomainsScreen> {
  bool loading = true;
  bool _submitting = false;

  List<Map<String, dynamic>> domains = <Map<String, dynamic>>[];
  Map<String, dynamic>? institution;
  String? institutionState;
  String? loadError;

  final TextEditingController domainController = TextEditingController();
  Timer? verifyTimer;

  InstitutionDomainsRepository get repo =>
      ref.read(institutionDomainsRepositoryProvider);

  String get institutionId => institution?['id']?.toString() ?? '';

  bool get canManageDomains => institutionId.isNotEmpty;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _dioMessage(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;

      if (data is Map && data['message'] != null) {
        final message = data['message'].toString().trim();
        if (message.isNotEmpty) return message;
      }

      if (data is Map &&
          data['error'] is Map &&
          data['error']['message'] != null) {
        final message = data['error']['message'].toString().trim();
        if (message.isNotEmpty) return message;
      }

      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
    }

    return fallback;
  }

  Future<void> loadDomains({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }

    try {
      final stateData = await repo.getMyInstitutionState();
      final stateName = stateData['state']?.toString();
      final membership = stateData['membership'];

      Map<String, dynamic>? resolvedInstitution;
      if (membership is Map && membership['institution'] is Map) {
        resolvedInstitution = Map<String, dynamic>.from(
          membership['institution'] as Map,
        );
      }

      if (resolvedInstitution == null ||
          (resolvedInstitution['id']?.toString().isEmpty ?? true)) {
        setState(() {
          institution = null;
          institutionState = stateName;
          domains = <Map<String, dynamic>>[];
          loading = false;
          loadError = null;
        });
        return;
      }

      final id = resolvedInstitution['id'].toString();
      final domainList = await repo.getDomains(id);

      setState(() {
        institution = resolvedInstitution;
        institutionState = stateName;
        domains = domainList;
        loading = false;
        loadError = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        loadError = _dioMessage(e, 'Could not load institution domains.');
      });
      _showSnack(loadError!);
    }
  }

  Future<void> addDomain() async {
    final domain = domainController.text.trim();

    if (domain.isEmpty) {
      _showSnack('Enter a domain first.');
      return;
    }

    if (!canManageDomains) {
      _showSnack(
        'No verified institutional membership is active for this account yet.',
      );
      return;
    }

    if (_submitting) return;

    try {
      setState(() => _submitting = true);

      await repo.addDomain(institutionId, domain);

      domainController.clear();
      _showSnack('Domain added.');
      await loadDomains(silent: true);
    } catch (e) {
      _showSnack(_dioMessage(e, 'Could not add domain.'));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> removeDomain(String domainId) async {
    if (!canManageDomains) {
      _showSnack('No active institution found for domain management.');
      return;
    }

    try {
      await repo.removeDomain(institutionId, domainId);
      _showSnack('Domain removed.');
      await loadDomains(silent: true);
    } catch (e) {
      _showSnack(_dioMessage(e, 'Could not remove domain.'));
    }
  }

  Future<void> issueChallenge(String domainId) async {
    if (!canManageDomains) {
      _showSnack('No active institution found for domain management.');
      return;
    }

    try {
      final verification = await repo.issueDnsChallenge(
        institutionId,
        domainId,
      );

      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('DNS verification'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create the following TXT record in your DNS:'),
                const SizedBox(height: AuraSpace.s10),
                _copyRow(
                  'Record name',
                  verification['recordName']?.toString() ?? '',
                ),
                _copyRow(
                  'Record type',
                  verification['recordType']?.toString() ?? 'TXT',
                ),
                _copyRow(
                  'Record value',
                  verification['value']?.toString() ?? '',
                ),
                const SizedBox(height: AuraSpace.s12),
                const Text(
                  'After adding the record, click Verify. DNS propagation may take a few minutes.',
                ),
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: 8,
                  children: [
                    AuraGhostButton(
                      label: 'Cloudflare',
                      onPressed: () => _openDnsProvider('cloudflare'),
                    ),
                    AuraGhostButton(
                      label: 'GoDaddy',
                      onPressed: () => _openDnsProvider('godaddy'),
                    ),
                    AuraGhostButton(
                      label: 'Namecheap',
                      onPressed: () => _openDnsProvider('namecheap'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              AuraGhostButton(
                label: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        },
      );

      await loadDomains(silent: true);
    } catch (e) {
      _showSnack(_dioMessage(e, 'Could not issue DNS challenge.'));
    }
  }

  Future<void> verifyDomain(String domainId) async {
    if (!canManageDomains) {
      _showSnack('No active institution found for domain management.');
      return;
    }

    try {
      final verified = await repo.verifyDomain(institutionId, domainId);

      _showSnack(
        verified ? 'Domain verified successfully.' : 'DNS record not found.',
      );

      await loadDomains(silent: true);

      if (verified) {
        verifyTimer?.cancel();
      }
    } catch (e) {
      _showSnack(_dioMessage(e, 'Could not verify domain.'));
    }
  }

  void startAutoVerify(String domainId) {
    verifyTimer?.cancel();
    _showSnack('Auto verify started. Checking every 30 seconds.');

    verifyTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => verifyDomain(domainId),
    );
  }

  Widget _copyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: SelectableText('$label: $value')),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: value.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: value));
                    _showSnack('$label copied.');
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _openDnsProvider(String provider) async {
    String? url;

    switch (provider) {
      case 'cloudflare':
        url = 'https://dash.cloudflare.com';
        break;
      case 'godaddy':
        url = 'https://dcc.godaddy.com/manage';
        break;
      case 'namecheap':
        url = 'https://ap.www.namecheap.com/domains/list/';
        break;
    }

    if (url == null) return;

    final uri = Uri.parse(url);
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );

    if (!opened) {
      await Clipboard.setData(ClipboardData(text: url));
      _showSnack('Link copied. Open it in your browser.');
    }
  }

  Widget buildDomainCard(Map<String, dynamic> d) {
    final id = d['id']?.toString() ?? '';
    final domain = d['domain']?.toString() ?? '';
    final status = d['status']?.toString() ?? 'UNKNOWN';
    final trustLevel = d['trustLevel']?.toString() ?? '';
    final verifiedAt = d['verifiedAt']?.toString() ?? '';
    final isPrimary = d['isPrimary'] == true;
    final isVerified = status == 'VERIFIED';

    Color statusColor;
    if (isVerified) {
      statusColor = const Color(0xFF5FD99A);
    } else if (status == 'CHALLENGE_ISSUED') {
      statusColor = const Color(0xFF6BAEED);
    } else {
      statusColor = const Color(0xFFEDC264);
    }

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  domain,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: AuraText.small.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          if (isPrimary)
            Text(
              'Primary domain',
              style: AuraText.small.copyWith(color: AuraText.small.color),
            ),
          if (trustLevel.isNotEmpty && isVerified)
            Text(
              'Trust: $trustLevel',
              style: AuraText.small,
            ),
          if (verifiedAt.isNotEmpty)
            Text(
              'Verified: $verifiedAt',
              style: AuraText.small,
            ),
          const SizedBox(height: AuraSpace.s12),
          if (isVerified)
            Wrap(
              spacing: AuraSpace.s8,
              children: [
                AuraSecondaryButton(
                  label: 'Remove',
                  onPressed: () => removeDomain(id),
                ),
              ],
            )
          else
            Wrap(
              spacing: AuraSpace.s8,
              runSpacing: AuraSpace.s8,
              children: [
                AuraSecondaryButton(
                  label: 'DNS challenge',
                  onPressed: () => issueChallenge(id),
                ),
                AuraSecondaryButton(
                  label: 'Verify',
                  onPressed: () => verifyDomain(id),
                ),
                AuraSecondaryButton(
                  label: 'Auto verify',
                  onPressed: () => startAutoVerify(id),
                ),
                AuraSecondaryButton(
                  label: 'Remove',
                  onPressed: () => removeDomain(id),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final name = institution?['name']?.toString() ?? 'Institution';
    final slug = institution?['slug']?.toString() ?? '';

    if (canManageDomains) {
      return AuraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AuraSpace.s8),
            if (slug.isNotEmpty) Text('Slug: $slug'),
            if (institutionState != null && institutionState!.isNotEmpty)
              Text('Standing: $institutionState'),
          ],
        ),
      );
    }

    String message =
        'No verified institutional membership is active for this account yet.';

    if (institutionState == 'PENDING_REQUEST') {
      message =
          'Your institutional request is still in progress. Domains can be managed after membership becomes active.';
    } else if (institutionState == 'SIGNED_IN_NO_STANDING') {
      message =
          'This account is signed in, but it does not currently hold institutional standing.';
    } else if (institutionState == 'REJECTED') {
      message =
          'This institutional request was rejected. Domain management is not available on this account.';
    } else if (institutionState == 'SUSPENDED') {
      message =
          'This institutional standing is suspended. Domain management is temporarily unavailable.';
    }

    return AuraCard(child: Text(message));
  }

  Widget _emptyState() {
    return const InsEmptyState(
      icon: Icons.domain_outlined,
      title: 'No domains added yet',
      description:
          'Add your institution’s web domains and verify ownership to strengthen public trust.',
    );
  }

  @override
  void initState() {
    super.initState();
    loadDomains();
  }

  @override
  void dispose() {
    verifyTimer?.cancel();
    domainController.dispose();
    super.dispose();
  }

  void _focusAddDomainField() {
    if (canManageDomains && !_submitting) {
      // No explicit FocusNode is wired up; the form sits directly below the
      // mode header so a scroll-into-view is sufficient. The user types into
      // the existing input.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraScaffold(
      showHeader: false,
      body: InsScreen(
        children: [
          InsModeHeader(
            title: 'Domains & Trust',
            description:
                'Verify institutional web domains and strengthen public trust.',
            primaryAction: AuraPrimaryButton(
              label: _submitting ? 'Adding…' : 'Add domain',
              icon: Icons.add_rounded,
              onPressed: (_submitting || !canManageDomains) ? null : addDomain,
            ),
          ),
          const InsModeHeaderGap(),

          _statusCard(),
          const SizedBox(height: AuraSpace.s12),

          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add domain',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AuraSpace.s10),
                TextField(
                  controller: domainController,
                  enabled: canManageDomains && !_submitting,
                  decoration: InputDecoration(
                    hintText: 'example.org',
                    helperText: canManageDomains
                        ? 'Enter only the domain name. Use the action above to add.'
                        : 'Domain management becomes active once institutional membership is active.',
                  ),
                  onTap: _focusAddDomainField,
                  onSubmitted: (_) {
                    if (canManageDomains && !_submitting) {
                      addDomain();
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AuraSpace.s12),

          if (loading)
            const Center(child: AuraLoadingState(message: 'Loading domains…'))
          else if (loadError != null)
            InsEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load domains',
              description: loadError!,
              tone: InsTone.danger,
            )
          else if (!canManageDomains)
            const SizedBox.shrink()
          else if (domains.isEmpty)
            _emptyState()
          else
            ...domains.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                child: buildDomainCard(d),
              ),
            ),
        ],
      ),
    );
  }
}
