"""Attribute each RUNTIME route to the widget its builder constructs.

The runtime census (`_route_census.json`) is authoritative for which routes
exist — it is the object the app navigates with. This only answers "what does
this one build", by finding the route's declaration site in router.dart and
reading forward to the next route declaration.

Declaration-site lookup rather than a nested-structure parser on purpose: a
structural parser has to reproduce go_router's own nesting to stay aligned, and
when it drifts it drops routes silently (it dropped 3, measured) — which is
precisely the class of blind spot this audit exists to remove.
"""
import io, json, os, re

ROUTER = io.open('lib/router.dart', encoding='utf-8', newline='').read()

CONSTS = {}
for root, _dirs, files in os.walk('lib'):
    for f in files:
        if not f.endswith('.dart'):
            continue
        src = io.open(os.path.join(root, f), encoding='utf-8', newline='').read()
        for m in re.finditer(r"const\s+String\s+(\w+)\s*=\s*'([^']*)'", src):
            CONSTS.setdefault(m.group(1), m.group(2))

# Every `path:` declaration in router.dart, with its resolved literal value.
DECLS = []
for m in re.finditer(r"path:\s*(?:'([^']*)'|(\w+))", ROUTER):
    if m.group(1) is not None:
        v = re.sub(r'\$\{?(\w+)\}?',
                   lambda mm: CONSTS.get(mm.group(1), mm.group(0)), m.group(1))
    else:
        v = CONSTS.get(m.group(2))
        if v is None:
            continue
    DECLS.append((m.start(), v))
DECLS.sort()

SCREENISH = re.compile(
    r'\b(_?[A-Z]\w*(?:Screen|Scope|Shell|View|Page|Gate|Picker|Hub|Room|'
    r'EntryPoint|Entry|Editor|Detail|Viewer))\b')
WRAPPERS = {
    'Scaffold', 'SizedBox', 'Center', 'Padding', 'Material', 'Container',
    'AuraScaffold', 'AuraProductState', 'SafeArea', 'Column', 'Row', 'Stack',
    'GoRoute', 'ShellRoute', 'Icons', 'EdgeInsets', 'Text', 'ValueKey',
}


# Route BOUNDARIES wrap the real destination:
#   builder: (_, s) => InstitutionRouteScope(builder: (id) => RealScreen(...))
# Attributing the route to the boundary measures the boundary's file, which
# never draws a return control — so every institution route would have been
# reported as having no way back regardless of what its screen does. Measured:
# this affected the whole institution population.
BOUNDARIES = {
    'InstitutionRouteScope', 'InstitutionSpaceRouteScope',
    'DirectThreadCutoverScope', 'BootGate', 'AppShell',
}


def _pick(names, classes):
    """Prefer a name that is a class in lib/, and never a boundary wrapper.

    `AnnouncementEditorScope` is an ENUM the builder passes as an argument;
    naming it "the screen" attributed /announcements/create to a value rather
    than a surface.
    """
    real = [n for n in names if n not in BOUNDARIES]
    for n in real:
        if n in classes:
            return n
    for n in names:
        if n in classes:
            return n
    return (real or names or [None])[0]


def widget_for(path, last_segment, classes):
    """Find this path's declaration and name the widget it builds."""
    for i, (pos, val) in enumerate(DECLS):
        if val != path and val != last_segment:
            continue
        end = DECLS[i + 1][0] if i + 1 < len(DECLS) else len(ROUTER)
        body = ROUTER[pos:end]
        if 'builder:' not in body:
            # The window closed early: a `path:` inside this route's own
            # redirect closure ended it before the builder. Reopen to the next
            # ROUTE declaration instead. (/realtime/:sessionId, measured.)
            nxt = ROUTER.find('GoRoute(', pos + 8)
            body = ROUTER[pos:nxt if nxt > 0 else len(ROUTER)]
        if 'builder:' not in body:
            return None, 'redirect-only'
        b = body[body.index('builder:'):]
        names = SCREENISH.findall(b)
        picked = _pick(names, classes)
        if picked:
            return picked, 'ok'
        others = [n for n in re.findall(r'\b(_?[A-Z]\w+)\(', b)
                  if n not in WRAPPERS]
        picked = _pick(others, classes)
        if picked:
            return picked, 'ok'
        return None, 'no-widget-name'
    return None, 'declaration-not-found'


runtime = json.load(io.open('test/navigation/_route_census.json', encoding='utf-8'))

# Index every class in lib/, private ones included.
CLASS_FILE = {}
for root, _dirs, files in os.walk('lib'):
    for f in files:
        if not f.endswith('.dart'):
            continue
        p = os.path.join(root, f).replace(os.sep, '/')
        src = io.open(p, encoding='utf-8', newline='').read()
        for m in re.finditer(r'class\s+(_?[A-Z]\w+)\s*(?:<[^>]*>)?\s+extends', src):
            CLASS_FILE.setdefault(m.group(1), p)

CACHE = {}


def read(p):
    if p not in CACHE:
        CACHE[p] = io.open(p, encoding='utf-8', newline='').read()
    return CACHE[p]


BACK_ICON = re.compile(
    r'Icons\.(arrow_back\w*|chevron_left\w*|close\w*|west\w*)')
POP = re.compile(r'context\.pop\(|Navigator\.(of\(context\)\.)?pop\(|maybePop\(')
GO_HOME = re.compile(r"\.go\('/home'\)|\.go\('/'\)")
# A control that LOOKS like Back but navigates to a FIXED path. It is a
# parent return hardcoded at the call site: correct when you arrived from
# that parent, wrong from anywhere else, and it uses go() so it replaces
# the stack rather than unwinding it.
FIXED_GO = re.compile(r"\.go\('/[^']*'\)")
CANPOP = re.compile(r'canPop\(')
POPSCOPE = re.compile(r'\bPopScope\b|\bWillPopScope\b')
APPBAR = re.compile(r'\bAppBar\(|\bSliverAppBar\(')
AURASCAF = re.compile(r'\bAuraScaffold\(')
LEADING = re.compile(r'\bleading:')

# Shared page components that CAN render a return control, and the opt-in each
# one needs. A per-file icon scan misses these entirely, which would have
# reported a screen as having no way back when its shell was drawing one.
SHARED_BACK = {
    # InstitutionPage: `showBack` → Icons.arrow_back_rounded, defaults to
    # context.pop() (unguarded).
    'InstitutionPage': re.compile(r'InstitutionPage\('),
    # GuestShell: `showBackButton` → arrow_back_rounded → maybePop().
    'GuestShell': re.compile(r'GuestShell\('),
}
OPTIN = re.compile(r'showBack(?:Button)?:\s*true')

rows = []
for r in runtime:
    path = r['path']
    last = path.rsplit('/', 1)[-1]
    widget, how = widget_for(path, last, CLASS_FILE)
    f = CLASS_FILE.get(widget) if widget else None
    src = read(f) if f else ''
    rows.append({
        'path': path,
        'segments': r['segments'],
        'params': r['params'],
        'renders': r['renders'],
        'redirectOnly': (not r['renders']) and r['hasRedirect'],
        'widget': widget,
        'attribution': how,
        'file': f,
        'sourceFound': bool(src),
        'backIcon': bool(BACK_ICON.search(src)),
        'pop': bool(POP.search(src)),
        'canPop': bool(CANPOP.search(src)),
        'popScope': bool(POPSCOPE.search(src)),
        'appBar': bool(APPBAR.search(src)),
        'auraScaffold': bool(AURASCAF.search(src)),
        'passesLeading': bool(AURASCAF.search(src) and LEADING.search(src)),
        'hardcodedHome': bool(GO_HOME.search(src)),
        'fixedGo': bool(FIXED_GO.search(src)),
        'fixedGoTargets': sorted(set(FIXED_GO.findall(src)))[:6],
        'sharedPage': [k for k, rx in SHARED_BACK.items() if rx.search(src)],
        'sharedBackOptIn': bool(
            any(rx.search(src) for rx in SHARED_BACK.values())
            and OPTIN.search(src)),
    })

json.dump(rows, io.open('nav_audit.json', 'w', encoding='utf-8'), indent=1)

rend = [r for r in rows if r['renders']]
res = [r for r in rend if r['sourceFound']]
print('registered routes       :', len(rows))
print('  renders a screen      :', len(rend))
print('  redirect-only         :', sum(1 for r in rows if r['redirectOnly']))
print('  attributed to a widget:', len(res),
      '(%.1f%%)' % (100.0 * len(res) / max(1, len(rend))))
print('  unattributed          :', len(rend) - len(res))
for r in rend:
    if not r['sourceFound']:
        print('     %-46s %s (%s)' % (r['path'], r['widget'], r['attribution']))
