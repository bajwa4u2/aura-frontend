# Windows 1.4.3 — certification and Microsoft Store submission

**Date:** 2026-09-11
**Authorisation:** founder — *"then certify in window app then submit 1.4.3 in
microsoft"*

    WINDOWS CERTIFICATION            PASS — 11/11 on the real platform
    MICROSOFT STORE 1.4.3.0          PUBLISHED — LIVE
    SUBMISSION                       1152921505701875307
    STATUS                           Published (passed certification same day)
    PREVIOUS PUBLISHED               1.4.2.0, retired

**AURA IS LIVE ON THE MICROSOFT STORE AT 1.4.3.0.** Read back from the Store
API after the founder said it had landed:

    lastPublishedApplicationSubmission   1152921505701875307   <- this submission
      status                             Published
      packages                           version 1.4.3.0  x64   (1.4.2.0 gone)
    pendingApplicationSubmission         NONE

Corroborated publicly, with a control that discriminates:

    apps.microsoft.com/detail/9N6CZR88F4NT   HTTP 200, names "AURA PLATFORM"
    apps.microsoft.com/detail/9NONEXISTENT00 HTTP 410

**This is the first platform on which 1.4.3 actually reaches people.** Apple is
still Waiting for Review; Play cannot ship at all yet.

An earlier line in this document said the status was `Certification`. That was
true when it was read and stopped being true shortly afterwards -- Microsoft
certified it the same day. The lesson is the ordinary one for a queue: a status
is a reading with a timestamp, not a standing fact, and this one needed
re-reading rather than repeating.

---

## What Partner Center held before this

Read from the Store submission API, not from a record:

    application   9N6CZR88F4NT  AURA PLATFORM
    last published submission 1152921505701821118   status Published
      package     version 1.4.2.0   x64   targetPublishMode Immediate
    pending submission        NONE

**So Windows had never been updated for 1.4.3**, and nothing was in flight.
`RELEASE_CERTIFICATION_1.4.3.md` said Windows was *"not rebuilt for 1.4.3… no
Windows artifact was produced"* — the second half was already wrong when written:
the MSIX was packaged at 05:31, nineteen minutes after that line. Corrected
there.

## The artifact, and why it did not need rebuilding

    path       build/windows/x64/runner/Release/aura.msix
    sha256     05c10922ee11b58a8c3f032c692df9adc9ff68d3bb9af2be259ea9bb65289225
    bytes      33,103,223
    packaged   2026-09-11 05:31:21

Read from the package's own `AppxManifest.xml`:

    Name                   AuraPlatformLLC.AURAPLATFORM
    Version                1.4.3.0
    Publisher              CN=3E4027A7-4D4D-4492-B8DE-BBE425E307E5
    ProcessorArchitecture  x64
    DisplayName            AURA PLATFORM

**A provenance scare worth recording, because the obvious reading was wrong.**
`aura.exe` in the Release directory is dated **2026-09-09**, two days before the
package. That looks like an MSIX built around a stale binary. It is not:

    data/app.so      2026-09-11 05:27   <- the compiled Dart, rebuilt
    aura.exe         2026-09-09 12:51   <- the native runner shell
    git log 5645106b..HEAD -- windows/   (empty)

`aura.exe` is the Flutter C++ runner, which only relinks when `windows/` changes,
and `windows/` has not changed. The app itself — `app.so` — was built at 05:27
from HEAD `109f0cc1`, whose shipped-source diff to current HEAD is **empty**.
The package carries the shipping source. **A file date is evidence about a file,
not about a build.**

## Certification — 11/11, real platform, real plugins

Run against the isolated certification stack, on the current shipping source.

**Isolation verified BEFORE any case**, per doctrine, with
`scripts/identity-certification/verify-isolation.sh`:

    PASS  DATABASE_URL is the local certification database
    PASS  database host is the in-network container, not a remote host
    PASS  certification stack marker present
    PASS  no /app/.env in the container
    PASS  no production integration credentials are set
    PASS  storage endpoint is the loopback discard port — cannot reach Cloudflare
    PASS  storage key is the certification literal, not a production credential
    PASS  User table exists and is EMPTY (0 rows) before any case runs

**`institution_verification_certification_test.dart -d windows` — 5/5**

    THE PLATFORM CAN REACH THE VERIFICATION CONTRACT AT ALL
    AN ACCOUNT WITHOUT STANDING IS REFUSED, and told why
    THE REFUSAL CARRIES A MACHINE CODE, not only prose
    EVIDENCE SENT FROM WINDOWS NAMES NO SUBMITTER
    THE SHIPPED PARSER SURVIVES A REAL PAYLOAD SHAPE

**`desktop_lifecycle_test.dart -d windows` — 6/6**

    platform channels are registered on the native build
    an address reached imperatively is the address that survives
    a call surface owns the screen on this platform too
    a directly-entered destination presents a governed return
    a protected surface is NOT framed on this platform either
    the one authority answers the same way on a native client

The first run failed honestly and said why — `sign-in must succeed — has the
journey proof been run against this stack to seed the fixture?` — so
`institution-verification-journey-proof.mjs` was run to seed, and it passed.
**A suite that names its own missing precondition is worth more than one that
just goes red.**

**The Release MSIX was re-hashed after certification** and is unchanged:
`flutter test -d windows` builds a *Debug* runner and never touches the Release
artifact. The bytes submitted are the bytes certified.

**EVIDENCE_LIMITED carried forward, not quietly dropped.** Synthetic OS input
into a Flutter desktop window is unreliable on this host, so Windows *UI
interaction* is still not claimed and is still not inferred from the web build.
Logic, networking, plugin registration and the shipped parsers are what these
11 prove.

## The submission

    plan    1.4.3.0 > 1.4.2.0, acceptable            -> ready to stage
    stage   draft 1152921505701875307, upload HTTP 201
            RETIRE 1.4.2.0 marked PendingDelete
            SET PACKAGE HTTP 200
    commit  HTTP 202, CommitStarted
    status  CommitStarted -> Certification -> PUBLISHED, errors: []

The one warning is `SalesUnsupportedWarning`, which says the sales resource
moved to the dashboard. It is informational and unrelated.

### A tooling defect found and fixed on the way

The first `stage` failed at `SET PACKAGE` with:

    400 InvalidParameterValue — "Please keep all file entries for existing
    packages. If you wish to remove a package, mark it as PendingDelete.
    The following packages are missing in your update: 2000000000097864581"

`store_submit_package.py` replaced `applicationPackages` outright with the new
package. The Ingestion API reads an omitted entry as a malformed update, not as
a removal. So the wrong shape was the *ordinary* case — a version bump replaces
every package, which is exactly when the old list was dropped.

Fixed in `company/tools/windows-store-release/store_submit_package.py` (`faf57a4`):
existing entries are carried forward marked `PendingDelete`, which is how the API
is told "this one goes" and what makes the new package a replacement rather than
an addition beside the old one.

**It failed after a 33 MB upload**, which is a slow way to learn a payload shape,
so the reason is now a comment in the file rather than something to rediscover.

**The half-staged draft was aborted (HTTP 204) before retrying**, so the Store
was never left holding a malformed submission. That the tooling splits
`plan / stage / commit / abort` is what made this safe to get wrong once — the
irreversible step stayed behind its own explicit `--yes`.

## State

    MICROSOFT   1.4.3.0 PUBLISHED — LIVE. Done.
    APPLE       1.4.3 (38) submitted, Waiting for Review.
    PLAY        AAB 38 ready; blocked on Aura not being published at all.

Three platforms, three different states, none of them inferred from another.

## Housekeeping

The isolated certification stack is left running and should be torn down when
no longer needed:

    docker compose -p auracert -f docker-compose.identity-certification.yml down -v
