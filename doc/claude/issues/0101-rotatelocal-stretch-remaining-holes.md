# 0101 — rotate-in-place during connected stretch: remaining tear-off holes (wire-owner cases)

**Status: OPEN (documented; pre-existing — NOT regressions of 0100). Found and empirically
confirmed by the 0100 adversarial review (workflow wf_80304448-181, live repros under X on the
fixed binary).**

Issue 0100 fixed the reported gesture: partial-selected follow wires whose moving endpoint sits on
a selected INSTANCE pin get that instance's origin as their rotatelocal pivot. Three adjacent
gestures in the same key chord (`m` connected stretch + ALT-R/ALT-F) remain torn, all pre-dating
0100 (they tear identically on the pre-0099 baseline):

## H1 (major) — fully-SELECTED follow wire between two co-selected instances

Box-select two connected instances, `m`, ALT-R, drop. `select_attached_nets` grabs the pin-to-pin
wire at BOTH ends and `select_wire` (select.c:1041) folds SELECTED1|SELECTED2 → full SELECTED, so
0100's `sel == SELECTED1 || == SELECTED2` gate excludes it: the wire rotates rigidly about its OWN
(x1,y1) while each instance rotates about its OWN origin → both endpoints off-pin → P1 disconnect.
Confirmed live (R1@(0,0), R2@(0,200), strap (0,30)-(0,170), ALT-R, drop +40,+20: strap lands
(-100,50)-(40,50); pins at (10,20)/(70,220)). **Structural blocker:** the two endpoints need
DIFFERENT pivots (each owning instance's origin) — the commit block's single-(wpx,wpy)-per-wire
rotation cannot express that; needs per-ENDPOINT pivots + an L-bend (the endpoints also stop being
axis-aligned, so a rigid wire cannot connect them: this is really a reroute, kin to Phase 4c).

## H2 (major) — wire-grab stretch: follower attached to a selected WIRE's endpoint

Select a WIRE (not an instance), `m`, ALT-R, drop. The 0100 owner scan only inspects sel_array
ELEMENT entries → no owner found → follower keeps the wire-own fallback pivot, while the grabbed
wire rotates about ITS own pristine (x1,y1) → junction rotates away from the follower's endpoint →
P1 tear. Confirmed live (wire A (0,0)-(100,0) grabbed, follower B (100,0)-(100,100) to R3.P: B's
end translates to (140,20), A's far end rotates to (40,120); R3.P torn onto fresh #net1).
**Candidate fix:** extend the owner scan to fully-SELECTED wires' endpoints, pivot = that wire's
PRISTINE (x1,y1). ⚠ ordering hazard: a grabbed wire earlier in sel_array is already rewritten by
place_moved_wire when a later follower scans it — the pristine pivots must be captured in a
PRE-PASS before the commit k-loop.

## H3 (minor) — exact `==` owner match vs the grab's endpoint_near tolerance

`select_attached_nets` grabs a follower whose endpoint is within `tol = cadsnap/2` of a moving pin
(select.c:1615, endpoint_near), but the 0100 scan requires exact `px == mvx && py == mvy` → an
off-grid follower endpoint (e.g. (99.5,0) vs pin (100,0)) finds no owner → wrong pivot → same tear
class. Structural (not run live). **Candidate fix:** match with the same endpoint_near tolerance,
then snap the moving endpoint onto the matched pin's rigid image.

## Test-hardening already applied to test_rotate_stretch_reconnect_0100.tcl (33 checks)

- rot90+flip off-anchor grab (guards edit C's flip arm — at an anchor grab the global and
  per-instance pivots coincide, hiding a flip-arm regression);
- multi-instance R18+C12 rotate-in-place, grab differing from both origins (guards the owner
  disambiguation scan);
- rot180/270 no-short FLOOR asserts inside the known-limitation loop (a disconnect→short
  regression can no longer hide behind the informational note).

H1/H2/H3 fixes belong with Phase 4c (reroute engine under rotation) or a dedicated pre-pass pivot
map; each needs its own RED-first fixture (H1/H2 repro scripts are described above and in the
review transcripts under wf_80304448-181).

See `doc/claude/issues/0100-rotate-in-place-during-stretch-tears-follow-wires.md` (the fixed
reported case) and `doc/claude/specs/rotate_keep_connected_stretch.md`.
