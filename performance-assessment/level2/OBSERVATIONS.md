# Level 2: Summary of Observations (reqres.in)

Two runs. Both are kept because together they tell the full story.

| Run | Folder | Settings | Purpose |
|---|---|---|---|
| **Run 1: as specified** | `results/run1_rate_limited_20261004/` | 10 users, 30 s ramp / 5 steps, hold 60 s, think 1–3 s | The literal requirement |
| **Run 2: quota-aware** | `results/run2_quota_aware_20261004/` | same ramp, hold 160 s, think constant 40 s | Validate functional flow within the API's limits |

Each folder contains `results.csv`, `html_report/index.html`, `logout_users.csv`, `request_response_log.xml` (request + response bodies) and `summary_metrics.md`.

## Run 1: as specified → throttled

| Transaction | Samples | Err % | Avg | P90 | P95 | Codes |
|---|---:|---:|---:|---:|---:|---|
| TX01 Register | 316 | 93.7 | 234 | 418 | 577 | 200 ×20, **429 ×296** |
| TX02 Login | 20 | 0 | 140 | 155 | 158 | 200 ×20 |
| TX03 Get Profile | 20 | 100 | 149 | 175 | 182 | **401 ×20** |
| TX00 Journey | 316 | 100 | 254 | 460 | 604 | – |

* **429 Too Many Requests.** The free key `reqres-free-v1` allows **20 req/min** (`ratelimit-policy: 20;w=60`) and **40 req/day** (`x-ratelimit-limit: 40`, reset 00:00 UTC). The specified load produces ≈ 300 req/min. After the first ~20 requests, every Register was throttled, and *On error → start next loop* correctly skipped the rest of the journey.
* **401 on Get Profile.** I had added `Authorization: Bearer <token>`. reqres treats that header as its own session auth and rejects the demo token. I removed the header, since the API key is the only auth required.
* The latency numbers are mostly *429 rejection times*, so they are **not** application latency.

## Run 2: quota-aware → functional flow verified

| Transaction | Samples | Err % | Avg | P90 | P95 | Codes |
|---|---:|---:|---:|---:|---:|---|
| TX01 Register | 20 | 50 | 359 | 402 | 530 | 200 ×10, 429 ×10 |
| TX02 Login | 10 | 0 | 147 | 172 | 172 | 200 ×10 |
| TX03 Get Profile (+ email == CSV) | 10 | 0 | 412 | 434 | 442 | 200 ×10 |
| TX04a Logout | 4 | 0 | 180 | 220 | 220 | 201 ×4 |
| TX04b Delete Profile | 6 | 0 | 200 | 364 | 364 | 204 ×6 |
| TX00 Journey (completed) | 10 OK | – | 736 avg | 1 259 | 1 353 | – |

* **All 10 users completed the full journey**: CSV row → Register → Login (same row) → Get Profile → **email assertion passed 10/10** → random branch.
* **Random Controller:** Logout 4 / Delete 6 (a fair coin over 10 tosses).
* **External CSV:** `logout_users.csv` has exactly the 4 users that hit Logout (janet.weaver id 2, eve.holt id 4, charles.morris id 5, tobias.funke id 9). Row count matches the TX04a sample count.
* **Rate limit proven precisely:** requests 1–40 succeeded and requests 41–50 (users starting a 2nd iteration while the test was shutting down) all got **429**. This matches the 40/day quota exactly.
* Latency on the real API (single-digit concurrency): Login ≈ 150 ms, Register ≈ 360 ms, Get Profile ≈ 410 ms, Logout/Delete ≈ 180–200 ms. Every successful step is well within the 1 s / 1.5 s / 2 s SLA.

## SLA verdict

| Transaction | SLA (avg / P90 / P95 / err) | Run 1 | Run 2 |
|---|---|---|---|
| Register | 1000 / 1500 / 2000 ms / 1% | FAIL (429) | FAIL (429 after quota) |
| Login | same | PASS | PASS |
| Get Profile | same | FAIL (401, fixed) | PASS |
| Logout | same | not reached | PASS |
| Delete | same | not reached | PASS |
| **Overall** | | **FAIL** | **FAIL (rate limit only)** |

**Conclusion:** the script is functionally correct and the API is fast at low concurrency. The free API key's **rate limit (20/min, 40/day) makes the requested 10-user load impossible**. For a real load test you would request a higher quota or a whitelisted key, or test a self-hosted environment.

## Lessons
1. Probe the API manually and **read the headers** before load testing (rate limits, real status codes).
2. Assert the **correct** success code per call: 201 for create-style POST, 204 for DELETE.
3. Don't send headers the API didn't ask for (the Bearer header caused 401).
4. A Concurrency Thread Group **respawns threads**, so the iteration limit doesn't cap total requests. Use time bounds.
