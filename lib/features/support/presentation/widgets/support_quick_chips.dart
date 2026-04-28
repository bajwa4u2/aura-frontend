import 'package:flutter/material.dart';

const _kQuickReplies = [
  'I need help signing in',
  'I want to report a safety issue',
  'I have a billing question',
  'I found a bug',
  'I have a privacy request',
  'Other question',
];

class SupportQuickChips extends StatelessWidget {
  const SupportQuickChips({
    super.key,
    required this.onSelected,
    this.enabled = true,
  });

  final void Function(String text) onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _kQuickReplies.map((label) {
        return ActionChip(
          label: Text(label, style: theme.textTheme.labelMedium),
          onPressed: enabled ? () => onSelected(label) : null,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        );
      }).toList(),
    );
  }
}
