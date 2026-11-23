#!/bin/sh
# Appends uptime (load averages) every 30 s to load.log until results.log has
# the hyperfine summary.
cd "$(dirname "$0")"
until grep -q "Benchmark 2" results.log; do
  uptime >> load.log
  sleep 30
done
uptime >> load.log
