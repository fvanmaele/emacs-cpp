#!/bin/sh
# Prints a line every 5 ms for 4 s.
i=0
while [ $i -lt 800 ]; do echo t; sleep 0.005; i=$((i+1)); done
