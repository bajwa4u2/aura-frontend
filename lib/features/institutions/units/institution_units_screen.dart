import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/document_scaffold.dart';
import '../domain/institution.dart';

class InstitutionUnitsScreen extends ConsumerStatefulWidget {
  const InstitutionUnitsScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<InstitutionUnitsScreen> createState() =>
      _InstitutionUnitsScreenState();
}

class _InstitutionUnitsScreenState
    extends ConsumerState<InstitutionUnitsScreen> {
  bool _loading = true;
  String? _error;
  List<InstitutionUnit> _units = [];

  Dio get _dio => ref.read(dioProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await _dio
          .get('/institutions/${widget.institutionId}/units');
      final raw = res.data;
      final list = raw is Map ? raw['units'] : null;
      setState(() {
        _units = list is List
            ? list
                .whereType<Map<String, dynamic>>()
                .map(InstitutionUnit.fromJson)
                .toList()
            : [];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = _errMsg(e);
      });
    }
  }

  String _errMsg(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString().trim();
      }
    }
    return e.toString();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _archiveUnit(String unitId, bool currentlyArchived) async {
    try {
      await _dio.post(
        '/institutions/${widget.institutionId}/units/$unitId/archive',
      );
      _snack(currentlyArchived ? 'Unit restored.' : 'Unit archived.');
      await _load(silent: true);
    } catch (e) {
      _snack(_errMsg(e));
    }
  }

  // ignore: unused_element
  Future<void> _reorder(List<String> orderedIds) async {
    try {
      await _dio.post(
        '/institutions/${widget.institutionId}/units/reorder',
        data: {'orderedIds': orderedIds},
      );
      await _load(silent: true);
    } catch (e) {
      _snack(_errMsg(e));
    }
  }

  void _openUpsertSheet({InstitutionUnit? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UpsertUnitSheet(
        institutionId: widget.institutionId,
        existing: existing,
        onSaved: () => _load(silent: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DocumentScaffold(
      title: 'Units & branches',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Doc.title('Units & branches'),
          const SizedBox(height: AuraSpace.s10),
          Doc.meta('Manage public-facing units under this institution.'),
          Doc.lede(
            'Add departments, branches, offices, products, or services '
            'that appear on the public institution profile.',
          ),
          const SizedBox(height: AuraSpace.s16),
          AuraPrimaryButton(
            label: 'Add unit',
            icon: Icons.add,
            onPressed: () => _openUpsertSheet(),
          ),
          const SizedBox(height: AuraSpace.s16),
          if (_loading)
            const Center(
              child: AuraLoadingState(message: 'Loading units…'),
            )
          else if (_error != null)
            AuraCard(child: Text(_error!))
          else if (_units.isEmpty)
            const AuraCard(
              child: Text(
                'No units yet. Add a branch, department, or product to get started.',
              ),
            )
          else
            ..._buildUnitList(),
        ],
      ),
    );
  }

  List<Widget> _buildUnitList() {
    final active = _units.where((u) => !u.isArchived).toList();
    final archived = _units.where((u) => u.isArchived).toList();

    return [
      if (active.isNotEmpty) ...[
        ...active.map(
          (u) => Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s10),
            child: _UnitCard(
              unit: u,
              onEdit: () => _openUpsertSheet(existing: u),
              onArchive: () => _archiveUnit(u.id, false),
            ),
          ),
        ),
      ],
      if (active.isNotEmpty && archived.isNotEmpty)
        const SizedBox(height: AuraSpace.s8),
      if (archived.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s8),
          child: Text(
            'ARCHIVED',
            style: AuraText.small.copyWith(
              color: AuraSurface.faint,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...archived.map(
          (u) => Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s10),
            child: _UnitCard(
              unit: u,
              onEdit: () => _openUpsertSheet(existing: u),
              onArchive: () => _archiveUnit(u.id, true),
            ),
          ),
        ),
      ],
    ];
  }
}

// ── Unit card ─────────────────────────────────────────────────────────────────

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.onEdit,
    required this.onArchive,
  });

  final InstitutionUnit unit;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unit.name,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s8,
                  vertical: AuraSpace.s4,
                ),
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  unit.typeLabel,
                  style: AuraText.micro.copyWith(
                    color: AuraSurface.accentText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
              if (!unit.isPublic)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s8,
                    vertical: AuraSpace.s4,
                  ),
                  decoration: BoxDecoration(
                    color: AuraSurface.warnBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Hidden',
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.warnInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (unit.description != null && unit.description!.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(
              unit.description!,
              style: AuraText.small.copyWith(color: AuraSurface.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (unit.websiteUrl != null || unit.contactEmail != null) ...[
            const SizedBox(height: AuraSpace.s6),
            if (unit.websiteUrl != null)
              Text(
                unit.websiteUrl!,
                style: AuraText.micro.copyWith(color: AuraSurface.faint),
              ),
            if (unit.contactEmail != null)
              Text(
                unit.contactEmail!,
                style: AuraText.micro.copyWith(color: AuraSurface.faint),
              ),
          ],
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            children: [
              AuraGhostButton(
                label: 'Edit',
                onPressed: onEdit,
              ),
              AuraGhostButton(
                label: unit.isArchived ? 'Restore' : 'Archive',
                onPressed: onArchive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Upsert sheet ──────────────────────────────────────────────────────────────

class _UpsertUnitSheet extends ConsumerStatefulWidget {
  const _UpsertUnitSheet({
    required this.institutionId,
    this.existing,
    required this.onSaved,
  });

  final String institutionId;
  final InstitutionUnit? existing;
  final VoidCallback onSaved;

  @override
  ConsumerState<_UpsertUnitSheet> createState() => _UpsertUnitSheetState();
}

class _UpsertUnitSheetState extends ConsumerState<_UpsertUnitSheet> {
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  bool _isPublic = true;
  String _type = 'OTHER';
  bool _saving = false;

  static const _types = [
    ('PRODUCT', 'Product'),
    ('BUSINESS', 'Business'),
    ('BRANCH', 'Branch'),
    ('OFFICE', 'Office'),
    ('DEPARTMENT', 'Department'),
    ('SERVICE', 'Service'),
    ('PROGRAM', 'Program'),
    ('OTHER', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _slugCtrl.text = e.slug;
      _descCtrl.text = e.description ?? '';
      _websiteCtrl.text = e.websiteUrl ?? '';
      _emailCtrl.text = e.contactEmail ?? '';
      _phoneCtrl.text = e.contactPhone ?? '';
      _addressCtrl.text = e.address ?? '';
      _cityCtrl.text = e.city ?? '';
      _regionCtrl.text = e.region ?? '';
      _countryCtrl.text = e.country ?? '';
      _isPublic = e.isPublic;
      _type = e.type;
    }
    _nameCtrl.addListener(_autoSlug);
  }

  void _autoSlug() {
    if (widget.existing != null) return;
    final slug = _nameCtrl.text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    _slugCtrl.text = slug;
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_autoSlug);
    for (final c in [
      _nameCtrl,
      _slugCtrl,
      _descCtrl,
      _websiteCtrl,
      _emailCtrl,
      _phoneCtrl,
      _addressCtrl,
      _cityCtrl,
      _regionCtrl,
      _countryCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _errMsg(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString().trim();
      }
    }
    return e.toString();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final slug = _slugCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Enter a unit name.');
      return;
    }
    if (slug.isEmpty) {
      _snack('Enter a slug.');
      return;
    }

    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'name': name,
      'slug': slug,
      'type': _type,
      'isPublic': _isPublic,
      if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      if (_websiteCtrl.text.trim().isNotEmpty) 'websiteUrl': _websiteCtrl.text.trim(),
      if (_emailCtrl.text.trim().isNotEmpty) 'contactEmail': _emailCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'contactPhone': _phoneCtrl.text.trim(),
      if (_addressCtrl.text.trim().isNotEmpty) 'address': _addressCtrl.text.trim(),
      if (_cityCtrl.text.trim().isNotEmpty) 'city': _cityCtrl.text.trim(),
      if (_regionCtrl.text.trim().isNotEmpty) 'region': _regionCtrl.text.trim(),
      if (_countryCtrl.text.trim().isNotEmpty) 'country': _countryCtrl.text.trim(),
    };

    try {
      final dio = ref.read(dioProvider);
      if (widget.existing != null) {
        await dio.patch(
          '/institutions/${widget.institutionId}/units/${widget.existing!.id}',
          data: payload,
        );
      } else {
        await dio.post(
          '/institutions/${widget.institutionId}/units',
          data: payload,
        );
      }
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      _snack(_errMsg(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AuraSpace.s20,
        AuraSpace.s20,
        AuraSpace.s20,
        AuraSpace.s20 + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? 'Edit unit' : 'Add unit',
              style: AuraText.title,
            ),
            const SizedBox(height: AuraSpace.s20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name *'),
              enabled: !_saving,
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: _slugCtrl,
              decoration: const InputDecoration(
                labelText: 'Slug *',
                helperText: 'URL-safe identifier, e.g. north-branch',
              ),
              enabled: !_saving,
            ),
            const SizedBox(height: AuraSpace.s12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: _types
                  .map(
                    (t) => DropdownMenuItem(
                      value: t.$1,
                      child: Text(t.$2),
                    ),
                  )
                  .toList(),
              onChanged: _saving ? null : (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
              enabled: !_saving,
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: _websiteCtrl,
              decoration: const InputDecoration(labelText: 'Website URL'),
              keyboardType: TextInputType.url,
              enabled: !_saving,
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Contact email'),
              keyboardType: TextInputType.emailAddress,
              enabled: !_saving,
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Contact phone'),
              keyboardType: TextInputType.phone,
              enabled: !_saving,
            ),
            const SizedBox(height: AuraSpace.s12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
              enabled: !_saving,
            ),
            const SizedBox(height: AuraSpace.s12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(labelText: 'City'),
                    enabled: !_saving,
                  ),
                ),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: TextField(
                    controller: _regionCtrl,
                    decoration: const InputDecoration(labelText: 'Region'),
                    enabled: !_saving,
                  ),
                ),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: TextField(
                    controller: _countryCtrl,
                    decoration: const InputDecoration(labelText: 'Country'),
                    enabled: !_saving,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.s12),
            SwitchListTile(
              title: const Text('Visible on public profile'),
              value: _isPublic,
              onChanged: _saving ? null : (v) => setState(() => _isPublic = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AuraSpace.s20),
            Row(
              children: [
                AuraPrimaryButton(
                  label: _saving ? 'Saving…' : (isEdit ? 'Save changes' : 'Add unit'),
                  onPressed: _saving ? null : _save,
                ),
                const SizedBox(width: AuraSpace.s12),
                AuraGhostButton(
                  label: 'Cancel',
                  onPressed: _saving ? null : () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
