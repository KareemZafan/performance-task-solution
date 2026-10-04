# Level 3: Distributed Run Observations

**Run:** `results/dist_20261003_233338/` · 1 master (172.28.0.10) + 2 slaves (172.28.0.11, 172.28.0.12) · Docker lab · JMeter 5.6.3 · Java 17 · Xmx 4 GB on every node  
**Deliverables:** `L3_Distributed_Dummy.jmx` · `aggregate_results.csv` · `html_report/index.html` · `summary_metrics.md` · `logout_users_slave1.csv`, `logout_users_slave2.csv`

## Results (merged on the master)

| Transaction | Samples | Err % | Avg | P90 | P95 | Code |
|---|---:|---:|---:|---:|---:|---|
| TX00 Reqres User Journey | 163 | 0 | 1 022 | 1 225 | 1 297 | – |
| TX01 Register | 183 | 0 | 295 | 424 | 444 | 200 |
| TX02 Login | 181 | 0 | 367 | 531 | 573 | 200 |
| TX03 Get Profile | 171 | 0 | 191 | 278 | 292 | 200 |
| TX04a Logout | 77 | 0 | 169 | 242 | 250 | 201 |
| TX04b Delete Profile | 90 | 0 | 168 | 236 | 239 | 204 |

Console: `summary = 702 in 00:01:33 = 7.5/s … Err: 0 (0.00%)`, `Active: 20 Started: 20`.

## What the run proves

1. **Load is per slave:** `-Gusers=10` with 2 slaves → **20 active threads**. Samples split almost evenly: 172.28.0.11 = 350 rows, 172.28.0.12 = 352 rows (the `threadName` column is prefixed with the slave IP).
2. **`-G` properties reached the slaves:** the 5-step / 30 s ramp and 60 s hold were applied remotely.
3. **The full Level 2 logic ran remotely:** CSV data (copied to each slave), extractors, the email assertion, the Random Controller (Logout 77 / Delete 90 ≈ 46/54%), and the JSR223 file writer.
4. **Side-effect files stay on the slaves:** `logout_users_slave1.csv` (41 rows) + `logout_users_slave2.csv` (36 rows) = 77 = the TX04a sample count. With `{host}` in the file name, the two JVMs never write to the same file.
5. **`mode=StrippedBatch`:** the master-side View Results Tree log contains request data but **empty response bodies**. Results are stripped before being sent over RMI to save bandwidth and master heap.
6. **Heap:** `Xmx4g` was confirmed in each slave's java command line.
7. **Kill:** `kill_jmeter.sh local` on each slave sent SIGTERM to the JMeter JVM (container exit code 143 = 128 + 15). The first version killed itself because of `pgrep -f` self-matching; this was fixed with the `[A]pacheJMeter` pattern.

## Issues hit while building it (and fixes)

| Issue | Fix |
|---|---|
| `rmi_keystore.jks` not found | YAML folding split the command, so `-q distributed.properties` (ssl disable) never reached the slave. Use an exec-array command |
| `Duplicate options for -j` | `jmeter-server` already sets `-j`. Use `jmeter -s -j <file>` |
| Kill script killed itself | `pgrep -f '[A]pacheJMeter.jar'` |
