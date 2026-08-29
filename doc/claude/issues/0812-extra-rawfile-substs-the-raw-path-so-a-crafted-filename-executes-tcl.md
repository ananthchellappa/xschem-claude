# 0812 — `extra_rawfile()` `subst`s the raw file path, so a crafted filename EXECUTES Tcl

STATUS: **THE §16 RULING IS SETTLED — decided 2026-08-29 on the user's "decide the 23" instruction; see the RULING section at the foot of this file. The scanner ships as-is; ONE follow-up is now owed (say so in the Graph dialog when the results file cannot be opened, `src/xschem.tcl:4838-4846`). Before that: FIXED 2026-08-25, on the SECOND attempt (item 0812-retry) — step status E, and
the E is a RULING owed on one user-visible side effect (§16), not a doubt about the fix.**
18/18 probes went `PWNED=1` → `PWNED=0`, both `[exec touch]` host-file rows went
`exists=1` → `exists=0`, and four *ordinary* filenames that were broken at HEAD now work.
The retry is **§11-§17**; **§1-§10 are ATTEMPT 1, which was built, measured green, and
REVERTED the same day** (`doc/claude/evidence/0812-attempt1-reverted.patch.txt`). §4 was
binding on the retry and every one of its four constraints was met — read it before
touching 0816 or 0817, because the same trap is waiting there.
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



---


# THE RETRY — 2026-08-25, item 0812-retry. BUILT, MEASURED, SHIPPED (status E, §16)

## 11. What shipped

One resolver, in C, with **no evaluator in it at all**, called **once**. Everything in
attempt 1 except its sanitizer core was ported verbatim from
`doc/claude/evidence/0812-attempt1-reverted.patch.txt` (the patch still applied cleanly
against this tree), and only `subst_tcl_value()` was thrown away.

`src/util.c`, after `my_fopen()`; externs in `src/xschem.h` after `tclvareval`. All three
take `(const char *s, char *dest, int destsize)`, write at most `destsize` bytes (NUL
included, `my_strncpy` semantics), return `dest`, and are safe on `NULL` / `destsize<=0`:

| function | body |
|---|---|
| `expand_tilde()` | leading `~/` → `home_dir`, two `my_snprintf` branches. Ported as-is. `~user/` is not expanded — it never was. |
| **`expand_tcl_vars()`** | **NEW, and it is the whole difference from attempt 1.** A byte scanner. `${NAME}` (NAME non-empty, containing no `(` or `)`, taken literally and never rescanned) and `$NAME` (a run of `[A-Za-z0-9_]`, with `::` accepted *between* runs but never trailing) are looked up with `Tcl_GetVar2Ex(interp, NAME, NULL, TCL_GLOBAL_ONLY)` — a hash lookup, no `TCL_LEAVE_ERR_MSG`, so the interpreter result is not touched. A defined variable's **value is appended verbatim and never rescanned**. An undefined one is copied through as its own literal text by `append_unresolved_ref()`. **Every other byte is copied literally** — `{ } [ ] ; \ ( )` newline and quote included. `(` is never an index opener. No-`$` fast path; `copy_literal()` for the degenerate inputs. |
| `resolve_rawfile_path()` | the two composed. Idempotent on its own output: no leading `~/` survives, and a `$` that survives survived by being unresolvable, so a second pass fails identically. |

Helpers: `copy_literal()`, `append_n()`, `append_unresolved_ref()`, `is_var_name_char()`
(spelled out rather than `isalnum()` — no locale, no sign extension, and the paren
exclusion is visible at the point of use). C89 throughout; no allocation, so no
`_ALLOC_ID_`.

**The only safety claim any comment makes is grep-checkable**: the sole Tcl API the
resolver calls is `Tcl_GetVar2Ex` (3 call sites in `src/util.c`). `Tcl_SubstObj`,
`Tcl_ParseVar` and `Tcl_EvalObjv` appear only inside the comment that says they are *not*
used, and `grep -n subst src/util.c` outside comments returns nothing.

**Call sites.** `save.c` `extra_rawfile()`: all six `tclvareval("subst {", file, "}")`
pairs deleted, replaced by **one** `if(file) resolve_rawfile_path(file, f, (int)S(f));
else f[0] = '\0';` at the top; no arm's branch condition touched, and the two
`isonlydigit()` arms still `atoi()` the **raw** argument so `raw switch 3` / `raw clear 3`
are unchanged. `draw.c` `node_token_split()`: **both** `%` fields — `rawfile` through
`resolve_rawfile_path()`, `sim_type` through `expand_tcl_vars()` (a sim_type is a word like
`tran`, never a path, so no tilde), keeping the `[0] ? : dflt_sim_type` fallback.
`scheduler.c`: the four raw-family `regsub {^~/} {%s} {%s/}` + `tcleval()` splices
(`embed_rawfile` :851, `raw_read` :10559, `table_read` :13202, `vcd_read` :13787) and
`annotate_op`'s private two-`my_snprintf` tilde expansion all became `expand_tilde()`. The
three read verbs therefore expand the tilde **twice** when reached through `annotate_op`;
harmless because the first output already starts with `/`, and said out loud in the comment
because a sabotage variant will probe it.

**Prose the fix falsified, all corrected in the same commit (decision D9)** — attempt 1 was
reverted for exactly one false comment: `draw.c:3335` and the `node_token_split()` block;
`save.c`'s two blocks; `scheduler.c`'s `annotate_op` block; `scheduler.c:6065` (the
`Tcl_ResetResult` **stays**, its rationale changed — the `extra_rawfile` `tclvareval` that
used to be the thing leaving junk in the result is gone); `src/wave_viewer.tcl:2504-2508`
and its echo at `tests/headless/test_wave_crossdb_trace.tcl:164-167`. **`wviewer::db_path_safe`'s
guard regexp is byte-identical** — `%`, `"` and whitespace are genuine field-separator
hazards and `$` is still live by design; `[ ] { } \` stay on its reject list, now labelled a
conservative filter rather than a live hazard.

`src/Makefile.in` was **not** edited (`util.o` is already in `src/Makefile:8` and
`:102-103`), so `./configure` was correctly not run and the grep receipt is N/A by
construction.

## 12. BEFORE and AFTER, measured

**BEFORE — the Measure agent's transcript at HEAD `fadb226d`, verbatim.** 18/18 probes,
from a cold binary, four payload shapes:

```
BRACE raw-read             PWNED=1  r=0
BRACE raw-switch           PWNED=1  r=0
BRACE raw-clear            PWNED=1  r=0
BRACE raw-tableread        PWNED=1  r=0
BRACE raw-vcdread          PWNED=1  r=0
BRACE annotate_op          PWNED=1  r=a.raw
REGSUB raw_read verb       PWNED=1  r=0
REGSUB table_read verb     PWNED=1  r=
REGSUB vcd_read verb       PWNED=1  r=
REGSUB embed_rawfile       PWNED=1  r=
AIDX raw-read              PWNED=1  r=0
AIDX-NS raw-read           PWNED=1  r=0
AIDX annotate_op           PWNED=1  r=
AIDX raw-clear             PWNED=1  r=0
EXEC raw-read(nonexistent) OWNED_exists=1  r=0
EXEC annotate_op           OWNED_exists=1  r=
PWNED_TOTAL=16   (14 sentinel + 2 exec host-file created for a path that does NOT exist on disk)
SCH-LOAD PWNED=1  SCH-REDRAW PWNED=1  has_x=   (xschem load evil.sch under :99 openbox, node= graph field)  |  SCH-AIDX PWNED=1
ORD BRACK  -> 0 No raw file loaded   |   ORD BSLSH -> 0   |   ORD DOLLR -> 0   (filename silently BLANKED; literal: 'raw_read(): failed to open file  for reading' with nothing between the two spaces while br[1].raw exists on disk)
ORD PLAIN/SPACE/VARSUB -> 1 (ordinary + $netlist_dir already resolve today)
```

**AFTER — the same instruments, same display, on the fixed binary:**

```
PWNED_TOTAL=0                       (was 16)
EXEC raw-read(nonexistent) OWNED_exists=0   |   EXEC annotate_op OWNED_exists=0     (both were 1)
SCH-LOAD PWNED=0   SCH-REDRAW PWNED=0   SCH-AIDX PWNED=0        (all three were 1, on :99 with openbox live)
ORD BRACK -> 1 .../br[1].raw   |   ORD BSLSH -> 1 .../back\slash.raw   |   ORD DOLLR -> 1 .../pay$no_such_0812.raw     (all three were 0, blanked)
ORD PLAIN / SPACE / VARSUB -> 1     (unchanged)
SHIPPED autozero_comp.sch  load_err=0 draw_err=0  spec='$netlist_dir/autozero_comp.raw'        rc=1 resolved_ok=1
SHIPPED solar_panel.sch    load_err=0 draw_err=0  spec='$netlist_dir/solar_panel.raw'          rc=1 resolved_ok=1
SHIPPED cmos_example.sch   load_err=0 draw_err=0  spec='$netlist_dir/cmos_example_ngspice.raw' rc=1 resolved_ok=1
GUARD1  the `subst` COMMAND is invoked 0 times while resolving a path     (was 3)
GUARD2  a `regsub {^~/}` splice runs 0 times across raw_read/table_read/vcd_read/embed_rawfile/annotate_op   (was 4)
```

**Resolver semantics, measured directly rather than reasoned about:** `${netlist_dir}/ok.raw`
→ 1; `$ns0812::dir` → 1; `$::ns0812::dir` → 1; `${::ns0812::dir}` → 1; the same spelling
resolved from **inside a proc that shadows `netlist_dir` locally** → 1 (`TCL_GLOBAL_ONLY`,
decision D4). With `::v0812` set to the literal text `$netlist_dir`, reading `{$v0812/ok.raw}`
fails with `failed to open file $netlist_dir/ok.raw for reading` — **the value went in as
data and was never rescanned**. Literal fallback, no blanking: `.../ok.raw$::` (trailing `::`
not eaten), `.../${oops.raw` (unterminated brace), `.../ok.raw$` (bare `$`), `${a(1)}.raw`
(a braced name containing parens is literal text) all report the **whole** path.

**Tiers** (all on `:99`, Xvfb 1920x1080x24, openbox 3.6.1 live, via
`tests/headless/devdisplay.sh exec`; every batch bracketed by `md5sum src/xschem`):

```
T1 run_regression.tcl   32/32 cases fail=0, 0 FAIL/GOLD?/RESULT?/FATAL, 0 exit127, 3 NOGOLD   (identical to baseline)
T2 tests/headless/run.sh  HARNESS PASS, 6/6, rc=0                                             (identical to baseline)
T3 test_raw_read_dispatch            51 -> 88    ALL PASS
   test_op_annot                    355 -> 364   ALL PASS
   test_node_token_split            168 -> 174   ALL PASS   (nd_expect 166 -> 172)
   test_perform_action_embed_rawfile  ALL PASS, and with --logdir (EINJ1)/(EINJ2) RAN instead of self-deferring
   test_annot_show_menu 22, test_ase_launch 44, test_wave_viewer 400, test_backannotate_digital 81,
   test_wave_crossdb_trace 130, test_raw_read_failure_0306 63, test_wave_cursor_crossdb 93,
   test_wave_sigbrowser_digital 82, test_vcd_read 156, test_vcd_time_base 112,
   test_raw_ascii_point_bounds 90    — all ALL PASS, all equal to baseline
T4 make  rc=0, zero warnings, full link. src/Makefile.in untouched, ./configure NOT run.
```

## 13. Decisions — ladder rung, and the alternative rejected

| # | rung | decision | rejected, and why |
|---|---|---|---|
| **D1** | L2 | **No Tcl evaluator in the resolver at all**: a hand-written C byte scanner plus `Tcl_GetVar2Ex`. | Any `subst` flag combination — re-measured on `tclsh 8.6.13` the day of the retry: `subst -nobackslashes -nocommands {$a([set ::S 1])}` sets `::S`, namespaced too. `Tcl_SubstObj` (the same evaluator, reached from C). `Tcl_ParseVar` (re-imports Tcl's array-index grammar, whose index must then be substituted to be usable). The scanner is the only shape whose safety property a reviewer can check by reading it. |
| **D2** | L2 | **`(` is NEVER an index opener**, and a `${…}` name containing `(` or `)` is literal text rather than a lookup. `$a(1)` means `<value of a>(1)`. | Honouring Tcl array syntax. Measured cost in the shipped corpus: **zero** — `grep -rn '\$env(' --include=*.sch --include=*.sym` is empty tree-wide and the complete set of shipped `rawfile=` values is three `$netlist_dir/…` spellings plus the bare name `distrib`. Excluding parens from *both* name forms is what makes "no index is ever parsed here" a property of the scanner instead of a claim about what `Tcl_GetVar2Ex` does with `part1`. Cost pinned by row **ORD9**; variant **SAB-7**. |
| **D3** | L2 | **Per-variable literal fallback**: an unrecognised or undefined reference is copied verbatim and the scan continues. | Attempt 1's whole-string fallback ("resolve failed → answer the entire input literally"), because `$netlist_dir/pay$undefined.raw` then resolves to nothing useful, and because "every byte is copied literally except a recognised, **defined** reference" is a rule a reviewer checks in one pass. Both shapes are equally idempotent. |
| **D4** | L2 | Lookup scope is **`TCL_GLOBAL_ONLY`**. | Current-frame lookup. `tclvareval()` evaluated with `TCL_EVAL_GLOBAL` and `tclgetvar()` already uses `TCL_GLOBAL_ONLY`, so `$netlist_dir` must keep resolving when the caller is inside a proc — measured green from inside a proc that shadows it locally. Anything else silently breaks the shipped graph attributes on a redraw under a Tcl procedure. |
| **D5** | L2 | The four raw-family `regsub` verbs get **`expand_tilde()` only** — byte-identical to HEAD for every input without a `}`. | Routing them through `resolve_rawfile_path()`, which would **add** variable expansion nobody asked for and widen the diff. The measured residual is filed as **issue 0818**: at HEAD *and now*, `xschem raw_read {$netlist_dir/ok.raw} tran` → 0 while `xschem raw read` of the same spelling → 1. Not reachable through the shipped `open_sub_schematic`/`hi_descend` paths (they pass the already-resolved stored path). |
| **D6** | L2 | The `%` **sim_type** field gets `expand_tcl_vars()`; the `%` **rawfile** field gets the full `resolve_rawfile_path()`. | The full resolver on both — a sim_type is a word like `tran`, and `~/` there would be meaningless. **Both** fields are rewired, because a one-field fix leaves `draw.c:3357` a live sink (variant **SAB-5**, row **NINJ2**). |
| **D7** | **L1 — invariant I1** (one builder, many consumers, applied to the path resolver) | **ONE resolver, called ONCE** at the top of `extra_rawfile()`; every arm reads the resolved `f`. | Per-arm resolution — what HEAD did, six times. The `extra_raw_arr` registry is keyed by `strcmp()` on what the READ arm stored, and `annotate_op` feeds an already-resolved `xctx->raw->rawfile` back through the CLEAR arm, so arms that could ever disagree make `xschem raw clear $f` silently miss what `xschem raw read $f` loaded. The `isonlydigit()`/`atoi()` arms keep reading the raw argument, so `raw switch 3` / `raw clear 3` are unchanged. |
| **D8** | L2 | The function is named **`expand_tcl_vars()`**, not `subst_tcl_value()`; the literal helper is `copy_literal()`, not `subst_fallback_literal()`. | Keeping attempt 1's names. The word `subst` is precisely the false-safety label that let attempt 1 pass review with an exploitable core, and after this change there is no `subst` for a "fallback" to fall back *from*. A name that says what the code does cannot be mistaken for a claim about what it refuses. |
| **D9** | L2 | **Correct every comment the fix falsifies, in the same commit** (the five sites listed in §11). `wviewer::db_path_safe`'s guard is unchanged. | Leaving them. 0812 was reverted for exactly one such comment; shipping a tenth would repeat the failure that hid the defect for as long as it did. |
| **D10** | **L3** | The user-visible behaviour changes are implemented as decided, and the step is **status E** with the question in §16. | Nothing — L3 says implement and ask, and the item brief says a security fix files no new **rule debt**, so the question is recorded here rather than in `owed.sh`. |

## 14. Sabotage matrix — 7 variants, and the one predicted red that did not appear

Every variant neutralises a callee by **renaming it to a no-op**; no `/* SABOTAGE */`
comment was ever written. Restore was `cp` + `touch`, rebuild, `grep -rn SABOTAGE src/`
empty, baseline re-asserted.

| variant | predicted red | observed |
|---|---|---|
| **SAB-1** the evaluating sink is back (`resolve_rawfile_path_subst()` = the old `tclvareval("subst {"…)`) | 12 ("expect ≥18") | **31 — all predicted present.** `test_raw_read_dispatch` 24 (GUARD1, INJ1-6, INJ10, INJ10b, INJ11-17, ORD3-5, ORD7-9, KEY1-2), `test_node_token_split` 3 (NINJ1, NINJ3, NINJ4), `test_op_annot` 4 (AINJ1-4). GUARD1 names the sink outright: *"the `subst` COMMAND was invoked 3 time(s) while resolving a path"*. `probe0812` against that binary: `PWNED_TOTAL=12`, both exec rows `OWNED_exists=1`. |
| **SAB-2** variable expansion dropped (lookup always returns NULL) | 9 | **10** — all 9 (VAR1-4, KEY1, KEY3, NVAR1-2, AORD3) plus ORD9, which reads through `::a0812` and so also needs the lookup. |
| **SAB-3** tilde expansion dropped | 5 | **6** — all 5 (ORD7, KEY1, AORD1, two `embed_rawfile` `~/` rows) plus a third `embed_rawfile` `~/` row. `test_node_token_split` stayed ALL PASS, correctly: no tilde in a graph attribute. |
| **SAB-4** the unresolved-reference literal fallback dropped | 2 | **exactly 2** — ORD5 (`$undefined`) and ORD8. Surgical as designed; the separate `append_unresolved_ref()` callee is why (attempt 1's equivalent reddened **131** rows and told nobody anything). |
| **SAB-5** one field of `node_token_split()` left on the old sink | 1 | **exactly 1** — NINJ2, the `%` **sim_type** field. NINJ1/3/4 stayed green, proving the two fields are independently covered and a one-field fix cannot pass. |
| **SAB-6** the hoist collapsed — resolution in the READ arms only | 7 | **1** — KEY1 only (`{1 0} {1 0} {1 1}`). See below. |
| **SAB-7** `(` treated as an index opener | 1 | **exactly 1** — ORD9. Decision D2's cost is pinned by a row, not only by a comment. |

**⚠ PREDICTED RED THAT DID NOT APPEAR: SAB-6 / INJ2, INJ3, INJ4, INJ13, INJ14, KEY3.**
Root-caused, not waved through. **SAB-6 introduces no evaluator** — measured, not argued:
`probe0812` against the SAB-6 binary gives `PWNED_TOTAL=0` and `OWNED_exists=0`, against
the SAB-1 binary `PWNED_TOTAL=12` and `OWNED_exists=1`. The five INJ rows assert *the
sentinel stays 0*, so they are **correctly** green when nothing can execute, and all five
went **red under SAB-1**, which proves they are non-vacuous and do reach the switch and
clear arms with a non-empty registry. KEY3 clears an already-**absolute** path, which needs
no resolution, so arm disagreement cannot reach it; KEY3 went red under SAB-2, so it does
have teeth over the idempotence it claims. **The mechanism SAB-6 breaks — one resolver, all
arms agreeing — is caught deterministically by KEY1.** The prediction was wrong about
*which* rows, not about whether the mechanism is covered.

## 15. The rows that were added (and why each shape is there)

`tests/headless/test_raw_read_dispatch.tcl` **51 → 88**: **GUARD1** (the `subst` *command*
is never invoked while a path is resolved — necessary, not sufficient: a C-level
`Tcl_SubstObj` would not dispatch through the command, which is exactly how attempt 1 would
have passed it), **GUARD2** (no `regsub {^~/}` splice runs), **INJ1-INJ6** brace escape
through read / switch / clear+type / clear-no-type / table_read / vcd_read *with a non-empty
registry*, **INJ7-INJ9** the regsub shape through the three top-level verbs, **INJ10/10b**
the payload-named file still **loads** under its literal name, **INJ11-INJ14** the array
index plain and namespaced through read / clear / switch, **INJ15/INJ16** `[exec touch]`
asserting the **created file** on a path that does not exist, **INJ17** the brace payload on
a never-created path, **ORD1-ORD9** the anti-hollow set (plain, spaces, `br[1].raw`,
`back\slash.raw`, `pay$undefined.raw`, relative, `~/`, an array-index-shaped name that
exists, and `(` not an index opener), **VAR0-VAR4** (VAR0 greps the three shipped schematics
at run time to assert the premise still holds, then each exact spelling is loaded),
**KEY1-KEY3** read↔clear agreement and idempotence.
`test_node_token_split.tcl` **168 → 174**: NVAR1-2, NINJ1-4 (`%` rawfile *and* `%` sim_type,
plus the `xschem load` + redraw row, non-vacuous on `:99` — `winfo exists .drw` = 1 during
the run). `test_op_annot.tcl` **355 → 364**: section Z — Z0, AINJ1-4, AORD1-3, AKEY1.
`test_perform_action_embed_rawfile.tcl`: EINJ1/EINJ2, which **run** rather than self-defer
when the suite is given `--logdir` (`--nolog` and `--logdir` are mutually exclusive).

## 16. ⚠ THE RULING THIS STEP OWES (why the status is E)

The fix changes behaviour a user can see, and no prior ratification covers it:

1. `br[1].raw`, `back\slash.raw`, `pay$undefined.raw` and `~/x.raw` **start working**
   through `xschem raw read`, where all four failed before and three of them silently
   blanked the filename.
2. A `\` in a path is **no longer eaten** (plain `subst` ate it; the scanner copies it).
3. **`$a(1)` in a rawfile spelling stops being a Tcl array lookup** and becomes
   `<value of a>(1)` — decision D2. ⚠ **And that includes `$env(HOME)/x.raw`**, which is
   the spelling a user is far more likely to have typed than a bare `$a(1)`: measured
   `rc=0` after the fix, and it worked at HEAD through `subst`. Cost in the shipped tree is
   still genuinely zero (`grep -rn '\$env(' --include=*.sch --include=*.sym` is empty
   tree-wide; the one `$env(HOME)` in `doc/xschem_man/developer_info.html:1879` sits inside
   a `sim(...)` command string, a different mechanism). An earlier draft of this ruling
   named only `$a(1)`, which understated what the user is actually ruling on.
4. `extra_rawfile()` **no longer leaves the resolved path in the Tcl interpreter result**.
   That leftover was measured nondeterministic at HEAD (`r=::op_annot::text` on an ordinary
   call — whatever ran last), no caller in `src/*.tcl` reads it and no test pins it either
   way, so it is deliberately left unpinned.

Items 1, 2 and 4 are unambiguous improvements. **Item 3 is the question:**

> **Should a raw-file path keep Tcl array-element syntax — `$a(1)`, and with it
> `$env(HOME)/x.raw` — given that nothing in the shipped corpus uses either and that
> keeping them is what makes the sanitizer impossible to state simply?**

Answering "keep it" means re-admitting an index grammar that must then be proven inert;
answering "drop it" is what shipped. **No new rule debt was filed** — the item brief says a
security fix should need none — so this paragraph *is* the record.

## 17. STILL OPEN

* **⚠ SUPERSEDED BY §18 — an adversary pass DID run, late.** When §17 was first written
  Verify-C had produced nothing and the claim was handed over as *UNREFUTED-UNTESTED*. A
  real adversary pass arrived after commit `3ab11016` had landed; it did **not** refute the
  central claim, and it **did** refute two comments the fix shipped. See **§18**. The
  paragraph below is kept as written, because the substitute probe it describes is still
  evidence. The write-up agent substituted its own
  13-shape probe on the shipped binary rather than reporting nothing, all dead, all
  asserting the host side effect where one applies: a variable **value** containing
  `[exec touch …]` (never rescanned — the engine tried to open a file literally named
  `[exec<TAB>touch<TAB>…].raw`, which is the non-vacuity proof), a `${NAME}` whose NAME
  carries a command substitution, a three-level namespaced array index with `exec`, `~/`
  followed by a brace escape, a newline-separated payload, a payload in the **type**
  argument, `annotate_op` **with no argument** and the payload in the simulation-directory
  name, a 4000-character variable name (over `namebuf`), a path longer than `PATH_MAX`
  with the payload past the truncation point, and the array-index-with-`exec` shape through
  `raw switch`, `raw clear`, the `table_read` verb and the `vcd_read` verb. Eight ordinary
  filenames re-checked green in the same run. **This is not a substitute for a dedicated
  adversary agent**; treat the next crew that touches this family as owing one.
* **0816** — the nine remaining `regsub {^~/}` + `tcleval()` splices outside the raw-file
  family (`scheduler.c` 2980, 7611, 7767, 7835, 8132, 8989, 9028, 9831, 11183) plus
  `xinit.c:3235` (a compile-time constant). `load`, `merge` and `log` were measured
  `PWNED=1`. **`expand_tilde()` is the drop-in.**
* **0817** — the `tclvareval()` brace-group splices of file-derived strings;
  `parselabel.c`'s `tk_messageBox` is the sharpest and is deliberately unmeasured (modal,
  issue 0803). **`expand_tcl_vars()` is the drop-in wherever the splice exists only to
  expand variables.**
* **0818** — the top-level `raw_read` / `table_read` / `vcd_read` verbs still do not expand
  a `$var`-spelled path, so one spelling loads through `xschem raw read` and not through
  `xschem raw_read` (decision D5, deliberate).
* **0815** — `xschem compare_schematics <path>` segfaults under `--nogui` (exit 139).
  Pre-existing, not injection, measured identical before and after.
* **⚠ THIS BULLET WAS WRONG AND IS NOW ISSUE 0820.** It said the only way a `$` reaches
  the output is by being **unresolvable**, so that only an undefined→defined race could
  break idempotence. False: a `$` also reaches the output when a **defined** variable's
  VALUE contains one, because a value is never rescanned — which is the safety property
  itself. Measured, and the live two-pass route (a graph `%` rawfile field, resolved by
  `node_token_split()` and again by `extra_rawfile()`) does load an entry whose key a
  one-pass `xschem raw clear` cannot match. Unchanged from HEAD, no shipped spelling reaches
  it, comments corrected — **doc/claude/issues/0820-*.md**.
* **Measurement-integrity, and it happened AGAIN**: Verify-A and Verify-B ran concurrently,
  and Verify-B rebuilt the binary at least three times mid-measurement. Verify-A's first T1
  showed a non-reproducible `open_close FATAL:11` (1888 vs 1899 result files) and a stray
  empty `@O@` appeared in the repo root; both vanished on the fixed binary across four
  subsequent runs, and every number in §12 was re-measured with an `md5sum src/xschem`
  bracket. **Verify and Sabotage must not be live at the same time** — this is the second
  consecutive item where that cost a batch.
* **Stale figure, corrected**: the Implement report quoted binary md5 `2cceb930…`; the
  binary actually in the tree and measured by everyone downstream is `cbf8784a…`
  (source-vs-binary freshness verified: `find src -maxdepth 1 -newer src/xschem` = 0 files).
  A stale number in a report, not a stale binary.

## 18. THE ADVERSARY PASS — ran late, did NOT refute the fix, DID refute two of its comments

Verify-C ran after commit `3ab11016` had landed, against the committed binary
(`md5 cbf8784a`, `git diff 3ab11016 HEAD -- src/ tests/` empty). **`refuted: false`.**

### 18.1 What it attacked, and found dead

* **11 name-form shapes the crew's own rows never ran**, each asserting the sentinel AND an
  `[exec touch]` host file: `${a[exec touch F]}` (a name carrying a command substitution
  and no parens, so the name really is looked up), `${a([exec …])}`,
  `${::nsx::a([exec …])}`, `$$a([exec …])`, a payload delivered through a **defined
  variable's VALUE**, backslash-brace `q\};…`, an embedded newline, a double-quote payload,
  `$undefined[exec …]`, and a 600-character name (over the 512-byte `namebuf`) followed by
  `[exec …]`. **All dead: `P=0`, `hostfiles={}` on every one.**
* The same shapes **through the arms a dead registry would skip** — `raw switch`,
  `raw clear`, `raw table_read`, `raw vcd_read` with a database preloaded, then the
  regsub-shaped and array-index payloads through all four top-level verbs. **12/12 dead.**
* **`annotate_op` with no argument** and the payload in `netlist_dir`, in three shapes.
  Dead.
* **The `.sch` route end to end with host-side-effect assertions** — `[exec touch]` in the
  `%` rawfile field, in the `%` sim_type field, inside a `${name}`, and behind a brace
  escape; loaded from disk, redrawn, fullyzoom'd. Sentinel 0 and hostfile 0 on all four.
  (The crew's own NINJ rows check only a sentinel; this is the stronger version.)
* **Anti-hollow, 15/15** literal-name loads including `paren(1).raw`, `curly{x}.raw`,
  `semi;colon.raw`, `quote".raw`, `dollar$.raw`, `brace${x.raw`, TAB, `amp&and.raw` and an
  embedded newline; **six** variable spellings resolve; the three shipped `$netlist_dir`
  schematics confirmed independently.
* **Bounds**: a 9000-character value, 800 chained references, names at exactly 511 and 512
  bytes (511 resolves, 512 falls to literal — the documented `namebuf` boundary), nested
  `${${a1}}` emitted literally, UTF-8, empty argument, bare `$`, bare `~`. No crash, no
  execution, no truncation into a different real path.
* **Arm semantics** the hoist could have silently changed: `raw switch 2` / `raw switch 0` /
  `raw clear 3` still read the RAW argument via `atoi()`; `raw switch <path>` with no type
  still falls through to the switch-to-next arm.
* **Scope fence** re-verified: the four raw-family regsub splices gone, the nine 0816 sites
  and `xinit.c:3235` byte-identical, `db_path_safe`'s guard regexp byte-identical.

### 18.2 What it refuted — two shipped comments, and that is the same failure attempt 1 died of

1. **`Tcl_GetVar2Ex` is not "a hash lookup" and the path is not evaluator-free.** A Tcl
   **read trace** on the named global runs on it, and can rewrite the value the read
   returns. Measured: `exec touch` created a host file and the resolved path became
   `/etc/plain.raw`. Mitigation measured too — all 9 shipped `trace add variable` sites are
   `write` traces, zero read traces, and no `Tcl_TraceVar` in `src/*.c`.
   → **doc/claude/issues/0819-*.md**. Comments in `src/util.c` and `src/xschem.h` corrected;
   the mitigation is now pinned by **GUARD3** in `test_raw_read_dispatch.tcl`, whose teeth
   were demonstrated (adding one read trace to `src/xschem.tcl` reds it).
2. **`resolve_rawfile_path()` is not idempotent in general**, and the reason the comment
   gave was wrong. → **doc/claude/issues/0820-*.md**; §17's bullet corrected in place;
   comments in `src/util.c`, `src/xschem.h`, `src/draw.c` and `src/wave_viewer.tcl`
   corrected.

**Both were comment-only defects — no compiled token changed.** Receipt:
`git diff -U0 -- src/util.c src/draw.c src/xschem.h` filtered to lines not beginning with
`*`, `/*` or `*/` is **empty**.

> ⚠ **CONSEQUENCE FOR THE NEXT CREW'S FRESHNESS CHECK, SAID OUT LOUD SO NOBODY IS MISLED.**
> The write-up agent is **not permitted to build** (crew rule 2 — only the Implement agent
> runs `make`), so those three files now have an **mtime newer than `src/xschem`** and
> `find src -maxdepth 1 -newer src/xschem` reports **3 files** instead of 0. The binary is
> **not** stale: `md5 cbf8784a…` is the same binary every §12 and §18 number was measured
> on, before and after these edits, and the only changed bytes are inside comment blocks.
> **Rebuild at the top of the next item** — it costs nothing and restores the 0-file
> invariant. Do not read the 3 as evidence that a measurement described code not in the
> tree; the receipt above is the discriminator.

### 18.3 What it found that is a new defect elsewhere

* **`src/xschem.tcl:4775` `graph_fill_listbox` splices a `.sch` `rawfile=` attribute into a
  Tcl script and it EXECUTES** — live GUI code, 7 call sites. `:4842` `raw_is_loaded` has
  the same shape and is dead code. → **doc/claude/issues/0821-*.md**, and note that 0821
  *corrects* the adversary's own reading of `:4775` (it substitutes the .sch-derived LOCAL,
  not a global — measured `res=LOCAL1 HIT=1`), which makes it worse than reported, not
  better. Outside this item's scope fence; it belongs with 0816/0817.

### 18.4 Residual risks it raised that are recorded elsewhere and NOT fixed

* GUARD1 counts invocations of the `subst` **command**, so a future C-level
  `Tcl_SubstObj`/`Tcl_ParseVar` would pass it silently. The property that actually holds is
  structural — no `(`/`)` can ever enter `namebuf`, so no index is ever parsed — and is only
  checkable by reading `expand_tcl_vars()`. The suite says so; restating it here because it
  is the one row a reader is most likely to over-trust.
* The dropped interp-result side effect is unpinned in **both** directions (§16 item 4).
* The `~` contradiction between `draw.c` and `wave_viewer.tcl` is **settled**: the `%`
  rawfile field **is** tilde-expanded, because `node_token_split()` calls
  `resolve_rawfile_path()`, which calls `expand_tilde()`. `wave_viewer.tcl` was wrong and
  is corrected.
* The mandated annotation invariants I1–I7 are untouched by this diff — it constructs no
  vector name anywhere; `op_annot::vector` (`src/op_annot.tcl:635`) remains the single
  builder. Verified rather than assumed, but **not** independently re-derived.

### 18.5 The one thing this pass changes about how the family is worked

An adversary pass that arrives **after** the commit is still worth having — it found two
false comments and one live defect elsewhere — but it cost a second write-up cycle and a
second set of source edits on a "finished" item. **Run Verify-C before the write-up agent,
and never concurrently with Sabotage.** That is now two consecutive items where agent
concurrency corrupted or delayed measurement (§17, last two bullets).

---

## 19. THE §16 RULING, ANSWERED — 2026-08-29, under the user's "decide the 23" instruction

**RULING: the loss stands. Keep the scanner exactly as it ships. Tcl array-element
syntax in a results-file path — `$a(1)`, and with it `$env(HOME)/x.raw` — does NOT
come back.** Decision D2 is ratified as permanent. No code moves.

Verified in this tree before ruling, not taken on the write-up's word:

* `src/util.c:910-914` `is_var_name_char()` excludes `(` and `)`; `src/util.c:1000-1006`
  rejects a `${NAME}` containing either. So neither name form can open an index. The
  sole Tcl API in the scanner is `Tcl_GetVar2Ex` (`src/util.c:1029`).
* `grep -rn '\$env(' --include=*.sch --include=*.sym .` → **0 files**, tree-wide. The
  complete set of shipped `rawfile=` spellings is seven `$netlist_dir/...` paths plus
  the bare name `distrib` — every one of them a plain global scalar the scanner still
  resolves (`src/xschem.tcl:76` etc. confirm `netlist_dir` is a scalar).
* `~/` still expands in the same field: `src/util.c:1075` (`resolve_rawfile_path()`
  calls `expand_tilde()`), pinned green by row **ORD7-tilde**,
  `tests/headless/test_raw_read_dispatch.tcl:500`.
* D2's cost is priced by a test row, not only a comment: **ORD9-paren-not-index**,
  `tests/headless/test_raw_read_dispatch.tcl:511`. A change of mind reds a check.
* No split brain: the only `subst`-based existence test left in the GUI,
  `file_exists` (`src/xschem.tcl:2847`), has **zero callers** — nothing tells the user
  a `$env(...)` path exists and then fails to open it. The ADE-side loader
  `ase::attach_dbs` (`src/ase.tcl:2100-2101`) tests `[file isfile $rawfile]` on an
  already-absolute path and never sees the spelling at all.

Why this is not a real trade:

1. **The one plausible spelling has an exact working synonym in the same box.**
   `$env(HOME)/x.raw` and `~/x.raw` name the same file, and `~/` works. Nothing a user
   can do was lost — only one way of typing it.
2. **Any other environment variable has a one-line escape hatch.** `set PDK_ROOT
   $env(PDK_ROOT)` in `~/.xschem/xschemrc` (sourced at global scope, `src/xinit.c:3458+`)
   makes `$PDK_ROOT/x.raw` resolve, because a scalar global is what the scanner reads.
3. **CADENCE OR NOTHING.** `$env(...)` in a stored path is a stock-XSCHEM Tcl-ism. The
   Cadence-shaped surface — Netlist-and-Run composing its own absolute results path —
   never used it. "It preserves legacy XSCHEM behaviour" is an argument against.
4. **Restoring it re-admits an index grammar that would then have to be proven inert.**
   Attempt 1 (§1-§10) shipped, and was reverted for, a sanitizer nobody could state in
   one sentence. "No array index is ever parsed here" is the sentence. It is worth more
   than a spelling with a synonym.

The failure is also loud rather than silent: an unresolvable `$env(HOME)/sim.raw` is
copied through **verbatim** and reported with the literal text the user typed
(`src/save.c:1334`), so the unexpanded `$env(...)` is visible in the message. It is not
blanked, and it never opens a different file. (The **wording** of that message is a
separate matter and is not ruled on here.)

**If a real bench ever needs it**, add `$env(NAME)` as a narrow, explicitly named case in
`expand_tcl_vars()` — a literal `$env(` prefix, one `Tcl_GetVar2Ex(interp, "env", NAME,
TCL_GLOBAL_ONLY)`, closing `)` required. **Do not restore the general array-index
grammar.** That is a future option, not a scheduled change; nothing is owed today.

Items 1, 2 and 4 of §16 (ordinary filenames starting to work, `\` no longer eaten, the
interpreter result no longer polluted) are ratified as the improvements they are.

---

## 20. ADVERSARY PASS ON THE §19 RULING — 2026-08-29. THE CODE STANDS; THE REASON GIVEN DOES NOT

**Verdict: the shipped scanner stays (do NOT re-open a general Tcl array-index
grammar), but §19 is overturned on three points — its security rationale, its
"permanently / nothing is owed" framing, and its claim that the failure is loud.**

### 20.1 The paren rule is NOT what closed the injection — this file's own sabotage run says so

§19 (and the sentence drafted to tell the user) attribute the loss of
`$env(HOME)/x.raw` to security: "dropping that spelling is what stops a booby-trapped
file name from running commands". **That is false, and §14 already measured it.**

* **SAB-7** put `(` back as an index opener and reddened **exactly one** row — **ORD9**,
  the cost row. **Every injection row stayed green**, including `INJ11-INJ14`
  (`tests/headless/test_raw_read_dispatch.tcl:450-462`), which drive
  `$noar0812([set ::SC_PWNED 1]).raw` plain and namespaced through read / clear /
  switch and assert the sentinel stays 0. Those four rows are non-vacuous: they go
  **red under SAB-1**.
* The mechanism is plain in the code: this scanner never substitutes anything. An
  index would reach `Tcl_GetVar2Ex` as a **literal element name**, exactly as the
  variable name does today (`src/util.c:1029`). What closed the hole is **D1** — no
  evaluator anywhere in the resolver — not **D2**.

So D2 buys a **one-sentence, readable safety property** ("no index is ever parsed
here"), which is worth having. It does not buy safety. Justification 4 of §19
("restoring it re-admits an index grammar that would then have to be proven inert")
is answered by SAB-7: on *this* scanner it was already proven inert, in this file.

**This matters beyond wording.** Attempt 1 (§3) was reverted for exactly one comment
asserting a safety property the code did not have, and §18.2 refuted two more. A
*ruling* that asserts a safety property the code does not have is the same defect
one level up, and it is the level the user reads.

### 20.2 The failure is SILENT on the surface the ruling itself names

§19: "the failure is also loud rather than silent ... reported with the literal text
the user typed (`src/save.c:1334`)". Measured in this tree:

* `src/save.c:1334` is `dbg(0, "raw_read(): failed to open file %s for reading\n", f)`.
  `dbg()` writes to `errfp` (`src/util.c:265-272`) and `errfp = stderr`
  (`src/main.c:91`, `src/xinit.c:1252`). A GUI user does not read it, and
  `raw_read(): failed to open file ... for reading` is developer voice, not the 9th-grade
  English the standing PLAIN ENGLISH ruling requires.
* The box the ruling names — the Graph dialog's results-file entry
  (`.graphdialog.center.right.rawentry`, `src/xschem.tcl:4921`, `:5091`) — says
  **nothing at all**. `graph_fill_listbox` (`src/xschem.tcl:4838-4846`) calls
  `xschem raw read`, and when it returns 0 it simply **skips the fill**: the signal
  list comes back **empty**, with no sentence anywhere. Type the old spelling, get a
  blank list and no reason.

That is a locally-correct, collectively-absurd refusal — the INTENT OVER MECHANISM
case — and `src/wave_viewer.tcl:4127` states the house position on exactly this shape:
"Refusing LOUDLY here is the honest move: emitting a suffix the engine cannot switch
on would silently draw nothing." **Fixing a silent refusal needs no ruling.**

### 20.3 One premise of §19 is narrower than it reads

§19's "no split brain" check covered `file_exists` (`src/xschem.tcl:2847`, zero callers
— confirmed) and `ase::attach_dbs` (`src/ase.tcl:2100-2101` — confirmed). It did not
look at **`library_defs_expand_path` (`src/library_defs.tcl:22-34`)**, which expands
`${VAR}` in a library path from **the environment** (`$env($var)`) — in the
Cadence-shaped library registry this branch ships. So "an environment variable in a
stored path is a stock-XSCHEM Tcl-ism the Cadence surface never uses" is not quite
true of this tree: the Library Manager teaches that spelling, and the identical
spelling in the results-file box means a Tcl **global** and falls through as literal
text. Unchanged by the fix (HEAD's `subst` read globals too), so it is not a
regression — but it is why "nothing was lost, only one way of typing it" understates
what was dropped: **environment variables in results paths**, full stop.

Verified and NOT disputed from §19: `$env(` appears in **0** `.sch`/`.sym` files
tree-wide; the shipped `rawfile=` set is seven `$netlist_dir/...` spellings plus the
bare name `distrib`, all plain global scalars the scanner still resolves; `~/` still
expands (`src/util.c:1069-1077`, row **ORD7-tilde** at
`tests/headless/test_raw_read_dispatch.tcl:500`); the xschemrc hatch
(`set PDK_ROOT $env(PDK_ROOT)`) does work, sourced at global scope.

### 20.4 The ruling that replaces §19

1. **Keep the scanner as it ships.** No general array-index grammar. Keep **ORD9** as
   the price tag. `$env(HOME)/x.raw` stays unsupported today.
2. **Do not tell the user the paren rule is a security rule.** The honest sentence is
   the plain one: *"The results-file box understands `~/` and plain names like
   `$netlist_dir`. It does not understand `$env(HOME)/sim.raw` — type `~/sim.raw` or
   the whole path."* No claim about booby-trapped filenames; that hole was closed by
   removing the evaluator, and it stays closed either way.
3. **Fix the silence, which is the part that actually costs a user something.** When
   the results-file box cannot open what is in it, say so in the dialog, in plain
   English, quoting the text the user typed — instead of returning an empty signal
   list. (`src/xschem.tcl:4838-4846`; the stderr line at `src/save.c:1334` is not a
   user-facing report.)
4. **Do not close the door "permanently".** `$env(NAME)` as one explicitly named case
   — literal `$env(` prefix, one `Tcl_GetVar2Ex(interp, "env", NAME, TCL_GLOBAL_ONLY)`,
   closing `)` required — remains available and provably evaluator-free. It is not
   scheduled and nothing is owed on it today; it is simply not forbidden, because the
   reason §19 gave for forbidding it does not hold.

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, on 2026-08-29: **"decide the 23, leave 0861 and 0299 for me"**.
A read-only audit had classified 25 of the 57 queued ruling debts as questions whose
answer is cheap and obvious; the user excluded 0861 and 0299 and told us to decide the
rest. **This debt (the §16 question) was one of the 23.** It was decided on the user's
behalf, not by them.

### The ruling, as an instruction to the codebase

1. **Keep the results-file scanner exactly as it ships.** No general Tcl array-index
   grammar comes back. `(` and `)` stay out of a variable name, by either name form.
   Row **ORD9-paren-not-index** (`tests/headless/test_raw_read_dispatch.tcl:511`) stays
   as the price tag, so a silent reversal reds a check instead of drifting.
   `$env(HOME)/sim.raw` in a results-file box stays unsupported today.

2. **Never tell the user the paren rule is a security rule.** The sentence to use, if
   one is ever shown, is the honest one:
   *"The results-file box understands `~/` and plain names like `$netlist_dir`. It does
   not understand `$env(HOME)/sim.raw` — type `~/sim.raw` or the whole path."*
   An earlier draft of this ruling's user-facing line said dropping that spelling "is
   what stops a booby-trapped file name from running commands". **That line is
   withdrawn and must not be shipped.** The injection hole was closed by removing the
   evaluator (decision D1); it stays closed whether or not parens are honoured.

3. **Fix the silence** — see the follow-up below. This part is not ratification; it is
   work that is now owed.

4. **The door is not closed permanently.** `$env(NAME)` as one explicitly named case —
   a literal `$env(` prefix, one
   `Tcl_GetVar2Ex(interp, "env", NAME, TCL_GLOBAL_ONLY)`, closing `)` required — stays
   available and is provably evaluator-free. Nothing is scheduled and nothing is owed
   on it today. It is simply **not forbidden**, because the reason given for forbidding
   it does not hold.

Items 1, 2 and 4 of §16 (ordinary filenames starting to work, `\` no longer eaten, the
interpreter result no longer polluted) are **ratified as improvements**, unchanged.

### Why

* **CADENCE OR NOTHING.** `$env(...)` inside a stored results path is a stock-XSCHEM
  Tcl-ism. The Cadence-shaped surface this branch ships — Netlist-and-Run — composes
  its own absolute results path and never sees that spelling at all
  (`ase::attach_dbs` tests `[file isfile $rawfile]`, `src/ase.tcl:2100-2101`). "It
  preserves legacy XSCHEM behaviour" is an argument **against** under the standing
  ruling, not for.
* **Nothing a user can DO was lost — only one way of typing it.** `$env(HOME)/x.raw`
  and `~/x.raw` name the same file, and `~/` is still expanded
  (`expand_tilde()` inside `resolve_rawfile_path()`, `src/util.c:1069-1077`). Any
  other environment variable has a one-line escape hatch in `~/.xschem/xschemrc`:
  `set PDK_ROOT $env(PDK_ROOT)` makes `$PDK_ROOT/x.raw` resolve, because a scalar
  global is exactly what the scanner reads.
* **Restoring the grammar costs more than it buys.** Attempt 1 of this very fix was
  reverted for shipping a sanitizer nobody could state in one sentence. *"No array
  index is ever parsed here"* is that sentence, and it is worth more than a spelling
  that already has a working synonym.
* **But the security framing is measurably false**, which is why item 2 above exists.
  Sabotage variant SAB-7 (§14) put `(` back as an index opener and reddened **exactly
  one** row — ORD9, the cost row. Every injection row stayed green, including
  INJ11–INJ14 (`tests/headless/test_raw_read_dispatch.tcl:450-462`), which drive
  `$noar0812([set ::SC_PWNED 1]).raw` plain and namespaced through read/clear/switch
  and assert the sentinel stays 0. Those four are non-vacuous — they go red under
  SAB-1. Attempt 1 was reverted for **one comment asserting a safety property the code
  did not have**; a ruling that repeats that assertion is the same defect one level up,
  at the level the user actually reads.
* **PLAIN ENGLISH and INTENT OVER MECHANISM** are what force the follow-up. Today a
  results-file box that cannot open what is in it says nothing at all to a GUI user.

### What was verified in the tree (so a later reader need not re-derive it)

* `src/util.c:910-914` — `is_var_name_char()` is `[A-Za-z0-9_]` only; `(` and `)` are
  excluded on purpose, with the reason in the comment above it. No index is parsed.
* `src/util.c:1000-1006` — a `${NAME}` containing `(` or `)` is rejected and emitted as
  a literal `$`; both name forms are paren-free by construction.
* `src/util.c:1029` — the only Tcl API in the scanner is
  `Tcl_GetVar2Ex(interp, namebuf, NULL, TCL_GLOBAL_ONLY)`. Reading the `env` **array**
  as a scalar returns NULL, so `$env(HOME)` falls to `append_unresolved_ref()` and
  passes through as literal text.
* `src/util.c:1069-1077` — `resolve_rawfile_path()` = `expand_tilde()` then
  `expand_tcl_vars()`. `~/` still expands: the working synonym.
* `grep -rn '\$env(' --include=*.sch --include=*.sym .` → **0** files tree-wide. The
  shipped corpus cost of decision D2 is genuinely zero.
* The shipped `rawfile=` set is seven `$netlist_dir/...` spellings plus the bare name
  `distrib`; `netlist_dir` is a plain global scalar (`src/xschem.tcl:76-78`), so every
  shipped spelling still resolves.
* `tests/headless/test_raw_read_dispatch.tcl:500` **ORD7-tilde** and `:511`
  **ORD9-paren-not-index** — `~/` works, and D2's cost is pinned by a check.
* `tests/headless/test_raw_read_dispatch.tcl:450-462` **INJ11–INJ14** — the array-index
  injection rows, green with parens excluded and green under SAB-7 as well.
* `src/xschem.tcl:2847` `file_exists`, the last `subst`-based existence test — **zero
  callers** across `src/*.tcl` and `utils/*.tcl`. Nothing tells the user such a path
  exists and then fails to open it.
* `src/ase.tcl:2100-2101` — `ase::attach_dbs` tests `[file isfile $rawfile]` on an
  already-absolute path; the Netlist-and-Run route never sees a `$env()` spelling.
* `src/save.c:1334` — a failed open reports the path verbatim, **but through
  `dbg(0, ...)` → `errfp` → stderr** (`src/util.c:265-272`, `src/main.c:91`,
  `src/xinit.c:1252`). A GUI user never sees it. This is developer voice, not a
  user-facing report — §19's claim that the failure is "loud" was wrong on this point.
* `src/xschem.tcl:4838-4846` — `graph_fill_listbox` calls `xschem raw ...` and, on a 0
  return, simply skips the fill. The signal list comes back **empty with no sentence
  anywhere**. The box in question is the Graph dialog's results-file entry
  (`.graphdialog.center.right.rawentry`, `src/xschem.tcl:4921`, `:5091`).
* `src/library_defs.tcl:22-34` — `library_defs_expand_path` expands `${VAR}` in a
  library path **from the environment** (`$env($var)`), in the Cadence-shaped library
  registry this branch ships. Not a regression (HEAD's `subst` read only Tcl globals in
  the results path either), but it means the Library Manager teaches an environment-
  variable spelling that the results-file box does not honour. Worth knowing; it does
  not change the ruling.
* `src/xinit.c:3458+` — `xschemrc` is sourced at global scope, so the
  `set PDK_ROOT $env(PDK_ROOT)` hatch really does yield a scalar global the scanner
  resolves.

### Ratification vs. code change

**Mixed.** Items 1, 2 and 4 of the ruling **ratify what already ships — nothing moves
in the code.** Item 3 **implies a code change, and it is FOLLOW-UP WORK NOT YET DONE:**

> When the Graph dialog's results-file box cannot open what is typed in it, say so **in
> the dialog**, in plain English, quoting the text the user typed — instead of
> returning an empty signal list. Site: `src/xschem.tcl:4838-4846` (`graph_fill_listbox`,
> the `if {$res}` arm has no `else`). The existing `src/save.c:1334` stderr line does
> not discharge this. The house position on exactly this shape is already written down
> at `src/wave_viewer.tcl:4127`: *"Refusing LOUDLY here is the honest move ... would
> silently draw nothing."*

Item 2 also implies that **no shipped comment, message or doc line may describe the
paren exclusion as a security measure.** If one exists, it is wrong and should be
corrected when next touched.

### Adversary

An adversary pass ran against the first draft of this ruling (§20) and **overturned it
in part**: it did not disturb the code answer — no array-index grammar returns — but it
showed the security rationale was false (SAB-7 reddened only the cost row), that the
"loud failure" was a stderr line a GUI user never sees, and that closing the door
"permanently" was unearned. Its better answer is what is recorded above.

**The user may reverse this at any time; it was decided to spare their attention, not to
bind them.**
