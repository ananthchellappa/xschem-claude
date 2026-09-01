# 0833 — two live `tclvareval` brace-concat splices outside 0831's list (and two recorded-not-chased)

Status: **verified PRESENT on the 0831 tree, NOT DRIVEN, NOT FIXED.**
Found by 0831's scout while enumerating the family; line text re-confirmed by
0831's Implement agent on the post-fix tree.
Severity: **unknown pending a drive** — both have the exact shape 0827 / 0829 /
0831 were filed for, and one is file-derived, but neither has been driven, so
this issue claims presence and shape only.
Family: 0812 / 0816 / 0817 / 0821+0822 / 0825 / 0827 / 0829 / 0831 / 0832.

> ⚠ **THE TITLE SAYS TWO. IT IS NOW EIGHT.** 0831's adversary pass found **six
> more** of the same family, in three files nobody had scanned — see **§2b**. The
> filename is left alone so existing references keep resolving; the count in it is
> wrong. Anyone extending `FN_PROCS` should read §2b first: **none of the three
> files is in `FN_FILES`**, so no proc-name extension reaches them.

## 1. `src/move.c:9135` — the placement-gesture toolbar splice (FILE-DERIVED)

```c
   if((xctx->ui_state & PLACE_SYMBOL)) {
     int n = xctx->sel_array[0].n;
     const char *f =  abs_sym_path((xctx->inst[n].ptr+ xctx->sym)->name, "");
     tclvareval("c_toolbar::add {",f, "}; c_toolbar::display", NULL);
   }
```

`(inst[].ptr + xctx->sym)->name` is the **symbol's own name**, i.e. `.sch`/`.sym`
data — the same class of source 0825 and 0827 closed. `}` in it closes the group
and `; c_toolbar::display` is already program text *after* the group, so the
payload does not even have to repair the tail. Fires at the end of a **placement
gesture** (a normal drop of a symbol), not at load.

⚠ **Not driven.** Reaching it needs a placed instance whose symbol name carries
the payload, and it sits behind `PLACE_SYMBOL` in `move_objects()`. Measure
before claiming severity.

## 2. `src/scheduler.c:7472` — `xschem list_hilights` (TWO unquoted words)

```c
      const char *sep = "{ }";
      ...
      else sep = argv[i];
      ...
      if(!all) tclvareval("join [lsort -decreasing -dictionary {", tclresult(), "}] ", sep, NULL);
```

Two problems in one line:

* the braced word is `tclresult()` straight out of `list_hilights(all)` — i.e.
  **`.sch`-derived net names**;
* `sep` is `argv[i]`, appended with **no quoting of any kind** — not even a brace
  group to escape out of.

And the whole thing is inside a `[lsort ...]` **command substitution**, so it
carries 0829's bracket problem too.

⚠ **Not driven.**

## 2b. ⚠ SIX MORE, FOUND BY 0831's ADVERSARY — the plot/print save-dialog pair

Three files carry the **same two splices each**, one file-derived and one
dialog-derived. Verified present by reading; **NOT driven**.

**(a) the schematic's OWN path spliced into the save dialog** — this is 0817
§Z.2's crafted-**filename** vector, not 0827's crafted-content one:

    src/draw.c:121
    src/psprint.c:1790
    src/svgdraw.c:1108

each of the shape

```c
   tclvareval("save_file_dialog {", ..., "} *.png INITIALLOADDIR {",
              <pwd_dir>, "/", get_cell(xctx->sch[xctx->currsch], 0), ".png}", NULL);
```

`get_cell(xctx->sch[xctx->currsch],0)` is the current schematic's own path — so
the attacker input is the **file name**, and the user only has to open the file
and hit the plot/print export.

**(b) the dialog's RETURNED filename spliced straight back**:

    src/draw.c:126
    src/psprint.c:1795
    src/svgdraw.c:1113

```c
   tclvareval("file dirname {", xctx->plotfile, "}", NULL);
```

**Why neither was driven.** Both need `has_x`, and the payload's second command
runs only *after* a **modal** save dialog returns — the same wall that stopped
`move.c:9135`. Driving them needs a stubbed `save_file_dialog` (the pattern
`test_create_instance.tcl` CI17 uses for `load_file_dialog`), which is a test to
write, not a reading to make.

**Why the 0831 guard does not see them.** `FN07`'s `FN_FILES` is
`{scheduler.c callback.c}` (plus the files 0827 added). `draw.c`, `psprint.c` and
`svgdraw.c` are **not scanned at all**, by FN07 or by SC09. Adding the proc names
`save_file_dialog` / `file dirname` to `FN_PROCS` changes nothing until those
three files are added to `FN_FILES` — and `{file dirname}` as a needle will also
match the *converted* `tcl_call("file dirname", …)` sites, so it needs the
`tclvareval("` anchor that FN07 already applies.

## 3. Recorded, deliberately NOT chased

* `src/hilight.c:1113-1120` — `win_regexec()`, three brace groups. Inside
  `#ifndef __unix__`; **not compiled on this platform.** A Windows build issue,
  not a Linux one.
* `src/xinit.c:3392` — `file copy {srcfile} {dstfile}`. Fires only on the
  first-run `USER_CONF_DIR` mkdir, from program-derived paths. Low reach.

## 4. Why FN07 does not cover these

`tests/headless/test_raw_read_dispatch.tcl` FN07 is a **name list scanned over
`FN_FILES`**, and `move.c` is not in `FN_FILES` at all; `list_hilights`'s splice
has no proc name to list (`join [lsort ...]`). Extending the name list would not
reach either. FN07's "⚠ WHAT IT DOES NOT COVER" note names both sites explicitly
so a green there can never be read as a sweep — see 0831 §6.

A **shape** scan (`tclvareval("<anything> {`) was considered for FN07 and
rejected, measured: it fires on ~10 further sites that are *not* defects,
including `scheduler.c:7828`/`:7849` which 0831 §5 records as already guarded
(`is_pristine_untitled() && tcl_braceable()`, issue 0022), the `ciw_echo`/`alert_`
message composers, `xinit.c:470` `lindex {`, and `save.c`'s `catch {`. That would
be a **standing red**, and CLAUDE.md is explicit that a standing red is a defect,
not furniture.

## 5. The fix, when someone takes it

Same mechanism as 0831, no new one:

```c
     tcl_call("c_toolbar::add", f, NULL, NULL);
     tcleval("c_toolbar::display");
```

and for `list_hilights`, copy `tclresult()` out first (it is `tclresult()`, so
`util.c:1122-1126` forbids handing it straight to `tcl_call()` — the
`token.c:150-154` rule), then

```c
     my_strdup2(_ALLOC_ID_, &nets, tclresult());
     tcl_call_mid("join [lsort -decreasing -dictionary", nets, "]", sep);  /* or build it Tcl-side */
```

— the second word `sep` is a *separator*, so the cleanest shape is probably a
tiny Tcl proc taking two data arguments, called with plain `tcl_call()`.

**Drive each one before fixing it**, and give each a driven negative row plus an
anti-hollow positive twin (issue 0828): the toolbar must still gain the symbol
after a placement, and `xschem list_hilights <sep>` must still join with the
caller's separator.

## 6. Why 0831 did not fix these

Ladder **L2** plus the brief's stop rule, identical to 0832's: 0831 was a
measured, rebuilt, fully-tiered unit over nine sites. Adding two undriven sites
late would have invalidated its receipt and buried two *unmeasured* claims inside
a report full of measured ones — which is exactly the 0817 §Z.4 failure the whole
family exists to stop repeating.

## 7. Claims discipline (0823)

A `.sch` is executable **by design**. Neither this issue nor 0831 may be written
up as "the injection family is closed" or "an untrusted `.sch` is safe to open".
