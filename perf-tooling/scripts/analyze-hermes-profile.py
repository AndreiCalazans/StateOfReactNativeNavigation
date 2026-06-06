#!/usr/bin/env python3
"""Analyze source-mapped Hermes CPU profiles (Chrome trace produced by
convert-hermes-profile.js).

Reconstructs the JS-thread call tree from B/E events and reports, averaged over
the given run(s):
  - JS busy time (non-idle self time, ~ the cold-start burst),
  - distinct source files / node_modules executed,
  - CPU "blamed" to the responsible library (nearest non-infra ancestor),
  - the hottest functions by self time, with their owning module.

Usage:
  analyze-hermes-profile.py <label> <run1-hermes.json> [run2 ...] [--json]
"""
import json, sys, collections

INFRA = {'root', 'Native', 'JavaScript', 'react-native', '@react-native',
         'metro-runtime', 'react', 'react-dom', 'unknown', 'Metadata'}


def js_thread_events(path):
    evs = [e for e in json.load(open(path)) if e.get('ph') in ('B', 'E')]
    by_tid = collections.defaultdict(list)
    for e in evs:
        by_tid[e['tid']].append(e)
    tid = max(by_tid, key=lambda t: len(by_tid[t]))  # JS thread = most events
    return sorted(by_tid[tid], key=lambda e: e['ts'])


def analyze(path):
    ev = js_thread_events(path)
    self_name = collections.Counter()
    blame = collections.Counter()
    name_mod = {}
    files, mods = set(), set()
    stack, prev, busy = [], None, 0
    for e in ev:
        ts = e['ts']
        if prev is not None and stack:
            dt = ts - prev
            top = stack[-1]
            if top['name'] != '[root]':
                self_name[top['name']] += dt
                name_mod[top['name']] = top['mod']
                busy += dt
                blamed = next((fr['mod'] for fr in reversed(stack)
                               if fr['mod'] not in INFRA), top['mod'])
                blame[blamed] += dt
        prev = ts
        if e['ph'] == 'B':
            a = e.get('args') or {}
            mod = a.get('node_module') or a.get('category') or 'unknown'
            if a.get('url'):
                files.add(a['url'])
            if mod not in INFRA:
                mods.add(mod)
            stack.append({'name': e['name'], 'mod': mod})
        elif stack:
            stack.pop()
    return dict(busy_us=busy, files=len(files), mods=len(mods),
                blame=blame, self_name=self_name, name_mod=name_mod)


def main():
    args = [a for a in sys.argv[1:] if a != '--json']
    as_json = '--json' in sys.argv
    label, paths = args[0], args[1:]
    n = len(paths)
    B, SN, NM, busy, fc, mc = (collections.Counter(), collections.Counter(),
                               {}, [], [], [])
    for p in paths:
        r = analyze(p)
        busy.append(r['busy_us']); fc.append(r['files']); mc.append(r['mods'])
        B.update(r['blame']); SN.update(r['self_name']); NM.update(r['name_mod'])

    avg = lambda xs: sum(xs) / len(xs)
    data = {
        'label': label, 'runs': n,
        'jsBusyMs': round(avg(busy) / 1000, 1),
        'distinctFiles': round(avg(fc)),
        'distinctNodeModules': round(avg(mc)),
        'blameByLibraryMs': [(m, round(t / n / 1000, 1)) for m, t in B.most_common(12)],
        'hottestFunctionsMs': [(nm, round(t / n / 1000, 1), NM.get(nm, '?'))
                               for nm, t in SN.most_common(16)],
    }
    if as_json:
        print(json.dumps(data, indent=2))
        return
    print(f"### {label} (avg of {n} runs)")
    print(f"  JS busy ~{data['jsBusyMs']}ms | files ~{data['distinctFiles']} | "
          f"node_modules ~{data['distinctNodeModules']}")
    print("  -- CPU blamed to library --")
    for m, t in data['blameByLibraryMs']:
        print(f"    {t:>7}ms/run  {m}")
    print("  -- hottest functions (self) --")
    for nm, t, mod in data['hottestFunctionsMs']:
        print(f"    {t:>7}ms/run  {nm:38s} [{mod}]")


if __name__ == '__main__':
    main()
