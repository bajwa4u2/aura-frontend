/// PRODUCT LANGUAGE AUTHORITY — C0.
///
/// Governs product-critical **semantics**, not prose.
///
/// ── WHAT THIS IS ─────────────────────────────────────────────────────────
/// A typed vocabulary of canonical product nouns and semantic action families,
/// so the same product action cannot acquire three different words on three
/// different screens. Measured drift that motivated it: `Try again` (29) vs
/// `Retry` (22) for one action, and `Cancel` / `Dismiss` / `Close` / `Discard`
/// used interchangeably for four genuinely different intentions.
///
/// ── WHAT THIS IS NOT ─────────────────────────────────────────────────────
/// **Not a database of every sentence in the application.** Explanatory prose,
/// body copy and contextual sentences stay where they are written. Only the
/// semantic layer is centralised:
///
///   semantic action  ProductAction.discardDraft
///   display copy     "Discard draft"   (rendered contextually)
///
/// FD-10 froze the semantics below. This file implements them; it does not
/// reopen them.
library;

/// Canonical product nouns (FD-10).
///
/// Distinctions frozen by founder decision and **never collapsed**:
///   THREAD != SPACE
///   MEETING != ROOM != LIVE
///   MEMBER != PARTICIPANT        (durable relationship vs session state)
///   PERSON != INSTITUTION != MEMBERSHIP != ACTING CONTEXT != PRESENCE
///   CORRESPONDENCE != MESSAGE/DM (governed formal form vs conversation)
///   POST is the canonical publication object; WORKS may only ever be a
///   curated/aggregate projection, never a competing publication model.
///   FOLLOW (asymmetric) != CONNECT (reciprocal, only when that capability
///   legitimately exists).
class ProductNoun {
  const ProductNoun._(this.key, this.singular, this.plural);

  final String key;
  final String singular;
  final String plural;

  /// **THE canonical human identity** (founder decision, 2026-08-15).
  ///
  /// A human being is never canonically typed or presented as "Member" merely
  /// because they use Aura or belong to an institution. [member] is a
  /// *contextual relationship status* a Person may hold — not an identity.
  ///
  /// "Aura member" remains legitimate ordinary prose **only** where it truly
  /// means *a Person who holds the relevant membership relationship*.
  static const person = ProductNoun._('person', 'Person', 'People');
  static const institution =
      ProductNoun._('institution', 'Institution', 'Institutions');
  /// A **contextual relationship status**, never an identity (founder
  /// decision, 2026-08-15). Held by a [person] with respect to an
  /// [institution] or a [space]. Membership is governed independently of who
  /// the person is.
  static const member = ProductNoun._('member', 'Member', 'Members');
  static const participant =
      ProductNoun._('participant', 'Participant', 'Participants');
  static const thread = ProductNoun._('thread', 'Thread', 'Threads');
  static const space = ProductNoun._('space', 'Space', 'Spaces');
  static const meeting = ProductNoun._('meeting', 'Meeting', 'Meetings');
  static const room = ProductNoun._('room', 'Room', 'Rooms');
  static const live = ProductNoun._('live', 'Live', 'Live');
  static const message = ProductNoun._('message', 'Message', 'Messages');

  /// AURA CONVERSATION SYSTEM (canon 2026-08-16): the dominant private
  /// communication domain noun.
  static const conversation =
      ProductNoun._('conversation', 'Conversation', 'Conversations');
  /// **ONE canonical product meaning** (founder decision, 2026-08-15): a
  /// distinct governed **formal/deliberate communication form**. This is the
  /// FD-10 meaning and it is the only one.
  ///
  /// The older architectural use of "Correspondence" as an *umbrella* for
  /// Spaces + Threads + Messages + Direct Threads is classified **LEGACY /
  /// ARCHITECTURAL NAMING DRIFT**. It has lost canonical product status as of
  /// this decision.
  ///
  /// Filesystem and package naming (`lib/features/correspondence/`,
  /// `CorrespondenceIdentity`, `correspondence_hub_screen`) may keep the
  /// legacy sense until **C7**, which owns choosing the correct umbrella name
  /// and migrating safely with compatibility preserved. Renaming paths during
  /// C0 would be unrelated implementation churn.
  ///
  /// Documentation and this authority must not treat the umbrella meaning as
  /// canonical Correspondence semantics.
  static const correspondence =
      ProductNoun._('correspondence', 'Correspondence', 'Correspondence');
  static const post = ProductNoun._('post', 'Post', 'Posts');
  static const announcement =
      ProductNoun._('announcement', 'Announcement', 'Announcements');

  static const all = <ProductNoun>[
    conversation,
    person, institution, member, participant, thread, space, meeting,
    room, live, message, correspondence, post, announcement,
  ];

  @override
  String toString() => 'ProductNoun($key)';
}

/// The five identity concepts FD-11 froze as never collapsible:
///
///     PERSON != INSTITUTION != MEMBERSHIP != ACTING CONTEXT != PRESENCE
///
/// Declared here so the distinction is *expressible and testable* rather than
/// merely written down. These are **not** product nouns — [presence] in
/// particular is a concept whose product meaning is deliberately unresolved:
/// its only implementation is a single-actor online/recency heartbeat, and the
/// six-meaning overload it acquired is retired by **C2**, which owns whatever
/// human-facing presence semantics survive.
enum IdentityConcept {
  /// The canonical human identity. See [ProductNoun.person].
  person,

  /// An organisation with a verifiable public presence.
  institution,

  /// A contextual relationship a person holds. See [ProductNoun.member].
  membership,

  /// Who a person is currently acting as (FD-9). Never their identity.
  actingContext,

  /// Real-time availability signalling. **Not** identity, **not** membership.
  presence,
}

/// The four **stop/undo** families FD-10 froze as semantically distinct.
///
/// The drift being eliminated is *arbitrary interchangeability*, not
/// vocabulary diversity: each of these means something the others do not.
enum StopIntent {
  /// Stop or withdraw an operation/intent that has **not completed**.
  cancel,

  /// Remove an item/prompt/attention projection from the person's current
  /// attention **without implying the underlying object was deleted**.
  dismiss,

  /// Close a view, panel, modal, sheet or presentation surface **without**
  /// implying cancellation or deletion.
  close,

  /// Deliberately abandon **unsaved/uncommitted** composition or draft work.
  discard,
}

/// Canonical semantic actions.
///
/// A surface refers to the action; the label comes from here. That is what
/// stops the same action acquiring a second word somewhere else.
enum ProductAction {
  /// THE canonical failed-operation action (FD-10). Replaces the
  /// `Try again` / `Retry` split for the semantic action
  /// *the previous operation failed -> attempt it again*.
  retry,

  /// Re-fetch current data on a surface that is **working**. This is NOT
  /// [retry] and the two must not be merged: `saved_screen.dart` legitimately
  /// carries both — a header `Refresh` on the loaded list and a recovery
  /// action on the error state. Only the recovery position belongs to [retry].
  refresh,

  /// Reload the application itself, e.g. the update gate picking up a new web
  /// build. Distinct from both [retry] and [refresh].
  reload,

  cancel,
  dismiss,
  close,
  discardDraft,

  send,
  publish,
  reply,

  join,
  leave,
  accept,
  decline,

  // ── MEMBERSHIP OPERATIONS (frozen doctrine) ────────────────────────────
  // `INSTITUTION_SPACE_MEMBERSHIP_DOCTRINE.md` (founder-approved, frozen):
  // "The product must distinguish these operations honestly, never renaming
  // one into the other as a shortcut fix."
  //
  // The doctrine exists because a real defect shipped: an "Add member" button
  // wired to an invitation endpoint, so the label promised immediate
  // membership and the system delivered an invitation.
  //
  // These name a SEMANTIC ACTION only. Whether the acting person may perform
  // it is decided by backend/domain authority — never inferred from the word.

  /// Direct membership establishment, where authority and product rules
  /// legitimately permit it. **No invitation, no acceptance step.**
  addMember,

  /// Issue an invitation that requires the governed invitation lifecycle:
  /// delivery, recipient attention, acceptance or decline.
  invitePerson,

  /// View and manage outstanding invitation state. Distinct from issuing one.
  manageInvites,

  /// Change which legitimate acting context — Person or Institution — a
  /// consequential action will be attributed to, **before it is committed**.
  ///
  /// Added 2026-08-15 as an approved extension discovered through C1
  /// implementation. Normal authority evolution, not C0 remediation.
  ///
  /// It does **not**: grant authority · change membership · change role ·
  /// change account or login identity · edit content · imply impersonation.
  /// It is available only when multiple legitimate acting contexts genuinely
  /// exist — see the frozen invariant **NO CHOICE WITHOUT A REAL CONSEQUENCE**.
  ///
  /// "Identity" here means selection among canonical acting identities. It
  /// never collapses PERSON / INSTITUTION / MEMBERSHIP / ACTING CONTEXT /
  /// PRESENCE / AUTHENTICATION — implementation names the mechanism
  /// acting-context selection; Product Language presents it as Switch identity.
  ///
  /// Contextual copy may describe it naturally for the surface ("Publish
  /// as…", "Sending as…", "Replying as…"). There is exactly ONE semantic
  /// action behind all of them.
  switchIdentity,

  /// Generic invitation intent, retained for surfaces where the specific
  /// membership operation is not the subject (e.g. inviting to a meeting).
  ///
  /// **Never a substitute for [addMember] or [invitePerson]** on a membership
  /// surface — the C0 gate enforces that the three stay distinct.
  invite,

  follow,
  manage,
  view,
  open,
  remove,
  save,
  edit,
}

/// Canonical labels for semantic actions.
///
/// Deliberately short: these are **action labels**, not sentences. Anything
/// longer belongs in the calling surface as contextual copy.
class ProductLabels {
  const ProductLabels._();

  static const Map<ProductAction, String> _labels = <ProductAction, String>{
    ProductAction.retry: 'Retry',
    ProductAction.refresh: 'Refresh',
    ProductAction.reload: 'Reload',
    ProductAction.cancel: 'Cancel',
    ProductAction.dismiss: 'Dismiss',
    ProductAction.close: 'Close',
    ProductAction.discardDraft: 'Discard',
    ProductAction.send: 'Send',
    ProductAction.publish: 'Publish',
    ProductAction.reply: 'Reply',
    ProductAction.join: 'Join',
    ProductAction.leave: 'Leave',
    ProductAction.addMember: 'Add member',
    ProductAction.invitePerson: 'Invite person',
    ProductAction.manageInvites: 'Manage invites',
    ProductAction.switchIdentity: 'Switch identity',
    ProductAction.invite: 'Invite',
    ProductAction.accept: 'Accept',
    ProductAction.decline: 'Decline',
    ProductAction.follow: 'Follow',
    ProductAction.manage: 'Manage',
    ProductAction.view: 'View',
    ProductAction.open: 'Open',
    ProductAction.remove: 'Remove',
    ProductAction.save: 'Save',
    ProductAction.edit: 'Edit',
  };

  static String of(ProductAction action) => _labels[action]!;

  /// The label for a stop/undo intent, so a surface must choose the *meaning*
  /// rather than reaching for whichever word feels right.
  static String forStop(StopIntent intent) {
    switch (intent) {
      case StopIntent.cancel:
        return _labels[ProductAction.cancel]!;
      case StopIntent.dismiss:
        return _labels[ProductAction.dismiss]!;
      case StopIntent.close:
        return _labels[ProductAction.close]!;
      case StopIntent.discard:
        return _labels[ProductAction.discardDraft]!;
    }
  }

  /// Words that carry **no meaning of their own** — they can only ever mean
  /// "the previous operation failed, attempt it again", which [
  /// ProductAction.retry] already owns. Enforced by the C0 architecture gate.
  ///
  /// Deliberately narrow. `Refresh` and `Reload` are **not** here: they are
  /// separate canonical actions ([ProductAction.refresh],
  /// [ProductAction.reload]) that name things retry does not. The gate governs
  /// them positionally instead — a recovery action must say Retry — rather
  /// than banning the words outright.
  ///
  /// Prose is **not** governed. Only whole action labels are.
  static const Map<String, ProductAction> prohibitedActionSynonyms =
      <String, ProductAction>{
    'try again': ProductAction.retry,
    'retry operation': ProductAction.retry,
    'try once more': ProductAction.retry,
    // Attribution switching has exactly ONE semantic action. These are not
    // different product actions; inventing them would fragment it.
    'change publisher': ProductAction.switchIdentity,
    'change sender': ProductAction.switchIdentity,
    'change speaker': ProductAction.switchIdentity,
    'change institution': ProductAction.switchIdentity,
    'change identity': ProductAction.switchIdentity,
  };
}
