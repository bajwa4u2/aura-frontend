import 'package:dio/dio.dart';
import '../kind/kind_composition.dart';
import '../../../core/product/product_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/institutions/institution_paths.dart';

import '../../../core/authority/authority_providers.dart';
import '../../../core/institutions/institution_access_provider.dart';
import '../../../core/authority/capability_projection.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../domain/institution.dart';
import '../institution_words.dart';
import '../workspace/workspace_page.dart';

class InstitutionUnitsScreen extends ConsumerStatefulWidget {
  const InstitutionUnitsScreen({super.key, required this.institutionId});

  final String institutionId;

  @override
  ConsumerState<InstitutionUnitsScreen> createState() =>
      _InstitutionUnitsScreenState();
}

/// Whether this viewer may administer units.
///
/// The destination itself is participation baseline — units are part of how an
/// institution describes itself, and the server already withholds non-public
/// and archived ones. These CONTROLS are not baseline: creating, editing and
/// archiving an operating context is administration, and the backend enforces
/// it as institution ADMIN.
bool _canAdministerUnits(WidgetRef ref) =>
    ref.watch(capabilityProjectionProvider).presentationFor(
          ConsequentialAct.administerUnits,
        ) ==
    ControlPresentation.available;

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

  /// Active or Archived (DD-43: the one tabs idiom, not an ARCHIVED heading).
  String _tab = 'active';

  @override
  Widget build(BuildContext context) {
    final canAdminister = _canAdministerUnits(ref);
    // What this kind calls its units: Departments, Campuses… (DD-42 phase 3).
    final composition = compositionForInstitution(ref, widget.institutionId);
    final active = _units.where((u) => !u.isArchived).toList();
    final archived = _units.where((u) => u.isArchived).toList();
    final showing = _tab == 'archived' ? archived : active;

    return WorkspacePage(
      type: WorkspacePageType.collection,
      title: composition.unitPlural,
      purpose: 'Departments, branches, offices, products or services that appear on the public institution profile.',
      primary: canAdminister
          ? WorkspaceAction(
              label: 'New ${composition.unitSingular.toLowerCase()}',
              icon: Icons.add_rounded,
              onPressed: () => _openUpsertSheet(),
            )
          : null,
      tabs: [
        WorkspaceTab(id: 'active', label: 'Active', count: _loading ? null : active.length),
        if (archived.isNotEmpty || _tab == 'archived')
          WorkspaceTab(id: 'archived', label: 'Archived', count: _loading ? null : archived.length),
      ],
      selectedTab: _tab,
      onTab: (id) => setState(() => _tab = id),
      loading: _loading,
      children: [
        if (_error != null)
          WorkspaceEmpty(
            icon: Icons.error_outline_rounded,
            title: 'Could not load ${composition.unitPlural.toLowerCase()}',
            body: _error!,
            action: WorkspaceAction(label: ProductLabels.of(ProductAction.retry), icon: Icons.refresh_rounded, onPressed: _load),
          )
        else if (showing.isEmpty)
          WorkspaceEmpty(
            icon: Icons.account_tree_outlined,
            title: _tab == 'archived'
                ? 'Nothing archived'
                : 'No ${composition.unitPlural.toLowerCase()} yet',
            body: _tab == 'archived'
                ? 'Archived ${composition.unitPlural.toLowerCase()} wait here and can be restored.'
                : 'Add a branch, department, or product to get started.',
            action: canAdminister && _tab != 'archived'
                ? WorkspaceAction(
                    label: 'New ${composition.unitSingular.toLowerCase()}',
                    icon: Icons.add_rounded,
                    onPressed: () => _openUpsertSheet(),
                  )
                : null,
          )
        else
          ..._buildUnitList(showing, canAdminister: canAdminister),
      ],
    );
  }

  List<Widget> _buildUnitList(List<InstitutionUnit> units, {required bool canAdminister}) {
    // The institution's canonical address, so unit links carry the same
    // identity the rest of the workspace does.
    final identity = ref.watch(institutionIdentityProvider);
    return [
      for (final u in units)
        _UnitCard(
          unit: u,
          // A unit is an operating context, so the row leads INTO it.
          // Opening is participation; administering it is gated above.
          // BOTH SLUGS (founder ruling, step 2), matching the public
          // precedent /institutions/:slug/units/:unitSlug rather than
          // inventing a second shape for the same resource. A unit slug is
          // unique within its institution, so the pair is exact.
          onOpen: u.isArchived
              ? null
              : () => context.push(
                    institutionUnitContextPath(
                      identity?.workspaceAddress ?? widget.institutionId,
                      u.slug.trim().isNotEmpty ? u.slug : u.id,
                    ),
                  ),
          onEdit: u.isArchived
              ? () => _openUpsertSheet(existing: u)
              : (canAdminister ? () => _openUpsertSheet(existing: u) : null),
          onArchive: canAdminister ? () => _archiveUnit(u.id, u.isArchived) : null,
        ),
    ];
  }
}

// ── Unit row ──────────────────────────────────────────────────────────────────

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    this.onOpen,
    required this.unit,
    required this.onEdit,
    required this.onArchive,
  });

  final InstitutionUnit unit;

  /// Entering the unit as an operating context. Always available to whoever
  /// can already see the unit — the server decides what they find inside.
  final VoidCallback? onOpen;

  /// Null when the viewer may not administer units. Absent, not disabled —
  /// a control someone can never enable is noise, not information.
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final contextLine = <String>[
      unit.typeLabel,
      if (unit.description != null && unit.description!.isNotEmpty) unit.description!,
      if (unit.description == null || unit.description!.isEmpty) ...[
        if (unit.websiteUrl != null) unit.websiteUrl!,
        if (unit.contactEmail != null) unit.contactEmail!,
      ],
    ].join(' · ');
    final actions = <(String, IconData, VoidCallback)>[
      if (onEdit != null) ('Edit', Icons.edit_outlined, onEdit!),
      if (onArchive != null)
        (unit.isArchived ? 'Restore' : 'Archive', unit.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, onArchive!),
    ];
    return WorkspaceRow(
      leading: const WorkspaceIcon(Icons.account_tree_outlined),
      title: unit.name,
      context: contextLine,
      pill: unit.isPublic
          ? const WorkspacePill(label: 'On profile', tone: WorkspaceTone.done)
          : const WorkspacePill(label: 'Hidden', tone: WorkspaceTone.waiting),
      onTap: onOpen,
      trailing: actions.isEmpty
          ? null
          : PopupMenuButton<int>(
              tooltip: 'Actions for ${unit.name}',
              color: AuraSurface.overlay,
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: AuraSurface.muted),
              onSelected: (i) => actions[i].$3(),
              itemBuilder: (_) => [
                for (var i = 0; i < actions.length; i++)
                  PopupMenuItem<int>(
                    value: i,
                    child: Row(
                      children: [
                        Icon(actions[i].$2, size: 18, color: AuraSurface.muted),
                        const SizedBox(width: AuraSpace.s12),
                        Text(actions[i].$1, style: AuraText.body),
                      ],
                    ),
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
    // The address is made from the name (phase 2, 2026-10-09): people were
    // asked for a "Slug", a developer's word for something they never need to
    // choose. An existing unit keeps the address it already has.
    final existing = _slugCtrl.text.trim();
    final slug = existing.isNotEmpty ? existing : unitAddressFromName(name);
    if (name.isEmpty) {
      _snack('Enter a unit name.');
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
              decoration: const InputDecoration(labelText: 'Name'),
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
              maxLines: null,
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
