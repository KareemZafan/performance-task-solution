# Performance Technical Assessment v1.3 — Apache JMeter 5.6.3

A complete, runnable solution for all four levels, with real results and a step-by-step learning guide.

## Learn in this order
| # | Guide | What you'll master |
|---|---|---|
| 0 | [docs/00-fundamentals.md](docs/00-fundamentals.md) | Test types, percentiles, Little's Law, JMeter execution order & scoping, variables vs properties |
| 1 | [docs/01-level1-fundamentals.md](docs/01-level1-fundamentals.md) | Thread Groups, Transaction/Throughput Controllers, JSON Extractor, JSR223, assertions, timers, baseline vs load, SLAs |
| 2 | [docs/02-level2-controllers.md](docs/02-level2-controllers.md) | Concurrency Thread Group, CSV data, correlation, Random Controller, writing files safely, View Results Tree logging |
| 3 | [docs/03-level3-distributed.md](docs/03-level3-distributed.md) | Master/slave architecture, RMI ports, `-R`/`-G`/`-X`, heap, shared files, kill scripts, troubleshooting |
| 4 | [docs/04-level4-monitoring.md](docs/04-level4-monitoring.md) | InfluxDB 2 + Grafana via Docker, Backend Listener, dashboard 19950 |
| 5 | [docs/05-demo-runbook.md](docs/05-demo-runbook.md) | Script for the online demo + interview Q&A |

## Deliverables map
| Level | JMX | Results | HTML report | Observations |
|---|---|---|---|---|
| 1 | `level1/L1_FakeStore_Journey.jmx` (Baseline + Load TGs) | `level1/results/run_*/baseline_results.csv`, `load_results.csv` | `level1/results/run_*/html_report_load/` | `level1/OBSERVATIONS.md` |
| 2 | `level2/L2_Reqres_Journey.jmx` | `level2/results/run*/results.csv`, `logout_users.csv`, `request_response_log.xml` | `level2/results/run*/html_report/` | `level2/OBSERVATIONS.md` |
| 3 | `level3/L3_Distributed_Dummy.jmx` + `scripts/` + `docker/` | `level3/results/dist_*/aggregate_results.csv` | `level3/results/dist_*/html_report/` | `level3/OBSERVATIONS.md` |
| 4 | `level4/L4_Monitoring_Dummy.jmx` + `docker-compose.yml` + `grafana/` | `level4/results/run_*/results.csv` | `level4/results/run_*/html_report/` + `evidence/*.jpg` | `level4/OBSERVATIONS.md` |

## Quick start
```bash
./tools/install_jmeter.sh                       # JMeter 5.6.3 + Plugins Manager + jpgc-casutg + jpgc-dummy (~/tools)
export PATH=~/tools/apache-jmeter-5.6.3/bin:$PATH

level1/run_level1.sh                            # baseline + load, HTML for load, SLA verdict
level2/run_level2.sh                            # reqres journey (mind the 40 req/day free-key quota)
(cd level3/docker && docker compose up -d --build slave1 slave2 && docker compose run --rm master)
level4/run_level4.sh                            # InfluxDB + Grafana + monitored run → http://localhost:3000/d/jmeter-19950
```
`tools/analyze_results.py` turns any results CSV into avg/P90/P95 tables, baseline deltas and an SLA verdict (`--sla level1/sla.json`).

## Key findings in one glance
* **L1:** fakestoreapi.com returned **Cloudflare 522 (origin unreachable)** for 100% of requests during the run → verdict FAIL (environment); script logic, separation of baseline/load and failure handling verified.
* **L2:** reqres free key = **40 requests/day + 20/min** → 429s dominate at the specified load; Logout = 201 and Delete = 204 (asserted correctly); `Authorization: Bearer` header triggers 401 on reqres.
* **L3:** 2 slaves × 10 users = 20 active threads, 702 samples, 0 errors, per-slave logout files, 4 GB heap verified, kill script demonstrated.
* **L4:** dashboard 19950 live with all required panels; Grafana and CSV numbers agree.
