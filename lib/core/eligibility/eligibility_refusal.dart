import '../errors/app_error.dart';

/// WHAT AN ELIGIBILITY REFUSAL IS, TO THE CLIENT.
///
/// The backend answers a blocked act with a 403 carrying a stable code and a
/// `details.resolvable` flag. Those two facts decide the entire affordance:
///
///   * `resolvable: true`  — the person can act right now and succeed. Offer
///     the action that resolves it, then retry.
///   * `resolvable: false` — only time will change the answer. Say so, and do
///     NOT offer a retry, because a retry button that cannot succeed is worse
///     than no button: it reads as a bug and invites repeated failure.
///
/// The refusal never says how old anyone is — Policy §5 forbids echoing the
/// date or the computed age — so the client has nothing to render but the
/// requirement and the remedy, which is exactly the intent.
enum EligibilityRefusalKind {
  /// No date of birth on file. Nothing can be decided until there is one.
  dateOfBirthRequired,

  /// Jurisdiction is undeclared AND declaring it would change the answer.
  /// The one refusal that a country selection can actually resolve.
  jurisdictionRequired,

  /// Under the account threshold.
  accountAge,

  /// Under the publication threshold.
  publicationAge,

  /// Under the flat 18 required to speak for an institution.
  institutionRepresentationAge,
}

/// The canonical backend codes. Kept as literals rather than derived from a
/// prefix so that a renamed code fails to match loudly here instead of
/// silently degrading to a generic 403 in front of a person.
const String kEligibilityDobRequired = 'ELIGIBILITY_DOB_REQUIRED';
const String kEligibilityJurisdictionRequired =
    'ELIGIBILITY_JURISDICTION_REQUIRED';
const String kEligibilityAccountAge = 'ELIGIBILITY_ACCOUNT_AGE';
const String kEligibilityPublicationAge = 'ELIGIBILITY_PUBLICATION_AGE';
const String kEligibilityInstitutionRepresentationAge =
    'ELIGIBILITY_INSTITUTION_REPRESENTATION_AGE';

class EligibilityRefusal {
  const EligibilityRefusal({
    required this.kind,
    required this.message,
    required this.resolvable,
  });

  final EligibilityRefusalKind kind;

  /// The backend's own wording. Rendered verbatim: it is the authority's
  /// sentence about its own rule, and paraphrasing it here is how the client
  /// and the policy drift apart.
  final String message;

  final bool resolvable;

  /// True when confirming a country is the specific thing that would resolve
  /// it — the only case where the confirmation sheet is worth showing.
  bool get needsJurisdiction =>
      kind == EligibilityRefusalKind.jurisdictionRequired;

  /// True when the person must supply a date of birth first.
  bool get needsDateOfBirth =>
      kind == EligibilityRefusalKind.dateOfBirthRequired;

  /// Read a refusal out of a mapped error, or null when this failure is not
  /// an eligibility refusal at all.
  ///
  /// Returns null generously. Treating an unrelated 403 as an eligibility
  /// block would put a country picker in front of someone whose real problem
  /// is that they are not a member of the institution.
  static EligibilityRefusal? from(Object? error) {
    if (error is! AppError) return null;

    final code = (error.code ?? '').trim();
    final kind = _kindFor(code);
    if (kind == null) return null;

    return EligibilityRefusal(
      kind: kind,
      message: error.message,
      // Absent means not resolvable. An older backend that does not send the
      // flag must not have its silence read as "offer them a retry".
      resolvable: error.resolvable ?? false,
    );
  }

  static EligibilityRefusalKind? _kindFor(String code) {
    switch (code) {
      case kEligibilityDobRequired:
        return EligibilityRefusalKind.dateOfBirthRequired;
      case kEligibilityJurisdictionRequired:
        return EligibilityRefusalKind.jurisdictionRequired;
      case kEligibilityAccountAge:
        return EligibilityRefusalKind.accountAge;
      case kEligibilityPublicationAge:
        return EligibilityRefusalKind.publicationAge;
      case kEligibilityInstitutionRepresentationAge:
        return EligibilityRefusalKind.institutionRepresentationAge;
      default:
        return null;
    }
  }
}
