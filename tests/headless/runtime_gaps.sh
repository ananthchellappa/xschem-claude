#!/bin/sh
# runtime_gaps.sh [runid|dir] -- decompose a workflow run's ELAPSED time into
# ACTIVE work and STALLED wall-clock, and say whether the box was suspended.
#
# Why this exists: a run that reports "7 hours" is almost never seven hours of
# work. Twice now (crew_annotate, and the 0658 crew on 2026-08-24) a single
# multi-hour gap was ~98% of the elapsed time, caused by the WINDOWS HOST
# SLEEPING and freezing the whole WSL2 VM. Reconstructing that by hand costs an
# hour of forensics; this prints it directly.
#
# The suspend check is a clock contradiction, not a guess: while the VM is
# suspended the monotonic clock stops but wall clock resyncs from the host on
# resume, so /proc/stat's btime (= now - uptime) jumps FORWARD by the sleep
# duration. Any file older than the claimed boot time proves no reboot happened
# and the shift is a suspend.
set -e

W="$HOME/.claude/projects/-home-analog-dev-xschem-claude"
S="$W/d3814e51-1808-449c-9831-c79891f78000/subagents/workflows"
case "$1" in
  "")      D=$(ls -dt "$S"/wf_* 2>/dev/null | head -1) ;;
  /*)      D="$1" ;;
  *)       D=$(ls -dt "$S"/*"$1"* 2>/dev/null | head -1) ;;
esac
[ -n "$D" ] && [ -d "$D" ] || { echo "runtime_gaps: no such run: ${1:-<latest>}" >&2; exit 2; }

echo "run: $(basename "$D")"

python3 - "$D" <<'PY'
import json, os, sys, datetime
D = sys.argv[1]
def p(x): return datetime.datetime.fromisoformat(x.replace('Z', '+00:00'))
THRESH = 600  # a gap this long is not thinking, it is a stall

tot_span = tot_stall = 0.0
first = last = None
rows = []
for f in sorted(os.listdir(D)):
    if not (f.startswith('agent-') and f.endswith('.jsonl')): continue
    ts = []
    for line in open(os.path.join(D, f)):
        try: d = json.loads(line)
        except Exception: continue
        if d.get('timestamp'): ts.append(p(d['timestamp']))
    if len(ts) < 2: continue
    ts.sort()
    span = (ts[-1] - ts[0]).total_seconds()
    gaps = [((ts[i+1] - ts[i]).total_seconds(), ts[i]) for i in range(len(ts)-1)]
    stall = sum(g for g, _ in gaps if g > THRESH)
    big = max(gaps, key=lambda g: g[0])
    first = ts[0] if first is None else min(first, ts[0])
    last  = ts[-1] if last is None else max(last, ts[-1])
    tot_span += span; tot_stall += stall
    rows.append((f[6:14], len(ts), span, stall, big))

rows.sort(key=lambda r: -r[3])
print("%-10s %5s %8s %8s %8s  %s" % ("agent", "recs", "span", "active", "stalled", "largest gap began"))
for a, n, span, stall, big in rows:
    print("%-10s %5d %7.2fh %7.2fh %7.2fh  %6.0fs @ %s" %
          (a, n, span/3600, (span-stall)/3600, stall/3600, big[0], big[1].strftime('%H:%M:%SZ')))

if first and last:
    wall = (last - first).total_seconds()
    print("\nwall clock across all agents : %.2f h" % (wall/3600))
    print("agent-seconds stalled >10min : %.2f h of %.2f h (%.0f%%)"
          % (tot_stall/3600, tot_span/3600, 100*tot_stall/tot_span if tot_span else 0))
PY

echo
echo "--- was the VM suspended? ---"
BT=$(awk '/btime/{print $2}' /proc/stat)
BTS=$(date -d "@$BT" '+%F %T')
echo "claimed boot (btime)          : $BTS"
OLD=$(find "$D" -type f ! -newermt "$BTS" 2>/dev/null | wc -l)
if [ "$OLD" -gt 0 ]; then
  echo "files in this run older than it: $OLD"
  echo "VERDICT: SUSPENDED. A file cannot predate its filesystem's boot, so btime"
  echo "         jumped forward -- the host slept and froze the VM. Not a reboot,"
  echo "         not a slow run, not an API stall. Fix is Windows-side:"
  echo "         powercfg /change standby-timeout-ac 0"
else
  echo "files in this run older than it: 0"
  echo "VERDICT: no suspend detected for this run. A large stall above is then a"
  echo "         genuine stall -- look at the record either side of the gap."
fi
