#!/usr/bin/env bash
# Start a JMeter slave (jmeter-server) manually on THIS machine.
# Usage: ./start_slave.sh [SLAVE_IP]       (default: first non-loopback IP)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
JMETER_HOME=${JMETER_HOME:-/opt/jmeter}

# 1. Which IP will the master use to reach me? RMI embeds this IP in the stub it hands out,
#    so it MUST be reachable from the master (not 127.0.0.1).
SLAVE_IP=${1:-$( (hostname -I 2>/dev/null || ipconfig getifaddr en0) | awk '{print $1}')}

# 2. Heap - 4 GB as required (overrides bin/setenv.sh if both are present)
export HEAP=${HEAP:-"-Xms1g -Xmx4g -XX:MaxMetaspaceSize=256m"}

# 3. Refuse to start twice
if pgrep -f "ApacheJMeter.jar.*-s" >/dev/null; then
  echo "jmeter-server already running (pid $(pgrep -f 'ApacheJMeter.jar.*-s'))"; exit 0
fi

echo ">> Starting jmeter-server on ${SLAVE_IP} (registry 1099, RMI 4000, HEAP='${HEAP}')"
cd "$HERE"   # relative CSV paths in the plan (data/users.csv) resolve from here
# "jmeter -s" == what bin/jmeter-server runs, but lets us choose our own log file with -j
nohup "$JMETER_HOME/bin/jmeter" -s -Dserver_port=1099 \
  -Djava.rmi.server.hostname="${SLAVE_IP}" \
  -q "$HERE/config/distributed.properties" \
  -j "$HERE/results/jmeter-server-${SLAVE_IP}.log" \
  > "$HERE/results/jmeter-server-${SLAVE_IP}.out" 2>&1 &
echo $! > "$HERE/results/jmeter-server.pid"

# 4. Wait until the RMI registry port is open
for i in $(seq 1 30); do
  if (exec 3<>/dev/tcp/127.0.0.1/1099) 2>/dev/null; then echo ">> Slave ready (pid $(cat "$HERE/results/jmeter-server.pid"))"; exit 0; fi
  sleep 1
done
echo "!! Slave did not open port 1099 - check results/jmeter-server-${SLAVE_IP}.log"; exit 1
