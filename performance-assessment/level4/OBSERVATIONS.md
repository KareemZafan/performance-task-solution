# Level 4: Monitoring Run Observations

**Run:** `results/run_20261004_023807/` · InfluxDB 2.7 + Grafana 11.2 (Docker Compose) · dashboard **19950** provisioned · Backend Listener → `http://localhost:8086/api/v2/write?org=perf&bucket=jmeter` every 5 s  
**Evidence:** `evidence/01_summary_live.jpg`, `02_metrics_response_times.jpg`, `03_active_threads_total_vs_failed.jpg`

## What was observed live in Grafana
* **Active Threads Over Time:** the Concurrency Thread Group's stepped ramp 2 → 4 → 6 → 8 → 10 over 30 s, then flat at 10.
* **Summary:** Min/Max/Active users 10, Total Requests rising (367 at the screenshot), **Failed Requests 0**.
* **Metrics table and Transactions Response Times:** Journey ≈ 1.04 s, Register ≈ 306 ms, Login ≈ 356 ms, Get Profile ≈ 204 ms, Logout/Delete ≈ 170 ms, all updating every 10 s.
* **Total vs Failed Requests Over Time:** ~25–30 requests per 5 s interval and a flat zero failure line.

## End-of-run numbers (from `results.csv`, all samples)

| Transaction | Samples | Err % | Avg | P90 | P95 |
|---|---:|---:|---:|---:|---:|
| TX00 Reqres User Journey | 184 | 0 | 1 037 | 1 259 | 1 314 |
| TX01 Register | 194 | 0 | 309 | 432 | 444 |
| TX02 Login | 188 | 0 | 369 | 530 | 552 |
| TX03 Get Profile | 187 | 0 | 193 | 281 | 287 |
| TX04a Logout | 97 | 0 | 166 | 238 | 247 |
| TX04b Delete Profile | 88 | 0 | 170 | 239 | 243 |

The Grafana values match the CSV within a few ms. The small differences exist because Grafana shows **per-5-s-window aggregates**, while the CSV/HTML uses every sample.

## Issues hit and fixes
| Issue | Fix |
|---|---|
| Dashboard 19950 uses Flux (InfluxDB 2.x) | Used `influxdb:2.7`, a Flux data source, and token auth (not 1.8/InfluxQL) |
| Imported JSON contains `${DS_INFLUXDB}` / `${VAR_SEND_INTERVAL}` placeholders | Replaced them with the provisioned datasource uid and `5` |
| All panels empty at first | The `bucket` variable defaulted to a system bucket. Default changed to `jmeter` |
