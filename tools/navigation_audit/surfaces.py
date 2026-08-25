"""Census the navigable surfaces that have no registered route.

Sheets, dialogs and pushed pages are destinations a person can be standing in
with nothing on screen from the router's point of view. The route census cannot
see them at all, so a route-only audit would report coverage it does not have.
"""
import io, os, re, collections, json

OPENERS = {
    'showModalBottomSheet': re.compile(r'showModalBottomSheet[<(]'),
    'showDialog': re.compile(r'showDialog[<(]'),
    'showGeneralDialog': re.compile(r'showGeneralDialog[<(]'),
    'MaterialPageRoute': re.compile(r'MaterialPageRoute[<(]'),
    'Navigator.push': re.compile(r'Navigator\.(?:of\(context\)\.)?push[<(]'),
    'OverlayEntry': re.compile(r'OverlayEntry\('),
}

# Evidence that the surface can be left deliberately, from inside it.
DISMISS = re.compile(
    r'Icons\.close|context\.pop\(|Navigator\.(?:of\(context\)\.)?pop\(|'
    r'maybePop\(|TextButton\(|AuraGhostButton\(|AuraSecondaryButton\(|'
    r'onPressed:|barrierDismissible')

rows = []
per_kind = collections.Counter()
for root, _dirs, files in os.walk('lib'):
    for f in files:
        if not f.endswith('.dart'):
            continue
        p = os.path.join(root, f).replace(os.sep, '/')
        src = io.open(p, encoding='utf-8', newline='').read()
        lines = src.split(chr(10))
        for kind, rx in OPENERS.items():
            for m in rx.finditer(src):
                ln = src[:m.start()].count(chr(10))
                per_kind[kind] += 1
                # The call's own neighbourhood: enough to see whether the
                # surface it opens carries a way out.
                window = chr(10).join(lines[ln:ln + 45])
                rows.append({
                    'file': p,
                    'line': ln + 1,
                    'kind': kind,
                    'isScrollControlled': 'isScrollControlled: true' in window,
                    'barrierDismissibleFalse':
                        'barrierDismissible: false' in window,
                    'hasDismissEvidence': bool(DISMISS.search(window)),
                })

json.dump(rows, io.open('nav_surfaces.json', 'w', encoding='utf-8'), indent=1)

print('NON-ROUTE NAVIGABLE SURFACES :', len(rows))
for k, v in per_kind.most_common():
    print('  %-22s %3d' % (k, v))

sheets = [r for r in rows if r['kind'] == 'showModalBottomSheet']
full = [r for r in sheets if r['isScrollControlled']]
print()
print('modal bottom sheets            :', len(sheets))
print('  full-height (scrollControlled):', len(full),
      '<- reads as a page, not a sheet')
print('  no dismiss evidence in-window :',
      sum(1 for r in sheets if not r['hasDismissEvidence']))
print('dialogs with barrierDismissible:false :',
      sum(1 for r in rows if r['barrierDismissibleFalse']))
print('surfaces with NO dismiss evidence     :',
      sum(1 for r in rows if not r['hasDismissEvidence']))
