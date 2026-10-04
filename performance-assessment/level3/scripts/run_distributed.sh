#!/usr/bin/env bash
# Run the Level 3 plan from the MASTER across all slaves, then build CSV + HTML results.
# Usage: SLAVES=192.168.56.11,192.168.56.12 MASTER_IP=192.168.56.10 ./run_distributed.sh [extra jmeter args]
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
JMETER=${JMETER:-jmeter}
SLAVES=${SLAVES:-192.168.56.11,192.168.56.12}
MASTER_IP=${MASTER_IP:-$( (hostname -I 2>/dev/null || ipconfig getifaddr en0) | awk '{print $1}')}
STAMP=$(date +%Y%m%d_%H%M%S)
OUT="$HERE/results/dist_${STAMP}"
mkdir -p "$OUT"

echo ">> Master ${MASTER_IP} -> slaves [${SLAVES}]"
#  -n  non-GUI            -t  plan (master serializes it and SENDS it to each slave)
#  -R  explicit slave list (overrides remote_hosts)
#  -G  GLOBAL property: pushed to every slave (-J would only set it on the master!)
#  -X  tell the slaves to exit when the test ends
#  -Djava.rmi.server.hostname  IP the slaves must use to call the master back
"$JMETER" -n \
  -t "$HERE/L3_Distributed_Dummy.jmx" \
  -R "$SLAVES" \
  -q "$HERE/config/distributed.properties" \
  -Djava.rmi.server.hostname="$MASTER_IP" \
  -Gusers="${USERS_PER_SLAVE:-10}" -Grampup=30 -Gsteps=5 -Ghold="${HOLD:-60}" \
  -Gusers.csv=data/users.csv \
  -Glogout.file="results/logout_users_{host}.csv" \
  ${EXIT_SLAVES:+-X} \
  -l "$OUT/aggregate_results.csv" \
  -j "$OUT/jmeter-master.log" \
  -e -o "$OUT/html_report" \
  "$@"

python3 "${TOOLS:-$HERE/../tools}/analyze_results.py" --load "$OUT/aggregate_results.csv" --out "$OUT/summary_metrics.md" || true
echo ">> Done: $OUT/aggregate_results.csv  |  $OUT/html_report/index.html"
