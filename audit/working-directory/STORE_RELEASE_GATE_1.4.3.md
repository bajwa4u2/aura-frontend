# Aura 1.4.3 (38) — store release gate

2026-09-09. A gate is not a summary. Each condition below is either MET or NOT
MET, and **no store submission may begin while any condition is NOT MET**. The
conditions are ordered by dependency, not by importance: several later ones
cannot even be attempted until an earlier one clears.

---

## G1 — The backend is deployed before any client reaches a store

**NOT MET.**

The 1.4.3 client sends `dateOfBirth` and `jurisdiction` with a registration.
The deployed backend refuses them — proven live, not predicted:

    POST https://api.auraplatform.org/v1/auth/register  ->  400
      "property dateOfBirth should not exist"
      "property jurisdiction should not exist"

Ship the client first and every new user's registration fails on every
platform at once. This is the gate's first condition because nothing after it
matters if it is wrong.

The order is fixed and is not the intuitive one:

    1. deploy aura-backend        (identity contract, tolerant of both clients)
    2. deploy the web client      (first surface on the new contract)
    3. submit the store builds    (Apple, Microsoft; Play separately — see G6)

The backend accepts the old client's registration as well as the new one, so
step 1 is safe on its own. The reverse order is not.

## G2 — Both repositories are pushed

**NOT MET.** 26 unpushed commits on `aura-backend`, 12 on `aura_final`. Both
merges completed locally as fast-forwards; `git push origin main` was **denied
by the permission classifier** and has not been worked around.

This single condition blocks G1 (Railway deploys from GitHub), the web deploy,
and the entire iOS lane (Codemagic builds from GitHub), and therefore every
store submission. It is the highest-leverage item in this document and it needs
the founder, not more engineering.

## G3 — Artifacts exist for every platform being submitted

**PARTIALLY MET.**

| Platform | Artifact | State |
|---|---|---|
| Android | `app-release.aab`, signed, versionCode 38, target API 36 | MET |
| Windows | `aura.msix` 1.4.3.0, name "AURA PLATFORM" verbatim | MET |
| Web | `build/web` | MET |
| iOS | none | **NOT MET** — no macOS host here; needs G2 first |

## G4 — Store numbers are legal and unspent

**MET**, verified in the signed-in consoles rather than from repo notes: Apple
build 38 absent; Play versionCode 38 unused; Microsoft 1.4.3.0 above the live
1.4.2.0.

This condition is time-sensitive. It stays MET only while the frozen trees stay
frozen. Any further commit to either tree spends 38 and the next build is 39.

## G5 — Store listing assets represent the product being submitted

**NOT MET.**

`store_assets/` is now claimed and committed, and its screenshots are the
2026-09-06 capture. They depict the **pre-1.4.3** product: registration,
Personal Details, verification and the profile editor's place fields all
changed in this release and none of those changes are represented. They must be
re-captured, not resubmitted. A `STORE_LISTING_RECORD_2026-09-09.md` successor
is owed at closeout and should supersede rather than edit the 09-06 record.

## G6 — Google Play production access

**NOT MET, and not an engineering item.**

    App status:  Closed testing (10 installed audience)
    Production:  Inactive
    Console:     "Apply for access to production ... you need to run a
                  closed test which meets our criteria."

Aura has never been in Play production. This is Google's personal-developer
rule: a qualifying closed test — 12 or more testers, 14 continuous days — then
an application Google reviews. It is a founder decision with a multi-week
waiting period and it cannot be engineered around. **Apple and Microsoft are
not blocked by it**, so treating the three stores as one release is the wrong
model for 1.4.3.

## G7 — Certification is complete enough to submit

**PARTIALLY MET, and further along than it was.** Web, Android and Windows all
boot, sign in and navigate on their real platforms. The identity contract, the
age floor and the Public Profile Location repair are certified end to end. The
permanent Finance doorway is certified on Web, Windows and a physical Pixel, and
— uniquely in this release — against **another product's real implementation**,
in three passes with the Finance workstream covering no grant, a real grant and
a revocation.

Still open: iOS is uncertified at every level, and Meetings, realtime,
institution administration and messaging are EVIDENCE_LIMITED on every platform.
See `RELEASE_REGRESSION_MATRIX_1.4.3.md`.

Whether EVIDENCE_LIMITED on Meetings is acceptable for a release is a founder
judgement, not an engineering one. It is recorded here rather than quietly
rounded up to PASS.

## G8 — Finance stays dormant

**MET, and now demonstrated rather than asserted.** Every `FINANCE_*` variable
is unset in production, so all four doorway routes 404 there. When the backend
is deployed they become reachable and still grant nothing: the destination is
drawn only by an active FinanceGrant resolved from Finance's own database, and
production Finance holds one canonical book in SETUP, **zero principals and zero
grants**. The revocation pass proved the shape of the dormant case directly —
identity succeeds, the door is absent, and full Aura authority buys nothing.

Deploying 1.4.3 does not activate Finance authority, and activation is the
Finance workstream's to perform, not Aura's.

---

## Gate verdict

**CLOSED.** Four conditions are NOT MET — G1, G2, G5, G6 — and two are only
partially met. G2 is the one that unblocks the most: it is a permission the
founder grants, and G1, the iOS lane and every submission follow from it.
