# 0261 — three descend paths return success while landing the user on a blank or fabricated page

Status: **OPEN** — all three variants reproduced headless (transcript below). What is *not* measured
is the GUI presentation: the title-bar text and read-only marker are read off `set_modify()`
(`src/actions.c:256-262`) rather than clicked through under a real `$DISPLAY`.
Area: `src/save.c` `load_schematic()` (`:3711`) — the generator arm (`:3801-3808`), the `pclose`
(`:3833`), the empty-filename arm (`:3858-3874`); `read_xschem_file()`'s EOF `break` (`src/save.c:3161`);
`descend_symbol()` (`src/save.c:5546`, loads at `:5643` / `:5669`); `descend_schematic()`
(`src/actions.c:3575`, loads at `:3737`)
Tests: none — no headless case asserts on a descend that loads zero objects, and nothing in
`tests/headless/` drives a schematic generator at all. Proposed
`tests/headless/test_descend_blank_success_0261.tcl`
Found: 2026-08-08, in the descend silent-refusal census (`doc/claude/code_analysis/descend_silent_refusal_census.md`)
Related: [0250](0250-failed-descend-strands-the-window-on-a-blank-child-page.md) (the *failed* load that
still commits the level change — the mirror case, see "Not 0250" below),
[0251](0251-a-refused-descend-has-no-return-channel.md) (the discarded return value that makes this
undetectable from Tcl), [0232](0232-missing-symbol-substitution-silently-unnames-nets.md) (the same
"substitute something plausible and say nothing" reflex, one layer down),
[0203](0203-stale-sel_array-descends-a-deselected-instance.md),
[0056](0056-ctrl-n-blank-window-collides-with-unsaved-untitled.md) (owns `get_unused_untitled_name`,
which this issue abuses).

## The defect

Every other finding in the descend census is a *refusal* that says nothing. This one is the
inverse: the descend **succeeds by every signal the program emits** — `load_schematic()` returns 1,
`descend_schematic()` returns 1, `xschem descend` prints `1`, `xctx->currsch` advanced, the title bar
names the child cell, the page is editable — and the user is looking at a blank or half-built
canvas that is not the cell they asked for.

`load_schematic()` initialises `ret` optimistically and has exactly **one** place that lowers it:

```c
src/save.c:3718
  int ret = 1; /* success */
```
```c
src/save.c:3810-3812
    if( fd == NULL) {
      size_t len;
      ret = 0;
```

Everything after `fd != NULL` — the parse, the truncation warnings, the object count, the
generator's exit status — is invisible to the return value (`return ret;` at `src/save.c:3905`).
Three distinct producers of a non-`NULL` `fd`-or-equivalent therefore report success on nothing.

### (a) A schematic generator that fails or emits nothing

```c
src/save.c:3801-3809
    if(generator) {
      char *cmd;
      cmd = get_generator_command(ffname);
      if(cmd) {
        fd = popen(cmd, "r");
        my_free(_ALLOC_ID_, &cmd);
      } else fd = NULL;
    }
    else fd=my_fopen(name,fopen_read_mode);
```

The only generator failure this catches is "the generator **file** is not on the library path":
`get_generator_command()` returns `NULL` solely when `stat()` on the resolved command fails
(`src/token.c:174-176`). Once the file exists, `popen()` hands back a valid `FILE*` regardless — it
forks `/bin/sh`, so even a non-executable or syntactically broken script yields a readable, empty
pipe. Then:

```c
src/save.c:3829-3834
    } else {
      clear_drawing();
      dbg(1, "load_schematic(): reading file: %s\n", name);
      read_xschem_file(fd);
      if(generator) pclose(fd);
      else fclose(fd); /* 20150326 moved before load symbols */
```

`pclose()`'s return value — the wait status of the generator, the *only* channel by which a
generator can report "I could not build this cell" — is discarded on the spot. What is checked: the
generator file exists. What is not checked: that it ran, that it exited 0, that it wrote a single
byte, or that what it wrote was a complete cell. A generator that dies halfway through emitting the
schematic leaves the partial output committed as the child page, with no marker of where it stopped.

Note the one accidental channel: the generator's **stderr** is not redirected by `popen(cmd, "r")`,
so a generator that diagnoses its own failure on stderr reaches a terminal-launched user's terminal
(measured below). A desktop-launched GUI user sees nothing, and either way `ret` is still 1.

### (b) An existing but empty or truncated `.sch`

`read_xschem_file()`'s loop terminates on EOF, and that is the **normal** exit for every successful
load in the program:

```c
src/save.c:3159-3162
  while(!endfile)
  {
    if(fscanf(fd," %c",tag)==EOF) break; /* space before %c --> eat white space */
    switch(tag[0])
```

A zero-byte file takes the `break` on the first iteration — bit-for-bit the same control flow as a
correct file that has been fully consumed. There is no record-count check, no "did I see a `v` line"
check, and `xctx->file_version` is defaulted to `1.0` for a file that carried no version at all
(`src/save.c:3285-3288`). The function is `void`; it could not report a problem if it wanted to.

Truncation is *partially* noisy, and the distinction matters because it decides how much of the fix
is new machinery versus routing existing messages:

| fixture | diagnostic emitted | `load_schematic` ret |
|---|---|---|
| 0 bytes | none | 1 |
| header only (`v`/`G`/`K`/`V`/`S`/`E`, no objects) | none | 1 |
| cut mid-`C` record (`C {blk.sym} 100`) | `WARNING: missing fields for INSTANCE object, ignoring.` (`src/save.c:2922`) | 1 |
| cut inside a `{...}` string | `EOF reached, malformed {...} string input, missing close brace` (`src/save.c:3306`) + `WARNING:  missing fields for TEXT object, ignoring` (`src/save.c:2862`) | 1 |

The sibling record loaders warn the same way (`WIRE` `:2884`, `POLYGON` `:2955`, `ARC` `:3023`,
`xRECT` `:3067`, `LINE` `:3128`). All of them are bare `fprintf(errfp, ...)` — **stderr**, not
`alert_`, not `statusmsg`, not the CIW. Per the census's reachability rule they are visible to a
terminal-launched user and invisible to a desktop-launched one, and in neither case do they change
the outcome: the descend still reports success and the truncated cell is still what you are now
editing (and, being editable and `modified=0`, what a later Ctrl+S will write back — losing whatever
followed the truncation point in the original file).

"Zero objects" alone is **not** a defect signal. `xschem_library/inst_sch_select/comp3_empty.sch` is
a shipped, deliberate near-empty cell (pins, `S {vout out 0 2}`, no body) referenced by
`inst_sch_select.sch:159`, and `load_schematic()` itself treats `xctx->instances == 0` as a legitimate
state at `src/save.c:3842`. The thing that must be distinguished is *loaded an empty/unparseable
byte stream* from *loaded a well-formed file that happens to contain nothing*.

### (c) A `tcleval()` symbol reference that evaluates to empty after link time

`descend_symbol()` resolves the target with no emptiness check anywhere in the chain:

```c
src/save.c:5659-5669
    if(!sympath || stat(sympath, &buf)) { /* not found */
      dbg(1, "descend_symbol: not found: %s\n", sympath);
      if(is_generator(name)) {
        my_strdup2(_ALLOC_ID_, &sympath, tcl_hook2(name));
      } else {
        my_strdup2(_ALLOC_ID_, &sympath, abs_sym_path(tcl_hook2(name), ""));
      }
    }
    dbg(1, "descend_symbol(): name=%s, sympath=%s, dirname=%s\n", name, sympath, xctx->current_dirname);
    ++xctx->currsch; /* increment level counter */
    load_schematic(1, sympath, 1, 1);
```

If the instance's symbol name is `tcleval(...)` and the expression now evaluates to the empty string,
both arms produce `""` — `tcl_hook2()` returns the empty Tcl result directly (`src/token.c:88-92`),
and `abs_sym_path()` is a wrapper over the Tcl proc whose first statement is
`if {$fname eq {} } return {}` (`src/xschem.tcl:12322`). Note `is_generator()` matches
`tcleval($::x)` — its regex is `^[^ \t()]+\([^()]*\)[ \t]*$` (`src/token.c:115`) — so it is the
generator arm that usually fires, but the outcome is identical either way. `xctx->currsch` is already
incremented on the line above.

`load_schematic("")` then falls into the arm that exists to serve **File > New**:

```c
src/save.c:3858-3874
  } else { /* ffname == NULL or empty */
    /* if(reset_undo) xctx->time_last_modify = time(NULL); */ /* no file given, set mtime to current time */
    if(reset_undo) xctx->time_last_modify = 0; /* no file given, set mtime to 0 (undefined) */
    clear_drawing();
    /* next free untitled[-n] name, avoiding both on-disk files and names already open in
     * other windows so a second blank window does not collide (issue 0056) */
    get_unused_untitled_name(xctx->netlist_type == CAD_SYMBOL_ATTRS, name, S(name));
    my_strncpy(xctx->current_name, name, S(xctx->current_name));
    if(getenv("PWD")) {
      /* $env(PWD) better than pwd_dir as it does not dereference symlinks */
      my_strncpy(xctx->current_dirname, getenv("PWD"), S(xctx->current_dirname));
    } else {
      my_strncpy(xctx->current_dirname, pwd_dir, S(xctx->current_dirname));
    }
    my_mstrcat(_ALLOC_ID_, &xctx->sch[xctx->currsch],  xctx->current_dirname, "/", name, NULL);
    if(reset_undo) set_modify(0);
  }
```

The descend lands on a **fabricated blank cell named `$PWD/untitled[-N].sch`**, `modified=0`, fully
editable, `ret` still 1. Note the extension: `get_unused_untitled_name`'s `symbol` argument is read
from `xctx->netlist_type` *before* `descend_symbol()` sets `CAD_SYMBOL_ATTRS` at `src/save.c:5679`,
so a **symbol-view** descend fabricates a cell called `untitled.sch` and then flips the editor into
symbol mode on top of it — measured below. This branch is correct for File > New (`ask_new_file` /
the discard path at `src/actions.c:3942-3946` uses the same namer) and always wrong as a descend
destination.

**Correction to the census brief.** The ~40 stray `untitled-*.sch` at the repo root (plus copies
under `src/` and `tests/`) are **not** evidence of this path. Every one of them is 89 bytes and ends
`N 0 0 100 0 {}` — they are the residue of headless test scripts that did
`xschem clear force; xschem wire 0 0 100 0; xschem save` on an unnamed buffer. The fabrication here
is purely in-memory (nothing writes the file until the user saves), so it leaves no on-disk trace at
all. Do not cite the stray files as corroboration.

`descend_schematic()` is **not** exposed to (c): `get_sch_from_sym()` leaves `filename` empty in the
same situation and the caller bails at `src/actions.c:3617` (`if(!filename[0]) return 0;`). That is a
silent *refusal* — census issue [0251](0251-a-refused-descend-has-no-return-channel.md)'s territory,
not this one. Only `descend_symbol()`, which has no such guard, reaches the fabrication.

### Not 0250

[0250](0250-failed-descend-strands-the-window-on-a-blank-child-page.md) and this issue meet at the
same blank canvas from opposite directions, and conflating them will produce a fix for one that
misses the other:

| | 0250 | 0261 |
|---|---|---|
| `load_schematic` outcome | `fd == NULL` → `ret = 0` | `fd` valid → `ret = 1` |
| what is wrong | the level change was committed *anyway* (`currsch++` precedes the load) | the level change is legitimate; the *content* is wrong |
| the honest fix | unwind `currsch` on failure, or surface the 0 | detect that "success" produced nothing real |
| a caller that checked the return | would catch it | would **not** — the return says 1 |

0250 is "the program knew and did not tell you". 0261 is "the program did not know". In the
transcript below the `no_such_gen` row is a 0250 instance sitting next to three 0261 instances, for
contrast.

## Reproduce

Measured, working tree at `08ef2ffd`, prebuilt `src/xschem`. Fixtures under
`/tmp/claude-1000/-home-analog-dev-xschem-claude/ee436d63-e0fe-4f9d-aa40-0c351cf000f5/scratchpad/rep/`:
`blk.sym` (`type=subcircuit`), parents carrying `schematic=` overrides, `empty.sch` (0 bytes),
`hdronly.sch` (header records only), `trunc_inst.sch` (cut after `C {blk.sym} 100`), `trunc_brace.sch`
(cut inside a `T {` string), and four generators (`gen_partial.tcl` emits `v`…`E` plus one wire then
`exit 3`; `gen_ok_empty.tcl` is `exit 0`; `gen_stderr.tcl` writes one line to stderr then `exit 2`;
`no_such_gen.tcl` does not exist). `parent5.sch` holds `C {tcleval($::mysym)} 300 -100 0 0 {name=y2}`.

```
$ ./src/xschem --nogui --pipe -q --script $D/final.tcl 2>&1
Using run time directory XSCHEM_SHAREDIR = /home/analog/dev/xschem-claude/src
Sourcing /home/analog/dev/xschem-claude/src/xschemrc init file
(a) generator schematic ---------------------------------------
  gen_partial (half a cell, then exit 3): ret=1  currsch=1 cell=gen_partial.tcl() insts=0 wires=1
  gen_ok_empty (exit 0, no output):       ret=1  currsch=1 cell=gen_ok_empty.tcl() insts=0 wires=0
  no_such_gen (generator file missing):   ret=0  currsch=1 cell=no_such_gen.tcl() insts=0 wires=0
gen_stderr.tcl: cannot build cell: bad parameter
  gen_stderr (writes to stderr, exit 2):  ret=1  currsch=1 cell=gen_stderr.tcl() insts=0 wires=0
(b) existing but empty / truncated .sch ------------------------
  empty.sch (0 bytes):                    ret=1  currsch=1 cell=empty.sch insts=0 wires=0
  hdronly.sch (header, no objects):       ret=1  currsch=1 cell=hdronly.sch insts=0 wires=0
WARNING: missing fields for INSTANCE object, ignoring.
  trunc_inst.sch (cut mid-C-record):      ret=1  currsch=1 cell=trunc_inst.sch insts=0 wires=1
EOF reached, malformed {...} string input, missing close brace
WARNING:  missing fields for TEXT object, ignoring
  trunc_brace.sch (cut inside {...}):     ret=1  currsch=1 cell=trunc_brace.sch insts=0 wires=1
(c) tcleval symbol name blanked after link time ----------------
  descend_symbol: currsch=1 cell=untitled.sch insts=0 wires=0 netlist_type=symbol modified=0
  full schname=/tmp/claude-1000/-home-analog-dev-xschem-claude/ee436d63-e0fe-4f9d-aa40-0c351cf000f5/scratchpad/rep/untitled.sch
```

Reading the rows:

- `ret=1` is the value `xschem descend` puts in the Tcl result (`src/scheduler.c:3006`), i.e. the
  value `descend_schematic()` returned at `src/actions.c:3785`.
- `gen_partial` shows the half-written cell committed: `wires=1` is the one wire the generator
  managed to emit before `exit 3`. Nothing distinguishes it from a cell that really has one wire.
- `gen_stderr`'s line appears *because* this run is on a terminal; the same run under a
  desktop-launched GUI shows nothing anywhere in the UI.
- `no_such_gen` is the 0250 shape: `ret=0` **and** `currsch=1`. Because `xschem descend` hardcodes
  `alert=0` (`src/scheduler.c:2993/3000/3002`), even that honest 0 produces no message.
- (c): a symbol-view descend whose target evaluated to empty landed on `untitled.sch` — `.sch`
  extension, `symbol` netlist type, `modified=0`.

The three `dbg()` calls that would have told a developer what happened
(`src/save.c:3786-3787`, `:3857`, `:5667`) are all level 1, i.e. invisible at the default debug level
regardless of how xschem was launched.

`descend_symbol` additionally has no return channel at all — its scheduler branch ends
`Tcl_ResetResult(interp);` (`src/scheduler.c:3035`) and the two `load_schematic()` calls at
`src/save.c:5643` and `:5669` drop the value on the floor. See
[0251](0251-a-refused-descend-has-no-return-channel.md).

### Rider, measured: the fabricated path is *appended*, not assigned

`src/save.c:3872` uses `my_mstrcat`, which **appends** when the target pointer is non-`NULL`:

```c
src/util.c:776
  if(*str != NULL) s = strlen(*str);
```

This is an omission rather than a design: the sibling fabrication site — the File > New / discard
path — does the free explicitly before the same call,

```c
src/actions.c:3948-3949
        my_free(_ALLOC_ID_, &xctx->sch[xctx->currsch]);
        my_mstrcat(_ALLOC_ID_, &xctx->sch[xctx->currsch], pwd_dir, "/", name, NULL);
```

whereas `src/save.c:3872` has no such free. `xctx->sch[]` slots above the current level are never
cleared when a new top-level file is loaded, so a stale entry at that depth is concatenated with the
fabricated name:

```
A. load parent4, descend into generator x1, DO NOT go_back
   currsch=1 sch0=parent4.sch sch1=gen_partial.tcl()
B. load parent5 into the same window while still at level 1
   currsch=0 sch0=parent5.sch sch1=
C. blank the tcleval and descend_symbol y2
   currsch=1
   schname=gen_partial.tcl()/tmp/claude-1000/-home-analog-dev-xschem-claude/ee436d63-e0fe-4f9d-aa40-0c351cf000f5/scratchpad/rep/untitled.sch
```

(`sch1` prints empty at step B only because `xschem get schname 1` guards on `x <= xctx->currsch`
and never calls `Tcl_SetResult` — `src/scheduler.c:4691-4693`. The allocation is still there, which is
what `my_mstrcat` finds.) The resulting `xctx->sch[1]` is a path that cannot exist; a save from that
page would target it. This is a real bug in the same three lines and should be fixed with them, but
it is a *consequence* of reaching a branch that should never have been reached from a descend.

Secondary, unmeasured, same branch: `get_unused_untitled_name()` collision-tests with
`stat(name, &buf)` on a **relative** name (`src/xinit.c:178`), i.e. against the process cwd, while the
path it feeds is built from `getenv("PWD")` (`src/save.c:3866-3868`). Tcl's `cd` does not update
`$env(PWD)`, so after any scripted `cd` the two disagree and the "unused" guarantee does not hold for
the directory the name is actually placed in.

## What the user perceives

For all three variants: the canvas goes blank (or shows a fragment), the hierarchy is one level
deeper, and the title bar reads `xschem [N] - <cell>` with no marker — `set_modify()` composes it as
`"xschem" wn " - [file tail [xschem get schname]]" ro` (`src/actions.c:260`), and `modified` is 0 so
not even the `*` appears. The `ro` suffix is empty unless `descend_readonly` is on
(`src/actions.c:3768-3771`); the generator page in particular is left writable because the read-only
probe is explicitly skipped for generators (`if(reset_undo && !generator) xctx->readonly = !file_writable(name);`,
`src/save.c:3836`).

So the presentation is indistinguishable from "this cell is genuinely empty" — which for
(a) and (b) is a plausible reading, and for (c) is not, but the only tell is the word `untitled` in
the title bar, which reads as a File > New page rather than as an error.

The failure mode that follows is the expensive one: the user, believing they are inside the child
cell, draws into the blank page and saves. For (b) that overwrites the truncated original with the
truncation made permanent; for (a) it creates a file literally named `gen_partial.tcl()`; for (c) it
writes `$PWD/untitled.sch` (or the concatenated nonsense path from the rider). None of this is
recoverable through undo, which was reset by the descend (`xctx->clear_undo()`, `src/save.c:3732`).

## Fix, if it is to be closed

Three independent changes; (3) is the one that is unambiguously a bug in every reading.

**1. Check the generator's exit status.** `pclose()` already returns it; capture it and fail the load.

```c
/* src/save.c:3832-3834 */
      read_xschem_file(fd);
      if(generator) {
        int st = pclose(fd);
        /* A generator that dies or exits nonzero produced no cell (or half of one):
         * treat it as a failed open, not as an empty schematic. Its own stderr, if
         * any, went straight through to xschem's stderr and never reached the GUI. */
        if(st == -1 || !WIFEXITED(st) || WEXITSTATUS(st) != 0) ret = 0;
      }
      else fclose(fd);
```

`WIFEXITED`/`WEXITSTATUS` need `<sys/wait.h>` and a `__unix__` guard; the Windows path already goes
through `tclsh` in `get_generator_command()` (`src/token.c:190`) and `_pclose` returns the exit code
directly. With `ret = 0` the existing `alert` machinery at `src/save.c:3813-3818` does **not** fire —
it is inside the `fd == NULL` arm — so either hoist the alert out of that arm or add a parallel one;
and remember every current descend caller passes `alert=0` (`src/scheduler.c:2993`), so the message
must not be the only channel. See (4).

**2. Distinguish "empty file" from "file with no objects".** These are different facts and only the
first is an error. The cheap discriminator is at the top of `read_xschem_file()`: the loop already
knows whether the first `fscanf` hit EOF before any record. Give the function an `int *` out-param (or
a small struct) reporting *records consumed* and *malformed records seen*, and have `load_schematic()`
warn when records-consumed is 0 for a file that `stat()`s non-empty — or when it is 0 and the byte
size is 0. Route the existing per-record `fprintf(errfp, "WARNING: ...")` messages
(`src/save.c:2862/2884/2922/2955/3023/3067/3128`, `:3306`) through the same counter so a truncated
load is reportable rather than merely printable. Do **not** make "zero objects" itself an error:
`comp3_empty.sch` must keep loading clean.

**3. Refuse — loudly — to fabricate an untitled cell as a descend target.** Fabricating one for
File > New is the branch's purpose; reaching it from a descend is always wrong. Two edits:

- In `descend_symbol()`, before `++xctx->currsch` at `src/save.c:5668`, bail on an empty resolution
  with a user-visible message and no level change:
  ```c
      if(!sympath || !sympath[0]) {
        my_snprintf(msg, S(msg), "Cannot descend: symbol reference \"%s\" resolves to nothing", name);
        statusmsg(msg, 1);
        if(has_x) { tclvareval("alert_ {", msg, "}", NULL); }
        my_free(_ALLOC_ID_, &sympath);
        return 0;
      }
  ```
  matching the guard `descend_schematic()` already has at `src/actions.c:3617` (which should also gain
  a message — that is [0251](0251-a-refused-descend-has-no-return-channel.md)).
- Independently, make the fabrication branch defensive: change `my_mstrcat` to `my_strdup2` at
  `src/save.c:3872` so it assigns rather than appends, whatever the caller did. That is a correctness
  fix on its own and does not depend on the guard above.

An optional belt-and-braces variant: give `load_schematic()` a flag meaning "an empty name is a
caller bug, not a New" and pass it from both descend entry points, so any *future* descend path that
loses its filename gets a refusal instead of a fabricated cell.

**4. The messages need somewhere to go.** All of the above produce a diagnosis that the current
plumbing throws away: `xschem descend` hardcodes `alert=0`, `descend_symbol` discards
`load_schematic`'s return entirely, and `stderr` is not a user channel for a desktop-launched GUI.
Landing (1)–(3) without also landing [0251](0251-a-refused-descend-has-no-return-channel.md)'s return
channel converts three silent wrong-successes into three silent refusals. Prefer `statusmsg`
(persistent, but see [0248](0248-gate-and-prompt-statusbar-messages-are-wiped-by-the-coordinate-readout.md)
for its wipe hazard) plus `ciw_echo` over `alert_`, which cannot be used at all from the headless and
scripted paths.

**Proposed test** `tests/headless/test_descend_blank_success_0261.tcl`: the fixture set used above,
asserting `xschem descend` returns 0 (and `currsch` is unchanged) for the failing-generator and
zero-byte cases, returns 1 for `comp3_empty.sch`-shaped cells, and that `descend_symbol` on a
blanked `tcleval()` name leaves `currsch` at 0 and `schname` unchanged. It is the first headless case
to drive a schematic generator at all, so the generator fixtures are reusable beyond this issue.

## Risks

- **Generators that exit nonzero on purpose.** Some site generators may emit a valid cell and then
  exit with a status nobody has ever looked at, because nobody has ever looked at it. Turning that
  into a hard failure is a compatibility break for exactly the users who use generators most. The
  conservative first landing is to *warn* on nonzero exit while still loading what arrived, and to
  hard-fail only when the exit is nonzero **and** zero records were consumed — which is the case that
  is unambiguously broken.
- **`pclose` and SIGPIPE.** `read_xschem_file()` reads to EOF, so the pipe is normally drained before
  `pclose`. If a future change ever stops reading early, the generator gets SIGPIPE and the new check
  would report a failure that the old code silently tolerated. Any early-exit added to the read loop
  must set a flag that suppresses the status check.
- **`ret = 0` now reaches 0250's stranding.** Making the generator arm return 0 routes more traffic
  through the path where `currsch` was already incremented and nothing unwinds it. 0261's fix makes
  0250 more visible, not less; they should land together or 0250 first.
- **`my_strdup2` at `src/save.c:3872` changes File > New too.** The append-vs-assign fix is correct in
  both cases, but File > New is a heavily-exercised path with tab/window interactions
  ([0056](0056-ctrl-n-blank-window-collides-with-unsaved-untitled.md)); the `sch[]` producers and
  `is_pristine_untitled()` (`src/scheduler.c:6722`, which keys off `xctx->currsch == 0` and the
  untitled basename) should be re-read before assuming nothing depended on the concatenation.
- **`read_xschem_file()` signature change.** It is `static` in `save.c` with exactly two callers —
  `load_schematic()` (`:3832`) and the disk-undo restore (`:4232`) — so the change is contained, but
  the undo-restore caller must **not** inherit the new refusal, or a legitimately empty undo slot
  becomes an error.
- **No coverage today.** Nothing in `tests/headless/` exercises a generator, an empty `.sch`, or a
  truncated `.sch`, so every one of these edits is currently unguarded. Land the test first.

---

## D5 attempt (2026-08-10) — built, verified, **REVERTED**. Still OPEN, and narrower than it looked.

Measured BEFORE (unchanged — the tree is back at `b1326180`), all three variants reporting
*positive* success (`ret=1` **and** `descend_error` empty):

```
0261a exit-3 generator   : descend='1' err='' currsch=1 wires=1 readonly=0
0261b truncated child : descend='1' err='' currsch=1 instances=0 wires=1
0261c descend_error      : ''   <- EMPTY == 'the descend worked'
```

Correction to the original write-up, measured: **0261c's recipe as filed does not reproduce.** If
`::mysym` is blank from the start, D4's `descend_missing_sym` guard catches it first
(`descend_symbol` → `0`, `missing-symbol`). The symbol must **resolve at load time and the
expression blank afterwards** (the live-parameter case) for File>New's fabrication branch to be
reached.

The fix that was built and reverted: a **second** channel `xctx->load_verdict` (with
`LOAD_V_{OK,NOFILE,FABRICATED,NORECORDS,GENFAIL,GENWARN}`) plus `load_malformed`;
`read_xschem_file()` returning a record count; `pclose()`'s wait status decoded under `__unix__`.
`load_schematic()`'s own `int` return was left byte-identical in meaning, because `src/xinit.c:3697`
and `:3713` do `if(!file_loaded) tcleval("exit 1")` — lowering it would make xschem exit 1 at
startup on an empty start cell. Measured green:

```
F1/F3 generator-emitting-nothing and 0-byte child -> ret=0 moved=1 err=empty-file, spoken
F4 header-only (well-formed, object-free) child   -> ret=1 err={}   (comp3_empty preserved)
F2/F5 generator exit 3 WITH records, truncated child -> ret=1 err={} warned=1  (warn, never refuse)
```

**Reverted** because a sibling part of the same commit (the 0252 chooser filter) broke the
create-the-child workflow — see [0379](0379-get-sym-type-returns-empty-while-an-instance-is-selected.md).

**Still open, and the adversary pass showed the headline is wider than the fix was:** the verdict's
"at least one record consumed" rule is a **token count, not a parse-success count**.
`read_xschem_file()`'s `default:` arm counts every unknown token as a record, so an HTML 404 page or
a line of prose saved as `.sch` still gives `ret=1 err='' objs=0` on a blank page; only 0-byte and
whitespace-only files ever reach `NORECORDS`. Likewise a generator that prints a diagnostic banner
and **exits 0** produces `ret=1 err='' objs=0` with no warning at all, and `descend_symbol` into a
`.sym` containing prose gives `ret=1 err=''`. Counting only *recognised* tags — or counting
`default:` hits into `load_malformed` — is the missing piece. Note also that GENWARN and
`malformed>0` were ratified to return `1` with `descend_error` **empty**, so a scripted caller
cannot see a damaged load at all; only a human watching the status line can.
