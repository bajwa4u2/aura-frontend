import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:html' as html;

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/document_scaffold.dart';

class InstitutionDomainsScreen extends ConsumerStatefulWidget {
  const InstitutionDomainsScreen({super.key});

  @override
  ConsumerState<InstitutionDomainsScreen> createState() =>
      _InstitutionDomainsScreenState();
}

class _InstitutionDomainsScreenState
    extends ConsumerState<InstitutionDomainsScreen> {
  bool loading = true;
  List domains = [];
  Map? institution;

  final domainController = TextEditingController();

  Timer? verifyTimer;

  String get institutionId => institution?['id'] ?? '';

  Future<void> loadDomains() async {
    try {
      final dio = ref.read(dioProvider);

      final res = await dio.get('/institutions/me');

      final inst = res.data['institution'];

      if (inst == null) {
        setState(() => loading = false);
        return;
      }

      final id = inst['id'];

      final domainsRes = await dio.get('/institutions/$id/domains');

      setState(() {
        institution = inst;
        domains = domainsRes.data['domains'] ?? [];
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Future<void> addDomain() async {
    final domain = domainController.text.trim();
    if (domain.isEmpty) return;

    final dio = ref.read(dioProvider);

    await dio.post(
      '/institutions/$institutionId/domains',
      data: {'domain': domain},
    );

    domainController.clear();

    await loadDomains();
  }

  Future<void> removeDomain(String domainId) async {
    final dio = ref.read(dioProvider);

    await dio.delete('/institutions/$institutionId/domains/$domainId');

    await loadDomains();
  }

  Future<void> issueChallenge(String domainId) async {
    final dio = ref.read(dioProvider);

    final res = await dio.post(
      '/institutions/$institutionId/domains/$domainId/verify/dns',
    );

    final verification = res.data['verification'];

    if (!mounted) return;

    showDialog(
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
              _copyRow('Record name', verification['recordName']),
              _copyRow('Record type', verification['recordType']),
              _copyRow('Record value', verification['value']),
              SizedBox(height: AuraSpace.s12),
              const Text(
                'After adding the record, click "Verify". DNS propagation may take a few minutes.',
              ),
              SizedBox(height: AuraSpace.s12),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _openDnsProvider('cloudflare'),
                    child: const Text('Cloudflare'),
                  ),
                  TextButton(
                    onPressed: () => _openDnsProvider('godaddy'),
                    child: const Text('GoDaddy'),
                  ),
                  TextButton(
                    onPressed: () => _openDnsProvider('namecheap'),
                    child: const Text('Namecheap'),
                  ),
                ],
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  Widget _copyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: SelectableText('$label: $value'),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
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
        html.window.open('https://ap.www.namecheap.com/domains/list/', '_blank');
        break;
    }
  }

  Future<void> verifyDomain(String domainId) async {
    final dio = ref.read(dioProvider);

    final res = await dio.post(
      '/institutions/$institutionId/domains/$domainId/verify/check',
    );

    if (!mounted) return;

    final ok = res.data['verified'] == true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Domain verified successfully.'
              : 'DNS record not found yet. Try again in a minute.',
        ),
      ),
    );

    await loadDomains();
  }

  void startAutoVerify(String domainId) {
    verifyTimer?.cancel();

    verifyTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => verifyDomain(domainId),
    );
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

  Widget buildDomainCard(Map d) {
    final id = d['id'];
    final domain = d['domain'];
    final status = d['status'];

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            domain,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: AuraSpace.s8),
          Text('Status: $status'),
          SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            children: [
              ElevatedButton(
                onPressed: () => issueChallenge(id),
                child: const Text('DNS challenge'),
              ),
              ElevatedButton(
                onPressed: () => verifyDomain(id),
                child: const Text('Verify'),
              ),
              ElevatedButton(
                onPressed: () => startAutoVerify(id),
                child: const Text('Auto verify'),
              ),
              OutlinedButton(
                onPressed: () => removeDomain(id),
                child: const Text('Remove'),
              ),
            ],
          )
        ],
      ),
    );
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
          Doc.lede(
              'Attach and verify domains owned by the institution.'),
          SizedBox(height: AuraSpace.s12),

          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add domain',
                  style:
                      AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AuraSpace.s10),
                TextField(
                  controller: domainController,
                  decoration:
                      const InputDecoration(hintText: 'example.org'),
                ),
                SizedBox(height: AuraSpace.s10),
                ElevatedButton(
                  onPressed: addDomain,
                  child: const Text('Add domain'),
                ),
              ],
            ),
          ),

          SizedBox(height: AuraSpace.s12),

          if (loading)
            const Center(child: CircularProgressIndicator())
          else
            ...domains.map(buildDomainCard).toList()
        ],
      ),
    );
  }
}