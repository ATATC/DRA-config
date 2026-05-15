#!/bin/bash
# Pretty-print the user's LevelFS across all their accounts, sorted best-first.
# Use this before every `sbatch` to pick the highest-priority account.
# Works on any Alliance Canada cluster.

set -euo pipefail

printf "%-22s %-10s %-12s %s\n" "Account" "LevelFS" "EffUsage" "Verdict"
printf "%-22s %-10s %-12s %s\n" "-------" "-------" "--------" "-------"

sshare -U -l --noheader --parsable2 \
  | awk -F'|' '{
      verdict = ($9+0 > 1) ? "OK — submit here" : "Low — expect queue"
      printf "%-22s %-10.3f %-12.3f %s\n", $1, $9, $6, verdict
    }' \
  | sort -k2 -rn
