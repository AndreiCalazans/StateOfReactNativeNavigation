#!/usr/bin/env python3
"""Extract the native cold-start breakdown from a Perfetto trace.

Reports, for the target package:
  - RNMarker.* span durations (RUN_JS_BUNDLE, REACT_BRIDGELESS_LOADING, ...),
    forwarded into atrace by the rn-perf-tooling ReactMarker forwarder,
  - peak RSS split (anon / file / GPU / HWUI),
  - Hermes GC ('hades') thread count (a proxy for the number of JS runtimes).

Requires Perfetto's trace_processor. Point at it with --tp or PERFETTO_TP, or
let the perfetto python package download it.

Usage:
  analyze-perfetto-coldstart.py --trace <t.perfetto-trace> --app <pkg> [--tp <bin>] [--json]
"""
import argparse, json, os, sys


def get_tp(bin_path):
    from perfetto.trace_processor import TraceProcessor, TraceProcessorConfig
    cfg = TraceProcessorConfig(bin_path=bin_path) if bin_path else TraceProcessorConfig()
    return TraceProcessor, cfg


def rows(tp, sql):
    try:
        return list(tp.query(sql))
    except Exception:
        return []


def analyze(trace, pkg, bin_path):
    TraceProcessor, cfg = get_tp(bin_path)
    tp = TraceProcessor(trace=trace, config=cfg)
    like = f"%{pkg}%"

    rnmarkers = [(r.name, r.cnt, round(r.total_ms, 1), round(r.max_ms, 1)) for r in rows(tp,
        "select name, count(*) cnt, sum(dur)/1e6 total_ms, max(dur)/1e6 max_ms "
        "from slice where name like 'RNMarker.%' group by name order by max_ms desc")]

    mem = {r.name: round(r.max_mb, 1) for r in rows(tp, f"""
        select tk.name, max(c.value)/1e6 max_mb
        from counter c join process_counter_track tk on c.track_id=tk.id
        join process p on tk.upid=p.upid
        where p.name like '{like}' group by tk.name""")}

    hades = rows(tp, f"""select count(*) c from thread t join process p on t.upid=p.upid
                         where p.name like '{like}' and t.name='hades'""")
    threads = rows(tp, f"""select count(*) c from thread t join process p on t.upid=p.upid
                           where p.name like '{like}'""")
    tp.close()

    pick = lambda *keys: next((mem[k] for k in keys if k in mem), None)
    return {
        'app': pkg,
        'rnMarkersMs': {n: mx for (n, c, tot, mx) in rnmarkers
                        if mx and mx > 1 and n.endswith(('LOADING', 'BUNDLE', 'STARTUP',
                                                         'RUNTIME', 'CONSTANTS', 'FILE'))},
        'peakRssMb': pick('mem.rss', 'mem.rss.watermark'),
        'rssAnonMb': pick('mem.rss.anon'),
        'rssFileMb': pick('mem.rss.file'),
        'gpuMemMb': pick('GPU Memory'),
        'hwuiMb': pick('HWUI All Memory'),
        'hadesThreads': hades[0].c if hades else None,
        'threads': threads[0].c if threads else None,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--trace', required=True)
    ap.add_argument('--app', required=True)
    ap.add_argument('--tp', default=os.environ.get('PERFETTO_TP'))
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args()
    data = analyze(a.trace, a.app, a.tp)
    if a.json:
        print(json.dumps(data, indent=2)); return
    print(f"== {a.app}")
    print(f"   peak RSS={data['peakRssMb']}MB (anon={data['rssAnonMb']} file={data['rssFileMb']} "
          f"gpu={data['gpuMemMb']} hwui={data['hwuiMb']})  hades={data['hadesThreads']} threads={data['threads']}")
    for k, v in data['rnMarkersMs'].items():
        print(f"   {v:>7.1f}ms  {k}")


if __name__ == '__main__':
    main()
