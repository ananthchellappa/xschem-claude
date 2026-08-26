# 0826 — test_wave_markers MX7b/MX7d go red when Tk KEY DELIVERY STALLS and the suite silently falls back to the shipping handler

Status: **OPEN — measured LIVE on a PRISTINE tree, NOT FIXED.**
⚠ **THE DIAGNOSIS IN §3 IS WRONG AND IS CORRECTED IN §3b.** The file was filed
against an unpinned *window geometry*; the verify pass then measured that the early
geometry rows are byte-identical between the green and red runs, and that the real
divergence is a **Tk key-delivery stall**. §3 is kept as filed, because being wrong
about a mechanism after correctly refusing to wave the red through is the useful
half of the record. The filename was corrected to match §3b.
Found by the 0821+0816+0817 crew's Implement agent, 2026-08-25, while diffing
the tier list against the Measure agent's baseline of the same day.
Severity: medium — it is a **standing red that is not a code defect**, i.e.
exactly the furniture CLAUDE.md says a real regression hides behind.

## 1. What happened

The Measure agent recorded `test_wave_markers` at **ALL PASS (983 checks)** on
`:99` at 21:25. Three hours later the same suite, same display, reports
**6 FAILED (977 passed)** — MX7b x3 and MX7d x3, all of them the pixel-scan
half of a marker drag:

```
  note: MX7b no anchor pixel in the scan (try 1..3)
  MARKER-TEST-STALL: MX7b could not arm a viewer marker drag (1) after 3 tries
    — ui_state=0 ctx=.x1.drw
FAIL: MX7b its anchor pixel was found -> {0} (exp {1})
FAIL: MX7b a press ABOVE the plot box still grabbed the anchor -> {0} (exp {1})
FAIL: MX7b the drag COMMITTED even though the pointer left the window -> {0} (exp {1})
FAIL: MX7d the label pixel was found -> {0} (exp {1})
FAIL: MX7d the press armed the LABEL drag -> {0} (exp {2})
FAIL: MX7d ldx/ldy changed even though the pointer ended over strip 1 -> {0} (exp {1})
```

## 2. It is NOT the crew's change — bisected four ways

| tree | result |
|---|---|
| HEAD C + HEAD Tcl (**pristine**, rebuilt) | **6 FAILED** |
| HEAD C + fixed `xschem.tcl` | 6 FAILED |
| fixed C + HEAD `xschem.tcl` | 6 FAILED |
| fixed C + fixed Tcl (the shipped fix) | 6 FAILED |
| the same suite, 21:25, same binary sources | ALL PASS (983) |

`git log 17b0c3fe..HEAD -- src/` is EMPTY, so no source changed between the
green run and the red one either.

## 3. The mechanism, from the suite's own diagnostics

Two OTHER rows print the pixel they scanned, and they moved:

```
  MX4b  a margin pixel was scanned      {140 313}   ->  {155 287}
  MS-X2 an empty plot-box pixel scanned (450,270)   ->  (499,253)
```

The drawing area is a **different size** in the two runs, so every coordinate
the suite derives from it moves. MX7b and MX7d are the two rows with no
margin: MX7b deliberately parks a marker on the TOPMOST sample so its anchor
sits a few pixels ABOVE the plot box but still inside `GRAPH_MARKER_TOL`, and
`waves_selected()` insets the rect by `border = 5 * tk_scaling`
(`src/callback.c:128`). A few pixels of geometry drift moves the anchor out of
the band the press can reach, and `ui_state` stays 0.

`:99` is 1920x1080x24 at 100x100 dpi with **openbox** live in both runs
(`tests/headless/devdisplay.sh status`), so the screen did not change; what
changed is where/how large openbox placed the suite's `.x1` window, which the
suite never pins.

## 3b. ⚠ CORRECTED MECHANISM — key delivery, not geometry

Measured by the item's Verify-A agent while re-running the suite under exclusivity:

**The geometry rows are IDENTICAL between the two runs.** MP0 `(236,184)`,
`(71,107)`, `(236,96)`; MS-X5 `{458 139}`; `plotbox=1 band=15 10 646 326`. Whatever
moved, the window did not.

**What appears only in the red run is seven new lines of:**

```
note: send_key: <Key-m> ... never took effect (200 tries)
Tk key delivery stalled (WSLg focus) - driving the shipping handler (round 1)
```

The suite's fallback **drives the shipping handler directly** instead of delivering
a real key event. That places markers at different pixels, which is why the two
diagnostic coordinates in §3 moved — `MX4b {140 313} -> {155 287}`,
`MS-X2 (450,270) -> (499,253)` — and why MX7b/MX7d, the two rows with zero margin,
then miss their scan band. The `waves_selected()` inset in §3 is still the reason
those two rows are the ones with no slack; it is not the reason the coordinate
moved.

So §5's fix direction 1 ("pin the geometry") would **not** fix this. The fix is to
make the key path deterministic, or to fail the stall as one named precondition row
rather than as six behavioural rows that read like the drag logic broke (§5's
direction 2, which was already the better one).

## 3c. The bisect, re-run rather than accepted on prose

The adversary pass flagged that accepting §2's table from a summary is exactly the
"standing red as furniture" pattern. Verify-A re-ran the decisive leg itself: the
**pre-fix binary** kept at `scratch_0812-retry/verifyA/xschem_pinned` (built 19:42,
predating this item's own source commit) reproduces **the same 6 failures, the same
8 stall notes and the same MX4b `{155 287}`**. Also re-run: a clean private
`xvfb-run`, and a fresh Xvfb `:87` with no stale `_NET_ACTIVE_WINDOW` — same 6 both
times. It is not this item's change, and it is not display state left behind by it.

## 4. Why it matters more than six checks

`test_wave_markers` is a 983-check suite on the GUI feature this branch is
shipping. A baseline that swings between 983-green and 977/6 **with no code
change** cannot be diffed against, which is the whole job of a tier baseline —
and a crew that sees "6 FAILED" against a remembered "ALL PASS" spends its
budget bisecting its own innocent patch, which is what happened here.

## 5. Fix directions (none taken)

1. ~~**Pin the geometry.**~~ **Superseded by §3b** — the geometry did not move.
   Pinning it is still good hygiene, but it would not have prevented these six.
2. **Make the stall loud in the right place.** The suite already prints
   `MARKER-TEST-STALL` with a correct diagnosis; it should FAIL AS A GEOMETRY
   PRECONDITION (one row, named) rather than as three behavioural rows that
   read like the drag logic broke.
3. Reject 1600x1200-style screen sizes explicitly (issue 0132 precedent).

## 6. Acceptance

1. Two consecutive runs on `:99`, with an unrelated window opened on the
   display between them, give the same check count.
2. The MX4b / MS-X2 scanned coordinates are identical across those runs.
3. **A forced key-delivery stall fails ONE named precondition row, not six
   behavioural ones**, and the row says "key delivery stalled" in its own text.
4. The handler fallback either places the marker where the key would have, or
   refuses to stand in for it — one or the other, decided and written down.
