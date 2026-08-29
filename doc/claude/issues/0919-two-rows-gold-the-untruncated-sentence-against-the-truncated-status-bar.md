# 0919 — two acceptance rows gold a whole sentence against a sink that
#         truncates it, so a checkout ~50 characters deeper false-reds them

STATUS: OPEN — NOT failing today, and that is the problem with it.
FOUND BY: item B2's adversary pass, 2026-08-28, the hard way: a mirror of the
          suite staged under a deep scratch path reported H6 and H13 red on a
          tree that was entirely correct, both showing
          `…There is no results file at…` with the tail eaten. Re-mirroring at a
          short path gave 15/15.
RELATED: [0911](0911-on-a-descended-sheet-with-no-ase-l-session-the-chord-never-repairs.md)
         (the suite this is in), [0639](0639-annot-msg-types-clause-is-unbudgeted-and-overflows-the-255-char-statusmsg-seam.md)
         (the 255-char seam itself), 0886.

---

## 1. The measurement

Rows **H6** and **H13** of `tests/headless/test_annot_hier_0911.tcl` read the
status line with `xschem get statusmsg` and compare it against a complete
sentence:

```
Showing device operating-point values on the schematic. There is no results
file at <netlist_dir>/top.raw yet. Run a simulation first.
```

But that sink is **capped**. `cadence::_annot_say` sends the CIW the sentence
whole and the held status line the same sentence through `cadence::_annot_fit`
(`utils/annot_mode.tcl:724-737`), which elides anything over 255 bytes down to
252 plus `...` — because the C side stores it in `statusmsg_text[256]`. That is
documented, deliberate and long-standing (issue 0639, ruling recorded at 0886).

At the canonical checkout path the H6 sentence is **205 characters**, so there
are **50 characters of headroom**. A worktree, a differently-named clone, or a
`$HOME` a little longer eats that, and the two rows go red for a reason that has
nothing whatever to do with the annotator.

## 2. Why the obvious fix is wrong

Running the *expected* string through `cadence::_annot_fit` before comparing
makes the rows green everywhere — and **destroys them**. Both rows exist to prove
the refusal names `top.raw` and not `sub.raw`. Truncation eats the tail of the
sentence, which is where the filename lives. So on a deep path the "fixed" row
would compare `…There is no results file at /very/long/path/nd/h6/to...` against
itself and pass whichever file the code chose. A row that cannot see the defect
it was written for is worse than a row that false-reds: the false red gets
investigated.

That is why this is filed rather than patched in passing.

## 3. What would actually close it

Any of these; the first is probably right:

* **Assert on the CIW sink instead.** It gets the sentence whole, by design, and
  it is the sink the PLAIN ENGLISH ruling is really about. The status line's job
  is to be a glanceable echo, not the record.
* **Split the assertion**: gold the fitted status line for shape, and assert the
  *path* separately against the unfitted sentence.
* **Pin the fixture path length** so the suite's scratch prefix cannot grow —
  brittle in a different way, and it does not help the two rows say anything they
  do not say now.

## 4. The general form, which is the part worth keeping

**Any row that golds a whole minted sentence against `xschem get statusmsg` is
length-sensitive, and the sensitivity is invisible until someone moves the
checkout.** The annotation surface mints long sentences with absolute paths in
them by design; several suites gold them. This issue names the two rows that were
measured, not the only two that could be affected — a sweep of
`grep -l 'get statusmsg' tests/headless/*.tcl` against
`cadence::_annot_fit`'s 255-byte cap would find the rest.
