# 0260 — the descend chooser silently gives up on an instance whose symbol carries no name= token

Status: **OPEN** — the silent `return 0`, the empty-name plumbing that causes it, and the
name-aliasing hazard that a naive fix would walk into are all measured headless (transcripts
below). What is *not* measured: the GUI key press itself (`e` → `hi_descend`, read from
`src/xschem.tcl:14175` + `:6271-6273`), and the multi-level `sch_path` degeneracy noted under
Risks.
Area: `src/xschem.tcl` `hi_descend_dialog()` (`:6165-6170`, the bail at `:6169`);
`hi_descend_target_inst()` (`:5758-5773`, the unchecked `lindex` at `:5772`);
`hi_descend()` (`:6066-6067`, same bail, same silence); the empty-name source
`set_inst_flags()` (`src/actions.c:989`); the reporting format `selected_set`
(`src/scheduler.c:11026-11031`); the name-keyed resolvers `hi_descend_inst_sym()`
(`src/xschem.tcl:5753-5756`) and `get_instance()` (`src/scheduler.c:187-208`)
Tests: `tests/headless/test_hi_descend.tcl` covers view enumeration, alternate views, symbol
view, mode, iteration and a mixed instance+wire selection (`SELGATE`, `:74-81`) — every case
with a *named* instance. Nothing anywhere selects a nameless instance. Proposed
`tests/headless/test_hi_descend_nameless_0260.tcl`
Found: 2026-08-08, in the descend silent-refusal census
(`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: [0251](0251-a-refused-descend-has-no-return-channel.md) (the discarded `0` this proc
returns is one of its instances), [0252](0252-non-subcircuit-symbols-refused-silently-after-the-chooser-offered-the-view.md)
(the *other* refusal the same two shipped symbols hit, one layer down),
[0249](0249-descend-symbol-silently-refuses-any-multi-selection.md),
[0253](0253-descend-semaphore-thresholds-disagree-and-a-zero-is-misread.md) (the `>= 2` gate at
`src/xschem.tcl:6044`, in front of this proc),
[0203](0203-stale-sel_array-descends-a-deselected-instance.md) (the other "the resolver trusts
the selection too much" defect), **0261** (descend reports success on a blank page — the
adjacent "the return value lies" case).
Spec: `doc/claude/specs/hi_descend.md`. Precedent for the empty-instname hazard:
issue **0183**, whose fix comment lives at `src/actions.c:2718-2722`.

## The defect

The descend chooser has three ways out of target resolution. Two of them talk to the user.
The third — an instance that *is* selected but whose name is the empty string — returns 0 with
no dialog, no `ciw_echo`, no `statusmsg`, and no stderr. In the GUI the user presses `e` on a
selected instance and the application does nothing at all.

```tcl
src/xschem.tcl:6165-6170
proc hi_descend_dialog {{instname {}}} {
  if {$instname eq {}} {
    if {[llength [xschem selected_set]] == 0} { return [hi_descend_pick_arm] }
    set instname [hi_descend_target_inst {}]
    if {$instname eq {}} { cmdmode::resume_all; return 0 }
  }
```

`hi_descend_pick_arm` (`:6104-6127`) always speaks — `ciw_echo "hi_descend: click the instance
to descend into (ESC to cancel)"` at `:6125`, or the headless fallback at `:6106`. The
resolver speaks on its one failure arm:

```tcl
src/xschem.tcl:5758-5773
proc hi_descend_target_inst {inst} {
  if {$inst ne {}} {
    if {[hi_descend_inst_sym $inst] eq {}} {
      ciw_echo "hi_descend: no such instance: $inst" error
      return {}
    }
    return $inst
  }
  …
  set sel [xschem selected_set]
  if {[llength $sel] == 0} { ciw_echo "hi_descend: select an instance to descend into" error; return {} }
  return [lindex $sel 0]
}
```

`:5772` returns `[lindex $sel 0]` **unchecked**. A non-empty list whose first element is the
empty string flows straight back into `:6169`, which cannot tell that answer apart from the
resolver's own "I already told the user" `{}` — so it stays quiet and returns 0. The scripted
entry point has the identical hole at `src/xschem.tcl:6066-6067`:

```tcl
  set instname [hi_descend_target_inst $inst]
  if {$instname eq {}} { return 0 }
```

**Why an instance has no name.** `set_inst_flags()` fills `instname` unconditionally:

```c
src/actions.c:989
  my_strdup2(_ALLOC_ID_, &inst->instname, get_tok_value(inst->prop_ptr, "name", 0));
```

`my_strdup2` never yields NULL and `get_tok_value` returns `""` for an absent token, so an
instance of a symbol whose template carries no `name=` has `instname == ""` — empty, never
NULL. That is not an inference; the codebase already states it, in the comment the 0183 fix
left behind at `src/actions.c:2718-2722`:

```c
    /* instname is "" (never NULL -- set_inst_flags() fills it via my_strdup2 +
     * get_tok_value) when the scope symbol's template carries no name= token. …
     * Issue 0183. */
```

**Why `llength` is 1 and not 0.** `selected_set` brace-wraps each instname with no emptiness
check:

```c
src/scheduler.c:11026-11031
        } else if(what == ELEMENT && xctx->sel_array[n].type == ELEMENT) {
          i = xctx->sel_array[n].n;
          if(first == 0)  Tcl_AppendResult(interp, " ", NULL);
          Tcl_AppendResult(interp, "{", xctx->inst[i].instname, "}", NULL);
          first = 0;
        }
```

so a nameless instance is reported as the well-formed two-character result `{}` — a list of
length **1** whose element 0 is `""`. The wrapper's `llength … == 0` pick-arm test at `:6167`
is therefore not taken (something *is* selected, correctly), and the empty element reaches the
silent bail. The brief's load-bearing step holds as written: `selected_set` does **not** drop
empty names.

**This is not a synthetic case.** Eight symbols in `xschem_library/devices/` carry a
`template=` but contain no `name=` token anywhere — `arch_declarations.sym`,
`architecture.sym`, `attributes.sym`, `netlist_options.sym`, `package.sym`,
`package_not_shown.sym`, `port_attributes.sym`, `use.sym` — and 27 instances of them appear
across 21 shipped schematics, `xschem_library/logic/test_ngspice.sch` among them. The
distribution is lopsided and worth knowing before writing a fixture: `use` 19, `arch_declarations`
4, `netlist_options` 2, `architecture` 1, `package_not_shown` 1, and `attributes`, `package`,
`port_attributes` **0** — those last three ship as symbols but no shipped schematic instantiates
them, so `attributes.sym` is not a usable fixture despite being the obvious candidate.

## Reproduce

Fixture: the shipped `xschem_library/logic/test_ngspice.sch`, which holds two nameless
instances (`use.sym` at index 2, `netlist_options.sym` at index 14). `ciw_echo` is a no-op
under `--nogui` (`src/ciw.tcl:113-120`), so the script wraps it to capture every line that
*would* have reached the user; `hi_descend_enum_views` is wrapped only to observe which
instance the chooser resolved.

```
$ ./src/xschem --nogui --pipe -q --script .../rep0260.tcl
loaded: /home/analog/dev/xschem-claude/xschem_library/logic/test_ngspice.sch
instance_list row 2: name={} sym={use.sym} type={use}
instance_list row 14: name={} sym={netlist_options.sym} type={netlist_options}
nameless instance index = 2  (total instances 28)
--- A: nothing selected ---
selected_set   = ||
llength        = 0
hi_descend_dialog -> 0
echoes         = {error {hi_descend: select an instance to descend into}}
resolved       = __none__
--- B: the nameless instance selected ---
selected_set   = |{}|
llength        = 1
lindex 0       = ||
hi_descend_dialog -> 0
echoes         =
resolved       = __none__
hi_descend     -> 0
echoes         =
hi_descend_target_inst {} -> ||
echoes         =
```

A is the working refusal: one message. B is the defect: **three** entry points
(`hi_descend_dialog`, `hi_descend`, `hi_descend_target_inst`) each return the failure value
with an empty echo list. `resolved` never changes, so the chooser never even reached view
enumeration.

The control confirms the bail is strictly earlier than anything else on the path. With a
*named* instance selected, resolution succeeds and `hi_descend_dialog_body` runs far enough to
build the modal toplevel — which is exactly what `--nogui` cannot do:

```
--- C control: NAMED instance reaches the dialog body ---
rc=1 res=|invalid command name "toplevel"|  echoes=
```

**The aliasing hazard, measured.** Every resolver downstream keys off the *name*, and the
empty name is not unique — `hi_descend_inst_sym` (`src/xschem.tcl:5753-5756`) returns the
first match:

```
--- aliasing: what an empty instname resolves to ---
hi_descend_inst_sym {}      = |use.sym|
hi_descend_enum_views {}    = |{schematic schematic .../devices/use.sch} {symbol symbol .../devices/use.sym}|
```

That was measured with the **netlist_options** instance selected: had the empty name been let
through, the chooser would have offered the views of `use.sym` — a different cell. `get_instance()`
(`src/scheduler.c:187-208`) has the same linear `strcmp` scan and the same behaviour from C:

```
xschem descend -inst {} -> 0
```

no `instance not found` error, because index 2 *was* found and selected; the 0 comes from the
type check further down. So the silence is guarding something real. It is guarding it in the
wrong place, and without saying so.

**What descending into a nameless instance actually does today**, when the chooser is bypassed.
`descend_symbol()` builds the hierarchy path by concatenating `instname` (`src/save.c:5596-5600`):

```c
  /* build up current hierarchy path */
  my_strdup(_ALLOC_ID_,  &str, xctx->inst[n].instname);
  my_strdup(_ALLOC_ID_, &xctx->sch_path[xctx->currsch+1], xctx->sch_path[xctx->currsch]);
  my_strcat(_ALLOC_ID_, &xctx->sch_path[xctx->currsch+1], str);
  my_strcat(_ALLOC_ID_, &xctx->sch_path[xctx->currsch+1], ".");
```

and with an empty `instname` that is a doubled separator:

```
--- descend_symbol (key I) on the NAMELESS netlist_options instance ---
before: currsch=0 sch_path=|.| sch=test_ngspice.sch
descend_symbol -> ||
after : currsch=1 sch_path=|..| sch=netlist_options.sym
back  : currsch=0 sch_path=|.| sch=test_ngspice.sch
--- descend_symbol on a NAMED instance (control) ---
descend_symbol -> ||
after : currsch=1 sch_path=|.l2.| sch=title.sym
```

Key `i` therefore **succeeds** on the very instance key `e` gives up on: the symbol view opens,
`go_back` returns cleanly, and the only casualty is a degenerate `..` path. The C schematic
descend refuses the same instance, but for an unrelated reason — the `type` gate at
`src/actions.c:3620-3624` rejects `netlist_options`, which is [0252](0252-non-subcircuit-symbols-refused-silently-after-the-chooser-offered-the-view.md),
not this issue:

```
--- D: C descend on the nameless netlist_options instance ---
selected_set=|{}|
xschem descend -> |0|  currsch=0 schname=test_ngspice.sch
echoes=
```

Note also that `descend_schematic()` handles the empty name *deliberately* rather than
refusing it (`src/actions.c:3634-3645`): `if(xctx->inst[n].instname && xctx->inst[n].instname[0])`
… `else { my_strdup2(_ALLOC_ID_, &str, ""); inst_mult = 1; }`. The C layer tolerates
namelessness; only the Tcl chooser treats it as unspeakable.

**Not reproduced:** the GUI keystroke. `src/xschem.tcl:14175` binds `<Key-$hi_descend_key>`
(default `e`) to `hi_descend_keybind_script` (`:6271-6273`), whose body is
`if {[expr {%s & 0x4c}]} {xschem callback …} else {hi_descend}; break` — a plain press calls
exactly the `hi_descend` measured above, so the user-visible consequence (press `e`, nothing
happens, no message anywhere) follows from the transcript, but was read from source rather
than clicked.

## Fix, if it is to be closed

Three layers, in increasing order of ambition. The first is the issue; the others are what the
first exposes.

**1. Say why (required).** Split the resolver's two `{}` returns so the caller can tell
"already reported" from "nothing to report". Cheapest correct shape — echo at the point of
knowledge, in `hi_descend_target_inst` at `src/xschem.tcl:5772`:

```tcl
  set n [lindex $sel 0]
  if {$n eq {}} {
    ciw_echo "hi_descend: the selected instance has no name= property; it cannot be addressed by name" error
    return {}
  }
  return $n
```

Do **not** move the check up into `hi_descend_dialog`'s `:6169` guard: `hi_descend` (`:6066`)
shares the resolver and needs the same message, and the scripted path is where a silent 0 is
most damaging.

**2. Decide what descending into a nameless instance means.** A refusal is defensible for the
schematic view — the hierarchy path is name-built (`src/save.c:5596-5600`, `src/actions.c:3719-3722`)
and an empty component yields the degenerate `..` measured above. It is *not* defensible for
the **symbol** view, which key `i` already opens successfully on the same instance, and which
`hi_descend_enum_views` always appends (`src/xschem.tcl:5814-5817`). The honest chooser offers
the symbol view, greys the schematic view, and labels the reason. That is a strictly larger
change than (1) and can land separately.

**3. Stop keying the chooser on the name.** The root defect is that `selected_set` reports
instances by a field that is neither required nor unique, and every resolver downstream
(`hi_descend_inst_sym`, `hi_descend_enum_views`, `hi_descend_iters`, `get_instance`) does a
`strcmp` against it. `xschem selection` already exists and already returns `{type index col id}`
per object (`src/scheduler.c:11052-11059`) — an index-carrying chooser has neither the silent
bail nor the aliasing, and would also fix the "`descend -inst {}` descends a different
instance" behaviour measured above. Largest change; the one that actually closes the class.

## Risks

- **A naive fix is worse than the silence.** Letting the empty name through to
  `hi_descend_enum_views` enumerates the views of whichever nameless instance comes first in
  the array — measured: `use.sym` while `netlist_options` was selected. Any change here must
  either keep refusing or switch to index addressing (fix 3); it must not "just remove the
  guard".
- **The echo changes every caller.** `hi_descend_target_inst` is shared by the dialog, the
  scripted `hi_descend`, and the verb-noun pick continuation. `tests/headless/test_hi_descend.tcl`
  asserts on descend outcomes rather than on echo text, so it should be unaffected, but that is
  read from the file, not run.
- **The message may not survive.** Per [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md),
  statusbar text is wiped by the coordinate readout; `ciw_echo` only lands if the CIW is open.
  An echo-only fix can still leave a desktop-launched user with nothing. Whether this deserves
  an `alert_` is a policy call shared with the rest of the census.
- **Multi-level path degeneracy, unverified.** One nameless level gives `..`; two would give
  `...`, and two *different* nameless instances at the same level are indistinguishable in
  `sch_path`. `sch_path_hash` is recomputed from that string, so highlight and backannotation
  attribution could collide. Only the single-level case was measured; if fix (2) opens the
  symbol view for nameless instances, this needs measuring first.
- **Scope creep into 0252.** The two shipped nameless symbols (`netlist_options`, `use`) are
  *also* non-subcircuit types, so a user who gets past this issue immediately hits the next
  silent refusal. Fixing 0260 alone converts "nothing happens" into "one message, then nothing
  happens" unless 0252 lands with it.
