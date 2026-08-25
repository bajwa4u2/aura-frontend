"""How is each destination actually navigated TO?

This is the half of the contract the destination cannot see. `context.push`
grows the stack, so a system back or a pop unwinds to the real predecessor.
`context.go` REPLACES it, so a destination reached that way has no predecessor
at all — and on a platform with no browser chrome there is then nothing to
return to even if the screen drew a control.
"""
import io, json, os, re, collections

NAV = re.compile(r"context\.(push|go|replace|pushReplacement)\(\s*'([^']*)'")
NAV_INTERP = re.compile(r"context\.(push|go|replace|pushReplacement)\(\s*'([^']*\$[^']*)'")

calls = collections.defaultdict(lambda: collections.Counter())
sites = collections.defaultdict(list)

for root, _dirs, files in os.walk('lib'):
    for f in files:
        if not f.endswith('.dart'):
            continue
        p = os.path.join(root, f).replace(os.sep, '/')
        src = io.open(p, encoding='utf-8', newline='').read()
        for m in NAV.finditer(src):
            verb, target = m.group(1), m.group(2)
            # Normalise an interpolated segment to a route parameter so it
            # joins against the registered route table.
            norm = re.sub(r'\$\{[^}]*\}', ':x', target)
            norm = re.sub(r'\$\w+', ':x', norm)
            calls[norm][verb] += 1
            sites[norm].append(p + '  ' + verb)

rows = json.load(io.open('nav_classified.json', encoding='utf-8'))


def route_key(path):
    return re.sub(r':\w+', ':x', path)


registered = {route_key(r['path']): r for r in rows}

matched = 0
unmatched = collections.Counter()
verb_by_class = collections.defaultdict(lambda: collections.Counter())

for target, verbs in calls.items():
    k = route_key(target)
    r = registered.get(k)
    if r is None:
        unmatched[target] += sum(verbs.values())
        continue
    matched += 1
    for v, n in verbs.items():
        verb_by_class[r['classification']][v] += n

total_push = sum(v['push'] for v in calls.values())
total_go = sum(v['go'] for v in calls.values())
total_repl = sum(v['replace'] + v['pushReplacement'] for v in calls.values())

print('literal in-app navigation call sites')
print('  push            :', total_push, '(stack grows — a return exists)')
print('  go              :', total_go, '(stack REPLACED — no predecessor)')
print('  replace         :', total_repl)
print('  distinct targets:', len(calls), ' matched to a registered route:', matched)
print()
print('NAVIGATION VERB BY DESTINATION CLASSIFICATION')
print('  %-28s %6s %6s' % ('classification', 'push', 'go'))
for cls, c in sorted(verb_by_class.items(), key=lambda kv: -sum(kv[1].values())):
    print('  %-28s %6d %6d' % (cls, c['push'], c['go']))

print()
print('DEFECTIVE destinations that are reached by go() — no stack to return to')
DEFECTIVE = {'MISSING_RETURN_PATH', 'DEEPLINK_ESCAPE_MISSING',
             'WRONG_RETURN_SEMANTICS', 'HARDCODED_PARENT_RETURN'}
worst = []
for target, verbs in calls.items():
    r = registered.get(route_key(target))
    if r and r['classification'] in DEFECTIVE and verbs['go']:
        worst.append((verbs['go'], target, r['classification']))
for n, t, c in sorted(worst, reverse=True)[:20]:
    print('  go x%-3d %-42s %s' % (n, t, c))
print('  ... total such destinations:', len(worst))

json.dump({'calls': {k: dict(v) for k, v in calls.items()}},
          io.open('nav_entrymodes.json', 'w', encoding='utf-8'), indent=1)
