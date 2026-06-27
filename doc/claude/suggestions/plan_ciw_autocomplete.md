# Plan — CIW TAB autocomplete

**Status:** PROPOSED. **Branch:** `feature/autocomplete`.
**Spec:** `doc/claude/specs/ciw_autocomplete.md`. **Touches:** `src/ciw.tcl` (the proc + the
binding), `src/Makefile.in` + `src/Makefile` (generate & install the subcommand
list), `tests/headless/test_ciw_autocomplete.tcl` (new).

## Goal

Add readline/bash-style `<Tab>` completion to the CIW command entry `.ciw.c.e`,
completing the token under the cursor against: Tcl commands (first token), the
`xschem` subcommand list (second token after `xschem`), `$`-variables, and file
paths (fallback). Ambiguous matches extend to the longest common prefix and, if
that adds nothing, list candidates in the upper log pane. No new widgets.

## The shape (decided from the code as it is now)

`.ciw.c.e` is a `text` widget; bindings there already end in `break` to beat the
Text class bindings (`ciw.tcl:71-77`). The upper pane append helper `ciw_echo
{line {tag}}` (`ciw.tcl:95`) is the listing surface. History globals
(`::ciw_history`, `ciw_exec`) make good fixtures for the tests. The `xschem`
subcommand vocabulary is **not** introspectable — it must come from a generated,
shipped data file (spec "the one real design decision"). `XSCHEM_SHAREDIR`
resolves to `src/` when running from the source tree and to the install share dir
otherwise, so a file generated into `src/` and listed for install works in both.

## Phasing

- **P1 — command/variable completion (the headline).** Subcommand list generation
  + the `ciw_complete` proc with sources: `$var`, `xschem <subcommand>`,
  first-token Tcl command, and (as the fallback) file path. This is ~90% of the
  value and is self-contained.
- **P2 — argument-aware completion (later, optional).** C-var names for
  `set`/`get`, layer/instance/net names, sub-subcommand trees. Slots in ahead of
  the path fallback in the same position-dispatch. Not in this plan's steps.

Everything below is P1.

## Steps

### 1. Generate the subcommand list (build) — inert by itself

Add a rule to `src/Makefile.in` (then regenerate `Makefile` via `./configure`, or
mirror the rule into `src/Makefile` directly for a quick local build — the repo's
canonical path is the `.in`):

```make
xschem_subcommands.txt: scheduler.c
	grep -oE 'strcmp\(argv\[1\], *"[A-Za-z0-9_]+"' $< \
	  | sed -E 's/.*"([A-Za-z0-9_]+)"/\1/' | sort -u > $@
```

- Add `xschem_subcommands.txt` to the build's default target dependencies so a
  bare `make` produces it, and to the **install file list** (the brace-list at
  `Makefile.in:14-21`, where `actions.csv` / `keybindings.csv` live) so
  `make install` ships it to `XSCHEM_SHAREDIR`.
- Sanity after building: `wc -l src/xschem_subcommands.txt` ≈ 267; it contains
  `load`, `netlist`, `save`, `add_graph`.
- Caveat to verify, not assume: the grep pattern must match the actual source
  spacing. `scheduler.c` uses both `strcmp(argv[1], "x")` and (line 1726)
  `strcmp(argv[2], "help")` for sub-subcommands — we want **argv[1] only**, so the
  pattern is anchored on `argv[1]`. Confirm the count matches the
  `grep -oP 'strcmp\(argv\[1\],\s*"\K[^"]+'` reference (267) before wiring it in.

### 2. Load the list lazily in `ciw.tcl`

A global, populated on first Tab (not at source time — keeps startup untouched and
tolerates a missing file):

```tcl
set ::ciw_subcommands {}        ;# filled on first completion
proc ciw_load_subcommands {} {
  if {[llength $::ciw_subcommands]} return
  global XSCHEM_SHAREDIR
  set f [file join $XSCHEM_SHAREDIR xschem_subcommands.txt]
  if {[catch {open $f r} fh]} return          ;# missing file -> stays empty
  set ::ciw_subcommands [split [string trim [read $fh]] \n]
  close $fh
}
```

Graceful-degradation requirement: a missing/empty file must leave the other
sources fully working (no error on Tab).

### 3. The `ciw_complete` proc (core)

Single proc in `ciw.tcl`. Skeleton (real code matches surrounding comment density):

```tcl
proc ciw_complete {} {
  set w .ciw.c.e
  set line [$w get 1.0 insert]            ;# start-of-input to cursor
  set toks [regexp -all -inline {\S+} $line]
  set trailing [regexp {\s$} $line]       ;# cursor after a space => new token
  set idx  [expr {$trailing ? [llength $toks] : [llength $toks]-1}]
  set tok  [expr {$trailing ? {} : [lindex $toks end]}]

  set cands [ciw_candidates $toks $idx $tok]   ;# source dispatch, below
  if {![llength $cands]} { bell; return }

  if {[llength $cands] == 1} {
    ciw_insert_completion $tok [lindex $cands 0]
  } else {
    set lcp [ciw_longest_common_prefix $cands]
    if {[string length $lcp] > [string length $tok]} {
      ciw_insert_completion $tok $lcp        ;# advance, no trailing space
    } else {
      ciw_echo [join [lsort $cands] "  "] result    ;# list in upper pane
    }
  }
}
```

Source dispatch `ciw_candidates {toks idx tok}` — cheapest/most-specific first
(mirrors spec "by token position"):

1. `tok` starts with `$` → strip `$`, `info globals <rest>*`, re-prepend `$` on
   each candidate.
2. `idx == 1 && [lindex $toks 0] eq "xschem"` → `ciw_load_subcommands`; filter
   `::ciw_subcommands` by `[string match ${tok}* $_]`.
3. `idx == 0` → `info commands ${tok}*` (procs + builtins, includes `xschem`).
4. else → path: `glob -nocomplain -- ${tok}*` with `~` expansion; mark dirs.

Helpers:
- `ciw_longest_common_prefix {list}` — standard char-by-char shrink.
- `ciw_insert_completion {tok full}` — delete the last `[string length $tok]`
  chars before `insert`, insert `$full`. Single-candidate non-dir gets a trailing
  space; a directory candidate gets a trailing `/` and **no** space; LCP insertion
  gets neither. Compute the delete range as `"insert - N chars"` so multi-token
  lines stay intact.

Edge cases to handle explicitly (each is a likely bug, worth a test or a comment):
- empty entry + Tab → `idx 0`, `tok ""` → lists all commands (large; acceptable,
  it is what a shell does).
- `tok` containing a path with spaces — first cut splits on whitespace only;
  document that brace/quote-aware tokenising is out of scope (paths with spaces
  won't complete). Don't silently half-handle it.
- candidate with shell-special chars in path completion — insert literally; no
  quoting (out of scope, note it).

### 4. Bind it

In `ciw_create`, alongside the other `.ciw.c.e` binds:

```tcl
bind .ciw.c.e <Tab> {ciw_complete; break}
```

`break` is load-bearing (suppresses focus traversal). Place it with the existing
binds (`ciw.tcl:71-77`) so the grouping reads as one set.

### 5. Tests

New `tests/headless/test_ciw_autocomplete.tcl`, same harness shape as
`test_ciw.tcl` (X + `--pipe`, `check {name ok}` accumulating `::fails`). Drive
`ciw_complete` directly by setting entry text and `insert`, then assert. Cover
AC1–AC8 from the spec. Helper for each case:

```tcl
proc set_entry {s} { .ciw.c.e delete 1.0 end; .ciw.c.e insert end $s }
# AC1
set_entry "xschem loa"; ciw_complete
check "unique completes to 'xschem load '" \
  [expr {[string trim [.ciw.c.e get 1.0 end]] eq "xschem load"}]
```

Add the case to `tests/headless/cases.txt` if that's the driver (check how
`test_ciw.tcl` is registered there). Keep only discriminating checks — no
asserting Tk internals that pass regardless of the feature.

## Verification

- `make` produces `src/xschem_subcommands.txt` (~267 lines, includes `load`).
- Build clean; `make install` to a `DESTDIR` shows the file in the share dir.
- `test_ciw_autocomplete.tcl`: AC1–AC8 green under X.
- Existing `test_ciw.tcl` still green (no regression to the entry's other binds —
  Return/Up/Down/Ctrl-BackSpace).
- Manual: path completion (`xschem load /tmp/<Tab>` descends, `~/<Tab>` expands);
  Tab does not steal focus out of the entry.

## Rules / guardrails

- One proc family in `ciw.tcl`, one binding, one generated data file, one make
  rule, one test file. No C changes in P1 — the dispatcher is untouched; the only
  new coupling to `scheduler.c` is the generated list, which is regenerated, never
  hand-edited.
- Edit `Makefile.in`, not the generated `Makefile` (the "DO NOT EDIT" header) —
  regenerate via `./configure`. A local hand-mirror into `Makefile` is fine for
  iterating but the `.in` change is the deliverable.
- Match `ciw.tcl`'s comment density and the `break`-everywhere binding idiom.
- Graceful degradation is a requirement, not a nicety: missing data file → empty
  subcommand completion, everything else still works, no Tab error.
- Don't half-implement space-in-path / quoting; either do it or note it out of
  scope (this plan notes it out of scope).
