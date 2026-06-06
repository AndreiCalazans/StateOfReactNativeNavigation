#!/usr/bin/env python3
"""Aggregate per-app perf results into a comparison table.

Reads every perf-results/<label>/<label>-summary.json (cold-start) and, if
present, <label>.json (Flashlight measures) and writes:
  perf-results/comparison.json
  perf-results/comparison.md

Usage: scripts/compare.py [perf-results-dir]
"""
import json
import os
import sys
import statistics


def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None


def flashlight_summary(data):
    """Average FPS / total CPU / peak RAM across Flashlight iterations."""
    if not data or "iterations" not in data:
        return {}
    fps, cpu, ram = [], [], []
    for it in data["iterations"]:
        for m in it.get("measures", []):
            if isinstance(m.get("fps"), (int, float)):
                fps.append(m["fps"])
            c = m.get("cpu", {})
            if isinstance(c, dict) and isinstance(c.get("perName"), dict):
                cpu.append(sum(v for v in c["perName"].values() if isinstance(v, (int, float))))
            r = m.get("ram")
            if isinstance(r, (int, float)):
                ram.append(r)
    out = {}
    if fps:
        out["avgFps"] = round(statistics.mean(fps), 1)
    if cpu:
        out["avgTotalCpuPct"] = round(statistics.mean(cpu), 1)
    if ram:
        out["peakRamMb"] = round(max(ram), 1)
    return out


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else "perf-results"
    rows = []
    for label in sorted(os.listdir(base)):
        d = os.path.join(base, label)
        if not os.path.isdir(d):
            continue
        cold = load_json(os.path.join(d, f"{label}-summary.json"))
        flash = load_json(os.path.join(d, f"{label}.json"))
        row = {"app": label}
        if cold:
            row["medianDisplayedMs"] = cold.get("medianDisplayedMs")
            row["minDisplayedMs"] = cold.get("minDisplayedMs")
            row["maxDisplayedMs"] = cold.get("maxDisplayedMs")
            row["coldRuns"] = cold.get("runs")
        row.update(flashlight_summary(flash))
        if len(row) > 1:
            rows.append(row)

    rows.sort(key=lambda r: (r.get("medianDisplayedMs") is None, r.get("medianDisplayedMs") or 0))

    out_json = os.path.join(base, "comparison.json")
    with open(out_json, "w") as f:
        json.dump(rows, f, indent=2)

    # Markdown table
    headers = [
        ("app", "Library"),
        ("medianDisplayedMs", "Cold start (median ms)"),
        ("minDisplayedMs", "min"),
        ("maxDisplayedMs", "max"),
        ("avgFps", "Avg FPS"),
        ("avgTotalCpuPct", "Avg CPU %"),
        ("peakRamMb", "Peak RAM (MB)"),
    ]
    lines = []
    lines.append("# Navigation performance comparison")
    lines.append("")
    lines.append("Android cold start (OS `Displayed` metric) and Flashlight FPS/CPU/RAM")
    lines.append("over the shared navigate flow. Lower cold start / CPU / RAM is better;")
    lines.append("higher FPS is better. Device: see MEMORY.md.")
    lines.append("")
    lines.append("| " + " | ".join(h[1] for h in headers) + " |")
    lines.append("| " + " | ".join("---" for _ in headers) + " |")
    for r in rows:
        cells = []
        for key, _ in headers:
            v = r.get(key)
            cells.append("—" if v is None else str(v))
        lines.append("| " + " | ".join(cells) + " |")
    lines.append("")
    md = "\n".join(lines)
    with open(os.path.join(base, "comparison.md"), "w") as f:
        f.write(md + "\n")
    print(md)


if __name__ == "__main__":
    main()
