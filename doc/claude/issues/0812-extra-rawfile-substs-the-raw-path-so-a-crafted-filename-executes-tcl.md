# 0812 — `extra_rawfile()` `subst`s the raw file path, so a crafted filename EXECUTES Tcl

STATUS: **OPEN — STILL LIVE AT HEAD. A fix was built, measured green on 21+5+5+1 new
checks, survived all five sabotage variants, and was then REFUTED BY THE ADVERSARY AND
REVERTED 2026-08-25 (step status F).** `src/` and `tests/` are byte-identical to the
commit before the attempt; the reverted diff is kept at
`doc/claude/evidence/0812-attempt1-reverted.patch.txt`. **§ "The attempt" below is
binding on whoever retries this.**
FOUND IN: `src/save.c` — the six `tclvareval("subst {", file, "}", NULL)` calls in
`extra_rawfile()` (the two read arms, the switch arm and the three clear arms);
`src/scheduler.c` — the `raw_read` verb's own `regsub {^~/} {%s} {%s/}` + `tcleval()`
splice.
RELATED: `src/scheduler.c`'s `annotate_op` branch, whose comment block says this hazard
was closed for that command in C (it resolves `~/` with two `my_snprintf` branches
instead of a `regsub` tcleval). **That claim is true of its own line and false of the
path as a whole**: the hazard is closed one frame up and open one frame down.

## Measured (this tree, patched for 0807, `--nogui`)

```tcl
set f {<dir>/q}; set ::SC_PWNED 1; list {a.raw}   ;# a real file with that name
set ::SC_PWNED 0
catch {xschem annotate_op $f 0}
```

```
INJ| annotate_op  PWNED=1  ret=<0>
```

`::SC_PWNED` is 1: the filename's `}` closed `subst`'s brace group early and the rest of
the name ran as script. The scout on item 0807 measured the same through
`xschem raw_read <crafted path>` via `src/scheduler.c`'s
`regsub {^~/} {%s} {%s/}` + `tcleval()` (scheduler.c, the `raw_read` verb).

## Why it is reachable

Every path that hands a user-chosen or simulator-chosen filename to `extra_rawfile()`
reaches it: the `annotate_op` branch, `xschem raw read`, `xschem raw clear <file>`, the
ASE annotate arm, `open_sub_schematic`'s carry-over, `hi_descend`'s new-window arm. The
filename need not be typed — a directory a user chose plus a cell name is enough.

## Fix, when someone takes it (⚠ SUPERSEDED — see §4 and §10; both sentences below are wrong)

The `subst` exists only to expand Tcl variables and `~` in a path. Either drop it (the
callers already have resolved paths) or route it through a form with nothing to escape
from — `Tcl_SubstObj` with a value, or `list`-quoting the argument. The `annotate_op`
branch's two-`my_snprintf` `~/` expansion is the in-tree precedent for the C-side answer.

## Unaffected by 0807's revert, and an aggravating factor for its retry

The transcript above was taken on the attempt-1 binary, but the sink is in `extra_rawfile()`,
which that attempt did not touch — **this reproduces at HEAD unchanged**.

⚠ For whoever retries 0807: a detach-based fix runs attacker-controlled Tcl **while a
database is detached**, i.e. while a live `Raw` is owned only by a C local and is in no
registry. `xschem raw clear` in that window is harmless (the detached entry is not there to
clear), but anything that tears down `xctx` would leave the reattach writing through freed
memory. Fixing this issue first would remove that interaction entirely.

## Not fixed under 0807

0807's scope is the destroy-then-read lifetime bug and the fabricated return value. This
is a different decision with a different blast radius (every `extra_rawfile()` caller,
and the `~`/variable expansion some of them may rely on).


---


# THE ATTEMPT — 2026-08-25, BUILT, GREEN, REFUTED, REVERTED (status F)

## 1. The one thing to carry away

**`subst -nobackslashes -nocommands` IS NOT A SANITIZER.** `-nocommands` suppresses
*top-level* command substitution only. A command substitution that occurs **as part of a
variable substitution** — an ARRAY INDEX, `$name([...])` — still runs, because a variable
reference's index is itself fully substituted. Measured in `tclsh 8.6.13`, brace-quoted
literals so the outer parse cannot be blamed:

```
array-index            S=1  -> ERR: can't read "a(1)": no such variable
array-index-ns         S=1  -> ERR: can't read "::ns::a(1)": no such variable
existing-array         S=1  -> ok
braced-var             S=0  -> ERR: can't read "[set ::S 1]": no such variable
top-level-cmd          S=0  -> [set ::S 1]
```

The array need not exist: the index is evaluated **before** the lookup fails. So any
resolver that leaves `$` active by handing attacker text to `subst` inherits full
arbitrary code execution, no matter which `-no*` flags it passes.

## 2. What the attempt did

`src/util.c` gained one resolver, declared in `src/xschem.h`, and it replaced every
splice in the raw-file family:

* `expand_tilde()` — leading `~/` → `home_dir`, pure C (the `annotate_op` branch's private
  two-`my_snprintf` copy folded into it, so one expander instead of two).
* `subst_tcl_value()` — `subst -nobackslashes -nocommands <value>` through
  `Tcl_EvalObjv` with the word list pre-built (`TCL_EVAL_GLOBAL`, matching the old
  `tclvareval()` scope), literal fallback on error, no-`$` fast path.
* `resolve_rawfile_path()` — the two composed, idempotent on its own output.

Call sites replaced: all six `save.c` `extra_rawfile()` substs by **one** hoisted call;
both `draw.c` `node_token_split()` fields; the four raw-family `regsub {^~/}` + `tcleval`
splices (`embed_rawfile`, `raw_read`, `table_read`, `vcd_read` verbs).

It worked, for the payload shapes anyone had thought of. **15 of the repro's 18 probes
went PWNED=1 → PWNED=0** (the other three are the out-of-scope 0816 verbs), and three
ordinary cases that were *broken at HEAD* started working (`[`, `\`, `$undefined`, plus
`~/` through `raw read`).

## 3. Why it was reverted

The adversary pass drove a payload nobody in the crew had written a row for, and the
write-up agent re-measured it independently on the same binary:

```
AIDX-rawread    PWNED=1  r=1        file named  $a([set	::SC_PWNED	1]).raw
AIDX-annotate_op PWNED=1 r=::op_annot::text
AIDX-exec       OWNED_READ exists=1 r=0    file named  $a([exec	touch	<dir>/OWNED_READ]).raw
```

The third line is the sharp one: **`exec touch` ran and created a host file, for a path
that did not exist on disk at all**. The resolver runs before any `stat()`, so a
non-existent filename is enough. Every route that reached `subst_tcl_value()` was still a
full local ACE: `raw read`, `raw switch`, `raw clear`, `raw table_read`, `raw vcd_read`,
`annotate_op`, and — under X, on a plain `xschem load evil.sch` + redraw — the graph
`node=` field.

Reverted rather than patched-in-place because:

* the shipped comment in `src/util.c` said in as many words that `[` and `]` are
  literal and that the value is never evaluated. That is **false**, and the brief for this
  item named "a comment asserting a safety property the code does not have" as the reason
  the original defect survived review. Shipping it would have been the tenth instance.
* the four suites were **ALL PASS with the defect live** (72 / 173 / 360 / EINJ1). Green
  suites plus a false comment is strictly worse than a known-open issue: it retires the
  attention that would otherwise fix it.
* a corrected sanitizer written at write-up time would carry no sabotage pass and no
  adversary pass — the two things that caught this.

## 4. BINDING ON THE RETRY

1. **Do not use `subst` in any form.** Scan the path in C and expand only what you
   recognise: `$name`, `${name}`, `$ns::name` looked up with `Tcl_GetVar2Ex`, everything
   else copied literally, `(` never treated as an index opener. That is the only shape
   with no evaluator in it at all.
2. **Variable expansion must survive** — this is measured, and issue text to the contrary
   is refuted below. Nine `draw.c`/`callback.c` sites hand `extra_rawfile()` a graph
   `rawfile=` attribute unsubstituted, and the shipped corpus spells it `$netlist_dir/…`
   (`xschem_library/ngspice/autozero_comp.sch`, `.../solar_panel.sch`,
   `xschem_library/examples/cmos_example.sch`).
3. **One resolver, called once.** The `extra_raw_arr` registry is keyed by `strcmp()` on
   the string the READ arm stored, so read/switch/clear must not be able to disagree, and
   the resolver must be idempotent on its own output (`annotate_op` feeds an
   already-resolved `xctx->raw->rawfile` back through the clear arm). `src/ase.tcl`'s
   read/clear pair on one path is the first thing that breaks if this drifts.
4. **Red-phase rows must include the array-index shape**, namespaced and not, plus an
   `[exec ...]` row that asserts a host side effect (a created file), plus a row on a path
   that does **not exist**. The crew's rows used only `q}; …` (brace escape) and top-level
   `[set …]` — both neutralised by the attempt while the defect stayed live.
5. **Three payload shapes, not one**: brace-escape `q}; set ::SC_PWNED 1; list {a.raw`
   for the `subst` sink, `x} {y} {z}; set ::SC_PWNED 1; list {a` (no slash) for the
   `regsub` sink, `$a([set ::SC_PWNED 1]).raw` for the array-index sink. A suite that
   reuses one shape passes over the others.
6. Keep the attempt's non-sanitizer parts — they were right and are already written in
   `doc/claude/evidence/0812-attempt1-reverted.patch.txt`: the hoist to one call in
   `extra_rawfile()`, the `expand_tilde()` dedup, the literal fallback that stops a failed
   resolution blanking the filename, both `node_token_split()` fields.

## 5. Sabotage matrix of the attempt (recorded because it is evidence about the SUITE)

| variant | predicted red | observed |
|---|---|---|
| SAB-1 evaluating sink restored | 11 | **18** — all 11 plus INJ10b, NINJ3, ORD3-5, KEY1-2 |
| SAB-2 variable substitution dropped | 4 | **4 exact** — VAR1, NVAR1, NVAR2, KEY1; every INJ row stayed green, which is the point |
| SAB-3 tilde expansion dropped | 4 | **6** — the 4 plus two more embed_rawfile `~/` rows |
| SAB-4 failed substitution blanks the filename | 2 | **131** — the no-`$` fast path routes the common case through that callee too (flagged in advance by the implementer) |
| SAB-5 composite resolver inert | 5 | **4** — KEY2 did not fire, see below |

**Predicted red that did NOT appear: SAB-5 / KEY2.** Mechanism verified, not guessed:
KEY2's payload contains no `$` and no leading `~/`, so `resolve_rawfile_path()` is the
identity on it and the stub emits the same bytes. KEY2 has teeth (it went red under SAB-1
and SAB-4) but it does **not** discriminate the composite resolver from its parts, which
is what the plan claimed for it.

**And the matrix's real lesson: a full sabotage matrix proves the tests bind the code the
crew wrote. It says nothing about the code the crew did not think to write.** All five
variants were caught while the shipped fix was exploitable.

## 6. A measurement-integrity hazard the lead must see

Verify-A's first T3 batch showed 8/8 suites red with exactly SAB-4's signature. Cause: a
**concurrent Sabotage agent rebuilt the binary underneath it mid-batch** (`src/xschem`
mtime moved 17:09 → 17:29). It never reproduced across ~30 later runs, all bracketed by an
md5 check. Had Verify-A stopped at that batch it would have reported a catastrophic false
regression. **Verify and Sabotage must not be live at the same time.**

## 7. Still open (adversary residual risks)

* **This issue.** Live ACE at HEAD through every `extra_rawfile()` caller and both
  `node_token_split()` fields; re-measured after the revert, **18/18 probes PWNED=1**.
* **0815** — `xschem compare_schematics <path>` segfaults under `--nogui` (exit 139).
  Pre-existing; measured identical before, during and after the attempt.
* **0816** — the nine `regsub {^~/}` + `tcleval` splices outside the raw-file family
  (`load`, `merge`, `log` measured PWNED=1). The attempt would have left these open by
  design; the revert leaves all thirteen open.
* **0817** — the `tclvareval()` brace-group splices of file-derived strings,
  `parselabel.c`'s `tk_messageBox` sharpest and deliberately unmeasured (modal, 0803).
* **`annotate_op` with no argument** and a payload **simulation-directory** name measured
  PWNED=0 in one adversary harness run while the explicit path into the same directory
  fired. Not root-caused. It is not evidence of safety — the explicit-path case
  establishes the directory-name vector.

## 8. Ordinary cases — the anti-hollow counterweight, and the state at HEAD

Through `xschem raw read`, at HEAD (i.e. now, after the revert):

| filename | HEAD | attempt (reverted) |
|---|---|---|
| plain / with spaces / relative | 1 | 1 |
| `br[1].raw` | **0**, filename silently blanked | 1 |
| `back\slash.raw` | **0**, opened as `backslash.raw` | 1 |
| `pay$undefined.raw` | **0**, filename silently blanked | 1 |
| `~/probe.raw` | **0** | 1 |
| `$netlist_dir/x.raw` | 1 | 1 |

The blanking is the code `my_strncpy`ing a **failed** `tclresult()` — the measured
`raw_read(): failed to open file  for reading`, nothing between the two spaces. **These
four are defects in their own right and are still live**; the retry should fix them with
the resolver, and must not "fix" the injection by refusing unusual filenames.
## 10. ⚠ THE SENTENCE IN THIS ISSUE THAT THE MEASUREMENT REFUTES

> "Either drop it (the callers already have resolved paths)"

**False, and dropping the `subst` would have broken shipped schematics.** The graph-level
`rawfile=` attribute reaches `extra_rawfile()` **completely unsubstituted** from nine
`draw.c`/`callback.c` sites, and the shipped corpus spells it with a variable — the
complete set of `rawfile=`/`xrawfile=` values under `xschem_library/` is
`{$netlist_dir/autozero_comp.raw, $netlist_dir/cmos_example_ngspice.raw,
$netlist_dir/solar_panel.raw, distrib}`, no brackets anywhere. Measured: `xschem raw read
{$netlist_dir/tr.raw} tran` returns 1 and stores the RESOLVED absolute path. So **variable
substitution had to survive**; command substitution and the brace-group escape had to die.

Second half-wrong sentence: "The `subst` exists only to expand Tcl variables **and `~`** in
a path." `subst` never expanded `~` — Tcl's tilde handling is a filename-level thing and
`my_fopen()` just `stat()`s. `~/` worked through `annotate_op` **only** because that branch
expanded it in C one frame up; through `xschem raw read` it returned 0.


## 9. The site sweep, corrected (still true at HEAD)


**Correction 1 to the text above.** "the two read arms, the switch arm and the three clear
arms" is wrong: `extra_rawfile()` had **two read + two switch + two clear** substs, and
only **four fire**. `save.c`'s two `isonlydigit(file)`-guarded substs cannot be reached
with a metacharacter (`isonlydigit()`, token.c, permits only a leading `-` and digits) and
their `f` was afterwards read by nothing but one `dbg()`. They were dead code with a live
side effect; the fix removes them along with the rest rather than leaving a second code
shape in one function.

**Correction 2 — the seventh site, outside this issue's own list.** `src/draw.c`
`node_token_split()` `subst`s the `rawfile` **and** `sim_type` fields of a graph rect's
`node=` attribute — a string read **straight out of a `.sch` file**. Measured: a schematic
whose `node=` field carries `[set<TAB>::SC_PWNED<TAB>1]` sets the sentinel on a plain
`xschem load evil.sch` + redraw **under X**. Opening a schematic someone sent you ran their
Tcl. (Honest caveat, kept in the test file: XSCHEM's attribute language already evaluates
Tcl from a `.sch` **by design** via the documented `tcleval(...)` property form. This was an
UNINTENDED one, in a field `doc/xschem_man/graphs.html` documents as taking a path plus
`$netlist_dir` and nothing else.)

**The measurement that kills the "the user typed the path" objection.** `xschem annotate_op`
**with no argument at all** — the shipped menu entry — was PWNED=1 with the payload living
in the **simulation directory** name (`<netlist_dir>/<cell>.raw`). Nobody typed anything.

