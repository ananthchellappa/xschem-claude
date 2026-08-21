# Voice / natural-language control of xschem — the ATOMIC plan

Status: **PROPOSED 2026-08-20, planning only. No code exists.**
Branch `fluid-editing`, HEAD **`ab33cee6`** (the architecture doc landed at
`722ce61e`; `ab33cee6` committed issues 0519 and 0520, which were untracked when
this pass began; see §4 and the Appendix).
Next free issue number: **0521** (`ls doc/claude/issues | grep -oE '^[0-9]{4}' |
sort -n | tail -1` → `0520`; `doc/claude/issues/status.md:48` already says
*"Highest in use here is 0520, so the next one is 0521"* and needs no edit).

**Companion, and the authority for everything this file does not restate:**
`doc/claude/suggestions/voice_control_natural_language_plan.md` (847 lines,
commit `722ce61e`) — the architecture. **This file answers only "what do I do
first, then next".** It does not re-argue the architecture; where it *amends* the
architecture it says so, by line number, in §1.

Precedence, in force from the moment work starts:
**the voice spec (§4/A2, once it exists) > a filed issue > this file > the
architecture doc.** The architecture doc is demoted deliberately: two of its
sentences contradict the user's rulings and Amendment AM-1 strikes them in place.

---

## The two rulings this plan is built on

Both are the user's own words, quoted verbatim, and both are load-bearing.

> **RULING 1 (recipes, not commands).** *"it might be easier to say 'run sim' and
> 'plot vbg' or 'run LVS' than to go through menus, sometimes. Something like
> 'open saved state associated with this schematic' takes me a few clicks and
> mouse pointer movements to accomplish."*

> **RULING 2 (voice is one source among many).** *"we cannot have only one source
> that issues commands. They can come from keyboard, mouse, user typing into CIW
> entry field, TCP server, whatever. We don't expect conflicts. But, if there are,
> we can cross that bridge when we come to it."*

> **RULING 3 (LVS was a shape, not a request — and it names the ranking rule).**
> *"I meant 'run LVS' conceptually only. I know there isn't anything like that
> today in Xschem. What I meant is, a very short, easy utterance that, through
> menu/mouse/keyboard would cost more effort."*

The target is the **multi-click, parameterised chore**. The mouse wins for
drawing and the user agrees; that exclusion is permanent, not a v1 limitation
(§9). At least three of the four named examples are **not one xschem command**;
they are multi-step recipes, and one of them (`run LVS`) is nothing at all in
this tree today (§2).

**Ruling 3 gives the catalogue its admission test, and it is a RATIO, not a
click count:**

> **gesture cost today ÷ utterance cost.** A chore earns a row when the hand
> path is long *and* the phrase is short. Both halves are required.

Four corollaries, and they cut real candidates:

1. **An existing accelerator usually disqualifies a row.** If one key already
   does it, voice is competing with a keystroke and loses on latency, on
   accuracy and on the fact that a misheard word can execute something else.
   `zoom full`, `undo` and `escape` are excluded on exactly this test (§9) — and
   V-01a/V-04/V-06/V-11 all survive it, and the reason is structural rather
   than lucky: they live in or route through the **ASE-L window, which has zero
   keyboard accelerators** — measured this run, `grep -c accelerator
   src/ase_window.tcl` → **0**, against **16** in `src/wave_viewer.tcl` and
   **119** in `src/xschem.tcl`. The parts of this tool that are mouse-only are
   exactly the parts worth speaking to.
2. **A parameter raises the numerator hard.** `plot vbg` is worth saying because
   the alternative is a canvas hunt or typing into a browser; `plot` alone
   would not be.
3. **A window hop is worth ~2 clicks that no click count shows** — raise, re-aim,
   and the eye re-finding its place. V-04 and V-06 cross schematic → ASE-L →
   viewer.
4. **Frequency multiplies it.** A 6-click chore done twice a session beats a
   10-click chore done twice a month.

The `replaces today` column of the catalogue is the numerator, measured. It is
not decoration: a row whose numerator is 1 click and whose only virtue is that
it can be spoken should be struck before a crew builds it.

---

## 1. What changed since the architecture doc

Three amendments. They are rulings, not options, and AM-1–AM-3 belong in
`DECISIONS.md` before any code is written.

### AM-1 — an intent binds to a NAMED RECIPE, never to a command string  *(Ruling 1)*

The architecture doc says the opposite in two places and **both sentences must be
struck through in place**, the way `doc/claude/results_batch/PLAN.md:177-188`
strikes a superseded requirement (keep the wrong text, annotate it; do not
delete, because items were briefed against it):

- `voice_control_natural_language_plan.md:18-20` — *"Tier 0 is a deterministic
  table — utterance → intent id → **an emitter template the broker owns** — and
  answers in ~7 ms"*
- `:266-267` — *"broker: allow-list → arity/type check → **emitter template** →
  ONE wrapped line"*

An emitter template *is* a command string. Replace with: **the broker's output
space is `{recipe_id, slot spans}`**; the recipe is an ordinary Tcl proc in this
tree that any source can call.

Three measurements force it:

1. **ASE-L is 100% mouse-only.** `grep -c accelerator src/ase_window.tcl` → **0**
   (`src/wave_viewer.tcl` → 16, `src/xschem.tcl` → 119). The five `bind $top` rows
   (`src/ase_window.tcl:274,278,279,585,586`) are two window-closes, a `<FocusIn>`
   and two entry commits — no action chord. Three of the user's four examples live
   in that window. Voice there competes with **nothing**.
2. **A bare proc name is already a first-class command everywhere else.**
   `ciw_exec` (`src/ciw.tcl:227`) does an unconditional `set code [catch {uplevel
   #0 $cmd} res]` at `:254`. Measured: a hand-defined proc typed bare into the CIW
   ran, echoed its result, entered history, and landed in `Xschem.log` as
   `voice_run_sim` + `#= sim launched` — indistinguishable from `xschem undo`.
   Typing `run sim` produced `# failed: run sim` + `#! invalid command name
   "run"`. **Nothing must be built for recipes to be runnable; only for them to be
   named in English.**
3. **The async intents cannot be assembled from outside the process.**
   `ase::run` (`src/ase.tcl:1706`) returns an execute id (measured 177 ms) and
   completes ~59 s later by evaluating a Tcl callback at global level
   (`src/ase.tcl:1901`). The three outside-broker options all fail: polling is N
   round trips of frozen editor; `ase::wait` (`src/ase.tcl:1906`) brackets its
   `vwait` with `xschem set semaphore ±1` (`:1909-1911`), and a raised semaphore
   makes every `new_schematic switch` a silent no-op (`src/ase_window.tcl:5040-5049`
   records this as having emptied the design schematic); and pumping the event loop
   from inside a socket command is the wedge that **permanently destroys the
   channel** (0519-A, reproduced twice this run).

Consequence for the sequence: **the recipe file (B6–B8) comes before slots (B9)**,
and the recipes are named `recipe::*`, **not** `voice::*` — a proc only voice can
call is the smell Ruling 2 exists to prevent. The CIW, the palette, `actions.csv`,
a key bind, a socket client and a headless suite are all first-class callers.

### AM-2 — the NL translator lives IN-PROCESS; `xvoiced` becomes a thin transport

A change from `…plan.md:253-266` (§3). The CIW is already an unconditional Tcl
evaluator with an existing string→string rewrite hook applied **before** the eval:
`ciw_interactive_load` (`src/ciw.tcl:219`, called at `:230`), whose own header
states the scope exactly — *"scripts, --script files and action-log replays do NOT
go through here"*, i.e. **typed-by-a-human only**, which is precisely the voice
layer's scope.

What it buys: the typed path and the spoken path share **one** implementation, so
Phase C adds a microphone and nothing else; the whole NL layer is testable by a
scored `test_*.tcl` inside xschem with no second process; and the allow-list
shrinks from **322 verbs** (`wc -l src/xschem_subcommands.txt` → 322) to ~40
recipe ids — a closed set, strictly stronger and much smaller to audit.

`xvoiced` then only: finds the right editor, refuses if more than one is
listening, wraps one line, and sends `voice::utter {<text>}`. No grammar, no
table.

### AM-3 — no lock, no owner, no serialisation scheme  *(Ruling 2)*

`…plan.md:17-18` — *"A single long-lived WSL process (`xvoiced`) **owns the
only socket to xschem**"* — is struck in place by AM-1's mechanism. It is wrong as a
requirement and it contradicts the ruling.

Measured, twice, this run: **two simultaneous connections were both accepted and
both answered correctly** (per-connection state is keyed by socket handle,
`src/xschem.tcl:5927-5928`, unset per socket at `:5890-5892`); a client arriving
300 ms into a 1500 ms command **waited 1203.6 ms and received the correct
answer**. The Tk event loop already *is* the queue. Exclusivity buys nothing and
does not even cover the real hazard — the 0519-A wedge is caused by a **nested**
call inside a **single** client's command.

The one exclusivity rule in v1 concerns the **target, not the client**: if more
than one xschem is listening, refuse and print the list (C1). Everything else is
**deferred by user ruling** (§9), and `DECISIONS.md` must carry that ruling in the
user's own words so a later contributor does not helpfully add a lock.

---

## 2. The v1 intent catalogue

**Binding rule:** an utterance selects a `recipe_id` and a set of verbatim
transcript **spans**. A deterministic resolver maps each span to a real identifier
drawn from the live design. *The model never emits an identifier.* If a future
contributor lets it, the architecture has failed.

Class key: **read** = no writes anywhere · **reversible** = one named inverse
exists · **amber** = writes files outside the schematic, announced · **red** =
overwrites something the user authored, second-channel confirm.

| id | say | recipe (all steps composed in one proc) | slots | class | replaces today |
|---|---|---|---|---|---|
| **V-01a** | `run sim` (ASE-L session present) | `ase::session_for_current` → make design current → `ase::run <state> <callback>` | — | amber | 2 clicks + 2 cold, **0 accelerators exist** |
| **V-01b** | `run sim` (plain schematic) | `set_sim_defaults` if unset → assert a batch profile → `xschem netlist` → `simulate` → report | — | amber | 2 clicks, and the shipped default silently does the wrong thing |
| **V-02** | `stop` | `ase::ui::do_stop $key` (`src/ase_window.tcl:5109`) | — | destructive-outward, **no gate** | 2 clicks |
| **V-03** | `is it done` | live id? else `ase::last_result` (`src/ase.tcl:1919`) | — | **read** | 2 clicks + read a log pane |
| **V-04** | `plot vbg` | bracket → session → viewer open → raw attached → resolve → `wviewer::plot_signals` (`src/wave_viewer.tcl:7302`) → restore | `signal` 1..n | reversible | 3 clicks + a canvas hunt, **or** 3 + typing (+2 to open the viewer) |
| **V-05** | `plot the outputs` | bracket → `ase::ui::auto_plot $key` (`src/ase_window.tcl:4932`) → restore | — | amber (clears the auto strip) | **no click exists — see below** |
| **V-06** | `open the saved state for this schematic` | `ase::design_of_current` → `ase::ui::state_views` → tie-refuse → `ase::open_state` → restore | `view` (optional) | reversible, rebinds results | 4–6 clicks + scrolling 6 libs / 49 cells |
| **V-07** | `save the state` / `save state as <name>` | `ase::session_save` (`src/ase.tcl:3599`) or `ase::session_adopt` (`:3620`) | `view` (optional, free text) | **red** | 3 clicks + typing |
| **V-08** | `use the last run` | `results::list` (`src/results.tcl:287`) → `results::select` (`:711`) | `result` | reversible | 4 clicks |
| **V-09** | `highlight vdd` | resolve → `xschem hilight_netname <net>` per name (`src/scheduler.c:6511`) → one redraw | `net` 1..n | reversible | hunt + click + `K` |
| **V-10** | `descend into X1` | `xschem descend -inst <name>` (`src/scheduler.c:3213`, `-inst` arm `:3219`) | `instance` | reversible | hunt + click + `E` |
| **V-11** | `make R5 twenty k` | `xschem setprop instance <inst> <tok> <val>` (`src/scheduler.c:12621`) → read back | `instance`,`token`,`value` | reversible (undo) | hunt + click + `q` + field + OK = **≥4 + typing** |
| **V-12** | `undo that` | recorded inverse of the last **voice** act, fingerprint-checked | — | reversible | 1 key (a safety intent, not a click saver) |
| **V-13** | `check it` | `xschem check_unique_names 0` + `xschem net_pin_mismatch` | — | **read** | 2 separate invocations |
| **V-14** | `netlist it` | `xschem netlist -erc` | — | **amber, announced** | 1 click |

⚠ **Read the third column as the steps, never as the binding target.** Per AM-1
every row is reached through a `recipe::<id>` proc and the broker's output space
is `{recipe_id, spans}`; the cell names what that proc composes. This matters most
for the thin rows — V-02, V-13 and V-14 look like one command each, and a crew
member who binds the utterance straight to `ase::ui::do_stop` or
`xschem netlist -erc` has reintroduced the emitter template AM-1 struck. A thin
recipe is still a recipe: it owns the bracket, the `catch`, the
`{ok done_steps failed_step reason}` return and the announced side effect, none of
which a bare command string has.

**V-05 is the highest-value entry on a cost basis and it replaces no click,
because there is no click.** `ase::ui::auto_plot` is the complete "plot everything
this state marks plottable" recipe; its **only** caller in the tree is `after idle
[list ase::ui::auto_plot_idle $key]` at `src/ase_window.tcl:5048`, inside
`run_finished`. No menu, no key, no button reaches it. Today a user who deleted a
trace must re-run the simulation (measured 59.2 s on `tb_bandgap`) to get the plot
set back. File it as issue **0527** (§8) whether or not voice ships.

### The user's four examples, answered honestly

| the user said | what v1 does | honest caveat |
|---|---|---|
| **"run sim"** | V-01a *and* V-01b — both are recipes | The two paths behave differently and v1 must implement **both**. `proc simulate` (`src/xschem.tcl:6112`) **does not netlist** — `grep 'file exists' src/xschem.tcl` over `:6112-6199` returns nothing, so it runs the tool on a stale or absent `$N` and says nothing. Worse, the shipped default `sim(spice,default)` is **0** and `sim(spice,0,cmd)` is `$terminal -e {ngspice -i "$N" -a \|\| sh}` (`src/xschem.tcl:4331`) — an *interactive terminal* that produces no raw. V-01b must assert a batch profile (`sim(spice,2,cmd)` = `ngspice -b -r "$n.raw" "$N"`, `:4345`) and refuse with an offer if none is configured, rather than report on a run it cannot see. |
| **"plot vbg"** | V-04 | Works, and the seam is clean: measured `wviewer::plot_signals $key {v(vbg)}` → **22.1 ms**, and `{v(bogus_zz)}` → **0.76 ms** returning `{v(bogus_zz) {unknown token 'v(bogus_zz)' (not an operator/function, number or raw variable)}}` — a per-name, machine-readable refusal, the best error surface in the tree. Case skew is real: the state spells it `VBG`, the raw spells it `v(vbg)`. |
| **"run LVS"** | **Not in v1. It does not exist in this tree — and per Ruling 3 that is not a gap in the catalogue.** The user named it as an example of the *shape*, not as a request. It stays in this document as the worked example of the class, because it makes the general point: once the layer exists, any tool added later is voiced for roughly the cost of one table row and one recipe proc. | Verified, not assumed: `sim(tool_list)` = `spice spicewave spectre verilog verilogwave vhdl vhdlwave` (`src/xschem.tcl:4327`) — there is no verification tool class for `simconf` to iterate. `Simulation > LVS` (`src/xschem.tcl:17725-17738`) is **five netlist-format checkbuttons** (`lvs_netlist`, `uppercase_subckt`, `top_is_subckt`, `lvs_ignore`, `spiceprefix`), not a run. `grep -rn "netgen\|klayout\|magic\b" src tests` hits only the English phrase "magic number". The three PDK `run.sh` files are 7 lines each and only exec xschem. **The recipe shape is right and the tree is missing one step**: `lvs_netlist 1; top_is_subckt 1; xschem netlist; exec <the user's comparator>` — v2, gated on issue **0525** (a verification-tool class, or a general external-tool registry). Do not substitute something else and call it LVS. |
| **"open saved state associated with this schematic"** | V-06 | Works, one call — `ase::open_state lib cell view` (`src/ase.tcl:3689`), measured **417 ms**. Two traps: **the ambiguity is real in the user's own tree** (`ase::ui::state_views sky130_tests_ase tb_bandgap` → `ngspice_state1 ngspice_state_test`, 2.50 ms), so the recipe must offer both and refuse the tie; and **Route B is not this intent** — `Session > Load State` (`ase::ui::do_load_state_from`, `src/ase_window.tcl:4212`) is a *content import* that leaves the session key pointing elsewhere, so a later Save State does not write back. |

### V-13 was wrong in the design pass and is fixed here

The design pass classed `check.run` as **read** and gave it four steps. Two of
those steps **edit the user's schematic**:

- `xschem show_unconnected_pins` — measured this run: instances **15 → 17** on
  `rlc.sch` + one unconnected resistor, `modified` stays 1. It places a
  `lab_show.sym` label on every unconnected pin. `src/netlist.c:1715-1731` →
  `attach_labels_to_inst(2)` at `:1729`; the tree's own comment at
  `src/scheduler.c:808-827` calls it *"always-mutating"* and says the raw call
  **owns the undo**. **Excluded from voice entirely.**
- `xschem netlist -erc` writes files into `netlist_dir` **and pushes undo**
  (`src/in_memory_undo.c:614` — *"was incremented by a previous push_undo() in
  netlisting code"*), and the architecture doc's own tier table puts `netlist` in
  the **red** tier (`…plan.md:415`). It becomes its own announced intent **V-14**,
  not a hidden step inside "check it".

What survives as **read**: `check_unique_names 0` (highlight only — `1` *renames*,
`src/actions.csv:100,101`) and `net_pin_mismatch` (`Shift-X`, `src/actions.csv:99`).

### Corrections to the design pass's own claims

- **V-09 is a win, not a unique capability.** "No GUI entry anywhere passes a
  name" is **false**: `Ctrl+F` → `tools.search` (`src/actions.csv:153`) →
  `property_search` (`src/xschem.tcl:11883`) has a **Highlight** radio
  (`src/xschem.tcl:11930`) and runs `xschem searchmenu exact $search_select …`
  (`:11919`). `net_hilight_apply` (`:666`) and `probe_net` (`:5987`) also take
  names. V-09 still saves a hunt-and-click; it is not the only door.
- **`ase::run` and `ase::netlist` THROW, they do not echo.** `return -code error`
  at `src/ase.tcl:1666, 1669, 1679, 1686, 1695` and `:1709`. `ase::ui::do_run`
  catches; a recipe calling `ase::run` directly does not. Every recipe wraps its
  calls in `catch` and converts to the `{ok done_steps failed_step reason}`
  contract (§5/B6).
- **`ase::netlist` takes a different branch headless.** `src/ase.tcl:1683-1690`:
  under `!has_x` it silently `xschem load $path`; under X it refuses. A green
  `--nogui` suite does **not** prove the GUI path — B7 owes an X leg.

### The recognised-and-refused set

A phrase the user will say and this tree cannot do must produce an **honest named
refusal**, never silence. Out-of-grammar silence is the standing VUI defect: a
system that silently ignores its user teaches that user to stop talking to it
inside a week.

| phrase | refusal |
|---|---|
| `run LVS` · `run DRC` · `check the layout` | *"xschem has no LVS. It netlists for one — the LVS netlist switches are under Simulation, LVS. Say 'check it' for the checks it does have."* |
| `move that` · `drag it` · `stretch the wire` · `rotate this` | *"I don't do drawing. Use the mouse."* |
| `draw a wire` · `place a resistor` | *"I don't place or draw. Use the mouse."* |
| `save the schematic` · `save all` | *"I don't save schematics. Ctrl-S."* |
| `quit` · `close everything` | *"I don't close xschem."* |
| `delete it` · `clear` | *"I need a name — I don't delete by pointing."* |

### Grammar budget

Measured on this box: **0.95 ms per identifier, linear** (50 → 46.8 ms, 100 →
74.4 ms, 300 → 246.1 ms, 1000 → 964.5 ms). **Cap every slot's `<one-of>` at 300.**
A realistic per-schematic vocabulary (~40 nets + ~60 instances) swaps in ~74 ms.
Re-derived this run with `grep -rhoE 'lab=[A-Za-z0-9_\[\]:.]+' xschem_library/ |
sort -u | wc -l`: **637** distinct across the whole library, **45** in the
heaviest single example (`xschem_library/examples/test_bus_tap.sch`). ⚠ Both
numbers move with the token character class you choose — re-derive with your own
regex at item time and record it; do not quote these. `tb_bandgap`'s raw carries **424** names whose visible
head includes `v(m.x1.x1.x1.xm1.msky130_fd_pr__nfet_01v8#body)` — unspeakable, so
the grammar is built from the **class-filtered** subset (B10), never from
`xschem raw list` raw.

---

## 3. Batch layout, sizing, and the three-batch split

### 3.1 This is three batches, not one

The honest shape, and the single most important sequencing decision in this file:

| batch | items | what it is worth on its own |
|---|---|---|
| **A — hardening + scaffolding** (§4) | 5 prep + 9 crew + 1 gate | Closes 0519, 0520, 0004 and 5 new issues. **Valuable with zero voice**: the command channel stops lying, and `select`/`setprop` stop silently hitting object 0. |
| **B — the typed path** (§5) | 12 crew + 1 gate | A working natural-language bar in the CIW. **Still zero microphone.** At the end of B, the mic is the only untested link in the system. That property is why the ordering exists. |
| **C — speech** (§6) | 10 crew | The microphone, the grammar, TTS, tier 1, deixis. Gated on A4 (does this machine capture audio at all?). |

Presenting it as one 30-item plan is the thing most likely to leave the tree
half-converted at item 8. **Batch A is independently justified — run it even if
voice is abandoned.**

### 3.2 Measured sizing anchors (from `doc/claude/results_batch/LEDGER.md`)

Do **not** use the "median 53 new checks" figure that circulated in the design
pass; it matches neither ledger in this tree. The real rows, per item — `checks |
sabotages | files`:

```
 1 read-restamp-0509            74 | 21 |  7      6 persistence-write-side       497 | 29 | 7
 2 results-tcl-resolver        139 | 34 | 11      7 results-select-dialog  [E]    58 | 65 | 10
 3 raw-select-subverb          215 | 38 | 10      8 waves-menu-cadence-gate [E]   42 | 50 | 9
 4 results-select-orchestrator 296 | 41 |  7      9 kill-second-rawinfo-parser   377 | 21 | 12
 5 rawbar-load-reexpress       532 | 27 |  8     10 calculator-consumes-sel [E]  789 | 38 | 8
```

⚠ **`checks` is a running total across the suites an item ran, not new work.**
Item 2's receipt reads *"65 new checks, total 139"*. Size a new item at **40–80
new checks**, and expect the ledger's `checks` column to be larger.

**Wall clock, measured from commit timestamps** in the results batch:
1h54, 3h09, 2h42, 2h41, 2h31, 3h26, 3h15, 2h25, 2h25 → **mean 2h43, median 2h41**,
one crew of 7 agents each. The calculator batch's own 90-minute planning estimate
was optimistic by ~1.8×. **Plan 2.5–3 h per crew item.** 31 crew items across the
three batches is **~80–95 h of wall clock** — an *estimate*, and it does not fit
any overnight window.

### 3.3 The batch directory (results_batch shape — it ran 10/10 with zero audit movement)

`doc/claude/voice_batch/` does not exist today. A1 creates:

```
PLAN.md            the item table + the briefs passed verbatim as args.brief   (driver)
CREW_BRIEF.md      landmines + non-negotiables; in EVERY item's load list      (driver)
DECISIONS.md       user + driver rulings, not re-openable by a crew            (driver)
LEDGER.md          one row per completed item — "no crew agent may edit"       (driver)
EYEBALL_SIGNOFF.md the look-debt sign-off sheet  (results_batch has one; the   (driver)
                   design pass omitted it while carrying 9 [E] items)
item_pipeline.js   copied from doc/claude/results_batch/                       (driver)
homeguard.sh       copied from doc/claude/results_batch/                       (driver)
utterances_v1.tsv  A0's deliverable, then FROZEN as the held-out eval set
recon/             the three recon reports + the adversarial spec passes
receipts/NN-<slug>.md   5 sections, <=120 lines                        (crew closer)
```

Verdict key, enforced in `item_pipeline.js:505-509`, not merely in prose:
`[x]` done and sabotage-verified · `[E]` done, pixels, **a human must look** ·
`[D]` deferred (**issue required**) · `[F]` failed (**issue required**).
A pixel payload can never be `[x]`.

### 3.4 Check-id bands, measured free this run

`grep -hoE '\bXX[0-9]+\b' tests/headless/*.tcl tests/headless/*.sh | wc -l` → 0
for each of: **`OVF` `VC` `HND` `VO` `VR` `VS` `UTT` `VX` `VP`**.
⚠ **`VT` is TAKEN** (14 uses) — do not use it. Re-derive every band at item time;
a doc-quoted band has been wrong twice in this repo.

All nine proposed suite filenames are free (`test_actionlog_overflow`,
`test_voice_channel`, `test_select_by_handle`, `test_voice_core`,
`test_voice_recipes`, `test_voice_slots`, `test_voice_utterances`,
`test_xvoiced`, `test_voice_asr`).

### 3.5 Non-negotiables for `CREW_BRIEF.md`

- **NOTHING may write under `$HOME` or `$::USER_CONF_DIR`** — not the suite, not a
  hand-written drive. This has cost the user real data twice
  (`~/.xschem/raw_history` truncated, unrecoverable; `~/.xschem/recent_files`
  wiped). Every suite invocation carries `HOME="$TMP"` **and** `--norecent`.
  `homeguard.sh snap/check` brackets every item.
- **`AUDIT_DISPLAY=:0` is forbidden in these batches, for any reason.** Record the
  debt: `owed.sh add suite <name> "<why>"`.
- **A pixel deliverable owes a human eye.** `owed.sh add look`, verdict `[E]`, and
  report *"suites green, please look"* — never "done". Only the user clears a look
  debt. **Current standing debt, measured this run: `owed.sh count` → 5 suite,
  24 look.** This plan adds ≥9 more; A1 must ask whether the queue should be
  drained first (§10/Q6).
- **Do NOT run `tools/review_gate/review_gate.sh`** — there is no human in a
  driver batch. The review is the three hostile lenses.
- **The audit is a DIFF, never a count.** Report by test NAME and STATUS, both
  directions. `full_audit.sh` is never clean. Lines reading `FAIL     | key …` are
  within-file detail, not test rows — a naive `grep -c '^FAIL'` over-counts.

### 3.6 The dependency graph, in one place

Prereqs live in each item's header; this is the same information as one edge list,
so a driver can schedule lanes without reading 900 lines. `X ← Y` means X waits on
Y. **Every batch-B item additionally waits on G-A and A2; every batch-C item
additionally waits on G-B and A4.**

```
A0 ←                     A5 ← A1                B1 ←                 C1  ← G-B
A1 ←                     A6 ← A5                B2 ← B1              C2  ← C1
A2 ← A0, A1              A7 ← A6                B3 ← B2              C3  ← C2, B10
A3 ←   (before A5)       A8 ← A7                B4 ← B3              C4  ← C2
A4 ←                     A9 ← A8                B5 ← B1, A0          C5  ← C2, B10
                         A10 ← A9               B6 ← B1              C6  ← C3, C5
                         A11 ← A6               B7 ← B6              C7  ← C4, C6
                         A12 ← A11              B8 ← B6              C8  ← B12, Q4
                         A13 ← A12              B9 ← B5              C9  ← B10, 0523
                         G-A ← A3, A5..A13      B10 ← B9, B8         C10 ← C8
                                                B11 ← B10
                                                B12 ← B9, B3
                                                G-B ← B1..B12
```

**Acyclic, and every edge points backwards in document order** — checked edge by
edge, both directions. **Five edges cross a batch boundary**, and those are the
ones a lane scheduler drops: `B5 ← A0` (the threshold cannot be guessed before the
user's utterances exist), `C3 ← B10`, `C5 ← B10`, `C9 ← B10` and `C8 ← B12`. One
more edge is not an item at all: `C9 ← issue 0523`, filed in **A1** and fixed in
§8 row 14 — C9 is its only consumer, so 0523 can stay open through all of A and B.

**Parallel lanes that actually exist**, once their prereqs are met: `A0 ∥ A1 ∥ A3
∥ A4`; `A7→A8→A9→A10` (`src/xschem.tcl`) **∥** `A11→A12→A13` (`src/scheduler.c`),
both after A6; `B3→B4` ∥ `B5→B9` ∥ `B6→{B7, B8}`. Everything else is a chain.
⚠ A6 and A7 are the one pair that looks parallel and is not — A7's own note says
serialise them.

**Two edges that are deliberately *absent*, and a crew agent will try to add
both:** B3 does **not** wait on B5 (it ships the call site and a stub translator —
see B3), and B8 does **not** wait on B9 (A2 rules case folding — see A2). Adding
either turns two parallel lanes into one chain and costs ~3 h each.


---

## 4. BATCH A — the blocking hardening

> **Nothing in Batch B or C may start until gate G-A passes.** Issues **0519**
> (the command channel kills the editor three ways and every one returns
> success), **0520** (select-by-handle silently hits object 0) and **0004** (the
> listener binds every interface) are the whole of it. 0519 and 0520 are the
> authority for A5–A13; where this file and an issue disagree, **the issue wins**.
> Both are now tracked (committed `ab33cee6`) — when this pass began they were
> untracked and `git clean -fd` would have deleted the authority.

Lane discipline: **A5–A9 and A11–A13 contend for one build tree.** `./configure &&
make` regenerates the gitignored `src/Makefile`; two lanes cannot `make` at once,
and CLAUDE.md forbids `make` while suites run. Either serialise, or give the Tcl
lane its own worktree.

---

### A0 — 30 utterances in the user's own words · `[x]` · **do this first**
- **What:** ask the user for ~30 things they would say, in *their* words, for
  chores they actually do. Zero repo code. **This is the only step that can still
  change the architecture, and it costs nothing.**
- **Files:** `doc/claude/voice_batch/utterances_v1.tsv` (~30 rows:
  `utterance TAB intended-effect TAB chore-class TAB slots-present`) +
  `recon/matcher_baseline.txt` (~40 lines). *Estimate.*
- **Prereq:** none.
- **Done when:** `wc -l doc/claude/voice_batch/utterances_v1.tsv` ≥ 30, and
  `matcher_baseline.txt` has one row per utterance carrying the live
  `fuzzy_subseq_score` top hit (`src/xschem.tcl:9266`, against the 166-row
  `action_table`) plus a hand verdict, ending in `HIT n MISS n WRONGHIT n` whose
  three numbers sum to the row count.
- **Test:** none — a measurement, recorded in the receipt. The design pass's own
  30 *guesses* scored 16 miss / 5 confidently wrong, 3 of those wrong hits being
  mutators (`"move this"` → `xschem break_wires 1`). The user's set replaces that
  number and **sets the pass threshold for B5 and B12** — do not fix a threshold
  before the data exists.
- **Look debt:** none (the user is the source here, not the audience).
- **Blocks:** B5 table size, B9 slot list, B12 eval set.

### A1 — rulings, scaffold, SEVEN issues, and the three struck sentences · `[x]` · ⟂A0
- **What:** create `doc/claude/voice_batch/` per §3.3; write `DECISIONS.md`;
  strike-annotate `…plan.md:17-18`, `:18-20`, `:266-267` in place; file the issues.
- **`DECISIONS.md` must rule on:** the architecture doc's §10 Q1–Q7; **AM-1/AM-2/AM-3**;
  and the eight new questions in §10 of this file.
- **Issues to file (next free = 0521):**
  - **0521** — `ase::open_state` opens a `.sym` as a state file in a flat library
    and returns 1. `src/ase.tcl:3690-3697` never checks the resolved datafile's
    extension; `cellview_resolve` (`src/library_defs.tcl:289`) maps any
    non-`schematic` view to `<cell>.sym`. Measured: `xschem cellview_path
    examples/rlc ngspice_state1` → `…/examples/rlc.sym`, `ase::open_state examples
    rlc ngspice_state1` → **1**, session bound to the `.sym`, state dict blank —
    while `ase::ui::state_views` correctly returns `{}` (it filters `*.state`,
    `src/ase_window.tcl:4045`).
  - **0522** — the socket read loop `while {1} {if {[gets $sock line] < 0} break …}`
    (`src/xschem.tcl:5854-5860`) runs on a non-blocking channel (`-blocking 0`,
    `:5926`) and checks neither `eof` nor `fblocked`. Two measured symptoms, one
    root: a line split by ≥50 ms is **silently discarded** behind an empty
    success-shaped reply (⚠ the fragment is *not* executed — `gets` does not
    consume an incomplete line; the design pass's "executes the fragment" is
    wrong); and **a multi-line send with no trailing newline drops every line
    after the first and returns a plausible answer from an earlier line** —
    `"xschem get version\nxschem get instances"` without the final `\n` replied
    `3.4.8RC`, with it replied `117`. That second symptom is exactly the shape of
    the multi-line wrapper C1 mandates (`…plan.md` §3.3, *The wire format*,
    `:297`+ — **not** this file's §3.3), and it is in neither 0519 nor the recon.
  - **0523** — `ui_state` is **0** between button-press and first motion:
    `STARTSELECT` is set in the *Motion* handler behind a 2 px threshold
    (`src/callback.c:7045-7060`), not in button-press. No signal in the tree
    reports "a drag is in flight". **Blocks C9 (deixis).**
  - **0524** — `wviewer::plot_signals` (`src/wave_viewer.tcl:7302`) leaves the
    global context on the viewer window (measured `.drw`/`tb_bandgap.sch` →
    `.x1.drw`/`untitled.sch`), unlike its sibling `wviewer::signal_list` (`:2337`)
    which borrows and restores via `enter_ctx`/`leave_ctx` (`:1404`/`:1475`). Same
    shape as issue 0173, "a viewer switch is a LOAN".
  - **0525** — feature request: no verification-tool class exists (evidence in §2).
    **"run LVS" is not a v1 intent and this issue is why.**
  - **0526** — `ciw_exec`'s `rename ::puts ::ciw_saved_puts` pair
    (`src/ciw.tcl:247`, restored `:255-256`) is non-reentrant, and it is **worse
    than 0519-A**. Measured twice on `:99`: a nested `ciw_exec` fails with *can't
    rename to "::ciw_saved_puts": command already exists*; the background error
    opens **`.bgerrorDialog`, which takes a modal grab**, and the outer socket
    command **never returns** (8 s and 15 s timeouts); `::ciw_saved_puts` is left
    defined, so **every later `ciw_exec` fails identically — the CIW entry is dead
    for the session**; in one run the process then died with 0 bytes on stdout and
    stderr. `doc/claude/specs/ciw_puts_capture.md` and `test_ciw_puts_capture.tcl`
    contain **zero** hits for `reentran|nested|recursi`. This is a genuinely
    cross-source failure, in the proc AM-2 makes the primary voice surface.
  - **0527** — `ase::ui::auto_plot` (`src/ase_window.tcl:4932`) is reachable from
    no menu, key or button; its only caller is `:5048`.
- **Done when:** `ls doc/claude/voice_batch/` shows the nine scaffold entries;
  `ls doc/claude/issues/052[1-7]*.md | wc -l` → **7**; `git ls-files
  doc/claude/issues/052[1-7]* | wc -l` → **7** (D6: commit them, or `git clean -fd`
  deletes the authority); `grep -c 'TBD\|to be decided'
  doc/claude/voice_batch/DECISIONS.md` → **0**; and all three struck claims are
  annotated in `voice_control_natural_language_plan.md` —
  `grep -c 'SUPERSEDED'` → **≥2** and `grep -cE 'AM-1|AM-3'` → **≥3**, one
  annotation naming its amendment per claim.
  ⚠ **Two of the three live in the same paragraph** (`:17-20`, the §0 Verdict:
  AM-3 strikes the `xvoiced`-owns sentence at `:17-18`, AM-1 strikes the
  emitter-template sentence at `:18-20`, and they **share line 18**). Strike the
  sentences inline and put **two** annotation blocks after the paragraph, one per
  amendment — do not merge them into one, and do not renumber the paragraph.
- **Test:** none (docs). **Look debt:** none.

### A2 — the spec · `[x]` · prereq A0, A1 · **size this as a job, not a row**
- **What:** `doc/claude/specs/voice_control.md`. There are **95** `.md` specs today
  and **none is voice** (`ls doc/claude/specs/*.md | wc -l` → 95;
  `ls doc/claude/specs | grep -ci voice` → 0). **No item brief may cite an
  R-number before this lands** — every receipt, ruling and brief in the house
  format cites R-numbers.
- **Files:** one new doc. `doc/claude/specs/results_selection.md` is 966 lines /
  19 sections; expect the same. *Estimate ~700–950 lines.*
- **Numbering:** R100 channel · R200 recipes · R300 resolver · R400 broker+safety ·
  R500 typed path & CIW · R600 speech · R700 tier 1 · R800 corpus.
- **Requirements that must appear verbatim:** *"the model never emits an
  identifier — it emits a verbatim span of the transcript"*; *"voice permanently
  excludes fluid editing"*; *"conflict handling between command sources is
  deferred by user ruling — do not add a lock"*; *"schematic Y grows downward"*
  (`Y_TO_SCREEN`, `src/xschem.h:599`); the **margin gate** (§10/Q1); the **partial
  failure contract** (B6); the **freeze budget** (B10); and the **case-fold
  ruling** — the state spells the node `VBG` and the raw spells it `v(vbg)` (both
  measured), so the spec must say which spelling the resolver normalises to and
  which one a confirmation speaks. **This ruling lives here, in A2, so that B8 and
  B9 stay parallel**; without it B8 blocks on B9's ladder.
- **Two adversarial verification passes are mandatory.** House record: a prior
  spec's draft 1 carried 114 errors and its rewrite 64 more. Each pass re-derives
  every census itself and never ships an agent's number.
- **Done when:** `grep -cE '^\*\*R[0-9]{3}' doc/claude/specs/voice_control.md` ≥ 80;
  two pass reports exist under `doc/claude/voice_batch/recon/`, **each naming ≥1
  defect it found and where it was fixed**; and
  `grep -cE 'unverified|file:line missing|TBD' doc/claude/specs/voice_control.md`
  → **0**.
- **Look debt:** none.

### A3 — pin the pre-batch audit baseline · `[x]` · ⟂A0–A2
- **What:** one `full_audit.sh` on `:99`, written to
  `doc/claude/voice_batch/baseline_<date>_<sha>.txt`, plus a `BASELINE_SUMMARY`
  paragraph naming the **exact red list** by test name. The results batch pinned
  `baseline_2026-08-19_226302f9.txt` (331 pass / 15 fail / 0 / 0 of 346, 15 reds
  named); there are now **349** `test_*.tcl` and that file is stale for this batch.
  ⚠ `doc/claude/batch_F/baseline_status.txt` is **VOID** — pre-rework scorer; never
  diff or average against it.
- **Prereq:** none, but it **must precede A5** — G-A diffs against it and nothing
  else captures it.
- **Done when:** the file exists, `BASELINE` and `BASELINE_SUMMARY` are set as two
  constants in `voice_batch/item_pipeline.js` (**they roll forward together**, and
  the roll is recorded in the row that caused it), and the summary's pass+fail+
  crash+skip equals the total.
- **Cost:** ~40 min (a stashed A/B pair is ~80 min). **Never** run `full_audit.sh`
  with `env -u DISPLAY` (~62 bogus CRASHes).
- **Look debt:** none.

### A4 — can this machine hear at all? · `[E]` · ⟂A0–A3 · **run in week 1**
- **What:** a 10-second human check. **Nothing in Batch C is worth starting until
  this passes**, and the design pass had it at item 20.
- **Evidence it is needed:** the speech recon measured **7 of 8 WSLg captures
  failing with `Resource temporarily unavailable`** (the pulse log shows the RDP
  source connecting each time — a startup race, not a missing device), and the
  Windows side reporting `AudioLevel` **flat 0** for 5 s on the `Logi Webcam C920e`
  while microphone privacy reads `Allow` at HKCU, HKLM *and* `NonPackaged`. Two
  independent stacks agree the default capture endpoint is delivering ~nothing.
  Nobody has separated "muted / wrong device" from "quiet room".
- **Done when:** with the user speaking, a `System.Speech` `AudioLevel` poll from a
  WSL-spawned `powershell.exe` reports a non-zero max, **and** one
  `SetInputToDefaultAudioDevice()` recognition against a 3-phrase grammar returns
  a result. Record the device that worked.
- **Look/listen debt:** `owed.sh add look "mic capture check" "only the user can
  speak into it"`. **Verdict `[E]`.**
- **⚠ Housekeeping, from the recon:** a stray `mic.wav` from an earlier run was
  found in the session scratchpad and deleted. **Every capture is `shred -u`'d
  immediately**; put that in `CREW_BRIEF.md`.

---

### A5 — rule the `vsnprintf` portability question · `[x]` · prereq A1
- **What:** a **ruling**, written into `DECISIONS.md`. The design pass called
  0519-B "4 lines → 1"; it is not.
- **The measurement:** `HAS_SNPRINTF` **is never defined anywhere in this tree** —
  `grep -rn HAS_SNPRINTF src/ scconfig/ Makefile.conf.in` finds only *uses*
  (`src/util.c:505`, `:588`, `:734`, `src/save.c:2683`, `src/draw.c:7633`,
  `src/scheduler.c:5862`). So `src/util.c:508` `vsprintf(buf, fmt, args)` is the
  **live** branch, and the abort is glibc's `*** buffer overflow detected ***`
  FORTIFY check. The tree deliberately does not assume C99 — `src/util.c:611` is a
  hand-rolled `my_snprintf` for exactly that case — and **there is no
  `my_vsnprintf`** (`src/util.h:39` is the variadic form only).
- **The three options, one must be chosen:** (a) add `my_vsnprintf` and refactor
  the ~100-line hand-rolled formatter; (b) require C99 `vsnprintf` — a project
  ruling against CLAUDE.md's "C89 throughout"; (c) bound the input at the call
  site and leave `log_action` alone.
- **⚠ Trap:** `src/scheduler.c:5863` uses `HAS_SNPRINTF` as a **string**
  (`"HAS_SNPRINTF=%s\n", HAS_SNPRINTF`), so a bare `-DHAS_SNPRINTF` will not
  compile. Any option that defines the macro must fix that line too.
- **Done when:** `DECISIONS.md` names one option, with the compile consequence for
  `src/scheduler.c:5863` stated.
- **Look debt:** none.

### A6 — 0519-B: the 4 KB `log_action` abort · `[x]` · prereq A5 · **land this first among the code items**
- **Why first:** it is the only one of 0519's three that reaches an xschem with
  **no socket at all**, and by 0519's own measurement that is most of them.
- **Files:** `src/util.c:505-509` per A5's ruling (1–4 lines, or ~120 if option
  (a)); new `tests/headless/test_actionlog_overflow.tcl` (~200 lines, band
  `OVF1..`). **Needs `./configure && make`.** *Estimate.*
- **Done when** (RED today — measured `rc=134`, `*** buffer overflow detected ***`):
  ```sh
  timeout 30 ./src/xschem --nogui --pipe -q --logdir $T --script $T/ovf.tcl; echo rc=$?
  #  ovf.tcl:  if {[xschem get actionlog_filename] eq {}} { puts FATAL; exit 3 }   <- the trap
  #            xschem set header_text [string repeat L 4200]     (src/scheduler.c:12195)
  #            exit 0
  ```
  prints **`rc=0`**. Today it prints `rc=134`.
- **Test:** the suite `exec`s children — it may **not** arm the payload in its own
  process, because the failure is `SIGABRT`. Boundary legs at 4072 / 4085 / 4086 /
  4095 / 4096 (the `# failed: ` prefix moves the boundary). The safe-side leg must
  assert the **full line is present in the log file**, byte for byte, so a fix
  that truncates everything to nothing fails. GUI leg on `:99`, `has_x`-gated:
  open `update_schematic_header`, insert 4200 chars into `.dialog.textinput`,
  `invoke` OK, require survival.
- **Sabotage:** restore `vsprintf` → the over-length legs go red and the
  under-length legs **do not move**. `tests/headless/test_stdin_tcp_log.tcl` (163
  lines, the only existing socket test) stays green throughout — that difference
  is the proof the new checks are not redundant with it.
- **Look debt:** none.

### A7 — 0519-A: the re-entrancy wedge · `[x]` · prereq A6 (build lane) · ⟂ nothing
- **What:** `fileevent $sock readable {}` immediately before the `uplevel` at
  `src/xschem.tcl:5865`, **plus** a depth counter in `xschem_server` (`:5923`) so a
  *second* connection cannot be serviced while an evaluation is in flight. A fix
  that only disarms the current socket passes the same-connection leg and **fails
  the second-connection leg** — they are two bugs.
- **⚠ This is not the lock AM-3 forbids, and the receipt must say why.** The depth
  counter grants **no client any exclusivity and no client any priority**: it
  defers a second connection's `fileevent` until the in-flight evaluation returns,
  which is what the Tk event loop already does today — measured, a client arriving
  300 ms into a 1500 ms command **waited 1203.6 ms and got the correct answer**.
  Nothing is refused, nothing is owned, no source outranks another, and the
  counter is blind to which source a connection carries. It exists because
  **re-entering the interpreter mid-evaluation destroys the channel**, not to
  arbitrate between peers. A patch that instead *refuses* the second connection,
  or that reserves the channel for one client, is out of scope and contradicts
  §9 — reject it in review.
- **Files:** `src/xschem.tcl` ~20 lines; new `tests/headless/test_voice_channel.tcl`
  (~200 lines, band `VC1..`). **No rebuild** (`src/xschem.tcl` is sourced at
  runtime from `XSCHEM_SHAREDIR`), but ⚠ A6’s suite drives `xschem set
  header_text` through the action log and A7 changes the *other* action-log writer
  (`src/xschem.tcl:5874-5883`). **Serialise A6 and A7; do not run them in parallel.**
- **Done when**, all red today:
  ```
  send `set ::w 0; incr ::w; update; set ::w`  -> reply 1  AND the NEXT command still answers
  send a verb that raises alert_               -> channel survives the box being destroyed
  A blocks in alert_, B sends an ordinary query -> BOTH survive; neither reply is empty
  ```
  Probe E reproduced exactly this run: nested served in 10.6 ms, outer never
  returned, 3/3 post-probes timed out, process alive, stdout 0 B.
- **Test:** every leg runs in a **spawned child** — a wedge in the suite's own
  process ends the suite. ⚠ **Assert that the channel is dead, never a frame
  count**: the re-entry depth (~250 on this box) is not stable even here.
- **Sabotage:** drop the `fileevent` disarm → same-connection leg red,
  second-connection leg still red (two disjoint red sets).
- **Look debt:** none.

### A8 — 0519-C: delete the `redef_puts` rename pair · `[x]` · prereq A7
- **What:** delete `redef_puts` (`src/xschem.tcl:5863`) and the **unconditional**
  restore pair at `:5866-5867`. `redef_puts` (`src/xschem.tcl:11612`) is guarded by
  `if ![llength [info command ::tcl::puts]]`, so a nested call no-ops the rename
  but its tail still executes the restore — deleting the real `puts` and
  un-defining `::tcl::puts` out from under the outer call.
- **⚠ This is a behaviour change the design pass denied.** Measured: `puts
  hello_from_socket` over the socket replies `''` and prints nothing —
  `redef_puts` **swallows** it. After the fix that output goes to xschem's stdout.
  **State it as a decision in the receipt**, do not smuggle it.
- **Files:** `src/xschem.tcl` ~6 lines; `test_voice_channel.tcl` +60.
- **Done when:** after a round trip, `info commands ::puts` and `info commands
  ::tcl::puts` both still report their pre-call state; a socket `puts foo` lands
  on xschem's stdout and the reply is unchanged.
- **Sabotage:** restore the pair → the `puts` legs red, A7's wedge legs green.
- **Look debt:** none.

### A9 — 0522: framing · `[x]` · prereq A8
- **What:** check `eof`/`fblocked` in the read loop (`src/xschem.tcl:5854-5860`)
  and **refuse an incomplete line explicitly** instead of replying empty. Covers
  both symptoms: the discarded fragment and the truncated multi-line send.
- **Files:** `src/xschem.tcl` ~12 lines; `test_voice_channel.tcl` +60.
- **Done when:**
  ```
  line split at byte 10, 300 ms gap        -> an explicit refusal string, NOT an empty reply
  "get version\nget instances" no final \n -> a refusal, NOT '3.4.8RC'
  same WITH the final \n                   -> '117'   (unchanged)
  ```
- **⚠ Do not write a 0-gap fragmented-send leg from the recon transcript.** The
  recon recorded `split at byte 10, 0 ms gap -> '3.4.8RC'`; the critic pass
  measured `Connection reset by peer` on the identical shape. It is a race and a
  test written to either transcript will flake. Test the ≥50 ms shapes only.
- **Sabotage:** drop the `eof` check → the split legs red, the whole-line legs
  green.
- **Look debt:** none.

### A10 — 0004: bind the listener to loopback · `[x]` · prereq A9
- **Files:** `src/xschem.tcl:18042` → `socket -server xschem_server -myaddr
  $xschem_listen_addr $xschem_listen_port`; `set_ne xschem_listen_addr 127.0.0.1`
  beside `set_ne xschem_listen_port {}` at `:18637`; **add `xschem_listen_addr` to
  the variable registry list at `src/xschem.tcl:16191`** (its sibling is
  there; a variable that is not listed is not handled like one); `src/xschemrc:573` gains
  the sibling note; `doc/xschem_man/xschem_remote.html` one sentence. **Apply the
  same `-myaddr` to the bespice listener** (`src/xschem.tcl:18069`) — it does not
  evaluate what it receives, so 0519 does not apply to it, but 0004 does.
  `test_voice_channel.tcl` +40.
- **Done when:** `setup_tcp_xschem 0` returns port P and `ss -ltnH "sport = :$P"`
  shows `127.0.0.1:P` with **no** `0.0.0.0` and **no** `[::]` row (both are
  present today); clients on `127.0.0.1` and `localhost` still work; the escape
  hatch `set xschem_listen_addr 0.0.0.0` restores the old rows;
  `grep -c xschem_listen_addr src/xschem.tcl` ≥ 3.
- **Compatibility cost, to be stated in the receipt:** a client that connects to
  `::1` explicitly gets `Connection refused`. That is the whole cost.
- **Sabotage:** drop `-myaddr` → the `0.0.0.0` assertion red, connectivity green.
- **Look debt:** none.

### A11 — 0520(a) part 1: extract the selector resolver, no behaviour change · `[x]` · prereq A6
- **What:** lift `src/scheduler.c:9031-9060` (the `object` verb's selector block)
  into `static int object_index_from_selector(int type, const char *sel, int
  *layer_out)`, forward-declared beside `object_type_from_name` /
  `object_descriptor` (`src/scheduler.c:214-215`), and call it from the `object`
  arm. **Nothing else changes.**
- **Files:** `src/scheduler.c` ~40 lines. Needs `make`. *Estimate.*
- **Done when:** `full_audit.sh` diffs to **0 status changes** against A3's
  baseline, and `tests/stable_handles/` is unchanged. The **749** existing
  `xschem select` call sites under `tests/` (`grep -rn 'xschem select ' tests/ |
  wc -l` → 749; the design pass said 746, which is also not the sum of its own
  572+159+18) are untouched by construction.
- **Sabotage:** make the extracted function return -1 unconditionally → the
  `object` verb's rows go red across all seven types.
- **Look debt:** none.

### A12 — 0520(a) part 2: the eight `select` arms + four widenings · `[x]` · prereq A11
- **What:** call the resolver from the 8 `select` arms (`src/scheduler.c:11620-11703`).
  **A verbatim lift regresses on day one** — four widenings must happen *as* it
  moves:
  1. bare all-digit → array index **for every type**, bounds-checked as the `#` arm
     does (`:9047-9056`). Today a bare index reaches `get_instance()` only for
     `ELEMENT` (`:9059`).
  2. bare name → instance name, `ELEMENT` only, as today.
  3. `rect`/`line`/`poly`/`arc` keep their positional `<layer> <index>` path and
     reach the resolver only when `argv[3]` carries a sigil — which makes the
     arity guard at **`src/scheduler.c:11600-11611`** selector-aware. **This is the
     only fiddly part.**
  4. fix the `#` arm's own `atoi` (`:9044-9045`) while moving it, using
     `isonlydigit()` (`src/token.c:4162-4181`) — the test `get_text()` already uses
     (`src/scheduler.c:158`).
- **Files:** `src/scheduler.c` ~40 lines; new `tests/headless/test_select_by_handle.tcl`
  (~340 lines, band `HND1..`). *Estimate.*
- **Done when**, red today (measured: `select wire @41` returns **1** and selects
  **wire 0**; `select wire 1e2` → wire **1**): for **all seven** drawable types,
  `xschem object <type> #<index>` → take `id` → `xschem select <type> @<id>`
  returns 1 **and** `lindex [xschem selection] 0` names that same index; and
  `full_audit.sh` + `tests/stable_handles/` show 0 status changes.
- **Three assertions that must not be weakened:** start from `unselect_all` and
  assert the selection is **empty** after a failing select, not merely "not index
  0"; assert the **neighbour's** attribute is unchanged, not just the target's;
  derive the type list from `xschem objects`, **not** from a hand-written seven, so
  an eighth arm cannot skip the bound.
- **⚠ Stable ids are session counters.** Every check derives its handle from a live
  `xschem object … #<index>` **after its own load**; a hardcoded `@41` goes red the
  first time a fixture is loaded twice in one process.
- **Sabotage:** revert **one** arm to `atoi(argv[3])` → only that arm's rows go
  red. Two disjoint red sets are the proof.
- **Look debt:** none.

### A13 — 0520(a)+(c): the property verbs · `[x]` · prereq A12 · **do this or the feature is half-present**
- **Files:** `src/scheduler.c` ~40 lines — the 8 `setprop`/`getprop` arms
  (`:12756-12757`, `:12847`, `:12910`, `:13003-13004`, `:13043-13044`,
  `:13087-13088`, `:5626-5627`, `:5663`); `test_select_by_handle.tcl` +120.
- **Plus 0520(c), narrow form only:** a leading `@` or `#` that does not resolve
  becomes `TCL_ERROR`; a well-formed but absent reference keeps returning `"0"`,
  preserving `select_inst`'s value test (`src/xschem.tcl:5972`) and reviving
  `hi_descend_current`'s `catch` (`:8215`).
- **⚠ Rule the strictness separately, do not smuggle it.** Measured, these succeed
  today and would newly error under `isonlydigit()`: `select wire 40x` → 40,
  `40.9` → 40, `1e2` → **1**. Nothing under `tests/` or `src/*.tcl` passes such a
  string, so tightening is *available* — it is a second ruling.
- **Done when:** `xschem setprop wire @<id> lab ZZZ` does not touch wire 0 and the
  neighbour is unchanged; **the sigil-free leg** `xschem setprop wire OUTI lab ZAP`
  — a plain net-name typo, the mistake a person actually makes, which today
  returns rc 0 and **renames wire 0** (measured) — mutates nothing;
  `getprop text @<id>` and `setprop text @<id>` agree.
- **Sabotage:** as A12, per arm. **Look debt:** none.

### G-A — the blocking gate
One `full_audit.sh` on `:99`, **diffed against A3's pinned baseline by test NAME
and STATUS, both directions**, every change explained (red→green counts too).
Expected: **0 status changes**, plus exactly the declared new rows
(`test_actionlog_overflow`, `test_voice_channel`, `test_select_by_handle`)
pre-listed in the ledger's `## Suites this batch has added` table. Roll `BASELINE`
and `BASELINE_SUMMARY` together and record the roll.

---

## 5. BATCH B — the typed path (no microphone)

Prereq for every item: **G-A** and **A2**.

### B1 — `src/voice.tcl` core · `[x]`
- **What:** `voice::echo {msg ?tag?}` structurally copied from `ase::echo`
  (`src/ase.tcl:138`) — fans one message to the CIW pane *and* the action log,
  catch-guarded, correct headless, tagged `input`/`result`/`error`/`note` the way
  `ciw_echo` (`src/ciw.tcl:120`) already supports. **Do not tee inside `ciw_echo`**
  — that double-logs every action line. Plus `voice::log`, one JSONL record per
  utterance (`audio_sha, transcript, asr_conf, proposal, resolved, emitted, rc,
  fingerprint_before/after, verdict`), and `voice::utter {text}` returning a dict
  that answers `not_understood` for everything at this item.
- **Files:** new `src/voice.tcl` ~180 lines; `src/Makefile.in:23` +1 word;
  `src/xschem.tcl` +1 `source` line, placed **after** `wave_viewer.tcl` (`:16954`)
  and `results.tcl` (`:16962`) and **before** `ciw.tcl` (`:17000`), with the
  ordering reason in the comment. New `tests/headless/test_voice_core.tcl` (~220
  lines, band `VO1..`). *Estimate.*
- **Done when:** `grep -c ' voice.tcl' src/Makefile.in` → 1 **and** `grep -c
  'install -f voice.tcl' src/Makefile` → 1 **and** the `voice::echo` legs pass
  under both `--nogui` and X. **A new `.tcl` that is sourced but not installed is
  a known failure class here** — pin both halves. Run `./configure` after the
  `Makefile.in` edit and record in the receipt that `src/Makefile` is generated,
  untracked and not committed.
- **⚠ Budget the ripple:** the `source` line shifts every later `src/xschem.tcl`
  line number. A prior 8-line insert staled 14 citations across six documents.
  **Cite by symbol; re-grep before quoting.**
- **Sabotage:** remove the word from `Makefile.in` and re-`configure` → the install
  check red, the source check green.
- **Look debt:** none (nothing user-visible yet).

### B2 — 0526: make `ciw_exec`'s puts capture re-entrant · `[x]` · prereq B1
- **What:** fix the rename pair at `src/ciw.tcl:247`/`:255-256` before anything
  builds on that proc. Guard the rename on `info commands ::ciw_saved_puts`, or
  depth-count, and make the restore unconditional-but-correct. Extend
  `doc/claude/specs/ciw_puts_capture.md` — it has **zero** occurrences of
  `reentran|nested|recursi` today.
- **Files:** `src/ciw.tcl` ~15 lines; `tests/headless/test_ciw_puts_capture.tcl`
  +60; the spec +1 section.
- **Done when:** driving `ciw_exec` from inside a command that is itself running
  under `ciw_exec` (`.ciw.c.e insert` + `ciw_exec` from a socket command) leaves
  `info commands ::ciw_saved_puts` **empty**, no `.bgerrorDialog` appears
  (`grab current` stays `{}`), the outer command **returns**, and a subsequent
  `expr 2+2` in the CIW still works. All four are red today.
- **Sabotage:** restore the bare rename → all four legs red together; the
  non-nested capture legs stay green.
- **Look debt:** none.

### B3 — the CIW utterance/command split · `[E]` · prereq B2
- **What:** `ciw_interactive_load` (`src/ciw.tcl:219`, applied `:230`) is the
  precedent — a pure string→string rewrite before the eval. But **history (`:233`)
  and the pane echo (`:237`) both consume the rewritten `$cmd`**, so a translator
  dropped at `:230` shows and remembers the *generated Tcl*, not the user's words.
  **Split the echo/history/log triple into "what was said" vs "what ran".** That
  split rewrites `ciw_log_outcome`'s contract (`src/ciw.tcl:274`) and is the only
  non-trivial edit in Batch B's front half.
- **Files:** `src/ciw.tcl` ~25 lines; `tests/headless/full_audit.sh:84`
  `logdir_tests` +1 word (the CIW does not exist under `--nolog`,
  `src/xschem.tcl:18930`, so the suite needs `--logdir`);
  `test_voice_core.tcl` +160.
- **Done when:** a **byte baseline** captured *before* the edit (the pane text, the
  history list and the `Xschem.log` lines for `xschem get version`, `expr {6*7}`,
  a deliberate Tcl error, and `xschem load <f>`) is reproduced **byte-identical**
  after it, with `voice::translate` absent — including the `-gui` injection at
  `:230`. Capturing that baseline is part of this item; nothing else captures it.
  With a one-row table installed, the pane and history hold **the phrase** and
  `Xschem.log` holds **the generated command**.
- **⚠ This item ships the call site and the guard, not the table.** The real
  `voice::translate` and `src/voice_intents.tsv` are B5's, and B3 does **not**
  depend on B5: the "one-row table" above is a **stub `::voice::translate`
  defined inside `test_voice_core.tcl`**, which is also what makes the
  absent-translator baseline leg meaningful. A crew agent who waits for B5 has
  serialised two items that were written to run in parallel.
- **Sabotage:** delete the split → the "history holds the phrase" check red while
  everything else stays green.
- **Look debt:** `owed.sh add look "CIW utterance echo split" "the pane must read
  like a conversation, not like generated Tcl"`. **Verdict `[E]`.**

### B4 — the shadow guard · `[x]` · prereq B3
- **What:** `voice::translate` is consulted **first**, but may match only the
  closed Tier-0 table, and **must refuse any line whose first word is an existing
  Tcl command (`info commands`) or one of the 322 verbs in
  `src/xschem_subcommands.txt`** (322 lines, measured; loaded by
  `ciw_load_subcommands`, `src/ciw.tcl:295`). It is then impossible for the NL
  layer to shadow a real command. Guard the call with `if {[info procs
  ::voice::translate] ne {}}` so a partially installed tree still has a working
  CIW.
- **Files:** `src/ciw.tcl` ~10 lines; `src/voice.tcl` +40; suite +60.
- **Done when:** typing `xschem` — a real command that is also a plausible intent
  word — is refused by the guard and runs as Tcl; typing `set` likewise; a table
  row that collides with a verb name is **rejected at load time** with a named
  error, not silently shadowed.
- **Sabotage:** delete the guard → the `xschem`-as-utterance check red.
- **Look debt:** none.

### B5 — the intent table and the Tier-0 matcher · `[x]` · prereq B1, A0 · ⟂B3/B4
- **Files:** new `src/voice_intents.tsv` (~70 rows: `intent_id TAB phrase TAB
  recipe TAB tier`), `src/Makefile.in` +1 word, `src/voice.tcl` +~180; suite +200.
  **Zero-slot intents only.** *Estimate.*
- **Exact-match-before-fuzzy is load-bearing, not a nicety.** Measured on the live
  matcher: `"undo"` → `edit.undo` ✓ (score 1897) · `"undo it"` →
  `select.same_net_by_label` ✗ (1289) · `"undo the last thing"` → −1. **It is not
  monotone in politeness** — the most natural English pronoun flips a working
  command to a wrong action, silently.
- **Done when:** `voice::utter` scores A0's set at the threshold **A0 set** (not a
  threshold guessed before the data existed), with **0 wrong-hits**, and every
  miss returns an explicit `not_understood` listing the near-misses — never
  silence.
- **Sabotage:** delete one alias row → exactly that utterance's check red and no
  other. Reverse the exact/fuzzy order → the politeness legs red.
- **Look debt:** none.

### B6 — the recipe layer: bracket + failure contract · `[E]` · prereq B1 · ⟂B3–B5
- **What:** new `src/voice_recipes.tcl`, namespace **`recipe::`** (AM-1). This item
  ships **no chore recipe** — it ships the two things every recipe needs, and one
  trivial recipe to prove them.
  - **The context-restore bracket** (issue 0524, same shape as 0173). Copy
    `wviewer::enter_ctx`/`leave_ctx` (`src/wave_viewer.tcl:1404`/`:1475`,
    call-site pattern at `:2350-2357`). Every recipe: save
    `[xschem get current_win_path]`, do the work, `xschem new_schematic switch
    $home`, **and assert the switch landed** — a raised semaphore silently no-ops
    it (`src/ase_window.tcl:5040-5049`).
  - **The partial-failure contract:** every recipe returns
    `{ok done_steps failed_step reason}`. Required because `ase::run` throws
    mid-way, `ase::netlist` **deletes the artifact before netlisting**
    (`src/ase.tcl:1692`), and V-06 is a 5-step ladder — nothing today says what
    "step 3 of 5 failed" leaves behind or how it is spoken.
  - **A per-recipe freeze budget.** Tcl is single-threaded and the socket handler
    shares the Tk loop: measured, a client sent `xschem get version` 300 ms into a
    1500 ms command and was served at **1203.6 ms** — that is the editor frozen,
    keyboard and mouse included. Every recipe declares a budget; a step that
    exceeds it must be async (callback) or announced.
- **Files:** new `src/voice_recipes.tcl` ~180 lines, 2 build lines; new
  `tests/headless/test_voice_recipes.tcl` (~200 lines, band `VR1..`). *Estimate.*
- **Done when:** the trivial recipe's context is **identical before and after**
  (`current_win_path` **and** `schname`) including on every failure path; a recipe
  whose step 2 throws returns `{ok 0 done_steps 1 failed_step 2 reason …}` and
  restores; a recipe that exceeds its declared budget fails a check.
- **Sabotage:** delete the restore → the context check red; delete the `catch` →
  the contract check red.
- **Look debt:** `owed.sh add look "recipe context restore" "the tests can see the
  path matched; only you can see the screen went back where you were"`. **`[E]`.**

### B7 — `recipe::sim_run` (V-01a + V-01b) · `[E]` · prereq B6
- **What:** both paths, because the user's example is both.
  - **V-01a:** `ase::session_for_current` (`src/ase.tcl:3787`, hierarchy-aware —
    issue 0168) → `ase::ui::design_path` / `design_window` (`src/ase_window.tcl:4674`
    / `:4737`) to make the design current → `ase::run [ase::session_state $key]
    [list recipe::_sim_done $key]` (`src/ase.tcl:1706`). **Use the callback, never
    `ase::wait`** (`src/ase.tcl:1906` — its `xschem set semaphore ±1` bracket at
    `:1909-1911` is the one place serialisation is asserted today, and using it
    would introduce the lock AM-3 forbids).
  - **V-01b:** if `$::sim(...)` is unset — ⚠ **measured: `sim(tool_list)`,
    `sim(spice,default)` and `sim(spice,0,cmd)` are all UNSET in a bare `--nogui`
    session until `set_sim_defaults` (`src/xschem.tcl:4293`) runs** — call it,
    then assert a **batch** profile is selected, then `xschem netlist`, then
    `simulate` (`src/xschem.tcl:6112`). Refuse with an offer if the selected
    profile is interactive.
- **Files:** `src/voice_recipes.tcl` +160; `test_voice_recipes.tcl` +140; one
  **non-scored** `.sh` integration leg that runs a real sim. *Estimate.*
- **Done when:** V-01a returns within its declared budget (measured `ase::run`
  returns in **177 ms**) and the callback fires with the exit code (measured 59.2 s
  on `tb_bandgap`); with no session, V-01a returns a named refusal and calls
  `ase::run` **zero** times; V-01b with `sim(spice,default)` = 0 refuses and names
  the profile rather than running.
- **⚠ The headless suite does not prove the GUI path.** `ase::netlist`
  (`src/ase.tcl:1683-1690`) silently `xschem load`s under `!has_x` and refuses
  under X. **This item owes an X leg on `:99`**, and the `.sh` leg is invisible to
  `full_audit.sh` (which globs `test_*.tcl` only, `full_audit.sh:393`) — declare
  it in the receipt.
- **Sabotage:** replace the callback with `ase::wait` → the freeze-budget check red
  and the context-restore check red (the semaphore no-ops the switch).
- **Look debt:** `owed.sh add look "run sim by voice, both paths"`. **`[E]`.**

### B8 — `recipe::open_saved_state` + `recipe::plot_signal` (V-06, V-04) · `[E]` · prereq B6 · ⟂B9 (A2 carries the case-fold ruling)
- **V-06:** `ase::design_of_current` (`src/ase.tcl:3742`) → `ase::ui::state_views`
  (`src/ase_window.tcl:4042`) → **membership check** → `ase::open_state`
  (`src/ase.tcl:3689`). **Never hand `open_state` a guessed view name** — issue
  0521. **Never use `Session > Load State`** — `ase::ui::do_load_state_from`
  (`src/ase_window.tcl:4212`) is a content import.
- **V-04:** bracket → session → `wviewer::open $key` (`src/wave_viewer.tcl:1065`;
  refuses an unknown token at `:1072-1077`) → attach raw if `[xschem raw loaded] <
  0` → `ase::ui::plot_map_expr` per name then `ase::ui::repair_currents` **once**
  → `wviewer::plot_signals` (`:7302`) → **restore and verify**.
- **⚠ Case folding must already be ruled** — the state spells it `VBG`, the raw
  spells it `v(vbg)` (both measured). **A2 carries that ruling** (see A2's verbatim
  list), which is what keeps B8 and B9 parallel. If A2 shipped without it, B8
  gains a prereq on B9 and the two serialise — check A2's spec before launching
  the pair.
- **⚠ This item is two recipes and may be run as two.** `recipe::open_saved_state`
  (V-06) and `recipe::plot_signal` (V-04) share only B6's bracket: different
  fixtures, different done-when sets, different failure modes, one look debt each.
  Split into **B8a** (V-06) and **B8b** (V-04, which also needs A2's case-fold
  ruling) if the item overruns the 2.5–3 h anchor; both keep prereq B6 and both
  must land before B10.
- **Files:** `src/voice_recipes.tcl` +160; suite +160. *Estimate.*
- **Done when:** on `tb_bandgap` (two state views, measured) V-06 returns a `tie`
  naming both and calls `ase::open_state` **zero** times; after V-06 with a state
  carrying `viewer {open 1 …}`, `ase::session_for_current` is **non-empty** (it
  returns `{}` today — measured `.drw`/`tb_bandgap.sch` → `.x1.drw`/`untitled.sch`);
  after V-04, `current_win_path` and `schname` are unchanged; `plot_signals`'
  per-name errors are relayed verbatim (measured: `unknown token 'v(bogus_zz)'
  (not an operator/function, number or raw variable)`).
- **Sabotage:** delete the membership check → a flat-library leg opens
  `examples/rlc.sym` and returns 1 (0521's exact symptom) → that check red.
- **Look debt:** `owed.sh add look "open saved state / plot by voice"`. **`[E]`.**

### B9 — slots, the resolver ladder, the tie refusal and the MARGIN GATE · `[E]` · prereq B5
- **What:** the ladder — exact → casefold → spelled-out digits/letters (`R25` ⇒
  "arr twenty five", "arr two five") → Metaphone → Levenshtein ≤2. A **tie is
  refused, never guessed**: highlight all candidates, say *"two: R25 and R26 — say
  one or two"*, and resolve an ordinal against the **offered list**, never against
  a re-run spatial sort.
- **⚠ The gap the design pass left open, and this item closes it (M1).** Only a
  *tie* refuses today. A homophone that resolves to a **different valid name** —
  "vee dee dee" → `VDDA` instead of `VDD` — returns **1** and looks like success
  (measured: `hilight_netname A` → 1, `hilight_netname NOSUCHNET_ZZ` → 0, so an
  *invalid* name is caught and a *wrong* one is not). Require a numbered
  **margin gate**: auto-execute only when best-vs-second-best exceeds a ruled
  threshold; otherwise offer. §6.1 rule 1 ("state the resolved identifier, never the span")
  is the second half of the mitigation and it is a check, not a comment.
- **Two type classes that must not mix:** geometry slots (unitless schematic
  units, `cadsnap` 10 / `cadgrid` 20, `src/scheduler.c:12113`/`:12104`) are **never
  speakable**; *"make it two microns"* is a **property string** (`W=2u`) set via
  `setprop`.
- **Files:** `src/voice.tcl` +250; new `tests/headless/test_voice_slots.tcl` (~300
  lines, band `VS1..`). *Estimate.*
- **Done when:** A0's slot utterances resolve on a fixture the table has never
  seen; a deliberately ambiguous pair (`VDD`/`VDDA`) **refuses** rather than
  picking; `"arr twenty five"` resolves to `R25`; a span with no candidate refuses
  rather than fuzzing to the nearest.
- **Sabotage:** make the ladder return the first candidate on a tie → the tie legs
  red. Widen the margin to accept everything → the `VDD`/`VDDA` leg red.
- **Look debt:** `owed.sh add look "tie refusal: both candidates highlighted"`.
  **`[E]`.**

### B10 — the entity index and the freeze budget · `[x]` · prereq B9, B8
- **Sources of legal values at run time:** `xschem list_nets` / `nets`;
  `xschem instance_list`; `wviewer::signal_list` (`src/wave_viewer.tcl:2337` —
  424 entries in 17.8 ms on `tb_bandgap`, and its `type`/`leaf`/`class` fields
  **are already the resolver metadata the ladder needs**), **class-filtered**, not
  raw `xschem raw list`; `ase::ui::state_views`; `libmgr::lib_names` /
  `xschem cell_views`.
- **The budget is a FREEZE budget, not a latency budget.** A five-command rebuild
  is ~7.6 ms; adding `list_hierarchy` makes it **~53 ms**. Rebuild on `modified`
  transitions, window switch and `descend` — **never per utterance**.
- **Files:** `src/voice.tcl` +180; suite +180. *Estimate.*
- **Done when:** the rebuild is **≤10 ms** on the 117-instance fixture;
  `list_hierarchy` appears **zero** times on the rebuild path (grep-asserted in the
  suite); the `tb_bandgap` signal list drops from 424 to the class-filtered subset
  with `v(vbg)` still present.
- **Sabotage:** put `list_hierarchy` on the hot path → the budget check red.
- **Look debt:** none.

### B11 — the amber tier: verify, suppress, undo, defer · `[x]` · prereq B10
- **Post-condition verification:** status is a **state re-read, never a reply** —
  `xschem get total_nonsense_key_zz` returns rc 0 and empty. Fingerprint =
  object-count delta + `xschem hash_string [xschem objects]` (1.51 ms). ⚠
  **`xschem hash` does not exist** — the verbs are `hash_file`
  (`src/scheduler.c:6202`) and `hash_string` (`:6219`).
- **Do not build transactions:** `undo_depth` is unexposed (measured `''`),
  refused mutators push nothing, netlisting pollutes the stack
  (`src/in_memory_undo.c:614`), `modified` is not restored by undo, and `MAX_UNDO`
  is 80 (`src/xschem.h:339`).
- **⚠ V-12 must honour Ruling 2 (M4 of the critic).** "Pop once, re-check, stop on
  a second mismatch" is correct only if nothing else wrote. With 16 declared peer
  sources, **a mismatch is the normal case, not the exception.** Rule it:
  **`voice.undo` refuses outright whenever the fingerprint shows any change since
  the voice act it would reverse** — it never pops blind. The suite must test the
  *common* branch (another source wrote in between), not only the safe one.
- **Scaffolding wrapped in `log_action -suppress`** (`src/scheduler.c:7770`) so the
  user's log gains **exactly one line per utterance**.
- **The polite-caller check — announce or defer, NEVER a lock (AM-3), and it may
  never block a non-voice source:**
  ```tcl
  list [expr {[xschem get ui_state] & ~8}] [xschem get ui_state2] \
       [grab current] [winfo children .]
  ```
  Rationale per term, all measured: `SELECTION` is `8U` (`src/xschem.h:236`) and
  means only "something is selected", so it must be masked out (the in-flight mask
  is `ui_state & 0x7BFFF7`); `ui_state2` carries the MENUSTART discriminators
  (`src/xschem.h:265-296`) and `MENUSTARTDESCEND` can be stranded with `MENUSTART`
  already cleared (`src/callback.c:303-307`); `semaphore` is **worse than useless**
  — deliberately zeroed around dialogs (`src/callback.c:7548, 7963, 8200, 8351,
  8607, 8616, 8623`), measured 0 in every state including with a dialog open;
  `grab current` is blind to `.dialog` and `.alert`, both of which have their
  `grab set` **commented out** (`src/xschem.tcl:11605`, `:14133`), so the only
  honest detector of a non-grabbing modal is an unexpected toplevel in
  `winfo children .`. And **`RUBBER` is not a `ui_state` bit** (`#define RUBBER 16`,
  `src/xschem.h:358`, numerically identical to `STARTSELECT 16U` at `:237`) — the
  architecture doc's §3.6 mask is a category error that also misses **17 of the 21**
  bits the in-flight mask carries, including `PLACE_SYMBOL` (measured `ui_state` =
  **8232** during a placement). ⚠ Re-derived here: `src/xschem.h:233-256` defines
  **22** `ui_state` bits (bit 18 is free — `:251-252`), the in-flight mask drops
  `SELECTION` leaving **21**, and `STARTWIRE|STARTSELECT|STARTMOVE|RUBBER|MENUSTART`
  names only **4** real ones because `RUBBER` **is** `STARTSELECT` numerically. An
  earlier draft said 16 of 21, which double-counts `RUBBER` as its own bit — the
  exact mistake the row is about.
- **The press-before-motion window is covered by nothing and v1 does not pretend
  otherwise** — that is issue 0523.
- **Files:** `src/voice.tcl` +200; suite +200. *Estimate.*
- **Done when:** an utterance that issues 7 index queries adds **exactly 1** line
  to `Xschem.log`; a mutator arriving with `ui_state` = 8232 is deferred with a
  spoken reason; a fingerprint mismatch **refuses** and says why; **and V-12's own
  ruled branch is covered** — after a voice act, a *non-voice* source writes
  (drive it from a second peer: a socket client, or `xschem setprop` from the
  CIW), then `voice.undo` **refuses by name and pops nothing** (`xschem get
  modified` and the object count are unchanged by the refusal). That is Ruling 2's
  normal case, not its exception, and it is the leg most likely to be skipped.
- **Sabotage:** remove `-suppress` → the log-line-count check red. Use `semaphore`
  instead of `ui_state` → the deferral checks red (it is 0 in every real state).
- **Look debt:** none.

### B12 — the utterance eval as a scored suite · `[E]` · prereq B9, B3
- **What:** freeze `utterances_v1.tsv` as the eval set and **quarantine it** — it
  is the only held-out human data that will exist for a long time. Nothing may be
  tuned against it except through a recorded, dated evaluation.
- **Files:** new `tests/headless/test_voice_utterances.tcl` (~260 lines, band
  `UTT1..`). *Estimate.*
- **Done when:** it prints `RESULT: ALL PASS` at A0's threshold with **0
  wrong-hits**, and prints the three counts. **A wrong-hit is a hard FAIL; a miss
  is not.**
- **Look debt:** `owed.sh add look "typed voice bar in the CIW" "type the 30
  phrases yourself; the suites cannot tell you whether it feels like talking to
  the tool"`. Report *"suites green, please look"*. **`[E]`.**

### G-B — the typed gate
Second `full_audit.sh`, diffed against the rolled baseline, 0 status changes bar
the declared new suites. **After G-B the microphone is the only untested link in
the system.** That is the property the whole ordering exists to buy.

---

## 6. BATCH C — speech

Prereq for every item: **G-B**, and **A4 passed**.

| # | item | what | prereq | files (est.) | done when | look |
|---|---|---|---|---|---|---|
| **C1** | `xvoiced` transport | target discovery (`$XSCHEM_VOICE_PORT` → xschemrc → `ss -ltnpH` filtered on `users:(("xschem"`), **refuse if >1 is listening**; the `…plan.md` §3.3 wire-format wrapper (`:297`+) with `::__v*`-namespaced globals (the interpreter is shared with bespice/gtkwave and ~19k lines of `src/xschem.tcl`; overhead 0.1–0.4 ms); the **atomic-write contract** from 0522; the ~40-id allow-list | G-B | new `utils/xvoiced` ~350 ln; `test_xvoiced.tcl` ~240 ln, band `VX1..` | with two instances listening it exits non-zero naming both ports; with one, `--utterance "is it done"` (V-03 — a **catalogued** read-class zero-slot intent; `zoom full` is not one, and §9 excludes chorded zero-arg verbs) returns the wrapper's fields + a JSONL record; a `recipe_id` **outside the ~40-id allow-list** is refused by name before anything reaches the socket (`ss` shows no new connection); `error 42` and `expr {40+2}` produce **different bytes** on the wire | no |
| **C2** | ASR daemon | `utils/VoiceAsr.ps1`, launched via **`-EncodedCommand`** (a `.ps1` on the WSL filesystem **cannot** be run by UNC path — `AuthorizationManager check failed`, even with `-ExecutionPolicy Bypass`; and `wslpath -w` reports the distro as `Ubuntu-24.04`, not `Ubuntu`). `-Command -` also bypasses the block but **consumes stdin**, so it cannot host a controllable daemon. **One long-lived child** — spawn is 0.52–0.55 s; per-utterance transport after warm-up is **2.6–4.9 ms** | C1 | new ps1 ~250 ln + launcher ~80 ln; `test_voice_asr.tcl` ~200 ln, band `VP1..` | `SetInputToNull()` + `EmulateRecognize` drives the whole pipeline **with no microphone**, in the suite: a ready line, 5 recognitions, 1 rejection | no |
| **C3** | SRGS from the entity index | grammar built from B10's class-filtered index, **capped at 300 identifiers**; carries **spoken** forms | C2, B10 | `voice.tcl` +120, ps1 +80 | a 300-name grammar swaps in <300 ms (measured 246.1 ms); `'highlight nonexistent thing'` → **NO MATCH**, not a low-confidence guess; **`'plot v d d'` matches and `'plot vdd'` does not** — which is why the phonetic ladder is needed at *grammar build* time, not only at resolve time | no |
| **C4** | push-to-talk | **never a wake word** (at the best published false-alarm rate a 6-hour design day is ~one unrequested edit every two days, on a channel that executes what it is given). Order: foot pedal emitting F13–F24 in firmware (0 software, survives xschem having focus) → `RegisterHotKey` + `WM_HOTKEY` via `Add-Type` P/Invoke (PowerShell 5.1's in-box compiler; **no .NET SDK is installed here** — runtimes 6/8/9/10 are, `dotnet --list-sdks` is empty) → AutoHotkey | C2 | ps1 +90 ln, doc | a press starts and a release stops recognition with xschem focused | **`[E]`** |
| **C5** | TTS confirmation | the four rules of §6.1; three latency classes (≤25 ms, ~0.4 s, ~60 s) get one beat, one late beat, and accept+completion beats | C2, B10 | `voice.tcl` +90, ps1 +60 | every confirmation names the **resolved identifier**, not the span, and carries a number/name/exit code read back after the fact; a 3-of-4 partial is announced as partial | **`[E]`** |
| **C6** | confusion table | TTS→ASR round trip; harvest real corruptions; fold into grammar + eval | C3, C5 | new `voice_confusions.tsv` | the table has ≥50 measured rows and B12 still shows 0 wrong-hits with them injected | no |
| **C7** | mic in the loop | end-of-speech → pixels, measured end to end | C4, C6 | doc only | a number exists for each of the three latency classes, measured with a human speaking | **`[E]` always** |
| **C8** | tier 1 classifier | LLM entered **only** on a tier-0 miss; output `{intent_id, slot spans}` under a GBNF constraint; never a command string, never an identifier | B12, §10/Q4 ruling | new `utils/voice_tier1.py` ~300 ln | on A0's misses it proposes an intent that the resolver then accepts or refuses; it can never emit an identifier (grammar-enforced, sabotage-proved) | no |
| **C9** | deixis | "that one" / "this" — **blocked on issue 0523** | B10, 0523 | `voice.tcl` +200 | every mutator refuses on a stale pointer; `xschem hover` non-empty is a precondition | **`[E]`** |
| **C10** | corpus gate | held-out quarantine, kill criterion, fine-tune go/no-go | C8 | doc only | a written go/no-go with the eval numbers that justify it; **30 utterances is not a classifier eval set and the gate must say so** | no |

---

### 6.1 What the user hears back — the four rules (C5's contract)

1. **State the resolved identifier, never the span.** *"plotting v of vbg"*, never
   *"plotting vee bee jee"*. The confirmation **is** the resolution being made
   visible, which is the only thing that makes a fuzzy match legal at all — and it
   is the second half of B9's margin gate.
2. **State a measured outcome, never an acknowledgement.** Never "OK", "done",
   "running". Every sentence carries a number, a name or an exit code that was
   **read back after the fact** (B11's state re-read, never a reply).
3. **Two beats for anything over ~1 s.** The three measured latency classes are
   ≤25 ms (plot a name, list state views, `raw list`), ~0.4 s (open a state), and
   ~60 s (a real sky130 tran). Class 1 gets one beat; class 2 one late beat; class
   3 an **accept** beat that names what it accepted — so a misrecognition is
   caught before 59 seconds elapse — and a completion beat.
4. **A partial success is announced as partial.** Never round 3-of-4 up to "done".
   `wviewer::plot_signals` returns `{name reason}` pairs and `hilight_netname`
   returns 1/0 per name; both are already per-name and must be relayed that way.

**The written channel is not optional.** Every spoken line also goes to the CIW
pane and the action log through `voice::echo` (B1). Speech is unrereadable; a
424-signal count spoken once is a number the user will want to see.

**Three confirmations that must name a side effect, because the recipe caused
one:** V-05 *"…replacing what was on that strip"* (`auto_plot` calls
`wviewer::clear_graph_traces` before re-adding, `src/ase_window.tcl:4974`);
V-06 *"…424 signals from tb_bandgap_ase.raw"* (the open silently re-binds the
results — measured); V-14 *"wrote the netlist to `<dir>/<cell>.spice`"* (it also pushed undo).

## 7. Windows-side speech: the recommended path and the fallback

**This box, measured:** Windows `10.0.26200.9168` (Win11 25H2), WSL `2.6.3.0`,
WSLg `1.0.71`, Intel Core Ultra 5 235T (14 cores, NPU ≈13 TOPS → **not** a
Copilot+ PC, threshold 40), WSL RAM 7 GB, no CUDA GPU, PowerShell **5.1**
(`pwsh` 7 absent), .NET runtimes 6/8/9/10 but **`dotnet --list-sdks` is empty**,
`.wslconfig` has `networkingMode=mirrored`, mics `Logi Webcam C920e` (SAPI
default) and `MPOW HC6`.

### Recommended: `System.Speech` + SRGS in a long-lived PowerShell 5.1 child

Zero installs on either side. It is the **only** option that is offline, free,
drivable from a console child, emits a text stream a parent can read, **and**
accepts a custom grammar. Measured here: `Add-Type` load **140 ms**; recognizer
`MS-1033-80-DESK | en-US`; SAPI `Microsoft Speech Recognizer 8.0 for Windows`;
TTS voices David/Zira free in the same process; grammar swap **0.95 ms per
identifier, linear**; `DictationGrammar` loads offline in 14 ms and **coexists**
with the closed grammar (`grammar count = 2`) — that hybrid is the tier-1 feed.
Full daemon round trip measured: startup 1065 ms, then `run sim` 87.2 ms (JIT),
then 2.6–4.9 ms per utterance, reload of 300 names 248.4 ms.

**`EmulateRecognize` is the sleeper win**: the whole command pipeline is
regression-testable headlessly with **no microphone**, which is what makes this
feature CI-able at all (C2).

Status caveat, **read not measured**: `System.Speech` ships and is documented for
.NET 10 but is explicitly *"not accepting new features"*. The Sept 2024 retirement
was of **Windows Speech Recognition the user feature**, not the API — verified
here, the shared SAPI 5 recognizer still instantiates.

### Transport: a Windows child launched from WSL, stdout as a pipe

Verified streaming and unbuffered. **The interop pipe is fine; any filter you put
in the pipeline destroys it** — with `tr -d '\r'` in the pipe, five lines emitted
400 ms apart all arrived in **8 ms** (stdio full-buffering). Strip CR **in the
reader**, or `stdbuf -o0`. Ranked alternatives: localhost TCP works (5.13 ms under
mirrored networking) but is slower and lets the Windows side reach xschem's
command socket directly, which the pipe design structurally prevents — and
mirrored mode shares the loopback namespace with Windows, so ports collide with
Windows services (hit live). A file under `/mnt/c` adds 9p latency and invents
framing. `wsl.exe` from Windows inverts ownership and is worst on both.

### Fallback: Vosk in WSL over `/mnt/wslg/PulseServer`

**Prefer Vosk over Whisper.** Whisper has **no grammar mechanism** — it would
throw away the single biggest accuracy lever, and the 0.95 ms/identifier
measurement shows that lever is cheap. Vosk is ~50 MB, offline, streaming, and
**accepts a runtime JSON word list** — the direct analogue of the SRGS `<one-of>`
swap, so the same per-schematic vocabulary feeds both back-ends and `asr_source()`
stays a real seam. 7 GB of WSL RAM also argues against the larger Whisper models.
Model figures are **read, not measured** (nothing is installed here): whisper.cpp
`tiny` 75 MB / `base` ~140–150 MB; faster-whisper `small` int8 CPU ≈ RTF 0.13 →
~0.4 s for a 3 s utterance, *estimate*.

**Gate the fallback on fixing the capture race** — retry-with-backoff on `EAGAIN`;
the pulse log proves the RDP source does connect on each failed attempt.

### Rejected, with the reason

**Voice Access** (no text out, no arguments) · **Win+H dictation** (**cloud**, and
it injects keystrokes rather than emitting text) · **Windows AI Speech
Recognition** (MSIX + `systemAIModels`, requires `MaxVersionTested ≥ 10.0.26226.0`
and **this box is 26200**, and **the entire API surface has no grammar hook**) ·
**`Windows.Media.SpeechRecognition`** (needs package identity; not drivable from a
console child).

---

## 8. What xschem itself must grow

Concrete, with file:line and estimated size. Nothing here is speculative — each
row is either a filed issue or a named new file.

| # | change | where | size (est.) | needed by |
|---|---|---|---|---|
| 1 | `log_action` overflow fix (0519-B) | `src/util.c:505-509`, possibly a new `my_vsnprintf` beside `src/util.c:611` | 1–120 ln | A6 |
| 2 | socket re-entrancy + `puts` rename removal (0519-A/C) | `src/xschem.tcl:5851-5894`, `:5923` | ~26 ln | A7, A8 |
| 3 | socket framing (0522) | `src/xschem.tcl:5854-5860` | ~12 ln | A9 |
| 4 | loopback bind (0004) | `src/xschem.tcl:18042`, `:18069`, `:18637`, `:16191`; `src/xschemrc:573`; one html | ~10 ln | A10 |
| 5 | selector resolver + 16 arms (0520) | `src/scheduler.c:9031-9060` → new static fn near `:214`; arms at `:11620-11703`, `:12756-12757`, `:12847`, `:12910`, `:13003-13004`, `:13043-13044`, `:13087-13088`, `:5626-5627`, `:5663`; arity guard `:11600-11611` | ~140 ln | A11–A13 |
| 6 | `ciw_exec` puts re-entrancy (0526) | `src/ciw.tcl:247`, `:255-256` | ~15 ln | B2 |
| 7 | CIW utterance/command split | `src/ciw.tcl:230`, `:233`, `:237`, `:274` | ~25 ln | B3 |
| 8 | **new** `src/voice.tcl` | + `src/Makefile.in:23`, + one `source` in `src/xschem.tcl` after `:16962` | ~850 ln by end of B | B1, B5, B9–B11 |
| 9 | **new** `src/voice_recipes.tcl` (namespace `recipe::`) | same two build lines | ~500 ln | B6–B8 |
| 10 | **new** `src/voice_intents.tsv` | same | ~70 rows | B5 |
| 11 | `ase::ui::auto_plot` reachability (0527) | `src/ase_window.tcl:4932`; one `actions.csv` row + palette entry | ~3 ln | V-05, and worth doing alone |
| 12 | `ase::open_state` extension check (0521) | `src/ase.tcl:3690-3697` | ~6 ln | B8 |
| 13 | `wviewer::plot_signals` context restore (0524) | `src/wave_viewer.tcl:7302`, pattern at `:1404`/`:1475` | ~10 ln | B8 (or the recipe brackets it) |
| 14 | pointer-freshness signal (0523) | `src/callback.c:7045-7060` + a new `get` key | ~30 ln | **C9 only** |
| 15 | verification-tool class (0525) — **"run LVS"** | `sim(tool_list)` at `src/xschem.tcl:4327` + `simconf`, or a general external-tool registry | ~200 ln | **v2, not v1** |

**Precedent for sizing a new Tcl subsystem:** `src/results.tcl` is **940 lines**
today — 17 procs, 5 public (`resolve` `list` `current` `persist` `select`) and 12
helpers (`wc -l src/results.tcl`, `grep -c '^proc ' src/results.tcl`) — and it
reached that size over **six** commits of the results batch, not one
(`git log --oneline -- src/results.tcl | wc -l` → 6); the ASE-L Results dialog
was **+879 lines** in `src/ase_window.tcl`, the largest single-item delta in the
results batch, and came back `[E]` with 2 look debts.

---

## 9. Deferred by user ruling

**Conflict handling and serialisation between command sources.** The ruling, in
the user's words:

> *"we cannot have only one source that issues commands. They can come from
> keyboard, mouse, user typing into CIW entry field, TCP server, whatever. We
> don't expect conflicts. But, if there are, we can cross that bridge when we come
> to it."*

Therefore, and this must be copied verbatim into `DECISIONS.md` and into the spec
so a later contributor does not helpfully add one: **v1 builds no lock, no owner,
no queue, no serialisation scheme, and no exclusivity between clients.** The
architecture doc's `xvoiced`-owns-the-socket sentence (`:17-18`) is struck. The
politeness check (B11) is *announce-or-defer* for **voice's own** mutators and may
never block a non-voice source. The only exclusivity in v1 is about the **target**
— refuse when more than one xschem is listening (C1) — because attaching to the
wrong editor invalidates every other safety mechanism.

**Also excluded, and permanently rather than for v1:**

- **Everything mouse-shaped.** Fluid stretch, connected drag, rotate-drag
  body-route, wire drawing, symbol placement, area select, zoom-to-region, moving
  anything. Voice can replay a gesture; it cannot *steer* one, because steering is
  a continuous position stream and voice has no positional channel. This is also
  the exact rock every dead voice-CAD product broke on. **The user agrees the
  mouse wins for drawing.** Put it on page one of the spec.
- **Mode-arming verbs, the whole class** — anything that leaves the editor armed
  so the user's *next click* does something they never asked for. Measured:
  `xschem place_symbol devices/res.sym` moved `ui_state` 0 → **8232** and returned
  immediately. Voice uses fully parameterised one-shots only, and fires `escape`
  defensively at session start, after any refusal, and after any watchdog timeout.
- **Destructive-without-a-name** — `delete`, `clear`, `save all`, `saveas`, `load`,
  `reload`, `make_symbol`, `exit`, `exit force`, `delete_files`, `set no_undo`.
  And note that **read-only mode is not the safety primitive**: measured with
  `readonly=1`, `xschem undo` was **refused** and `xschem saveas` **succeeded**,
  writing 3,469 bytes. It refuses the escape hatch you need and permits the one
  you don't.
- **Zero-argument things that already have a chord** — voice adds latency and a
  false-accept risk and saves nothing: Signal Browser `Ctrl+B`
  (`src/wave_viewer.tcl:18546`), Show in Signal Browser `Ctrl+Alt+V`
  (`src/actions.csv:165`), Send highlighted nets to viewer `Ctrl+Shift+X` (`:122`),
  un-highlight all `Shift+K` (`:107`). *Exception:* `unhilight_all` is in v1 as
  **V-12's inverse**, not as an intent.
- **"run LVS"** — v2, gated on issue 0525 (§2, §8 row 15). Excluded because the
  *tool* is absent, not because the intent is wrong: per Ruling 3 it is the
  worked example of the class this catalogue is selected from, and the day a
  comparator is wired up it costs one table row and one recipe proc to say.

---

## 10. Open questions needing a ruling before work starts

Few, sharp, each with the default taken if the user says nothing.

**Q1 — the margin gate threshold.** A homophone that resolves to a *different
valid* name executes and looks like success. What best-vs-second-best margin
auto-executes?
*Default: refuse whenever the second-best candidate is within 1 edit or 1
Metaphone class of the best, and offer both. Conservative; tune from C6's
confusion table with recorded evidence.*

**Q2 — is the CIW the shipped home of the typed bar?** The CIW **does not exist
under `--nolog`** (`src/xschem.tcl:18930`, verified: `winfo exists .ciw` → 0 with
`--nolog`, 1 with `--logdir`), and B5/B12 both assume it does.
*Default: yes, the CIW is the home, and voice is documented as requiring a logging
session. A separate always-present bar is a v2 item.*

**Q3 — which window does an utterance target?** This branch ships tabs and
detached windows. `xschem new_schematic switch` is the restore primitive in every
bracket and it silently no-ops while the semaphore is raised.
*Default: the utterance targets the window that owns the current xctx at the
moment it arrives; the entity index is per-window; "this schematic" means
`[xschem get schname]` of that window; with more than one editor window open,
every confirmation names the cell it acted on.*

**Q4 — does tier 1 run locally?** Every utterance carries cell, net and library
names from the user's PDK work. The architecture doc never says where the
classifier runs.
*Default: **local only**. No utterance text, no entity index and no schematic
identifier leaves the machine. If the user wants a hosted model, that is an
explicit, separate ruling.*

**Q5 — retention of the utterance log and the confusion table.** `voice::log`
records `audio_sha, transcript, …` per utterance; `voice_confusions.tsv` records
real corruptions of real net names. Neither has a stated location, lifetime, or
rule about leaving the repo.
*Default: both live under `$USER_CONF_DIR` — **not** the repo, and never committed
— rotate at 30 days, and audio itself is never written to disk (the recon found
and deleted a stray `mic.wav` an earlier run had left behind).*

**Q6 — drain the look ledger first?** Measured now: **5 suite debts, 24 look
debts** outstanding. This plan adds **≥9** more.
*Default: run `owed.sh drain` for the suite debts before Batch A, and ask the user
to clear the 24 look debts before Batch B starts adding to them. A 33-deep eyeball
queue is a ledger nobody reads.*

**Q7 — is `run sim` allowed to netlist without asking?** V-01a's `ase::run`
netlists as step 1 and V-01b calls `xschem netlist` explicitly; `netlist` is
**red** tier in the architecture doc (`…plan.md:415`) and it pushes undo
(`src/in_memory_undo.c:614`).
*Default: yes for V-01a — netlisting is intrinsic to "run sim" and the ASE-L
artifact lives in the session rundir, not the user's tree — and the confirmation
names it ("Netlisting tb_bandgap, then ngspice"). No for a bare `netlist it`
(V-14), which announces what it wrote and where.*

**Q8 — one batch or three?** §3.1 splits this into A (hardening, valuable with
zero voice), B (typed, zero microphone) and C (speech). 31 crew items at a
measured median of 2h41 is ~80–95 h.
*Default: three batches, run in order, with a decision point after each gate. Do
not start B until A's gate is green; do not start C until A4 has proved this
machine can hear.*

---

## Appendix — corrections carried forward

Verified this run; each replaces a claim that appeared in the architecture doc or
in the design pass that preceded this file.

| claim | correction |
|---|---|
| `…plan.md:17-18` — `xvoiced` owns the only socket | Struck. Two simultaneous connections both answered; per-socket state at `src/xschem.tcl:5927-5928`. AM-3. |
| `…plan.md:18-20`, `:266-267` — "emitter template the broker owns" | Struck. AM-1: the broker emits `{recipe_id, spans}`. |
| `…plan.md` §3.2 — "the client must `shutdown(SHUT_WR)`" | Wrong twice: 3/3 replies with no shutdown at 1.35–2.53 ms, and on a non-blocking channel `gets` returns −1 for an *incomplete line* too. The real rule is the atomic-write one (0522). |
| `…plan.md` §3.6 mask `…\|RUBBER\|…` (`:434`) | `RUBBER` is not a `ui_state` bit (`src/xschem.h:358` vs `:237`); the mask also misses **17 of the 21** bits the in-flight mask carries (22 defined at `src/xschem.h:233-256`, bit 18 free at `:251-252`, `SELECTION` masked out). B11 carries the correct one. |
| `…plan.md` §2 — "no .NET SDK is installed" | Precisely: runtimes 6/8/9/10 are installed, `dotnet.exe` is on PATH, `--list-sdks` is empty. The conclusion holds and is moot — `Add-Type` compiles the P/Invoke in-box. |
| the tree's own help text — `xschem switch_back` (`src/scheduler.c:10228`) | Typo **in the tree**, not in `…plan.md`, which never mentions it (`grep -c switch_back …plan.md` → **0**). The implementation is the `raw` sub-verb at `src/scheduler.c:10477`; there is no top-level `switch_back`. Carried here because a recipe author reading that help block will write the wrong verb. |
| design pass — `check.run` is read-only | **False.** `show_unconnected_pins` added 2 instances on a 15-instance fixture (measured); `netlist -erc` writes files and pushes undo. §2. |
| design pass — "no GUI entry anywhere passes a name" | False: `Ctrl+F` → `property_search` Highlight radio (`src/xschem.tcl:11930`, `:11919`), `net_hilight_apply` (`:666`), `probe_net` (`:5987`). |
| design pass — `ase::run`/`ase::netlist` echo their refusals | They **throw** (`return -code error`, `src/ase.tcl:1666,1669,1679,1686,1695,1709`). Recipes must `catch`. |
| design pass — 0519-B is "4 lines → 1" | `HAS_SNPRINTF` is never defined; `vsprintf` is the live branch; there is no `my_vsnprintf`. A5 rules it. |
| design pass — the handler "executes whatever it has and closes" | It does not: `gets` does not consume an incomplete line, so the command is **discarded**, not truncated-and-run. |
| design pass — 746 `select` call sites | **749** (`grep -rn 'xschem select ' tests/ \| wc -l`), and 572+159+18 = 749. |
| design pass — `$::sim(...)` measured headless | Unset in a bare `--nogui` session until `set_sim_defaults` (`src/xschem.tcl:4293`) runs. Right values, wrong provenance. |
| design pass — 96 specs | **95** `.md` (`ls doc/claude/specs/*.md \| wc -l`); `ls \| wc -l` counts 96 entries. |
| design pass — `validate_rpn` at `src/wave_viewer.tcl:4409` | `:3689` (`:4409` is a call site inside `add_trace`). |
| design pass — select arity guard `:11603-11607` | `src/scheduler.c:11600-11611`. |
| design pass — `raw list` at `src/scheduler.c:10335` | The `raw` verb is at `:10335`; the `list` sub-verb arm is `:10757`. |
| design pass — 0519/0520 are untracked, `git clean -fd` deletes the authority | **Resolved**: both committed at `ab33cee6` (`git ls-files doc/claude/issues/0519* 0520*` → 2). |
| design pass — "house median 53 new checks/item over 17 items" | Unverifiable; matches neither ledger. §3.2 carries the real rows. |
