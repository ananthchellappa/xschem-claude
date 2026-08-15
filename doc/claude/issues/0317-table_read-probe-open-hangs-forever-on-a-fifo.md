# 0317 — `table_read()`'s probe `open()` hangs the editor forever on a fifo

**Status:** OPEN. Documentation only — nothing fixed, no test written (a hanging check would kill
the suite).
**Area:** `src/save.c`, `table_read()` — the bare `open(f, O_RDONLY)` probe that precedes
`count_lines_bytes()`.
**Found:** recorded in
`doc/claude/issues/0306-a-failed-raw-read-leaves-a-state-the-next-operation-crashes-on.md`'s
"which non-regular files" table as a measured behaviour; split out into its own issue on 2026-08-12
when 0306 was fixed, because 0306's fix deliberately does **not** address it and both phase-3
reviewers asked for it to be filed rather than left as a footnote.

---

## Mechanism

`table_read()` sizes the file before it reads it:

```c
  /* quick inspect file and get upper bound of number of data lines */
  ufd = open(f, O_RDONLY);
  if(ufd < 0) goto err;
  count_lines_bytes(ufd, &lines, &bytes);
  close(ufd);
```

`open(fifo, O_RDONLY)` **blocks until a writer opens the other end**. There is no `O_NONBLOCK`, no
timeout, and nothing above it rejects a fifo — `my_fopen()` would (`!S_ISREG(buf.st_mode)` →
`NULL`), but `my_fopen()` is not called until after this probe. The editor is single-threaded and
this runs on the Tk main loop, so the whole application freezes: no redraw, no menu, no way to
cancel. Only a signal ends it.

## Why 0306's fix does not cover it

0306 was two SIGSEGVs caused by a *half-built database* surviving a failed read. Its fix frees that
database at `table_read()`'s `err:` label. A fifo never reaches `err:` — it never reaches the
allocation either. Freeing cannot address a hang.

0306's own "Fix, when someone takes it" lists **"make the two opens agree"** (probe with
`my_fopen()`, or `fstat` the probe fd for `S_ISREG` before `count_lines_bytes`) as an optional
extra, and notes it "also fixes the fifo hang". That option was **declined** when 0306 was fixed,
for a reason worth recording: it makes the orphan impossible to create, which makes 0306's own fix
unfalsifiable — measured as sabotage SAB-11 in
`tests/headless/test_raw_read_failure_0306.tcl`, where it turns nine checks green with the
`free_rawfile()` deleted. 0306 chose the free (which restores the reader contract every other
reader honours) and left this for a change that can be tested on its own terms.

## Repro

```sh
mkfifo /tmp/i0317/afifo
./src/xschem --nogui --pipe -q --nolog --script - <<'EOF'
xschem raw table_read /tmp/i0317/afifo
puts SURVIVED
EOF
```

Hangs indefinitely at ~0% CPU. `SURVIVED` never prints. **Do not put this in a suite** — it
consumes the whole per-test budget and scores the row TIMEOUT.

## Reachability

The same reachability argument as 0306 part 1, and no better: it needs a path that `stat()`s as
existing but is not a regular file, which means typed, scripted, or carried in a schematic's
`rawfile=` graph attribute (`graph_fill_listbox`, `src/xschem.tcl`, which is the one shipped route
that hands `table_read()` an unvalidated attribute). A fifo is a less likely accident than a
directory. It is filed at that weight: low probability, but the consequence is worse than a crash —
a crash at least tells the user what happened and leaves an emergency save.

`vcd_read()` should be checked for the same shape when this is taken; so should any other reader
that sizes a file before opening it properly.

## Fix, when someone takes it

Probe with `my_fopen()`, which already enforces `S_ISREG`:

```c
  { FILE *pf = my_fopen(f, fopen_read_mode);
    if(!pf) goto err;
    fclose(pf); }
  ufd = open(f, O_RDONLY);
```

or `fstat(ufd, &sb)` and reject `!S_ISREG(sb.st_mode)` before `count_lines_bytes()`. Either closes
the gap at its source and makes the two opens agree about what a readable file is.

**Whoever does this must not treat 0306's checks as their safety net.** SAB-11 is exactly this
change, and it reds only the nine `C*f` ids (the ones that assert the orphan was *built*) — every
crash and registry id stays green. That is by design: those nine exist so this change is visible.
Expect them to red, confirm the reason is "the orphan is never created" and not "the free was lost",
and rewrite them rather than deleting them.
