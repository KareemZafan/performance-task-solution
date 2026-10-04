### Baseline metrics (ms)

| Transaction | Samples | Err % | Avg | P90 | P95 | Max |
|---|---:|---:|---:|---:|---:|---:|
| TX00 User Journey | 20 | 100.0 | 19876 | 20253 | 20347 | 22120 |
| TX01 Get Product List | 20 | 100.0 | 19861 | 20252 | 20345 | 22118 |

### Load metrics (ms) compared with baseline

| Transaction | Samples | TPS | Err % | Avg | Δ Avg | P90 | Δ P90 | P95 | Δ P95 | Codes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| TX00 User Journey | 1522 | 4.76 | 100.0 | 19531 | -2% | 20143 | -1% | 20375 | +0% | :1522 |
| TX01 Get Product List | 1522 | 4.76 | 100.0 | 19530 | -2% | 20142 | -1% | 20375 | +0% | 522:1497, Non HTTP response code: java.net.SocketException:22, Non HTTP response code: java.net.SocketTimeoutException:3 |

### SLA verdict (load run)

| Transaction | Thresholds | Verdict | Breached |
|---|---|---|---|
| TX00 User Journey | avg≤2000, p90≤3000, p95≤3500, err≤1.0% | **FAIL** | avg<=2000ms, p90<=3000ms, p95<=3500ms, err<=1.0% |
| TX01 Get Product List | avg≤800, p90≤1200, p95≤1500, err≤1.0% | **FAIL** | avg<=800ms, p90<=1200ms, p95<=1500ms, err<=1.0% |

**Overall verdict: FAIL**
