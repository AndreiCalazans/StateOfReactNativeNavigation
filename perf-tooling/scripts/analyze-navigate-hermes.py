#!/usr/bin/env python3
"""Isolate the JS 'navigation burst' in a Hermes profile captured during a
Home->Details navigation (navigate-profile.sh).

The profile contains: a startup burst, a long idle, then the navigation burst
(render Details + Fabric commit) triggered by the tap, then idle until dump.
This finds the busy clusters (leaf != [root]) and reports the LAST one (the
navigation): wall duration, JS busy, CPU blamed to each library, and the
hottest functions = the call stack that mounted the screen.

Usage: analyze-navigate-hermes.py <label> <run-hermes.json> [--json]
"""
import json, sys, collections

INFRA = {'root', 'Native', 'JavaScript', 'react-native', '@react-native',
         'metro-runtime', 'react', 'react-dom', 'unknown', 'Metadata'}


def js_events(path):
    evs = [e for e in json.load(open(path)) if e.get('ph') in ('B', 'E')]
    by = collections.defaultdict(list)
    for e in evs:
        by[e['tid']].append(e)
    tid = max(by, key=lambda t: len(by[t]))
    return sorted(by[tid], key=lambda e: e['ts'])


def analyze(path, gap_ms=250):
    ev = js_events(path)
    t0 = ev[0]['ts']
    # Walk, attribute each inter-event interval to current leaf; collect busy
    # intervals (leaf != [root]) with their frame+module.
    stack, prev = [], None
    busy = []   # (start, end, name, mod)
    for e in ev:
        ts = e['ts']
        if prev is not None and stack:
            top = stack[-1]
            if top['name'] != '[root]':
                busy.append((prev, ts, top['name'], top['mod'],
                             tuple((f['name'], f['mod']) for f in stack)))
        prev = ts
        if e['ph'] == 'B':
            a = e.get('args') or {}
            stack.append({'name': e['name'],
                          'mod': a.get('node_module') or a.get('category') or 'unknown'})
        elif stack:
            stack.pop()

    # Cluster busy intervals separated by > gap_ms of idle.
    clusters = []
    cur = []
    for b in busy:
        if cur and (b[0] - cur[-1][1]) / 1e3 > gap_ms:
            clusters.append(cur); cur = []
        cur.append(b)
    if cur:
        clusters.append(cur)
    if not clusters:
        return None

    def summarize(cl):
        self_name = collections.Counter()
        blame = collections.Counter()
        name_mod = {}
        bus = 0
        for (s, e_, name, mod, stk) in cl:
            dt = e_ - s
            self_name[name] += dt
            name_mod[name] = mod
            bus += dt
            blamed = next((m for (n, m) in reversed(stk) if m not in INFRA), mod)
            blame[blamed] += dt
        return {
            'startOffsetMs': round((cl[0][0] - t0) / 1e3, 1),
            'wallMs': round((cl[-1][1] - cl[0][0]) / 1e3, 1),
            'jsBusyMs': round(bus / 1e3, 1),
            'blame': blame.most_common(8),
            'top': [(n, round(t / 1e3, 1), name_mod[n]) for n, t in self_name.most_common(14)],
        }

    # Navigation = everything after the startup cluster (render + commit +
    # didAppear may land in a few sub-bursts; merge them all).
    nav_intervals = [b for cl in clusters[1:] for b in cl]
    return {
        'startup': summarize(clusters[0]),
        'navigation': summarize(nav_intervals) if nav_intervals else summarize(clusters[-1]),
        'numClusters': len(clusters),
    }


def main():
    args = [a for a in sys.argv[1:] if a != '--json']
    as_json = '--json' in sys.argv
    label, path = args[0], args[1]
    r = analyze(path)
    if as_json:
        print(json.dumps({'label': label, **r}, indent=2)); return
    nav = r['navigation']
    print(f"### {label}: navigation burst (of {r['numClusters']} JS bursts)")
    print(f"  start≈{nav['startOffsetMs']}ms into profile | wall={nav['wallMs']}ms | JS busy={nav['jsBusyMs']}ms")
    print("  -- CPU blamed to library --")
    for m, t in nav['blame']:
        print(f"    {round(t/1e3,1):>6}ms  {m}")
    print("  -- hottest functions (mount call stack leaves) --")
    for n, t, mod in nav['top']:
        print(f"    {t:>6}ms  {n:36s} [{mod}]")


if __name__ == '__main__':
    main()
