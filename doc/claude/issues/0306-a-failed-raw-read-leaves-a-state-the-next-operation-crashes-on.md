# 0306 — a failed raw read leaves a state the next operation crashes on

**Status:** **FIXED** in `c6743aff` (2026-08-12, branch `fluid-editing`, unpushed). Both parts and
the leak. 63 checks in `tests/headless/test_raw_read_failure_0306.tcl` (registered in
`full_audit.sh`'s `nogui_tests`), 14 sabotage mutations, leak measured as a matched valgrind pair
(2,278,504 bytes → 0). Receipt: `doc/claude/batch_F/receipts/16-issue-0306-failed-raw-read.md`.
**CLOSED 2026-08-12** by the owner's ruling, with the Waves-menubar-cue eyeball **waived, not
performed** — see receipt §7 for what came out of trying to hand it over, including a *possible*
separate paint defect (the menubar word may never visibly turn Green even though the mirrored
`tctx::<win>_waves` variable does) that is intentionally **not filed**: new issue only if it
recurs.

Three things the fix found that this issue did not name, all recorded rather than folded in:
* `xschem raw clear <file>` and `xschem raw clear <file> <type>` are **two more crash doors** onto
  the same orphan (`extra_rawfile()`'s `what==3` by-name arms, whose `strcmp(rawfile, ...)` had no
  guard at all). Measured segfaulting pre-fix; fixed here, checks C18/C19.
* `read_dataset()` leaks the same ~250 KB `Raw` on four malformed-header aborts **and destroys the
  loaded database with it** — the same shape in a third function, and more reachable than this one.
  Filed as **issue 0316**, deliberately not fixed here.
* The probe `open()` still **hangs forever on a fifo**. Filed as **issue 0317**; fixing it makes
  this fix unfalsifiable (measured as sabotage SAB-11), so it needs its own change.

Two independent SIGSEGVs, both **PRE-EXISTING**, both measured in this tree at
`1afca8a2`. Below is the original filing, unchanged.
**Area:** `src/save.c` `table_read()` and `extra_rawfile()`'s non-spice dedup loop (part 1);
`src/scheduler.c` the `set raw_level` arm in `xschem_cmds_s` (part 2).
**Found:** 2026-08-09, during the adversarial review of the issue-0290 dispatch collapse
(`1afca8a2`). The review returned **zero** findings against that change; these two crashes fell out
of its refutations, i.e. they are things the review *tried and failed* to pin on 0290 and found
were already there.
**Related:** `doc/claude/issues/0290-raw_read-bypasses-the-non-spice-reader-dispatch.md` (FIXED),
`doc/claude/issues/0213-read-raw-ascii-point-overruns-its-buffer.md` (FIXED — the other
pre-existing C defect the same seam produced).
Numbered 0306, continuing the local sequence above 0285/0290/0295-0305 and well clear of
`github/open_pdk`, which is at 0263.

Both halves are the same shape, which is why they are one issue: **a raw read that fails leaves
`xctx->raw` in a state the very next operation dereferences without checking.** Part 1 leaves it
non-NULL but half-built; part 2 leaves it NULL. Neither failure is announced to the caller in a way
the caller acts on — both return 0 into Tcl and the script carries on to the next line.

> **Line numbers** below are from `1afca8a2`. Locate by symbol; the numbers are a convenience.

---

# Part 1 — `table_read()` allocates before it opens, and its error path does not free

## Mechanism

`table_read()` (`src/save.c:1833`) does its `open()`-probe, then **allocates**, then opens for real:

```c
  ufd = open(f, O_RDONLY);                            /* :1847  succeeds on a directory  */
  if(ufd < 0) goto err;
  count_lines_bytes(ufd, &lines, &bytes);
  close(ufd);

  xctx->raw = my_calloc(_ALLOC_ID_, 1, sizeof(Raw));  /* :1852  ALLOCATE                 */
  raw = xctx->raw;
  ...
  int_hash_init(&raw->table, HASHSIZE);               /* :1858  + 31627 * 8 bytes        */
  fd = my_fopen(f, fopen_read_mode);                  /* :1859  can still fail           */
  if(fd) {
    ... /* everything, including my_strdup2(&raw->rawfile, f), happens in here */
  }
  err:                                                /* :1958 */
  dbg(0, "table_read(): failed to open file %s for reading\n", f);
  return 0;                                           /* :1960  frees nothing            */
```

The two opens do not agree about what a readable file is. The bare `open(f, O_RDONLY)` at `:1847`
succeeds on a directory and on `/dev/null`; `my_fopen()` (`src/util.c:752`) rejects both:

```c
  if(!S_ISREG(buf.st_mode)) return NULL;   /* src/util.c:761 */
```

So for any path that `stat()`s as existing but is **not a regular file**, control reaches `:1852`,
allocates a `Raw` and a `HASHSIZE` hash table, then falls out of the `if(fd)` into `err:` and
returns 0 — leaving `xctx->raw` **non-NULL with `rawfile == NULL`**. A nonexistent path is safe:
`open()` fails at `:1847` and `goto err` runs before any allocation.

That orphan is invisible to the usual test — `sch_waves_loaded()` returns -1 for it, so
`xschem raw loaded` says -1 and a caller has no reason to suspect a database is there. The next
non-spice read walks into it. `extra_rawfile()` adopts whatever `xctx->raw` points at into the
registry:

```c
  /* src/save.c:1550 */
  if(xctx->raw && xctx->extra_raw_n == 0) {
    xctx->extra_raw_arr[xctx->extra_raw_n] = xctx->raw;
    xctx->extra_raw_n++;
  }
```

and then dedups the non-spice arm on filename **alone**, with no NULL guard:

```c
  /* src/save.c:1570, the non-spice (table/vcd) dedup loop */
  for(i = 0; i < xctx->extra_raw_n; i++) {
    if( !strcmp(xctx->extra_raw_arr[i]->rawfile, f)) break;
  }
```

`strcmp(NULL, f)` → SIGSEGV. The **spice** arm (`:1608-1613`) tests
`xctx->extra_raw_arr[i]->sim_type &&` first, and the orphan's `sim_type` is also NULL, so that loop
short-circuits and survives. Only the non-spice arm crashes.

## `vcd_read()` is not affected — and that asymmetry is the fix

`vcd_read()` has the same allocate-then-parse shape but ends with a single cleanup reached on both
paths (`src/vcd_read.c:850`):

```c
  done:
  ...
  if(!res && xctx->raw) free_rawfile(&xctx->raw, 0, 1);
  return res;
```

`table_read()` is the odd one out among the two non-spice readers. `raw_read()` (`src/save.c:1217`)
avoids the problem a different way — it calls `my_fopen()` **first** (`:1232`) and only allocates
inside `if(fd)` (`:1234`) — and its *content*-failure path is measured clean too (see below).

## Repro (measured, this tree, `1afca8a2`)

```sh
mkdir -p /tmp/i0306/adir
printf 'time a b\n0 0 1\n1 2 3\n2 4 5\n' > /tmp/i0306/good.tbl

cat > /tmp/i0306/p1.tcl <<'EOF'
puts "A: loaded before = [xschem raw loaded]"
puts "B: raw_read <dir> table -> [xschem raw_read /tmp/i0306/adir table]"
puts "C: loaded after  = [xschem raw loaded]"
flush stdout
puts "D: [xschem raw table_read /tmp/i0306/good.tbl]"
puts SURVIVED
EOF

./src/xschem --nogui --pipe -q --nolog --script /tmp/i0306/p1.tcl
```

Observed:

```
A: loaded before = -1
table_read(): failed to open file /tmp/i0306/adir for reading
B: raw_read <dir> table -> 0
C: loaded after  = -1
rename dir (null) to /tmp/xschem_emergencysave_untitled-13_gadgbdcdeg failed
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled-13_gadgbdcdeg

FATAL: signal 11
while editing: untitled-13
```

exit status 1. Note lines B and C: the command reported failure *and* `raw loaded` still says -1 —
there is no signal at the Tcl level that a half-built database is sitting in `xctx->raw`. (Run the
same script without line D and the process exits printing `free_rawfile(): clearing data`, which is
the orphan being torn down at shutdown — the only visible trace of it.)

Under valgrind the fault is exactly the unguarded `strcmp`:

```
==1827135== Invalid read of size 1
==1827135==    at 0x4850364: strcmp (vgpreload_memcheck-amd64-linux.so)
==1827135==    by 0x1DED0F: extra_rawfile (src/xschem)
==1827135==    by 0x1A1178: xschem_cmds_r.constprop.0 (src/xschem)
==1827135==    by 0x1B9662: xschem (src/xschem)
==1827135==  Address 0x0 is not stack'd, malloc'd or (recently) free'd
```

### Which spellings reach it — all four crash, measured

| command that orphans | crashes on the next `xschem raw table_read <good>` |
| --- | --- |
| `xschem table_read <dir>` (top-level verb, `xschem_cmds_t`) | yes |
| `xschem raw table_read <dir>` (`xschem_cmds_r`) | yes |
| `xschem raw read <dir> table` | yes |
| `xschem raw_read <dir> table` | yes — **new spelling, see the note below** |

Two failed `xschem raw table_read <dir>` in a row is the shortest form: the first orphans, the
second adopts and crashes.

### Which non-regular files

| path | outcome | why |
| --- | --- | --- |
| a directory | **orphan → SIGSEGV** | `open()` ok, `S_ISREG` false |
| `/dev/null` | **orphan → SIGSEGV** | same |
| a fifo with no writer | **HANGS** at `open()` (`:1847`) | blocks before `my_fopen()` is ever reached — never orphans |
| a nonexistent path | safe | `open()` fails, `goto err` precedes the `my_calloc` |
| a regular file that is not a table | safe | `my_fopen()` succeeds; `table_read()` builds a real database |
| a regular file read as **spice** and rejected on content | safe | `raw_read()`'s content-failure path is measured non-orphaning — `read_dataset()`→`extra_rawfile()` already freed it (`src/save.c:1269`) |

## The leak

Every failed `table_read()` on a non-regular path leaks the whole `Raw` plus its hash table. With a
good database already loaded (so `extra_raw_n > 0`), the failure takes `extra_rawfile()`'s restore
branch — `xctx->raw = save;` at `src/save.c:1590` — which overwrites the only pointer to the
orphan. That is the leak path, and it does not crash, because the dedup loop then only ever sees
the good entry.

```tcl
# /tmp/i0306/leak10.tcl
xschem raw table_read /tmp/i0306/good.tbl
for {set i 0} {$i < 10} {incr i} { xschem raw table_read /tmp/i0306/adir }
```

```
$ valgrind --leak-check=full ./src/xschem --nogui --pipe -q --nolog --script /tmp/i0306/leak10.tcl

==1827328== 2,278,504 (1,360 direct, 2,277,144 indirect) bytes in 10 blocks are definitely lost
==1827328==    at 0x484D953: calloc
==1827328==    by 0x1DA31D: my_calloc
==1827328==    by 0x1DBCFA: table_read
==1827328==    by 0x1E041B: read_rawfile_by_type
==1827328==    by 0x1DEF25: extra_rawfile
==1827328== LEAK SUMMARY:
==1827328==    definitely lost: 1,360 bytes in 10 blocks
==1827328==    indirectly lost: 2,277,144 bytes in 9 blocks
```

The same script with the loop removed leaks `0 bytes in 0 blocks`, so the whole figure is
attributable. One failed read costs **136 direct + 253,016 indirect** bytes (measured separately at
N=1); 253,016 is `HASHSIZE` (31627, `src/xschem.h:343`) × `sizeof(Int_hashentry *)`. valgrind
reports 10 direct blocks but only 9 indirect ones at N=10 — one hash table lands in the 5.6 MB
`possibly lost` bucket rather than `indirectly lost`; the per-read cost from the N=1 run is the
number to trust.

## Reachability — stated flat, not talked up

**No ordinary editing operation feeds `table_read()` a directory.** Every shipped generator of
these commands — `open_sub_schematic`, `hi_descend_newwin`, `load_raw`, the ASE plot path
(`src/ase.tcl:1469-1487`), the waveform viewer (`src/wave_viewer.tcl:3007, 3216`) — passes a path
that was just read successfully as a regular file, or a path the user picked out of a file dialog.
Triggering this needs a path that `stat()`s as **existing but not regular**, which means a
user-typed or scripted path.

The one shipped route that does not validate its path first is `graph_fill_listbox`
(`src/xschem.tcl:4721`), whose line 4737 is `set res [xschem raw table_read $rawfile $sim_type]`
where `$rawfile` is the graph rect's `rawfile=` **attribute** after `subst` — a schematic-authored
string, not a checked file. A schematic whose graph names a directory (or a stale path that a
directory later occupies) reaches it from the graph dialog with no typing at all. That is a code
path, not a measured repro — it was not exercised here, and it still needs the attribute to name a
non-regular existing path.

So: a real crash, a real 250 KB-per-attempt leak, on an input that is easy to produce deliberately
and hard to produce by accident. Filed at that weight.

## ⚠ Note on `1afca8a2` — a new spelling, not a new bug

Commit `1afca8a2` (the 0290 dispatch collapse) added `xschem raw_read <f> table` to the list of
commands that can reach `table_read()`: before it, that arm's private chain knew only `vcd`, so
`table` fell through to `raw_read()`, which opens before allocating and therefore cannot orphan.
The other three spellings in the table above went through `extra_rawfile()`'s non-spice arm to
`table_read()` before `1afca8a2` exactly as they do after. The defect is unchanged and older; the
new spelling is a fourth door onto it, recorded here so nobody bisects to `1afca8a2` and concludes
it introduced the crash.

## Fix, when someone takes it

One line, the one `vcd_read()` already has, before `table_read()`'s `return 0` at `src/save.c:1960`:

```c
  err:
  dbg(0, "table_read(): failed to open file %s for reading\n", f);
  if(xctx->raw) free_rawfile(&xctx->raw, 0, 1);
  return 0;
```

That restores the invariant the readers are declared against. `src/xschem.h:2251-2253`, on
`vcd_read()`, spells the entry half out — *"Same contract as `table_read()`: `xctx->raw` must be
NULL on entry"* — and `table_read()` itself enforces it at `src/save.c:1842` by refusing when
`xctx->raw` is set. A reader that returns 0 having left `xctx->raw` non-NULL has broken the entry
condition of the *next* call, which is precisely what the crash is. One `free_rawfile()` kills both
the crash and the leak, because the orphan is what both are made of.

Two things worth doing alongside, neither required for the fix:

* **Guard `extra_rawfile()`'s non-spice dedup loop** (`src/save.c:1570`) the way the spice loop
  already is, so a NULL `rawfile` skips rather than crashes. Defence in depth: the crash is a
  *consequence* of the orphan, and any future reader with the same slip re-arms it.
* **Make the two opens agree.** `table_read()` probes with a bare `open()` and reads with
  `my_fopen()`; the disagreement about `S_ISREG` is the whole gap. Probing with `my_fopen()` (or
  `fstat`-ing `ufd` for `S_ISREG` before `count_lines_bytes`) closes it at the source and also
  fixes the fifo hang, which no amount of freeing addresses.

A test belongs in `tests/headless/test_raw_read_dispatch.tcl` (the file 0290 created): read a
directory and `/dev/null` through each of the four spellings, assert `xschem raw loaded` is -1, then
assert a following good `xschem raw table_read` returns 1 and the process is still alive.

---

# Part 2 — `xschem set raw_level <n>` dereferences `xctx->raw` with no NULL guard

## Mechanism

The setter, in `xschem_cmds_s` (`src/scheduler.c:11412`):

```c
  else if(!strcmp(argv[2], "raw_level")) { /* set hierarchy level loaded raw file refers to */
    int n = atoi(argv[3]);
    if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
    if(n >= 0 && n <= xctx->currsch) {
      xctx->raw->level = atoi(argv[3]);                                    /* :11416  NO GUARD */
      my_strdup2(_ALLOC_ID_, &xctx->raw->schname, xctx->sch[xctx->raw->level]);
      Tcl_SetResult(interp, my_itoa(n), TCL_VOLATILE);
    } else {
      Tcl_SetResult(interp, "-1", TCL_VOLATILE);
    }
  }
```

The range check is on `n`, not on `xctx->raw`. The matching **getter** in `xschem_cmds_r`
(`src/scheduler.c:4622`) *is* guarded —

```c
  if(!strcmp(argv[2], "raw_level")) {
    int ret = -1;
    if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
    if(xctx->raw) ret = xctx->raw->level;      /* :4625 */
    Tcl_SetResult(interp, my_itoa(ret), TCL_VOLATILE);
  }
```

— so the pair is asymmetric: reading a level with no database loaded returns -1, writing one
segfaults.

## The callers make it a live path, not a hypothetical

Both shipped carry-over procs call the setter on the line **immediately after** the read, with no
test of the read's result. `open_sub_schematic` (proc at `src/xschem.tcl:5660`):

```tcl
    if { $rawfile ne {}} {
      if {$sim_type eq {op}} {
        xschem annotate_op $rawfile
      } else {
        xschem raw_read $rawfile $sim_type        ;# src/xschem.tcl:5705
      }
      xschem set raw_level $raw_level             ;# src/xschem.tcl:5707
    }
```

`hi_descend_newwin` (proc at `src/xschem.tcl:5918`) has the same two lines folded onto one:

```tcl
  if {$rawfile ne {}} {
    if {$sim_type eq {op}} { xschem annotate_op $rawfile } else { xschem raw_read $rawfile $sim_type }
    xschem set raw_level $raw_level               ;# src/xschem.tcl:5959
  }
```

These are the only two `xschem set raw_level` call sites in the shipped tree (the others are in
`tests/headless/test_wave_sigbrowser_i11.tcl` and `..._i12.tcl`, and in worktree copies).

And the `raw_read` arm they call **clears the registry before it reads** (`src/scheduler.c`, the
`raw_read` arm in `xschem_cmds_r`):

```c
      if(argc > 2) {
        double sweep1 = -1.0, sweep2 = -1.0;
        tcleval("array unset ngspice::ngspice_data");
        extra_rawfile(3, NULL, NULL, -1.0, -1.0);      /* <- clear-all: sets xctx->raw = NULL */
        ...
        res = read_rawfile_by_type(f, &xctx->raw, argc > 3 ? argv[3] : NULL, 0, sweep1, sweep2);
```

`extra_rawfile()`'s clear-all branch sets `xctx->raw = NULL` unconditionally (`src/save.c:1700`).
So **any** failure of that read — for any reason — leaves `xctx->raw == NULL` and the next Tcl line
dereferences it. In the new-window case `xctx->raw` is NULL to begin with (fresh context) and the
failed read simply never sets it; either way the setter is handed NULL.

The 0290 `table` misroute was one way to make that read fail. It is fixed. **Every other way still
works:** a rawfile deleted or moved since it was loaded, a truncated or malformed one, a wrong
declared type, a permissions change.

## Repro (measured, this tree, `1afca8a2`)

Three variants, all `FATAL: signal 11`, exit status 1. These are literally the two lines the two
procs above emit.

**(a) the rawfile is gone**

```tcl
puts "raw_read rc = [xschem raw_read /tmp/i0306/gone.raw tran]"
puts "loaded after = [xschem raw loaded]"
flush stdout
xschem set raw_level 0
puts SURVIVED
```

```
raw_read(): failed to open file /tmp/i0306/gone.raw for reading
raw_read rc = 0
loaded after = -1
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled-13_faebcedgda

FATAL: signal 11
```

**(b) wrong declared type on a real regular file** — `xschem raw_read /tmp/i0306/good.tbl tran`
(a table declared `tran`, which 0290 deliberately requires to FAIL rather than be content-sniffed),
then `xschem set raw_level 0`:

```
raw_read(): no useful data found
rc=0
FATAL: signal 11
```

**(c) with a database already loaded** — proving the clear-then-fail is what empties it:

```
load table: 1
loaded=0
free_rawfile(): clearing data                      <- the loaded database is destroyed here
raw_read(): failed to open file /tmp/i0306/gone.raw for reading
raw_read of a missing file: 0
loaded now=-1
FATAL: signal 11
```

Under valgrind:

```
==1828251== Invalid write of size 4
==1828251==    at 0x1AB0A8: xschem_cmds_s.constprop.0 (src/xschem)
==1828251==    by 0x1B9642: xschem (src/xschem)
```

— the write is `xctx->raw->level = ...`, `level` being an `int`.

The `op` branch of the same `if` is no better: `xschem annotate_op <missing>` also leaves
`xctx->raw` NULL and the following `xschem set raw_level 0` segfaults identically.

## Fix, when someone takes it

Guard the arm, matching the getter at `:4625`, and report the refusal the same way the
out-of-range case already does:

```c
  else if(!strcmp(argv[2], "raw_level")) {
    int n = atoi(argv[3]);
    if(!xctx) {Tcl_SetResult(interp, not_avail, TCL_STATIC); return TCL_ERROR;}
    if(xctx->raw && n >= 0 && n <= xctx->currsch) {
      ...
    } else {
      Tcl_SetResult(interp, "-1", TCL_VOLATILE);
    }
  }
```

`-1` is already this arm's "did not take" answer, so no caller learns a new convention.

That is the crash fix and it is sufficient. Separately worth considering — it is a behaviour
change, so it should be a decision, not a drive-by: the two carry-over procs *silently* destroy the
source window's database when the re-read fails (`extra_rawfile(3, ...)` runs unconditionally,
before the read that may fail), which is the same data-loss shape 0290 was about, arrived at from a
different direction. Making them test the `xschem raw_read` result and report through `ciw_echo`
would tell the user their waveforms are gone instead of leaving them to notice.

A test belongs alongside 0290's, in `tests/headless/test_raw_read_dispatch.tcl`: after each failing
read, assert `xschem set raw_level 0` returns `-1` and the process survives.

---

# Not in scope of 0290

0290 was one defect with one shape: a `(file, type) → reader` dispatch written down twice, where
the second copy had drifted. Its fix deleted the second copy. Neither crash here is that. Part 1 is
an error path in one reader that forgets to free — `table_read()` would have had it if the dispatch
had never been duplicated, and `vcd_read()`, which was written against the same contract in the
same subsystem, does not. Part 2 is a missing NULL guard in a `set` verb on the other side of the
scheduler, which fires on *every* read failure and has nothing to do with which reader ran.

Folding them in would have made 0290 "assorted things wrong near raw files", which is the kind of
issue that gets fixed in the wrong order and closed while a third of it is still open. They are
filed together because they share a lesson — **a failed read has to leave the editor in the state
it found it**, and neither of these does — and separately from 0290 because the fix that closes
0290 does not touch either one. Recording the review's three refutations as one issue rather than
three keeps that lesson in one place; the third finding, unrelated to this theme, is not here.

Neither was fixed as part of the review, on purpose. The review's job was to say whether
`1afca8a2` was sound; it is. Changing `table_read()`'s error path or the `set raw_level` arm in the
same breath would have put unreviewed edits under a green audit that was measured against a
different change.
