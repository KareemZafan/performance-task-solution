#!/usr/bin/env bash
# Level 2 runner. Needs the "Custom Thread Groups" plugin (jpgc-casutg) - see tools/install_jmeter.sh
set -euo pipefail
cd "$(dirname "$0")"
JMETER=${JMETER:-jmeter}
STAMP=$(date +%Y%m%d_%H%M%S)
OUT="$(pwd)/results/run_${STAMP}"
mkdir -p "$OUT"

"$JMETER" -n \
  -t L2_Reqres_Journey.jmx \
  -q ../tools/report.properties \
  -l "$OUT/results.csv" \
  -j "$OUT/jmeter.log" \
  -Jlogout.file="$OUT/logout_users.csv" \
  -Jvrt.file="$OUT/request_response_log.xml" \
  -e -o "$OUT/html_report" \
  "$@"

python3 ../tools/analyze_results.py --load "$OUT/results.csv" --sla sla.json --out "$OUT/summary_metrics.md"
echo ">> Done. Report: $OUT/html_report/index.html   Logout users: $OUT/logout_users.csv"
