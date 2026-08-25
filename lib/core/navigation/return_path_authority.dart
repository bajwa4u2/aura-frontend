/// RETURN-PATH AUTHORITY.
///
/// FOUNDER CONTRACT (2026-08-25): every Aura destination has a deliberate,
/// context-correct, platform-appropriate way forward AND a deliberate way out.
///
/// ─────────────────────────────────────────────────────────────────────────
/// A SIBLING OF RC4, NOT AN EXTENSION
/// ─────────────────────────────────────────────────────────────────────────
///
/// `destination_continuity.dart` (RC4) answers:
///
///     "May this destination continue, and what governed exit occurs when it
///      cannot?"
///
/// This answers a different question about a person who is legitimately where
/// they are:
///
///     "What does returning from here MEAN?"
///
/// Founder ruling: the two must cooperate without conflation. They do, in one
/// direction only — this consumes RC4's `validatedReturnTarget` so a return
/// destination is held to the same shape rules as a preserved one, and never
/// the reverse. Folding return into RC4 would make one file answer two
/// subjects, which is the shape RC6 was written about.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS EXISTS
/// ─────────────────────────────────────────────────────────────────────────
///
/// The 2026-08-25 census found 83 of 151 audited surfaces with no correct way
/// out. The cause was not 83 screens: it was that nothing owned the question,
/// so it was answered 83 times — 47 of them by not answering, 5 by hardcoding
/// a fixed parent that is right only if you arrived from it.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE TWO ENTRY MODES (founder ruling §8)
/// ─────────────────────────────────────────────────────────────────────────
///
/// A. NORMAL IN-APP ENTRY — a real Aura journey exists. Unwind it. Directory →
///    Institution → Space → Conversation returns through what the person
///    actually did, not to an invented fixed destination.
///
/// B. DIRECT / DEEP-LINK ENTRY — there is no predecessor. Resolve a canonical
///    contextual parent. Never manufacture history, never default everything
///    to `/home`, never hardcode a parent when context can be derived.
///
/// The distinction is not guessed: it is `canPop`, which is the router's own
/// answer about whether a predecessor exists.
library;

import 'destination_continuity.dart';

/// What returning from a destination MEANS. Presentation renders this; it does
/// not decide it (founder ruling §2).
enum ReturnSemantic {
  /// Unwind the person's real journey. The predecessor exists.
  stackReturn,

  /// No predecessor, but this destination has a canonical parent in the
  /// product hierarchy.
  parentReturn,

  /// Return to the originating institution/person context rather than to a
  /// structural parent.
  contextReturn,

  /// Leave an unfinished creation/edit flow, honouring its preservation
  /// contract. NOT hierarchical Back, and never labelled as Back.
  flowCancel,

  /// Move to the governed destination after a flow succeeds.
  flowComplete,

  /// Dismiss an overlay without changing navigation.
  modalDismiss,

  /// Entered directly with no Aura predecessor: a derived, contextual escape.
  deepLinkFallback,

  /// A genuine top-level destination. A back affordance here would be a lie.
  rootNoReturn,

  /// Governed destructive/authorisation exit. RC4 owns the policy.
  terminalExit,
}

/// The governed answer: what returning means, and where it goes.
class ReturnAction {
  const ReturnAction({
    required this.semantic,
    this.destination,
    this.label,
  });

  const ReturnAction.root() : semantic = ReturnSemantic.rootNoReturn,
        destination = null,
        label = null;

  final ReturnSemantic semantic;

  /// Where to go. Null for [ReturnSemantic.stackReturn] (unwind instead),
  /// [ReturnSemantic.modalDismiss] and [ReturnSemantic.rootNoReturn].
  final String? destination;

  /// What the destination is called, when naming it helps. A bare arrow is
  /// correct when the predecessor is unknown; "Spaces" is better when it is.
  final String? label;

  /// Should a return affordance be presented at all?
  bool get hasAffordance => semantic != ReturnSemantic.rootNoReturn;

  /// Is this hierarchical return (as opposed to cancelling or dismissing)?
  /// Presentation uses this to choose Back vs Cancel vs Close — the founder
  /// ruling is explicit that these must not be confused.
  bool get isHierarchical => const {
        ReturnSemantic.stackReturn,
        ReturnSemantic.parentReturn,
        ReturnSemantic.contextReturn,
        ReturnSemantic.deepLinkFallback,
      }.contains(semantic);

  @override
  String toString() => 'ReturnAction($semantic, $destination)';
}

/// Whether a candidate path is a destination this app actually registers.
///
/// Injected rather than duplicated. The authority must not carry its own copy
/// of the route table: a second list is a list that drifts, which is the exact
/// defect RC6 was written about. The real implementation is built from the
/// live `GoRouter` configuration.
typedef RouteExists = bool Function(String path);

/// Destinations that are genuinely top-level and must never show a back
/// control (founder-approved primaries + the public roots).
const Set<String> _roots = {
  '/', '/home', '/public', '/messages', '/discover', '/create',
};

/// Institution workspace SECTION ROOTS. Lateral movement between these belongs
/// to the shell, so they are roots within their context — but they are not
/// application roots: entered directly they still owe a way out to the
/// institution itself.
final RegExp _institutionSectionRoot = RegExp(
  r'^/institution/([^/]+)/(explore|activity|announcements|live|spaces|'
  r'messages|meetings|members|overview|dashboard|standing)$',
);

final RegExp _institutionScoped = RegExp(r'^/institution/([^/]+)(/|$)');

/// Flow surfaces: entering one is starting a piece of work, so leaving it is
/// CANCELLING, not going back a level. Derived from the census — every one of
/// these is a create/edit/compose destination.
final RegExp _flowSurface = RegExp(
  r'(^|/)(new|create|write|edit|compose|edit-profile|get-started|'
  // §XIV: booking a time is a piece of work with a cancel, not a level in a
  // hierarchy. `/meet/:slug/book` leaves back to the page it was started from.
  r'request-verification|book|reschedule)(/|$)',
);

/// Human names for canonical parents, so an affordance can say where it goes.
const Map<String, String> _parentLabels = {
  '/messages': 'Messages',
  '/discover': 'Discover',
  '/institutions': 'Institutions',
  '/spaces': 'Spaces',
  '/home': 'Home',
  '/': 'Aura',
  '/me': 'You',
  '/admin': 'Admin',
  '/announcements': 'Announcements',
  '/saved': 'Saved',
  '/updates': 'Updates',
};

String _normalize(String path) {
  var p = path.trim();
  final q = p.indexOf('?');
  if (q >= 0) p = p.substring(0, q);
  if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
  return p.isEmpty ? '/' : p;
}

/// The canonical parent of a path, by dropping trailing segments until a
/// REGISTERED destination is found.
///
/// Structural rather than tabulated on purpose. A hand-written parent table is
/// a second source of truth about the route tree; this asks the tree.
String? _prefixParent(String path, RouteExists exists) {
  final segments = _normalize(path).split('/').where((s) => s.isNotEmpty).toList();
  for (var i = segments.length - 1; i > 0; i--) {
    final candidate = '/${segments.take(i).join('/')}';
    if (exists(candidate)) return candidate;
  }
  return null;
}

/// THE GATES — RC4's subject, and not this authority's.
///
/// A hierarchical Back on a sign-in gate would contradict a governed
/// transition, so the shared affordance declines to present for them and
/// leaves their exits to `destination_continuity.dart`.
final RegExp _gateDomain = RegExp(
  r'^/(_boot|login|register|auth|logout|verify-email|verify-pending|'
  r'complete-identity|reset-password|forgot-password|enter-institution)(/|$)'
  r'|^/institution/sign-in$',
);

/// LIVE CALL SURFACES — a BEHAVIOUR exemption, not a domain one.
///
/// R-4 (founder ruling 2026-08-25) admits Meetings to this authority: the
/// blanket `meetings|meet|realtime` protection is over. But one thing about
/// those surfaces was always right and survives on its own merits — a person
/// who is INSIDE a synchronous session does not "go back". They leave, and
/// leaving is a governed act with consequences for other people in the room:
/// it may end the meeting for everybody, it releases the camera, it writes a
/// participation record. A generic Back control that quietly popped the router
/// would perform none of that.
///
/// So the exemption is now stated in terms of what the surface IS rather than
/// which feature owns it, which is why it correctly covers a direct call at
/// `/realtime/:sessionId` and correctly does NOT cover the waiting room, the
/// meeting record, availability, or public booking — none of which is a call.
final RegExp _liveCallSurface = RegExp(
  r'^/meetings/[^/]+/live(/|$)'
  r'|^/institution/[^/]+/meetings/[^/]+/live(/|$)'
  // `/realtime/:sessionId` is a call. `/realtime` on its own is the LOBBY —
  // a list of rooms, where nobody is connected to anything and a way out is
  // exactly what is wanted.
  r'|^/realtime/[^/]+',
);

/// THE AUTHORITY.
class ReturnPathAuthority {
  const ReturnPathAuthority._();

  /// Is this destination outside the shared affordance's remit?
  ///
  /// Two populations, for two different reasons: the auth/boot gates, whose
  /// exits RC4 owns, and live call surfaces, where leaving is a governed act
  /// rather than a navigation (see [_liveCallSurface]).
  ///
  /// R-4: the Meetings Workspace is no longer among them. The authority always
  /// resolved these paths — describing them is how they adopted this — and now
  /// it presents for them too.
  static bool isProtectedDomain(String path) {
    final p = _normalize(path);
    return _gateDomain.hasMatch(p) || _liveCallSurface.hasMatch(p);
  }

  /// True for a surface a person is synchronously present on.
  static bool isLiveCallSurface(String path) =>
      _liveCallSurface.hasMatch(_normalize(path));

  /// Resolve what returning from [path] means.
  ///
  /// [canPop] is the router's own answer about whether a real predecessor
  /// exists — the difference between founder ruling §8's mode A and mode B.
  /// [isAuthed] decides which home a public informational surface falls back
  /// to. [hasUnsavedWork] lets a flow declare itself; the flow owns that fact,
  /// this owns what it means.
  static ReturnAction resolve({
    required String path,
    required bool canPop,
    required bool isAuthed,
    required RouteExists exists,
    bool hasUnsavedWork = false,
    String? institutionContext,
  }) {
    final p = _normalize(path);

    // A genuine root never acquires a fake Back, even mid-journey: the shell
    // owns movement between primaries.
    if (_roots.contains(p)) return const ReturnAction.root();

    // FLOW BEFORE HIERARCHY. Leaving an unfinished creation is cancelling it,
    // and calling that "Back" is the confusion the ruling names explicitly.
    if (_flowSurface.hasMatch(p)) {
      return ReturnAction(
        semantic: ReturnSemantic.flowCancel,
        destination: canPop ? null : _contextualFallback(p, isAuthed, exists),
        label: null,
      );
    }

    // MODE A — a real journey exists. Unwind what the person actually did
    // rather than jumping to a structural parent they never visited.
    if (canPop) {
      return const ReturnAction(semantic: ReturnSemantic.stackReturn);
    }

    // MODE B — entered directly. Derive, never manufacture.
    final institutionRoot = _institutionSectionRoot.firstMatch(p);
    if (institutionRoot != null) {
      // A section root's way out is its institution, not the application root:
      // dropping someone from an institution section into /home is the
      // context loss this chapter exists to remove.
      final address = institutionRoot.group(1)!;
      final workspace = '/institution/$address/explore';
      return ReturnAction(
        semantic: ReturnSemantic.contextReturn,
        destination: exists(workspace) ? workspace : '/institutions',
        label: 'Institution',
      );
    }

    final parent = _prefixParent(p, exists);
    if (parent != null) {
      return ReturnAction(
        semantic: ReturnSemantic.parentReturn,
        destination: parent,
        label: _parentLabels[parent],
      );
    }

    final fallback = _contextualFallback(p, isAuthed, exists);
    return ReturnAction(
      semantic: ReturnSemantic.deepLinkFallback,
      destination: fallback,
      label: _parentLabels[fallback],
    );
  }

  /// Where a directly-entered destination with no registered parent escapes to.
  ///
  /// Context first, home last. Founder ruling §8: do not default everything to
  /// `/home`, and do not use an arbitrary hardcoded parent when context can be
  /// derived.
  static String _contextualFallback(
      String path, bool isAuthed, RouteExists exists) {
    final home = isAuthed ? '/home' : '/';

    // A fallback that lands where the person already stands is a loop wearing
    // an arrow. Found by the population test on `/institutions`, whose own
    // context prefix is itself. When a candidate is the path, escalate.
    String settle(String candidate) => candidate == path ? _escalate(candidate, home) : candidate;

    final inst = _institutionScoped.firstMatch(path);
    if (inst != null) {
      final workspace = '/institution/${inst.group(1)}/explore';
      if (exists(workspace) && workspace != path) return workspace;
      return settle('/institutions');
    }
    if (path.startsWith('/messages')) return settle('/messages');
    if (path.startsWith('/admin')) return settle('/admin');
    if (path.startsWith('/me')) return settle('/me');
    if (path.startsWith('/institutions')) return settle('/institutions');
    if (path.startsWith('/u/') ||
        path.startsWith('/discover') ||
        path.startsWith('/search') ||
        path.startsWith('/spaces')) {
      return settle('/discover');
    }
    // CROSS_PLATFORM_INFORMATIONAL_DESTINATIONS (founder ruling §5): privacy,
    // terms, mission and their siblings are first-class on every client. Their
    // canonical escape is the home the VIEWER has, which differs by session —
    // that is why it is resolved rather than written into a table.
    return home;
  }

  /// One level out from a context that turned out to BE the destination.
  /// Directories belong to Discover; everything else belongs to home.
  static String _escalate(String candidate, String home) {
    const toDiscover = {'/institutions', '/spaces', '/search', '/discover'};
    if (toDiscover.contains(candidate) && candidate != '/discover') {
      return '/discover';
    }
    return home;
  }

  /// A return destination is held to the same SHAPE rules as a preserved one —
  /// no scheme, no authority, no smuggled origin, no control characters. This
  /// is the only place the two authorities touch, and only this way round.
  ///
  /// WITH ONE DELIBERATE DIFFERENCE, AND IT IS THE POINT OF BEING SIBLINGS.
  ///
  /// RC4 refuses `/` outright, and is right to: as a PRESERVED GATE TARGET,
  /// "come back to the root afterwards" says nothing a gate could not do by
  /// default. But `/` is a registered destination and the correct way out for a
  /// signed-out reader on an informational page — which is a different subject.
  ///
  /// Found by the render test, not by reasoning: the control appeared on
  /// `/terms`, was tapped, and nothing moved, because the destination had been
  /// silently refused. Conflating the two authorities would have made this
  /// unfixable without weakening RC4's open-redirect refusal for everyone.
  static String? safeDestination(String? candidate) {
    final value = (candidate ?? '').trim();
    if (value == '/') return '/';
    return validatedReturnTarget(value);
  }
}
