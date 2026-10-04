#!/usr/bin/env bash
# Copy everything a slave needs that the master does NOT send automatically.
# The master only ships the .jmx. Data files, plugins, properties and heap settings must already exist on each slave,
# at the SAME relative path the plan uses.
# Usage: SLAVES="192.168.56.11 192.168.56.12" SSH_USER=perf ./distribute_files.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SLAVES=${SLAVES:-"192.168.56.11 192.168.56.12"}
SSH_USER=${SSH_USER:-perf}
REMOTE_DIR=${REMOTE_DIR:-/home/$SSH_USER/level3}
REMOTE_JMETER=${REMOTE_JMETER:-/opt/jmeter}
LOCAL_JMETER=${JMETER_HOME:-/opt/jmeter}

for ip in $SLAVES; do
  echo ">> $ip"
  ssh "$SSH_USER@$ip" "mkdir -p $REMOTE_DIR/{data,config,scripts,results}"
  scp "$HERE"/data/users.csv                 "$SSH_USER@$ip:$REMOTE_DIR/data/"        # CSV test data
  scp "$HERE"/config/distributed.properties  "$SSH_USER@$ip:$REMOTE_DIR/config/"      # RMI ports, ssl off
  scp "$HERE"/scripts/*.sh                   "$SSH_USER@$ip:$REMOTE_DIR/scripts/"     # start/kill scripts
  scp "$HERE"/scripts/setenv.sh              "$SSH_USER@$ip:$REMOTE_JMETER/bin/"      # 4 GB heap
  # Plugin jars (Concurrency Thread Group, Dummy Sampler) - identical versions on all nodes
  scp "$LOCAL_JMETER"/lib/ext/jmeter-plugins-*.jar "$SSH_USER@$ip:$REMOTE_JMETER/lib/ext/"
  scp "$LOCAL_JMETER"/lib/jmeter-plugins-cmn-jmeter-*.jar "$SSH_USER@$ip:$REMOTE_JMETER/lib/" 2>/dev/null || true
done
echo ">> Files distributed."
