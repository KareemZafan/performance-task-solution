### Metrics (ms)

| Transaction | Samples | TPS | Err % | Avg | Δ Avg | P90 | Δ P90 | P95 | Δ P95 | Codes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| TX00 Reqres User Journey | 20 | 0.09 | 50.0 | 736 | n/a | 1259 | n/a | 1353 | n/a | :10, 200:10 |
| TX01 Register | 20 | 0.09 | 50.0 | 359 | n/a | 402 | n/a | 530 | n/a | 200:10, 429:10 |
| TX02 Login | 10 | 0.04 | 0.0 | 147 | n/a | 172 | n/a | 172 | n/a | 200:10 |
| TX03 Get Profile | 10 | 0.04 | 0.0 | 412 | n/a | 434 | n/a | 442 | n/a | 200:10 |
| TX04a Logout | 4 | 0.02 | 0.0 | 180 | n/a | 220 | n/a | 220 | n/a | 201:4 |
| TX04b Delete Profile | 6 | 0.03 | 0.0 | 200 | n/a | 364 | n/a | 364 | n/a | 204:6 |

### SLA verdict (load run)

| Transaction | Thresholds | Verdict | Breached |
|---|---|---|---|
| TX00 Reqres User Journey | avg≤3000, p90≤4500, p95≤5000, err≤1.0% | **FAIL** | err<=1.0% |
| TX01 Register | avg≤1000, p90≤1500, p95≤2000, err≤1.0% | **FAIL** | err<=1.0% |
| TX02 Login | avg≤1000, p90≤1500, p95≤2000, err≤1.0% | **PASS** | - |
| TX03 Get Profile | avg≤1000, p90≤1500, p95≤2000, err≤1.0% | **PASS** | - |
| TX04a Logout | avg≤1000, p90≤1500, p95≤2000, err≤1.0% | **PASS** | - |
| TX04b Delete Profile | avg≤1000, p90≤1500, p95≤2000, err≤1.0% | **PASS** | - |

**Overall verdict: FAIL**
