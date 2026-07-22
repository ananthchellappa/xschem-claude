# The "find" command that isn't a command — porting a foreign tool over one Tcl dispatcher

*How XSCHEM gained Tanner S-Edit's Find Navigator without a single line of C —
and what that teaches about reproducing a foreign tool's built-in command by
composing the primitives a host already exposes, instead of extending the engine.*

This is a **teaching** companion to the design record
(`doc/claude/specs/find_helper.md`). That spec is the exhaustive *what*: the
widget-to-verb mapping table, the form layout, the match-mode linkage rules, the
guard rationale, and the RED-first test plan. This tutorial is the *why* and the
*how it hangs together* — the architecture, the porting strategy, and the load-bearing
hazards a newcomer would trip on. When you want the design decisions in full, read
the spec; this page will not re-tabulate them.

It is written for someone early in their career who can write a loop and a function
call, but has never had to reason about *one program exposing its whole self through
a single scriptable command*, or about *porting a feature whose original lived
inside a compiled engine you cannot see*. All the code is real and on the
`fluid-editing` branch; every line number was read from source and is reproducible.

Scattered through are **▶ Level up** sidebars that lift each concrete XSCHEM detail
to the general idea, so you can carry it to any codebase.

---

## Part 0 — The misconception to dispel first

You are told: "XSCHEM now has S-Edit's *Find Navigator* — find ports, instances or
net-labels by name pattern, then select / count / list / bulk-rename them." S-Edit's
version was a **native, built-in command**: you typed `find <type> ... -modify {script}`
and a compiled C engine did the enumeration, matching, and mutation, running your
braced `-modify` script *inside itself* (`references/find_helper_spec.md:112`).

So the natural expectation is: **someone added a `find` verb to XSCHEM's C core.**

They did not. There is **no `find` subcommand** anywhere in the engine, and the
feature shipped with **zero changes to any `.c`, `.h`, `.y`, `.l`, or `Makefile`**.
The entire Find Navigator is one file of pure Tcl — `utils/find_helper.tcl`,
662 lines — plus a spec, a headless test, and one line in a startup script. The spec
states the constraint outright: "**No new matching engine and no new C verb**"
(`doc/claude/specs/find_helper.md:34`).

That fact is the spine of this tutorial. Everything else explains *why that was
possible* and *why it was the right call*.

> **▶ Level up — separate the capability from its original packaging.**
> A feature you are asked to port arrives wearing the clothes of its old home: a
> command, a class, an engine. Your first job is to strip those off and ask what the
> capability *actually is* — here, "walk objects, keep the ones whose name matches,
> then act on them." Capabilities are portable; packaging usually is not.

---

## Part 1 — The fork in the road

S-Edit's `find` was C. To bring it to XSCHEM you have two routes:

1. **Extend the engine.** Add a native `find` verb in C: new parsing, new iteration,
   new mutation, new undo handling — a compiled twin of S-Edit's command.
2. **Reproduce it in the host's scripting surface.** Write a Tcl loop that
   *enumerates → classifies → matches → acts*, built entirely out of verbs the
   engine already exposes.

The port took route 2, and the payoff parts below show *why* it is correct here. The
short version: route 1 is only justified when a genuinely-missing **primitive** forces
it. If the host already exposes the primitives — a way to count objects, read a
property, write a property, select, and bracket an undo transaction — then their
*composition* already is the feature, and writing C buys you nothing but a larger
attack surface, a rebuild, and a second place for bugs to live.

The whole argument therefore rests on one question: does XSCHEM's scripting surface
already expose those primitives? Part 2 answers it.

---

## Part 2 — The enabling architecture: one command, and the primitives under it

### 2.1 The single `xschem` command

Almost everything XSCHEM can do is reachable through **one** Tcl command named
`xschem`. It is registered exactly once:

```c
Tcl_CreateCommand(interp, "xschem", (myproc *) xschem, NULL, NULL);   // src/xinit.c:3247
```

Menus, keybindings, the regression tests, and `find_helper.tcl` all drive the C core
by calling `xschem <subcommand> ...`. The C entry point is the giant dispatcher
`int xschem(...)` at `src/scheduler.c:11976`. It reads `argv[1]` as the subcommand
(`argc < 2` → `"Missing arguments."`) and routes on the **first letter**:

```c
switch(argv[1][0]) {              // src/scheduler.c:11997
  case 'a': ...                   // -> xschem_cmds_a(...)
```

Each letter has a static handler (`xschem_cmds_a` … `xschem_cmds_z`; e.g.
`xschem_cmds_f` at `src/scheduler.c:3198`, `xschem_cmds_s` at `9253`). Inside a group,
verbs are matched by a `strcmp` if/else chain, and an unrecognized verb sets
`cmd_found = 0`, which the top level turns into a hard `"invalid command"` TCL_ERROR.
There is no silent no-op: **if `find_helper` had leaned on a `find` verb that did not
exist, it would fail loudly.** It does not lean on one — the only `find*` token in the
whole dispatcher is `find_nth` (`src/scheduler.c:3248`), an unrelated string-splitter.

> **▶ Level up — expose one command, get scripting for free.**
> XSCHEM chose a *narrow-waist* API: a single command whose first argument selects a
> subcommand. The cost is a big dispatch switch; the payoff is enormous — every new
> C feature is automatically scriptable, testable headless, and composable, because
> it is just another word after `xschem`. When a design routes all power through one
> well-defined choke point, higher layers can build features the original authors
> never anticipated. That is exactly what Find Navigator does.

### 2.2 The five primitives the port actually needs

Find Navigator is built from a small handful of *pre-existing* verbs. Each one already
had a C implementation; the port added none:

| Job | Verb the port calls | Dispatch site |
|---|---|---|
| Count objects | `xschem get instances` | `src/scheduler.c:3811` |
| Classify one object | `xschem getprop instance <N> cell::type` | `src/scheduler.c:4470` (reads the **symbol**'s `prop_ptr`) |
| Read a name | `xschem getprop instance <N> <tok>` | `src/scheduler.c:4474` (reads the **instance**'s `prop_ptr`) |
| Write a name | `xschem setprop [-fast] instance <N> <tok> <val>` | `src/scheduler.c:10351`; `-fast` parsed at `10359` |
| Select / scope | `xschem selected_set`, `select instance`, `unselect_all` | `9724`, `9454`, `11570` |

Two of these deserve emphasis because they are what make the whole loop *possible*.

**Index-addressable targets.** Every `getprop`/`setprop`/`select` resolves its target
through `get_instance()` (`src/scheduler.c:86`), which accepts **either a name or a
numeric index** — `isonlydigit(s)` → `atoi(s)` at lines 91-92. That single fact lets the
port iterate raw integer indices `0 .. N-1` with no new addressing primitive. Without
it, route 2 would have needed a C change just to name the objects it walks.

**Batchable undo.** `setprop` calls `xctx->push_undo()` **only when `-fast` is not
set** (`if(!fast) { ... xctx->push_undo(); }` at `src/scheduler.c:10394`). So one
outer `xschem push_undo` plus a loop of `setprop -fast` collapses a whole rename sweep
into a *single* undo step. The primitive for "batch this as one transaction" was
already there.

The conclusion of Part 2: the primitives exist, they are index-addressable, and they
compose into a transaction. Route 2 is not a compromise — it is simply reading the API
the host already published.

---

## Part 3 — One object store, many "types": the classification landmine

Before the walkthrough, one domain fact that shapes every proc in the file.

S-Edit has *typed* object classes — a port is a port, an instance is an instance, a
net-label is a net-label. XSCHEM does **not**. It stores ports, net-labels, and real
components together in **one flat instance array** (`utils/find_helper.tcl:19-23`).
What distinguishes them is the **symbol's `cell::type`** — a token read from the
*symbol* behind each instance. So "find by type" cannot index a typed collection; it
must **classify** each entry as it walks.

`type_ok` is that classifier (`utils/find_helper.tcl:96-103`):

```tcl
port     { return [expr {[lsearch -exact {ipin opin iopin} $ctype] >= 0}] }
netlabel { return [expr {$ctype eq "label"}] }
instance { return [expr {[lsearch -exact {ipin opin iopin label show_label {}} $ctype] < 0}] }
```

A **port** is `ipin`/`opin`/`iopin`; a **netlabel** is `label`; an **instance** is
anything that is *not* one of those, plus `show_label` and empty-type excluded as
non-connecting (the same exclusion rule as `toggle_pins_netlabels.tcl`).

Now the sharp edge. In S-Edit, `property get -name Name` was **uniform** — one call,
every object kind. In XSCHEM the user-visible *name* lives in a **different property
token depending on kind**:

- a component instance's name is its instance name, stored in the **`name`** attribute;
- a port's or net-label's "name" is the **net text**, stored in the **`lab`** attribute.

That routing is centralized in exactly one three-line proc — the file itself calls it
"the single biggest porting hazard" (`utils/find_helper.tcl:88-93`):

```tcl
proc find_helper::name_token {objtype} {
  if {$objtype eq "instance"} { return name }
  return lab
}
```

Get this token wrong and the tool silently reads and *renames the wrong field on
every object* — no error, just corruption. So every read and every write in the whole
file funnels through `name_token`: `collect` (line 299), `do_rename` (line 323),
`list_names` (line 449), and `run`'s report path (line 411). One choke point, tested
directly by the headless suite (`name_token instance → name`, `port → lab`).

> **▶ Level up — when a foreign abstraction has no host equivalent, centralize the
> bridge.** S-Edit's "a name is a name" does not survive the border. The disciplined
> response is not to sprinkle `if type == instance` across the code; it is to encode
> the mismatch in *one* named function and route every access through it. The hazard
> then has exactly one place to be right, and exactly one place to unit-test.

---

## Part 4 — Guided walkthrough: the life of one "Run"

Follow a single click of **Run**. The orchestrator is `find_helper::run`
(`utils/find_helper.tcl:383-431`); it calls, in order, guard → history → collect →
(optional) rename → apply-selection → status. Each step maps back to a piece of
S-Edit's native command.

### 4.1 Scope → the identifiers to walk

`scope_indices` (`utils/find_helper.tcl:283-294`) yields *what* to iterate for the
chosen Scope:

- **view** → integer indices `0 .. [xschem get instances]-1` (lines 285-289);
- **selection** → the instance **names** from `xschem selected_set` (line 291).

Both kinds of identifier work uniformly downstream *because* `get_instance()` accepts a
name or an index (Part 2.2). This is S-Edit's `-scope` argument, reproduced.

### 4.2 collect → enumerate, classify, match

`collect` (`utils/find_helper.tcl:297-314`) is the heart — S-Edit's
`find <type> -name ...` filter, as a loop:

```tcl
foreach i [find_helper::scope_indices] {
  set ctype [xschem getprop instance $i cell::type]     ;# classify
  if {![find_helper::type_ok $objtype $ctype]} continue ;# type filter (Part 3)
  set val [xschem getprop instance $i $tok]             ;# read name via name_token
  if {$pat eq "" || [find_helper::match $mode $pat $val $nocase]} {
    lappend out $i
    if {$::find_helper::first} break                     ;# -first short-circuit
  }
}
```

The matcher `match` (`utils/find_helper.tcl:116-140`) has one branch per mode:
`wildcard` → `string match`, `regex` → `regexp`, `exact` → `string equal`,
`contains` → `string first`, and a `default` whole-string equality — each with an
optional `-nocase`. Which mode is live is decided by `mode_of`
(`utils/find_helper.tcl:106-112`) in fixed precedence **wildcard > regex > exact >
contains > default**. Crucially, the user's pattern is only ever handed to Tcl's
matchers as **data** — never `eval`'d (comment at `114-115`).

The checkbox **auto-uncheck** logic lives in `link` (`utils/find_helper.tcl:143-154`),
which mutates only namespace variables (e.g. ticking `exact` clears
wildcard/regex/contains/nocase; `add` and `sub` clear each other). It is wired to the
Tk checkbuttons via `-command [list find_helper::link $var]` at line 576 — keeping the
mutual-exclusion rules in the pure core, not buried in widget callbacks.

> **▶ Level up — keep policy in a pure function, wiring in the shell.** The *rule*
> "exact excludes contains" is data logic; the *checkbutton* is UI. `link` holds the
> rule and takes a plain string argument, so the same rule is testable with no Tk. The
> widget only says *when* to apply it. Push decisions down to pure functions; let the
> UI be a thin trigger.

### 4.3 do_rename → the `-modify` port, as one undo transaction

If a From pattern is present, `run` calls `do_rename`
(`utils/find_helper.tcl:320-347`). This is S-Edit's `-modify {script}` reproduced
with `getprop`/`regsub`/`setprop`, and it demonstrates two idioms worth stealing.

**Single-undo transaction.** The sweep is bracketed:

```tcl
xschem push_undo          ;# one checkpoint for the whole batch     (326)
xschem set no_undo 1      ;# suppress per-op pushes                 (327)
catch { foreach i $indices { ... xschem setprop -fast ... } } emsg
xschem set no_undo 0                                              ;# (343)
xschem set_modify 1                                              ;# (344)
xschem redraw             ;# ONE repaint, not one per edit        (345)
```

`-fast` skips `setprop`'s own `push_undo` (Part 2.2), so N renames land as **one**
undoable action with **one** redraw — reproducing S-Edit's `renderoff`/`renderon`
batching purely from existing verbs.

**Injection safety, isolated for testing.** The actual transform is one line,
deliberately pulled into its own proc so it can be unit-tested with pathological input
(`utils/find_helper.tcl:186-188`):

```tcl
proc find_helper::rename_transform {from to old} {
  return [regsub -all -- $from $old $to]
}
```

`from`, `to`, and `old` are Tcl **variables** fed to `regsub`. Any `[ ] { } $` inside
them is **inert data** — never command or variable substitution. A user typing a
From-pattern of `[exec rm ...]` gets a literal string match attempt, not a shell.

**FAILED handling that mirrors S-Edit.** Each object is wrapped in its **own** `catch`
(lines 331-338), and *both* the `getprop` and the `setprop` are inside it. An
unresolvable identifier or a rejected write is appended to `::fails` as `[list $i $m]`
and **the sweep continues** — reproducing S-Edit's half-updated "FAILED" reporting.
Only genuinely-changed values (`if {$new ne $old}`) are applied and recorded to
`::hits`. `run` then renders `old -> new` lines and a `FAILED:` block
(`utils/find_helper.tcl:404-408`) and a `"N found, N renamed, N failed"` status.

> **▶ Level up — index stability across a mutating sweep.** `collect` snapshots a list
> of indices, then `do_rename` writes to each. This is safe *because* `setprop name/lab`
> only edits a property string; it does not add, delete, or reorder entries in the
> instance array, so index `i` still names the same object on the write pass. Whenever
> you iterate a collection you are also mutating, you must know whether the mutation can
> invalidate the cursor — here the answer is "no, by construction," and that is worth
> stating explicitly rather than assuming.

### 4.4 apply_selection → the `-add` / `-sub` / `-count` port

`apply_selection` (`utils/find_helper.tcl:350-360`) maps the Selection flags onto the
matched identifiers, all with `nodraw` batching: `count` selects nothing (report-only);
`add` selects each; `sub` removes each (`select instance $i clear nodraw`); otherwise
it replaces the selection (`unselect_all` then select each). One `redraw` at the end of
`run` paints the result.

### 4.5 The List action and `order_by_screen`

`list_names` (`utils/find_helper.tcl:443-461`) is a *pure read*: `collect`, then build
`{name x y}` triples via `xschem instance_coord`, hand them to `order_by_screen`, and
emit a CSV. It never selects, never renames, pushes no history.

`order_by_screen` (`utils/find_helper.tcl:161-181`) is a small, honest heuristic worth
naming as such: it computes the bounding spread `xs = xmax-xmin`, `ys = ymax-ymin`,
then sorts ascending by **X** if `xs >= ys` (left → right) else ascending by **Y**
(top-first — and because XSCHEM's screen-Y grows *downward*, top-first means *smallest
Y first*). No dedup. It is a convention, not a law, which is precisely why it lives in
one testable function with a comment stating the convention.

---

## Part 5 — How it plugs in, and how it is tested

### 5.1 A pure core wrapped in a Tk-guarded shell

The file is deliberately three zones (banners at lines 84, 276, 524):

1. **Pure-Tcl core** — `name_token`, `type_ok`, `mode_of`, `match`, `link`,
   `order_by_screen`, `rename_transform`, `build_summary`, history. No Tk, no engine.
2. **Engine-backed core** — `scope_indices`, `collect`, `do_rename`, `apply_selection`,
   the guards, `run`/`list_names`. Needs a live document, but **still no Tk**.
3. **The Tk form** — `show`, `init_fonts`, the widgets. Tk-only.

The header promises the proc *definitions* all load with no Tk present; only `show()`,
the fonts, and the trailing `bind` are Tk-guarded (`utils/find_helper.tcl:30-32`). The
glue that makes this work is `has_widgets` (`utils/find_helper.tcl:466-468`): it is true
only when the `winfo` command exists **and** `.fh` exists. Every `ui_set_*` proc
**always stores to a namespace variable first, then touches a widget only if
`has_widgets`** (lines 469-499). So the identical logic runs headless (writing state a
test can read) or drives real widgets when the form is up.

> **▶ Level up — a headless seam is a testing seam.** Splitting "compute the answer"
> from "show the answer" is not just tidiness; it is what lets a test call `collect` and
> assert on the result with no display server. If your logic can only be exercised by
> clicking a button, you have coupled correctness to the UI. A `has_widgets`-style gate
> — store always, render conditionally — buys you a testable core for a few lines.

### 5.2 The RED-first headless test

`tests/headless/test_find_helper.tcl` `source`s the util and exercises the core with
**no Tk**. It runs via `xschem --nogui --pipe -q --nolog --script ...` and prints an
`OVERALL: ok` sentinel that `run_regression.tcl` greps. It can drive:

- **Section A** — pure units: `name_token`, `type_ok` across every `cell::type`, all
  `match` modes, `link`, `order_by_screen`, `rename_transform` with pathological input.
- **Section B** — engine units against a loaded fixture: `scope_indices`, `collect`,
  `do_rename` (asserting single-undo and FAILED handling), selection.

What it **cannot** test is the Tk form itself — widget layout, the comboboxes, the copy
bindings — because those never load headless. That is a deliberate, documented boundary:
the load-bearing logic is in the pure/engine core precisely so the untestable Tk shell
stays thin.

### 5.3 The keybinding — and why not `keybindings.csv`

The util is sourced from `src/cadence_style_rc` (line 156), and the public entry point
`find_helper::show` is bound to **Ctrl+Shift+G** at the bottom of the file:

```tcl
if {[llength [info commands bind]]} {
  catch { bind .drw <Control-Shift-Key-G> {find_helper::show; break} }   // 660-662
}
```

Why a raw Tk `bind` rather than a row in `keybindings.csv`? Because
`keybindings.csv` rows are replayed through `xschem bind`, which only accepts an action
id **already compiled into the C `action_registry[]`** (`callback.c`). There is *no
runtime path to register a Tcl proc as an action*, so a brand-new pure-Tcl proc simply
**cannot** be dispatched from `keybindings.csv` without a C-source change
(`utils/find_helper.tcl:35-45`). The established no-C mechanism is a `.drw` binding
ending in `break` (the `break` stops the chord from also reaching the generic
`<KeyPress>` → `xschem callback` → C dispatcher), and `clone_canvas_bindings` propagates
it to detached/new canvases. The keybinding choice is itself a consequence of the
"no C change" constraint.

---

## Part 6 — Faithful, not literal

A good port preserves *intent*, and knows where a literal copy would betray it. Find
Navigator diverges from S-Edit in three deliberate places:

- **The Command box is a summary, not a re-runnable line.** S-Edit could echo the exact
  `find ...` string it ran. XSCHEM has no single `find` verb to echo, so `build_summary`
  (`utils/find_helper.tcl:192-210`) produces a human-readable *summary* of the query.
  The transparency purpose is kept; the literal string is not (`doc/claude/specs/find_helper.md:37`).
- **Native clipboard.** S-Edit's shadowed-`clipboard`/`clip.exe` hack becomes the native
  Tk clipboard via `cadence::clip_put` (`copy_results`, `utils/find_helper.tcl:512-522`).
- **Hierarchy scope is refused.** XSCHEM's verbs act on the **current sheet only**;
  there is no cross-sheet find/-modify primitive, so `guard_check` returns `hierarchy`
  and the run is refused with "descend and re-run per sheet"
  (`utils/find_helper.tcl:366`, `374`). This is the *one* place where a missing
  primitive genuinely blocks a feature — and the disciplined answer was to **defer with
  a receipt**, not to write speculative C.

The guards themselves show a deliberate asymmetry: `run` calls `guard_check 1` so
renames and selection are blocked on a read-only sheet, but `list_names` calls
`guard_check 0` so **listing — a pure read — is still allowed** on a read-only
schematic (`utils/find_helper.tcl:390`, `446`). Read-only should block writes, not
inquiry.

> **▶ Level up — port the intent, audit each divergence.** Every place a port cannot be
> 1:1 is a decision, and each decision deserves a recorded reason. "Summary not literal
> string," "native not shadowed clipboard," "hierarchy deferred" are not sloppiness —
> they are intent preserved under a different set of constraints, each written down.

---

## Part 7 — Takeaways you can carry anywhere

1. **A "native command" in one tool is often just a composition of primitives in
   another.** Before you extend an engine to match a foreign feature, list the
   primitives the host already exposes. If enumerate + read + write + select + batch-undo
   are all there, the feature is a script, not a C patch.

2. **A narrow-waist API (one command, many subcommands) is a superpower for the layers
   above it.** Because XSCHEM routes everything through `xschem <verb>`, a 663-line Tcl
   file reproduced a compiled tool's built-in with zero engine risk, zero rebuild, and
   full headless testability.

3. **Centralize every place a foreign abstraction doesn't map cleanly.** The name/lab
   split is the whole port's landmine; it lives in one three-line `name_token` and is
   funneled through everywhere. One place to be right, one place to test.

4. **Feed user input to matchers and transforms as data, never as code.** `regsub`/
   `string match` on plain variables is injection-safe by construction; isolating the
   transform in `rename_transform` makes that guarantee unit-testable.

5. **Split a pure/engine core from the UI shell** so the load-bearing logic is testable
   without a display, and the untestable widget layer stays thin.

6. **When a primitive really is missing, defer with a receipt.** Hierarchy scope was the
   one genuine gap; it was refused with a clear message, not papered over with C written
   on spec.

### If you ever DID need a new C verb

Sometimes route 1 is right — a needed primitive is genuinely absent (say, a
cross-sheet iterator). Note that this project's spec deliberately did *not* take that
route: it rules out **a new matching engine and a new C verb**, and says a missing
primitive (hierarchy-wide iteration) is **deferred, not written in C**
(`doc/claude/specs/find_helper.md:34-36`). But *if* a gap were ever real and
unavoidable, a new verb has a fixed home. New verbs are
dispatched by **first letter** (`switch(argv[1][0])` at `src/scheduler.c:11997`), so a
hypothetical native `find` would live in the `'f'` group `xschem_cmds_f`
(`src/scheduler.c:3198`) — right next to the existing `find_nth`. Put it anywhere else
and the dispatcher will never reach it. But reach for that only after you have proven the
composition of existing verbs cannot do the job. For Find Navigator, it could.
