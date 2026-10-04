# Level 1 — Fundamentals & Requirement Understanding (Fake Store API)

**Files:** `level1/L1_FakeStore_Journey.jmx` · `level1/run_level1.sh` · `level1/sla.json` · `level1/OBSERVATIONS.md`

---

## Step 0 — Understand the requirement before touching JMeter

Write the requirement down as a test design. This is what assessors look for first.

| Requirement | Design decision | JMeter element |
|---|---|---|
| Ramp to 120 users within 1 min | 120 threads, ramp-up 60 s, then **hold** (steady state) for 5 min | Thread Group (scheduler: duration 300 s) |
| Measure "User Journey" time | Wrap all steps in one transaction, **exclude timers** | Transaction Controller |
| Capture product ID dynamically **and randomly** | JSONPath `$[*].id`, Match No. **0** (= random) | JSON Extractor |
| Store ID as **JMeter property** | `props.put(...)` in Groovy | JSR223 PostProcessor |
| Use the ID in View + Add to cart | `${__P(productId_${__threadName})}` | HTTP Request path/body |
| Add-to-cart for 40% only | Percent-executions throughput controller = 40 | Throughput Controller |
| Assert 200 OK | Response code **equals** 200 | Response Assertion |
| Think time 2–3 s | 2000 ms constant + 0–1000 ms random | Uniform Random Timer |
| Baseline + Load in one JMX | Two Thread Groups, **run consecutively** | Test Plan → "Run Thread Groups consecutively" |
| Separate CSVs | One listener inside each Thread Group | Simple Data Writer × 2 |

---

## Step 1 — Test Plan level setup

Open JMeter (`jmeter` → GUI) → **File ▸ New**.

1. **Test Plan** → name `L1 - Fake Store E-commerce Journey`.  
   ✅ Tick **"Run Thread Groups consecutively (i.e. one at a time)"**.  
   *Why:* baseline must run alone; if both ran together the baseline would measure a loaded system and be useless as a reference.
2. **Add ▸ Config Element ▸ HTTP Request Defaults**  
   Protocol `${__P(protocol,https)}`, Server `${__P(host,fakestoreapi.com)}`, Timeouts: connect 5000, response 30000.  
   *Why:* every sampler inherits host/protocol, so switching environments = one CLI flag (`-Jhost=staging.example.com`). Timeouts prevent a hung connection from blocking a thread forever.
3. **Add ▸ Config Element ▸ HTTP Header Manager**: `Content-Type: application/json`, `Accept: application/json`.

## Step 2 — Build the journey once, reuse it twice (Test Fragment + Module Controller)

Both thread groups execute *the same* journey. Copy-pasting it would mean every fix must be made twice.

1. **Add ▸ Test Fragment ▸ Test Fragment** → `FRAG - User Journey`. (A fragment never runs by itself.)
2. Inside it: **Add ▸ Logic Controller ▸ Transaction Controller** → `TX00 User Journey`.
   * ☐ *Generate parent sample* — **unchecked**: you get the journey row **and** each step's row in results.
   * ☐ *Include duration of timer and pre-post processors* — **unchecked**: journey time = pure server time, think time excluded (otherwise the SLA would mostly measure your own sleeps).

### 2.1 `TX01 Get Product List` — GET `/products`
Children:
* **Response Assertion** → *Field to test*: Response Code · *Pattern matching*: **Equals** · pattern `200`.
* **JSON Extractor**
  * Names of created variables: `productId`
  * JSON Path: `$[*].id` → "the `id` of every element of the root array" (20 ids)
  * Match No.: **0** → *random* match. (1 = first, -1 = all → `productId_1..N`)
  * Default: `NOT_FOUND`
* **JSR223 PostProcessor (Groovy)** — stores the ID as a **property**:
  ```groovy
  String id = vars.get("productId")
  if (id == null || id == "NOT_FOUND") {        // extractor failed -> fail the sample visibly
      prev.setSuccessful(false)
      prev.setResponseMessage("productId could not be extracted from /products")
      return
  }
  props.put("productId", id)                                    // literal requirement (global)
  props.put("productId_" + ctx.getThread().getThreadName(), id) // thread-safe copy
  ```
  **Deep-dive — why two keys?** Properties are one global map per JVM. With 120 threads, thread A writes 7, thread B writes 13 a millisecond later, thread A then reads 13. For this API that's harmless (any valid id works), but in a real shop it would mean "user A views product 7 but adds product 13 to cart": wrong data and wrong cache behaviour. Keying by thread name gives each VU its own slot while still satisfying "store as property". (In real projects you'd simply use the variable `${productId}`; properties are for config and cross-thread-group sharing.)
  
  *Groovy objects available in JSR223:* `vars` (thread variables), `props` (properties), `prev` (the previous SampleResult), `ctx` (JMeterContext), `log`, `sampler`.  
  Always pick **Groovy** + "Cache compiled script" — it's compiled once; BeanShell/JS are interpreted on each run and become a bottleneck at load.

### 2.2 `TX02 View Product Details` — GET `/products/${__P(productId_${__threadName},1)}`
* Nested function: inner `${__threadName}` resolves first → `__P` reads that property, default `1`.
* **Response Assertion** = 200.
* **JSON Assertion** `$.id` == the same property → proves we got the product we asked for (a 200 with the wrong body is still a bug).

### 2.3 Throughput Controller — 40% add to cart
* **Add ▸ Logic Controller ▸ Throughput Controller**: *Percent Executions*, value `40`, ☐ *Per User*.
* With *Per User* **off**, the 40% is computed over **all** executions of all threads (a shared counter), so the overall ratio is 40% exactly. With it **on**, each thread keeps its own counter (40% per user).
* Alternatives and when to use them:
  | Option | Behaviour |
  |---|---|
  | Throughput Controller (percent) | Deterministic 40% of executions — **chosen** |
  | If Controller `${__jexl3(${__Random(1,100)} <= 40)}` | Probabilistic ~40%, varies run to run |
  | Separate Thread Group with 48 of 120 users | "40% of **users**" exactly, but users never switch behaviour |
  
### 2.4 `TX03 Add To Cart` — POST `/carts`, Body Data:
```json
{"userId":1,"products":[{"productId":${__P(productId_${__threadName},1)},"quantity":${__Random(1,5,qty)}}]}
```
* Assertion pattern `20[01]` with **Matches** (regex): the task says "200 OK", but REST APIs *should* answer resource creation with **201 Created**. Accepting both avoids a false failure. Say this out loud in the interview; it shows you understand HTTP semantics rather than copying requirements blindly.

### 2.5 Think time
**Add ▸ Timer ▸ Uniform Random Timer** at fragment level: Constant delay `2000`, Random max `1000` ⇒ uniformly 2000–3000 ms **before every sampler**.  
*(Gaussian Random Timer gives a bell curve; Constant Throughput Timer targets a rate instead of a pause.)*

## Step 3 — The two Thread Groups

| | TG01 Baseline | TG02 Load |
|---|---|---|
| Threads | `${__P(baseline.users,1)}` | `${__P(load.users,120)}` |
| Ramp-up | 1 s | `${__P(load.rampup,60)}` ⇒ +2 users/s |
| Loop / duration | `${__P(baseline.iterations,20)}` loops | Infinite loop, **Specify thread lifetime** duration `${__P(load.duration,300)}` |
| On sampler error | Start next thread loop | Start next thread loop |
| Child | Module Controller → `FRAG - User Journey` | Module Controller → `FRAG - User Journey` |
| Listener | Simple Data Writer → `baseline_results.csv` | Simple Data Writer → `load_results.csv` |

* **"Start next thread loop" on error**: if `/products` fails, there is no ID, so continuing would cascade into meaningless errors. Skip the rest of the iteration.
* **Thread lifetime vs loops**: a load test is defined by *time at load*, not by the number of iterations.
* **Simple Data Writer inside the TG** = the listener-scope rule (fundamentals §3.2) → separate, clearly labelled CSVs from a single run. The `threadName` column additionally tags each row (`TG01 - Baseline…` vs `TG02 - Load…`).

## Step 4 — Run it properly (CLI, not GUI)

```bash
cd level1
./run_level1.sh                       # baseline (20 iterations) then load (120 VU, 60 s ramp, 300 s)
./run_level1.sh -Jload.duration=600   # any knob can be overridden
```
What the script runs:
```bash
jmeter -n -t L1_FakeStore_Journey.jmx -q ../tools/report.properties -Jresults.dir=$OUT -j $OUT/jmeter.log
jmeter -g $OUT/load_results.csv -o $OUT/html_report_load        # HTML report from the LOAD csv only
python3 ../tools/analyze_results.py --baseline ... --load ... --sla sla.json
```
| Flag | Meaning |
|---|---|
| `-n` | non-GUI |
| `-t` | test plan |
| `-q` | extra properties file (CSV fields, APDEX thresholds, percentiles) |
| `-J` | set a property on this JVM |
| `-l` | results file (not used here: TG-scoped writers instead) |
| `-j` | JMeter log file |
| `-g` + `-o` | generate the HTML dashboard from an existing CSV into an empty folder |
| `-e -o` | run **and** generate the dashboard at the end |

## Step 5 — Define SLAs **before** looking at results (`level1/sla.json`)

| Transaction | Avg | P90 | P95 | Errors |
|---|---|---|---|---|
| TX01 Get Product List | ≤ 800 ms | ≤ 1200 | ≤ 1500 | ≤ 1% |
| TX02 View Product Details | ≤ 600 | ≤ 1000 | ≤ 1200 | ≤ 1% |
| TX03 Add To Cart | ≤ 1000 | ≤ 1500 | ≤ 2000 | ≤ 1% |
| TX00 User Journey (3 calls, no think time) | ≤ 2000 | ≤ 3000 | ≤ 3500 | ≤ 1% |

Defining them first prevents the classic bias of "adjusting the SLA to the result".

## Step 6 — Read the HTML report (what to look at, in order)

1. **Dashboard → Statistics table**: per label Samples, Error %, Average, 90th/95th/99th pct, Throughput.
2. **Errors** & **Top 5 errors by sampler**: what failed and why (code + message).
3. **Charts ▸ Over Time ▸ Response Times Over Time**: stable or climbing?
4. **Active Threads Over Time**: confirms the 60 s ramp to 120.
5. **Charts ▸ Throughput ▸ Transactions per second**: should plateau once all 120 users are active (Little's Law ≈ 36 req/s).
6. **Response Time Percentiles / Distribution**: long tail?
7. **Response Times vs Threads**: the scalability curve. Flat = scales; rising = contention.

The real results and verdict for this run are in `level1/OBSERVATIONS.md`.
