import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// THE WORKSPACE FRAME (DD-43, 2026-10-09).
///
/// The founder, looking at the institution workspace: "every screen is another
/// world". It had four page frames, three title styles, three filter styles,
/// four kinds of Back and two loading styles. Every workspace screen is now
/// one of five page types, built from the parts in this file and nothing
/// else:
///
///   board       Today's replacement, the Desk's summary blocks
///   collection  header, tabs with counts, rows; an item opens beside the list
///   record      one thing: status, content, actions, history
///   composer    writing, with its check beside it, and one Publish bar
///   settings    labelled sections in one column, one Save bar, one Cancel
///
/// The rules the parts enforce: one serif title with one plain purpose line;
/// at most one gold action, top right, everything else under More; one tabs
/// row; one row; one empty state; an outline while loading, never a spinner;
/// Back only on records, composers and sub-pages, naming where it goes. The
/// kind (DD-42) changes words and order, never this layout.
enum WorkspacePageType { board, collection, record, composer, settings }

/// One thing a person can do from a page header or a bar.
class WorkspaceAction {
  const WorkspaceAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool destructive;
}

/// One tab: a label, and how many things it holds when that is known.
class WorkspaceTab {
  const WorkspaceTab({required this.id, required this.label, this.count});

  final String id;
  final String label;
  final int? count;
}

/// Where a record's Back goes: the section it belongs to.
class WorkspaceBack {
  const WorkspaceBack({required this.label, required this.path});

  /// The section's name, e.g. "Questions". Shown as "Back to Questions".
  final String label;
  final String path;
}

/// Widths. Measured against the content area beside the rail, not the window.
class WorkspaceLayout {
  WorkspaceLayout._();

  /// Collections, records and settings: one reading column.
  static const double column = 880;

  /// The Board and composers: room for two columns of blocks.
  static const double wide = 1080;

  /// The list's width when an item is open beside it.
  static const double list = 420;

  /// The open item's widest reading measure.
  static const double detail = 760;

  /// From this content width an item opens beside its list.
  static const double splitFrom = 1040;

  /// Below this content width the page is laid out for a phone.
  static const double phoneBelow = 600;

  static double gutter(double width) {
    if (width < phoneBelow) return AuraSpace.s16;
    if (width < 1024) return AuraSpace.s24;
    return AuraSpace.s32;
  }
}

/// The workspace's type: only these, everywhere.
class WorkspaceType {
  WorkspaceType._();

  static const TextStyle pageTitle = TextStyle(
    fontFamily: 'AuraSerif',
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AuraSurface.ink,
  );

  static const TextStyle purpose = TextStyle(
    fontFamily: 'AuraSans',
    fontSize: 14,
    height: 1.45,
    color: AuraSurface.muted,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: 'AuraSerif',
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AuraSurface.ink,
  );

  static const TextStyle rowTitle = TextStyle(
    fontFamily: 'AuraSans',
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AuraSurface.ink,
  );

  static const TextStyle rowContext = TextStyle(
    fontFamily: 'AuraSans',
    fontSize: 13,
    height: 1.4,
    color: AuraSurface.faint,
  );

  static const TextStyle eyebrow = TextStyle(
    fontFamily: 'AuraSans',
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: AuraSurface.faint,
  );
}

/// A workspace page. Every workspace screen is one of these.
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({
    super.key,
    required this.type,
    required this.title,
    this.purpose,
    this.primary,
    this.more = const [],
    this.back,
    this.tabs = const [],
    this.selectedTab,
    this.onTab,
    this.tabTrailing,
    this.children = const [],
    this.loading = false,
    this.detail,
    this.bar,
  });

  final WorkspacePageType type;
  final String title;

  /// One plain line: what this page is for.
  final String? purpose;

  /// The one gold action. Never more than one.
  final WorkspaceAction? primary;

  /// Everything else a person can do here, under More.
  final List<WorkspaceAction> more;

  /// Only records, composers and sub-pages have a way back.
  final WorkspaceBack? back;

  final List<WorkspaceTab> tabs;
  final String? selectedTab;
  final ValueChanged<String>? onTab;

  /// A search field or one Filter control, at the end of the tabs row.
  final Widget? tabTrailing;

  /// The page's content, top to bottom.
  final List<Widget> children;

  /// While true the content is an outline of what is coming.
  final bool loading;

  /// The open item. Beside the list on wide screens; on narrow screens the
  /// caller opens it as its own page instead and leaves this null.
  final Widget? detail;

  /// A Save or Publish bar, pinned to the bottom.
  final Widget? bar;

  /// Whether an item opens beside the list at this width. Callers ask this
  /// to decide between showing [detail] and pushing a record page.
  static bool opensBeside(BuildContext context, double contentWidth) =>
      contentWidth >= WorkspaceLayout.splitFrom;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuraSurface.page,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final phone = width < WorkspaceLayout.phoneBelow;
          final gutter = WorkspaceLayout.gutter(width);
          final split = detail != null && width >= WorkspaceLayout.splitFrom;

          final head = <Widget>[
            WorkspaceHeader(
              title: title,
              purpose: purpose,
              primary: primary,
              more: more,
              back: back,
              compact: phone || split,
            ),
            if (tabs.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s16),
              WorkspaceTabs(
                tabs: tabs,
                selected: selectedTab ?? tabs.first.id,
                onSelected: onTab,
                trailing: split ? null : tabTrailing,
              ),
            ],
            const SizedBox(height: AuraSpace.s20),
          ];
          final content = loading ? [WorkspaceLoading(type: type)] : children;

          Widget column(double maxWidth, {required bool withBar}) {
            final list = ListView(
              padding: EdgeInsets.fromLTRB(gutter, AuraSpace.s24, gutter, AuraSpace.s32),
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...head, ...content],
                    ),
                  ),
                ),
              ],
            );
            if (!withBar || bar == null) return list;
            return Column(children: [Expanded(child: list), bar!]);
          }

          if (!split) {
            final max = switch (type) {
              WorkspacePageType.board || WorkspacePageType.composer => WorkspaceLayout.wide,
              _ => WorkspaceLayout.column,
            };
            return column(max, withBar: true);
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: WorkspaceLayout.list + 2 * gutter,
                child: column(WorkspaceLayout.list, withBar: false),
              ),
              const VerticalDivider(width: 1, thickness: 1, color: AuraSurface.divider),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: WorkspaceLayout.detail + 2 * AuraSpace.s32),
                    child: detail,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The header every workspace page has.
class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.title,
    this.purpose,
    this.primary,
    this.more = const [],
    this.back,
    this.compact = false,
  });

  final String title;
  final String? purpose;
  final WorkspaceAction? primary;
  final List<WorkspaceAction> more;
  final WorkspaceBack? back;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (more.isNotEmpty) WorkspaceMoreButton(actions: more),
      if (more.isNotEmpty && primary != null) const SizedBox(width: AuraSpace.s8),
      if (primary != null) WorkspacePrimaryButton(action: primary!, compact: compact),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (back != null) ...[
          WorkspaceBackLink(back: back!),
          const SizedBox(height: AuraSpace.s12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: WorkspaceType.pageTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (purpose != null && purpose!.trim().isNotEmpty) ...[
                    const SizedBox(height: AuraSpace.s4),
                    Text(purpose!, style: WorkspaceType.purpose),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: AuraSpace.s16),
              Row(mainAxisSize: MainAxisSize.min, children: actions),
            ],
          ],
        ),
      ],
    );
  }
}

/// "← Back to Questions": names where it goes; unwinds when it can.
class WorkspaceBackLink extends StatelessWidget {
  const WorkspaceBackLink({super.key, required this.back});

  final WorkspaceBack back;

  @override
  Widget build(BuildContext context) {
    final label = 'Back to ${back.label}';
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          final router = GoRouter.maybeOf(context);
          if (router == null) return;
          if (router.canPop()) {
            router.pop();
          } else {
            router.go(back.path);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_back_rounded, size: 16, color: AuraSurface.muted),
              const SizedBox(width: AuraSpace.s6),
              Text(label, style: AuraText.small.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one gold action.
class WorkspacePrimaryButton extends StatelessWidget {
  const WorkspacePrimaryButton({super.key, required this.action, this.compact = false});

  final WorkspaceAction action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: AuraSurface.accent,
      foregroundColor: AuraSurface.onAccent,
      disabledBackgroundColor: AuraSurface.accentSoft,
      padding: EdgeInsets.symmetric(horizontal: compact ? AuraSpace.s12 : AuraSpace.s16, vertical: AuraSpace.s12),
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontFamily: 'AuraSans', fontSize: 14, fontWeight: FontWeight.w700),
    );
    if (compact && action.icon != null) {
      return Tooltip(
        message: action.label,
        child: FilledButton(
          onPressed: action.onPressed,
          style: style,
          child: Semantics(label: action.label, child: Icon(action.icon, size: 18)),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: action.onPressed,
      style: style,
      icon: Icon(action.icon ?? Icons.add_rounded, size: 18),
      label: Text(action.label),
    );
  }
}

/// Everything that is not the gold action.
class WorkspaceMoreButton extends StatelessWidget {
  const WorkspaceMoreButton({super.key, required this.actions});

  final List<WorkspaceAction> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'More',
      color: AuraSurface.overlay,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AuraSurface.divider),
      ),
      onSelected: (i) => actions[i].onPressed?.call(),
      itemBuilder: (_) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: actions[i].onPressed != null,
            child: Row(
              children: [
                if (actions[i].icon != null) ...[
                  Icon(
                    actions[i].icon,
                    size: 18,
                    color: actions[i].destructive ? AuraSurface.dangerInk : AuraSurface.muted,
                  ),
                  const SizedBox(width: AuraSpace.s12),
                ],
                Flexible(
                  child: Text(
                    actions[i].label,
                    style: AuraText.body.copyWith(
                      color: actions[i].destructive ? AuraSurface.dangerInk : AuraSurface.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AuraSurface.divider),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('More', style: TextStyle(fontFamily: 'AuraSans', fontSize: 14, fontWeight: FontWeight.w600, color: AuraSurface.muted)),
            SizedBox(width: AuraSpace.s4),
            Icon(Icons.expand_more_rounded, size: 18, color: AuraSurface.muted),
          ],
        ),
      ),
    );
  }
}

/// The one tabs row: labels with counts; a search or Filter at its end.
class WorkspaceTabs extends StatelessWidget {
  const WorkspaceTabs({
    super.key,
    required this.tabs,
    required this.selected,
    this.onSelected,
    this.trailing,
  });

  final List<WorkspaceTab> tabs;
  final String selected;
  final ValueChanged<String>? onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in tabs) ...[
            _TabChip(tab: t, selected: t.id == selected, onTap: onSelected == null ? null : () => onSelected!(t.id)),
            const SizedBox(width: AuraSpace.s8),
          ],
        ],
      ),
    );
    if (trailing == null) return row;
    return Row(
      children: [
        Expanded(child: row),
        const SizedBox(width: AuraSpace.s12),
        trailing!,
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.tab, required this.selected, this.onTap});

  final WorkspaceTab tab;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s14, vertical: AuraSpace.s8),
          decoration: BoxDecoration(
            color: selected ? AuraSurface.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: selected ? AuraSurface.accent : AuraSurface.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tab.label,
                style: TextStyle(
                  fontFamily: 'AuraSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AuraSurface.ink : AuraSurface.muted,
                ),
              ),
              if (tab.count != null) ...[
                const SizedBox(width: AuraSpace.s6),
                Text(
                  '${tab.count}',
                  style: TextStyle(
                    fontFamily: 'AuraSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: selected ? AuraSurface.accentText : AuraSurface.faint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The status palette. Semantic, never decorative.
enum WorkspaceTone { waiting, done, problem, live, neutral }

class WorkspacePill extends StatelessWidget {
  const WorkspacePill({super.key, required this.label, this.tone = WorkspaceTone.neutral});

  final String label;
  final WorkspaceTone tone;

  static (Color, Color) colors(WorkspaceTone tone) => switch (tone) {
        WorkspaceTone.waiting => (AuraSurface.accentSoft, AuraSurface.accentText),
        WorkspaceTone.done => (AuraSurface.goodBg, AuraSurface.goodInk),
        WorkspaceTone.problem => (AuraSurface.dangerBg, AuraSurface.dangerInk),
        WorkspaceTone.live => (const Color(0xFF0F1B29), AuraSurface.infoInk),
        WorkspaceTone.neutral => (AuraSurface.elevated, AuraSurface.muted),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = colors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AuraRadius.pill)),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'AuraSans', fontSize: 12, fontWeight: FontWeight.w600, color: ink, height: 1.3),
      ),
    );
  }
}

/// The one row. Every list in the workspace is made of these.
class WorkspaceRow extends StatelessWidget {
  const WorkspaceRow({
    super.key,
    required this.title,
    this.leading,
    this.context,
    this.pill,
    this.trailing,
    this.selected = false,
    this.onTap,
    this.emphasis,
  });

  /// Who or what, in one or two lines.
  final String title;

  /// An avatar or an icon, 36 wide.
  final Widget? leading;

  /// One line of context, ending with the date.
  final String? context;

  final WorkspacePill? pill;

  /// A menu or a small action. Never a second gold button.
  final Widget? trailing;

  /// Open beside the list.
  final bool selected;
  final VoidCallback? onTap;

  /// Overdue (problem) or live: an edge in that tone, so it is seen first.
  final WorkspaceTone? emphasis;

  /// Below this row width the pill moves under the title, so the title keeps
  /// its line on a phone.
  static const double _stackBelow = 520;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? AuraSurface.accent
        : (emphasis != null ? WorkspacePill.colors(emphasis!).$2.withValues(alpha: 0.45) : AuraSurface.divider);
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Material(
        color: selected ? AuraSurface.elevated : AuraSurface.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s14, vertical: AuraSpace.s12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final stacked = box.maxWidth < _stackBelow;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (leading != null) ...[
                      SizedBox(width: 36, child: Center(child: leading)),
                      const SizedBox(width: AuraSpace.s12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: WorkspaceType.rowTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (this.context != null && this.context!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(this.context!, style: WorkspaceType.rowContext, maxLines: stacked ? 2 : 1, overflow: TextOverflow.ellipsis),
                          ],
                          if (stacked && pill != null) ...[const SizedBox(height: AuraSpace.s6), pill!],
                        ],
                      ),
                    ),
                    if (!stacked && pill != null) ...[const SizedBox(width: AuraSpace.s12), pill!],
                    if (trailing != null) ...[const SizedBox(width: AuraSpace.s8), trailing!],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon, for rows about things rather than people.
class WorkspaceIcon extends StatelessWidget {
  const WorkspaceIcon(this.icon, {super.key, this.tone = WorkspaceTone.neutral});

  final IconData icon;
  final WorkspaceTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = WorkspacePill.colors(tone);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: ink),
    );
  }
}

/// The one empty state, in the list's own place: what will appear here, and
/// the one action that fills it.
class WorkspaceEmpty extends StatelessWidget {
  const WorkspaceEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final WorkspaceAction? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s24),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkspaceIcon(icon),
          const SizedBox(width: AuraSpace.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: WorkspaceType.rowTitle),
                const SizedBox(height: AuraSpace.s4),
                Text(body, style: AuraText.muted),
                if (action != null) ...[
                  const SizedBox(height: AuraSpace.s12),
                  TextButton.icon(
                    onPressed: action!.onPressed,
                    icon: Icon(action!.icon ?? Icons.add_rounded, size: 18),
                    label: Text(action!.label),
                    style: TextButton.styleFrom(
                      foregroundColor: AuraSurface.accentText,
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontFamily: 'AuraSans', fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// While a page loads: an outline of what is coming, in place.
class WorkspaceLoading extends StatelessWidget {
  const WorkspaceLoading({super.key, this.type = WorkspacePageType.collection, this.rows = 3});

  final WorkspacePageType type;
  final int rows;

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: AuraSurface.elevated, borderRadius: BorderRadius.circular(6)),
        );
    Widget outlineRow() => Container(
          margin: const EdgeInsets.only(bottom: AuraSpace.s8),
          padding: const EdgeInsets.all(AuraSpace.s14),
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            children: [
              Container(width: 36, height: 36, decoration: const BoxDecoration(color: AuraSurface.elevated, shape: BoxShape.circle)),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [bar(220, 12), const SizedBox(height: AuraSpace.s8), bar(140, 10)],
                ),
              ),
            ],
          ),
        );
    return Semantics(
      label: 'Loading',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (var i = 0; i < rows; i++) outlineRow()],
      ),
    );
  }
}

/// A labelled section: Settings pages, records and the Board are made of these.
class WorkspaceSection extends StatelessWidget {
  const WorkspaceSection({
    super.key,
    required this.title,
    this.description,
    this.link,
    required this.child,
    this.boxed = true,
  });

  final String title;
  final String? description;

  /// One quiet link at the section's right ("All questions"). Never a button.
  final WorkspaceAction? link;
  final Widget child;

  /// Settings and Board sections sit on a card; record sections do not.
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final inner = boxed
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AuraSpace.s18),
            decoration: BoxDecoration(
              color: AuraSurface.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: child,
          )
        : child;
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(title, style: WorkspaceType.sectionTitle)),
              if (link != null)
                InkWell(
                  onTap: link!.onPressed,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          link!.label,
                          style: const TextStyle(fontFamily: 'AuraSans', fontSize: 13, fontWeight: FontWeight.w700, color: AuraSurface.accentText),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: AuraSurface.accentText),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: AuraSpace.s4),
            Text(description!, style: AuraText.small),
          ],
          const SizedBox(height: AuraSpace.s12),
          inner,
        ],
      ),
    );
  }
}

/// The Save or Publish bar: one Cancel, one gold action, a status line.
class WorkspaceBar extends StatelessWidget {
  const WorkspaceBar({super.key, required this.primary, this.cancel, this.secondary, this.status});

  final WorkspaceAction primary;
  final WorkspaceAction? cancel;

  /// One quiet second act beside the gold one ("Save draft"). Never gold.
  final WorkspaceAction? secondary;

  /// "All changes saved", "3 things to look at".
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AuraSurface.card,
        border: Border(top: BorderSide(color: AuraSurface.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        AuraSpace.s20,
        AuraSpace.s12,
        AuraSpace.s20,
        AuraSpace.s12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: LayoutBuilder(builder: (context, box) => Row(
        children: [
          // On a phone the acts need the room; the status line steps aside.
          Expanded(
            child: status == null || box.maxWidth < 520
                ? const SizedBox.shrink()
                : Text(status!, style: AuraText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (cancel != null) ...[
            TextButton(
              onPressed: cancel!.onPressed,
              style: TextButton.styleFrom(
                foregroundColor: AuraSurface.muted,
                textStyle: const TextStyle(fontFamily: 'AuraSans', fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: Text(cancel!.label),
            ),
            const SizedBox(width: AuraSpace.s8),
          ],
          if (secondary != null) ...[
            OutlinedButton(
              onPressed: secondary!.onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AuraSurface.ink,
                side: const BorderSide(color: AuraSurface.divider),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontFamily: 'AuraSans', fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: Text(secondary!.label),
            ),
            const SizedBox(width: AuraSpace.s8),
          ],
          WorkspacePrimaryButton(action: primary),
        ],
      )),
    );
  }
}
