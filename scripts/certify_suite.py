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


def run(suite: str, device: str | None) -> tuple[list[dict], int]:
    cmd = [flutter_executable(), "test", suite, "--reporter", "json"]
    if device:
        cmd += ["-d", device]

    events: list[dict] = []
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
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return events, proc.wait()


def classify(events: list[dict]) -> dict:
    # name/skip metadata arrives on testStart, the outcome on testDone.
    meta: dict[int, dict] = {}
    for e in events:
        if e.get("type") == "testStart":
            t = e.get("test", {})
            meta[t.get("id")] = t

    discovered = passed = failed = skipped = 0
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
            failures.append(name)

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
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("suite")
    ap.add_argument("--device")
    ap.add_argument("--out", default="certification")
    args = ap.parse_args()

    name = os.path.splitext(os.path.basename(args.suite))[0]
    events, exit_code = run(args.suite, args.device)
    r = classify(events)
    r["suite"] = name
    r["process_exit_code"] = exit_code

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

    return {"PASS": 0, "FAIL": 1, "NO_COVERAGE": 2}[r["status"]]


if __name__ == "__main__":
    sys.exit(main())
