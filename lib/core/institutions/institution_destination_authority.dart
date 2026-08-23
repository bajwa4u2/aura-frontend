/// INSTITUTION DESTINATION AUTHORITY — one table, two consumers.
///
/// Founder principle (2026-08-23):
///   **VISIBILITY FOLLOWS AUTHORITY FIRST. DENIAL PROTECTS THE BOUNDARY
///   SECOND.**
///
/// Navigation asks this table what to offer. The router asks the SAME table
/// whether an address may be entered. That is the point of it existing: if the
/// two kept their own lists, a destination could disappear from the rail while
/// its URL stayed open — which is precisely the shape of defect where "hidden"
/// gets mistaken for "protected".
///
/// A destination absent from this map is the PARTICIPATION BASELINE: standing
/// in the institution is itself the authority. That is a positive statement,
/// not a gap — Explore, Spaces, Messages, Meetings, Announcements, Live,
/// Activity, Members and Profile are things a member legitimately holds
/// (founder ruling D1), and Members in particular is participation because
/// canonical doctrine says "visibility follows responsibility: every member
/// sees who holds delegated capabilities".
///
/// **Hiding is not the security boundary and never was.** The backend enforces
/// every act independently. This decides what is OFFERED and what an address
/// resolves to, so nobody is handed a surface built for authority they do not
/// hold, and a stale link fails to a truthful standing surface instead of a
/// half-broken screen.
library;

import '../authority/capability_projection.dart';

/// The acts that let a viewer hold an OPERATIONAL institution surface.
///
/// Expressed as a set of administrative acts rather than a role test, so a
/// pure Representative or Host — who hold real authority, but not
/// administrative authority — do not receive an operational destination, while
/// a member holding a single delegated administrative capability does.
const List<ConsequentialAct> kOperationalInstitutionAuthority =
    <ConsequentialAct>[
  ConsequentialAct.manageMembers,
  ConsequentialAct.manageJoinRequests,
  ConsequentialAct.manageInvitations,
  ConsequentialAct.manageSpaces,
  ConsequentialAct.publishAnnouncement,
  ConsequentialAct.manageMeetings,
  ConsequentialAct.manageAvailability,
  ConsequentialAct.manageAnalytics,
];

/// Path segment → the acts that may hold it. Any one suffices, so authorities
/// compose without a variant per role.
const Map<String, List<ConsequentialAct>> kInstitutionDestinationAuthority =
    <String, List<ConsequentialAct>>{
  'dashboard': kOperationalInstitutionAuthority,
  'join-requests': [ConsequentialAct.manageJoinRequests],
  'invites': [ConsequentialAct.manageInvitations],
  'availability': [ConsequentialAct.manageAvailability],
  'domains': [ConsequentialAct.manageDomains],
  'billing': [ConsequentialAct.manageBilling],
  'edit-profile': [ConsequentialAct.manageBranding],

  // The units LIST is the structural management surface (create, retire,
  // edit). Entering one unit is participation and stays baseline — the
  // destination table keys on the section, and `units/<address>` is a
  // different destination from `units`.
  'units': [ConsequentialAct.administerUnits],

  // AUTHORING destinations. Representative authority reaches these; publishing
  // is separately governed at the act itself, not at the door.
  'posts/new': [ConsequentialAct.authorOfficialContent],
  'posts/edit': [ConsequentialAct.authorOfficialContent],
  'announcements/new': [ConsequentialAct.authorOfficialContent],
};

/// The acts required to hold [section], or an empty list for the
/// participation baseline.
List<ConsequentialAct> institutionDestinationAuthority(String section) =>
    kInstitutionDestinationAuthority[section.trim()] ??
    const <ConsequentialAct>[];

/// Whether [projection] may hold [section].
///
/// A null projection means standing has not resolved (or does not exist). It
/// is NOT treated as a refusal here — callers distinguish "still resolving"
/// from "no", because deciding on an unresolved authority is the RC2 defect
/// that made refresh unsurvivable.
bool institutionDestinationPermits(
  CapabilityProjection? projection,
  String section,
) {
  final required = institutionDestinationAuthority(section);
  if (required.isEmpty) return true;
  if (projection == null) return false;
  return required.any(
    (act) =>
        projection.presentationFor(act) == ControlPresentation.available,
  );
}

/// The section a canonical institution path names, or null when the path is
/// not an id-scoped institution destination.
///
/// `/institution/<id>/<section>[/...]` → `<section>`, except that an authoring
/// verb is part of the destination's identity: composing an institution post
/// is a different act from reading one, so `/posts/new` and
/// `/posts/<id>/edit` resolve to `posts/new` and `posts/edit` rather than
/// collapsing into `posts`.
String? institutionSectionOf(String path) {
  final parts = path.split('?').first.split('/')
    ..removeWhere((p) => p.isEmpty);
  if (parts.length < 3) return null;
  if (parts[0] != 'institution') return null;

  final section = parts[2];
  final last = parts.last;
  if (parts.length > 3 && (last == 'new' || last == 'edit')) {
    return '$section/$last';
  }

  // ENTERING a unit is not MANAGING the institution's unit topology.
  //
  // `/units` is the structural surface — create, retire, edit — and is
  // administrative. `/units/<address>` is one operating context, and
  // participating in it is baseline. Collapsing both to `units` would have
  // gated a member out of a unit they belong to, using the authority meant to
  // govern restructuring.
  //
  // Meetings deliberately do NOT work this way: `/meetings/<id>/room` stays
  // `meetings`, because a meeting instance is not a different authority from
  // the meetings surface. The distinction is specific, not a general rule.
  if (section == 'units' && parts.length > 3) return 'units/context';

  return section;
}
