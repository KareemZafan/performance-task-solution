# Level 2 — Controllers & Advanced Thread Groups (reqres.in)

**Files:** `level2/L2_Reqres_Journey.jmx` · `level2/data/users.csv` · `level2/run_level2.sh` · `level2/OBSERVATIONS.md`

---

## Step 0 — Probe the API by hand first (this saved the test)

Before scripting, send each call once with curl or Postman and write down the **real** status codes and bodies:

| Step | Call | Real status | Body we need |
|---|---|---|---|
| Register | `POST /api/register` | **200** | `{"id":4,"token":"QpwL5tke4Pnpja7X4"}` |
| Login | `POST /api/login` | **200** | `{"token":"..."}` |
| Get Profile | `GET /api/users/{id}` | **200** | `{"data":{"id":4,"email":"eve.holt@reqres.in",...}}` |
| Logout (as specified) | `POST /api/users/{id}` | **201 Created** | echo of body + `createdAt` |
| Delete | `DELETE /api/users/{id}` | **204 No Content** | *(empty)* |

Findings that changed the design:
1. **"Assert 200 OK" is wrong for 2 of 5 calls.** Logout returns 201 and Delete returns 204. Asserting 200 there would report 100% false failures. Assert the **correct success code per call** and explain why.
2. **Register only accepts reqres' predefined users** (`george.bluth@`, `janet.weaver@`, `eve.holt@`…); unknown emails are rejected with **400** (we saw `{"error":"user not found"}` for an unknown email on login). So the CSV must contain those emails.
3. **Every request needs `x-api-key: reqres-free-v1`**, otherwise 401 `missing_api_key`.
4. **Sending `Authorization: Bearer <token>` makes reqres return 401**, because it switches to a different auth scheme. The demo token is not a real session token, so we don't send it.
5. **Rate limit**: response headers `ratelimit-policy: 20;w=60` and `x-ratelimit-limit: 40` (resets 00:00 UTC). The free shared key allows ~20 req/min and **40 requests per day**. Our design load (10 users × 4 req every ~8 s ≈ 300 req/min) is 15× the per-minute limit, so most requests **will** be throttled (429). See OBSERVATIONS.

> Lesson: **read the response headers**. `RateLimit-*`, `Retry-After`, `X-Cache`, `CF-Ray` tell you about throttling, caching and CDNs between you and the app.

---

## Step 1 — Install the plugin (Custom Thread Groups)

The "Custom Thread Group" requirement → **Concurrency Thread Group** from *Custom Thread Groups* (`jpgc-casutg`).
```bash
./tools/install_jmeter.sh          # installs Plugins Manager + jpgc-casutg + jpgc-dummy
# GUI alternative: Options ▸ Plugins Manager ▸ Available Plugins ▸ "Custom Thread Groups" ▸ Apply
```

## Step 2 — Concurrency Thread Group: 10 users / 30 s / 5 steps

**Add ▸ Threads ▸ bzm – Concurrency Thread Group**

| Field | Value | Meaning |
|---|---|---|
| Target Concurrency | `${__P(users,10)}` | Users to keep alive |
| Ramp Up Time | `${__P(rampup,30)}` | Seconds to reach target |
| Ramp-Up Steps Count | `${__P(steps,5)}` | 5 stairs: 2 → 4 → 6 → 8 → 10, one every 6 s |
| Hold Target Rate Time | `${__P(hold,60)}` | Steady state after ramp |
| Time Unit | **seconds** | ⚠ the default is *minutes*; a classic mistake |
| Thread Iterations Limit | `${__P(iterations,)}` | Empty = unlimited (used for quota-aware runs) |

**Why Concurrency TG instead of the standard one?**
* The standard TG ramps linearly and can't hold an exact concurrency once threads finish. Concurrency TG **maintains** the target: if a thread ends, it starts a new one.
* Stepped ramp-up lets you see the response at each level (2, 4, 6, 8, 10 users) as clean plateaus in "Active Threads Over Time". That's ideal for finding the knee of the curve.
* Related plugins: *Ultimate Thread Group* (arbitrary schedule rows) and *Arrivals / Free-Form Arrivals TG* (open model: targets **arrivals/sec** instead of concurrent users).

## Step 3 — CSV Data Set Config (registration data)

`data/users.csv`:
```
email,password
george.bluth@reqres.in,Perf@12345
janet.weaver@reqres.in,Perf@12345
...
```
**Add ▸ Config Element ▸ CSV Data Set Config**
| Field | Value | Why |
|---|---|---|
| Filename | `${__P(users.csv,data/users.csv)}` | Relative to the JMX folder; overridable |
| Variable Names | `email,password` | |
| Ignore first line | **True** | Header row |
| Recycle on EOF | True | 10 rows, many iterations |
| Stop thread on EOF | False | |
| Sharing mode | **All threads** | Each *iteration* takes the next row, so the same email is used by Register **and** Login in that iteration (requirement: "use same data for logging in") |

**How "same data for login" works:** a CSV row is read **once per iteration** per thread (when the first sampler in scope runs). Both Register and Login reference `${email}`/`${password}` in the same iteration, so they get the same row automatically.

## Step 4 — Samplers, extractors, assertions

### TX01 Register — `POST /api/register` body `{"email":"${email}","password":"${password}"}`
* Response Assertion: code **equals 200**
* JSON Extractor `registeredId` ← `$.id`

### TX02 Login — `POST /api/login`, same body (same CSV row)
* Response Assertion 200 · JSON Extractor `token` ← `$.token`

### TX03 Get Profile — `GET /api/users/${registeredId}`
* Response Assertion 200
* **JSON Extractor with two variables** (semicolon-separated in every field):
  `userId;profileEmail` ← `$.data.id;$.data.email`, match `1;1`, defaults `NOT_FOUND;NOT_FOUND`
* **Response Assertion on a JMeter variable** (email check):
  *Apply to:* **JMeter Variable Name to use** = `profileEmail` · Field: Text Response · **Equals** · pattern `${email}`  
  Comparing the *extracted* value is robust; comparing raw body text breaks on whitespace or key order. Equivalent alternative: JSON Assertion `$.data.email` expected `${email}`.

### Random Controller — Logout **or** Delete
**Add ▸ Logic Controller ▸ Random Controller**: executes **exactly one** child per iteration, chosen at random (≈50/50).
| Alternative | When |
|---|---|
| Random Controller | Equal weights (**chosen**) |
| Throughput Controllers 70/30 | Weighted mix |
| Switch Controller `${__Random(0,1)}` | Deterministic index |
| Weighted Switch Controller (plugin) | Weighted, one element |

* **TX04a Logout** — `POST /api/users/${userId}` → assert **201**
  * JSR223 PostProcessor: append to external CSV
    ```groovy
    if (!prev.isSuccessful()) return                       // only users that really logged out
    String path = props.getProperty("logout.file", "output/logout_users.csv")
            .replace("{host}", java.net.InetAddress.getLocalHost().getHostName())
    File f = new File(path)
    String line = [vars.get("userId"), vars.get("email"), ctx.getThread().getThreadName(),
                   new Date().format("yyyy-MM-dd'T'HH:mm:ss.SSS")].join(",") + "\n"
    synchronized (org.apache.jmeter.util.JMeterUtils.class) {   // ONE writer at a time
        if (!f.exists()) { f.getAbsoluteFile().getParentFile().mkdirs(); f.append("userId,email,threadName,timestamp\n") }
        f.append(line)
    }
    ```
    **Why `synchronized`?** 10 threads may finish Logout in the same millisecond. Without a lock, two `append` calls can interleave bytes ("4,eve…6,tra…\n\n"). Locking on a single JVM-wide object makes writes atomic. *Alternative:* the **Flexible File Writer** plugin, or `sample_variables=userId` + Simple Data Writer.
* **TX04b Delete Profile** — `DELETE /api/users/${userId}` → assert **204**

## Step 5 — Uniform Random Timer
`${__P(think.min,1000)}` + random `${__P(think.range,2000)}` ⇒ 1–3 s before each sampler.

## Step 6 — View Results Tree → external log with request & response bodies
**Add ▸ Listener ▸ View Results Tree** → *Write results to file*: `logs/request_response_log.xml` → **Configure**:
* ✅ Save As XML (**required**: CSV format cannot store bodies)
* ✅ Save Response Data (XML) · ✅ Save Sampler Data (XML) (= request body/URL)
* ✅ Save Request Headers · ✅ Save Response Headers · ✅ Save Assertion Failure Message

The file is written in non-GUI mode too (any listener with a filename writes). Open it later with *View Results Tree ▸ Browse*.  
⚠ This is a **debug** listener. Storing bodies costs CPU, disk and heap. For real load tests use "Log/Display Only: Errors" or `jmeter.save.saveservice.response_data.on_error=true`.

## Step 7 — Run

```bash
cd level2 && ./run_level2.sh
# quota-aware variant: 10 users, same 30 s / 5-step ramp, EXACTLY one journey each = 40 requests
./run_level2.sh -Jhold=160 -Jthink.min=40000 -Jthink.range=0
```

### Designing a run around a rate limit (worked example)
Constraints: ≤ 20 req/min and ≤ 40 req/day, and every one of the 10 users must complete 4 steps.
* A constant think time T fires **before each** sampler, so a user starting at time s sends requests at s+T, s+2T, s+3T, s+4T.
* Rate = 10 users / T. With T = 40 s you get **15 req/min** (< 20 ✔).
* The last pair of users starts at 24 s (5 steps × 6 s: 0, 6, 12, 18, 24), so their 4th request lands at ≈ 24 + 160 = **184 s**.
* The first users would send a 5th request at 0 + 200 = 200 s, so end the test between 184 s and 200 s: ramp 30 + hold 160 = **190 s**.
* Total = 10 × 4 = **40 requests** (= daily quota ✔).

> ⚠ **Thread Iterations Limit does not cap total load in a Concurrency TG.** When a thread finishes its iterations, the CTG **starts a new thread** to keep the target concurrency. In our test, 3 slots with `iterations=1` started 23 threads in 26 s. To cap total requests, bound the **time** (as above), or use a standard Thread Group with a loop count.
Outputs in `results/run_<timestamp>/`: `results.csv`, `html_report/`, `logout_users.csv`, `request_response_log.xml`, `summary_metrics.md`.
