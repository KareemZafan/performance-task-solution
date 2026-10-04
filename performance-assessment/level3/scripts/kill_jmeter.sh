#!/usr/bin/env bash
# Stop / kill JMeter + its Java process on slaves (and optionally locally).
#   ./kill_jmeter.sh local                         -> this machine only
#   SLAVES="192.168.56.11 192.168.56.12" ./kill_jmeter.sh remote
#
# Escalation ladder (always try the gentle way first):
#   1. stoptest.sh / shutdown.sh  -> UDP 4445 to a running NON-GUI master: graceful stop / immediate stop
#   2. kill  (SIGTERM)            -> JVM shutdown hooks run, logs flushed
#   3. kill -9 (SIGKILL)          -> last resort, nothing flushed
set -uo pipefail
MODE=${1:-local}
SSH_USER=${SSH_USER:-perf}
SLAVES=${SLAVES:-"192.168.56.11 192.168.56.12"}

read -r -d '' KILL_SNIPPET <<'EOS'
# '[A]pache...' regex: matches the java cmdline but NOT this script's own text (classic self-match pitfall)
PIDS=$(pgrep -f '[A]pacheJMeter.jar')
if [ -z "$PIDS" ]; then echo "   no JMeter java process"; exit 0; fi
echo "   JMeter PIDs: $PIDS"
ps -o pid,etime,rss,args -p $(echo $PIDS | tr ' ' ',') | cut -c1-150
kill $PIDS 2>/dev/null; sleep 5
LEFT=$(pgrep -f '[A]pacheJMeter.jar')
if [ -n "$LEFT" ]; then echo "   still alive -> kill -9 $LEFT"; kill -9 $LEFT; fi
pkill -f '[j]meter-server' 2>/dev/null
echo "   killed. Port 1099 listeners left: $( (ss -ltn 2>/dev/null || netstat -an) | grep -c ':1099 ' )"
EOS

case "$MODE" in
  local)  echo ">> local"; bash -c "$KILL_SNIPPET" ;;
  remote) for ip in $SLAVES; do echo ">> $ip"; ssh "$SSH_USER@$ip" "bash -s" <<<"$KILL_SNIPPET"; done ;;
  *) echo "usage: $0 local|remote"; exit 1 ;;
esac
