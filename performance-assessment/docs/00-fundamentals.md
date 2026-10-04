# 00 — Performance Testing Fundamentals (read this first)

This is the mental model you need before any JMeter click makes sense. Every later chapter refers back here.

---

## 1. What performance testing actually answers

Functional testing asks *"does it work?"*. Performance testing asks:

| Question | Test type | Shape of load |
|---|---|---|
| How fast is it with **no contention**? | **Baseline** | 1 user, many iterations |
| Does it meet SLAs at **expected** traffic? | **Load** | Ramp to target users, hold steady |
| Where does it **break**? | **Stress** | Keep increasing until errors/latency explode |
| Can it survive a **sudden burst**? | **Spike** | Jump from low to very high instantly |
| Does it **degrade over time** (leaks)? | **Soak / Endurance** | Normal load for hours |
| How much can it handle (**capacity**)? | **Capacity / Scalability** | Step-wise increase, find the knee |

Level 1 of the assessment is **baseline + load**. The baseline is your *reference*: every load number is meaningless unless you can say "it got X% slower than when nobody else was using it".

---

## 2. The vocabulary (memorize these)

| Term | Meaning | Where you see it in JMeter |
|---|---|---|
| **Virtual user (VU) / thread** | One simulated user; a Java thread looping through your script | Thread Group → *Number of threads* |
| **Ramp-up** | Time to start all threads. 120 threads / 60 s = 1 new user every 0.5 s | Thread Group → *Ramp-up period* |
| **Iteration** | One pass through the Thread Group's children | Loop count |
| **Sample** | One request + its result (time, code, bytes, success) | One row in the CSV/JTL |
| **Transaction** | A business step grouping one or more samples ("User Journey") | Transaction Controller |
| **Response time / elapsed** | First byte sent → last byte received | `elapsed` column |
| **Latency** | First byte sent → **first** byte received (server think + network) | `Latency` column |
| **Connect time** | TCP (+TLS) handshake time | `Connect` column |
| **Think time** | Pause a real user takes between actions | Timers |
| **Throughput (TPS/RPS)** | Completed samples per second | HTML report → Throughput |
| **Error rate** | Failed samples / total samples | `success=false` rows |
| **Percentile (P90, P95, P99)** | P95 = 95% of requests were *at or faster than* this value | Aggregate Report, HTML report |
| **SLA / SLO** | The agreed threshold: e.g. "P95 < 1.5 s and errors < 1%" | You define it; JMeter measures it |
| **APDEX** | Satisfaction score 0–1 from two thresholds (satisfied / tolerated) | HTML report top-left |

### Why percentiles, not averages?
Average hides the pain. 99 requests at 100 ms + 1 request at 10 s = **avg 199 ms** (looks great) but **1 user in 100 waited 10 s**. SLAs are almost always on P90/P95/P99. Always report **avg + P90 + P95** at least (exactly what the assessment asks).

### Little's Law (the one formula you must know)
```
Concurrent users  =  Throughput  ×  (Response time + Think time)
        N         =       X       ×  (       R      +     Z     )
```
Use it to **sanity-check** results and **design** tests:

* Level 1: 120 users, think ≈ 2.5 s × 3 steps (timer fires before every sampler), response ≈ 0.4 s/step  
  one iteration ≈ 3 × (2.5 + 0.4) ≈ 8.7 s → X ≈ 120 / 8.7 ≈ **13.8 journeys/s ≈ 36 requests/s**.  
  If your report shows 5 req/s with 120 users, something is throttling (server or *your load generator*).
* Want 100 TPS with R = 0.5 s and Z = 3 s? You need N = 100 × 3.5 = **350 threads**.

---

## 3. How JMeter works internally (so the rules stop being "magic")

```
Test Plan
 ├── Config elements      (CSV Data Set, HTTP Defaults, Header Manager, UDV)  ← set up data/settings
 ├── Thread Group         (who & how many)
 │    ├── Controllers     (Transaction, Throughput, Random, If, Loop, Module)  ← flow logic
 │    │    └── Samplers   (HTTP Request, Dummy Sampler, JDBC...)               ← the actual work
 │    │         ├── Pre-Processors   (run before THIS sampler)
 │    │         ├── Post-Processors  (extractors - run after)
 │    │         └── Assertions       (pass/fail decision)
 │    ├── Timers          (think time)
 │    └── Listeners       (collect results)
```

### 3.1 Execution order for each sampler (very common interview question)
1. Configuration elements
2. Pre-Processors
3. **Timers** (the pause happens *before* the sampler)
4. **Sampler** executes
5. Post-Processors (extractors) — only if the sample returned
6. Assertions
7. Listeners

Consequence: the JSON Extractor runs **before** assertions, so an extractor can run on an error page — that is why we set a default value like `NOT_FOUND` and check it.

### 3.2 Scoping rules
An element applies to **its siblings and their descendants**:
* A timer at Thread Group level fires before **every** sampler in that Thread Group.
* An assertion placed *under* a sampler applies to that sampler only.
* A **listener inside a Thread Group only sees that Thread Group's samples** — Level 1 uses this to write baseline and load results to separate CSVs from one run.

### 3.3 Variables vs Properties
| | Variables `${name}` | Properties `${__P(name)}` |
|---|---|---|
| Scope | **Per thread** (each VU has its own copy) | **Global** — shared by all threads in the JVM |
| Created by | Extractors, CSV Data Set, UDV, `vars.put()` | `-Jname=value`, `user.properties`, `props.put()`, `__setProperty` |
| Typical use | Session data: tokens, IDs, CSV rows | Configuration: users, duration, host; cross-thread-group sharing |
| In distributed mode | Live on each slave | Each slave has its **own** properties → push with `-G` |

> Level 1 asks to *store the product ID as a property*. A property is **global**, so 120 threads writing the same key overwrite each other (a race condition). The plan does the literal requirement (`productId`) **and** a thread-safe key (`productId_<threadName>`), and explains why. Knowing this trade-off is exactly what an assessor wants to hear.

### 3.4 Functions you will use constantly
| Function | Does |
|---|---|
| `${__P(name,default)}` | Read property with default — makes plans configurable from CLI |
| `${__Random(1,5)}` | Random integer |
| `${__threadNum}` / `${__threadName}` | Current thread number / name |
| `${__machineName}` | Hostname (handy in distributed mode) |
| `${__time(yyyy-MM-dd)}` | Timestamp |
| `${__jexl3(expr)}` / `${__groovy(expr)}` | Evaluate expression (If Controller conditions) |

---

## 4. Golden rules of running tests

1. **Never load test from the GUI.** The GUI is for building/debugging. It consumes huge CPU/RAM (especially View Results Tree) and distorts results. Run with `jmeter -n -t plan.jmx -l results.csv -e -o report/`.
2. **Disable/remove heavy listeners** in load runs (View Results Tree, Aggregate Report GUI). Use Simple Data Writer / `-l`.
3. **Monitor the load generator** (CPU < ~75%, heap, network). If the generator is saturated, *you are measuring JMeter, not the system*.
4. **Use realistic think time.** Without it, 120 threads ≠ 120 users; it's far more aggressive.
5. **Parameterize everything** with `${__P(...)}` so the same JMX runs baseline/load/stress via CLI flags.
6. **Correlate dynamic data** (IDs, tokens) with extractors — never hard-code.
7. **Assert on business correctness**, not only status codes (e.g. the email in Level 2).
8. **Warm-up / ramp-up** matters; exclude ramp-up from steady-state analysis when the SLA is about steady state.
9. **Know the target's limits** (rate limits, WAF, CDN) *before* blaming the application — Level 2 hit exactly this.
10. **Only test systems you are authorised to load.** Public demo APIs (fakestore, reqres) have rate limits for a reason — keep loads modest.

---

## 5. The analysis workflow (what to do after every run)

1. **Validity first**: error %, error codes. If errors > SLA, latency numbers may be invalid (fast failures look "fast"!).
2. **Throughput vs users**: does TPS grow with users? Plateau = saturation point.
3. **Response time over time**: flat = stable; climbing = queueing/leak; saw-tooth = GC or autoscaling.
4. **Percentiles vs baseline**: Δ% per transaction. Which step degrades most? That is your bottleneck candidate.
5. **Correlate** with server metrics (CPU, DB, GC) — Level 4's Grafana is the live version of this.
6. **Verdict**: per-transaction PASS/FAIL against stated SLAs + overall verdict + recommendations.

The repo's `tools/analyze_results.py` automates steps 1, 4 and 6 from the CSV.
