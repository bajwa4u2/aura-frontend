"""Emit the per-surface census as committed evidence."""
import io, json, csv, collections, os

rows = json.load(io.open('nav_classified.json', encoding='utf-8'))
surfaces = json.load(io.open('nav_surfaces.json', encoding='utf-8'))
entry = json.load(io.open('nav_entrymodes.json', encoding='utf-8'))['calls']

OUT = 'docs/navigation'
os.makedirs(OUT, exist_ok=True)

import re


def key(p):
    return re.sub(r':\w+', ':x', p)


verbs = {}
for target, v in entry.items():
    verbs.setdefault(key(target), collections.Counter()).update(v)

DEFECTIVE = {'MISSING_RETURN_PATH', 'DEEPLINK_ESCAPE_MISSING',
             'WRONG_RETURN_SEMANTICS', 'HARDCODED_PARENT_RETURN'}

with io.open(OUT + '/return_path_census.csv', 'w', encoding='utf-8', newline='') as fh:
    w = csv.writer(fh)
    w.writerow([
        'route', 'product_area', 'entry_modes', 'navigated_by',
        'current_return_mechanism', 'expected_return_semantic',
        'visible_affordance', 'system_back_effective', 'deeplink_fallback',
        'context_preservation', 'mobile_viable', 'classification',
        'required_correction', 'widget', 'file',
    ])
    for r in rows:
        v = verbs.get(key(r['path']), collections.Counter())
        nav = ' '.join('%s=%d' % (k, n) for k, n in sorted(v.items())) or 'not-navigated-by-literal'
        mech = []
        if r['backIcon']:
            mech.append('own back icon')
        if r['appBar']:
            mech.append('AppBar')
        if r.get('sharedBackOptIn'):
            mech.append('shared page showBack')
        if r['pop']:
            mech.append('pop()' + ('+canPop' if r['canPop'] else ' UNGUARDED'))
        if r.get('fixedGo'):
            mech.append('go(fixed)')
        if r['popScope']:
            mech.append('PopScope')
        # A stack exists only if something pushed to it.
        sysback = 'yes' if v.get('push') else ('no — reached by go()' if v.get('go') else 'unknown')
        w.writerow([
            r['path'], r['area'], '|'.join(r['entryModes']), nav,
            '; '.join(mech) or 'none',
            r['expectedSemantic'] or '',
            'yes' if (r['backIcon'] or r['appBar'] or r.get('sharedBackOptIn')) else 'no',
            sysback,
            'yes' if r['classification'] not in ('DEEPLINK_ESCAPE_MISSING',) and r['params'] else
            ('MISSING' if r['params'] else 'n/a'),
            'unknown' if r['classification'] in DEFECTIVE else 'ok',
            'yes' if r['mobileViable'] else 'NO',
            r['classification'], r['rule'] or '',
            r['widget'] or '', r['file'] or '',
        ])

with io.open(OUT + '/return_path_surfaces.csv', 'w', encoding='utf-8', newline='') as fh:
    w = csv.writer(fh)
    w.writerow(['file', 'line', 'kind', 'full_height', 'dismiss_evidence',
                'barrier_dismissible_false'])
    for s in surfaces:
        w.writerow([s['file'], s['line'], s['kind'],
                    s['isScrollControlled'], s['hasDismissEvidence'],
                    s['barrierDismissibleFalse']])

json.dump(rows, io.open(OUT + '/return_path_census.json', 'w', encoding='utf-8'),
          indent=1)

print('wrote', OUT + '/return_path_census.csv', len(rows), 'routes')
print('wrote', OUT + '/return_path_surfaces.csv', len(surfaces), 'surfaces')
print('wrote', OUT + '/return_path_census.json')
