# 0650 — `ase::echo` has no sink in the ASE session window, so every notice the feature emits is invisible where the user is working

STATUS: **OPEN — measured 2026-08-23** by the adversary leg of the 0648 crew,
which flagged it as the reason 0648's fix may be invisible to the very user who
reported it. Related: 0617, 0633, 0635, 0636, 0648, 0649.

---

## The measurement

```tcl
proc ase::echo {msg {tag {}}} {
  if {[info commands ::ciw_echo] ne {}} { catch {::ciw_echo $msg $tag} }
  ...
  if {$tag eq {error}} { catch {xschem log_action -error $msg} } \
  else                 { catch {xschem log_action -result $msg} }
}
```

Two sinks, and **neither is the ASE session window**:

* `::ciw_echo` — the CIW, a *separate, closable* toplevel;
* `xschem log_action` — a `#= ` line in `Xschem.log`.

`grep -n 'ciw_echo|proc ase::echo' src/ase_window.tcl` returns **nothing**. The
window the user drives the simulation from has no echo sink at all.

## Why this matters more than a missing widget

Every sentence the OP-annotation work added speaks through `ase::echo`:

| message | issue |
|---|---|
| "device operating-point parameters … were NOT saved in this deck. Tick Outputs > Save All …" | 0617 nudge |
| "`$n` device OP save card(s) added to the deck." | the success line, since 44f52f9a |
| "no device OP save cards were added — this schematic has unsaved edits …" | 0633 refusal |
| "no device below this cell produced an OP save card …" | the empty-block report |
| "ASE op cards: …" under-emission warnings | `last_warnings` |
| the discard line 0648 just added | 0648 |

**The user who reported 0648 never mentioned seeing the run-1 nudge.** That is
consistent: they were in the ASE window, and the nudge went somewhere else. Their
report — "I re-ran the sim and still don't get OP info" with no mention of any
message — is what this defect looks like from the outside.

It also means **0648's fix inherits the same invisibility.** The re-armed nudge
and the new discard line are correct and tested, and a user with the CIW closed
still sees nothing. Fixing 0648 without fixing this leaves the user exactly where
they started.

## The correction this forces to 0648's own filing

0648 §3 claimed *"Nothing ever confirms the cards WERE emitted."* **That is
wrong** — `src/ase.tcl` has echoed `ASE: $n device OP save card(s) added to the
deck.` since commit `44f52f9a`, twelve hours before 0648 was filed. The message
existed; it was *unreachable*. The defect was never the missing sentence, it was
the missing sink. 0648's Outcome section records the refutation.

## What to do

Give the ASE session window a sink. The natural one already exists — the log
toplevel (`$top.logwin`, `ase::ui::log_append`) — but note it is *closable* too
and is scoped to a run, whereas these notices fire at netlist time. Candidates,
in rough order of blast radius:

1. A **status/notice line in the session window itself**, always present. Smallest
   surprise, always visible, no new window.
2. Tee `ase::echo` into `ase::ui::log_append` for the session that raised it —
   cheap, but only helps when the log window is open, and 0649 shows that window
   already has content problems.
3. Auto-raise the CIW on an `error`-tagged echo. Rejected on sight: stealing focus
   mid-run is worse than silence.

## Landmines

- **Do not change `ase::echo`'s existing two sinks.** Tests capture ASE notices by
  renaming `::ciw_echo`, and an empty message still echoes a blank line — both are
  relied upon. Add a sink; do not reroute.
- `ase::echo` is called from non-GUI paths (`ase::netlist`, `ase::run_deck`) that
  must keep working headless with no session window at all. A new sink must be a
  no-op when there is no window, exactly as `ase::ui::log_widget` returning `{}` is.
- An echo can fire before the session window exists, and after it is destroyed.
- Volume: the under-emission channel can emit one line per unnamed device. A
  session-window sink needs the same discipline the nudge got (0636) or it becomes
  the noise it was meant to cure.

## Acceptance

- With the CIW closed, a netlist that emits no OP cards produces a message the
  user can see without opening another window.
- Headless runs are unaffected; no suite that renames `::ciw_echo` changes count.
- The success line, the nudge, the refusal and the discard all reach the new sink.
