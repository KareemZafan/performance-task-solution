#!/usr/bin/env python3
"""
Turn JMeter CSV result files (JTL) into a per-transaction summary and an SLA verdict.

Usage:
  analyze_results.py --load load.csv [--baseline baseline.csv] [--sla sla.json] [--out summary.md]

Percentiles use the same "nearest rank" method as the JMeter HTML dashboard,
so the numbers match what you see in the report.
"""
import argparse
import csv
import json
import math
import sys
from collections import defaultdict


def percentile(sorted_values, pct):
    if not sorted_values:
        return 0
    rank = math.ceil(pct / 100.0 * len(sorted_values))
    return sorted_values[max(rank, 1) - 1]


def load_jtl(path):
    rows = defaultdict(list)
    first_ts, last_end = None, None
    with open(path, newline="", encoding="utf-8") as fh:
        for r in csv.DictReader(fh):
            ts, elapsed = int(r["timeStamp"]), int(r["elapsed"])
            first_ts = ts if first_ts is None else min(first_ts, ts)
            last_end = ts + elapsed if last_end is None else max(last_end, ts + elapsed)
            rows[r["label"]].append((elapsed, r["success"].lower() == "true", r["responseCode"]))
    duration_s = max((last_end - first_ts) / 1000.0, 1) if first_ts else 1
    return rows, duration_s


def summarize(rows, duration_s):
    out = {}
    for label, samples in sorted(rows.items()):
        times = sorted(s[0] for s in samples)
        errors = sum(1 for s in samples if not s[1])
        codes = defaultdict(int)
        for s in samples:
            codes[s[2]] += 1
        out[label] = {
            "count": len(samples),
            "error_pct": round(100.0 * errors / len(samples), 2),
            "avg": round(sum(times) / len(times)),
            "min": times[0],
            "max": times[-1],
            "p90": percentile(times, 90),
            "p95": percentile(times, 95),
            "p99": percentile(times, 99),
            "tps": round(len(samples) / duration_s, 2),
            "codes": dict(codes),
        }
    return out


def delta(new, old):
    if not old:
        return "n/a"
    return f"{(new - old) / old * 100:+.0f}%"


def verdict(label, stats, sla):
    rule = sla.get("transactions", {}).get(label, sla.get("default", {}))
    checks = []
    for metric in ("avg", "p90", "p95"):
        limit = rule.get(f"{metric}_ms")
        if limit is not None:
            checks.append((f"{metric}<={limit}ms", stats[metric] <= limit))
    err_limit = rule.get("error_pct", sla.get("default", {}).get("error_pct"))
    if err_limit is not None:
        checks.append((f"err<={err_limit}%", stats["error_pct"] <= err_limit))
    ok = all(c[1] for c in checks)
    failed = [c[0] for c in checks if not c[1]]
    return ("PASS" if ok else "FAIL"), failed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--load", required=True)
    ap.add_argument("--baseline")
    ap.add_argument("--sla")
    ap.add_argument("--out")
    a = ap.parse_args()

    load = summarize(*load_jtl(a.load))
    base = summarize(*load_jtl(a.baseline)) if a.baseline else {}
    sla = json.load(open(a.sla)) if a.sla else {}

    lines = []
    if base:
        lines += ["### Baseline metrics (ms)", "",
                  "| Transaction | Samples | Err % | Avg | P90 | P95 | Max |",
                  "|---|---:|---:|---:|---:|---:|---:|"]
        for k, s in base.items():
            lines.append(f"| {k} | {s['count']} | {s['error_pct']} | {s['avg']} | {s['p90']} | {s['p95']} | {s['max']} |")
        lines.append("")

    title = "### Load metrics (ms) compared with baseline" if base else "### Metrics (ms)"
    lines += [title, "",
              "| Transaction | Samples | TPS | Err % | Avg | Δ Avg | P90 | Δ P90 | P95 | Δ P95 | Codes |",
              "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|"]
    for k, s in load.items():
        b = base.get(k, {})
        codes = ", ".join(f"{c}:{n}" for c, n in sorted(s["codes"].items()))
        lines.append(f"| {k} | {s['count']} | {s['tps']} | {s['error_pct']} | {s['avg']} | {delta(s['avg'], b.get('avg'))} "
                     f"| {s['p90']} | {delta(s['p90'], b.get('p90'))} | {s['p95']} | {delta(s['p95'], b.get('p95'))} | {codes} |")
    lines.append("")

    if sla:
        lines += ["### SLA verdict (load run)", "",
                  "| Transaction | Thresholds | Verdict | Breached |", "|---|---|---|---|"]
        overall = True
        for k, s in load.items():
            rule = sla.get("transactions", {}).get(k, sla.get("default", {}))
            th = ", ".join(f"{m}≤{rule[m + '_ms']}" for m in ("avg", "p90", "p95") if m + "_ms" in rule)
            th += f", err≤{rule.get('error_pct', sla.get('default', {}).get('error_pct'))}%"
            v, failed = verdict(k, s, sla)
            overall &= v == "PASS"
            lines.append(f"| {k} | {th} | **{v}** | {', '.join(failed) or '-'} |")
        lines += ["", f"**Overall verdict: {'PASS' if overall else 'FAIL'}**", ""]

    text = "\n".join(lines)
    if a.out:
        open(a.out, "w").write(text)
    print(text)


if __name__ == "__main__":
    sys.exit(main())
