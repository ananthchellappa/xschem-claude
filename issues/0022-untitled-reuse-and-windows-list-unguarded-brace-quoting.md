# Issue 0022 — untitled-reuse load and `xschem windows` wrap filenames in braces without a `tcl_braceable` guard

**Opened:** 2026-06-22
**Status:** RESOLVED 2026-06-22 (branch `fluid-editing`) **as hardening** — see §5.
Two defensive fixes applied: the reuse path now guards with `tcl_braceable(f)` (matching
the sibling logging code) and falls through to `new_schematic` otherwise; `xschem windows`
now builds its result with `Tcl_NewListObj`/`Tcl_ListObjAppendElement` instead of
hand-concatenating braces. **Not independently reachable** as a user-facing bug — braced
*paths* are unsupported codebase-wide (see §5), so there is no end-to-end RED. No test
added (a braced-path test would assert unsupported behavior).
**Affects:** `is_pristine_untitled` reuse path in `xschem load_new_window` and the new
`xschem windows` subcommand (`src/scheduler.c`).
**Severity:** low — only triggers on schematic paths containing `{`, `}` or `\`; corrupts
the generated Tcl command for those paths.
**Branch:** `fluid-editing`. See [[untitled-reuse]], [[multi-window-detach]].

---

## 1. Symptom

Opening a file whose path contains a brace or backslash on a fresh untitled buffer loads the
wrong path or silently fails; `xschem windows` returns a malformed Tcl list when an open
schematic's name contains a brace, so callers (`win_entry`, the test `lmap`) misparse it.

## 2. Root cause

The reuse branch builds the load command by raw brace concatenation, with **no**
`tcl_braceable(f)` check:

```c
/* src/scheduler.c:3715 and :3733 */
if(is_pristine_untitled()) tclvareval("xschem load {", f, "}", NULL);
```

A `f` containing `}` (e.g. `/home/user/proj{v2}/top.sch`) yields
`xschem load {/home/user/proj{v2}/top.sch}` — the early `}` truncates the path. The sibling
logging code in the same function guards the identical pattern with `tcl_braceable(f)`
(e.g. `if(tcl_braceable(f)) log_action("xschem load_new_window {%s}", f);`), so the guard
already exists in-tree and was simply not applied here.

The new `xschem windows` subcommand has the same class of bug for the schematic name:

```c
/* src/scheduler.c (xschem_cmds_w, the "windows" branch) */
Tcl_AppendResult(interp, "{", wp, " {", tp, "} ", tp, " ", xwin, " {", nm, "}} ", NULL);
```

`nm` is the user-controlled `current_name`; an unbalanced brace in it corrupts the list
element boundary. (`wp`/`tp`/`xwin` are `.xN`-style and safe.)

## 3. Fix

Before the reuse `tclvareval`, guard with `tcl_braceable(f)` and fall through to the
`new_schematic(...)` path (which does not brace-quote) when it is not braceable — or use a
quoting helper. For `xschem windows`, build the result with `Tcl_Obj` list APIs
(`Tcl_NewListObj` / `Tcl_ListObjAppendElement`) so element quoting is correct regardless of
the name, rather than hand-concatenating braces.

## 4. Tests

None added. A braced-path load cannot succeed end-to-end (see §5), so a test would assert
behavior the codebase does not support. The two fixes are verified by inspection against the
codebase's own `tcl_braceable` convention and the Tcl list API.

## 5. Why this is hardening, not a reachable bug

While fixing the two flagged spots, the leading-`~/` expansion in the same `load_new_window`
path was found to brace-wrap the path into a Tcl `regsub` (`src/scheduler.c:3695`), and
`abs_sym_path` (`src/actions.c:388`) wraps it into `abs_sym_path {%s} {%s}`. `update_recent_file`
and `log_action` do the same. So a path containing a Tcl brace is already corrupted upstream
before it ever reaches the reuse `tclvareval` or `xschem windows` — **braced filenames are
unsupported throughout the path-handling chain**, not just at the two reviewed spots. Names
with spaces are fine (the old hand-concatenation brace-wrapped `nm`, which protects spaces);
only braces break, and braces are unsupported anyway.

Making braced paths work would require routing every path through a non-Tcl-string API
(`Tcl_Obj`/`my_*` C-string calls) across the whole chain — a large, invasive, higher-risk
change, out of scope for this review. The two fixes here are kept as low-risk
internal-consistency hardening: the reuse path no longer builds a corrupt `xschem load {...}`
command (it falls through to the C-string `new_schematic`), and `xschem windows` is now
structurally robust by construction.
