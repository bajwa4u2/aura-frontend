import 'package:flutter/material.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../domain/institution.dart';

class PublicUnitCard extends StatelessWidget {
  const PublicUnitCard({
    super.key,
    required this.unit,
    required this.institutionName,
  });

  final InstitutionUnit unit;
  final String institutionName;

  @override
  Widget build(BuildContext context) {
    final locationParts = <String>[
      if (unit.city != null && unit.city!.isNotEmpty) unit.city!,
      if (unit.region != null && unit.region!.isNotEmpty) unit.region!,
      if (unit.country != null && unit.country!.isNotEmpty) unit.country!,
    ];
    final location = locationParts.join(', ');

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  unit.name,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AuraSpace.s8),
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
            ],
          ),
          if (unit.description != null && unit.description!.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(
              unit.description!,
              style: AuraText.small.copyWith(
                color: AuraSurface.muted,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: AuraSpace.s8),
          _MetaRow(
            icon: Icons.apartment_outlined,
            text: 'Part of $institutionName',
          ),
          if (location.isNotEmpty)
            _MetaRow(icon: Icons.place_outlined, text: location),
          if (unit.websiteUrl != null && unit.websiteUrl!.isNotEmpty)
            _MetaRow(icon: Icons.language_outlined, text: unit.websiteUrl!),
          if (unit.contactEmail != null && unit.contactEmail!.isNotEmpty)
            _MetaRow(
              icon: Icons.mail_outline_rounded,
              text: unit.contactEmail!,
            ),
          if (unit.contactPhone != null && unit.contactPhone!.isNotEmpty)
            _MetaRow(
              icon: Icons.phone_outlined,
              text: unit.contactPhone!,
            ),
          if (unit.address != null && unit.address!.isNotEmpty)
            _MetaRow(
              icon: Icons.location_on_outlined,
              text: [unit.address!, if (location.isNotEmpty) location]
                  .join(', '),
            ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AuraSurface.faint),
          const SizedBox(width: AuraSpace.s6),
          Expanded(
            child: Text(
              text,
              style: AuraText.micro.copyWith(color: AuraSurface.muted),
            ),
          ),
        ],
      ),
    );
  }
}
