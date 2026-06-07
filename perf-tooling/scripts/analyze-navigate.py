#!/usr/bin/env python3
"""Measure a Home->Details navigation from a Perfetto trace captured by
navigate-profile.sh.

Auto-detects the navigation by clustering the app's presented frames: the first
cluster is the cold-start paint, the last cluster is the screen transition the
tap triggered. Anchors the press at the input dispatch immediately preceding
that burst and reports press->first-frame and press->settled (transition done).

Usage: analyze-navigate.py --trace <t> --app <pkg> [--tp BIN] [--json]
"""
import argparse, json, os


def tp_open(trace, binp):
    from perfetto.trace_processor import TraceProcessor, TraceProcessorConfig
    cfg = TraceProcessorConfig(bin_path=binp) if binp else TraceProcessorConfig()
    return TraceProcessor(trace=trace, config=cfg)


def rows(tp, q):
    try:
        return list(tp.query(q))
    except Exception:
        return []


def cluster(frames, gap_ms=500):
    """frames: sorted list of (ts, dur). Split where start gap > gap_ms."""
    out, cur = [], []
    for f in frames:
        if cur and (f[0] - cur[-1][0]) / 1e6 > gap_ms:
            out.append(cur); cur = []
        cur.append(f)
    if cur:
        out.append(cur)
    return out


def analyze(trace, app, binp):
    tp = tp_open(trace, binp)
    start = rows(tp, "select start_ts s from trace_bounds")[0].s
    frames = [(r.ts, r.dur) for r in rows(tp, f"""
        select afts.ts, afts.dur from actual_frame_timeline_slice afts
        join process p using(upid) where p.name='{app}' order by afts.ts""")]
    janks = {r.ts: r.jank_type for r in rows(tp, f"""
        select afts.ts, afts.jank_type from actual_frame_timeline_slice afts
        join process p using(upid) where p.name='{app}'""")}
    disp = [r.ts for r in rows(tp, f"""
        select ts from slice where name like 'startDispatchCycleLocked%{app}%' order by ts""")]
    tp.close()

    if not frames:
        return {"app": app, "error": "no frames"}
    clusters = cluster(frames)
    nav = clusters[-1]                       # transition burst = last cluster
    cold = clusters[0]
    nav_first_ts, nav_first_dur = nav[0]
    nav_last_ts, nav_last_dur = nav[-1]
    # press = latest input dispatch at or before the first transition frame
    press = max([d for d in disp if d <= nav_first_ts + 1_000_000] or [nav_first_ts])

    first_present = nav_first_ts + nav_first_dur
    last_present = nav_last_ts + nav_last_dur
    janky = sum(1 for (ts, _) in nav if janks.get(ts, 'None') not in ('None', None, 'Buffer Stuffing'))

    ms = lambda x: round(x / 1e6, 1)
    return {
        "app": app,
        "pressOffsetMs": ms(press - start),
        "pressToFirstFrameMs": ms(first_present - press),
        "pressToSettledMs": ms(last_present - press),
        "transitionFrames": len(nav),
        "transitionSpanMs": ms(last_present - first_present),
        "jankyFrames": janky,
        "coldStartFrames": len(cold),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--trace', required=True)
    ap.add_argument('--app', required=True)
    ap.add_argument('--tp', default=os.environ.get('PERFETTO_TP'))
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args()
    d = analyze(a.trace, a.app, a.tp)
    if a.json:
        print(json.dumps(d, indent=2)); return
    if 'error' in d:
        print(f"{a.app}: {d['error']}"); return
    print(f"== {a.app}")
    print(f"   press @ {d['pressOffsetMs']}ms into trace")
    print(f"   press -> first Details frame : {d['pressToFirstFrameMs']} ms")
    print(f"   press -> transition settled  : {d['pressToSettledMs']} ms "
          f"({d['transitionFrames']} frames, {d['jankyFrames']} janky)")


if __name__ == '__main__':
    main()
