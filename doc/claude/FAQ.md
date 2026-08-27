# FAQ

Running Q&A spanning the connected threads of XSCHEM internals work done in
this repo: the input action-registry / binding-table work (branch
`feature/action-registry`), the action-logging / CIW work (branch
`feature/action-logging`), and the scriptability / stable-object-handles work
(branch `feature/stable-object-handles`) — plus general questions about the
XSCHEM data model that come up along the way. Each entry records the **project
state when it was asked** (branch + HEAD commit + phase), because answers are
often tied to how much of a refactor had landed at that moment — a later phase
may make an old "no" a "yes."

Newest entries on top.

---

## Q57. My sabotage run reddened a big pile of rows and I blamed the guard. How do I know it was the guard?

- **Asked:** 2026-08-27
- **Project state:** branch `annotate`, issue **0876**/**0879**, the A3h
  hardening pass on `utils/annot_mode.tcl`.

**Check the brace balance of the file you just edited, before you run anything.
A one-line `sed` into a braced Tcl body is a structural edit, and a broken one
reports a SUPERSET of reds that looks exactly like a well-covered guard.**

Measured. Neutralizing `cadence::_annot_ciw` by replacing *one line* of its body
with `return 0` left an unmatched `}` that closed the proc early. That variant
reddened **twelve** rows. Replacing the *whole proc* reddens the **three** the
guard actually owns. The twelve-row result is not a stronger signal than the
three-row one — it is a different bug, in the test harness, wearing the guard's
name.

This is almost certainly how issue **0876** came to record an S15b result that
three later runs could not reproduce, and whose stated cause is mechanically
impossible. The lesson generalizes past Tcl: **a sabotage variant that reds more
than you predicted is a reason to re-check the edit, not a reason to upgrade your
confidence.** A guard's blast radius can genuinely surprise you (S5 here reddened
13 rows against a predicted 1, correctly) — so the discriminator is not the count,
it is whether the file still parses as you intended.

The check costs one line and there is no excuse for skipping it:

```tcl
set f [open utils/annot_mode.tcl]; set d [read $f]; close $f
puts "complete=[info complete $d]"
```

`CLAUDE.md` already warns that **braces inside Tcl comments count**. This is the
same hazard from the other end: braces inside the text you *delete* count too.

---

## Q56. The restored binary's md5 doesn't match the original. Did my sabotage restore fail?

- **Asked:** 2026-08-27
- **Project state:** branch `annotate`, issue **0876**, sabotaging guard **G10**
  at `src/scheduler.c:2372`.

**Probably not — check the SOURCE, not the binary. `src/scheduler.c:4343`
compiles `__DATE__ " : " __TIME__` into the program, so two back-to-back builds
of byte-identical source differ.**

Measured: exactly **one** byte differs between two such builds, a seconds digit,
confirmed with `cmp -l`. The other three files in that guard set — `save.c`,
`actions.c`, `callback.c` — do rebuild bit-identically, which is the trap: the
first several restores in a session reproduce the original md5 exactly, you come
to trust binary md5 as your restore check, and then the one variant that touches
`scheduler.c` looks like a failed restore and sends you hunting.

**The valid restore checks, in order:** `md5sum` the *source* against its backup;
`git diff HEAD -- src/` empty; `grep -rn SABOTAGE src/ utils/` empty; and the
baseline suite green. Binary md5 is a convenience that is only sound for
translation units with no `__DATE__`/`__TIME__`.

Related, and the reason this matters at all: the house rule is `cp backup
src/file.c && touch src/file.c`, **never `cp -p`**. A preserved mtime makes
`make` a no-op and every later number is measured against the previous sabotage's
binary — a failure that produces confident, green, meaningless output.

---

## Q55. I put a guard at the top of the function. Why did the thing it guards against still happen?

- **Asked:** 2026-08-27
- **Project state:** branch `annotate`, issue **0872**, `cadence::annot_mode` in
  `utils/annot_mode.tcl`.

**Because the function went and CHANGED the state the guard had inspected. A gate
that runs before a search cannot speak for what the search brings back.**

The shape, and it is worth recognising because it reads as correct in review:

```
proc do_the_thing {} {
  if {![state_is_acceptable]} { return }   ;# the gate
  ...
  if {nothing is attached} {
     find_a_candidate_and_attach_it        ;# the state the gate inspected is now different
  }
  ...
  announce_success
}
```

RULING **0856** says the OP chords must do nothing, silently, on a transient
database. A gate was added at the top of `cadence::annot_mode` asking
`xschem raw sim_type`, and it deliberately answers **yes when nothing is
attached** — it has to, or pressing `6` with no database could never go and find
one. Measured: with a transient at the candidate path and nothing attached, one
`Alt-6` still wrote the mask, still attached the transient, and still announced
*"OP annotation ON (node voltages) -- loaded &lt;that transient&gt;"*. One key press
from the most ordinary desktop state there is, past a guard written for exactly
that ruling.

**The fix is to ask again, after the state changes, and UNWIND** — not to
strengthen the first ask. Making the first gate refuse a no-database session was
measured and reds six rows, because `6` with nothing loaded must still search,
still load, and still name the file it could not find.

Two details the unwind got wrong on the first attempt and that generalize:

* **Restore what the user had, not a zero.** The mask goes back to `$cur`. A
  press must not clear bits the press did not set.
* **Undo the side effect, not just the flag.** The database this proc attached
  itself is detached. Leaving a transient attached is not "nothing" — the
  waveform viewer would hold data the user never loaded, and cursor motion would
  start publishing from it.

**Why no suite caught it:** one row exercised the refusal with a database already
attached; another exercised the candidate search with no database on disk.
**Nothing composed them** — nobody put a transient at the candidate path. That is
the identical test-gap shape as issue **0869** one layer up, and it is the shape
to go looking for whenever two rows each cover "half" of a path.

---

## Q54. I bound `<Alt-Shift-Key-6>` and my chord never fires. Why?

- **Asked:** 2026-08-27
- **Project state:** branch `annotate`, issue **0868** (the transient annotation
  chord), `src/cadence_style_rc`.

**Because on a US layout Alt+Shift+6 is not "6 with two modifiers" — it is the
keysym `asciicircum`, and Tk dispatches on the keysym.**

Measured with `wish` on `:99`. Keycode 15 is the pair `6 asciicircum`, so:

```
K plain-6            (keysym=6 state=0x00) -> KEY-6
K Alt+6              (keysym=6 state=0x08) -> ALT-KEY-6
K Alt+Shift+6-as-6   (keysym=6 state=0x09) -> ALT-KEY-asciicircum
K Alt+Shift+6-real   (keysym=asciicircum state=0x09) -> ALT-KEY-asciicircum
K Shift+6-real       (keysym=asciicircum state=0x01) -> NOTHING
```

Note the third line: even an event **synthesised** with keysym `6` plus Shift+Alt
dispatches to `<Alt-Key-asciicircum>`. `<Alt-Shift-Key-6>` never fires at all.

So the real bind is `<Alt-Key-asciicircum>`; the `<Alt-Shift-Key-6>` form is kept
only as the documented **non-US-layout fallback**, where the shifted `6` is
something else entirely. `src/cadence_style_rc` already recorded the identical
gotcha for Ctrl-Shift-4 → `dollar`, one screenful above.

**Why this bites so hard:** a landing that writes only the Shift-Key-6 form passes
every behavioural row in the tree — the mode itself works when driven from Tcl —
and is dead under the user's fingers. Nothing but a **structural** row (0868's
V20, which greps `cadence_style_rc` for both spellings) can see it, and no
automated row can press a physical Alt+Shift+6 at all; that stays a `look` debt.

---

## Q53. "Only when the user requests it" — is a scripted `xschem set cursor2_x` a request?

- **Asked:** 2026-08-27
- **Project state:** branch `annotate`, issues **0865** / **0868**, ruling D5-1.

**Unratified, and it is the sharpest question the annotation work has produced.**
The A3 crew answered *yes* and the user has not yet ruled (rule debt `0868`).

Issue 0865's complaint is real: with *Simulation > Graphs > "Live annotate probes
with 'b' cursor"* in its shipped **unticked** state, the sheet was acquiring a
node-voltage annotation nobody asked for, and then holding it while the cursor
moved away — a number not measured for the state it is shown in, RULING D5-1.

0865's own ruling was "gate every ungated publisher on that box". Measured, the
inventory behind it is wrong in both directions: `src/scheduler.c:12080`, named as
a publisher, sits inside `#if 0` and is **dead code**; and the
`backannotate_at_cursor_b_nograph()` arm of the same `xschem set cursor2_x` is a
**fourth** publisher nobody listed.

The distinction that was drawn instead:

| publisher | verdict | why |
|---|---|---|
| `raw_read()`'s tail (`save.c`) | **gated** | loading a waveform file is something the PROGRAM does |
| `descend_schematic()`'s tail (`actions.c`) | **gated** | so is descending a hierarchy |
| both `xschem set cursor2_x` arms (`scheduler.c`) | **left publishing** | somebody TYPED a sentence naming a time |

Supporting measurement: the waveform viewer's own `cursor_toggle` does
`xschem new_schematic switch` **first**, so its `set cursor2_x` publishes inside the
VIEWER's context and never reaches the design sheet. And gating the verb would
touch 43 call sites across five suites, three of which never mention the box, while
buying nothing — both plans leave the identical residual, a requested snapshot that
persists while the cursor moves on.

**What makes the residual acceptable at all** is the on-request door built beside
it (0868): before it existed, no gesture in the program could re-measure a
published number — not `s`, not the chord again, not `Ctrl-6` then the chord.

---

## Q52. A test says the value is on the schematic, and the schematic is blank. Why?

- **Asked:** 2026-08-27
- **Project state:** branch `annotate`, issues **0864**/**0865**/**0866**, ruling 0614.

**Because `xschem translate` is not a paint measurement, and two careful
findings came apart on exactly that.**

A node voltage reaches the sheet in two stages. First the token expands:
`xschem translate <inst> {@spice_get_voltage}` reads
`xctx->raw->cursor_b_val[]` under `!raw_is_digital(raw) && sch_waves_loaded()
>= 0 && annot_p >= 0` (`src/token.c`). Then, and only then, the text has to
survive **`text_hidden()`** (`src/actions.c`), where annotation classes answer to
the `annot_show` mask that `6` / `Alt-6` / `Ctrl-6` write. The mask's resting
value is 0, so a freshly loaded raw expands the token and paints nothing.

Measured on one fixture, one binary, one run — the difference is the whole point:

```
P1 shipped annot_show=0:  token='4'  PAINTED texts = d
P2 after Alt-6 (mask 2):  token='4'  PAINTED texts = d 4
P4 after Ctrl-6 (mask 0): token='4'  PAINTED texts = d
```

0864's verification used `translate` and concluded both that loading a raw paints
numbers nobody asked for and that no control takes them off again. Neither is
true; the mask does both jobs. **If a row or a probe claims something is or is
not on the schematic, it must read an SVG or PS export (or pixels).** The
suite's own `opa_l_print2` / `opa_l_seen` helpers exist for this.

---

## Q51. I unticked "Live annotate probes with 'b' cursor" and pressed `6`. Why did the box tick itself back on?

- **Asked:** 2026-08-27
- **Project state:** branch `annotate`, issue **0864** (fixed), **0865** (open).

**It was a bug, it is fixed, and the box now ships OFF.**

The checkbutton in **Simulation > Graphs** promised one thing — follow cursor B
and re-annotate as it moves — and secretly did a second: it was the *first* gate
on whether annotation RENDERED at all, in two places at once
(`op_annot::_annotated` for the device OP block that `6` draws, and six
`cursor_b_val[]` gates in `src/token.c` for the node voltages `Alt-6` draws).
Because unticking it blanked everything, the annotate path force-ticked it back
(`tclsetboolvar("live_cursor2_backannotate", 1)`) so `6` would still show
something — upstream's own patch for the same coupling, `89d847fb`, papering
over `96f80d1d`.

0864 split the two. The switch is no longer a render gate in either language,
the force-set is gone, and the default is back to upstream's original `0`. `6`
and `Alt-6` paint exactly what they painted before; what needs the box ticked is
the *following*: with it off, dragging cursor B no longer repaints the sheet.

⚠ **The half that is still open is 0865.** With the box off, a value that is
already on the sheet does not follow the cursor and `Alt-6` will not refresh it,
so the schematic can hold a number measured at a time point the cursor has left.
`Ctrl-6` clears it; ticking the box makes it follow again.

---

## Q50. My node voltages disappeared. I load a raw and the nets are bare until I press something. What changed?

- **Asked:** 2026-08-22
- **Project state:** branch `annotate`, issues **0613**/**0614**/**0615**/**0621**, spec `op_annotation.md` §4.8.

**They are now behind the annotation switch, on purpose — and the resting value
of that switch is `0`, which is the part nobody has ratified yet (issue 0621).**

Before this change, `@spice_get_voltage` texts on `lab_pin` / `ipin` / `opin` /
`vdd` / `lab_wire` / `ngspice_probe` — and the branch currents on `ammeter` /
`capa` / `ind` / `diode` / `isource` / `bsource` / `cccs` / `vsource` — appeared the
moment a raw was loaded, whatever the annotation mask said. That was the complaint in 0613
("node voltages are already displayed without asking for them") **and** the reason
`Ctrl-6` did not mean "everything off": it cleared the device OP blocks and left
every node voltage painted. Both halves are the same defect, and fixing it means
the voltages now follow `annot_show` bit 1.

⚠ **The two classes are on DIFFERENT bits (issue 0678).** Node voltages follow
bit 1 (`Alt-6`); **branch currents follow bit 0 (`6`)**, beside the device OP
blocks. 0614 first put both on bit 1; the user drove a real sky130 bench on
2026-08-24 and ruled the other way — a source's branch current is *that device's*
terminal current, i.e. device OP info like a FET's `id`, while a node voltage is a
property of the *net*. `Ctrl-6` still clears both, because it clears both bits.

### Three ways to get them back

```tcl
# 1. the chords, in a cadence_style_rc session
Alt-6                    ;# adds node voltages
6                        ;# adds device OP blocks AND branch currents

# 2. the menu, in the ASE-L session this schematic is bound to (issue 0682)
ASE-L > Results > Annotate > DC Node Voltages       ;# bit 1
ASE-L > Results > Annotate > Operating Point info   ;# bit 0
#    ⚠ THE `View > Show / Hide` PAIR IS GONE since 2026-08-24. It shipped for two
#    days (issue 0457(b)) and the same user reversed the placement on a real
#    sky130 bench: "We want to be like Cadence. It needs to ONLY be in ASE-L >
#    Results > Annotate > Operating Point Info", because "results (including OP
#    info) only make sense when there is a result loaded". Both entries are GREYED
#    until the session has a raw on disk, and ticking one attaches that raw to the
#    design if nothing is loaded there yet.

# 3. permanently, in ~/.xschem/xschemrc
set annot_show 2         ;# node voltages on from startup
set annot_show 1         ;# device OP blocks + branch currents on from startup
set annot_show 3         ;# ... both -- and THIS is the pre-0614 stock behaviour,
                         ;#     not 2: before 0614 the node voltages AND the branch
                         ;#     currents were both always-on (issue 0621)
```

### The chords are ADDITIVE now, which is not how they used to work

| chord | what it does | what it does NOT do |
|---|---|---|
| `6` | `annot_show \|= 1` — adds device OP blocks **and branch currents** (issue 0678) | never removes node voltages; **not a toggle** — press it twice and nothing changes |
| `Alt-6` | `annot_show \|= 2` — adds node voltages | never removes OP blocks |
| `Ctrl-6` | `annot_show = 0` | — this is the **only** off switch |

So `Ctrl-6` then `Alt-6` gives you node voltages **alone**, which the old
three-state cascade could not produce.

### And they are a different colour now

Node voltages moved to **layer 9** — white on the default dark palette, teal
(`#00aaaa`) on the light one — so you can tell them apart from the six-row device
OP block, which stays layer 15 (`#ff7777`). Branch currents keep layer 17
(`#00ffcc`). Remap or disable in one line:

```tcl
set annot_voltage_layer 4     ;# any layer index
set annot_voltage_layer -1    ;# off: fall back to each text's own layer=
```

⚠ Two gotchas worth knowing. **Disabling layer 9 in the Layers menu silently
removes every node voltage** — it looks exactly like the feature being broken.
And on a sheet built from the generic `devices/nmos4` / `pmos4` symbols, the
`vgs=` / `vds=` rows are a single composite text that the switch does **not**
reach, so they survive `Ctrl-6` in the OP block's colour (issue **0623**).

---

## Q49. Why is `@spice_get_current<n>` not handled anywhere, when the source mentions it?

- **Asked:** 2026-08-22
- **Project state:** branch `annotate`, issue **0614**, spec `op_annotation.md` §4.8.

**Because it does not exist.** It has no branch in `token.c` and never had one.
Its **only** appearance anywhere in the tree is a stale comment at
`save.c:5743` — `/* @spice_get_current or @spice_get_current<n> */` — and that
comment is where every later list of "the annotation token spellings" was
transcribed from, including issue 0614's own five-item list. A text spelled that
way renders nothing.

The real set is **six**, all verified live against a two-vector OP raw:

| spelling | handler | renders |
|---|---|---|
| `@spice_get_voltage` | `token.c:4821` | the net's voltage |
| `@spice_get_voltage(<net>)` | `token.c:4912` | ditto, named net — and the LCC rewrite at `save.c:5722` builds the **dotted-path** form `@spice_get_voltage(x1.inv.vout)` |
| `@#<pin>:spice_get_voltage` | `token.c:4315` | the pin's net voltage. The pin may be a **name** (`@#A:`) or an index (`@#0:`), and it may carry a bus range (`@#A[3:0]:`) |
| `@spice_get_diff_voltage` | `token.c:5094` | the two-pin difference |
| `@spice_get_current` | `token.c:5163` | the device branch current |
| `@spice_get_current_<param>(…)` | `token.c:4989` | a named device current |

`@spice_get_modelparam_<p>` and `@spice_get_modelvoltage_<p>` **are** matched (by
the regex at `token.c:4646`) and then silently produce nothing — issue **0418**.
That is why the annotation classifier deliberately does not classify them.

If you are writing a classifier over these, match the **whole string** (after
truncating at the first `(` when `)` is the last character), never a substring:
the tree ships 119 `@spice_get_node` records and 158 `vgs=…@#1:spice_get_voltage
- @#2:spice_get_voltage` composites that a substring match sweeps up, and they are
device OP info, not node voltages.

---

## Q48. My sky130 transistors used to show `id=` and `gm=` as soon as I loaded a simulation. They stopped. Where did they go, and how do I get them back?

- **Asked:** 2026-08-22
- **Project state:** branch `annotate` @ `df53d254` — issues **0475**, **0476**, **0457**, spec `op_annotation.md` S10.

**They were switched off on purpose, and there is a one-click way back.**

sky130's 40 shipped FET symbols each carried four texts baked into the symbol
file — `id=`, `gm=`, `vgs=`, `vds=` — 119 records in all. They rendered whenever
a raw was loaded, with no way to turn them off. The OP-annotation work replaces
them with one formatted block (six values by default: `id gm gds vgs vth vds`),
so leaving both on would print two sets of numbers over each other. The 119
records gained one token, `hide=true`.

### Getting the old texts back

**View > Show hidden texts.** That is the whole escape hatch — the token is
`hide=true`, which answers to `show_hidden_texts` and *not* to `annot_show`, so
the four come back at any annotation setting. Scriptable as:

```tcl
xschem set show_hidden_texts 1 ; set ::show_hidden_texts 1
xschem update_all_sym_bboxes
```

Set both halves. The C field is what drawing reads; the Tcl variable is what the
menu checkbutton and a later pull read, and writing only one leaves them
disagreeing.

**Permanently, for your own library**, delete the token from the symbol files:

```sh
find sky130A/xschem_libs/sky130_fd_pr -name '*.sym' \
  -exec perl -0pi -e 's/\{layer=(15|17)\nhide=true\}/{layer=$1}/g' {} +
```

Check first with `grep -rc 'hide=true' sky130A/xschem_libs/sky130_fd_pr --include='*.sym'`
— expect 119 records across 40 files before, 0 after.

### Why this is not simply a loss

Three things, in order of how much they matter:

1. **With no raw loaded the old texts were noise.** They rendered literally as
   `id=-  gm=-  vgs= -  vds= - ` on every transistor in the schematic. The new
   block draws nothing at all until there is data.
2. **The new block shows more, and formats it.** Six values in an aligned
   monospace column instead of four values in four separately-placed texts, with
   engineering suffixes and a consistent width.
3. **It is one keystroke.** `6` turns annotation on, `Ctrl-6` off, `Alt-6`
   cycles. The old texts had no switch of any kind.

### The honest catch

The new block only fires if XSCHEM has loaded `sky130_procs.tcl`, which happens
via `sky130A/cadence_style_rc`. **If your rc never sources it, you get neither
the new block nor the old texts** — that is real subtraction, and it is issue
0475's whole question. Ratified 2026-08-22: ship it, with *Show hidden texts* as
the way back. Issue **0457** tracks the missing stock control for the mask, and
until it lands the `6` key is the only affordance outside the cadence profile.

### What hiding them did NOT fix

Measured on the sky130 `bandgap_opamp` bench, 2026-08-22: the annotation block
still collides with the symbol's **geometry** text — `pfet_01v8`, `nf=1`,
`1 x 1 / 6` — and with the `VCC`/`VSS` pin labels, none of which carry a `hide=`
token or answer to any knob. On a typical instance **4 of the 6 rows are
unreadable**. Two adjacent devices in that schematic, `M2` and `M18`, show it
cleanly: identical code, one perfectly legible, one destroyed, purely by where
the block landed. That is issue **0605**, ruled 2026-08-22 as "the overlay's
position, size, layer, font and anchor will all become user-controllable —
later, after basic functionality."

So: hiding `id=`/`gm=` bought **no space**. It removed the duplicate, which was
its actual job.

### Not sky130

gf180's 38 records have shipped with `hide=true` all along. **IHP is the one PDK
whose annotation texts still answer to no knob at all** (2 inductor records plus
`annotate_fet_params`), as do 30 records in `xschem_library/devices/*.sym` —
issue **0476** records that as a deliberate omission, not an oversight.

---

## Q46. `xschem move_objects END` did nothing and my test still passed. Is a typo'd sub-verb an error now, and how far does the check reach?

- **Asked:** 2026-08-12
- **Project state:** branch `open_pdk` @ `d99f3791` + this session — issue **0266** (item D10).

**Yes — but only in the first two argument slots of the one-shot form.** Know exactly where the
line is, because the interesting half of this answer is what is still silent.

The mechanism: the verb dispatched on `argv[2]` with four bare `strcmp`s against the lowercase
literals `start`/`step`/`end`/`abort`, and *everything else* fell into the one-shot coordinate form,
whose only commit-vs-arm discriminator was an argument **count** (`argc > 3 + nparam`). Nothing ever
asked whether `argv[2]` was a number, so `atof()` turned every typo into `0.0`. Three shapes of
silent wrong answer followed, all measured: `move_objects END` armed a **deferred menu move**
(`ui_state 296 → 65832`) and committed nothing — the next ESC then deleted the paste the caller
believed it had dropped; `move_objects END 40 40` was worse, because `argc` alone put it on the
commit path with `dx = atof("END") = 0.0`, writing the document at the wrong coordinate with rc 0;
and a **truncated** `move_objects 40` armed too, which is the replay hazard, since a log is
`source`d as Tcl and every spelling answered `TCL_OK`.

**The ratified answer, in three parts:**

1. **A verb that cannot mean what it was handed says so.** An unrecognised, non-numeric dispatch
   slot is now a `TCL_ERROR` naming the token, not a silent arm. The sub-verbs stay
   **case-sensitive on purpose** — the alternative on the table was to accept `END` via the tree's
   existing `my_strcasecmp`, and that was rejected because it only *widens* the grammar of a verb
   whose log-replay surface wants exactly one spelling, and it still leaves `foo` and a truncated
   `40` arming silently. This is user-visible: a script that used to run past the no-op now aborts
   at that line. That is the point.
2. **Validate the argument shape, never the program state.** The check inspects only the TYPE and
   COUNT of the verb's own arguments. It adds no precondition to `move_objects <dx> <dy> …`, which
   still commits from any `ui_state` — that form is the replay/test seam (`WIRING.md` landmine 2),
   and gating it is how you break every test that drives the editor without a mouse.
3. **Order: refuse read-only first, validate second, side-effect third.** `scheduler_readonly_reject`
   stays the first statement of the branch, so a read-only buffer still answers "read-only" even for
   a bad spelling — the more important thing to tell the user. And the validator runs *before*
   `connect_by_kissing` is armed and before `select_attached_nets()` grows the selection, so a
   rejected line leaves nothing behind. Both orderings have a dedicated sabotage variant and a
   single witness row each; relocating the call by four lines reddens exactly one check.

**Where the line is** (this is the part to remember): the check guards `argv[2]` and `argv[3]` of the
**one-shot** form and nothing else. Still silent, still `atof`/`atoi`, still rc 0 —
`move_objects end END 40` commits at `dx = 0` (issue **0405**, and that is the very form the docs
recommend as the scripted commit constructor); `0 0 1 0 -anchor 50` drops the anchor and rotates
about the wrong pivot (**0406**, and truncation in that tail is what a corrupted *emitted* log line
actually looks like); `nan`/`inf` pass a `strtod` check and then corrupt or erase the saved record
(**0407**); and `copy_objects`, `rect`, `polygon`, `line`, `arc`, `circle` all still arm on an
unknown slot (**0404**). The general lesson: a validator earns exactly the promise it tests, and the
first draft of this one had three doc surfaces promising more than the code delivered.

---

## Q45. Something deselected while I was placing a label and the canvas went dead. Is that still a thing?

- **Asked:** 2026-08-11
- **Project state:** branch `open_pdk` @ `2f866dec` + this session — issue **0262** (item D8).

**No — the canvas repairs itself now. But the label you never dropped stays in the drawing, and it
still renames the net it landed on.** That trade is the whole decision, and it is deliberate.

The mechanism: `unselect_all()` zeroes `ui_state` wholesale, and a live placement preview is always
selected — so the gesture bits vanish without the placement teardown ever running. The flags that
say "a preview is live" (`sympin_preview`, `wirelabel_preview`) are *not* `ui_state` bits, so they
survived, and with them stuck the Button-1 select/grab block and `wire_label_try_commit()` both
refuse forever. **ESC could not repair it** — the teardown is gated on the very bit that is gone —
so the only recovery was to throw the document away.

Reachable how? Not just from scripts, which is what 0262 originally assumed. Measured: the
**default Ctrl+Button2 chord** (its pin-type-cycle fallback runs a bare deselect when the *Add Pin*
form is not the one that is open), the **Hilight ▸ Compare schematics** menu item (its entire body
is a deselect), and **Ctrl+S** (`save` deselects one line before it writes the file — issue
**0358**, which additionally writes the undropped object into your `.sch` and then tells you the
buffer is clean).

**The ratified answer, in two parts** — and the shape matters more than this one bug:

* **A. The dead-canvas half is fixed ONCE, class-wide, not door by door.** The tripwire that used to
  merely *report* this state now **repairs** it, at the two funnels every command and every GUI
  event passes through. So any door — the three above, or a fourth nobody has found — is now at
  worst *orphan-only*, never terminal. **No command was given a new `delete()`** to achieve that:
  gating the deselect verb would have put a silent delete behind 866 scripted call sites whose
  normal use is "deselect, then select this other thing" (including the Property form's **Cancel**).
* **B. A command that also *commits* or *persists* the stray object still needs its own gate**,
  because a repair happens afterwards and cannot un-write a file or un-emit a netlist. `netlist` got
  that gate (issue **0263**); `save` has not yet (issue **0358**).

**What you should do:** drop the label (click) or ESC it before you deselect, save or netlist —
same advice as Q41. If it happens anyway you will see one status line, *"Pending placement
abandoned…"*, the canvas will work again, and **you should look for a stray label** — undo removes
it. Watch out on a freshly-saved file: the stray object does not currently set the modify flag
(issue **0398**), so nothing will prompt you on close.

---

## Q44. Two commands both want the next Button-1. Who wins, and where is that decided?

- **Asked:** 2026-08-10
- **Project state:** branch `open_pdk` @ `ee290c5b` + this session — issue **0257** (item D6).

**The one the user pressed most recently wins, it takes ownership at its own VERB, and it must name
what it displaced.** Three ratified rules produce that answer together: "whatever you just pressed
is what you meant" (0240/0242/0243/0247/0265/0269), "gates live at the verbs, never at the shared
per-click primitive" (0243 F2), and "a teardown must name what it is tearing down" (0241).

Concretely, `xschem descend_pick` arms a click-pick. If net-highlight mode, deselect mode, or a
resting `persistent_command` wire already owns Button-1, the *press* used to be eaten by whichever
arm of `handle_button_press()` came first — the pick simply never happened, and in the wire case the
press even **started a wire** on the instance the user meant to descend into. The fix is not in the
press dispatcher. It is three statements at the top of the verb: tear down the wire/line command,
tear down the click mode, *then* set the arm bits, then say one sentence that names both
(`Descend: net-highlight mode ended -- click the instance to descend into (ESC to cancel)`).

Three things make this a pattern rather than a one-off:

* **Teardown primitives are named functions that return what they ended**, not inline bit-clearing:
  `abort_wire_line_command()`, `abort_placement_preview()`, `abort_pending_merge()`,
  `abort_shape_draw()`, and now `abort_click_mode()`. The name is what lets the caller compose an
  honest sentence, and every one of them must honour `xctx->gate_bypass` and touch no selection.
* **Order is load-bearing.** Several teardowns write `ui_state2` wholesale, so all of them run
  *before* the arming assignment. Getting this backwards silently deletes the arm you just set.
* **The gate is one-directional unless you write the other half.** D6 gated the pick against the
  modes; nothing gates the modes against a live pick, so the reverse order still swallows
  ([0386](issues/0386-entering-net-highlight-or-deselect-mode-over-a-live-descend-pick-arm-still-swallows-it.md)),
  and a live shape draw is a door nobody gated at all
  ([0387](issues/0387-descend-pick-neither-aborts-nor-names-a-live-shape-draw-and-clobbers-its-discriminator.md)).
  When you add a mode, add both directions.

A corollary about ESC: the arm's liveness test must not depend on a bit some *other* handler clears.
The descend continuation in `abort_operation()` used to require `MENUSTART && MENUSTARTDESCEND`, and
the matching ButtonRelease burns `MENUSTART` unconditionally — so precisely the stranded state that
most needs rescuing was the one ESC could not see, and command mode stayed suspended forever. The
discriminator alone (`MENUSTARTDESCEND`) is the honest test.

---

## Q43. Why did a fix with 67 green checks, a clean sabotage matrix and an adversary pass still get reverted?

- **Asked:** 2026-08-10
- **Project state:** branch `open_pdk` @ `b1326180` + this session — issues **0250/0252/0253/0261/0369** (item D5).

**Short answer: because every one of those checks addressed instances by name, and the user
addresses them by selection.** The suite and the user were exercising different code paths, so the
green was real and the workflow was still broken.

The fix added a chooser filter so the descend view list stops offering a schematic view the C guard
is going to veto (issue 0252). It decided with `xschem get_sym_type $symabs`. That command answers
correctly on a freshly loaded sheet and returns **empty once an instance is selected** — which is
exactly the state a user is in when they select an instance and press descend
([0379](issues/0379-get-sym-type-returns-empty-while-an-instance-is-selected.md)). The filter then
collapsed to a bare `[file exists]` test and dropped the schematic row for a `type=subcircuit`
whose child does not exist yet, deleting the create-the-child-by-descending workflow — the very
capability the rest of the same commit had gone out of its way to preserve.

The test row that was supposed to catch this (*"a subcircuit whose .sch does not exist yet is still
offered"*) passed, because it called `hi_descend inst=XN`. Nothing in the suite ever set a
selection first.

Three durable lessons:

1. **A test must reproduce the user's gesture, not just the user's intent.** `inst=<name>` and
   *select-then-descend* are different states. When a feature is reachable two ways, pin both, or
   the cheaper one silently becomes the only one you have covered.
2. **Sabotage verifies the mechanism you built, not the mechanism you needed.** All eight variants
   behaved, including the one aimed at this filter (S6 turned its row red exactly as predicted).
   Sabotage proves a check is load-bearing; it cannot tell you the check is asking the wrong
   question.
3. **Do not build a user-visible decision on an accessor whose stability you have not measured in
   the caller's state.** The lookup was correct in every state the tests put it in and wrong in the
   state that mattered. Read it once from the state the feature will actually run in before making
   it load-bearing.

Corollary for bundling: the 0250/0261/0369 verdict mechanism, the 0253 threshold work and the 0252
filter were independent, and one bad component forced all of them out. Land independent mechanisms
in independent commits.

---

## Q42. When should a refused operation tell the user, and when is silence the right answer?

- **Asked:** 2026-08-10
- **Project state:** branch `open_pdk` @ `ee290c5b` + this session — issues **0249/0251/0254/0256/0366** (item D4).

**Short answer: silence is correct exactly when nothing the user saw, typed or clicked
promised the operation.** Record the reason always; speak it selectively.

Descend was the case that settled it. It had thirteen refusal sites and no status protocol —
only one of them said anything, and that one used `dbg(0)`, which a desktop-launched user
never sees. A refused `xschem descend_symbol` and a successful one both evaluated to the
empty string, so no script could tell them apart.

The tempting fix — "make every refusal speak" — is wrong, and there is a committed
regression lock proving it: `tests/headless/test_descend_inert_class.tcl` pins that 262
shipped annotation symbols (`lab_pin`, `gnd`, `vdd`, `ipin`/`opin`, title blocks, probes)
must be refused **silently**. Pressing `e` with a title block somewhere in a rubber-band
selection is not a request to descend into a title block, and answering it with a status
line trains the user to ignore the status line.

So the shape is two mechanisms, not one:

- **Record always** — a reason token on the context (`xschem get descend_error`), written at
  every refusal, including the silent ones. Tests and scripts get a machine-readable cause
  even where the UI stays quiet.
- **Speak selectively** — a separate predicate decides. Loud when the user pressed the key on
  something they picked (nothing selected, ambiguous multi-selection, a `---MISSING SYMBOL---`
  box they clicked precisely to interrogate). Silent when the refusal is about an object the
  user never aimed at.

Two implementation lessons worth carrying:

1. **The silent sites must still build their message and pass `speak = 0`.** The first cut
   passed `NULL` instead, and a sabotage run that forced the predicate to "always speak" left
   the lock green — the silence came from a missing string, not from policy. A policy you
   cannot falsify is not a policy.
2. **The reason must be a second channel, never a widened result.** `xschem descend`'s
   `"0"`/`"1"` string is load-bearing in seven places, one of which compares it as a string.
   Reason codes go in a new key; the boolean stays a boolean.

**Speak via `statusmsg_hold()`, not `statusmsg()`** — a plain status message is immediately
clobbered by `select.c`'s `n= x= y= w= h=` info line (0248), so an ordinary `statusmsg()` on a
refusal is indistinguishable from not reporting at all.

**Related trap:** a refusal channel documents "empty means success", which makes every
*unreported failure* actively worse than before, because callers now trust the channel.
`descend_symbol()` still drops `load_schematic()`'s result and returns success for a failed
load — see **0369**. When you add a reason channel, audit the failure sites, not just the
refusal sites.

---

## Q41. I netlisted while a label was still riding the cursor. Is the deck safe, and where did my label go?

- **Asked:** 2026-08-09
- **Project state:** branch `open_pdk` @ `825d69ce` + this session — issue **0263**.

**The deck is safe now. The label is gone, deliberately, and the status bar tells you so** —
`Netlist: pending placement abandoned`, held for 5 s. Same for a paste riding the cursor
(`Netlist: pending paste abandoned`).

**What used to happen was much worse than "the label was included".** An undropped label preview is
a real `lab_pin` instance, so the netlister treated it as a label you had dropped and renamed
**the whole net** it happened to be sitting on. A cell that netlists as

```
R1 net1 GND 1k
R2 net1 GND 2k
```

came out as `R1 FOO GND 1k` / `R2 FOO GND 2k` — *both* devices, because it is the net that gets
renamed — in SPICE, Spectre, tedax, Verilog and VHDL alike, with no warning anywhere. And on a
hierarchical netlist the preview was then **silently committed**: the netlister saves the document,
netlists, and restores it, and the restore baked the preview in as an ordinary instance. Three ESCs
could not remove it, the modify flag still read *unmodified*, and the next save wrote it to disk.
The same round trip also turned a `place_symbol` preview into a real device and an undropped input
pin into a **port of the subcircuit**.

**Why the label is thrown away rather than kept.** This is the honest trade and it is written down
as an open question. Keeping the gesture alive across a netlist means preserving five different
pieces of gesture state through a full document save/restore, in five backend drivers. Abandoning
it is two lines at the verb, reuses the teardown every other gesture already uses, and — critically
— *the status quo was not "the gesture survives"*: the hierarchical netlist already destroyed it and
gave you an object you could not delete. So the change trades a silently wrong netlist plus an
undeletable stray object for a cancelled label you were told about.

**What you should do:** drop the label (click) or ESC it before you netlist, exactly as you already
do before saving. A netlist with nothing armed is completely unaffected — the gate is a no-op, and
that is asserted by test, because it is what keeps the committed golden decks byte-identical.

**Still rough** (filed, not fixed): if a *previous* action stripped the gesture bits without tearing
the preview down (issue **0262** — the bare `unselect_all` verb, reachable after a property edit or
from Compare Schematics), the stray object is by then an ordinary instance and the netlist will
still emit it. *(2026-08-11: 0262 has been decided — see Q45 — and this stays true. The repair
brings the canvas back and deletes nothing, so the stray object still reaches the deck, and on a
freshly-saved file `modified` can still read 0 while it does: issue **0398**.)* And pressing **undo** after the abandon brings the preview back as a committed
instance (issue **0361**) — the same thing ESC has always done.

---

## Q40. I started drawing a rectangle, changed my mind and pressed `w`. Both were armed at once and nothing worked until ESC. Fixed?

- **Asked:** 2026-08-09
- **Project state:** branch `open_pdk` @ `6e7f1c55` + this session — issue **0269**, phase 3 of
  `doc/claude/suggestions/plan_modal_gesture_exclusion.md` (the last open phase).

**Yes.** Starting a rectangle, polygon, arc, circle or zoom box and then pressing anything else now
**abandons the shape** and starts what you actually pressed. The status bar says which verb took
over (`Wire: in-progress shape abandoned`), held for 5 s.

**What was happening.** The shape draws were the last gesture family with no teardown at all. Their
state bits were set when you armed them and cleared only when the gesture *finished*, so a second
gesture armed straight on top: `r` then `w` left both live. That is not merely untidy, because the
click handler tests every shape bit **before** the branch that would let a placement or a paste land
— so while a shape is armed no click can complete anything else. With a half-drawn **polygon** it
never resolves at all: every click just adds another polygon point. ESC was the only exit, and it
had to serve two gestures at once.

**What changed for you, concretely.**

- Any draw, placement, paste, insert, undo or redo cancels a live shape draw — including the two
  cadence-mode cases where the shape is armed but you have not clicked yet.
- The reverse too: starting a shape now cancels a live wire draw, a pin/label/symbol/text preview,
  or a paste riding the cursor. It used to cancel only the wire draw.
- A half-drawn **polygon** is discarded when another gesture takes over. Pressing **ESC** on one
  still closes and commits it, exactly as before — that is the gesture's own terminal, and it is
  unchanged deliberately.
- `z` (zoom box) used to do *nothing at all* while another draw was live. It now cancels that draw
  and starts the zoom box.
- Three side defects went with it: arming a polygon no longer marks a clean file modified with
  nothing drawn (**0270**); `Ctrl+V` / File ▸ Merge now cancels a wire you were drawing, which three
  documents claimed it already did and it never did (**0271**); and `xschem circle` /
  `xschem zoom_box` — the scripted forms, whose key and menu twins were already covered — now cancel
  what is live, with `circle` also gaining the read-only refusal its `arc` sibling always had
  (**0272**).

---

## Q47. Why did a digital signal have to be "bridged" to analog before I could plot it — and is that still true?

- **Asked:** 2026-08-08
- **Project state:** branch `fluid-editing` @ `1d776f33` + this session — §C of
  `doc/claude/specs/mixed_signal_signal_browser.md`.

**It was true. As of §C it is no longer true for anything a Verilog block dumps to VCD.**

**Why it was true.** Three separate facts stacked up, and you needed all three to go away:

1. **XSPICE event nodes never enter the `.raw` file.** Not with `save all`, not with an explicit
   `save <node>`. Measured on a 2-node digital chain: `save all dclk dq` produced a raw whose
   variable list was `time i(abr2) v(aq) v(clk) i(vclk)` — both event nodes simply absent.
   ngspice's raw writer only knows about analog nodes.
2. **Under `d_cosim`, only module PORTS cross the shim boundary at all.** The shim walks
   `inputs.h`/`outputs.h`/`inouts.h` and nothing else, so a signal internal to the Verilog never
   reaches ngspice in any form, bridged or not.
3. **xschem could not read VCD.** `src/rawtovcd.c` is an *exporter*; `raw_read()` read spice raw
   and nothing else.

So the only way to see a digital node in a waveform was to give it an analog identity — put any
analog load on it (a plain `robs <net> 0 1meg` inside a code block is enough; no symbol needed) and
ngspice auto-inserts a `dac_bridge`, after which it lands in the raw under its hierarchical name.
That works, but it only ever worked for nodes at the *boundary*. An internal signal of a Verilog
module had nothing to attach a resistor to.

**What changed.** Fact 3 is gone: `src/vcd_read.c` reads a VCD into the same `Raw` structure the
spice parser produces, and registers it in `xctx->extra_raw_arr[]` as an ordinary database. Nothing
downstream knows it came from a VCD — `xschem raw info` lists it, `xschem raw value` reads it, the
Signal Browser's all-databases reader enumerates it. Fact 2 is gone too, on the simulation side:
the patched Verilator shim in `tools/cosim/` dumps the model's full internal hierarchy.

Concretely, on the reference testbench, `phase half prev next_count tc carry` appear **nowhere in
the raw file** and are now browsable.

**What bridging is still for.** Anything you want in the *raw* — because it is part of an analog
measurement, or because you want it on the same trace as an analog signal today. Plotting an analog
and a digital database on one time axis is §D and is not done yet.

**Two things to know when you look at the numbers.** A VCD stores integer ticks scaled by
`$timescale`; the reader converts to seconds once, at read time, so the X axis matches the raw with
no unit juggling. And a digital `0`/`1` reads back as `0.0`/`1.0`, while `X` and `Z` read back as
`0.5` and `0.3` — deliberately *not* `0`, so an unknown can never be mistaken for a low.

---

## Q39. I had the Add Wire Label form open, pressed `Ctrl+A`, then closed the form — and my whole schematic was gone. Is that fixed?

- **Asked:** 2026-08-08
- **Project state:** branch `open_pdk` @ `d9c6a8e5` + this session — issue **0241**.

**Yes, fixed.** And it was as bad as it sounds: no `Delete` key, no ESC, no confirmation, and the
dirty flag said *unmodified* afterwards, so the emptied drawing closed without a "unsaved changes"
prompt and `reload` succeeded silently. One `undo` brought it back in the simple case, but not if
you had edited anything after opening the form.

**Why it happened.** Cancelling a cursor placement removed the preview with an internal delete —
and that delete is *selection-scoped*. It only ever worked because the arm left exactly the preview
selected, and nothing defended that: the Add-Label / Add-Pin / Insert-symbol forms are **modeless**,
so `Ctrl+A`, Edit ▸ Select all and `select_dangling_nets` were all reachable in between, and none
of them knows a placement is armed. It was never a `Ctrl+A` bug — anything that grew the selection
did it.

**What it does now.** The arm records *what the preview is* (per-object durable ids), and the
cancel re-selects exactly that before deleting. Your other objects are deselected but stay in the
drawing. Three more doors were closed with it:

- **the form's own window-close button** (the shortest route — it calls the same cancel);
- **typing one more character in the Name field**, which re-arms and dropped the old preview the
  same way — this one needed no cancel gesture at all;
- **pressing `w`** on a live preview, which used to *refuse* while several objects were selected
  (statusbar: *"finish or ESC the pending placement first"*). That refusal existed only because of
  this bug. It is gone: `w` now abandons the placement and starts drawing like every other verb,
  and what else you had selected survives.

**Paste / merge: scoped too, as of 2026-08-08 (issue 0244 part B).** `Ctrl+V` then `Ctrl+A` then ESC
used to be the same wipe on a sibling code path, and worse — the emptied drawing also reported
itself *unmodified*, so nothing prompted. Both are fixed: the cancel now removes exactly what the
paste brought in, and the `*` stays on the title if the document had unsaved edits before the paste.
One user-visible consequence to expect: **ESC-ing a paste no longer cleans the "unsaved changes"
star**, so Close / Quit / File ▸ New prompt again where they had gone quiet. That is the intent, not
a regression.

---

## Q38. I pressed `w`, started drawing, then pressed `r`. Nothing happened — why, and what does it do now?

- **Asked:** 2026-08-07 (in the GUI, under `src/cadence_style_rc`)
- **Project state:** branch `open_pdk` @ `465223be` + this session — issues **0247** / **0248**,
  phases 1-2 of `doc/claude/suggestions/plan_modal_gesture_exclusion.md`.

**Before:** the rectangle armed but could never start. Measured `ui=65537`
(`STARTWIRE|MENUSTART` + `MENUSTARTRECT`) with `last_command=1`: two modal gestures live at once,
and the click handler tests the wire first, so every click you gave the rectangle went to the wire.
ESC was the only way out. Infix mode had the same dead end with two rubber bands on screen.

**Now:** `r` abandons the in-progress wire and starts the rectangle — the same rule `l` and `p`
already followed (Q35), and `w` in the other direction (Q36): *whatever you just pressed is what
you meant*. Nothing is committed by the abandoned draw (a wire only exists once its second point
lands), and the status bar says `Rectangle: in-progress wire abandoned`.

The rule now covers **every** verb that can arm a second modal gesture on a live wire/line draw:
the shape draws `r`, `Shift+P`, `C`, `Ctrl+C` and their context-menu picks; the placements
`Alt+Shift+L`, `Ctrl+P`, `Ctrl+Shift+P`, `t`, Graphs ▸ Add graph / Add image, context-menu Insert
symbol / Insert text, the `I` and Insert keys, and a screen grab; plus the scripted arms
`xschem rect|polygon|arc [gui]`, `net_label`, `place_text`, `place_symbol`, `add_graph`,
`add_image`. It applies in both interface modes — including `infix_interface 0` (cadence), where
the shape arms on the first CLICK, which is exactly the click the wire was stealing.

Two things it deliberately does NOT do:

- **Coordinate/commit forms are untouched.** `xschem rect x1 y1 x2 y2`, `xschem polygon ...`,
  `xschem arc x y r a b layer`, `add_wire_label -drop`, `add_symbol_pin <x> <y> ...` store an object
  outright and arm nothing, so they leave a live draw alone — they are the replay/test seams.
- **`Ctrl+V` merge is still an exception**, in both directions: a merge preview carries different
  state (`STARTMERGE`) whose teardown needs issues 0242/0244 first.

Note that a follow-up dialog cannot undo the cancel: `t` opens the text dialog and Add image opens a
file chooser *after* the wire has been abandoned, so cancelling the dialog does not bring the wire
back. That matches component insert, which has behaved this way since 2026-08-07.

---

## Q37. The status bar keeps telling me things I never see. Is it lying?

- **Asked:** 2026-08-07
- **Project state:** branch `open_pdk` @ `465223be` — issue **0248**.

It was. `.statusbar.1` (the wide right-hand field) had one writer, `statusmsg()`, and two
high-frequency clobberers: the pointer readout `mouse = x y - selected: N w= h=`, refreshed on any
event once the pointer has moved 8 pixels **and only while a gesture is armed** — which is exactly
when a gate message has something to say — and, for placement verbs, the object-info line
`n=   0 x = ... w = ... h = ...` that the editor prints when it selects the preview it just placed,
one call after the gate message. So `Wire: pending placement abandoned` was written and destroyed
before a hand already in motion could read it. Measured: 25 mouse-motion events after the gate, the
field read `mouse = 150 100 - selected: 0 w=250 h=200`.

Now a gate or prompt message **holds** the field for 5 seconds, or until your next click — the click
releases it deliberately, so the live `w=`/`h=` size readout you use while dragging comes straight
back. An ordinary status line issued while a hold is up is dropped; a newer gate/prompt line
replaces it. Scripts can post their own line with `xschem statusmsg {text}`, which always wins.

The verb-noun prompts got the same treatment: `Move: click an object to move it`,
`Copy: …`, `Stretch: …`, `Rotate: …`, `Flip: …`, `Descend: click the instance to descend into`.

---

## Q36. And the other way round — I pressed `w` while a pin/label preview was stuck to the cursor. What happens?

- **Asked:** 2026-08-07
- **Project state:** branch `open_pdk` @ `bd61efed` + uncommitted — issue **0243** F2/F3 fix.

**The pending placement is abandoned and the wire starts.** Same ratified rule as Q35, applied to
the reverse door: whatever you just pressed is what you meant. The preview instance is removed
without burning an undo entry (the arm's single baseline is the only rollback point), the statusbar
says `Wire: pending placement abandoned`, and you are drawing wire from the cursor.

This closes a genuinely stuck state, not just an untidy one. With both armed, the click handler
tests `STARTWIRE` before the placement, so every click fed the wire and the preview could never be
dropped. Add-Wire-Label had an accidental escape hatch — typing one more character in the form
re-issues its `-place`, which hits the Q35 gate and frees the wire while keeping the preview —
but **Add-Pin had none**: ESC was the only exit and it threw the pin away.

**No exceptions any more.** Until 2026-08-08 the wire verb *refused* when a **multiple selection**
was live (a `Ctrl+A` under the preview, say) and said *finish or ESC the pending placement first*:
the teardown was a delete of the selection rather than of the preview, so abandoning there would
have taken your drawing with it. Issue **0241** scoped the teardown to the preview's own identity,
so the carve-out is gone — the verb abandons the placement and starts drawing no matter what else
is selected, and **what else is selected stays in the drawing**.

Every wire/line verb does it: `w`, Shift+L (graphic line), `W` / cadence `s` (snap wire), the
context menu's Insert wire / Insert line, the Wire and Line menu entries and toolbar buttons, and
scripted `xschem wire gui` / `xschem line gui` / `xschem snap_wire`. The gate is **not** in
`start_wire()` itself, because that function is also what a *click* calls to continue a running
draw (under `persistent_command` every press goes through it) — a teardown there would delete your
pending placement on an ordinary click one event after the keystroke. The scripted coordinate forms
(`xschem wire x1 y1 x2 y2`) commit a wire outright, arm no draw, and are deliberately not gated:
they are the replay/test seams.

Related: ESC now also cleans up properly after the arms that zero wire *command* mode (`r`, `P`,
`t`, …). Before, one ESC could leave `STARTWIRE`/`STARTRECT` set with no owner to erase the band —
the "grey lines of the same dimensions as the wire" of the 0240 report. See issue **0243** F3.

---

## Q35. I pressed `l` while still drawing a wire and everything broke. What does `l` do mid-draw now?

- **Asked:** 2026-08-06
- **Project state:** branch `open_pdk` @ `aabf354e` + uncommitted — issue **0240** fix.

**It cancels the wire you were drawing — or just leaves wire mode if no segment is in progress —
then opens the Add Wire Label form.** That is the
user-ratified behaviour as of 2026-08-06 (the alternatives considered were: ignore `l` with a
statusbar hint, or silently *finish* the wire at the current point). Nothing is committed — an
abandoned draw leaves no copper, burns no undo baseline, and the statusbar says
`Add Wire Label: in-progress wire abandoned`. A wire armed from the **menu** but not yet clicked is
dropped too, and wire *command* mode is left, so the next click does not restart a wire underneath
the new label preview.

That last part matters more than it sounds. After you end a segment with a double-click you are
still in wire mode (the diamond snap cursor is up) even though no wire is in progress — and with
`persistent_command` on (`cadence_style_rc`) the next canvas click is claimed by the wire command
*before* any placement can see it. So arming a label there without leaving the mode meant every
click started a new wire while the label preview kept following the mouse. `l` now leaves the mode
in all three of its states: live draw, menu-armed, and resting.

Why it cannot just let both run: `end_place_move_copy_zoom()` tests `STARTWIRE`
(`callback.c:2809`) **before** the placement arm (`:2864`), so while a wire draw is live every
click is consumed by the wire and the label can never reach its drop gate — exactly the
"XSCHEM wants to keep drawing wire" the report described. Two modal placement gestures at once has
no good meaning; one of them has to yield, and the one you just asked for wins.

The second half of that bug was worse and is also fixed: `ESC` used to *return early* out of
`abort_operation()` to preserve persistent wire mode, skipping the teardown below it. With a label
preview co-armed, that dropped `START_SYMPIN` while leaving `sympin_preview = 1` and the preview
instance committed in the drawing — after which the click-select guard
(`… && !xctx->sympin_preview`, `callback.c:7815`) was false forever and nothing could be selected,
dropped or cancelled again. The grey wire-shaped ghost lines and the dead zoom were the same thing:
the rubber bands are only ever erased while their `ui_state` bit is set. ESC now tears down both
gestures; the two-stage ESC for a *plain* wire draw (first press ends the segment, second leaves
wire mode) is unchanged.

**`p` (Add Pin) and component insert now do the same** (ratified 2026-08-07, issue **0243** F1):
arming either abandons a live wire/line draw, in all three states, through the one shared
`leave_wire_draw_for()` gate. The remaining placement verbs — `t` (text), `r`/`P` (rect/polygon),
`Alt+L`/`Ctrl+P` (`net_label`), graph/image insert, `Ctrl+V` merge — are still ungated and tracked
in 0243. Related open items found while fixing this: **0241**, **0242**, **0244**, **0245**,
**0246**.

---

## Q34. Now a net label follows the wire when I move it, and it rotates with it. What changed, and can I turn it off?

- **Asked:** 2026-08-06
- **Project state:** branch `open_pdk` @ `a72ddb34` + uncommitted — `wire_label_ride.md`
  **S3 (R3 = RIDE)** just landed on top of S0 + S1 + S2.

That is the fix for issue **0237**, and it supersedes Q33 below — read this one first.

Before S3, moving a wire out from under a net label left the label behind and the net silently
reverted to `#netN`. Now the label rides: at move START the gesture records which copper each
*stationary* label is sitting on, and at every drag step (and at release) that label is placed on
its copper's new geometry. Rotating or flipping the wire rotates and flips the **label's own text**
too, which is the Cadence behaviour and the part of R3 that is not just a translation.

Three things worth knowing:

- **It is not a Cadence mode.** 0237 reproduced on stock defaults as well — nothing ever split
  there, so the label was never on an endpoint and nothing ever rescued it. `label_ride` defaults to
  **1** for everybody.
- **It replaces the little rescue wire, it does not add to it.** `connect_by_kissing()` used to mint
  a zero-length stub wherever a moving wire's endpoint coincided with a stationary label's pin, and
  the drag rubber-banded that into a real wire. That is gone for labels (device pins and
  `ipin`/`opin`/`iopin` keep it). The same preference switches both, on purpose: `label_ride 0`
  gives you the old stub **and** no ride, so you get the pre-S3 behaviour exactly rather than a
  label with neither.
- **A label whose copper only PARTLY moves stays put.** If it sits at a crossing or an L-corner and
  only one of the wires is in the move, it is still connected to the one that stayed, so it does not
  travel. Same for a label sitting on a stationary device pin.

Escape hatch: `set label_ride 0`. As with `label_splits_wires` there is no menu entry — it is a
one-release hatch, not a feature toggle.

What is *not* covered, so you know where the edge is: dragging the **label itself** with the
keyboard stretch (`m` / Ctrl-m) still detaches it, because those paths do not arm
`connect_by_kissing` and the leash that would catch it is deliberately gated on that. That is issue
**0238**'s own one-line fix, still open. The mouse connected drag has been leashed since S1.

---

## Q32. Clicking either side of a net label used to select just that piece of wire, and now it selects the whole run. Did something break?

- **Asked:** 2026-08-06
- **Project state:** branch `open_pdk` @ `8fee6129` + uncommitted — `wire_label_ride.md`
  S2 (R2) just landed on top of S0 + S1.

No — that is the feature, and it is the one thing S2 deliberately gives up. `wire_segment_splitting.md`
made xschem split a wire in memory at every **attachment point** so each inter-attachment span became
an independent click target, and it counted a net label's `PINLAYER` rect as an attachment. S2 says a
net label is a **name**, not a terminal: it no longer cuts the wire it taps. A **device** pin still
does, so the resistor-tap case the splitting feature was built for is untouched — on the original
fixture (a run tapped by a label at x=−80 and a resistor at x=0) you now get **2** clickable segments
instead of 3, and the resistor's boundary is still there.

Three things worth knowing about it:

- **It only affects you if Auto Join/Trim Wires is on** (`autotrim_wires`, which `cadence_compat`
  force-enables). With stock defaults nothing ever split at a label, so nothing changes.
- **Nothing on disk changes, and connectivity does not change.** What binds a label to a net is
  `touch()` in `name_attached_inst_to_net()` (`src/netlist.c`), which is interior-inclusive — the
  split was never what made the connection. The save path's coalescer was always pin-blind, so the
  split never reached a `.sch` either.
- **It fixes a real bug in the other direction.** Splitting *both* wires where they cross gives four
  segments a coincident endpoint, and coincident endpoints *are* connectivity. So a label with an
  **empty** `lab=` sitting on a crossing — a label that names nothing at all — silently merged two
  independent nets. Measured: four resistors on one net before, two after.

Escape hatch if you want the old boundaries back: `set label_splits_wires 1`. It restores the pre-S2
behaviour exactly, including the crossing short. ~~There is one other reason you might want it right
now — see Q33.~~ (That second reason was the issue-0237 mask; **S3 removed the need for it the same
day** — see Q34.)

---

## Q33. Since that change, dragging a wire out from under a net label loses the net name. That used to work. Why?

> **SUPERSEDED 2026-08-06 by Q34 above — S3 landed the same day and this no longer reproduces.** The
> answer is kept because the *mechanism* generalises and is worth reading: it is the worked example
> of "removing manufactured endpoint coincidence removes rescues you did not know keyed on it"
> (`WIRING.md` landmine 15). All three rows of the table below now read `strands 0` / `VOUT`, and
> `label_splits_wires 1` is no longer a mitigation for anything.

- **Asked:** 2026-08-06
- **Project state:** branch `open_pdk` @ `8fee6129` + uncommitted — `wire_label_ride.md` S2 landed,
  **S3 not yet**.

It used to work **by accident**, and S2 removed the accident. This is issue **0237**, and until S2 it
only reproduced for stock-config users; now it reproduces for `cadence_compat` users too.

The mechanism is worth understanding because it generalises. Splitting the wire at the label's pin
put the label on a wire **endpoint**, and two entirely separate rescues fire only on endpoint
coincidence:

- `connect_by_kissing()`'s **wire-endpoint arm** (`src/actions.c`) found the stationary label in
  `instpin_spatial_table` at the moving wire's endpoint and minted a tether stub. Interior to a
  single unsplit wire, there is no endpoint there to find.
- `select_attached_nets()`' **ELEMENT arm** (`src/select.c`) fires only on `endpoint_near`, which is
  what used to make a `stretch` drag of a mid-span label carry its wire along (issue **0238**'s
  cell).

Neither was designed to protect a label; both did, as a side effect of geometry the splitter
manufactured. Measured on 0237's own repro — label stationary, wire translates, connected drag:

| config | wires | strands | net |
|---|---|---|---|
| `autotrim_wires 0` (stock default) | 1 | 1 | `#net1` |
| `autotrim_wires 1`, `label_splits_wires 1` (pre-S2) | 3 | 0 | `VOUT` |
| `autotrim_wires 1`, `label_splits_wires 0` (S2) | 1 | 1 | `#net1` |

So no new failure mode was invented — you now get the same result a default-config user has always
had — but if you were relying on the mask, it is gone. The real fix is **S3 (RIDE)**: the label
follows its wire's new geometry, orientation included, for every config at once. Until S3 lands,
`set label_splits_wires 1` restores the mask exactly.

Note what is *not* affected: dragging the **label itself** on a connected drag. That is S1's LEASH,
it is gated on `connect_by_kissing`, and it measures 0 strands in all three configs above — S2 is a
no-op for it, because the leash always resolved its owner as the whole **collinear run** rather than
one wire record, precisely so split points were invisible to it.

---

## Q31. Dragging a net label used to leave a little wire behind, and now it doesn't. What changed, and how is the label still connected?

- **Asked:** 2026-08-05
- **Project state:** branch `open_pdk` @ `74ef1aed` + uncommitted — `wire_label_ride.md`
  S1 (R1 + LEASH) just landed on top of S0's strand oracle.

The little wire was never the connection. It was `connect_by_kissing()`
(`src/actions.c`) dropping a **zero-length `SELECTED1` stub** at every moving instance pin that
started on stationary copper; the drag then rubber-banded that stub into real wire. For a device
pin that is exactly right — the pin *is* a terminal and it must stay wired. For a `type=label`
instance it is an artifact with three costs:

- sliding the label **along** its own wire leaked a duplicate collinear `N` record;
- dragging it **off** the wire left a permanent perpendicular stub, and that stub is a genuine
  third endpoint, so `merge_collinear_wires` refuses to weld across it — one `N` record on disk
  became three;
- under `autotrim_wires` a *nameless* label at a wire crossing silently merged two nets.

What actually binds a label to a net is `touch()`: `name_attached_inst_to_net()`
(`src/netlist.c:1034`) binds an instance pin to any wire whose span contains that pin coordinate,
**interior included**. So a label sitting mid-wire is connected without any split, any stub, or
any endpoint coincidence. Measured on the shipped corpus: split and unsplit produce byte-identical
SPICE across 244 schematics.

S1 therefore skips labels in that kissing arm (`inst_is_netlabel()`, `src/check.c` — deliberately
`strcmp(type,"label")`, so `ipin`/`opin`/`iopin`/`bus_tap` keep every behaviour they have) and
replaces the stub with a **leash**: at move START the gesture records which copper each *selected*
label was sitting on, and at move END a label whose pin left that copper is projected back onto
it, clamped to its endpoints (`label_ride_capture` / `label_ride_apply`, `src/move.c`). So you can
slide a label along its wire, you cannot drag it off, and neither gesture creates copper.

Four scoping facts worth knowing:

- **The rule is "it may not leave its OWN copper", not "it must end up on some copper".** Those
  differ whenever the drag lands on a *neighbouring* wire, a device pin, or another label's anchor:
  under the weak rule the label would quietly desert its net and rename what it landed on. The
  owner never changes (spec R7 / §5.4). The owner is the whole **collinear run** through the
  anchor, so the segment splits `autotrim_wires` introduces are invisible to it — the label slides
  across them freely.
- **It only applies to the connected drag.** The leash is gated on `xctx->connect_by_kissing`, so
  `m` (and every mouse stretch) leashes; Shift-M / the Ctrl+LMB detach do not, and there a label
  still detaches — that is what the modifier means, and it is how you deliberately move a label to
  a different net.
- **A label on a bare device pin is leashed to that pin**, not to a wire. 36 % of shipped labels
  sit on a device pin with no wire under them (the gnd/vdd idiom); without this they would have
  been silently orphaned by the same change.
- **A label that was already off copper is left alone.** The rule is *conservation* — no gesture
  takes a label off copper that was on copper — not prohibition. 91 labels across 21 shipped files
  sit off copper on purpose (`verilog_type=` declaration blocks parked off-sheet, `type=label`
  symbols used as pure graphics, wireless flyline fixtures).

Not yet done: a label does **not** follow its wire when the *wire* moves (that is RIDE, S3, and
issue **0237**'s own repro), and sliding past the end clamps rather than extending the wire
(R6, S5). See `doc/claude/specs/wire_label_ride.md` §7 and §14.

This supersedes the label half of **Q27** (W7's "keep the through-wire, drop one stub"): the
through-wire rule stands, the stub is gone.

---

## Q30. Ctrl+MMB cycles a pin's type (in/out/inout). How do I rebind that gesture to something else?

- **Asked:** 2026-07-19
- **Project state:** branch `fluid-editing` @ `74d1e03f` — the pin-type-editing slice
  (doc/claude/specs/pin_type_editing.md) just landed: `xschem set_pin_type` core verb,
  Ctrl+MMB placed-pin cycle (action id `edit.cycle_pin_type`), and the Edit Pin form.

The gesture is a row in the input action registry, so every generic remap route applies.
Three options, persistent first:

1. **Edit the user binding csv** (survives upgrades; the file-editable route). Copy
   `mousebindings.csv` (or `keybindings.csv` for a key chord) from the share dir to
   `~/.xschem/` and edit — the user copy is loaded after the shipped defaults and wins.
   The shipped row is:

       button,2,ctrl,canvas,edit.cycle_pin_type,

   Change device/code/mods as desired; a key example for `keybindings.csv`
   (`code` = X keysym, `mods` = `ctrl|alt|shift|super` joined by `+`, ctx
   `canvas|graph|global`):

       key,t,0,canvas,edit.cycle_pin_type,

   To *remove* the default chord, set its action column to `-`. Format details are in
   each csv's header comment.

2. **`xschem bind` / `xschem unbind`** — same table, scripted. Works in
   `~/.xschem/xschemrc`, `cadence_style_rc`, or live in the CIW:

       xschem bind key t ctrl canvas edit.cycle_pin_type
       xschem bind wheel up alt canvas edit.cycle_pin_type   ;# Alt+wheel-up cycles
       xschem unbind button 2 ctrl canvas                    ;# drop the default MMB chord

   Usage: `xschem bind <wheel|button|key> <code> <mods> <ctx> <action_id> [idle]`.

3. **Bind the raw verb** anywhere Tk reaches: the core is plain
   `xschem set_pin_type -cycle` (selection-based), and `addpin::cycle_type` is the full
   gesture (adds the pin-under-pointer pick when nothing is selected). A custom menu
   button, toolbar hook, or direct `bind .drw <Key-F9> {addpin::cycle_type}` all work —
   but prefer routes 1/2: registry-bound chords appear in the generated keyboard
   cheat-sheet and are action-logged.

---

## Q29. With the action-log / CIW coverage work in progress, what will a user actually *notice* differently when using the tool right now?

- **Asked:** 2026-07-14
- **Project state:** branch `fluid-editing` @ `e3764a07`. Action-log coverage was
  re-audited this day (`doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md`):
  the "self-log at the C core" migration is ~70% landed, and the **first core-migration
  atom** — double-click connected-select — just shipped (`e3764a07`). This answer is a
  point-in-time snapshot; later atoms will widen what follows.

**Short version: the CIW log pane (and `Xschem.log`) is becoming a live, replayable transcript
of what you do — and each landed slice makes more of your gestures show up in it in real time.**
The value is not a new drawing feature; it is that the tool now *narrates itself* in a language
you can copy, replay, and script.

### What is visibly different today

- **Open the CIW** (the command/interaction window that auto-opens in an interactive session).
  As you work, the upper pane fills with the exact `xschem …` command each action maps to —
  place a wire, move a device, flip, trim, descend, click-select, and now **double-click to grow
  a connected selection** all appear as they happen. Before this atom, the double-click grew the
  selection *silently*; now it writes `xschem select_grow_connected x y` you can watch land.
- **The log is a script.** Those lines are executable. Copy one into the CIW entry to repeat the
  action; `source` the whole `Xschem.log` into a fresh session to replay a sequence. This turns
  "how do I automate this?" into "do it once, read the line it logged." The log doubles as a
  **discoverability tool for the scriptable API** — you learn the command names by performing the
  gestures.
- **Bug reports get a reproducer for free.** The tail of the log is the precise command sequence
  that led to the current state — paste it into an issue instead of describing clicks in prose.

### What a user should *not* yet expect (honest scope)

Coverage is deliberately partial and still climbing, so the log is a **growing transcript, not yet
a complete macro recorder**. As of this HEAD, a handful of common actions still do not appear or
do not replay faithfully — notably **Ctrl-X (cut) and the Delete key**, **Ctrl-E return** on the
keyboard, **Library Manager** create/rename/delete/git operations, and **property-dialog** commits
(logged as a non-replayable `# marker`, not an executable command). Selecting a single object *is*
now logged (`xschem select_at`), which updates the older **[Q24]** answer — descend-to-schematic and
click-select have since moved from "silent" to "logged"; go_back and a few keyboard paths remain the
open cases. Treat the log today as "most standard edit/selection gestures, faithfully, with a known
shrinking list of gaps," and check the coverage audit for the current edge.

### Why this is the shape of the value

Each fix is one C core taught to log itself, which means the action is captured **from every path
that reaches it** — menu, toolbar, keyboard, gesture, script — not just the one the developer
remembered. So the practical user-visible effect of the ongoing work is monotonic: the CIW keeps
getting more trustworthy as a record, gesture by gesture, without changing how you draw. The
double-click atom is the first of several (`delete`, `go_back`, `descend_symbol` are queued next);
each one you will notice simply as "that thing I do now shows up in the log, and I can replay it."

---

## Q28. What are XSCHEM's current move/stretch/rotate keys versus Cadence Virtuoso, and with `cadence_compat=1` loaded, what still doesn't match Cadence?

- **Asked:** 2026-07-09
- **Project state:** branch `fluid-editing` @ `4cc95a99` (fluid-editing default ON; issues 0091–0097 landed).

**Two variables, often confused.** Wire behavior on a move is governed by two independent
Tcl vars:

- `fluid_editing` (default **1**, `xschem.tcl:14715`) — the incremental rip-up/reroute
  *engine*. **On its own it reroutes nothing.** It only runs once `xctx->stretch_select` is
  armed. `stretch_select` is set exclusively inside `select_attached_nets()`
  (`select.c:1589`), and whether that runs at move START is gated on
  `enable_stretch`/Ctrl/`cadence_compat` — **never on `fluid_editing`** (`move.c:5162`,
  `5228`, `5740`).
- `enable_stretch` (default **0**, `xschem.tcl:14673`) — global "grab attached nets on move"
  toggle. Key `y` flips it (`edit.toggle_stretch`, `keybindings.csv:33`).

### Default config (`cadence_compat=0`) — inverted vs Cadence

- **Keyboard** (`m` is hard-coded in C at `callback.c:4715`, *not* in `keybindings.csv`, so it
  can't be remapped there): plain `m` = **disconnected** move (because `enable_stretch=0`);
  **Ctrl+`m`** = stretch/connected (Ctrl inverts `enable_stretch`, `callback.c:6096`);
  `Shift+m`/`M` = kissing-connect (add wires to moved pins), *not* a plain move; Alt+`m` =
  kissing.
- **Drag**: plain LMB-drag = disconnected (`stretch = 0 ^ 0 = 0`); **Ctrl+LMB-drag** =
  connected/reroute; Shift+LMB-drag = copy.
- This is **backwards from Cadence**, where plain drag = stretch and Ctrl+drag = detach.

### `cadence_compat=1` (loaded via `cadence_style_rc`)

`cadence_style_rc` sets `cadence_compat 1` + `fluid_editing 1` + `en_pin_select 1` +
snap/crosshair/orthogonal, and *leaves `enable_stretch` at 0* (its `set enable_stretch 1` is
commented out). The `cadence_compat` flag rewires the Button1 drag branch
(`callback.c:6069-6090`) to the true Virtuoso three-way, independent of `enable_stretch`:

| Gesture | Effect |
|---|---|
| plain LMB-drag | attached move — `connect_by_kissing=2` + `select_attached_nets()` → wires follow/reroute |
| **Ctrl**+LMB-drag | **detached** move — wires left behind |
| Shift+LMB-drag | copy |

It also force-sets `autotrim_wires=1` (`xschem.tcl:15153`), collapses a multi-select to the
clicked item on a no-drag release (`callback.c:6263`), and remaps several keys (`Ctrl+r` →
run simulation, plain `s` → snapped wire, etc.).

### Cadence Virtuoso *schematic* reference (for the diff)

Note the schematic/layout trap: in the **schematic** editor `m` = **Stretch** (keeps wires
attached + reroutes), `Shift+m` = **Move** (rigid, no reroute) — opposite of the layout
editor. Rotate `r` (90° **CCW**); mirror `Shift+r` (L↔R) / `Ctrl+r` (U↕D). Plain drag =
move-with-wires, Ctrl+drag = detach, Shift+drag = copy. Commands are modal/sticky with a
reference point, `F3` opens a live options form (reroute on/off, gravity), and while an
object floats you can press the rotate/mirror key and **the wires stay connected and reroute
live**. (Sources: VT MICS bindkeys tutorial; AnalogHub/miscircuitos hotkey lists; Cadence
forum 38605.)

### Gaps that remain with `cadence_compat=1`

What already matches: the 3-way LMB drag model (plain/Ctrl/Shift), copy-drops-disconnected,
end-of-move cleanup (`maintain_wire_segments` + orphan/loop/reversal cleanup,
`move.c:5778-5816`), single wire-endpoint tip-grab stretch (`callback.c:6024`/`6062`), and
snap/orthogonal defaults. The gaps:

1. **No connected rotate/flip (headline gap).** Cadence keeps a rotated/mirrored component
   wired and reroutes live. In XSCHEM, pressing R/F *mid-stretch* sets `move_rot`/`move_flip`
   ≠ 0, which gates **off** every fluid-reroute stage (`move.c:1167`, `5349`, `5740`, `5790`)
   — the wires still rubber-band-translate but the intelligent reroute dies for the rest of
   the gesture. A *standalone* rotate/flip of a placed wired instance (`callback.c:5003-5011`)
   grabs no attached nets → wires detach/dangle. There is no connected rotate/flip anywhere.
2. **Keyboard verbs inverted — `cadence_compat` does not remap `m`/`M`** (the `m`/`M`
   handlers contain no `cadence_compat` reference). Cadence `m`=stretch, `Shift+m`=move;
   XSCHEM plain `m`=disconnected, connected=**Ctrl+`m`**, and `Shift+m`=kissing (not a rigid
   move). The correct mouse model is undone by wrong keyboard verbs.
   **ADDRESSED 2026-07-09** (uncommitted): with `cadence_compat=1`, `m` is now STRETCH
   (connected, verb-noun + noun-verb) and `Shift+M` is a rigid disconnected MOVE, matching
   Virtuoso. See `doc/claude/specs/cadence_stretch_move_keys.md`. Gaps #1 (connected
   rotate/flip) and #3–#6 remain.
3. **Rotate/mirror keys + direction differ.** Cadence `r` (CCW) / `Shift+r` / `Ctrl+r`;
   XSCHEM `Shift+R` (**CW**) / `Shift+F` (L↔R) / `Shift+V` (U↕D).
4. **`Ctrl+r` collision.** Cadence `Ctrl+r` = mirror vertical; XSCHEM cadence mode rebinds it
   to **run simulation** (`callback.c:4969`).
5. **No `F3` mid-command options form** — reroute on/off, gravity, and route style are not
   user-tunable mid-gesture.
6. **(unverified/softer)** numeric coordinate/delta entry during a move and `Enter`=repeat-
   last / sticky modal repeat — present in Virtuoso, not found on the XSCHEM move path.

Bottom line: `cadence_compat=1` gives correct **mouse** semantics but wrong **keyboard**
semantics, and **no connected rotate/flip** — gap #1 is the real feature hole; #2–#4 are
keybinding/remap fixes.

---

## Q27. When I drag a net-label that taps the *middle* of a wire, why did the whole wire jog into a U-detour instead of leaving the wire in place and dropping a single stub?

- **Asked:** 2026-07-05
- **Project state:** branch `fluid-editing` @ `670ad255` (wire-segment-splitting W0–W6 landed).

**Symptom.** Fixture `SANDBOX/test_wire_splits/`: wire `N -100 -60 110 -60`, a `lab_wire`
net-label tapping it mid-span at `(-80,-60)`, a resistor tap at `0`. Grab the label and drag
it up. Desired (`sch_desired`): the horizontal run stays put, one clean vertical stub joins
the label's new position back to the tap. Actual (`sch_after`): the left half of the run got
rubber-banded into a 4-segment U-detour.

**Root cause — a two-feature interaction.** The **wire-segment-splitting** feature (W1)
breaks the wire at every attachment point into abutting **collinear segments**, so the label
tap at `(-80,-60)` — which used to be *mid-span* on one wire — becomes a shared **endpoint**
of two segments (`-100→-80` and `-80→0`). The **wire-follow-on-move** machinery then grabs
those segments through *two* paths:

1. `select_attached_nets()` (select.c) grabs wires by **endpoint coincidence** with the
   moving pin → it grabs *both* through-segments.
2. Even after (1) is suppressed, `connect_by_kissing()` drops a stub at the tap and
   `compute_wire_slide()` (move.c) **promotes** that stub — its far end (the tap) has
   coincident neighbours, so it looks like a slidable *corner* — and drags the run.

Before the split, the tap was mid-span (not an endpoint) so `select_attached_nets` never
fired and `connect_by_kissing` alone dropped one clean stub. **The split defeated the
correct tap-move semantics.** (Diagnostic lever: with `orthogonal_wiring=0`, kissing already
produced the desired result, which isolated `compute_wire_slide` as the second culprit.)

**Fix (both gated inside the stretch path only).** Two predicates that recognise a *straight
run passing through a point* (two wire endpoints there that are collinear **and**
opposite-direction: `cross==0 && dot<0`, exact because split coords are grid-aligned):

- `select.c wire_through_tap_arm()` — in `select_attached_nets`, **skip** grabbing a wire
  that is one arm of a through-run at the moving pin. Gated on `connect_by_kissing` being
  armed, so a stub always *replaces* the skipped grab (otherwise a stretch-without-kissing
  move would leave the tap disconnected); the arming was reordered before
  `select_attached_nets` at the move/copy/drag sites.
- `move.c point_is_collinear_pass()` — in `compute_wire_slide`, **jog instead of slide**
  when a wire's far end is a straight pass-through of *stationary* wires (so the kiss stub at
  a tap stays a single clean stub, never dragging the run).

A perpendicular L-arm or a lone wire-end has no collinear-opposite partner, so it still
follows normally. Regression coverage: `tests/headless/test_wire_split.tcl` W7/W7b/W7c
(run-intact + single stub; stretch-without-kissing stays connected; 4-way cross stays
connected). See `doc/claude/specs/wire_segment_splitting.md`.

---

## Q26. When I rubber-band a selection box, why does a partially-crossed *line* (or pin/wire endpoint) get grabbed but a partially-crossed *instance* does not — and is `enable_stretch` the reason?

- **Asked:** 2026-07-04
- **Project state:** branch `fluid-editing` @ `8f7e621b`.

**Short version:** two *different* features are in play, and neither is "partial overlap
selects the whole object" the way it first looks. **`enable_stretch`** grabs individual
**sub-parts** (endpoints / corners / vertices) of *decomposable* objects as stretch
handles — it does **nothing** to an instance, which is atomic. The behavior that selects a
**whole** object on partial overlap is a *separate* variable, **`select_touch`** (an
AutoCAD-style crossing-window), and it is gated on the **drag direction**, not on
`enable_stretch`.

**The area-select funnel** is `select_inside()` (`select.c:1524`). Per object type:

| Object | Selected by area when… | Extra when `stretch` on |
|---|---|---|
| instance | **fully enclosed** (`RECT_INSIDE`) only | *nothing* — the partial branch is `#if 0` (select.c:1601) |
| wire / line | both endpoints enclosed | one endpoint inside → that end grabbed (`SELECTED1/2`) |
| rectangle | all 4 corners enclosed | a corner inside → that corner grabbed (`SELECTED1..4`) |
| arc | bbox enclosed | center/endpoint inside → grabbed (`SELECTED1/2/3`) |
| polygon | all vertices enclosed | a vertex inside → that vertex grabbed |

So an instance is **all-or-nothing**: `enable_stretch` cannot make it partial-selectable
because it has no grabbable sub-points. A line looked "partially selected" only because its
*endpoint* (a sub-part) fell in the box while `stretch` was on.

**Window vs crossing is drag direction.** `select_rect()` (`actions.c:4956`) dispatches on
`xctx->nl_dir`, set at press time from the drag direction
(`callback.c:3986`: `mx >= mx_save ? nl_dir=0 : nl_dir=1`):
- **left → right** (`nl_dir=0`) → `select_inside()` — **window**, full enclosure.
- **right → left** (`nl_dir=1`) *and* `select_touch=1` → `select_touch()` — **crossing**,
  partial overlap selects **whole** objects, instances included.

`select_touch` defaults **on** (`xschem.tcl:14669`); `enable_stretch` defaults **off**
(`xschem.tcl:14659`). So: to grab a partially-crossed *instance*, drag **right-to-left**
(that is `select_touch`, not `enable_stretch`). `enable_stretch` is only about grabbing
endpoints/corners for a subsequent stretch-move, and (non-cadence) about instance-move
net-follow. See the fluid-editing spec `doc/claude/specs/fluid_editing.md`, which builds on
this to give first-click tip/edge grab.

---

## Q25. Which `xschem` Tcl commands exist in this fork but not in upstream XSCHEM — and where is the list?

- **Asked:** 2026-07-04
- **Project state:** branch `fluid-editing` @ `6effc201`.

**Short version:** there is a maintained reference doc — **[`doc/new_tcl_commands.md`](../new_tcl_commands.md)**
(at the `doc/` root, not under `doc/claude/`, because it is useful to any user, not just
the internals work). It inventories every `xschem` subcommand added on this branch that was
not present at the upstream fork point.

**At the time of writing:** 220 subcommands upstream → 295 here — **75 new, 0 removed**,
grouped by feature (stable object handles & the `object`/`objects` query API; replayable
interaction `select_at`/`hover`; action logging & input `bind`ings; net-highlight styles /
scope / cross-window sync; the OpenAccess Library/Cell/View manager; pins & wire-stubs;
windows/tabs; backup; property forms; view & wiring toggles).

**How the list is derived (and how to refresh it).** It is the set difference of the
`xschem` subcommands in `src/scheduler.c` between this branch and the fork point
(`f276d0cf`), using the same `grep 'strcmp(argv[1], "…")'` extraction the build uses for
`src/xschem_subcommands.txt`. The doc's final section has the exact regenerate command (and
note: diffing against the *latest* upstream `origin/master` instead of the fork point may
show a few as also-present-upstream if added independently there). **Scope:** top-level
subcommands only — new `xschem get`/`set` sub-targets, object selectors (`@id`, `#index`),
and standalone Tcl procs in `*.tcl` files also grew and are not in that count.

---

## Q24. Why are descend/return (Ctrl-E / Ctrl-X), the E-key descend-options form, and the act of selecting an instance NOT logged to the CIW log pane and the log file, when other actions are?

- **Asked:** 2026-07-03
- **Project state:** branch `fluid-editing` @ `9b854d54`. Action-logging + CIW landed
  (spec `doc/claude/specs/action_logging.md`, checklist `action_logging_checklist.md`);
  hi_descend dialog landed (`doc/claude/specs/hi_descend.md`).

**Short version:** two independent reasons. **(A)** those keys are served by the *legacy
inline key switch* in `callback.c`, which bypasses the only paths that log; and **(B)**
descend-to-schematic and click-select are *non-replayable by design* (the object-reference
gap, issue 0005), so even where a wrapper runs they get at most a `#` marker.

**The logging funnel.** Everything that reaches the file + the CIW pane goes through one C
function, `log_action()` (`util.c:394` — it writes the file line AND mirrors to the pane via
`ciw_echo`). Exactly three callers feed it:
- `dispatch_input_action()` (`callback.c:3454`/`3471`) — the binding-table path; runs the
  action's canonical command then logs it (unless `nolog`, or the core already self-logged).
- `menu_action_logged` (`action_registry.tcl:190`) — menu picks.
- self-log-at-core — specific scheduler commands calling `log_action()` themselves
  (`wire`, `cut`, `copy`, `delete`, `move_objects`, place…).

**Reason A — the keys miss all three.** The default `E`/`Ctrl+E`/`I` descend keys are NOT in
`keybindings.csv`, so `dispatch_input_action()` finds no binding, returns 0, and the event
falls through to the hard-coded switch in `callback.c`, which calls the C functions **directly**:
`descend_schematic()` (`callback.c:4330`), `go_back()` (`4334`, `5425`), `descend_symbol()`
(`4450`). And the underlying scheduler commands `xschem descend` / `go_back` / `descend_symbol`
do **not** self-log at the core (`scheduler.c:1288`/`3014`/`1310` — no `log_action`). So nothing
records them. The **E-key form** is the same story: `E` is a raw Tk `bind … {hi_descend; break}`
(`xschem.tcl:5535`/`5543`) opening the `hi_descend` dialog; the proc does not `log_action`, and a
dialog is not a replayable command anyway — then it descends inline. Neither launch nor result
logs.

**Reason B — descend-to-schematic and click-select are non-replayable by design.** A descend
depends on *which instance* is selected; a click-select depends on *which object* is under the
cursor. The v1 log has no stable object handle to reconstruct that on replay. The spec accepts
the gap: `action_logging.md` principle 4 ("Object-reference gap accepted for v1: click-select
cannot be faithfully [replayed]"); checklist row 17 (click-select "still silent"), row 51
(replayable `xschem select_at x y` **deferred**), row 53 (full causal replay of
selections+descend/go_back **deferred**). So even the right-click context-menu pick for
descend-to-schematic logs only `# … not replayable: needs object reference, issue 0005`
(`callback.c:2538`), and `select.c` has no `log_action` at all.

**Per item:**

| Action | Logs? | Why |
|---|---|---|
| Select instance (click) | no | Reason B — non-replayable by design, deliberately silent |
| `E` → descend-options form | no | Reason A — raw Tk bind to `hi_descend`; dialog, no `log_action` |
| Descend to schematic (E/X) | no | Reason A (inline path) **+** Reason B (object-ref gap) |
| Return / `go_back` (Ctrl-E, Ctrl-X) | no | Reason A only — `go_back` **is** replayable, just misses the log |
| `descend_symbol` (I) | no | Reason A only — also replayable |

**Proof it's the path, not policy (for go_back/descend_symbol):** fire the same actions from the
**Edit menu** (Push schematic / Pop) and they DO log — `menu_action_logged` records
`xschem descend` / `xschem go_back`. Right-click → Pop / Descend-into-symbol logs too
(context table, `callback.c:2539-2540`).

**Fixable subset.** `go_back` and `descend_symbol` are replayable and miss logging only from
Reason A — fix = self-log at the core (add `log_action("xschem go_back")` in the scheduler block,
as `cut`/`delete` do), or bind the keys through `keybindings.csv` to `edit.pop`/`edit.push_symbol`
so `dispatch_input_action()` logs them. Descend-to-schematic, the E-form, and click-select need
Reason B solved first (stable object handles / the deferred `xschem select_at x y`, rows 51/53)
before they can be *replayable*; until then the most they can get is a `#` marker.

---

## Q23. From Tcl in the CIW, can I name a *hierarchical* net (`x1.x2.x3.net`) plus a highlight style (a `net_hilight_style` row index, or an F5-style literal styledef) and have that possibly-buried net highlighted — with every ancestor along the path cued in the most-recent style, Cadence-style?

- **Asked:** 2026-07-02
- **Project state:** branch `fluid-editing` @ `5d4b7e7f`. Net-hilight-styles feature complete
  (style table + `-style N` + `net_hilight_apply` + blink/marching-ants + the `.nhse` editor);
  buried-net cue feature landed (`compute_buried_hilights`). See
  `doc/claude/specs/net_hilight_styles.md` and `doc/claude/specs/buried_net_hilight.md`.

**Short version:** **partial.** Applying a style *by row index* or *by literal styledef* works, and
highlighting a *buried* net with ancestor cues works — but the two do **not** yet compose in a
single call. There is no `hilight <hier-net> -style N` today.

**How styles get applied (all Tcl-drivable, all resolve the net at the *current* level only).**
- By **row index:** `xschem hilight_netname -style N <net>` — sets `hilight_color=N` for this one
  apply, does **not** advance the style cursor (`scheduler.c:3324`).
- By **literal styledef** (the F5-key kind — an 8-col row `{index color width dash angle blink_ms
  anim rate}`): `net_hilight_apply {styledef} ?net…?` (`xschem.tcl:642`) installs the literal row
  (dedups by content) then loops `hilight_netname -style $idx` over the named nets.
- The GUI keys `9`/`8`/`0` (highlight / remove / clear-all) and the `.nhse` style editor ride the
  same core. **Every** path funnels through `hilight_netname()`, which looks the name up in the
  **current** hierarchy level's node hash (`bus_node_hash_lookup` at `currsch`) and stamps the new
  `hilight_table` entry with `sch_path[currsch]` — so the *level you are viewing* decides both
  what resolves and how deep the entry is recorded.

**The hierarchical part.** `hilight_netname` does **not** parse a dotted path: feed
`x1.x2.x3.net` at the top and it is not a top-level net name → lookup fails → returns `0`, nothing
highlights. The working hierarchical route is **`probe_net {fullnet}`** (`xschem.tcl:3778`): it
calls `descend_hierarchy` (walks the dots, descending `x1`→`x2`→`x3`), then `hilight_netname net`
at the leaf level. Because it is now descended, the entry is stamped with the deep path
`.x1.x2.x3.`, which is exactly what drives the buried cue. **Gap:** `probe_net` takes **no**
`-style` — it uses the current style cursor, so "hierarchical net *and* an explicit style" is not
one call. Workarounds: script the pieces yourself
(`descend_hierarchy x1.x2.x3.net 0; xschem hilight_netname -style N net; <ascend>`), or the raw
debug primitive `xschem test 2 <path> <net> <col>` → `hier_hilight_hash_lookup` inserts a
deep-path entry *without* descending — but that is a test hook whose `col` is a raw (negative)
color index on the sim-logic path, **not** a style-table row.

**How robust is the buried cue vs. the Cadence model?** `compute_buried_hilights`
(`hilight.c:1830`, run inside `propagate_hilights` on every highlight change / descend / ascend)
matches the model, with one structural caveat:

- **Per-level, not simultaneous.** A net buried in `x3` flags `x1`'s bbox when you view the top,
  `x2`'s when descended into `x1`, `x3`'s when in `x2` — a recursive prefix-match against the
  current path alone (`hilight.c:1826-1829`). You cannot see `x3`'s rectangle *at the top*: `x3`'s
  bbox does not exist there. Each ancestor is cued at **its own** level.
- **Most-recent style wins:** yes. A monotonic `seq` is stamped per apply and carried across
  descend; the cue takes the most-recently-applied buried net's style (`e->seq >= bseq[k]`,
  `hilight.c:1860`) — so the last highlight action's style is what ancestors show.
- **Rectangle in that exact style:** yes — the four bbox edges draw through `draw_hilight_wire`,
  so color/width/dash **and** blink/marching apply.
- **Other caveats:** `probe_net` leaves you *descended* on success (no auto-ascend), so you must
  ascend to *see* the ancestor cues; an instance that exposes the net at a **pin** shows the pin
  color and gets **no** cue (`buried_inst_pin_hilighted`, `hilight.c:1858`); vector instances are
  matched by base name before `[` (not per-slice); only `unhilight_all` (key `0`) clears the cue
  from above.

**Recommendation / how to fully match Cadence.** To get "name a hierarchical net + pick a style +
have the ancestors cued in that style" in one shot, add a `-style N` passthrough to `probe_net`
(thread it into the wrapped `hilight_netname` call) — the buried-cue machinery already stores and
renders the style, so nothing downstream needs to change.

## Q22. I work on ~10 projects that each need a *different* library setup. How do I set `XSCHEM_LIBRARY_DEFS` (and the library path) on a per-project basis?

- **Asked:** 2026-06-30
- **Project state:** branch `cadence-pin-name-text` @ `8e70fb1b` (follow-up to Q21 and the
  library docs). Full write-up: `doc/library_defs.md` §8.

**Key fact:** `XSCHEM_LIBRARY_DEFS` and `XSCHEM_LIBRARY_PATH` are **Tcl variables set inside an
`xschemrc`**, *not* OS environment variables xschem reads on its own (nothing bridges
`$env(XSCHEM_LIBRARY_DEFS)` → the Tcl global by default — see option C). And xschem selects an
`xschemrc` **per project**. At startup it sources, in order: any `--preinit '<tcl>'` → the
**system** `xschemrc` (always) → then **exactly one** of `--rcfile <file>` (if given) /
`./xschemrc` in the **launch directory** (`getcwd()`, `xinit.c:3059-3072`) / `~/.xschem/xschemrc`.
The system rc runs first, so a project rc *layers on top*.

So there is no single global to keep editing — give each project its own rc. Three styles:

- **A — a directory per project with its own `./xschemrc` (idiomatic).** Put
  `set XSCHEM_LIBRARY_DEFS /path/proj/library.defs` (or build `XSCHEM_LIBRARY_PATH`) in
  `~/proj/chipA/xschemrc`; `cd ~/proj/chipA && xschem` picks it up. Ten dirs → ten setups, no
  flags.
- **B — `--rcfile <proj>/xschemrc`** — explicit, cwd-independent; ideal for a per-project
  launcher or a `xschem-proj <name>` wrapper. Highest precedence over the cwd/personal rc.
- **C — environment-driven (direnv / modules).** A bare `export XSCHEM_LIBRARY_DEFS=…` does
  **nothing** by itself (xschem reads the Tcl var). Add a one-line bridge once to the personal
  `~/.xschem/xschemrc` —
  `if {[info exists env(XSCHEM_LIBRARY_DEFS)]} { set XSCHEM_LIBRARY_DEFS $env(XSCHEM_LIBRARY_DEFS) }`
  — then a per-project `.envrc` (`export XSCHEM_LIBRARY_DEFS=…`) switches libraries on `cd`.

Notes: `XSCHEM_LIBRARY_DEFS` is a `:`-separated list (mix a shared + a project defs file);
`--preinit` runs *before* the rc chain so those can override it (prefer `--rcfile`); and since
`xschemrc` is Tcl, one shared rc could branch on `$env(PROJECT)`/cwd — but a per-dir rc (A) or
`--rcfile` (B) is cleaner. Recommendation: **A** as the baseline, **C** if you already use
direnv/modules.

## Q21. I migrated my old-style libraries (pins whose name text is *not* owned by the pin) into new libraries with the pin-name migration tool. How do I make the Library Manager load the *migrated* libraries when xschem starts?

- **Asked:** 2026-06-30
- **Project state:** branch `cadence-pin-name-text` @ `6b8e6f93`. Pin-owned-name-text P0–P8
  done; migration tool `tools/migrate/migrate_pin_names.py` shipped; user-facing docs
  `doc/pin_name_migration.md` (the tool) and `doc/library_defs.md` (library registration)
  written. Example run: `xschem_libraries_oa` → `xschem_libs_newsym` (342 `.sym`, 239 migrated,
  0 errors), verified all load in xschem + netlist byte-identical.

**Short version:** it is *only* a startup-path question, because the migration is a drop-in.
The migrated tree keeps the same Library/Cell/View names, the same pin `name=`/`dir=`, and the
same connectivity — only display tokens (`show_pinname`, `name_*`) changed and adopted `T`
labels were folded in, so **netlists are identical**. The tool even copied the original tree's
`library.defs` (same `DEFINE` lines). So making xschem "load the correct libraries" means
pointing its startup search at the migrated tree instead of the old one — nothing needs
re-registering by hand.

xschem's startup library set comes from your `xschemrc`: whichever `library.defs` it loads —
explicitly via `XSCHEM_LIBRARY_DEFS`, or **auto-discovered** on `XSCHEM_LIBRARY_PATH` — is what
the Library Manager shows. Two clean ways:

- **Swap the tree on the path (recommended):** in `xschemrc`, put the migrated tree on
  `XSCHEM_LIBRARY_PATH` and drop the old one —
  `append XSCHEM_LIBRARY_PATH :/path/xschem_libs_newsym` (and remove the
  `…/xschem_libraries_oa` line). The migrated tree carries its own `library.defs`, so xschem
  auto-discovers it and the same library names reappear, now with owned pin names.
- **Or point `XSCHEM_LIBRARY_DEFS` at the migrated defs file:**
  `export XSCHEM_LIBRARY_DEFS=/path/xschem_libs_newsym/library.defs` (explicit defs take
  precedence over auto-discovered ones).

**The one trap:** do *not* leave *both* trees on the path with the *same* library names — two
`DEFINE devices …` are deduped by name and precedence/search-order decides the winner, so you
may silently get the old, un-migrated cells. Remove the old tree, or rename its libraries.

**Simplest of all:** because the migration is display-only, netlist-invariant, and idempotent,
you can migrate the *original* tree **in place** (its `.bak`/git is the backup) and skip the
two-tree problem entirely — every `library.defs` entry and schematic reference stays as-is and
each cell just gains owned pin names. Existing schematics never need editing: `C {devices/nmos4}`
resolves through whichever `devices` is registered, so once the migrated one is on the path they
pick up the owned-name symbols automatically.

**Verify at startup:** Tools ▸ Library Manager → pick a migrated cell → **Symbol ▸ Pin names ▸
Show all pin names** shows its names; `xschem get_inst_lcv` on a placed instance reports the
Library/Cell/View it resolved from. Full step-by-step: `doc/library_defs.md` §7.

## Q20. What would it take to animate net highlights (blink + marching ants) in *multiple* open windows at once, not just the front one?

- **Asked:** 2026-06-25
- **Project state:** branch `fluid-editing` @ `c2162eeb`. Net-highlight-styles: Pass 1 + 1.5 +
  2a (blink) + 2b (marching ants, phases A–E) all complete & committed; the animation tick
  animates only the **front** window by design. Plan for this item:
  `doc/claude/suggestions/plan_net_hilight_multiwindow_anim.md`.

> **UPDATE — DONE (2026-06-25, `fluid-editing`).** Implemented as planned, phases A–E. **Now
> every *visible* detached window animates its net highlights (blink + marching) simultaneously;**
> background **tabs** stay front-only (shared canvas, by design). It was exactly the "lift the
> global-front-`xctx` assumption out of four entry points behind one audited context-borrow"
> job described below. What shipped:
> - **`net_hilight_borrow_ctx()` / `net_hilight_restore_ctx()`** (`hilight.c`): the side-effect-free
>   borrow (repoint `xctx` at a window, no raise/focus/title) — A3 audit confirmed the draw path
>   is `xctx`-relative except the file-scope draw batch buffers, which stay safe as long as a
>   borrow wraps one complete, non-reentrant `draw()`.
> - **`xschem get net_hilight_animated <win>`** and **`xschem redraw_hilight_region <win>`** take an
>   optional window and evaluate/draw *that* window via the borrow.
> - **`net_hilight_anim_update()`** fans out to every open window (`net_hilight_anim_update_all`
>   exposes it for the kill-switch); the per-window Tcl tick gates on **`winfo viewable`** (stops
>   iconified windows and background tabs; a `<Visibility>` binding re-arms on restore).
> - **Serialization (E1):** no window animates a frame while the focused window is mid-gesture
>   (`net_hilight_ctx_gesturing()` on the pre-borrow context — a held `semaphore` from a passive
>   modal dialog does NOT freeze other windows). The global wall-clock keeps all windows in phase.
>   See `doc/claude/specs/net_hilight_styles.md` and `doc/claude/specs/multi_window_detach.md`.
>
> Commit chain on `fluid-editing` (each phase RED-first + a `/code-review high` gate): A `00ed9ebd`
> (+review `c85b4751`) → B `4115a27d` (+`fd12f072`) → C `87a36b86` (+`2b7cf900`) → D `4ab92062`
> (+`03597562`) → E `38bf4ea4` (+docs `0f66df43`, +review `ba14af94`). Deferred cleanups logged as
> issues `0030` (dash-period recompute), `0031` (per-window style-table staleness), `0032`
> (anim-update fan-out cost).

**Today it's front-window-only on purpose, but the groundwork is mostly there.** xschem already
keeps a **separate `Xschem_ctx` per window/tab** in the `save_xctx[]` array (`get_save_xctx()`,
`xinit.c:83`); the global `xctx` (`globals.c:236`) just points at the current/front one. Each
context owns its own `window`, `save_pixmap`, cairo surfaces/contexts, `gc[]`/`gc_hilight`,
zoom/pan, object arrays and hilight tables (`xschem.h:1058`+). The catch: **all drawing operates
on the global `xctx`** — to draw window N you must repoint `xctx` at `save_xctx[N]`.

The animation path bakes "front-only" into three spots:
- `net_hilight_anim_update()` (`hilight.c`) arms the Tcl tick only for `xctx->current_win_path`.
- `net_hilight_has_animation()` / `scan_animating_hilights()` / `draw_hilight_region()` all read
  the **global** `xctx`.
- `xschem redraw_hilight_region <win>` (`scheduler.c`) explicitly **returns 0 (stop)** when
  `win != xctx->current_win_path`, so a background window's tick cancels itself.

The one piece already multi-window-ready is the Tcl tick itself: `net_hilight_after` is an array
keyed by window path, so N concurrent self-rescheduling ticks already work.

**What it needs (see the plan doc for the atomic RED-first steps):**
1. A **side-effect-free "borrow context for a draw" primitive** — repoint `xctx` → `save_xctx[N]`,
   regional-redraw into N's pixmap+canvas, repoint back, with **no** focus/raise/title side
   effects (unlike the existing `switch_window()`, `xinit.c:1579`, which is heavyweight). *This is
   the only real risk* — drawing is almost all `xctx`-relative, but it needs an audit for hidden
   global draw state (`bbox()`, `set_clip_mask`, cairo globals).
2. Make the per-window query/frame evaluate window N via that borrow (`get net_hilight_animated
   <win>`, `redraw_hilight_region <win>`); drop the front-window bail.
3. `net_hilight_anim_update` arms **every** animating window (iterate `save_xctx[]`), not just the
   front.
4. Serialize the borrows + never borrow mid-gesture (globalize the `semaphore`/`HILIGHT_ANIM_BUSY`
   checks).
5. Animate only **visible** canvases → this is really a **detached-windows** feature; background
   **tabs share one canvas and aren't visible**, so they correctly stay static (gate on
   `winfo viewable`).
6. The wall-clock (`net_hilight_now_ms`) is already global, so all windows animate in sync — no work.

It is **not a new subsystem** (per-window contexts + per-window ticks already exist); the work is
lifting the "global front `xctx`" assumption out of those four entry points. It's the same
deferral the Pass-2a/2b reviews kept flagging, and a natural sub-item of the broader
**multi-window-detach** work (`doc/claude/specs/multi_window_detach.md`).

---

## Q19. Where are the net-highlight keys `9`/`8`/`0` defined, and how do I reassign them?

- **Asked:** 2026-06-24
- **Project state:** branch `fluid-editing` @ `0934579e`. Net-highlight-styles plan
  (`doc/claude/suggestions/plan_net_hilight_styles.md`): Pass 1 (Phases 1–4) + Pass 1.5 (tilted
  stripes) complete; only Pass 2 (animation) remains. Spec: `doc/claude/specs/net_hilight_styles.md`.

**They are three plain Tk bindings in `src/cadence_style_rc` (lines 81–83), each firing one
`xschem` subcommand:**

```tcl
bind .drw <Key-9> {xschem hilight_net_interactive;   break}   ;# highlight net(s)
bind .drw <Key-8> {xschem unhilight_net_interactive; break}   ;# remove a specific highlight
bind .drw <Key-0> {xschem unhilight_all;             break}   ;# remove ALL highlights
```

| Key | Command | Behavior |
|---|---|---|
| `9` | `xschem hilight_net_interactive` | noun-verb if a net/wire/label is selected (highlight it, advancing the style each press, selection kept); else verb-noun click-to-highlight mode, ESC to end |
| `8` | `xschem unhilight_net_interactive` | remove highlight on the selection, or click-to-remove mode |
| `0` | `xschem unhilight_all` | clear all net highlights |

The trailing **`break` is load-bearing**: it stops the digit from also reaching the C key
dispatcher, where bare `0` toggles pin logic level (`8`/`9` are no-ops there).

**Architectural note — these are NOT in the data-driven action registry.** Unlike the
snap/grid actions of Q17/Q18 (which are registered `ActionDef`s bound via `xschem bind key
<keysym> …`), `9`/`8`/`0` are direct **Tk `bind .drw`** lines (the "Tier A" recipe of Q17).
So `xschem bind` / `xschem bindings dump` / `xschem unbind` neither list nor manage them —
you reassign them by editing the Tk binding, not the registry. (The three *commands* are
real `xschem` subcommands in `scheduler.c`; only the key→command wiring lives in the rc.)

**To reassign — edit the Tk bind in `cadence_style_rc`, your `~/.xschem/xschemrc`, or a
`--script` file:**

1. **Free the old key** (optional): delete or comment out the `bind .drw <Key-9> …` line, or
   re-point it. (To make the old digit do nothing at all, leave a `bind .drw <Key-9> {break}`.)
2. **Bind the new key** to the same command, keeping `break`:
   ```tcl
   # e.g. move "highlight net" from 9 to F5, and "clear all" from 0 to Shift-F5
   bind .drw <Key-F5>       {xschem hilight_net_interactive; break}
   bind .drw <Shift-Key-F5> {xschem unhilight_all;           break}
   ```
3. Re-source the rc (or restart). New/detached windows inherit it automatically —
   `clone_canvas_bindings` (`xschem.tcl:10932`, issue 0020) copies `.drw` bindings to each
   new canvas.

**Gotchas.**
- Bind by the **keysym the chord actually emits**: Shift changes it (on a US layout `Shift-9`
  is `parenleft`, not `9`), so `bind .drw <Key-parenleft> …`, not `<Shift-Key-9>`. Run `xev`
  (or `wish`'s `bind . <Key> {puts %K}`) to read a key's keysym.
- The command is the stable part — you can wire `hilight_net_interactive` to **any** key,
  or even a mouse button (`bind .drw <Button-2> {xschem hilight_net_interactive; break}`) or a
  menu entry; only the trigger changes.
- These bindings live in `cadence_style_rc`, so they exist only when that rc is sourced. To
  have them everywhere, move the three lines into your `~/.xschem/xschemrc`.

**If you instead want them in the remappable registry** (so they show in `bindings dump` and
take CSV rows), that's the Q17 **Tier B** path: register `ActionDef`s wrapping the three
commands in `callback.c`, then `xschem bind key 57 0 canvas net.hilight` (etc.). That needs a
recompile and is only worth it if you want registry-managed remapping; for a personal key
swap, the Tk `bind` edit above is the one-line, no-recompile answer.

---

## Q18. Some keyboard shortcuts stopped working — `g`/`G` (snap), `Ctrl-g`, `Alt-g`, `%` (grid). Where did they go, and how do I get them back?

- **Asked:** 2026-06-23
- **Project state:** branch `fluid-editing`, plan
  `doc/claude/suggestions/plan_keybind_snap_grid_actions.md` Phases 0–2 landed (snap defaults
  removed, the five actions registered, `cadence_style_rc` rebind recipes added);
  Phase 3 (delete the now-dead `case 'g'`/`case '%'`) still pending. Spec:
  `doc/claude/specs/keybind_snap_grid_actions.md`. Background: Q17.

**They didn't disappear — they were turned into *user-bindable actions* that now ship
UNBOUND, so you choose the keys.** The snap / grid / net-highlight operations used to be
hard-wired to specific keys in C. They are now entries in the action registry with **no
built-in default chord**, so every key mapping is yours to set (the whole point: map keys
to functions from Tcl / a loadable script, nothing soldered in C). The *functions* are
unchanged and still on the menus (Options / View).

**Where to get them back: the binding block in `src/cadence_style_rc`** (the
`# --- snap / grid / highlight key actions ---` block, ~lines 128–146). Uncomment the
`xschem bind` line for the shortcut you want:

| Old key | Did | Action id | Recipe in cadence_style_rc |
|---|---|---|---|
| `g` | halve snap | `view.snap_half` | line ~140 (commented) |
| `Shift-g` (`G`) | double snap | `view.snap_double` | line ~141 (commented) |
| `Alt-g` | highlight net → waveform viewer | `hilight.send_to_waveform` | line ~142 (commented) |
| `Ctrl-g` | set snap value (dialog) | `view.set_snap_value` | line ~143 (commented; old `Ctrl-g` is now grid) |
| `%` | toggle grid | `view.toggle_draw_grid` | line ~146 (commented) |

**`CTRL-G` is the one that ships active** — `cadence_style_rc` line ~137 binds it to
`view.toggle_draw_grid`, so under the cadence config **Ctrl-G toggles grid visibility**.

**The general way** (works in any rc / `--script` / the CIW):
`xschem bind key <keysym> <mods> canvas <action>` — keysyms `g`=103, `G`=71, `%`=37,
`s`=115 (run `xev` for others), mods `0|ctrl|alt|shift|super` joined by `+`. List what's
live with `xschem bindings dump`; remove one with `xschem unbind`. Gotcha: Shift changes
the produced keysym (Shift-g → `G`/71), so bind the chord by the keysym it actually emits.
See Q17 for the binding-table internals and `doc/claude/specs/keybind_snap_grid_actions.md` for the
full design.

---

## Q17. What is CTRL-G bound to currently, and what would it take to use it to toggle grid display ON/OFF?

- **Asked:** 2026-06-23
- **Project state:** branch `fluid-editing` @ `2919e381` (just after the 8
  code-review fixes, issues 0019–0026). The relevant substrate is the
  action-registry binding table (`feature/action-registry`): data-driven
  `ActionDef` table, `xschem bind/unbind/bindings`, context-aware dispatch —
  the migration from hardcoded C `case` keys to the table is **partial**.

> **Update (2026-06-23, IMPLEMENTED).** This was built — but the design landed *cleaner*
> than the "Tier B default binding" recommendation below: there is **NO built-in default**.
> The five ops are registered actions (`view.snap_half`, `view.snap_double`,
> `view.set_snap_value`, `hilight.send_to_waveform`, `view.toggle_draw_grid`) that ship
> **UNBOUND**; the `g`/`G` snap defaults were removed and the hardcoded `case 'g'`/`case '%'`
> deleted. Every chord is user-specified — `cadence_style_rc` carries the **active**
> `xschem bind key 103 ctrl canvas view.toggle_draw_grid` (so CTRL-G toggles grid under that
> config) plus commented recipes for the rest. See `doc/claude/specs/keybind_snap_grid_actions.md` and
> Q18 (how to rebind the shortcuts that "disappeared"). The Tier A/B/C analysis below is kept
> as the historical "what it would take" picture.

**CTRL-G currently *sets the snap value*** — it pops an `input_line` dialog
("Enter snap value…") and applies it via `xschem set cadsnap`. It is a
**hardcoded C branch** (`callback.c:3884`, `case 'g':` → `if(rstate==ControlMask)`),
**not** in the data-driven table. For context, the other `g` chords are:

| Chord | Does | Where |
|---|---|---|
| `g` | halve snap factor | `view.snap_half` (table; `keybindings.csv:32`, `act_snap_half` `callback.c:2602`) |
| `Shift-g` (`G`) | double snap factor | `view.snap_double` (table; `keybindings.csv:33`) |
| `Ctrl-g` | **set snap value (dialog)** | hardcoded `callback.c:3884` |
| `Alt-g` | highlight net → waveform viewer | hardcoded `callback.c:3890` |

**Grid toggling today** flips the Tcl var `draw_grid` and redraws. It is reachable
two ways, both hardcoded / not an action:
- the `%` key — `callback.c:4708` `case '%'`;
- Options menu **"Draw grid"** checkbutton (`xschem.tcl:11341`, `-variable draw_grid`,
  `-command {xschem redraw}`, accelerator `%`).

There is **no `view.toggle_draw_grid` action** in the registry yet.

**Key precedence fact.** The binding table is consulted **first**: `handle_key_press`
calls `dispatch_input_action()` at `callback.c:3601` and `return`s early on a match —
so a table entry for Ctrl-g will *shadow* the hardcoded "set snap value" case
automatically (that numeric-snap function then loses its Ctrl-g access; plain `g`/`G`
snap still work). Actions can be **C-backed** (`d->fn`) or **Tcl-backed** (`d->tcl`,
`dispatch_input_action` `callback.c:2994`), which decides whether a change needs a
recompile.

**Three tiers to make Ctrl-G toggle the grid:**

**Tier A — rc one-liner, no recompile (fastest).** A more-specific Tk binding pre-empts
the generic `<KeyPress>`→C dispatch (same trick as the command palette's
`<Control-Shift-Key-P>`). Add to `cadence_style_rc` / xschemrc:
```tcl
bind .drw <Control-Key-g> {set draw_grid [expr {!$draw_grid}]; xschem redraw; break}
```
Propagates to new/detached windows automatically (issue 0020's `clone_canvas_bindings`
fix). Downsides: bypasses the action log and the keybindings table.

**Tier B — data-driven action, the "right" way (needs a rebuild).** Matches the
codebase's migration direction and gives action-log + CSV-remap for free:
1. In `callback.c`, lift the `case '%'` body into `toggle_draw_grid_cmd()` + an
   `act_toggle_draw_grid` wrapper, and register
   `{ "view.toggle_draw_grid", act_toggle_draw_grid, NULL, "Toggle grid display" }`
   in the `ActionDef` table (next to `view.toggle_draw_pixmap`, `callback.c:2694`).
2. Bind the chord — either a default in `init_input_bindings`
   (`set_input_binding(DEV_KEY, 'g', ControlMask, ACTX_CANVAS, "view.toggle_draw_grid");`,
   mirroring `callback.c:2848`) or a CSV row `key,103,ctrl,canvas,view.toggle_draw_grid`.
3. Decide where "set snap value" goes: it's auto-shadowed by the table-first dispatch,
   so either migrate it to its own action + chord, or accept dropping it.
4. (Optional cleanup) point `%` at the same action and delete the dead `case '%'`.

**Tier C — minimal C hack.** Change the `case 'g'` `ControlMask` branch body to toggle
the grid. Quick, but fights the migration and silently drops set-snap.

**Recommendation:** Tier B — ~25 lines, keeps the architecture consistent, and makes the
chord remappable from `keybindings.csv` / `xschem bind` without further code. Tier A is
the instant no-recompile fallback.

---

## Q16. After the wire-prop-preservation fix (`06b08e61`), what difference will a user actually notice?

- **Asked:** 2026-06-19
- **Project state:** branch `fluid-editing` @ `06b08e61` (fix), docs follow-up at
  `d47558f5`. Wire-editing-on-move plan complete through Phase 6; this commit fixes
  **TC12 / R19**, the last RED — the full `tests/headless/wireedit` map (TC0–TC17) is now
  green. Bug-class write-up: `doc/claude/code_analysis/prop_dropped_on_move_tutorial.md`.

**Short answer: stretch-moving a component no longer strips a connected wire's properties
— most visibly, a bus wire stays a bus instead of being silently demoted to a plain
thin wire.** On ordinary unlabeled wires there is **no visible change** (output is
byte-identical).

**Before vs after.** When you rubber-band-stretch a wire by dragging a component it's
connected to, and the drag triggers the colinear-slide path, the move used to re-create
the surviving wire segment with **empty properties** — wiping `bus=` and any other
attribute tokens. A 4-bit bus drawn thick would come back as a plain thin wire on a
different net. After the fix the survivor **inherits the original wire's `prop_ptr`**, so
the bus (and any property) is preserved.

| | drag-stretch a `{bus=4}` wire | result |
|---|---|---|
| before `06b08e61` | saved as | `N 0 70 0 130 {}` — bus lost, wire demoted |
| after `06b08e61` | saved as | `N 0 70 0 130 {bus=4}` — bus preserved |

**When it's visible (all three must hold):**
1. stretch / rubber-band is active (`enable_stretch`, e.g. `cadence_compat` mode);
2. the wire being stretched carries a **persistent attribute** (notably a bus); and
3. the move hits the colinear-slide re-create path (`place_moved_wire()`'s V-H/H-V branch).

Because it was **silent data loss**, users who hit it before likely never traced it to
the move — they'd just notice a bus had gone thin/plain later. This removes that surprise.

**What this is NOT.** It is unrelated to the Phase-6 **exit-stub** feature (`8ba5ddf7`),
which is behind `wire_exit_stub` (default **OFF**) — users notice that one only if they
enable it (Options → "Keep stub out of moved pins"). And the very latest commit
(`d47558f5`) is an internal tutorial doc with **zero** user-facing effect.

**Why the original test premise was wrong (worth knowing).** Phase 1 asserted a wire's
`lab=A[3:0]` token survives the move. It can't — a bare wire's `lab` is a **write-only
derived-net cache** that `prepare_netlist_structs()` overwrites with the auto net name
(`#net1`) move-or-not. The real, user-visible thing to preserve is a *persistent* attribute
(`bus=`) and a real `lab_pin` net-label **instance**, which is what TC12 now tests. See the
tutorial for the full bug class (metadata loss across object re-creation).

---

## Q15. Two instances are placed so that two of their pins sit on the same point (directly connected, no wire). One instance is then moved. The pins must STAY connected — so wire segments need to be generated. What support exists for this, and where is it on the wire-editing plan?

- **Asked:** 2026-06-19
- **Project state:** branch `fluid-editing` @ `bc0fdb66`. Wire-editing-on-move plan
  (`doc/claude/code_analysis/wire_editing_spec_and_plan.md`): Phase 0 (scaffold) + Phase 1
  (TC1–TC15 baseline) + Phase 2 (sub-grid tolerant match) landed; the new
  `cadence_compat` modifier-drag feature is also in (`15dced84`).

**The mechanism already exists — `connect_by_kissing()` (`actions.c:1163`) — but the
drag path doesn't call it.** For each pin of the *moving* instance it scans (before the
move) for a coincident **non-selected instance pin** (true abutment) or a touching
wire; on a hit it inserts a zero-length wire anchored at that point (`storeobject(...,
SELECTED1, ...)`), which the move then stretches into the connecting segment. Verified
headlessly with two abutted `res.sym` pins at `(0,30)`, moving one by `(40,0)`:

| Move | Result |
|---|---|
| `xschem move_objects 40 0 kissing` | one wire `{0 30 40 30}` — **connection kept** |
| `xschem move_objects 40 0 stretch` | **0 wires — connection lost** |

It fires when `xctx->connect_by_kissing == 2`, set by: the **`M`** move command
(`callback.c:4053`) and **Ctrl+M** (`:4067`, move+stretch+kissing), an Alt-move and a
duplicate path (`:4037`/`:3683`), scripted `move_objects … kissing`
(`scheduler.c:3911`), and the **legacy intuitive Shift+drag** path (`:5272`).
`move_objects` consumes it at move END (`move.c:619/1165`).

**The gap:** the plain/stretch drag uses `select_attached_nets()`, which only stretches
*existing* wires — so dragging an abutted instance silently disconnects it. And in
**`cadence_compat`** mode the new drag branch maps plain→stretch, Ctrl→move,
Shift→copy, so **no click-drag gesture sets the kissing flag** — the legacy Shift+drag
that used to is now `copy`. So today this works only via the **`M` command** (or
scripted `kissing`), not by dragging.

**Where on the plan:** it was *not* a pre-existing test case. As of this commit it is
**TC16 (Issue H / R20)**, folded into **Phase 3** — which now routes the plain /
`cadence_compat` drag through `connect_by_kissing()`. Because that one function covers
**both** the T-junction/mid-span case (TC5) and the pin-abutment case (TC16), a single
Phase-3 change is positioned to turn both green *and* restore the kissing behavior
cadence users lost. TC16's baseline test
(`tests/headless/wireedit/test_wireedit_16_pin_abutment.tcl`) is RED on the drag path
today.

---

## Q14. Cadence supports both the verb-noun and noun-verb interaction grammars (like LTspice's verb-noun, plus the modern select-then-act). How big is the gap between XSCHEM and Cadence here?

- **Asked:** 2026-06-15
- **Project state:** branch `library-manager` @ `5661885e`. The relevant
  substrate is the action-registry binding table (branch
  `feature/action-registry`, Phase 3 plan complete) — `xschem bind/unbind/bindings`,
  data-driven `ActionDef`, context-aware dispatch, the `idle_only` semaphore flag.

**Smaller than the question implies — XSCHEM already supports *both* grammars
today.** It just doesn't frame them as "Cadence parity." The gap is qualitative
(polish + unification), not "missing feature," and the *architectural* gap is
small because the bindkey substrate Cadence is built on is exactly what the
action-registry work has been constructing.

**1 — XSCHEM already spans the verb-noun / noun-verb spectrum via four flags.**
There isn't one interaction model; there's a cluster of booleans (defaults in
`xschem.tcl:12037-12043`) that between them cover the range:

| Flag | Default | What it actually controls |
|---|---|---|
| `intuitive_interface` | **1** | The *noun-verb* refinements: click-on-object selects, click-drag a selected object moves it, click-empty deselects (`callback.c:5166-5230`). The modern select-then-act polish. |
| `infix_interface` | **1** | The verb *ordering*. `=1` → pressing `m`/`c`/`C`/`w`… acts **immediately at the cursor** (`copy_objects(START)` grabs where the pointer is). `=0` → the same key sets `MENUSTART \| MENUSTARTCOPY` and **waits for a click to anchor** (`callback.c:3656-3663`). That `=0` path *is* the verb-noun/prefix flow — and it's the path menu invocations already use. |
| `persistent_command` | 0 | The *armed-verb-repeats* behavior — the command stays active across objects until Escape (`callback.c:1892`, `5120`). LTspice's "stay in the tool." |
| `cadence_compat` | 0 | An explicit Cadence-bindkey bundle: Ctrl=simulate, click-on-selected-clears-selection, snap-cursor toggle, etc. (`callback.c:4251, 4584, 5321`). |

So pressing `c` with `infix_interface=1` gives the XSCHEM-native *infix* flow
(point already established by the cursor, verb injected in the middle); set it
`0` and the *same key* becomes prefix/verb-noun (verb first, then click a point).
The `MENUSTART`/`MENUSTART2` bits (`xschem.h:238-263`) are a per-command armed-verb
state machine that already covers move, copy, wire, line, rect, arc, polygon,
zoom, and wire-cut.

**2 — The remaining gap is qualitative.** What Cadence has that XSCHEM's version
doesn't:

1. **A unified command/point-entry kernel.** Cadence's `hiEnterPoint`/`hiGetPoint`
   is one generalized mechanism: a command declares "I need K points," the kernel
   collects them, drives the status-bar prompts ("Point at reference… Point at
   destination"), and allows **typed coordinate entry**. XSCHEM hardcodes the
   prefix flow per-command via `MENUSTART2` bits and scattered
   `if(infix_interface)` branches. No prompt line guiding the points, no
   coordinate typing. **This is the single biggest gap.**
2. **`persistent_command` is narrow.** The menu only exposes it as "Persistent
   wire/line place command" (`xschem.tcl:10962`); Cadence makes nearly *every*
   command persistent/repeating.
3. **No per-command options form.** Cadence's F3 brings up the active command's
   option form mid-gesture; XSCHEM has global toggles, not command-scoped ones.
4. **The modes are four loosely-coupled booleans, not a model.** They interact
   ad-hoc — `callback.c:2842` already notes `cadence_compat`-gated keys "the table
   can't express," and the action-registry work hit `s`/`Ctrl+r` keys that couldn't
   migrate because forward-behavior lives inside a `cadence_compat`-conditioned
   branch.

**3 — Why the *architectural* gap is small.** The substrate Cadence is built on
is bindkeys + a central command dispatcher — exactly what `feature/action-registry`
constructed: `xschem bind/unbind/bindings`, a data-driven `ActionDef` table (Tcl-
or C-backed), context-aware dispatch, an `idle_only` flag mirroring
semaphore-sensitivity. *That is the bindkey half of Cadence.* The missing half is
a **generalized point-entry state machine** layered on the dispatcher — one that
replaces the per-key `MENUSTART2` bit-twiddling and the `if(infix_interface)` forks
with: *"current command C wants N points; here are its prompts; here's whether it
persists; here's its options form."* Build that and the four flags collapse into
one coherent model, with prefix/infix/persistent/cadence behaviors becoming
*configurations* of it rather than separate code paths.

**Bottom line:** feature-wise the gap is modest (both grammars already exist;
what's missing is a prompt/point-entry kernel, generalized persistence, and
command-scoped options); architecturally it's small and shrinking, because the
dispatcher being decomposed is the right foundation and the `MENUSTART` machinery
is a working-but-ad-hoc prototype of the kernel you'd formalize.

---

## Q13. Why doesn't pressing `q` to open the Edit Properties form write `xschem edit_prop` to the action log?

- **Asked:** 2026-06-14
- **Project state:** branch `slick-property-forms` @ `098f4ea1` (the slick
  property form + multi-instance editing + the scope highlight + the modeless
  selection M1 have all landed; the action-logging machinery from
  `feature/action-logging` is present in this lineage).

**Because the action log records *committed effects*, not *user intentions* —
and "open a dialog" is an intention, not an effect.** Pressing `q` is genuinely
unlogged, but the fix is not "log `q`"; understanding *why* teaches three
architecture ideas that outlast this one key.

**1 — The log is opt-in at chokepoints, not an automatic command tap.** It is
tempting to assume the log wraps the one `xschem` dispatcher (`scheduler.c`) and
records every subcommand for free — the way the binding table funnel made key
remapping free (Q7). It doesn't. Logging is a **curated set of hand-placed
`log_action("xschem …")` calls** at specific sites: gesture completions
(wire/line/rect/arc/move/copy in `actions.c`), pan/zoom and placements
(`callback.c`), file open/save (resolved paths). A path with no `log_action()`
writes nothing. The `q` key calls the C function `edit_property(0)` **directly**
(`callback.c:4130`) — it never even goes through the `xschem edit_prop` Tcl
command — and neither it nor `edit_property()` carries a `log_action`. So:
silence, by omission.

> Why opt-in rather than a blanket tap on the dispatcher? Because most `xschem`
> subcommands are **queries** (`get`, `wire_coord`, `objects`, `instance_id`, …)
> — read-only, fired constantly, and meaningless in a replay. A blanket tap would
> drown the signal (the few state-changing commands) in noise (the thousands of
> reads), and would still mis-handle the interactive ones (next point). Curation
> is the cost of a log that is actually *replayable*.

**2 — Log the effect, not the gesture. `edit_prop` is the wrong thing to log
even in principle.** `xschem edit_prop` just **opens a modal dialog**. A log is
only useful if it can be *replayed*, and replaying "open a dialog" would pop a
window and block, waiting for a human — there is nothing deterministic to re-run.
This is the same reason file open/save log the **resolved path**
(`xschem load {…/foo.sch}`) rather than "the open-file dialog appeared." The
replayable thing a property edit produces is the mutation the form issues on
OK/Apply:

```
xschem apply_properties <scope> <displayed_id> <new_prop> <old_prop>
```

That command is deterministic and idempotent-on-replay; `edit_prop` is neither.
So the right design is: **don't log the dialog-open as a *replayable command*; log
the apply.** The general principle — worth carrying to any undo/redo, audit-trail,
or event-sourcing system — is *record the committed transition (old→new state),
not the UI event that led a human to it.* Intentions are infinite and interactive;
effects are finite and replayable.

> **Update (2026-06-14): the launch *is* now recorded — as a non-replayable
> marker, not a command.** Opening the form writes a Tcl-comment line,
> `# xschem edit_prop <scope> — Edit Properties form opened (non-replayable:
> modal)`, emitted at `slickprop::edit_form` (the one point `q`/menu/`xschem
> edit_prop` converge). Because it begins with `#`, `source`-ing the log **skips
> it** — so the audit record of "the user opened the editor" coexists with a
> replayable log, and the modal never re-opens on replay. This is the key
> distinction: *a replay log can carry two kinds of line* — replayable commands
> (the apply) and inert `#` markers for intentions worth recording but not
> re-executing. Don't force an interactive event into a replayable command;
> demote it to a comment.

> This is exactly the **command/query and intent/effect split**. A keystroke, a
> menu pick, and a scripted call can all reach the same effect by different
> routes; logging at the effect captures all three with one instrumentation
> point, while logging at the gesture would need three (and would record the two
> interactive ones unreplayably).

**3 — So where's the bug? Not in `q` — in coverage.** The honest gap was that
`apply_properties` *itself* was **also not logged** (added for the multi-instance
work without a `log_action`). So property edits were absent from the replay log in
*any* form. **(Now fixed — see the placement subtlety below, which is the real
lesson.)**

**3a — The instinct is right, the placement is a trap.** The obvious fix is "one
`log_action` in the **funnel** every Apply/OK passes through —
`apply_instance_properties()` (`editprop.c`)." That is where you'd put *identity*
or *undo* (Q7): one chokepoint, every route covered. **But for a replay log it is
wrong**, and seeing why is the payoff of this question. Look at *who* calls that
funnel:

| caller | reaches `apply_instance_properties()` via |
| --- | --- |
| the form's OK / Apply | `do_apply` → `xschem apply_properties` |
| a CIW-typed command | the CIW → `xschem apply_properties` |
| **replay** (sourcing the log) | `source` → `xschem apply_properties` |
| a script / keybinding | → `xschem apply_properties` |

A `log_action` in the funnel fires for **all four**. Two of them must *not* be
logged from there: the **CIW already logs typed commands itself** (you'd write the
line twice), and **replay must re-execute without re-recording** (logging in the
funnel makes replaying a log *grow a fresh copy of every edit*). This is the exact
trap the engine already documents at `callback.c`: *"hooking move.c instead would
double-log every replay"* — move/zoom log at the **interactive gesture layer**
(`callback.c`), never in the engine (`move.c`) that the `xschem move_objects`
command reuses.

So the correct site is the **interactive layer** — the form's `do_apply`, which
replay/CIW/scripts never call:

```tcl
# slickprop::do_apply, after a successful apply ($did): log the REPLAYABLE
# command itself (built with [list ...] so it re-parses when the log is sourced).
if {$did} {
  slickprop::log_apply [list xschem apply_properties \
    $::slickprop_apply_scope $nav(disp_id) $::tctx::retval $cur(orig)]
}
```

> **The distinction worth internalizing:** *state-mutation* concerns (identity,
> undo, cache invalidation) belong at the **engine funnel** — the one place every
> route mutates. A *replay log* belongs one layer **up**, at the **interactive
> trigger** — because the log's own replay vehicle is the engine command, and a
> recorder that sits on its own playback head records itself. Same codebase, two
> different "right chokepoints," chosen by whether the concern must *not* re-fire
> during replay.

**One caveat the student should not miss: a replay log is only as good as its
*referents*.** `displayed_id` is a **session-stable** id (Q7/Q8) — unique and
durable *within* a run, but minted fresh each session and not written to the
`.sch` file. So a logged `apply_properties … 42 …` replays perfectly in the same
session, but feeding last week's log to a fresh process may have id 42 refer to a
different object (or nothing). This is the known "stable referents" problem
(deferred *issue 0005* in the action-logging spec): a faithful command log still
needs **stable names** for the things its commands point at, or replay across
sessions silently drifts. Logging the command is half the job; making its
arguments mean the same thing tomorrow is the other half.

**Takeaways for an aspiring engineer:**
- A good event/audit/undo log records **state transitions (effects)**, not
  **UI events (intentions)** — effects are deterministic and replayable;
  intentions are interactive and infinite.
- Pick the chokepoint by the **concern**: *state-mutation* concerns (identity,
  undo) go at the **engine funnel**; a **replay log** goes one layer up at the
  **interactive trigger**, or it records its own playback and double-logs.
- **Opt-in beats blanket** for replay logs: most calls are queries; recording
  everything destroys the signal and still botches the interactive cases.
- A log is only replayable if its **referents are stable** across the replay
  horizon you care about (same session vs. across sessions).

---

## Q12. With several schematic windows open, how do you get the wire list of *one specific* schematic?

- **Asked:** 2026-06-13
- **Project state:** branch `feature/stable-object-handles` @ `1c653298`.

**Switch the active context to that window, then query — there is no
"query window X while window Y is active."** Every `xschem` query command
(`get wires`, `wire_coord`, `wire_id`, `selection`, …) reads the **active
context** only (the global `xctx`). The single command that reaches across
windows is `tab_list`, and it returns only filenames. So the procedure is
always *find the window → switch to it → query → (optionally) switch back.*

```tcl
# 1. find the window holding the schematic you want, by filename.
#    tab_list rows are: {win_path} {full_filename}
set target {}
foreach line [split [xschem tab_list] \n] {
  if {[string match *Q1.sch* $line]} { set target [lindex $line 0] }
}
#    -> target is e.g. ".x1.drw"

# 2. make that window the active context
xschem new_schematic switch $target

# 3. the wire queries now refer to THAT schematic
set n [xschem get wires]                 ;# e.g. 19 (Q1's wire count)
for {set i 0} {$i < $n} {incr i} { ... } ;# Q1's wires
xschem selection                         ;# Q1's selection

# 4. (optional) go back
xschem new_schematic switch .drw         ;# main window
```

Verified headless against three open schematics (mos_power_ampli=91,
Q1=19, bus_keeper=8 wires): each switch + `get wires` returned the right
count, and the contexts stay fully isolated.

**Naming the target — two forms, and one trap.** `new_schematic switch`
accepts either:

- a **win_path** — `.drw` is the main window, then `.x1.drw`, `.x2.drw`, …
  This is the robust id; read it from `tab_list`, don't hardcode it.
- a **schematic basename *with extension*** — `xschem new_schematic switch
  Q1.sch`.

The trap (found while verifying): switch-by-name matches the **basename only**
(`get_cell_w_ext`, `xinit.c:1341` `get_tab_or_window_number`), *not* a path.
`xschem new_schematic switch /…/examples/bus_keeper.sch` **silently does
nothing** (stays put). Use `bus_keeper.sch`, or use the win_path. If two
windows hold the same basename, only the win_path disambiguates.

**Nuances worth knowing:**

- **Opening makes it active.** `new_schematic create {} <file>` switches the
  active context *to* the new schematic — after opening several you are "in"
  the last one created, not back in main.
- **You get the level currently shown.** If that window has descended into a
  sub-schematic (hierarchy push), `get wires` returns the *sub-sheet's* wires,
  not the top sheet's. `xschem get currsch` is the depth (0 = top).
- **Wire ids are per-context.** Id 5 in window A is a different wire from id 5
  in window B — each context has its own monotonic `wire_id_counter` (see Q9).
  Collecting handles across windows? Tag each id with its win_path.
- **`switch previous`** works only in tabbed mode; in separate-window mode it
  is a no-op (`xinit.c:1536`).
- **Wire 0** still has the `wire_coord 0` off-by-one — a *complete*
  enumeration loops from index 1 plus the `saveas` ground-truth fallback (see
  `doc/stable_wire_handles.md` §6); the id-based commands (`wire_id 0`,
  `selection`) are not affected.

This is purely about *reading* a chosen context; the underlying multi-window
model (tabbed vs windowed, `MAX_NEW_WINDOWS`, hierarchy vs separate windows) is
Q9.

---

## Q11. Is there a way to iterate over the *selected* objects from a script?

- **Asked:** 2026-06-13
- **Project state:** branch `feature/stable-object-handles` @ `7539fa68`
  (wire stable handles shipped; selection-as-data still a gap).

> **Update (2026-06-13, same day): the gap is now closed.** The
> `xschem selection` command described at the bottom of this answer was
> implemented (TDD, RED commit then GREEN) and is the recommended way to
> iterate the whole selection:
>
> ```tcl
> xschem selection
> ;# -> {text 0 3 7} {wire 0 1 6} {line 0 4 5} ...
> ```
>
> It returns one `{type index col id}` Tcl list element per selected object
> across all seven types — `type` ∈ `wire|instance|rect|line|poly|arc|text`,
> `index`/`col` address the object, and `id` is the session-stable id. **All
> seven drawable types now carry an id** (an `id` of `-1` means a *dangling*
> reference, not a type without ids). So
> `foreach o [xschem selection] { lassign $o type idx col id … }` works, and
> `xschem objects`/`object` give the same data as self-describing dicts plus a
> resolver (`doc/object_query_api.md`). The analysis below is kept as the
> historical "before" picture.

**Partially — and the gap is instructive.** The *complete* selection already
exists inside the engine, but only fragments of it are exposed to Tcl, so a
single generic "for each selected object" loop is **not** possible through the
documented surface today.

**What exists in C.** `rebuild_selected_array()` (`move.c:52`) walks all seven
object types and fills `xctx->sel_array[]` with a `{type, n, col}` triple for
every selected object — texts, instances, wires, then per-layer arcs / rects /
lines / polygons — and sets `xctx->lastsel` to the count. So the full, typed
selection list is assembled and sitting in memory after any selection change.

**What Tcl can actually read** — only pieces of that array:

| Command | Covers | Returns |
| --- | --- | --- |
| `xschem get lastsel` | all types | just the **count** |
| `xschem get first_sel` | all types | only the **first** object: `type n col` |
| `xschem selected_set` | **instances** only | `{name} {name} …` |
| `xschem selected_set rect` | **rects** only | `col n x1 y1 x2 y2` per line |
| `xschem selected_set text` | **texts** only | `n x y rot flip {txt}` per line |
| `xschem selected_wire` | **wires** only | net **labels** — *not* indices/handles |
| lines, polygons, arcs | — | **not exposed at all** |

(`selected_set` is defined at `scheduler.c:5589`; it switches only on `rect` /
`text` and otherwise defaults to instances — `selected_wire` at
`scheduler.c:5632`.)

So concretely, from a script you **can**:

- iterate selected **instances**, **rectangles**, and **texts** (three
  separate `selected_set` calls);
- read the **net labels** of selected wires (`selected_wire`);
- get the **count** (`get lastsel`) and the **first** selected object's
  type+index (`get first_sel`).

And you **cannot**:

- get a selected wire's *index or stable id* (only its label) when more than
  one object is selected — `get first_sel` shows just the first;
- enumerate selected **lines, polygons, or arcs** at all;
- get one unified list of everything selected.

This is the "selection as data" gap from `tcl_introspection_wire.md` §4 and
defect #4 (`selected_set` omits WIRE / LINE / POLYGON / ARC). It is purely a
*missing exposure*, not missing data: `sel_array` already holds the answer.

**Type codes** (for reading `first_sel` / `sel_array`):
`WIRE=1, xRECT=2, LINE=4, ELEMENT=8, xTEXT=16, POLYGON=32, ARC=64`
(`xschem.h:265–271`).

**The natural fix** is one new dispatcher branch — e.g. `xschem selection`
returning `type index col` (plus, for wires, the stable id from the Q7/handle
work) one row per selected object across all seven types — turning the
already-populated `sel_array` into a real, scriptable "iterate every selection"
list. That is the selection half of the planned `xschem object` uniform API,
and it is now more valuable because wires carry stable ids the command could
hand back.

---

## Q10. Can you open a schematic or symbol in *read-only* mode?

- **Asked:** 2026-06-12
- **Project state:** branch `feature/stable-object-handles` @ `10c3f2f8`
  (step 1 of stable handles complete; the wire-handle manual just landed).

**No — XSCHEM has no read-only / view-only open mode today.** Every file you
open is loaded into a fully editable in-memory context. There is no
application-level lock, no flag, and no startup option that makes a loaded
schematic non-editable. Specifically, the searches come back empty on all of
these:

- **No `xschem load` flag for it.** The `load` command
  (`scheduler.c`, the `xschem_cmds_l` group) accepts
  `-nosymbols | -gui | -noundoreset | -nofullzoom | -nodraw | -keep_symbols |
  -lastclosed | -lastopened` — controlling *symbol loading, undo, zoom and
  drawing*, none of them editability. There is no `-readonly`, `-view`, or
  `-noedit`.
- **No command-line flag.** The startup option parser (`options.c`) has
  `-x/--no_x` (headless), `-b/--detach`, output/netlist selectors, etc., but
  nothing like `--readonly` or `--view`. (Note `-r` is already taken — it
  means `--no_readline`, not read-only.)
- **No write-permission awareness at open time.** XSCHEM does not `access(…,
  W_OK)` a file when loading it and does not warn that a file is unwritable.
  The permission check happens only at *save*: `save_schematic()`
  (`save.c:~3470`) just does `fopen(schname, "w")` and, if that fails, pops
  `alert_ {file opening for write failed!}`. So you discover a file is
  read-only on the filesystem only when you try to save it.
- **The `modified` flag is not a lock.** `xctx->modified` (set via
  `set_modify()`) only drives the "save your changes?" prompt on close/reload;
  it never prevents an edit.

**The closest things that *do* exist** (and how you might lean on them):

1. **Per-element `lock` attribute.** Any object can carry `lock=true` in its
   property string; `select.c` (the `select_*` functions, ~lines 896–1226 for
   wire / inst / text / rect / poly / line) refuses to select a locked object
   for editing unless you override with Shift-click. This is *per-object, not
   per-file*, it's bypassable, and it doesn't stop programmatic edits — but it
   is the only built-in "don't touch this" mechanism. A script could stamp
   `lock=true` on everything to approximate a soft read-only.
2. **Filesystem permissions.** `chmod -w file.sch` genuinely protects the file
   on disk — XSCHEM will let you open and edit the in-memory copy, but the
   eventual save fails loudly. Read-only-on-disk plus "don't save" is the
   honest current workaround for "I just want to look."
3. **Headless inspection.** For pure querying with zero risk of mutation,
   `xschem -x -q --script <file>` (or `--pipe`) loads the file and lets a
   script read it via the `xschem` query commands without ever opening an
   editable window.

If a real read-only mode were wanted, the natural shape — given the
stable-handles direction — would be a context-level `read_only` flag checked at
the mutation funnel (the same chokepoint the handle work is building), plus an
`access(W_OK)` probe at load that sets it automatically for unwritable files.
That is not implemented; it is noted here as the obvious place it would go.

---

## Q9. What support is there for multiple open schematics/symbols — windows and tabs?

- **Asked:** 2026-06-12
- **Project state:** branch `feature/stable-object-handles` @ `10c3f2f8`.

**Good support — XSCHEM can hold many schematics/symbols open at once, in
either tabs or separate windows, each with its own fully independent state.**
The key facts:

**Two interchangeable modes, one switch.** The Tcl boolean
`tabbed_interface` (`xschem.tcl`, `set_ne tabbed_interface 1` — **default on**)
chooses between:
- **Tabbed** — all schematics share one top-level X11 window, switchable via a
  tab bar (`create_new_tab` / `switch_tab` / `destroy_tab` in `xinit.c`);
- **Windowed** — each schematic gets its own top-level window
  (`create_new_window` / `switch_window` / `destroy_window`).
`new_schematic()` (`xinit.c`) reads the flag at runtime and dispatches to the
right pair, so the *same commands* drive both.

**Each open schematic is a separate `Xschem_ctx`.** This is the important part
for scripting: every tab/window owns a complete, independent copy of the editor
state — its own `wire[]`, `inst[]`, selection, undo stack, zoom, hierarchy
stack, *and (per the stable-handles work) its own wire-id counter.* They live
in a `save_xctx[MAX_NEW_WINDOWS]` array (`xinit.c`); the global `xctx` always
points at the active one, and switching tabs/windows just repoints it. A wire
id is unique **within one context**, not across contexts — two tabs can both
have a wire with id 5.

**The Tcl commands a script uses** (all verified against `scheduler.c`):

| Command | What it does |
| --- | --- |
| `xschem new_schematic create <win_path> [file]` | open a new tab/window (empty, or with `file` loaded). `win_path` is `{}` for auto, or e.g. `.x1.drw` |
| `xschem new_schematic switch <win_path>` | make that tab/window active (`win_path` may be `previous` or a schematic name) |
| `xschem new_schematic destroy <win_path>` | close one tab/window |
| `xschem new_schematic destroy_all [force]` | close all extra tabs/windows |
| `xschem tab_list` | list every open tab/window as `{win_path} {filename}` rows |
| `xschem get current_win_path` | path of the active tab/window (`.drw` for the main one, `.x1.drw`, `.x2.drw`, …) |
| `xschem get ntabs` | number of *extra* tabs (0 = only the main one) |
| `xschem get schname` / `sch_path` / `currsch` | name / hier-path / hierarchy level of the active context |

**The hard limit is `MAX_NEW_WINDOWS = 20`** (`xschem.h`) — try to open a 21st
and `create_new_window` / `create_new_tab` refuse with "no more free slots."

**Don't confuse "open windows" with "hierarchy depth."** These are two
different stacks:
- *Descending* into a sub-circuit (double-click an instance) pushes onto the
  **hierarchy stack** `sch[CADMAXHIER]` (`CADMAXHIER = 40`) **inside the same
  context and the same window** — `currsch` counts the depth (0 at top). You're
  still in one `xctx`, looking deeper into one design.
- *Opening* a file in a new tab/window allocates a **brand-new `xctx`** with its
  own `currsch = 0`. A genuinely separate design, separate undo, separate
  everything.

So "20" bounds how many separate designs you can have open; "40" bounds how
deep you can drill into any one of them.

---

## Q8. Besides wires, what object types does XSCHEM have?

- **Asked:** 2026-06-12
- **Project state:** branch `feature/stable-object-handles` @ `10c3f2f8`.
  The stable-handle work so far covers **wires only**; this question is about
  what the other types are, since they are the roadmap for the rest of the
  identity work.

**XSCHEM schematics/symbols are built from seven drawable object types, plus
the symbol *definition* that instances point at.** They are all defined
together near the top of `xschem.h` and each lives in its own array on `xctx`.
The type constants (`xschem.h:265–271`) double as a bitmask:

| Const (value) | Struct | `xctx` array | What it is |
| --- | --- | --- | --- |
| `WIRE` (1) | `xWire` | `wire[]` | a net segment (the type the handle work started on) |
| `xRECT` (2) | `xRect` | `rect[layer][]` | rectangle / box — also pins, graphs, embedded images (by layer) |
| `LINE` (4) | `xLine` | `line[layer][]` | a graphical line (by layer) |
| `ELEMENT` (8) | `xInstance` | `inst[]` | a placed **component instance** (a reference to a symbol) |
| `xTEXT` (16) | `xText` | `text[]` | a text label / annotation |
| `POLYGON` (32) | `xPoly` | `poly[layer][]` | a polyline / polygon (by layer) |
| `ARC` (64) | `xArc` | `arc[layer][]` | a circular arc or (via attrs) circle/ellipse (by layer) |

And separately:

- **`xSymbol`** (`sym[]`) — a loaded **symbol definition** (the master). It is
  not a placed object you draw; it is the template an `xInstance` references.
  Editing a `.sym` file edits one of these; placing it in a schematic creates
  an `xInstance` (`ELEMENT`) that points at it.

**Two structural facts a script author should know**, because they shape how
each type is addressed and how much identity work each will need:

1. **Three types are flat arrays; four are per-layer.** `wire`, `text` and
   `inst` are single arrays indexed by one number — hence `xschem select wire
   5`, one index. But `rect`, `line`, `poly` and `arc` are arrays *per drawing
   layer* (`xRect **rect;` = one array per `cadlayers`) — so they are addressed
   by **(layer, index)**: `xschem select rect <color> <n>`. That extra
   coordinate is why their commands look different from wires'.
2. **The scatter the identity work has to tame differs by type.** Instances are
   the planned next target precisely because they have the worst remaining
   lifecycle scatter (`xctx->instances++` happens in `paste.c`, `move.c`,
   `actions.c`, …), the mirror image of the wire situation that Q7 describes.
   The recipe proven on wires — census every birth/death/compaction site,
   funnel them through one family of functions, then stamp a per-context
   monotonic id at the funnel — repeats type by type. Wires were chosen first
   as the simplest specimen; instances, then the per-layer graphical types,
   follow the same playbook.

The asymmetry in *query* support across these types (instances are addressable
by name and have a rich query family; wires and the graphical types are
index-only) is catalogued in `tcl_introspection_wire.md` §3 — that, plus
identity, is what the uniform `xschem object` API is eventually meant to even
out.

---

## Q7. Toward "anything through code": what is the *first* thing to address in the code?

- **Asked:** 2026-06-12
- **Project state:** branch `feature/stable-object-handles` @ `cdf9bd9e`. The
  Tcl-introspection analysis (`tcl_introspection_wire.md`) and the C-vs-C++
  objects tutorial are committed; no design or implementation yet.
- **Context:** the end goal is SKILL-class scriptability — the user can query
  and drive everything from code. Wires were the probe specimen. What's the
  keystone change?

**Not the handles themselves — the fact that the object store has no owner.**
The expectation was that `storeobject()` (`store.c:226`) is the single factory
for wires. Grepping disproved it: `xctx->wires++` also happens at **four
sites inside `check.c`** (236, 520, 595, 685 — the connectivity checker
splits and creates wires directly), and `xctx->instances++` happens in
`paste.c`, `move.c` and `actions.c`. Deletion/compaction is similarly
scattered (`check.c:298,399`, `move.c:147`, `select.c:513`).

Every capability the goal decomposes into — stable ids, coherent caches,
undo-safe references, mutation logging, change events — needs to hook the
same three events: *object born, object died, object moved in memory*. Today
those events have half a dozen doors each. So the first move is a **pure,
behavior-identical refactor: funnel object lifecycle through one chokepoint
per event.** It is the same move that already paid off twice in this
codebase: the `scheduler()` command funnel made action-logging nearly free,
and the binding-table funnel made key remapping free. xschem funnels
*commands*; it has never funneled *state mutation* — that is the missing
half of the architecture.

Build order that falls out by dependency: (1) census + funnel (verbatim,
characterization-tested); (2) identity — stamp a monotonic id at the funnel's
birth point, maintain id→index at death/compact; (3) coherence — cache
invalidation moves into the funnel, killing the stale-query bug class
wholesale; (4) only then the user-visible uniform API (`xschem object @id`,
selection as ids). Constraints carried from day one: both undo backends must
round-trip identity (memory undo copies structs — free; disk undo
round-trips through the `.sch` format — needs a decision), and the drawing
hot path stays untouched (the funnel costs one call on human-speed mutation
only).

---

## Q6. Is it true C is a subset of C++?

- **Asked:** 2026-06-12
- **Project state:** branch `feature/stable-object-handles` @ `cdf9bd9e`,
  right after the C-vs-C++ objects tutorial (`objects_in_c_vs_cpp.md`) landed.

**Almost, but not literally — and the gap runs in three layers** (all
demonstrated live with gcc/g++ during the session):

1. **Valid C that C++ rejects:** `int *new = malloc(n)` fails twice over —
   `new` is one of ~30 extra C++ keywords, and C++ forbids the implicit
   `void *` conversion every C `malloc` call relies on. `char *s = "hello"`
   loses the `const`. Plus implicit function declarations, K&R definitions,
   tentative definitions — the C89 idioms.
2. **Valid C that C++ never adopted:** VLAs, `restrict`, flexible array
   members, `_Generic`, compound literals, full C99 designated initializers.
   Modern C is not contained in modern C++ either.
3. **The dangerous layer — compiles in both, means different things:**
   `sizeof('a')` is **4 in C** (character constants are `int`) and **1 in
   C++** (`char`); file-scope `const` linkage differs; enum conversions
   differ. No diagnostic fires.

What people correctly mean is the pragmatic version: a large common dialect
("Clean C") compiles identically under both, and xschem's C89 is a few
mechanical fixes from it. For the handles work the relevant direction is:
everything in the tutorial — factory functions, deep-copy discipline,
accessor-only mutation, generational handles — is expressible in C89. We
borrow C++'s *design ideas*, not its syntax.

---

## Q5. Is the CIW a full-fledged Tcl interpreter? And what would Ctrl-Backspace word-delete and Up-arrow history take?

- **Asked:** 2026-06-11
- **Project state:** branch `feature/action-logging` @ `094ee4a2`. Phase 0 (log
  file), the CIW (incl. the sash UX rework), Layer A slice 1 (Tcl-backed action
  logging) and `--nolog` are done; Layer A slice 2 is planned.
- **Prompted by an experiment:** the user typed `set a 10`, `set b 20`,
  `expr {$a + $b}` into the CIW and it printed `30`.

**Yes — and it's even better (or scarier) than "a" Tcl interpreter: it is THE
application's own interpreter.** When you press Return, the CIW runs your line
with `uplevel #0 $cmd` — "evaluate this at the top level of the running
program." There is no sandbox, no separate baby interpreter. That has three
consequences worth understanding:

1. **State persists between commands.** Your `set a 10` created a real global
   variable in the live program — that's exactly why `expr {$a + $b}` could see
   it two commands later. You can define procs, run loops, `source` whole
   files.
2. **You share the interpreter with the GUI itself.** Everything xschem's menus
   and dialogs can do, you can do — reconfigure widgets, call any `xschem …`
   subcommand. The flip side: a long-running loop freezes the UI until it
   finishes, because your command runs on the same thread that redraws the
   screen.
3. **Your session is being recorded.** Successful commands are appended to
   `Xschem.log` (that's the design — the file is a faithful, replayable session
   record), so `set a 10` is now part of the log. Failed commands are written
   as `# failed:` comments so replaying the file never aborts.

One honest limitation: each Return must be a **complete** command. The CIW
doesn't (yet) check `info complete`, so you can't type an open
`foreach x {1 2} {` and finish it on the next line — it errors immediately.
Type the whole construct on one line (it wraps in the entry area).

**What the two conveniences take — both are small, pure-Tcl widget bindings in
`ciw.tcl`; no C changes at all:**

*Ctrl-Backspace deletes a word.* Tk's text widget doesn't bind
`<Control-BackSpace>` by default on X11, but its index arithmetic does all the
real work — `{insert -1c wordstart}` literally means "the start of the word
just before the cursor":

```tcl
bind .ciw.c.e <Control-BackSpace> {
  .ciw.c.e delete {insert -1c wordstart} insert
  break    ;# stop the class binding from ALSO deleting one character
}
```

The only refinement worth adding is shell-like whitespace handling (skip the
spaces behind the cursor first, then eat the word) — a few more lines.

*Up/Down recalls history.* Three pieces, ~15 lines:
1. a global list that `ciw_exec` appends each executed command to;
2. `<Up>`/`<Down>` bindings that replace the entry's content with the
   previous/next list item (each ending in `break`, so the cursor-movement
   class binding doesn't fire);
3. the standard nicety: the first Up stashes whatever you'd half-typed, so
   pressing Down past the newest entry brings your draft back.

One design trade-off to know about: because the entry is now a multi-line-
capable text widget, Up natively means "move the cursor up one display line"
inside a tall, wrapped command. Binding it to history steals that. The simple
answer (what terminals and Virtuoso do) is history-always; the fancier version
triggers history only when the cursor is on the first display line.

Both features are listed in the spec's §6 "explicitly not v1" bucket — doing
them is consciously pulling future items forward, justified because they're
cheap and the CIW is a window you type into constantly.

## Q4. So far, how has this work made the code easier to read and maintain?

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `21ea55f4`. We are partway
  through **Phase 3c** (moving keyboard/mouse handling into the lookup table); the
  scroll wheel, the right-drag zoom gesture, the no-modifier `f` and arrow keys, and
  the graph-routing of six more keys are done. **Phase 3d** (deleting the old
  hard-wired code) has not started.

**The honest headline first: the code is currently a bit *longer*, not shorter.**
This phase is an investment. We added the new "controls list" machinery (the lookup
table, the part that reads it, and the commands to edit it) *before* we could start
removing the old hard-wired handling. So the file grew by roughly 425 lines. That
reverses later, in Phase 3d, when the old code gets deleted now that the new system
can replace it. So far we've only begun that removal (about 30 lines gone in the
most recent step).

**What is genuinely easier to read today:**

1. **Commands have names now.** Before, what a key did was spelled out as raw math
   and function calls buried inside one enormous 1,600-line block. Now each behavior
   is a small, clearly named piece (e.g. "zoom full", "scroll up", "hand this to the
   waveform graph"). You can tell what a key does by its name instead of decoding it.

2. **"Which key does what" is now a plain list, separate from "what it does."**
   Previously those two ideas were tangled together in every case. Now there's an
   editable list of "this input → this command," and you can print the whole list
   with one command to see every shortcut at a glance. That single, readable
   overview simply did not exist before.

3. **A copy-pasted block is being deleted.** The exact same five-line check —
   "if the mouse is over a waveform graph, hand the event to the graph" — had been
   pasted into the code about twenty times. We've removed it from the scroll-wheel
   handling entirely and from six keyboard shortcuts so far, each time replacing the
   duplicated code with a single line in the list. More removals are queued.

4. **One shared path instead of three different ones.** The wheel, the mouse-drag
   gestures, and the keyboard now all flow through the same handling, with one clear
   rule for which binding wins. A maintainer learns one mechanism, not three.

5. **The tricky, easy-to-break details are now written down.** The handful of subtle
   rules that used to be invisible traps (why certain shortcuts must stay as-is, why
   one check has to happen before another) are now explained in comments right where
   they matter, plus a short tutorial and these FAQ entries — so the next person
   doesn't have to rediscover them the hard way.

**Bottom line:** any individual shortcut is clearer (named, self-explaining, with its
reasoning attached), and the system as a whole is now navigable through one readable
list instead of a giant undocumented block. The raw line count is temporarily higher;
it drops below where it started once Phase 3d removes the now-replaceable old code.

---

## Q3. In plain language (high-school level): what are the next couple of steps, and what's the end goal?

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `cd5b5c9a` (wheel, zoom-rect
  gesture, and the no-modifier `f` + arrow keys are data-driven; Group B sweep next).

**Next couple of steps**

1. **"Group B" keys sweep.** A handful of keys (`a`, `b`, `s`, Ctrl+tab-switch
   arrows, …) each carry a copy-pasted "if the mouse is hovering over a waveform
   graph, hand this to the graph instead" check buried in a 1600-line block of C.
   The next step lifts just that check out into the lookup table (a plain list of
   "this input → does that"). The keys' normal jobs (open a dialog, save a file)
   stay in C; only the graph-routing part becomes data. This deletes a lot of
   duplicate code. (Caveat found while scoping: some of these keys check an
   "are we busy?" counter *before* the graph check, so they must be migrated
   carefully or deferred — see the semaphore-ordering note in the Phase 3c work.)
2. **Let an action run a Tcl command, not just C.** Today the table can only point a
   key at a built-in C function. Most menu items are written in Tcl (the scripting
   layer). Teaching the table to also say "this key runs *this script command*"
   unlocks migrating dozens more keys.

**End goal (the analogy)**

Think of a TV remote whose buttons are *soldered* to fixed jobs — you can't make the
red button do the green button's thing without rebuilding the remote. That's how
XSCHEM's keyboard/mouse handling works today: every shortcut is hard-wired deep in
the code.

We're replacing it with a **"Controls" settings list**, like the rebind-your-keys
menu in a video game. One master list says *"this key / mouse button / scroll does
this action,"* and:

- **You can edit it** in a config file to remap anything — no recompiling. (Already
  true for the scroll wheel and the arrow keys; see Q2.)
- **The help/cheat-sheet builds itself** from that same list, so it can't drift out
  of sync with what the keys actually do.
- Once everything is moved over, the old hard-wired code is **deleted**, leaving the
  program smaller and easier to maintain.

In one line: **turn soldered buttons into a remappable controls menu — for every
key, mouse button, and scroll — and let the help screen generate itself from it**,
done one small, fully-tested batch at a time so nothing breaks.

---

## Q2. Can a user remap the mouse wheel — **Ctrl+wheel = zoom, plain wheel = vertical pan, Shift+wheel = horizontal pan** — via `.xschemrc` / `--script`? (And why didn't the original author's `replace_key` snippet work?)

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `bfec8793` (Phase 3a wheel
  fully data-driven; 3b gestures; 3c c4/c5 first key `f`). Wheel dispatch goes
  through the in-C binding table (`xschem bind wheel ...`).

**Answer: Yes — fully supported and verified.** Put these in `~/.xschem/xschemrc`
(or `./.xschemrc`, or a `--script` file):

```tcl
# zoom with Ctrl+wheel
xschem bind wheel up   ctrl canvas view.zoom_in
xschem bind wheel down ctrl canvas view.zoom_out
# vertical pan with plain wheel
xschem bind wheel up   0    canvas view.pan_up
xschem bind wheel down 0    canvas view.pan_down
# Shift+wheel already pans horizontally (view.pan_left / view.pan_right) by default
```

Verified against observable state after firing synthetic wheel events
(`xschem callback .drw 4 <mx> <my> 0 <4|5> 0 <state>`; state 0/1/4 = plain/Shift/Ctrl):

| Input | Result | Verdict |
|---|---|---|
| plain wheel | `zoom` unchanged, `yorigin` moves | vertical pan ✅ |
| Ctrl+wheel  | `zoom` changes                   | zoom ✅ |
| Shift+wheel | `zoom` unchanged, `xorigin` moves | horizontal pan ✅ |

`xschem bindings dump` reflects the swap. (Swap `up`↔`down` for the opposite scroll
direction.) Timing is safe: `xschem bind` calls `ensure_input_bindings()`, which
lazily seeds the defaults *then* applies the override; `init_input_bindings()` is
guarded by `input_bindings_initialized`, so it never re-runs and clobbers the user's
rows — order of `.xschemrc` vs GUI bring-up does not matter.

**Why the original author's `replace_key` snippet didn't work.** `replace_key` is a
separate, *older, Tcl/Tk-level* mechanism (`set_replace_key_binding` →
`key_binding`, xschem.tcl:10994/1121). It installs a more-specific Tk binding such
as `<Control-Button-4>` that re-emits an `xschem callback` with a **rewritten
modifier mask** (e.g. mapping `Control-Button-4` → the state of a plain
`ButtonPress-4`), tricking the C wheel handler into seeing a different chord. It is
fragile in ways that bite silently:

- **Tk 8.7 / 9.0 deliver the wheel as `<MouseWheel>`, not `<Button-4/5>`**
  (xschem.tcl:9981 only binds `<MouseWheel>` when `tclversion > 8.7`). On those
  builds the `<Control-Button-4>` overrides never fire — the physical event isn't a
  Button-4 event. **Most likely cause of the failure.**
- Depends on Tk binding-specificity and on which widget (`.drw` vs the toplevel) the
  generic `<ButtonPress>` (xschem.tcl:9996/9998) vs the `replace_key` binding land
  on — subtle, easy to get subtly wrong.
- Piggybacks on the C button-mask stripping (`callback.c:4507`) as an undocumented
  implementation detail.

**Why the binding table is robust instead.** It dispatches **in C, after** the
event is normalized to "wheel up/down + clean modifier mask" — independent of Tk
version or how Tk delivered the event. It is the intended replacement for
`replace_key` for wheel/button/(now) key remapping.

**Caveats.**
1. Over a waveform graph, plain/Shift wheel still routes to the graph
   (`graph.forward` over_graph rows, unchanged); the canvas rebind only affects
   bare-canvas wheeling. Ctrl+wheel stays canvas-zoom even over a graph (its branch
   in `handle_mouse_wheel` forces `ctx=ACTX_CANVAS`).
2. Keep `graph_use_ctrl_key` at its default `0`. Setting it `1` reserves Ctrl+wheel
   for graph interaction, and `handle_mouse_wheel` returns early for Ctrl — so the
   canvas zoom binding won't be reached.

---

## Q1. Can a user remap the zoom-rectangle gesture from RMB-drag to **Ctrl+RMB-drag** with the current code?

- **Asked:** 2026-06-08
- **Project state:** branch `feature/action-registry` @ `898639af` (Phase 3a/3b done,
  Phase 3c c4/c5 first batch — key `f` — done). Mouse buttons: only the *bare*
  Button3 zoom-rect chord is data-driven (Phase 3b).

**Answer: No — not with the code at that commit, even though the binding can be created.**

`xschem bind button 3 ctrl canvas view.zoom_rect` parses and stores a valid row
(`parse_mods("ctrl") → ControlMask`, code 3). But the **press handler never reaches
the table dispatcher for a *modified* Button3 chord.**

`handle_button_press` (`callback.c`) is an `if / else-if` chain, and the data-driven
`dispatch_button_chord()` sits at the *end* of it (`callback.c:4560`). Earlier
`if`/`else if` branches hardcode the modified-Button3 chords and match first:

```c
if     (!excl && button==Button3 && state==ControlMask && semaphore<2) { … select_connected_nets(1); }  // 4522 ← Ctrl+RMB caught HERE
else if(!excl && button==Button3 && EQUAL_MODMASK && …)                { break_wires_at_point(…); }       // 4530/4536  (Alt+RMB)
else if(!excl && button==Button3 && state==ShiftMask && …)             { select_connected_nets(0); }      // 4542  (Shift+RMB)
…
else if(!excl && semaphore<2 && dispatch_button_chord(button, state, mx, my)) return;                      // 4560 ← table only reached here
```

`state` *is* correctly button-mask-stripped at `callback.c:4507`, so
`dispatch_button_chord` would see `mods==ControlMask` and *could* match the row — but
it is never called for Ctrl+Button3 because the hardcoded branch at 4522 wins and the
dispatch is in a later `else if`. Only **bare** Button3 falls through (the plain-RMB
context menu was moved to the release path, freeing the no-modifier slot).

**The completion side is already ready.** On Ctrl+RMB *release*, `state ==
Button3Mask|ControlMask`, so the exact-match context-menu branch
`if(state == Button3Mask)` (`callback.c:4779`) is skipped and the Phase 3b
fallthrough `else if((ui_state & STARTZOOM) && semaphore<2) end_place_move_copy_zoom()`
(`callback.c:4789`) completes the gesture. So only the **initiation** is blocked.

**What it would take** (a natural Phase 3 follow-on, same pattern as the key work):
1. Extract the hardcoded modified-Button3 branches into `act_*` fns
   (`select_connected_nets`, `break_wires_at_point`) + `{button 3 ctrl/shift/alt
   canvas}` rows; **or**
2. Move `dispatch_button_chord` earlier so a user-bound chord pre-empts the hardcoded
   default ("table-first, hardcoded-fallthrough" precedence, like the keys now have).

**UX consequence:** Ctrl+RMB is already a feature (select instance + connected nets,
stopping at junctions), so rebinding it to zoom means relocating that feature to
another chord.
