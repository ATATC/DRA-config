#!/bin/bash
# Loop `seff` over the user's recent completed jobs for a given account.
# Works on any Alliance Canada cluster.
#
# Usage: ./group-seff.sh [days=7] [account=all]
#
# Examples:
#   ./group-seff.sh                       # last 7 days, all your accounts
#   ./group-seff.sh 30                    # last 30 days
#   ./group-seff.sh 14 def-<pi>_gpu       # last 14 days, specific account

set -euo pipefail
DAYS=${1:-7}
ACCOUNT=${2:-}

SINCE=$(date -d "$DAYS days ago" +%Y-%m-%d)

# NOTE: sacct --state filtering is unreliable on some Alliance clusters
# (observed empty results on Fir). Filter in awk instead — works everywhere.
SACCT_ARGS=(-u "$USER" --starttime="$SINCE" -X -P --noheader --format=JobID,State)
if [[ -n "$ACCOUNT" ]]; then
    SACCT_ARGS+=(-A "$ACCOUNT")
fi

printf "%-10s %-12s %-8s %-10s %-10s %-6s\n" "JobID" "State" "CPU%" "Mem%" "WallClock" "Cores"
printf "%-10s %-12s %-8s %-10s %-10s %-6s\n" "-----" "-----" "----" "----" "---------" "-----"

sacct "${SACCT_ARGS[@]}" | awk -F'|' '
    /\|(COMPLETED|TIMEOUT|FAILED)$/ { print $1 }
' | while read -r jid; do
    [[ -z "$jid" ]] && continue
    seff "$jid" 2>/dev/null | awk -v jid="$jid" '
        /^State:/            { state=$2 }
        /^Cores per node:/   { cores=$NF }
        /^CPU Efficiency:/   { cpu_eff=$3 }
        /^Memory Efficiency:/{ mem_eff=$3 }
        /^Job Wall-clock time:/ { wall=$NF }
        END { printf "%-10s %-12s %-8s %-10s %-10s %-6s\n",
              jid, state, cpu_eff, mem_eff, wall, cores }'
done
