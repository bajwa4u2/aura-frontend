import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// UNIT CONTEXT — an operating context INSIDE the institution.
///
/// Founder ruling §10/§14 (2026-08-23). This is deliberately NOT a second
/// workspace: it renders inside the institution shell, and does not reproduce
/// the institution sidebar. Entering a Unit narrows *what you are looking at*;
/// it does not move you to another product.
///
/// And it is not a details card. A legitimate viewer should be able to
/// understand and enter the Unit — what it is, who operates there, what work
/// belongs to it — which is what "completion cannot be: the Unit now has a
/// details screen" means in practice.
///
/// AUTHORITY IS THE SERVER'S. Everything rendered here is what the projection
/// chose to send for this viewer. The screen does not decide what a person may
/// see; it renders what came back and says plainly when something is absent.
class InstitutionUnitContextScreen extends ConsumerStatefulWidget {
  const InstitutionUnitContextScreen({
    super.key,
    required this.institutionId,
    required this.unitId,
  });

  final String institutionId;
  final String unitId;

  @override
  ConsumerState<InstitutionUnitContextScreen> createState() =>
      _InstitutionUnitContextScreenState();
}

class _InstitutionUnitContextScreenState
    extends ConsumerState<InstitutionUnitContextScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _unit;
  List<Map<String, dynamic>> _people = const [];
  Map<String, dynamic>? _work;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant InstitutionUnitContextScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The same screen can be rebuilt for a different unit; without this it
    // would keep showing the previous one under the new address.
    if (oldWidget.unitId != widget.unitId ||
        oldWidget.institutionId != widget.institutionId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(dioProvider).get(
            '/institutions/${widget.institutionId}/units/${widget.unitId}',
          );
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      final body = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;
      if (!mounted) return;
      setState(() {
        _unit = body['unit'] is Map
            ? Map<String, dynamic>.from(body['unit'] as Map)
            : null;
        _people = (body['people'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _work = body['work'] is Map
            ? Map<String, dynamic>.from(body['work'] as Map)
            : null;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.response?.statusCode == 404
            ? 'This unit is not available to you.'
            : 'Could not load this unit.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = _unit;

    return AuraScaffold(
      title: unit?['name']?.toString() ?? 'Unit',
      showHomeAction: true,
      body: _loading
          ? const AuraProductState(state: ProductState.loading)
          : _error != null
              ? AuraProductState(
                  state: ProductState.retryableError,
                  headline: 'Unit unavailable',
                  detail: _error,
                  onRecover: _load,
                )
              : unit == null
                  ? const AuraProductState(
                      state: ProductState.empty,
                      headline: 'Nothing to show',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(AuraSpace.s16),
                        children: [
                          _Identity(unit: unit),
                          const SizedBox(height: AuraSpace.s16),
                          if (_work != null) ...[
                            _Work(work: _work!),
                            const SizedBox(height: AuraSpace.s16),
                          ],
                          _People(people: _people),
                        ],
                      ),
                    ),
    );
  }
}

/// Identity, and its PROVENANCE. A Unit is institution-backed: the parent is
/// part of what a Unit is, not a footnote, so it renders with the name rather
/// than somewhere a reader might miss it.
class _Identity extends StatelessWidget {
  const _Identity({required this.unit});

  final Map<String, dynamic> unit;

  @override
  Widget build(BuildContext context) {
    final institution = unit['institution'] is Map
        ? Map<String, dynamic>.from(unit['institution'] as Map)
        : const <String, dynamic>{};
    final inherited = (unit['inheritedFields'] as List? ?? const [])
        .map((e) => e.toString())
        .toSet();
    final description = unit['description']?.toString().trim() ?? '';

    return _Card(
      children: [
        Text(unit['name']?.toString() ?? '', style: AuraText.headline),
        const SizedBox(height: AuraSpace.s4),
        Text(
          'A ${_typeLabel(unit['type']?.toString())} of '
          '${institution['name'] ?? 'this institution'}',
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          Text(description, style: AuraText.body),
        ],
        const SizedBox(height: AuraSpace.s12),
        _Contact(unit: unit, inherited: inherited),
      ],
    );
  }

  String _typeLabel(String? wire) {
    switch ((wire ?? '').toUpperCase()) {
      case 'PRODUCT':
        return 'product';
      case 'BUSINESS':
        return 'business';
      case 'BRANCH':
        return 'branch';
      case 'OFFICE':
        return 'office';
      case 'DEPARTMENT':
        return 'department';
      case 'SERVICE':
        return 'service';
      case 'PROGRAM':
        return 'programme';
      default:
        return 'unit';
    }
  }
}

/// Contact details, marking what is INHERITED from the institution.
///
/// The distinction is the product truth: a value shown without it would read as
/// the unit's own when it belongs to the parent and follows the parent when it
/// changes.
class _Contact extends StatelessWidget {
  const _Contact({required this.unit, required this.inherited});

  final Map<String, dynamic> unit;
  final Set<String> inherited;

  @override
  Widget build(BuildContext context) {
    const fields = <String, String>{
      'websiteUrl': 'Website',
      'contactEmail': 'Email',
      'contactPhone': 'Phone',
      'city': 'City',
      'country': 'Country',
    };

    final rows = <Widget>[];
    fields.forEach((key, label) {
      final value = unit[key]?.toString().trim() ?? '';
      if (value.isEmpty) return;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  label,
                  style: AuraText.small.copyWith(color: AuraSurface.faint),
                ),
              ),
              Expanded(child: Text(value, style: AuraText.small)),
              if (inherited.contains(key))
                Text(
                  'inherited',
                  style: AuraText.micro.copyWith(color: AuraSurface.faint),
                ),
            ],
          ),
        ),
      );
    });

    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

/// What work belongs here. Counts, because each surface governs its own access
/// — this must not become a side channel revealing what the viewer could not
/// open directly.
class _Work extends StatelessWidget {
  const _Work({required this.work});

  final Map<String, dynamic> work;

  @override
  Widget build(BuildContext context) {
    const labels = <String, String>{
      'spaces': 'Spaces',
      'posts': 'Publications',
      'announcements': 'Announcements',
      'bookingPages': 'Booking pages',
    };

    final entries = labels.entries
        .map((e) => MapEntry(e.value, (work[e.key] as num?)?.toInt() ?? 0))
        .toList();

    if (entries.every((e) => e.value == 0)) {
      return _Card(
        children: [
          const Text('Work', style: AuraText.emphasis),
          const SizedBox(height: AuraSpace.s6),
          Text(
            'Nothing has been associated with this unit yet.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ],
      );
    }

    return _Card(
      children: [
        const Text('Work', style: AuraText.emphasis),
        const SizedBox(height: AuraSpace.s10),
        Wrap(
          spacing: AuraSpace.s16,
          runSpacing: AuraSpace.s8,
          children: [
            for (final e in entries)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e.value}', style: AuraText.emphasis),
                  Text(
                    e.key,
                    style: AuraText.micro.copyWith(color: AuraSurface.faint),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Who operates here — with ASSOCIATION separated from AUTHORITY (§11).
///
/// Being assigned to a unit confers nothing. Someone with delegated authority
/// here is shown by the capability they actually hold, never by a role-like
/// label invented for display.
class _People extends StatelessWidget {
  const _People({required this.people});

  final List<Map<String, dynamic>> people;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return _Card(
        children: [
          const Text('People', style: AuraText.emphasis),
          const SizedBox(height: AuraSpace.s6),
          Text(
            'Nobody is assigned to this unit yet.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
        ],
      );
    }

    return _Card(
      children: [
        const Text('People', style: AuraText.emphasis),
        const SizedBox(height: AuraSpace.s4),
        Text(
          'Assignment says where someone participates. Authority is shown '
          'separately, and only where it has actually been delegated here.',
          style: AuraText.small.copyWith(color: AuraSurface.muted),
        ),
        const SizedBox(height: AuraSpace.s12),
        for (final p in people) _PersonRow(entry: p),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final person = entry['person'] is Map
        ? Map<String, dynamic>.from(entry['person'] as Map)
        : const <String, dynamic>{};
    final capabilities = (entry['capabilities'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person['displayName']?.toString() ??
                      person['handle']?.toString() ??
                      'Member',
                  style: AuraText.small,
                ),
                if (capabilities.isEmpty)
                  Text(
                    'Assigned',
                    style: AuraText.micro.copyWith(color: AuraSurface.faint),
                  )
                else
                  Text(
                    capabilities.map(_capabilityLabel).join(' · '),
                    style: AuraText.micro
                        .copyWith(color: AuraSurface.accentText),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Capability wire tokens read as what the person may DO here, never as a
  /// unit role. There is no UNIT_REPRESENTATIVE; there is someone who may
  /// speak for this unit.
  String _capabilityLabel(String wire) {
    switch (wire) {
      case 'OFFICIAL_REPRESENTATION':
        return 'May speak for this unit';
      case 'PUBLISH_OFFICIAL':
        return 'May publish for this unit';
      case 'HOST_MEETINGS':
        return 'May host meetings here';
      case 'MANAGE_SPACES':
        return 'Manages spaces here';
      case 'MANAGE_MEETINGS':
        return 'Manages meetings here';
      case 'MANAGE_ANNOUNCEMENTS':
        return 'Manages announcements here';
      default:
        return wire
            .toLowerCase()
            .replaceAll('_', ' ')
            .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase());
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.r16),
        border: Border.all(color: AuraSurface.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
