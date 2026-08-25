"""Classify every registered route against the founder's return-path taxonomy.

Evidence per route comes from `nav_audit.json` (runtime census joined to the
widget each route builds). Classification is deliberately conservative: a route
is only called defective when the evidence says no product-owned return exists,
and every judgement call is recorded as a rule name so the reasoning is
auditable rather than asserted.
"""
import io, json, re, os, collections

rows = json.load(io.open('nav_audit.json', encoding='utf-8'))

# ---------------------------------------------------------------- known facts
# The four founder-approved authenticated primaries + the two public primaries.
PRIMARIES = {'/home', '/messages', '/discover', '/create', '/'}

# Machinery and gates: not product destinations a person "returns" from.
MACHINERY = {'/_boot', '/login', '/register', '/auth', '/logout',
             '/complete-identity', '/verify-pending', '/enter-institution',
             '/institution/sign-in', '/reset-password', '/forgot-password'}

# Institution workspace roots — the shell's own landing surfaces.
INST_ROOT = re.compile(r'^/institution/:institutionId/(explore|activity|'
                       r'announcements|live|spaces|messages|meetings|members|'
                       r'overview|dashboard)$')

PROTECTED = re.compile(r'/(meet|meeting|meetings|realtime|live)(/|$)')


def area(path):
    if path.startswith('/institution'):
        return 'institution'
    if PROTECTED.search(path):
        return 'meetings/live (protected)'
    if path.startswith('/admin'):
        return 'admin'
    if path.startswith('/messages') or path.startswith('/direct'):
        return 'conversation'
    if path.startswith('/me'):
        return 'me/identity'
    if path.startswith('/discover') or path.startswith('/search'):
        return 'discover'
    if path.startswith('/articles') or path.startswith('/posts') \
            or path.startswith('/announcements') or path.startswith('/p/'):
        return 'publication'
    if path.startswith('/u/') or path.startswith('/institutions'):
        return 'directory/profile'
    if path in MACHINERY or path.startswith('/_'):
        return 'machinery/gate'
    return 'other'


def entry_modes(r):
    """How a person can ARRIVE. Params ⇒ addressable ⇒ deep-linkable."""
    modes = ['in-app']
    if r['params']:
        modes += ['deep-link', 'notification', 'external-link']
    elif r['segments'] >= 2:
        modes += ['deep-link']
    else:
        modes += ['deep-link']  # every registered path is a URL on web
    return modes


out = []
for r in rows:
    path = r['path']
    cls = None
    rule = None
    expected = None

    if not r['renders']:
        cls, rule, expected = 'NOT_A_SURFACE', 'redirect-only route', 'n/a'
    elif path in MACHINERY or path == '/_boot':
        cls, rule, expected = ('PROTECTED_BOUNDARY', 'auth/boot machinery',
                               'governed by RC4 destination continuity')
    elif not r['sourceFound'] and r['widget'] is None:
        cls, rule, expected = ('NOT_A_SURFACE',
                               'shorthand redirect with a loading placeholder',
                               'n/a')
    elif PROTECTED.search(path):
        cls, rule = 'PROTECTED_BOUNDARY', 'Meetings/Live — audit only'
        expected = 'TERMINAL_EXIT / governed by its own domain'
    elif path in PRIMARIES:
        cls, rule, expected = ('ROOT_NO_RETURN_REQUIRED', 'primary destination',
                               'ROOT_NO_RETURN')
    elif INST_ROOT.match(path):
        cls, rule = 'ROOT_NO_RETURN_REQUIRED', 'institution workspace root'
        expected = 'ROOT_NO_RETURN (shell owns lateral movement)'
    else:
        # A real destination. What does it expose?
        # A shared page component can draw the control the screen never
        # writes itself — but only when the screen OPTS IN. Measured:
        # exactly one screen in the product passes showBack: true.
        has_affordance = (r['backIcon'] or r['appBar']
                          or r.get('sharedBackOptIn', False))
        deep = bool(r['params'])
        if has_affordance and r['pop'] and r['canPop']:
            cls, rule = 'COMPLIANT', 'own affordance + stack-aware pop'
            expected = 'STACK_RETURN with PARENT_RETURN fallback'
        elif has_affordance and r['pop']:
            cls, rule = ('WRONG_RETURN_SEMANTICS',
                         'affordance pops without checking the stack')
            expected = 'STACK_RETURN needs a PARENT_RETURN fallback'
        elif has_affordance and r.get('fixedGo'):
            # Verified by hand on /institutions/:slug and /white-paper: the
            # control reads as Back and calls go('<fixed path>'). Right only
            # when you arrived from that one parent, and go() REPLACES the
            # stack, so it cannot unwind to wherever you actually came from.
            cls, rule = ('HARDCODED_PARENT_RETURN',
                         'back-looking control navigates to a FIXED path')
            expected = 'STACK_RETURN with PARENT_RETURN fallback'
        elif has_affordance:
            cls, rule = 'COMPLIANT', 'own affordance'
            expected = 'STACK_RETURN'
        elif deep:
            cls, rule = ('DEEPLINK_ESCAPE_MISSING',
                         'addressable detail with no product-owned return')
            expected = 'STACK_RETURN + DEEP_LINK_FALLBACK to a canonical parent'
        else:
            cls, rule = ('MISSING_RETURN_PATH',
                         'child destination with no product-owned return')
            expected = 'PARENT_RETURN'

    out.append({
        **r,
        'area': area(path),
        'entryModes': entry_modes(r),
        'expectedSemantic': expected,
        'classification': cls,
        'rule': rule,
        'mobileViable': cls in ('COMPLIANT', 'ROOT_NO_RETURN_REQUIRED',
                                'NOT_A_SURFACE', 'PROTECTED_BOUNDARY',
                                'HARDCODED_PARENT_RETURN'),
    })

json.dump(out, io.open('nav_classified.json', 'w', encoding='utf-8'), indent=1)

# ---------------------------------------------------------------------- report
def tally(key, rowset=out):
    c = collections.Counter(r[key] for r in rowset)
    return c


print('=' * 66)
print('REGISTERED ROUTE POPULATION :', len(out))
print('=' * 66)
for k, v in tally('classification').most_common():
    print('  %-28s %3d' % (k, v))

surfaces = [r for r in out if r['classification'] not in ('NOT_A_SURFACE',)]
defective = [r for r in out if r['classification'] in (
    'MISSING_RETURN_PATH', 'DEEPLINK_ESCAPE_MISSING', 'WRONG_RETURN_SEMANTICS',
    'HARDCODED_PARENT_RETURN', 'CONTEXT_LOSS', 'FLOW_EXIT_INCORRECT',
    'MODAL_EXIT_INCORRECT')]
compliant = [r for r in out if r['classification'] == 'COMPLIANT']

print()
print('audited surfaces (excl. non-surfaces):', len(surfaces))
print('  COMPLIANT                          :', len(compliant))
print('  DEFECTIVE                          :', len(defective))
print('  root / protected                   :',
      len(surfaces) - len(compliant) - len(defective))

print()
print('DEFECTS BY PRODUCT AREA')
for k, v in collections.Counter(r['area'] for r in defective).most_common():
    print('  %-28s %3d' % (k, v))

print()
print('DEEP-LINK-SPECIFIC (addressable, no escape):',
      sum(1 for r in defective if r['classification'] == 'DEEPLINK_ESCAPE_MISSING'))
print('INSTITUTION-CONTEXT defects           :',
      sum(1 for r in defective if r['area'] == 'institution'))
print('MOBILE-NON-VIABLE surfaces            :',
      sum(1 for r in surfaces if not r['mobileViable']))
print('PROTECTED (Meetings/Live) audited     :',
      sum(1 for r in out if r['classification'] == 'PROTECTED_BOUNDARY'))

print()
print('SHARED-LAYER EVIDENCE')
rend = [r for r in out if r['renders'] and r['sourceFound']]
print('  screens using AuraScaffold          :',
      sum(1 for r in rend if r['auraScaffold']),
      '(AuraScaffold renders NO header)')
print('  passing leading: into it (dropped)  :',
      sum(1 for r in rend if r['passesLeading']))
print('  hardcoding a home fallback          :',
      sum(1 for r in rend if r['hardcodedHome']))
print('  pop() without canPop() guard        :',
      sum(1 for r in rend if r['pop'] and not r['canPop']))
