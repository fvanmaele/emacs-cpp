#!/bin/sh
# Types x every 30 ms for 1.5 s after 1 s, then waits for Emacs to exit.
sleep 1
i=0
while [ $i -lt 50 ]; do printf x; sleep 0.03; i=$((i+1)); done
sleep 4
