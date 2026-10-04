#!/usr/bin/env bash
# Level 1 runner: Baseline TG then Load TG (serialized), separate CSVs, HTML report for the load run.
# Override any knob: ./run_level1.sh -Jload.duration=600 -Jbaseline.iterations=30
set -euo pipefail
cd "$(dirname "$0")"
JMETER=${JMETER:-jmeter}
STAMP=$(date +%Y%m%d_%H%M%S)
OUT="$(pwd)/results/run_${STAMP}"
mkdir -p "$OUT"

echo ">> Running baseline + load (non-GUI). Results -> $OUT"
"$JMETER" -n \
  -t L1_FakeStore_Journey.jmx \
  -q ../tools/report.properties \
  -Jresults.dir="$OUT" \
  -j "$OUT/jmeter.log" \
  "$@"

echo ">> Generating HTML dashboard for the LOAD run only"
"$JMETER" -g "$OUT/load_results.csv" -o "$OUT/html_report_load" -q ../tools/report.properties

echo ">> Baseline vs Load summary + SLA verdict"
python3 ../tools/analyze_results.py \
  --baseline "$OUT/baseline_results.csv" \
  --load "$OUT/load_results.csv" \
  --sla sla.json \
  --out "$OUT/summary_metrics.md"

echo ">> Done. Open $OUT/html_report_load/index.html"
