#!/bin/bash
# Pretty-print the user's FairShare across all their accounts, sorted best-first.
# Use this before every `sbatch` to gauge which account has the best submit priority.
#
# On Fir the FAIRSHARE priority component is driven by the multi-level FairShare score
# (FairTree), NOT by LevelFS — so this ranks and judges by FairShare, staying consistent
# with pick-gpu-account.sh and clusters/fir.md. LevelFS is shown for reference only.
# Works on any Alliance Canada cluster.
#
# Column indices are detected from the header — sshare's --parsable2 column order has
# shifted between SLURM versions, so positional parsing is fragile.

set -euo pipefail

SSHARE_OUT=$(sshare -U -l --parsable2 2>/dev/null)
HEADER=$(echo "$SSHARE_OUT" | head -1)

ACC_COL=$(echo "$HEADER" | awk -F'|' '{ for(i=1;i<=NF;i++) if($i ~ /^Account$/)   print i }')
FS_COL=$(echo  "$HEADER" | awk -F'|' '{ for(i=1;i<=NF;i++) if($i ~ /^FairShare$/) print i }')
LFS_COL=$(echo "$HEADER" | awk -F'|' '{ for(i=1;i<=NF;i++) if($i ~ /^LevelFS$/)   print i }')

if [ -z "${ACC_COL:-}" ] || [ -z "${FS_COL:-}" ] || [ -z "${LFS_COL:-}" ]; then
    echo "ERROR: could not locate Account/FairShare/LevelFS columns in 'sshare -U -l' output" >&2
    exit 1
fi

printf "%-22s %-10s %-10s %s\n" "Account" "FairShare" "LevelFS" "Verdict"
printf "%-22s %-10s %-10s %s\n" "-------" "---------" "-------" "-------"

# Sorted best-first by FairShare; the top row is the best submit priority (what
# pick-gpu-account.sh would choose, subject to its RRG/RPP preference).
echo "$SSHARE_OUT" \
  | tail -n +2 \
  | awk -F'|' -v a="$ACC_COL" -v f="$FS_COL" -v l="$LFS_COL" '$a != "" {
      verdict = ($f+0 >= 0.5) ? "at/above fair share" : "below fair share — lower priority"
      printf "%-22s %-10.3f %-10.3f %s\n", $a, $f, $l, verdict
    }' \
  | sort -k2 -rn
