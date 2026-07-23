# Next-session prompt — 0132 drag-2 pin-on-run-END inward feed (xfail)

Copy-paste the block below into a fresh session.

---

Fix the deferred 0132 §11.9c follow-up: THIRD-generation drag leaves an INWARD feed through the
body (drag2 xfail). Branch fluid-editing, HEAD fa4ede89, src/move.c is CLEAN. Read
doc/claude/WIRING.md (§11.9, §5 pass table, §3 step 13b, §11.1) and
doc/claude/issues/0132-fluid-second-drag-own-copper.md (whole §11.9c tail: fix + adversarial-review
guards + the Deferred paragraph) BEFORE editing.

## Bug
Repro: load tests/from_user/before_10.sch, drag x1 +20x (the fa4ede89 body-shove fires: jog
(140,80)-(160,80), backbone (160,-20)-(160,80) — clean), then drag x1 +20x AGAIN. x1 lands (150,20)
rot 1, body box x[117.5,170] y[-132.5,82.5]. The CTRL1 pin (160,80) now lands exactly ON the shoved
backbone's top END; the drag-1 jog collapses to zero and the backbone `N 160 -20 160 80` survives as
the pin's feed, diving -y straight THROUGH the body to the l1 rail (x=160 is 10 inside the right
edge 170). Connected, Manhattan, never-worse vs pre-fix — but the user-expected result is the wire
pushed ahead of the body again each generation: jog right to x=180 (fluid_grid_above(170)=180),
backbone (180,-20)-(180,80), rail extension (180,-20)-(220,-20).

Headless repro: same env as the 0132 tests (XSCHEM_LIBRARY_DEFS=<repo>/xschem_libs_newsym/
library.defs, library_registry_defs_only 1, XSCHEM_LIBRARY_PATH {}, cadence_compat 1,
fluid_editing 1, orthogonal_wiring 1), then twice: `xschem select instance x1;
xschem move_objects 20 0 stretch kissing; xschem unselect_all`. FLUID_TRACE=<path> traces
`bodyshove:` decline lines.

## Make this pass
tests/headless/test_fluid_ortho_ctrl1_shove_0132.tcl — the "drag2 P5" xcheck (CTRL1 vertical clear
of x in (117.5,170)) is the xfail tripwire; promote xfail→hard `check` when fixed. The first-drag
12 hard checks (incl. P5b whole-net clearance) must stay green. After fixing, ADD a drag-3 (+20x
more) assertion so the invariant holds per generation, not just once (the after_34/after_35 lesson:
one-generation checks let siblings escape green).

## Why existing layers miss it
- fluid_shove_body_crossing_backbone (move.c, the fa4ede89 pass): its strictly-both-sides
  through-run gate declines a pin AT the run end BY DESIGN — that gate is the over-fire guard that
  keeps ordinary escape feeds (TRIANG +y, the #net top feeds) and 1/2-pin devices untouched.
  DO NOT weaken it: adversarial review wf_cff67bed proved the over-fire classes are real
  (tests/headless/test_fluid_bodyshove_guards_0132.tcl G1-G5 pin them — all must stay green).
- insert_exit_stubs: the after_34 guard (e6186956) DECLINES inward slides but never REROUTES an
  already-inward feed; get_pin_escape_normal mis-picks on the text-inflated bbox (after_34 root
  cause) so it cannot be trusted for direction here.
- fluid_reroute_body_crossing_feeds + fluid_delete_body_crossing_copper: gated diag_relay (never
  reached on this accepted pure-ortho path). The old hoist of it to every stretch over-fired via
  its DELETE step on 2-pin devices and was reverted — do not re-hoist with the delete.

This is the feed-DIRECTION class = WIRING §11.9 remaining gap (a) (escape machinery un-gate).

## Candidate fix shapes (evaluate, pick one, negate every gate you add)
A. Second trigger shape in fluid_shove_body_crossing_backbone: pin exactly at a run END + the run
   dives INWARD through the body (candidate discriminator: the run segment from the pin is a
   body-crossing per fluid_seg_crosses_sel_body — i.e. NOT exempt by the box-centre outward-normal
   test — vs the ordinary escape feed which is exempt/outward or does not cross). Reuse the whole
   existing rebuild + verify machinery (ct from OWN body edge, corners, jog, dual partition verify,
   exact revert). Careful: the one-sided variant loses the both-sides over-fire guard, so the
   inward/body-cross discriminator carries ALL the safety — negate it against: 2-pin res feeds
   (wireedit 10/19/28-30), the G1 label case, short stubs that merely clip the box edge, ymove
   mirror.
B. Reroute-only variant of fluid_reroute_body_crossing_feeds on the !diag_relay path: for a moved
   pin whose FEED WIRE (endpoint on the pin) crosses the sel body inward, fluid_manh_route the feed
   to fluid_nearest_outside_body_anchor — WITHOUT the verified-delete step (here the backbone IS
   the feed; nothing needs deleting). Site it next to the body-shove call (real END, clean
   geometry). Same warnings: the reverted hoist's over-fire came from delete + firing on ordinary
   feeds; the inward-crossing gate must exclude exempt outward feeds.

## Regression gates (ALL must stay green)
- tests/headless/wireedit/run_wireedit.sh → WIREEDIT: ALL PASS
- every tests/headless/test_fluid_*.tcl → OVERALL: ok — 17 files, incl.
  test_fluid_bodyshove_guards_0132.tcl (G1-G5 review guards) and both 0132 second-drag tests.
- tests/from_user/after_35_fixed.sch: drag-1 saved geometry must stay byte-identical.

## Discipline
- Trace-verify the actual SAVED geometry of drag2 (and drag3); a green suite ≠ the code ran.
- Sabotage-verify any new predicate; ship deferred negations as xfail tests.
- Mem-snapshot + partition-verify + exact revert on every mutation (house never-worse).
- Adversarial-review the change (the wf_cff67bed lens set: over-fire / revert-UAF / geometry /
  verify-direction / lifecycle) before declaring done; fix or pin every confirmed finding.
- Update WIRING.md §11.9 + pass catalog + issue doc §11.9c, and the fluid-rotate-body-route-0130
  memory file.
