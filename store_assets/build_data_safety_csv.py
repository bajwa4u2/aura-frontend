"""Rewrite Aura's Play Data safety CSV from the exported template.

Every answer below is traced to code in aura_final; nothing is asserted that
was not verified. See store_assets/STORE_LISTING_RECORD_2026-09-06.md.
"""
import csv
import os

SRC = os.path.expanduser("~/Downloads/data_safety_export.csv")
DST = os.path.expanduser("~/Downloads/aura_data_safety_import.csv")

# Collected, linked, never shared, never ephemeral.
# Required = the account cannot exist without it.
REQUIRED = {"PSL_NAME", "PSL_EMAIL", "PSL_USER_ACCOUNT"}

# Optional = the person chooses whether it is ever collected (post a photo,
# record a voice note, attach a file, grant notification permission).
OPTIONAL = {
    "PSL_OTHER_MESSAGES",
    "PSL_PHOTOS",
    "PSL_VIDEOS",
    "PSL_AUDIO",
    "PSL_FILES_AND_DOCS",
    "PSL_USER_GENERATED_CONTENT",
    "PSL_DEVICE_ID",
}

ALL_TYPES = REQUIRED | OPTIONAL

# Account management applies only to the identity that makes an account work.
ACCOUNT_MGMT = {"PSL_NAME", "PSL_EMAIL", "PSL_USER_ACCOUNT"}

DELETION_URL = "https://auraplatform.org/account-deletion"

with open(SRC, newline="", encoding="utf-8") as fh:
    rows = list(csv.reader(fh))

header, body = rows[0], rows[1:]
changes = []


def set_value(row, value, why):
    if row[2] != value:
        changes.append((row[0], row[1], row[2], value, why))
        row[2] = value


for row in body:
    qid, rid = row[0], row[1]

    # 1. Data-deletion answer. Aura ships AccountDeletionScreen at
    #    /account-deletion, reachable from Security and Preferences.
    if qid == "PSL_SUPPORT_DATA_DELETION_BY_USER":
        if rid == "DATA_DELETION_YES":
            set_value(row, "true", "in-app account deletion exists")
        elif rid in ("DATA_DELETION_NO", "DATA_DELETION_NO_AUTO_DELETED"):
            set_value(row, "", "was declaring no deletion path")
        continue

    if qid == "PSL_DATA_DELETION_URL":
        set_value(row, DELETION_URL, "same route as the account deletion URL")
        continue

    # 2. Which data types are collected at all.
    if qid.startswith("PSL_DATA_TYPES_"):
        if rid in ALL_TYPES:
            set_value(row, "true", "collected by the client")
        continue

    # 3. Per-type usage and handling.
    if qid.startswith("PSL_DATA_USAGE_RESPONSES:"):
        parts = qid.split(":")
        if len(parts) != 3:
            continue
        _, dtype, question = parts
        if dtype not in ALL_TYPES:
            continue

        if question == "PSL_DATA_USAGE_COLLECTION_AND_SHARING":
            if rid == "PSL_DATA_USAGE_ONLY_COLLECTED":
                set_value(row, "true", "collected")
            elif rid == "PSL_DATA_USAGE_ONLY_SHARED":
                set_value(row, "", "never shared with third parties")

        elif question == "PSL_DATA_USAGE_EPHEMERAL":
            # Stored for the life of the account, not held for one request.
            set_value(row, "false", "persisted, not ephemeral")

        elif question == "DATA_USAGE_USER_CONTROL":
            if rid == "PSL_DATA_USAGE_USER_CONTROL_REQUIRED":
                set_value(row, "true" if dtype in REQUIRED else "", "required")
            elif rid == "PSL_DATA_USAGE_USER_CONTROL_OPTIONAL":
                set_value(row, "true" if dtype in OPTIONAL else "", "optional")

        elif question == "DATA_USAGE_COLLECTION_PURPOSE":
            if rid == "PSL_APP_FUNCTIONALITY":
                set_value(row, "true", "app functionality")
            elif rid == "PSL_ACCOUNT_MANAGEMENT":
                set_value(row, "true" if dtype in ACCOUNT_MGMT else "",
                          "account management")
            else:
                # No analytics SDK, no ad SDK, no personalisation engine.
                set_value(row, "", "not a purpose Aura has")

        elif question == "DATA_USAGE_SHARING_PURPOSE":
            set_value(row, "", "nothing is shared")

with open(DST, "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh, lineterminator="\r\n")
    w.writerow(header)
    w.writerows(body)

print(f"wrote {DST}")
print(f"{len(changes)} cells changed\n")
for qid, rid, old, new, why in changes:
    label = f"{qid}:{rid}" if rid else qid
    print(f"  {label}\n      {old!r} -> {new!r}   ({why})")
