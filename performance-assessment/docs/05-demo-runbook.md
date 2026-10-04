# 05 — Online Meeting Demo Runbook (Levels 3 & 4) + Interview Q&A

Rehearse this twice. Target: **15 minutes**, no dead air.

## Before the call (T-30 min)
```bash
export PATH=~/tools/apache-jmeter-5.6.3/bin:$PATH
open -a Docker                                   # wait for "Docker Desktop is running"
cd ~/Desktop/apis/performance-assessment
(cd level3/docker && docker compose build)       # image cached → instant start in the demo
(cd level4 && docker compose up -d)              # InfluxDB + Grafana warm
```
Open tabs: Grafana `http://localhost:3000/d/jmeter-19950`, `docs/03-level3-distributed.md` (diagram), a terminal with large font.

## Part 1 — Distributed (8 min)
| # | Say | Do |
|---|---|---|
| 1 | "Master orchestrates and collects; slaves generate load; RMI on 1099/4000, callbacks on 60000." | Show the mermaid diagram |
| 2 | "Each container is a node with a fixed IP — same as 3 VMs on a host-only network." | `cat level3/docker/docker-compose.yml` |
| 3 | "Ports and SSL are in one shared properties file." | `cat level3/config/distributed.properties` |
| 4 | Heap: "setenv.sh sets Xmx4g on every node." | `cat level3/scripts/setenv.sh` |
| 5 | **Init slaves manually** | `cd level3/docker && docker compose up -d slave1 slave2 && docker compose logs slave1 | tail -2` → point at `Created remote object ... 172.28.0.11:4000` |
| 6 | Verify heap | `docker exec jmeter-slave1 bash -c 'ps -o args -C java | grep -o "Xmx[0-9a-z]*"'` |
| 7 | Files shared | Show `scripts/distribute_files.sh` table in docs §6 |
| 8 | **Start the test** — explain `-R`, `-G`, `-Djava.rmi.server.hostname` | `docker compose run --rm master` → point at `Active: 20` ("10 per slave × 2") |
| 9 | Aggregate results | `open ../results/dist_*/html_report/index.html`, show threadName prefixes by slave IP in the CSV |
| 10 | **Kill on slaves** | `docker exec jmeter-slave1 /work/scripts/kill_jmeter.sh local` then `docker ps -a | grep slave` (Exited 143) |

## Part 2 — Monitoring (7 min)
| # | Say | Do |
|---|---|---|
| 1 | Stack: compose with InfluxDB 2.7 + Grafana, provisioned datasource | `cat level4/docker-compose.yml level4/grafana/provisioning/datasources/influxdb.yml` |
| 2 | Why 2.x: "19950 is Flux" | — |
| 3 | Backend Listener params (url v2, token, measurement, percentiles 50;90;95;99) | Open `L4_Monitoring_Dummy.jmx` in JMeter GUI → Backend Listener |
| 4 | Start the run | `cd level4 && ./run_level4.sh` |
| 5 | Walk the dashboard live: Active Threads steps, Total vs Failed, Response Times, Throughput, "Response time (Avg/90/95)", Error rate | Grafana, refresh 5s |
| 6 | Explain value (live detection, correlation with server metrics, history, alerts, distributed merge) | docs/04 §7 |

## Interview questions you should be able to answer

1. **Average vs percentile?** → fundamentals §2.
2. **Variables vs properties? Why is storing productId as a property risky?** → global race; thread-keyed property or use variables.
3. **Execution order of elements?** Config → Pre → Timer → Sampler → Post → Assertion → Listener.
4. **Why does my Transaction Controller time include think time?** "Include duration of timer…" checked.
5. **Throughput Controller "per user" on vs off?** Per-thread counters vs one shared counter.
6. **Concurrency TG vs standard TG?** Maintains concurrency, stepped ramp, hold; plugin needed on all nodes.
7. **Why 201/204 instead of 200?** REST semantics: Created / No Content.
8. **What does 429 mean and what do you do?** Rate limited → it's a test-environment constraint; get a higher quota / whitelist, or throttle with a Constant Throughput Timer; never report 429 latency as app latency.
9. **How do you know the load generator isn't the bottleneck?** CPU/heap of the injector, Little's Law check, compare with a second injector.
10. **In distributed mode with 3 slaves and 100 threads, how many users?** 300.
11. **-J vs -G?** Local vs pushed to all slaves.
12. **CSV in distributed mode?** Must be copied; each slave reads its own copy from the top → split files for uniqueness.
13. **Why not run load from the GUI?** Overhead, skewed results, OOM.
14. **Backend Listener vs HTML report percentiles?** Window aggregates vs exact over all samples.
15. **What's a 522?** Cloudflare: edge couldn't connect to origin (timeout) — the origin is down/unreachable.
