import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/document_scaffold.dart';
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
  List<Map<String, dynamic>> domains = <Map<String, dynamic>>[];
  Map<String, dynamic>? institution;

  final TextEditingController domainController = TextEditingController();

  Timer? verifyTimer;
  bool _submitting = false;

  String get institutionId => institution?['id']?.toString() ?? '';

  InstitutionDomainsRepository get repo =>
      ref.read(institutionDomainsRepositoryProvider);

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> loadDomains() async {
    try {
      final inst = await repo.getMyInstitution();

      if (inst == null) {
        setState(() {
          institution = null;
          domains = [];
          loading = false;
        });
        return;
      }

      final id = inst['id'].toString();
      final domainList = await repo.getDomains(id);

      setState(() {
        institution = inst;
        domains = domainList;
        loading = false;
      });
    } catch (e) {
      loading = false;
      _showSnack('Could not load institution domains.');
      setState(() {});
    }
  }

  Future<void> addDomain() async {
    final domain = domainController.text.trim();
    if (domain.isEmpty || institutionId.isEmpty || _submitting) return;

    try {
      setState(() => _submitting = true);

      await repo.addDomain(institutionId, domain);

      domainController.clear();
      _showSnack('Domain added.');
      await loadDomains();
    } catch (e) {
      _showSnack('Could not add domain.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> removeDomain(String domainId) async {
    try {
      await repo.removeDomain(institutionId, domainId);
      _showSnack('Domain removed.');
      await loadDomains();
    } catch (e) {
      _showSnack('Could not remove domain.');
    }
  }

  Future<void> issueChallenge(String domainId) async {
    try {
      final verification = await repo.issueDnsChallenge(institutionId, domainId);

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
                SizedBox(height: AuraSpace.s10),
                _copyRow('Record name', verification['recordName'] ?? ''),
                _copyRow('Record type', verification['recordType'] ?? 'TXT'),
                _copyRow('Record value', verification['value'] ?? ''),
                SizedBox(height: AuraSpace.s12),
                const Text(
                    'After adding the record, click Verify. DNS propagation may take a few minutes.'),
                SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                        onPressed: () => _openDnsProvider('cloudflare'),
                        child: const Text('Cloudflare')),
                    TextButton(
                        onPressed: () => _openDnsProvider('godaddy'),
                        child: const Text('GoDaddy')),
                    TextButton(
                        onPressed: () => _openDnsProvider('namecheap'),
                        child: const Text('Namecheap')),
                  ],
                )
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
            ],
          );
        },
      );

      await loadDomains();
    } catch (e) {
      _showSnack('Could not issue DNS challenge.');
    }
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
          )
        ],
      ),
    );
  }

  void _openDnsProvider(String provider) {
    switch (provider) {
      case 'cloudflare':
        html.window.open('https://dash.cloudflare.com', '_blank');
        break;
      case 'godaddy':
        html.window.open('https://dcc.godaddy.com/manage', '_blank');
        break;
      case 'namecheap':
        html.window.open(
            'https://ap.www.namecheap.com/domains/list/', '_blank');
        break;
    }
  }

  Future<void> verifyDomain(String domainId) async {
    try {
      final verified = await repo.verifyDomain(institutionId, domainId);

      _showSnack(
          verified ? 'Domain verified successfully.' : 'DNS record not found.');

      await loadDomains();

      if (verified) {
        verifyTimer?.cancel();
      }
    } catch (e) {
      _showSnack('Could not verify domain.');
    }
  }

  void startAutoVerify(String domainId) {
    verifyTimer?.cancel();

    _showSnack('Auto verify started. Checking every 30 seconds.');

    verifyTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => verifyDomain(domainId));
  }

  @override
  void dispose() {
    verifyTimer?.cancel();
    domainController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadDomains();
  }

  Widget buildDomainCard(Map<String, dynamic> d) {
    final id = d['id']?.toString() ?? '';
    final domain = d['domain'] ?? '';
    final status = d['status'] ?? 'UNKNOWN';
    final trustLevel = d['trustLevel'] ?? '';
    final verifiedAt = d['verifiedAt'] ?? '';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(domain,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: AuraSpace.s8),
          Text('Status: $status'),
          if (trustLevel.isNotEmpty) Text('Trust: $trustLevel'),
          if (verifiedAt.isNotEmpty) Text('Verified at: $verifiedAt'),
          SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            children: [
              ElevatedButton(
                  onPressed: () => issueChallenge(id),
                  child: const Text('DNS challenge')),
              ElevatedButton(
                  onPressed: () => verifyDomain(id),
                  child: const Text('Verify')),
              ElevatedButton(
                  onPressed: () => startAutoVerify(id),
                  child: const Text('Auto verify')),
              OutlinedButton(
                  onPressed: () => removeDomain(id),
                  child: const Text('Remove')),
            ],
          )
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const AuraCard(child: Text('No domains added yet.'));
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Institution domains',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Institution domains'),
          SizedBox(height: AuraSpace.s10),
          Doc.meta('DNS verification and domain ownership.'),
          Doc.lede('Attach and verify domains owned by the institution.'),
          SizedBox(height: AuraSpace.s12),

          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add domain',
                    style:
                        AuraText.body.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: AuraSpace.s10),
                TextField(
                  controller: domainController,
                  decoration: const InputDecoration(hintText: 'example.org'),
                ),
                SizedBox(height: AuraSpace.s10),
                ElevatedButton(
                    onPressed: _submitting ? null : addDomain,
                    child: Text(_submitting ? 'Adding...' : 'Add domain')),
              ],
            ),
          ),

          SizedBox(height: AuraSpace.s12),

          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (domains.isEmpty)
            _emptyState()
          else
            ...domains.map(buildDomainCard)
        ],
      ),
    );
  }
}