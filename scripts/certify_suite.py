#!/usr/bin/env python3
"""Run one integration suite and derive its certification status from COVERAGE.

    CERTIFICATION STATUS DERIVES FROM DEMONSTRATED COVERAGE,
    NOT COMMAND SUCCESS.

── WHY THIS EXISTS ─────────────────────────────────────────────────────────────

The 2026-08-27 iOS run recorded three SFU suites as PASS. Each had printed
"certification identities not provided", skipped every substantive test, and
exited 0. The lane read the exit code, saw success, and wrote PASS.

Nothing had been certified. A suite that stands down because its prerequisites
are absent has produced NO evidence, and reporting that as a pass is worse than
reporting nothing — it converts an absence of testing into a claim of
correctness, and it does so silently.

So status is no longer read from the exit code. It is derived from what the
suite actually executed:

    FAIL              at least one test failed or errored
    NO_COVERAGE       applicable, but nothing substantive ran
    PASS              at least one substantive test ran and all of them passed
    SKIPPED_PLATFORM  deliberately inapplicable to this client (caller's choice)

`hidden` tests — the loading/setUpAll/tearDownAll bookkeeping the runner emits —
are excluded from every count. They always "pass" and counting them would
recreate exactly the false green this file exists to prevent: a suite where
every real test skipped still shows passing bookkeeping.

Usage:
    certify_suite.py <suite.dart> [--device UDID] [--out DIR]

Prints a one-line verdict, writes <out>/<suite>.json with the full counts, and
exits 0 for PASS, 1 for FAIL, 2 for NO_COVERAGE — so a caller can distinguish
"nothing ran" from "something broke", which the old lane could not.
"""

import argparse
import json
import os
import subprocess
import sys


def flutter_executable() -> str:
    """The Flutter launcher for this host.

    On Windows the entry point is `flutter.bat`; `subprocess` will not find a
    bare `flutter` there. The certification host is macOS and the authoring
    host is windows-arm64, so this script has to run on both.
    """
    from shutil import which
    for candidate in ("flutter", "flutter.bat"):
        found = which(candidate)
        if found:
            return found
    return "flutter"


# THE CREDENTIALS THE REALTIME SUITES READ ARE COMPILE-TIME, NOT ENVIRONMENT.
#
# `relay_certification_test`, `sfu_certification_test` and their neighbours read
# their identity through `String.fromEnvironment('AURA_CERT_EMAIL')`. That is a
# `--dart-define`, resolved when the test is COMPILED. An exported shell
# variable of the same name reaches this process and never reaches the compiler,
# so the constant stays empty and every substantive test stands itself down.
#
# The 2026-08-29 run proved it: the `aura_cert` group was added to the workflow,
# the variables were present in the build environment, and the suites still
# reported NO_COVERAGE with "certification identities not provided". Injecting
# the group was necessary and did nothing on its own — the last hop was missing.
#
# So the runner forwards them itself. Values are never printed; only the NAMES
# of what was forwarded are echoed, which is enough to tell a NO_COVERAGE caused
# by a missing credential apart from one caused by a suite that simply cannot
# run here.
# Every name an integration suite reads through `String.fromEnvironment`, so a
# credential that exists in the build environment is never lost at this hop.
# Forwarding a name that is not set is a no-op, so the list may safely exceed
# what any single lane provides — a suite whose identities are genuinely absent
# still reports NO_COVERAGE, which is the honest outcome.
_FORWARDED_DEFINES = (
    "AURA_API_BASE",
    "AURA_CERT_EMAIL",
    "AURA_CERT_PASSWORD",
    # the multi-identity suites (SFU multiparty, media service, thread parity)
    "AURA_SFU_CERT_EMAILS",
    "AURA_SFU_CERT_PASSWORD",
    "AURA_EXTRA_EMAIL",
    "AURA_EXTRA_PASSWORD",
)


def forwarded_names() -> list[str]:
    """The forwarded variables that are actually set in this environment."""
    return [name for name in _FORWARDED_DEFINES if os.environ.get(name)]


def run(suite: str, device: str | None) -> tuple[list[dict], int, list[str]]:
    cmd = [flutter_executable(), "test", suite, "--reporter", "json"]
    if device:
        cmd += ["-d", device]

    forwarded = forwarded_names()
    cmd += [f"--dart-define={name}={os.environ[name]}" for name in forwarded]
    print(
        "dart-defines forwarded: " + (", ".join(forwarded) if forwarded else "none"),
        flush=True,
    )

    events: list[dict] = []
    markers: list[str] = []
    proc = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        encoding="utf-8", errors="replace",
    )
    assert proc.stdout is not None
    for line in proc.stdout:
        line = line.strip()
        # The runner interleaves plain build output with the JSON stream; the
        # non-JSON lines are still worth echoing so a build log stays readable.
        if not line.startswith("{"):
            if line:
                print(line, flush=True)
                # A SUITE THAT NEVER REACHED THE DEVICE HAS NOT FAILED ITS
                # ASSERTIONS.
                #
                # When the runner cannot run a suite on the device it still
                # emits testStart/testDone for every declared test and marks
                # them failed. On an Android emulator that died during
                # `adb install` that produced "discovered 9, executed 9,
                # failed 9" beside the line "No tests were found." - and it was
                # read, for three runs, as nine Android assertions failing.
                # Not one assertion had been evaluated.
                if "No tests were found" in line:
                    markers.append("no-tests-found")
                elif "device offline" in line or "Device disconnected" in line:
                    markers.append("device-offline")
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return events, proc.wait(), markers


def classify(events: list[dict]) -> dict:
    # name/skip metadata arrives on testStart, the outcome on testDone.
    meta: dict[int, dict] = {}
    for e in events:
        if e.get("type") == "testStart":
            t = e.get("test", {})
            meta[t.get("id")] = t

    # WHY A FAILURE FAILED, NOT JUST THAT IT DID.
    #
    # This runner used to report `FAILED : <test name>` and nothing else, so a
    # red suite in CI could not be diagnosed from CI output at all - the iOS
    # lane could not name which Meetings route broke, and the Android lane could
    # not say why nine assertions that pass on desktop fail on an emulator.
    # The reason is already in the JSON stream; it was simply being discarded.
    errors: dict[object, str] = {}
    for e in events:
        if e.get("type") != "error":
            continue
        tid = e.get("testID")
        if tid is None or tid in errors:
            continue
        first = (e.get("error") or "").strip().splitlines()
        if first:
            errors[tid] = first[0][:200]

    discovered = passed = failed = skipped = unexplained = 0
    skip_reasons: list[str] = []
    failures: list[str] = []

    for e in events:
        if e.get("type") != "testDone":
            continue
        # BOOKKEEPING IS NOT COVERAGE. Hidden entries always succeed, so
        # counting them is precisely how an all-skipped suite looks green.
        if e.get("hidden"):
            continue

        discovered += 1
        t = meta.get(e.get("testID"), {})
        name = t.get("name", "?")

        if e.get("skipped"):
            skipped += 1
            reason = (t.get("metadata") or {}).get("skipReason")
            skip_reasons.append(f"{name}: {reason}" if reason else name)
        elif e.get("result") == "success":
            passed += 1
        else:
            failed += 1
            detail = errors.get(e.get("testID"), "")
            # A FAILURE WITH NO ERROR IS NOT AN ASSERTION.
            #
            # When a test genuinely fails an expectation the JSON stream
            # carries an `error` event for it. A run that lost its device
            # mid-flight produces testDone(result != success) for every
            # enumerated test with NO error beside it. Those two look identical
            # in a count and mean opposite things, so the distinction is
            # recorded rather than inferred later from a build log.
            if not detail:
                unexplained += 1
            failures.append(f"{name} -- {detail}" if detail else name)

    executed = passed + failed

    if failed:
        status = "FAIL"
    elif executed == 0:
        # Applicable, ran, asserted nothing. This is the case that used to
        # report PASS.
        status = "NO_COVERAGE"
    else:
        status = "PASS"

    return {
        "status": status,
        "discovered": discovered,
        "executed": executed,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "skip_reasons": skip_reasons[:10],
        "failures": failures[:10],
        # How many of the failures arrived without any assertion error at all.
        # failed == unexplained is the signature of a run that was aborted,
        # not of a product that is broken.
        "unexplained_failures": unexplained,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("suite")
    ap.add_argument("--device")
    ap.add_argument("--out", default="certification")
    args = ap.parse_args()

    name = os.path.splitext(os.path.basename(args.suite))[0]
    events, exit_code, markers = run(args.suite, args.device)
    r = classify(events)
    r["suite"] = name
    r["process_exit_code"] = exit_code

    # THE SUITE NEVER REACHED THE DEVICE.
    #
    # `flutter test` marks every declared test failed when it cannot run them,
    # so a device that dies during `adb install` produces a full set of
    # "failures" that no assertion ever evaluated. Reporting that as FAIL says
    # the product is broken; reporting it as DEVICE_FAILURE says the run did
    # not happen, which is what actually occurred. It is the same rule the rest
    # of this file exists for, applied one layer lower: not-run is not a
    # verdict about the code.
    if r["failed"] and r["failed"] == r.get("unexplained_failures"):
        r["note"] = (
            f"all {r['failed']} failures arrived with NO assertion error, which "
            "is the signature of a run aborted mid-flight rather than of "
            "expectations that were evaluated and failed"
        )

    if markers:
        r["device_markers"] = sorted(set(markers))
        r["status"] = "DEVICE_FAILURE"
        r["note"] = (
            "the suite never ran on the device (" + ", ".join(sorted(set(markers)))
            + ") — the recorded failures are the runner marking declared tests "
            "unrunnable, NOT assertions that were evaluated"
        )

    # THE DISAGREEMENT WORTH SEEING. When the exit code says success and the
    # coverage says otherwise, that gap is the defect this file was written
    # for, so it is stated rather than quietly resolved.
    if exit_code == 0 and r["status"] != "PASS":
        r["note"] = (
            f"process exited 0 but status is {r['status']} — "
            "exit code is not evidence of coverage"
        )

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, f"{name}.json"), "w", encoding="utf-8") as f:
        json.dump(r, f, indent=2)

    # THE RAW STREAM, KEPT. Three Android runs were spent re-deriving what the
    # events already said, because only the summary survived as an artifact.
    with open(
        os.path.join(args.out, f"{name}.events.json"), "w", encoding="utf-8"
    ) as f:
        json.dump(events, f)

    print(
        f"  {r['status']:<16} {name}  "
        f"(discovered {r['discovered']}, executed {r['executed']}, "
        f"passed {r['passed']}, failed {r['failed']}, skipped {r['skipped']})",
        flush=True,
    )
    for reason in r["skip_reasons"]:
        print(f"      skipped: {reason}", flush=True)
    for fail in r["failures"]:
        print(f"      FAILED : {fail}", flush=True)

    if r.get("note") and r["status"] == "DEVICE_FAILURE":
        print(f"      {r['note']}", flush=True)

    # DEVICE_FAILURE certifies nothing, so it shares NO_COVERAGE's exit code
    # rather than FAIL's. A lane must not read "the emulator died" as "the
    # product is broken".
    return {"PASS": 0, "FAIL": 1, "NO_COVERAGE": 2, "DEVICE_FAILURE": 2}[r["status"]]


if __name__ == "__main__":
    sys.exit(main())
