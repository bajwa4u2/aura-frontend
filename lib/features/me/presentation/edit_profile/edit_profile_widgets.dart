import 'package:flutter/material.dart';

import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../../../core/ui/aura_text_block.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANEL
// ─────────────────────────────────────────────────────────────────────────────

class EditProfilePanel extends StatelessWidget {
  const EditProfilePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AuraSurface.divider),
        color: AuraSurface.card,
      ),
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANEL HEADER
// ─────────────────────────────────────────────────────────────────────────────

class EditProfilePanelHeader extends StatelessWidget {
  const EditProfilePanelHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AuraText.title.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: AuraText.muted.copyWith(fontSize: 13)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY CARD
// ─────────────────────────────────────────────────────────────────────────────

class EditProfileEntryCard extends StatelessWidget {
  const EditProfileEntryCard({
    super.key,
    required this.indexLabel,
    required this.child,
    required this.onRemove,
  });

  final String indexLabel;
  final Widget child;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                indexLabel,
                style: AuraText.muted.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onRemove,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AuraSurface.dangerInk,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Remove',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.dangerInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY SURFACE
// ─────────────────────────────────────────────────────────────────────────────

class EditProfileEmptySurface extends StatelessWidget {
  const EditProfileEmptySurface(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s18,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(label, style: AuraText.muted),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE ADD BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class EditProfileInlineAddButton extends StatelessWidget {
  const EditProfileInlineAddButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AuraSecondaryButton(
      label: label,
      onPressed: onPressed,
      icon: Icons.add_rounded,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREVIEW CHIP
// ─────────────────────────────────────────────────────────────────────────────

class EditProfilePreviewChip extends StatelessWidget {
  const EditProfilePreviewChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s8,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: AuraTextBlock(
        label,
        style: AuraText.muted.copyWith(fontSize: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECORD ROW
// ─────────────────────────────────────────────────────────────────────────────

class EditProfileRecordRow extends StatelessWidget {
  const EditProfileRecordRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s20,
        vertical: AuraSpace.s16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AuraSpace.s16),
          Flexible(
            child: AuraTextBlock(
              value,
              textAlign: TextAlign.right,
              style: AuraText.muted,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD
// ─────────────────────────────────────────────────────────────────────────────

class EditProfileField extends StatelessWidget {
  const EditProfileField({
    super.key,
    required this.label,
    required this.controller,
    required this.textInputAction,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final TextInputAction textInputAction;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AuraText.muted.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AuraSpace.s10),
        TextField(
          controller: controller,
          textInputAction: textInputAction,
          minLines: minLines,
          maxLines: maxLines,
          style: AuraText.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: AuraSurface.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s16,
              vertical: AuraSpace.s16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AuraSurface.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AuraSurface.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AuraSurface.ink,
                width: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class EditProfileSectionLabel extends StatelessWidget {
  const EditProfileSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AuraText.muted.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
    );
  }
}
