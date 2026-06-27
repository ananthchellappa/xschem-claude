#!/bin/sh
# Action-log, file-menu effects (plan doc/claude/suggestions/plan_file_menu_logging.md):
# every effect reachable through the File menu is recorded as its resolved,
# replayable command -- opens as `xschem load {/abs/path}` (dialog resolved in
# ask_new_file, recent/-gui resolved in the scheduler load branch), save-as as
# `xschem saveas {/abs/path} schematic|symbol` (resolved in saveas()), plain
# picks (Save, Clear) verbatim via the menu wrapper, reload inside
# action_reload, and quitting as `xschem exit closewindow force` logged at the
# scheduler exit chokepoint just before the process dies.
#
# Process 1 drives the dialogs (stubbed) and menu picks and asserts in-process;
# process 2 quits for real and the shell asserts the exit line landed LAST.
#
# Needs a display: DISPLAY=:0 sh test_file_menu_log.sh

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
XSCHEM="$REPO/src/xschem"
fail=0
ok()  { echo "ok:   $1"; }
bad() { echo "FAIL: $1"; fail=$((fail+1)); }

if [ -z "${DISPLAY:-}" ]; then echo "SKIP: no DISPLAY"; exit 0; fi
if [ ! -x "$XSCHEM" ]; then echo "FATAL: $XSCHEM not built"; exit 3; fi

LOGDIR1=$(mktemp -d); LOGDIR2=$(mktemp -d); WORK=$(mktemp -d); DRV=$(mktemp)
cleanup() { rm -rf "$LOGDIR1" "$LOGDIR2" "$WORK" "$DRV"; }
trap cleanup EXIT

# work on a COPY of the fixture so save paths never touch the repo
cp "$REPO/xschem_library/examples/nand2.sch" "$WORK/fix.sch"

# --- process 1: open / save / save-as / reload / clear ------------------------
cat > "$DRV" <<EOF
update idletasks; focus -force .drw; update idletasks
proc check {name ok} { puts "[expr {\$ok ? {ok:  } : {FAIL:}}] \$name"; flush stdout }
proc loglines {} {
  set fd [open [xschem get actionlog_filename] r]
  set b [read \$fd]; close \$fd
  return [split [string trimright \$b \n] \n]
}
# dialog stubs: resolved paths without any UI
proc load_file_dialog {args} { return "$WORK/fix.sch" }
proc save_file_dialog {args} { return "$WORK/out.sch" }
proc alert_ {txt {pos {}} {nowait 0} {yesno 0}} { return 1 }

# 1. menu Open: the File menu command (xschem load, no args) -> dialog stub ->
#    ask_new_file logs the RESOLVED open after the load
set n0 [llength [loglines]]
xschem load
update idletasks
check "menu Open logs resolved load" \
  [expr {[lsearch -exact [loglines] "xschem load {$WORK/fix.sch}"] >= \$n0}]
check "menu Open actually loaded the file" \
  [string match *fix.sch [xschem get schname]]

# 2. recent-style open: scheduler load with -gui and a filename
set n0 [llength [loglines]]
xschem load -gui $WORK/fix.sch
update idletasks
set new [lrange [loglines] \$n0 end]
check "-gui load logs resolved file once" \
  [expr {[llength [lsearch -all \$new "xschem load {$WORK/fix.sch}"]] == 1}]

# 3. menu Save: wrapper logs the verbatim pick after it runs
set n0 [llength [loglines]]
.menubar.file invoke [.menubar.file index Save]
update idletasks
check "menu Save logs 'xschem save'" \
  [expr {[lsearch -exact [loglines] {xschem save}] >= \$n0}]

# 4. Save as: dialog stub -> saveas() logs the resolved path + type
set n0 [llength [loglines]]
xschem saveas
update idletasks
check "save-as logs resolved 'xschem saveas {file} schematic'" \
  [expr {[lsearch -exact [loglines] "xschem saveas {$WORK/out.sch} schematic"] >= \$n0}]
check "save-as wrote the file" [file exists "$WORK/out.sch"]

# 5. reload (menu row is nolog; the confirmed branch inside action_reload logs)
set n0 [llength [loglines]]
action_reload
update idletasks
check "confirmed reload logs 'xschem reload'" \
  [expr {[lsearch -exact [loglines] {xschem reload}] >= \$n0}]

# 6. menu Clear Schematic: verbatim pick via the wrapper
set n0 [llength [loglines]]
.menubar.file invoke [.menubar.file index {Clear Schematic}]
update idletasks
check "menu Clear logs 'xschem clear schematic'" \
  [expr {[lsearch -exact [loglines] {xschem clear schematic}] >= \$n0}]

# 7. the whole file stays source-able
check "log file is source-able" \
  [expr {![catch {uplevel #0 [list source [xschem get actionlog_filename]]} err]}]

catch {destroy .ciw}; update
exit
EOF
OUT1=$(timeout 60 "$XSCHEM" --pipe -q --logdir "$LOGDIR1" --script "$DRV" 2>&1)
echo "$OUT1" | grep -E "^(ok:|FAIL:)"
N1=$(echo "$OUT1" | grep -c "^ok:")
F1=$(echo "$OUT1" | grep -c "^FAIL:")
[ "$N1" -eq 9 ] && [ "$F1" -eq 0 ] && ok "process-1 checks all passed" || bad "process-1: $F1 failed / $N1 ok (want 9)"

# --- process 2: a real quit logs the exit line, and logs it LAST --------------
cat > "$DRV" <<EOF
update idletasks; focus -force .drw; update idletasks
xschem load $WORK/fix.sch
catch {destroy .ciw}; update
xschem exit closewindow force
EOF
timeout 60 "$XSCHEM" --pipe -q --logdir "$LOGDIR2" --script "$DRV" >/dev/null 2>&1
LOG2="$LOGDIR2/Xschem.log"
if [ -f "$LOG2" ] && [ "$(tail -1 "$LOG2")" = "xschem exit closewindow force" ]; then
  ok "quit logs 'xschem exit closewindow force' as the last line"
else
  bad "quit line missing or not last ($(tail -1 "$LOG2" 2>/dev/null))"
fi

if [ "$fail" -eq 0 ]; then echo "RESULT: ALL PASS"; else echo "RESULT: $fail FAILED"; fi
[ "$fail" -eq 0 ]
