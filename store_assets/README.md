# store_assets — provenance and adoption

Claimed by the Aura release workstream on 2026-09-09, on founder instruction.
This directory had been sitting untracked and unowned; two workstreams
independently declined to sweep it into a commit, which was right. This note
records what it is and what was decided about each part, so nothing here is
committed blindly.

## Provenance

Output of the **2026-09-06 store listing and compliance metadata pass**, whose
record is `STORE_LISTING_RECORD_2026-09-06.md`. That pass was explicitly scoped
to metadata only:

    NEW_BUILD_CREATED=NO · NEW_BINARY_UPLOADED=NO
    NEW_VERSION_SUBMITTED=NO · ROLLOUT_STARTED=NO

It is legitimate, careful work, and it independently corroborates what the
consoles show today — including *"Google: Closed testing – Alpha, production
never active"*, which is still true and is now the single largest constraint on
a Play release.

## Decisions

**ADOPTED — committed**

| Path | Why |
|---|---|
| `STORE_LISTING_RECORD_2026-09-06.md` | The canonical record of what each console holds and why. Load-bearing: it records that the Microsoft product name "AURA PLATFORM" is verbatim-reserved and that a prior submission failed certification when it read "Aura". |
| `build_data_safety_csv.py`, `build_feature_graphic.py`, `build_play_screenshots.py` | Generators. Committing these makes the finished assets reproducible rather than mysterious. |
| `android/screenshots/{phone,tablet}`, `android/play_feature_graphic_1024x500.png` | Finished Play assets. |
| `ios/store`, `ios/store_65` | Finished App Store assets, both required display sizes. |
| `windows/store` | Finished Microsoft Store assets. |
| `release_notes/1.4.2.md` | The shipped release's notes. |

**DISCARDED from version control — kept on disk, gitignored**

`**/raw/` — unprocessed device captures (over 20MB, iOS alone is 20MB of
`IMG_*.PNG`). They are working intermediates: the generators cut the finished
assets from them, each release supersedes them, and they are not release
inputs. Ignoring them takes the tracked footprint from 37MB to 18MB.

## Known staleness — read before reusing anything here

The record predates the 1.4.2 release. It names **1.4.1 (36)** as shipped and
**1.4.2 (37)** as "in preparation"; 1.4.2 (37) has since shipped on all three
stores. The *identity and metadata* content remains current; the *version*
lines do not.

**The screenshots depict the pre-1.4.3 product.** They were captured before the
identity reconstruction, so any surface changed by it — registration, Personal
Details, verification, the profile editor's place fields — is not represented.
They must be re-captured for the 1.4.3 listing rather than resubmitted.

A `STORE_LISTING_RECORD_2026-09-09.md` successor is owed at 1.4.3 closeout, and
should supersede rather than edit the 09-06 record, so the state each pass found
stays readable.
