### Load metrics (ms) compared with baseline

| Transaction | Samples | TPS | Err % | Avg | Δ Avg | P90 | Δ P90 | P95 | Δ P95 | Codes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| TX00 Reqres User Journey | 316 | 3.42 | 100.0 | 254 | n/a | 460 | n/a | 604 | n/a | :316 |
| TX01 Register | 316 | 3.42 | 93.67 | 234 | n/a | 418 | n/a | 577 | n/a | 200:20, 429:296 |
| TX02 Login | 20 | 0.22 | 0.0 | 140 | n/a | 155 | n/a | 158 | n/a | 200:20 |
| TX03 Get Profile | 20 | 0.22 | 100.0 | 149 | n/a | 175 | n/a | 182 | n/a | 401:20 |

### SLA verdict (load run)

| Transaction | Thresholds | Verdict | Breached |
|---|---|---|---|
| TX00 Reqres User Journey | avg≤3000, p90≤4500, p95≤5000, err≤1.0% | **FAIL** | err<=1.0% |
| TX01 Register | avg≤1000, p90≤1500, p95≤2000, err≤1.0% | **FAIL** | err<=1.0% |
| TX02 Login | avg≤1000, p90≤1500, p95≤2000, err≤1.0% | **PASS** | - |
| TX03 Get Profile | avg≤1000, p90≤1500, p95≤2000, err≤1.0% | **FAIL** | err<=1.0% |

**Overall verdict: FAIL**
