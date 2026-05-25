#!/bin/bash
# Print the GPU account that will give the best SLURM priority.
#
# Ranks by FairShare (the priority-relevant 0–1 value SLURM uses for the
# FAIRSHARE component), not by LevelFS. Works on any Alliance Canada
# cluster — uses generic SLURM commands only.
#
# Why FairShare and not LevelFS:
#   LevelFS is `NormShares / EffectvUsage` *within a single parent group* —
#   it measures how under-used your account is among its siblings. When all
#   your GPU accounts share one parent (e.g. only def-* accounts), ranking
#   by LevelFS gives the right answer.
#
#   But when you also have an RRG (RAC competition award) account, the RRG
#   account's parent has a much larger share allocation at the root level.
#   That propagates into a higher *FairShare* score even when the RRG
#   account has been used more recently and shows lower LevelFS in its
#   own subtree.
#
#   Example (Fir, 2026-05-06, real numbers, account names anonymised):
#       def-<pi>-<sub>_gpu   LevelFS=2.998   FairShare=0.337
#       rrg-<pi>_gpu         LevelFS=0.431   FairShare=0.498
#   LevelFS picks the def-* account — wrong; submitting under the rrg-*
#   account gave a 1.48× higher FAIRSHARE priority component
#   (1.68 M → 2.50 M).
#
#   In addition, RRG / RPP allocations are merit-awarded for a specific
#   project and are annually use-it-or-lose-it; default allocations are
#   auto-granted fallbacks. So even on FairShare ties, prefer RRG/RPP first.
#
# Usage:
#   ./pick-gpu-account.sh
#   sbatch --account=$(./pick-gpu-account.sh) /path/to/job.sh
#
# Fallback to the previous LevelFS behaviour:
#   PICK_BY=levelfs ./pick-gpu-account.sh
#
# Exits non-zero with an empty line if sshare fails or no *_gpu account
# matches.

set -euo pipefail

PICK_BY=${PICK_BY:-fairshare}

# Detect column indices dynamically — sshare's --parsable2 column order has
# shifted between SLURM versions, but the header labels are stable.
SSHARE_OUT=$(sshare -U -l --parsable2 2>/dev/null)
HEADER=$(echo "$SSHARE_OUT" | head -1)

FS_COL=$(echo "$HEADER" | awk -F'|' '{ for(i=1;i<=NF;i++) if($i ~ /^FairShare$/) print i }')
LFS_COL=$(echo "$HEADER" | awk -F'|' '{ for(i=1;i<=NF;i++) if($i ~ /^LevelFS$/) print i }')

if [ -z "${FS_COL:-}" ] || [ -z "${LFS_COL:-}" ]; then
    echo "ERROR: could not locate FairShare/LevelFS columns in 'sshare -U -l' output" >&2
    exit 1
fi

case "$PICK_BY" in
    fairshare) SORT_COL=$FS_COL ;;
    levelfs)   SORT_COL=$LFS_COL ;;
    *) echo "ERROR: unknown PICK_BY=$PICK_BY (expected fairshare|levelfs)" >&2; exit 2 ;;
esac

RESULT=$(echo "$SSHARE_OUT" \
  | tail -n +2 \
  | awk -F'|' -v c=$SORT_COL '$1 ~ /_gpu$/ { print $c, $1 }' \
  | sort -rn \
  | head -1 \
  | awk '{ print $2 }')

if [ -z "$RESULT" ]; then
    echo "ERROR: no *_gpu account found in 'sshare -U -l' output (cannot pick a GPU account)" >&2
    exit 1
fi

echo "$RESULT"
