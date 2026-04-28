import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../domain/communications_models.dart';
import '../../providers.dart';

class DigestPreferencesPanel extends ConsumerStatefulWidget {
  const DigestPreferencesPanel({
    super.key,
    required this.initialFrequency,
  });

  final CommunicationFrequencyOption initialFrequency;

  @override
  ConsumerState<DigestPreferencesPanel> createState() =>
      _DigestPreferencesPanelState();
}

class _DigestPreferencesPanelState
    extends ConsumerState<DigestPreferencesPanel> {
  late CommunicationFrequencyOption _frequency;
  DigestPreviewResult? _preview;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _frequency = widget.initialFrequency;
  }

  Future<void> _previewDigest() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(communicationsRepositoryProvider)
          .previewDigest(frequency: _frequency);
      if (!mounted) return;
      setState(() => _preview = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createDigest() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(communicationsRepositoryProvider)
          .createDigest(frequency: _frequency);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_frequency.label} digest created or refreshed.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Digest schedule', style: AuraText.subtitle),
              ),
              AuraStatusChip(
                label: _frequency.label,
                backgroundColor: AuraSurface.accentSoft,
                textColor: AuraSurface.accentText,
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          const Text(
            'Preview what a daily or weekly summary would look like before creating the record.',
            style: AuraText.body,
          ),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _frequency.value,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(
                      value: 'DAILY_DIGEST',
                      child: Text('Daily digest'),
                    ),
                    DropdownMenuItem(
                      value: 'WEEKLY_DIGEST',
                      child: Text('Weekly digest'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _frequency =
                                communicationFrequencyOptionFromRaw(value);
                            _preview = null;
                          });
                        },
                ),
              ),
              AuraPrimaryButton(
                label: _busy ? 'Working…' : 'Preview digest',
                onPressed: _busy ? null : _previewDigest,
                icon: Icons.visibility_outlined,
              ),
              AuraSecondaryButton(
                label: _busy ? 'Working…' : 'Create digest',
                onPressed: _busy ? null : _createDigest,
                icon: Icons.add_circle_outline,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AuraSpace.s12),
            AuraErrorState(title: 'Digest action failed', body: _error!),
          ],
          const SizedBox(height: AuraSpace.s12),
          if (_preview == null)
            const AuraEmptyState(
              title: 'No preview yet',
              body: 'Choose a digest frequency and preview it here.',
              icon: Icons.inbox_outlined,
            )
          else
            _DigestPreviewCard(preview: _preview!),
        ],
      ),
    );
  }
}

class _DigestPreviewCard extends StatelessWidget {
  const _DigestPreviewCard({required this.preview});

  final DigestPreviewResult preview;

  @override
  Widget build(BuildContext context) {
    return AuraCard(
      borderColor: AuraSurface.divider,
      color: AuraSurface.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.subject,
            style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AuraSpace.s6),
          Text(preview.previewText, style: AuraText.muted),
          const SizedBox(height: AuraSpace.s12),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              AuraStatusChip(
                label: '${preview.itemCount} items',
                backgroundColor: AuraSurface.accentSoft,
                textColor: AuraSurface.accentText,
              ),
              AuraStatusChip(
                label: preview.frequency,
                backgroundColor: AuraSurface.card,
                textColor: AuraSurface.ink,
              ),
            ],
          ),
          if (preview.items.isEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            const Text(
              'No eligible items were available for this digest preview.',
              style: AuraText.body,
            ),
          ],
        ],
      ),
    );
  }
}
