# Level 1: Summary of Observations

**Run:** `results/run_20261004_022806/` · JMeter 5.6.3 non-GUI · macOS, Java 17 · 2026-10-04 02:28 to 02:42 (UTC+3)  
**Deliverables:** `L1_FakeStore_Journey.jmx` · `baseline_results.csv` · `load_results.csv` · `html_report_load/index.html` · `summary_metrics.md`

| Phase | Thread Group | Users | Ramp | Length | CSV |
|---|---|---|---|---|---|
| Baseline | TG01 | 1 | 1 s | 20 iterations | `baseline_results.csv` |
| Load | TG02 | 120 | 60 s | 300 s steady + ramp | `load_results.csv` |

## 1. Headline

**The target was unavailable for the whole test window. Every request to `https://fakestoreapi.com/products` failed with HTTP 522**, so the run measures *Cloudflare's origin-timeout behaviour*, not the Fake Store application. The verdict is **FAIL (environment)**. The test asset itself worked as designed, as explained below.

## 2. Baseline metrics (1 user, ms)

| Transaction | Samples | Err % | Avg | P90 | P95 | Max |
|---|---:|---:|---:|---:|---:|---:|
| TX00 User Journey | 20 | 100 | 19 876 | 20 253 | 20 347 | 22 120 |
| TX01 Get Product List | 20 | 100 | 19 861 | 20 252 | 20 345 | 22 118 |
| TX02 View Product Details | 0 | – | – | – | – | – |
| TX03 Add To Cart | 0 | – | – | – | – | – |

## 3. Load metrics vs baseline (120 users, ms)

| Transaction | Samples | TPS | Err % | Avg | Δ Avg | P90 | Δ P90 | P95 | Δ P95 | Response codes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| TX00 User Journey | 1 522 | 4.76 | 100 | 19 531 | −2% | 20 143 | −1% | 20 375 | 0% | – |
| TX01 Get Product List | 1 522 | 4.76 | 100 | 19 530 | −2% | 20 142 | −1% | 20 375 | 0% | 522 ×1 497 · SocketException ×22 · SocketTimeout ×3 |

## 4. SLA thresholds and verdict

| Transaction | Avg | P90 | P95 | Error % | Verdict |
|---|---|---|---|---|---|
| TX01 Get Product List | ≤ 800 | ≤ 1 200 | ≤ 1 500 | ≤ 1 % | **FAIL** (all four) |
| TX02 View Product Details | ≤ 600 | ≤ 1 000 | ≤ 1 200 | ≤ 1 % | **NOT EXECUTED** |
| TX03 Add To Cart | ≤ 1 000 | ≤ 1 500 | ≤ 2 000 | ≤ 1 % | **NOT EXECUTED** |
| TX00 User Journey | ≤ 2 000 | ≤ 3 000 | ≤ 3 500 | ≤ 1 % | **FAIL** (all four) |

**Overall: FAIL. Root cause: the system under test was unreachable, not a capacity problem.**

## 5. Analysis (how to reason about it)

1. **Validity first.** Error rate is 100%, so the response-time numbers describe a *timeout*, not application speed. Never report "P95 = 20 s" as the app's latency without saying this.
2. **Diagnosis of 522.** `522 Connection Timed Out` is a **Cloudflare** status: the edge (`CF-RAY …-MRS`, Marseille PoP) accepted our TLS connection but could not open a TCP connection to the Fake Store **origin** within ~19 s. This was reproduced outside JMeter with Python (`HTTP Error 522` after 19.7 s). A second symptom: macOS `curl` (LibreSSL) got a TLS *connection reset*. Both point to the hosting/network path, not to JMeter.
3. **Baseline ≈ load (Δ ≈ 0%).** That's expected when every request waits for the same fixed edge timeout. Load didn't make it worse because the bottleneck is a timer, not a queue.
4. **Little's Law sanity check.** N = 120, R ≈ 19.5 s, Z ≈ 2.5 s (one timer per iteration, since the journey aborts after step 1) → X ≈ 120 / 22 ≈ **5.5 req/s**. Measured: **4.76 req/s**, which includes the 60 s ramp. Consistent, so the generator was not the bottleneck.
5. **The script behaved correctly under failure:**
   * the JSON extractor found nothing → the JSR223 post-processor marked the sample failed with *"productId could not be extracted from /products"* (a clear message instead of a cryptic downstream 404),
   * `On sampler error → Start next thread loop` skipped View/Add-to-cart, which avoided 3 000+ meaningless cascade errors,
   * per-thread-group CSVs separated baseline and load cleanly.
6. **What we can't conclude:** anything about the product, details or cart endpoints, the 40% split, or scalability. These need a re-run when the API is healthy.

## 6. Recommendations

* **Add a pre-flight check** (a setUp Thread Group calling `/products` once, set to *Stop Test Now* on error) so a 20-minute run doesn't start against a dead target.
* **Re-run** with `./run_level1.sh` once `curl -s -o /dev/null -w "%{http_code}" https://fakestoreapi.com/products` returns `200`. The analysis script then fills in all four transactions and the 40% ratio (expect TX03 samples ≈ 0.4 × TX02 samples).
* For third-party/public APIs, record **availability** as its own SLA (e.g. ≥ 99.9% non-5xx), separate from latency SLAs.
* Use a lower load on public demo APIs, or a self-hosted copy (fakestoreapi is open source), to avoid hurting a shared service.
