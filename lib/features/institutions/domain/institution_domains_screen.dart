import 'dart:async';
import 'dart:html' as html;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  List<Map<String, dynamic>> domains = <Map<String, dynamic>>[];
  Map<String, dynamic>? institution;

  final TextEditingController domainController = TextEditingController();

  Timer? verifyTimer;
  bool _submitting = false;

  String get institutionId => institution?['id']?.toString() ?? '';

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  String _messageFromDio(Object error, {String fallback = 'Something went wrong.'}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (data is Map &&
          data['error'] is Map &&
          (data['error'] as Map)['message'] != null) {
        return (data['error'] as Map)['message'].toString();
      }
    }
    return fallback;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> loadDomains() async {
    try {
      final dio = ref.read(dioProvider);

      final res = await dio.get('/institutions/me');
      final data = _asMap(res.data) ?? <String, dynamic>{};

      final topInstitution = _asMap(data['institution']);
      final membership = _asMap(data['membership']);
      final membershipInstitution = _asMap(membership?['institution']);
      final request = _asMap(data['request']);

      final inst = topInstitution ?? membershipInstitution ?? request;

      if (inst == null || (inst['id']?.toString().trim().isEmpty ?? true)) {
        setState(() {
          institution = null;
          domains = <Map<String, dynamic>>[];
          loading = false;
        });
        return;
      }

      final id = inst['id'].toString();
      final domainsRes = await dio.get('/institutions/$id/domains');
      final domainsData = _asMap(domainsRes.data) ?? <String, dynamic>{};

      setState(() {
        institution = inst;
        domains = _asMapList(domainsData['domains']);
        loading = false;
      });
    } catch (error) {
      setState(() {
        loading = false;
      });
      _showSnack(
        _messageFromDio(
          error,
          fallback: 'Could not load institution domains.',
        ),
      );
    }
  }

  Future<void> addDomain() async {
    final domain = domainController.text.trim();
    if (domain.isEmpty || institutionId.isEmpty || _submitting) return;

    try {
      setState(() => _submitting = true);

      final dio = ref.read(dioProvider);

      await dio.post(
        '/institutions/$institutionId/domains',
        data: {'domain': domain},
      );

      domainController.clear();
      _showSnack('Domain added.');
      await loadDomains();
    } catch (error) {
      _showSnack(
        _messageFromDio(
          error,
          fallback: 'Could not add domain.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> removeDomain(String domainId) async {
    if (institutionId.isEmpty) return;

    try {
      final dio = ref.read(dioProvider);

      await dio.delete('/institutions/$institutionId/domains/$domainId');

      _showSnack('Domain removed.');
      await loadDomains();
    } catch (error) {
      _showSnack(
        _messageFromDio(
          error,
          fallback: 'Could not remove domain.',
        ),
      );
    }
  }

  Future<void> issueChallenge(String domainId) async {
    if (institutionId.isEmpty) return;

    try {
      final dio = ref.read(dioProvider);

      final res = await dio.post(
        '/institutions/$institutionId/domains/$domainId/verify/dns',
      );

      final data = _asMap(res.data) ?? <String, dynamic>{};
      final verification = _asMap(data['verification']) ?? <String, dynamic>{};

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
                SizedBox(height: AuraSpace.s12),
                const Text(
                  'After adding the record, click Verify. DNS propagation may take a few minutes.',
                ),
                SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );

      await loadDomains();
    } catch (error) {
      _showSnack(
        _messageFromDio(
          error,
          fallback: 'Could not issue DNS challenge.',
        ),
      );
    }
  }

  Widget _copyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText('$label: $value'),
          ),
          IconButton(
            tooltip: 'Copy',
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
          'https://ap.www.namecheap.com/domains/list/',
          '_blank',
        );
        break;
    }
  }

  Future<void> verifyDomain(String domainId) async {
    if (institutionId.isEmpty) return;

    try {
      final dio = ref.read(dioProvider);

      final res = await dio.post(
        '/institutions/$institutionId/domains/$domainId/verify/check',
      );

      final data = _asMap(res.data) ?? <String, dynamic>{};
      final ok = data['verified'] == true;

      _showSnack(
        ok
            ? 'Domain verified successfully.'
            : (data['message']?.toString() ?? 'DNS record not found yet. Try again in a minute.'),
      );

      await loadDomains();

      if (ok) {
        verifyTimer?.cancel();
      }
    } catch (error) {
      _showSnack(
        _messageFromDio(
          error,
          fallback: 'Could not verify domain.',
        ),
      );
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
    final domain = d['domain']?.toString() ?? '';
    final status = d['status']?.toString() ?? 'UNKNOWN';
    final trustLevel = d['trustLevel']?.toString() ?? '';
    final isPrimary = d['isPrimary'] == true;
    final verifiedAt = d['verifiedAt']?.toString() ?? '';

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            domain,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: AuraSpace.s8),
          Text('Status: $status', style: AuraText.body),
          if (trustLevel.isNotEmpty) ...[
            SizedBox(height: AuraSpace.s4),
            Text('Trust: $trustLevel', style: AuraText.body),
          ],
          if (isPrimary) ...[
            SizedBox(height: AuraSpace.s4),
            Text('Primary domain', style: AuraText.body),
          ],
          if (verifiedAt.isNotEmpty) ...[
            SizedBox(height: AuraSpace.s4),
            Text('Verified at: $verifiedAt', style: AuraText.body),
          ],
          SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              ElevatedButton(
                onPressed: id.isEmpty ? null : () => issueChallenge(id),
                child: const Text('DNS challenge'),
              ),
              ElevatedButton(
                onPressed: id.isEmpty ? null : () => verifyDomain(id),
                child: const Text('Verify'),
              ),
              ElevatedButton(
                onPressed: id.isEmpty ? null : () => startAutoVerify(id),
                child: const Text('Auto verify'),
              ),
              OutlinedButton(
                onPressed: id.isEmpty ? null : () => removeDomain(id),
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return AuraCard(
      child: Text(
        'No domains added yet.',
        style: AuraText.body,
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
            'Attach and verify domains owned by the institution.',
          ),
          SizedBox(height: AuraSpace.s12),
          AuraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add domain',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: AuraSpace.s10),
                TextField(
                  controller: domainController,
                  decoration: const InputDecoration(
                    hintText: 'example.org',
                  ),
                ),
                SizedBox(height: AuraSpace.s10),
                ElevatedButton(
                  onPressed: _submitting ? null : addDomain,
                  child: Text(_submitting ? 'Adding...' : 'Add domain'),
                ),
              ],
            ),
          ),
          SizedBox(height: AuraSpace.s12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (domains.isEmpty)
            _emptyState()
          else
            ...domains.map((d) => buildDomainCard(d)).toList(),
        ],
      ),
    );
  }
}