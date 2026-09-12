# Call instrumentation — the two concerns, separated

**Date:** 2026-09-11, post-restart recovery
**Authorisation:** founder — *"The current dirty diff contains two different
things: DIAGNOSTIC INSTRUMENTATION and BEHAVIORAL CHANGE. Therefore the current
Pixel build cannot be treated as a pure diagnostic overlay on 1.4.3. Separate
those concerns before any future call work."*

    LIVE CALLS            HOLD — NO MORE LIVE CALLS = TRUE
    NOTHING INSTALLED     the Pixel was not touched by this separation
    MAIN WORKING TREE     unchanged; the dirty edit is still exactly as it was

---

## Why this directory exists

The uncommitted edit on `sfu_realtime_transport.dart` was written as one change
and is two. One of them only writes things down. The other changes what the
client *decides* and reports about its own binding state. A build carrying both
cannot answer the question the instrumentation was added to answer, because any
`bind_*` value it reports is now produced by a rule that the shipped 1.4.3 does
not have — so a difference between this build and production could be the defect
or could be the edit, and nothing in the trace distinguishes them.

That is the whole reason for the split. It is not tidiness.

## The three patches

    00-combined-AS-INSTALLED-669cb776.patch
        The dirty diff verbatim, exactly as it stood at recovery.
        This is the source of the APK currently on the Pixel
        (sha256 669cb776547d565757ad4d10882e38229228261fbcfca1c948a280673d3b27e9).
        Preserved as evidence. Do not edit it.

    01-diagnostic-kinds-only.patch          DIAGNOSTIC — writes things down only
        (a) `kinds=` per-kind byte breakdown on the periodic `op=LIVE` line
        (b) the same breakdown on the one-shot `state=media_flowing` line
        (c) the `_kindSummary` helper, which distinguishes an ABSENT kind from a
            kind sitting at 0 bytes — the single distinction the one-way-audio
            question turns on

    02-bind-complete-semantics.patch        BEHAVIORAL — changes a decision
        `bind_complete` now additionally requires `bound >= receivingLines`, so a
        client with two receiving m-lines and one binding reports `bind_partial`.
        HELD SEPARATELY until the defect it claims to fix is independently
        established. The reasoning for it is recorded in
        `CALL_AUDIO_ONE_WAY_DEFECT.md`; the reasoning is not the evidence.

## Both are pinned against the release source

Base for every patch is `76177ce7`, whose **shipped** tree (`lib/`,
`pubspec.yaml`, `pubspec.lock`, `android/`, `assets/`) is byte-identical to
`191642d3` — the commit the 1.4.3 artifact manifest pins. Measured:
`git diff --name-only 191642d3 HEAD -- lib/ pubspec.yaml pubspec.lock android/ assets/`
returns nothing.

Note that `RELEASE_SOURCE_FREEZE_1.4.3.md` names `90b4383e`, which is **not** the
source the shipped artifacts were built from — that record has since been
corrected, see below. `191642d3` is the one that traces to the artifacts.

## The separation is asserted, not assumed

Applying the two patches in order to the base file reproduces the installed
source exactly:

    base = git show 76177ce7:lib/features/realtime/data/sfu_realtime_transport.dart
    base + 01                 == diagnostic-only variant      IDENTICAL
    base + 01 + 02            == the source behind 669cb776   IDENTICAL
                                 sha256 9298aa812a06c13cfb3582520f915366e248e35e585292423807a673b92d8e0c

`flutter analyze` on the diagnostic-only variant, run in an isolated worktree so
the live edit was never disturbed: **No issues found!**

**A trap that cost a false failure here, worth writing down.** The first
verification reported a total mismatch — every line different, same line count.
The cause was `git apply` run from a directory *outside* the repository: this
repo sets `core.autocrlf=false`, that setting is repo-local, and Git for Windows
supplies a different default above it, so the patch was written back with CRLF
against LF sources. Any verification of these patches outside a checkout of this
repo must pass `git -c core.autocrlf=false apply`. The artifact manifest already
warns that reproducibility depends on an LF checkout; this is the same hazard
arriving through the patch tool instead of the clone.

## Both variants are BUILT and NOT INSTALLED

Built in a disposable worktree, so the main tree's
`build/app/outputs/flutter-apk/app-release.apk` is untouched and still holds the
669cb776 artifact that matches the Pixel — the only remaining copy of it.

    A. CLEAN BASELINE — no patch applied
       sha256  a3e1fa05a6201f00333405c73dde8888142e643dbdeddc1f0a944e3aaaa13834
       size    132,265,042 bytes

    B. DIAGNOSTIC-ONLY — 01 applied, 02 NOT applied
       sha256  9a6f6ea0c17cc9fb9db98caf90b53852516c7525a86f13629abff9a9d848dbff
       size    132,281,426 bytes

    kept at  <scratchpad>/artifacts/{A-clean-baseline,B-diagnostic-only}.apk

**NEITHER IS INSTALLED. The Pixel was not touched.** Live calls remain on HOLD.

## Build A did NOT reproduce `3bd637fe…`, and the reason matters

The reproduction procedure said: *"confirm sha256 `3bd637fe…` before installing.
If it differs, stop: the tree is not frozen."* It differs. The tree is fine; the
instruction was not achievable.

    clean build, worktree #1   a3e1fa05…   132,265,042 bytes
    clean build, worktree #2   4768c5b5…   132,265,042 bytes

**Identical source. Identical size. Different bytes.** Two clean builds of the
same commit, differing only in the directory they were built in, do not agree —
so `3bd637fe…` was never reproducible by rebuilding, and checking for it was a
gate that could only ever fail.

The artifact manifest had already reached this conclusion for the app bundle and
wrote it down: *"byte equality is not available as a proof that two commits
produce the same app."* What is new is that it does not hold for the **same**
commit either, and that **size is stable where bytes are not** — the clean and
instrumented builds differ by exactly 16,384 bytes, reproducibly, while two
clean builds differ by zero bytes of length and many bytes of content.

So the usable check on a rebuilt baseline is its SIZE and its SOURCE, not its
hash:

    132,265,042 bytes   built from a clean 76177ce7 tree       = baseline
    132,281,426 bytes   built with 01 (and/or 02) applied      = instrumented

That is weaker than byte equality and it is what is actually available. Anyone
tempted to restore the "confirm 3bd637fe or stop" rule should first reproduce
the two-worktree result above, which takes eight minutes and settles it.

## Rebuilding either variant

    A. CLEAN BASELINE — the shipped 1.4.3 (38) behaviour
       Build from 76177ce7 with NO patch applied.

    B. DIAGNOSTIC-ONLY — release behaviour, extra trace
       Build from 76177ce7 with 01 applied and 02 NOT applied.

A worktree needs two untracked files copied in before `flutter build apk` will
run: `android/local.properties` and `android/key.properties`. Point the latter's
`storeFile` at the main tree's `android/upload-keystore.jks` by absolute path
rather than copying the key into a temporary directory.

## A stale freeze record, found while doing this and SINCE CORRECTED

`RELEASE_SOURCE_FREEZE_1.4.3.md` says *"it names **one** source that every 1.4.3
artifact is built from"* and gives `aura_final 90b4383e`. That is not the source
the artifacts were built from. Between `90b4383e` and the manifest-pinned
`191642d3`, `lib/` changed by **22 files, 4095 insertions, 1401 deletions** —
the institution-verification work, among others, all of which ships.

The artifact manifest is internally consistent and names its own deviation
honestly (`5d9bfcdd` → `191642d3`, fifteen comment lines, no executable
statement). The freeze document is the record that did not keep up.

**Corrected on founder instruction, 2026-09-11.** `RELEASE_SOURCE_FREEZE_1.4.3.md`
now carries a block stating that `90b4383e` is a CHECKPOINT and that the
artifact-source authority is `191642d3`. `90b4383e` was not erased — it is a real
freeze point, and the discipline that produced it is what made this drift visible
at all.

The reusable lesson is in that block: a freeze document names a commit, the tree
keeps moving for good reasons, and nobody re-freezes because the document already
says "frozen". A freeze is only true while someone re-pins it. The artifact
manifest, written FROM the artifacts, is the record that cannot drift the same
way — which is why it is the authority.


---

## Working state restored — 2026-09-11

**The tracked client source is back on the clean release baseline.** The
uncommitted edit is gone from `lib/`, and the repository no longer sits in an
ambiguous modified state. Nothing was lost: the three patches in this directory
reconstruct it exactly, and that reconstruction is asserted above.

    lib/features/realtime/data/sfu_realtime_transport.dart   RESTORED to 76177ce7
    the two concerns                                          preserved as 01 / 02
    the source that built 669cb776                            preserved as 00

**The behavioural `bind_complete` change was NOT committed to product source**,
founder instruction. It lives only as `02-bind-complete-semantics.patch` until
the defect it claims to fix is independently established.

### Where the prepared binaries are, and their shelf life

    A-clean-baseline.apk               a3e1fa05…   132,265,042 bytes
    A2-clean-baseline-second-path.apk  4768c5b5…   132,265,042 bytes
    B-diagnostic-only.apk              9a6f6ea0…   132,281,426 bytes

They are in this session's scratchpad, which is **temporary** — they will not
survive indefinitely and they are far too large for git. That is acceptable
because they are reproducible from the patches above, and because the thing
worth keeping is the hash-and-size evidence, which is recorded here.

**The Pixel still carries `669cb776` and was not touched.** Neither prepared APK
was installed. `CALLS = HOLD` stands.
