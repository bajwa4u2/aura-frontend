/// Release-Client Cross-System Quality Doctrine — principle 2 (Governed
/// Communication-Content Coherence). One governed authority for how long
/// composed content may be, per content category — replacing scattered,
/// inconsistent literals (`2000` in one composer, `10000` in another,
/// nothing at all in a third) that had silently drifted out of sync with
/// what the backend actually enforces.
///
/// Values reconcile with the backend's own `@MaxLength` decorators
/// (`aura-backend/src/*/dto/*.dto.ts`) — raised toward the founder-approved
/// ~6,000-character floor where a surface was previously capped below it,
/// and set to match/preserve whichever side (frontend or backend) already
/// supported more, never silently narrowed.
class ContentLengthPolicy {
  const ContentLengthPolicy._();

  /// Member feed Posts. Was capped at 2,000 on the frontend while the
  /// backend already allowed 5,000 — raised to the founder-approved 6,000
  /// on both sides.
  static const int post = 6000;

  /// Replies to a Post or Institution Post (same composer, same backend
  /// `@MaxLength(10_000)` on both reply DTOs — replies persist through the
  /// Post/InstitutionPost model itself, not a separate Reply model). Was
  /// capped at 2,000 on the frontend; raised to unlock the backend's
  /// already-higher capacity.
  static const int reply = 10000;

  /// Institution Posts. Was capped at 10,000 on the frontend while the
  /// backend already allowed 20,000 — raised to unlock the backend's
  /// already-higher capacity.
  static const int institutionPostBody = 20000;

  /// Announcements. The backend had no length limit at all on
  /// `bodyMarkdown` — a real validation gap, not a deliberate high ceiling.
  /// Set to match Institution Posts' ceiling (comparable governance
  /// weight: long-form official institutional communication).
  static const int announcementBody = 20000;

  /// Thread/DM/Space messages. `SendMessageDto` allowed 5,000,
  /// `SendDirectMessageDto` allowed 10,000 for the same conceptual action —
  /// an unexplained inconsistency depending only on which endpoint the
  /// message happened to go through. Unified to the higher of the two,
  /// consistent with "preserve the higher existing capability."
  static const int message = 10000;
}
