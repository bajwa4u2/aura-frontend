# Aura 1.4.0 — Store Release Notes (public-facing)

Version `1.4.0+25`, client commit `b73e8a1`.

Written to the same shape as `RELEASE_NOTES_1.3.0_STORE.md`: what a person
gets, in the words they would use for it. No internal names, no defect
numbers, and no explanation of how any of it works.

---

## Google Play — Release Notes (500 characters max)

**381 characters. Paste the block between the fences exactly as it is.**

```
What's new in this release:

- Share photos and videos with the people who follow you, in one step.
- Post up to 10 photos or videos, with a cleaner multi-photo layout.
- Edit or delete your own posts without leaving Home.
- Announcements can now be unpublished or removed.
- Reliability fixes to Home, to calls, and to choosing photos from your gallery.

Thank you for using Aura.
```

The 500-character ceiling is per language, and Google counts the blank lines
and the closing line, which is why the measured figure above is the whole
block rather than the bullets alone.

---

## Why each line is here

Kept deliberately short. Every line answers "what can somebody now do, or
what stopped getting in their way" — nothing is listed because it was
difficult to build.

| Line | What shipped |
|---|---|
| Share in one step | Share posts straight to followers; no topic is asked for, because a post to your followers is not a public record |
| Up to 10 | The limit rose from five and now matches what the app will accept, so nothing is uploaded that cannot be posted |
| Cleaner multi-photo layout | Multi-image posts fill their grid instead of sitting as small tiles in empty space |
| Edit or delete from Home | Owner actions on the feed card, so a post can be managed where it is met |
| Announcements | Unpublish and remove reached the app for the first time; both existed on the server and neither could be used |
| Reliability | The Home freeze, the call controls, and photo selection opening a file browser instead of the gallery |

## Deliberately NOT mentioned

- **Anything about calls beyond "reliability".** Realtime is certified on
  Android and on the web, and is NOT certified for desktop receive or for
  iOS. A release note is not the place to imply coverage that does not
  exist.
- **The attachment-limit history.** "Up to 10" is the useful fact. That it
  used to refuse a sixth item after uploading it is our problem, not the
  reader's.
- **Anything about topics.** Compose still asks for one on a public post,
  and saying "no topic needed" without that qualifier would be wrong.

---

## Apple App Store Connect

NOT WRITTEN YET, and deliberately so. iOS certification currently returns
`VERDICT=INCOMPLETE` (zero failures, one suite with no coverage) and the
last run predates this release entirely. Store copy for a build that has
not been certified would be asserting something we have not established.
