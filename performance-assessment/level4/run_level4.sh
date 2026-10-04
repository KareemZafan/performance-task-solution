#!/usr/bin/env bash
# Level 4: start InfluxDB + Grafana, run the dummy plan with the Backend Listener, watch it live in Grafana.
set -euo pipefail
cd "$(dirname "$0")"
JMETER=${JMETER:-jmeter}
STAMP=$(date +%Y%m%d_%H%M%S)
OUT="$(pwd)/results/run_${STAMP}"
mkdir -p "$OUT"

echo ">> Starting monitoring stack"
docker compose up -d
until curl -sf http://localhost:8086/health >/dev/null; do sleep 2; done
until curl -sf http://localhost:3000/api/health >/dev/null; do sleep 2; done
echo ">> Grafana: http://localhost:3000/d/jmeter-19950  (admin/admin) - set time range 'Last 15 minutes', refresh 5s"

"$JMETER" -n \
  -t L4_Monitoring_Dummy.jmx \
  -q ../tools/report.properties \
  -Jinflux.url="http://localhost:8086/api/v2/write?org=perf&bucket=jmeter" \
  -Jinflux.token=jmeter-local-dev-token \
  -Japp.name=reqres-dummy \
  -Jtest.title="L4 run ${STAMP}" \
  -Jbackend_influxdb.send_interval=5 \
  -Jlogout.file="$OUT/logout_users_{host}.csv" \
  -Jvrt.file="$OUT/request_response_log.xml" \
  -l "$OUT/results.csv" -j "$OUT/jmeter.log" \
  -e -o "$OUT/html_report" \
  "$@"
echo ">> Done. HTML: $OUT/html_report/index.html"
