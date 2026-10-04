#!/usr/bin/env bash
# Copy this file to $JMETER_HOME/bin/setenv.sh on EVERY node (master + slaves).
# bin/jmeter sources bin/setenv.sh automatically before starting the JVM.
#
# HEAP  : initial (-Xms) and max (-Xmx) Java heap. Task requirement: max heap 4 GB.
#         Rule of thumb: Xmx <= ~75% of the machine RAM, leave room for the OS + network buffers.
# On a dedicated load box, set Xms = Xmx (e.g. -Xms4g -Xmx4g) to avoid heap-resizing pauses.
export HEAP=${HEAP:-"-Xms1g -Xmx4g -XX:MaxMetaspaceSize=256m"}   # env HEAP wins if already set

# Optional GC tuning (G1 is already the default on Java 17); print GC info to a log for analysis
export JVM_ARGS="${JVM_ARGS:-} -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -Xlog:gc*:file=jmeter-gc.log:time,uptime:filecount=3,filesize=10m"
