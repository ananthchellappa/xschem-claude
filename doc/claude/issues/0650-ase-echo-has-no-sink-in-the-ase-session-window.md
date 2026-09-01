# 0650 — `ase::echo` has no sink in the ASE session window, so every notice the feature emits is invisible where the user is working

STATUS: **OPEN — measured 2026-08-23** by the adversary leg of the 0648 crew,
which flagged it as the reason 0648's fix may be invisible to the very user who
reported it. Related: 0617, 0633, 0635, 0636, 0648, 0649, **0653**.

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

## SCOPE ENLARGED 2026-08-23 — this issue now builds the general channel (0653)

0653 asked for the same thing from the other end: an OP annotation that renders blank
must say *why*, on a channel that cannot itself go silent. Its rulings are answered
and its build order puts the channel here, in 0650, because 0650 already has a real
consumer (`ase::echo`) and real suites to prove it with. Building the sinks inside
0653 would mean writing them twice and having two places to forget one.

**So this crew delivers `xschem::notify`, and rewires `ase::echo` onto it.** It does
NOT deliver the annotation accounting — that is 0653's own crew, second.

### The four sinks, behind one call

| sink | when | why |
|---|---|---|
| `xschem log_action` | **always** | durable, greppable, survives a shut window. Makes a notice auditable after the fact. Already what `ase::echo` does. |
| `ciw_echo` | when the CIW exists | the right channel for a live session. **No-ops silently when shut** (`src/ciw.tcl:120-121`) — which is precisely why it may not be the only visible sink. |
| `.statusbar.12` in the drawing window | when the CIW is shut **and** `::notify_style` is not `popup` | the can't-miss fallback. Precedent: `src/hilight.c:2201` already writes `*BUSY*` there. Short form plus "see CIW / log". |
| modal dialog, OK / ESC | `::notify_style eq {popup}` | opt-in, ruled global in 0653 R-0653-b. |

Without row 3 there is a reachable state — CIW shut, pop-up off — where the tool has
diagnosed a problem perfectly and told nobody. **That state must not exist**, and it
is the whole reason this issue is not just "add a text widget to the ASE window".

### Ruled behaviour inherited from 0653

* **`set ::notify_style {ciw|popup}`, default `ciw`** (R-0653-a). Read at call time,
  not cached — a user rc may set it after the proc is defined (invariant I5).
* **Global, one setting, all notices** (R-0653-b). No per-subsystem matrix.
* **Suppress an identical notice while the underlying state is unchanged; re-arm on
  change** (R-0653-c). **Reuse the latch 0648 just landed**
  (`ase::op_cards_nudge_ok` / `ase::op_cards_nudge_reset`) — generalise it, do not
  write a second one. One builder, two consumers (invariant I1); the 0648 sabotage
  leg proved that shape holds.
* **Every notice may carry a remedy: a menu location and a pasteable CIW command;
  never a button that acts** (R-0653-d). The signature must carry them as distinct
  fields, not baked into the message string, or the tests cannot execute the command
  separately from rendering the text.

### R-0653-d's three requirements are ACCEPTANCE ITEMS, not advice

1. **A test EXECUTES the printed command; it never string-compares it.** Trap already
   in the tree, `src/ase_window.tcl:2912`: "OFF IS `{}`, NEVER `0`". A remedy printing
   `save_op_params 0` looks right and is wrong; only execution catches it.
2. **The menu path is derived from the live menu or asserted against it.** Labels
   carry `\u2026` (`src/ase_window.tcl:470-502`). A hardcoded path missing a cascade
   level is a wrong direction printed with authority.
3. **The command invokes the same proc the menu invokes**, never the state underneath.
   `save_op_params` is "read as a gate in THREE places" (`src/ase.tcl:544`) and the
   menu path also invalidates the deck. Advice that half-works is the worst outcome
   available here.

### Headless

Under `--nogui` there is no Tk. The log sink must still fire, and **no sink may
raise**. `ciw_echo` already guards on `info commands winfo`; the statusbar and modal
sinks must guard equivalently, or every headless suite dies at the first notice.

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

---

## OUTCOME 2026-08-23 — the channel LANDED (status **E**); the session-window sink did NOT (issue 0655)

### ⚠ THIS ISSUE'S OWN MECHANISM SENTENCE IS FALSE, AND CORRECTING IT WAS THE FIX

The sink table above says `ciw_echo` *"No-ops silently when shut
(src/ciw.tcl:120-121)"*. **Measured false.** `src/ciw.tcl:53` is
`wm protocol .ciw WM_DELETE_WINDOW {wm withdraw .ciw}`, so closing the CIW
**withdraws** it: `.ciw` and `.ciw.l.t` still **exist**, `winfo ismapped` is 0,
and `ciw_echo` happily writes into the invisible widget — the pane text GREW.
`src/xschem.tcl:16703` already said so in a comment.

Consequence, and it is the whole reason to write this down: a fallback whose
condition is `winfo exists` would evaluate **true in exactly the user's
situation**, never fire, and **pass review**. The predicate is `winfo ismapped`
(`xschem::notify_ciw_visible`). Sabotaging it back to this issue's literal
sentence reddens PS14+PS15 — measured twice, independently.

The genuine `ciw_echo` no-op cases are `--nogui` (no `winfo`) and `--nolog`
(`ciw_create` is skipped, `src/xschem.tcl:16705`).

### What shipped

`xschem::notify` in `src/ciw.tcl` — four sinks, a `::xschem::notify_last` headless
witness whose `sinks` field names only the sinks that really succeeded, the
generalised R-0653-c latch (`notify_latch_{ok,rearm,reset}`), and the R-0653-d
remedy fields. `ase::echo` **and** `wviewer::echo` — byte-identical copies of each
other, a standing invariant-I1 breach *before* this step — are one-line delegates.

Acceptance, against the rows above:
* *"With the CIW closed, a netlist that emits no OP cards produces a message the
  user can see"* — **met for a withdrawn / iconified / never-created CIW**
  (PS14/PS15, 6/6 on a quiet tree). **Not met for a CIW that is merely stacked
  behind the design window** — `ismapped 1`, `viewable 1`, statusbar untouched.
  Filed as **0659**.
* *"Headless runs are unaffected; no suite that renames `::ciw_echo` changes
  count"* — **met**. Every baseline count is unmoved.
* *"The success line, the nudge, the refusal and the discard all reach the new
  sink"* — **met mechanically** (all four go through `ase::echo`), but the
  **discard still prints hardcoded, drifted menu prose** (**0661**), and volume
  means only the **last** of several notices survives on the fallback (**0660**).

### Still open, from this issue

**0655** (the session-window sink — this issue's actual title) is **not** closed:
`ase::echo` carries only `(msg, tag)` and has no session target. Also open:
**0658** (a missing channel silences everything, the durable log included),
**0659**, **0660**, **0661**, **0654**. Fixed in the same pass: **0656**, **0657**.
