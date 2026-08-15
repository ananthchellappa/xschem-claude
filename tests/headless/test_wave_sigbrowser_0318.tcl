# tests/headless/test_wave_sigbrowser_0318.tcl — issue 0318.
#
# ============================================================================
# WHAT IS UNDER TEST
# ============================================================================
# §F item F5 draws ONE SENTENCE inside the empty lower pane saying why it is
# empty. Dragging issue 0312's width grip WIPED that sentence: the sea canvas's
# `<Configure>` is wired into `wviewer::browser_sea_configure`, which called
# `browser_sea_refresh`, whose first act is to clear `browserseanote($token)` —
# so a RESIZE was treated as a NAVIGATION and the pane went back to being an
# unexplained empty box. Reported by hand, verbatim: "When you drag to make it
# really narrow, the sentence vanishes from the signal pane."
#
# THE FIX (issue 0318's candidate 1, "a refresh that redraws without clearing"):
# `browser_sea_refresh` takes `keepnote`, DEFAULT 0, and the ONE geometry caller
# — the `<Configure>` trampoline — passes 1. A kept notice also keeps the
# pane's CAPTION, because `browser_sea_say` would otherwise put the shipped
# `seaempty` sentence back under a pane that is still drawing the notice.
#
# ⚠⚠ WHY EVERY BEHAVIOURAL CHECK HERE READS THE CANVAS ITEM AND NOT THE
# VARIABLE. `browserseanote` is what SURVIVES; the drawn `seanote` tag is what
# the USER SEES, and the two are only equal because `browser_sea_draw` is
# reached. A check on the variable alone passes on a fix that never redraws, and
# a source grep sees nothing at all: every line involved in this defect was
# already there and individually correct.
#
# ⚠ AND THE RESIZE IS THE REAL GESTURE. `browser_grip_press` /
# `browser_grip_motion` / `browser_grip_drop` are issue 0312's shipped drag
# handlers, driven with the same X coordinates a pointer would deliver, so the
# `<Configure>` under test is one Tk really generated. BZ12's spy leg proves it
# arrived; without that leg every "the sentence survived" claim below would also
# pass on a resize that never happened.
#
# ============================================================================
# SABOTAGE TABLE — 19 mutations, each applied to src/wave_viewer.tcl, the WHOLE
# file re-run, reverted from a byte copy. Every row is MEASURED on the FINAL code
# (the table was re-measured from scratch after adversarial review changed the
# checks), every check in this file is red in at least one row, and no mutation
# produced a BGERROR.
#
# ⚠⚠ SEVEN ROWS (S13-S19), FOUR CHECKS (BZ05 BZ13b BZ19 BZ20) AND SIX EXTRA LEGS
# EXIST BECAUSE TWO ADVERSARIAL REVIEWS BROKE THE FIRST VERSION OF THIS FILE.
# It was 13/13 green, and all of the following were alive under it: the notice
# drawn WHITE ON WHITE, the notice drawn OUTSIDE the visible pane, F5's third
# surface deleted, a failed refresh leaving a sentence about a pane that no longer
# exists, the fix's own clear writing a LOCAL array so that it did nothing, the
# keep reading the array without its token, and BZ13's wrap-width arithmetic being
# ambiguous at exactly the width it drags to. S15/S16 are the two that mattered
# most: each reproduces the user's own words — "the sentence vanishes from the
# signal pane" — with every other check green.
# ============================================================================
#  #   mutation                                                    reds (measured)
# --- the fix itself ---------------------------------------------------------
#  S1  the trampoline stops passing the flag (revert 0318          BZ01 BZ02 BZ12
#      exactly, keep everything else)                              BZ13 BZ13b BZ16
#                                                                  BZ18
#  S2  the clear loses its guard: `set browserseanote($token) {}`   BZ03 BZ12 BZ13
#      unconditional again                                         BZ13b BZ16 BZ18
#  S3  the DEFAULT is flipped to `{keepnote 1}` — every caller      BZ01 BZ14 BZ15
#      keeps, i.e. a stale reason on a repopulated pane
#  S7  the guard is INVERTED (`if {$keepnote}`): geometry clears,   BZ03 BZ12 BZ13
#      navigation keeps                                            BZ13b BZ14 BZ16
#                                                                  BZ17 BZ18
# --- the caption half ------------------------------------------------------
#  S4  the kept-notice early return is deleted, so `browser_sea_    BZ04 BZ12 BZ18
#      say` re-captions the pane under a live notice
#  S5  the early return is made UNCONDITIONAL (`return $n`) — no    BZ04 BZ15
#      geometry event ever re-captions
# --- a navigation that FAILED is still a navigation (review) -----------------
# S13  both `catch {set browserseanote($token) {}}` lines in        BZ19
#      `browser_refresh`'s two bail-outs are deleted
# S14  `variable browserseanote` is removed from `browser_refresh`  BZ19
#      so those two clears address a LOCAL array and the `catch`
#      hides it. ⚠ THIS IS THE FIRST CUT OF THE FIX. A source grep
#      for the clear passed; only BZ19 sees the difference.
# --- the drawn sentence: what the USER can see (review) ---------------------
# S15  `-fill {#8b0000}` -> `-fill [ase::theme table]` — the        BZ11 BZ12
#      sentence drawn WHITE ON WHITE, i.e. 0318's reported
#      symptom with the item still there
# S16  `create text 6 4` -> `create text 600 4` — drawn outside     BZ11 BZ12
#      the visible pane, which an empty pane's zero-width
#      scrollregion cannot be scrolled to
# S17  `browser_notice`'s `browser_status` line deleted — F5        BZ11
#      loses its third surface
# S19  `browser_sea_draw`'s `if {$w < 80} { set w 240 }` wrap       BZ05
#      floor deleted (source-only: the 240 px sidebar clamp puts
#      the floor out of the fixture's reach — see BZ05's own ⚠)
# --- the evidence's own controls -------------------------------------------
#  S6  the trampoline calls `browser_sea_draw` instead of the      BZ01 BZ02 BZ15
#      keeping refresh.
#      ⚠ THE PREDICTED HOLE HERE DID NOT EXIST, and the difference
#      is recorded rather than quietly dropped: this row was
#      written expecting ONLY the source checks to see it (the
#      sentence does survive, and the pane does re-flow). BZ15
#      reds too, because a private draw path never re-captions the
#      pane. BZ01/BZ02 still earn their place: they are what says
#      the geometry path re-reads the tree selection through the
#      ONE refresh, which is browser_sea_configure's own argument.
#  S8  `browser_sea_draw`'s notice arm is disabled — the positive   BZ11 BZ12 BZ13
#      control, i.e. proof these checks read a DRAWN item          BZ13b BZ14 BZ16
#                                                                  BZ17 BZ19
#  S9  `browser_sea_configure` becomes a no-op — proof the reflow   BZ01 BZ02 BZ13
#      legs are load-bearing (the sentence would otherwise survive  BZ13b BZ15 BZ19
#      by accident, at the OLD width)
# S10  `browser_grip_motion` stops applying the width — proof the   BZ12 BZ13 BZ13b
#      drag really resizes something (the "nothing happened"        BZ15 BZ16 BZ18
#      hole). ⚠ It does NOT red BZ10: that check applies the start  BZ19 BZ20
#      width through `browser_width` directly, which is what makes
#      it a fixture precondition and not a claim about the grip.
# S11  the `keepnote` normalisation is deleted, so a non-boolean    BZ01 BZ17
#      argument throws instead of falling to the navigation
#      default. ⚠ Review's correction, recorded: the two BINDS pass
#      no argument, so the throw needs a FUTURE caller — these two
#      checks are a contract, not a live bug.
# S12  `browser_refresh`'s `set browserseaent($token) $seaent` is   BZ10 BZ18
#      deleted — the row that exists BECAUSE the first cut of this
#      file had no leg on that snapshot and was hollow (see the
#      fixture's own ⚠⚠). It is the only mutation BZ10 sees.
# S18  the keep reads the notice array WITHOUT its token (an        BZ20
#      `array get` sweep) — one window's sentence kept on
#      another's resize. ⚠ MEASURED GREEN ON ALL 17 CHECKS FIRST:
#      the canvas cannot see it (the draw reads the note per
#      token), so BZ20 needed the CAPTION sentinel before this row
#      reddened anything.
# ============================================================================
#
# ============================================================================
# WHAT THIS FILE DOES NOT CLAIM — expanded by adversarial review, which found
# most of this list absent
# ============================================================================
# * It drives a real sidebar in a BARE TOPLEVEL, not a real viewer with a loaded
#   VCD, and the notice is minted by calling `browser_notice` directly. The
#   end-to-end path that WRITES the sentence (Ctrl-Alt-V ->
#   ase::show_in_browser_for_current -> F5) is test_wave_sigbrowser_digital.tcl's
#   FD20-FD27. This file is about what a GEOMETRY event does to a notice that is
#   already on the pane.
# * `Ctrl-B` TWICE STILL CLEARS THE SENTENCE, and that is one of the four doors
#   issue 0318's Reachability section lists. It is NOT the `<Configure>`
#   trampoline: hiding and re-showing the sidebar goes `browser_toggle` ->
#   `browser_show` -> `browser_refresh $token 1`, whose own rule is
#   SHOW = REPOPULATE (it re-reads the raw), so it is a navigation by the code's
#   own declaration. Untested here, deliberately, and declared instead of implied.
#   The other three doors ARE covered: the sash and the grip both land on this
#   canvas's `<Configure>`, and a toplevel resize reaches the browser through
#   nothing else (`on_configure` -> `configure_apply` never touches it).
# * ISSUE 0320 IS LIVE ON THIS VERY FIXTURE. The same `<Configure>` that keeps
#   the notice still throws away the lower pane's SELECTION (`browserseasel` /
#   `browserseaanchor` are reset unconditionally by the refresh). This file drives
#   that gesture and asserts NOTHING about it; the check that closes it has to read
#   the drawn `selbox` items, and the ruling it needs is 0320's, not 0318's.
# * THE SUB-80 px WRAP FLOOR is pinned by source only (BZ05). The sidebar clamps
#   at 240 px, so a canvas narrow enough to reach the floor is not reachable
#   through the grip at all.
# * WITHOUT X (the `--nogui` arm) the five source checks run, the eleven
#   behavioural ones SKIP, and the banner still says `RESULT: ALL PASS`. House
#   convention — but for a file whose whole subject is what is on the screen, the
#   green on that arm means five greps and nothing else.
# * NOTHING HERE IS AN EYEBALL. Whether the sentence is LEGIBLE at ~250 px — the
#   verdict `EYEBALL_QUEUE.md` item 5 step 7 was blocked on — is a human's call.
#   The colour and the bbox legs say it is drawn, in its colour, inside the pane;
#   they do not say it reads well.

set ::wvbs_tag  wvsigbrowser_0318
set ::wvbs_name test_wave_sigbrowser_0318
source [file join [file dirname [info script]] wvbs_common.tcl]

# ---------------------------------------------------------------------------
# BZ01-BZ04 — SOURCE. The shape a behavioural check cannot see, and on this
# defect that is more than usual: mutation S6 (a private draw path in the
# trampoline) keeps every behavioural check green.
# ---------------------------------------------------------------------------
set bz_conf [wvproc_body $wsrc wviewer::browser_sea_configure]
set bz_ref  [wvproc_body $wsrc wviewer::browser_sea_refresh]
# ase.tcl is read for ONE leg of the ledger below: the callers of the sea refresh
# have to be countable, and a caller added from the OTHER file would be invisible
# to a count over wave_viewer.tcl alone.
set bz_asrc {}
catch {
  set bz_fh [open [file join $repo src ase.tcl] r]
  set bz_asrc [read $bz_fh]
  close $bz_fh
}

# ⚠ THE DEFAULT IS THE SAFE DIRECTION AND IT IS PINNED AS TEXT. `{keepnote 0}`
# means a caller that says nothing is a NAVIGATION and clears — so a future
# caller cannot leave a stale reason behind by forgetting. `{keepnote 1}` would
# reverse exactly that, and S3 measures it reddening BZ14 rather than this file
# going quiet.
#
# ⚠ LEG 3 IS THE NORMALISATION, AND IT IS THIS PROC'S OWN CONTRACT: its header
# says every rung is a guard because it rides <<TreeviewSelect>> and a throw
# there pops a MODAL bgerror that HANGS a headless run — and `if {!$junk}`
# throws. A non-boolean therefore has to read as 0, the navigation default, which
# is also the safe direction. BZ17 is the behavioural twin.
check {BZ01 (SOURCE) the refresh carries `keepnote` DEFAULTING to 0, normalises
       it, and the <Configure> trampoline is what asks for 1} \
  [list [expr {[string first \
                 "proc wviewer::browser_sea_refresh \{token \{keepnote 0\}\}" \
                 $wsrc] >= 0}] \
        [regexp -all {browser_sea_refresh \$token 1} $bz_conf] \
        [regexp -all \
          {set keepnote \[expr \{\[string is true -strict \$keepnote\] \? 1 : 0\}\]} \
          $bz_ref]] {1 1 1}

# ⚠⚠ THE LEDGER, AND IT IS WHAT MAKES A NEW CALLER VISIBLE. Three call sites in
# src/wave_viewer.tcl — <<TreeviewSelect>> (navigation), browser_refresh's tail
# (navigation: a bar keystroke that narrowed nothing away), and the <Configure>
# trampoline (GEOMETRY) — and exactly ONE of the three keeps the notice. A
# fourth caller, or a second keeper, reds this rather than being classified by
# nobody, which is how issue 0318 came back.
#
# ⚠ LEG 3 IS SPELLING-AGNOSTIC WITHIN THE FILE and legs 1-2 are not: a caller
# written `browser_sea_refresh $tok 1`, or unqualified (which resolves inside the
# namespace from any `proc wviewer::…` body), is invisible to an exact-text count.
# ⚠⚠ LEG 5 IS THE SENTINEL, AND WITHOUT IT LEG 4 IS SATISFIED BY "ase.tcl WAS
# NEVER OPENED": the read is `catch`ed into `{}`, and `string first` on the empty
# string is -1 — the catch-swallowed-into-a-matching-value shape, found by review.
check {BZ02 (SOURCE) three callers of the sea refresh, exactly ONE of them the
       geometry one that keeps the notice, none in ase.tcl — and ase.tcl really
       was read} \
  [list [regexp -all {wviewer::browser_sea_refresh \$token} $wsrc] \
        [regexp -all {wviewer::browser_sea_refresh \$token 1} $wsrc] \
        [regexp -all {browser_sea_refresh \$} $wsrc] \
        [expr {[string first {browser_sea_refresh $} $bz_asrc] >= 0}] \
        [expr {[string first {proc ase::show_in_browser_for_current} $bz_asrc] >= 0}]] \
  {3 1 3 0 1}

# ⚠ THE FLOOR THE ISSUE QUOTES, WHICH THIS FILE CANNOT DRIVE. `browser_sea_draw`
# wraps the sentence at the PANE's width and falls back to 240 under 80 px — the
# comment issue 0318 quotes as "the floor works, the text never reaches it". The
# sidebar clamps at 240 px, so a canvas under 80 px is not reachable through the
# grip and no behavioural check here can exercise it; a source leg is what keeps
# the floor from being deleted as dead code. BZ13b is what proves the NORMAL path
# does not silently use it.
check {BZ05 (SOURCE) the notice's wrap width is the pane's, with the floor the
       issue quotes still in place} \
  [list [regexp -all -- {-width \[expr \{\$w - 12\}\]} \
           [wvproc_body $wsrc wviewer::browser_sea_draw]] \
        [regexp -all -- {if \{\$w < 80\} \{ set w 240 \}} \
           [wvproc_body $wsrc wviewer::browser_sea_draw]]] {1 1}

# the clear is still ONE site (FD03's claim, one file over) and it is now
# guarded — the guard and the clear pinned together, since either alone is
# satisfiable by a mutation that reverses the behaviour.
check {BZ03 (SOURCE) the notice's one clear site is guarded by `!$keepnote`} \
  [list [regexp -all {if \{!\$keepnote\} \{ set browserseanote\(\$token\) \{\} \}} \
           $bz_ref] \
        [regexp -all {set browserseanote\(\$token\) \{\}} $bz_ref]] {1 1}

# ⚠ WHERE THE EARLY RETURN SITS IS THE WHOLE OF THE CAPTION HALF: AFTER the
# draw (so the pane is re-flowed at the new width) and BEFORE the first
# `browser_sea_say` (so the shipped §7.2 sentence does not replace the notice on
# the label `browser_notice` wrote it to).
set bz_i_draw [string first {browser_sea_draw $token} $bz_ref]
set bz_i_keep [string first {if {$kept ne {}} { return $n }} $bz_ref]
set bz_i_say  [string first {browser_sea_say} $bz_ref]
check {BZ04 (SOURCE) the kept-notice return is AFTER the draw and BEFORE the
       first caption write} \
  [list [expr {$bz_i_draw >= 0 && $bz_i_draw < $bz_i_keep}] \
        [expr {$bz_i_keep >= 0 && $bz_i_keep < $bz_i_say}]] {1 1}

# ---------------------------------------------------------------------------
# BZ10-BZ16 — THE GESTURE, DRIVEN on a real sidebar (X only).
# ---------------------------------------------------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # ⚠⚠ THE FIXTURE IS test_wave_sigbrowser_sea.tcl's BQ51 RECIPE, NOT A HAND-BUILT
  # TREE, AND THE DIFFERENCE WAS MEASURED. The first cut of this file seeded
  # `browsersigs` + `browser_rows` + `browser_populate` itself (the BE20 idiom,
  # which is about a resolver and not about the pane) and never set
  # `browserseaent` — the snapshot the LOWER PANE draws from. Every node then drew
  # zero cells, so BZ10's "the pane is empty" was true for the wrong reason and
  # BZ18 could not find a non-empty node at all. Seeding the inventory and letting
  # the SHIPPED `browser_refresh` build both halves is what makes "empty" and
  # "listing things" two states this fixture can really be in.
  catch {destroy .wvbz1}
  toplevel .wvbz1
  wm title .wvbz1 {issue 0318 resize-keeps-the-notice fixture}
  wm geometry .wvbz1 900x760+70+70
  canvas .wvbz1.drw -background white -width 700 -height 720
  pack .wvbz1.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbz [dict create top .wvbz1 win_path .wvbz1.drw]
  pcall ::wviewer::browser_build wvbz .wvbz1
  set BZF  .wvbz1.wvbrowser
  set BZTV $BZF.pw.tvf.tv
  set BZC  $BZF.pw.sea.c
  set BZST $BZF.pw.sea.st
  # `browser_toggle`, not a bare `pack`: it is the shipped show, so the WIDTH,
  # issue 0312's GRIP and the sash are all applied the way the product applies
  # them — and the grip is the widget whose drag this file is about.
  pcall ::wviewer::browser_toggle 1 wvbz
  set bz_mapped [bs_wait_mapped .wvbz1.drw]
  catch {bs_wait_mapped $BZTV}
  catch {bs_wait_mapped $BZC}
  catch {bs_wait_sash $BZF.pw}
  update

  # The inventory, hand-seeded for BQ51's reason: this fixture has no xschem
  # context, so `browser_reload`'s signal_list read correctly answers {}. The
  # `browser_refresh $tok 0` that follows is the SHIPPED refresh — it writes the
  # tree AND `browserseaent`, in one pass, exactly as a real one does.
  proc bz_seed {names} {
    set ::wviewer::browsersigs(wvbz) $names
    set ::wviewer::browserraw(wvbz)  {/nowhere/bztop.raw}
    set r [pcall ::wviewer::browser_refresh wvbz 0]
    update
    return $r
  }

  # ⚠ THE CANVAS WIDTH HAS TO HAVE SETTLED BEFORE THE DRAWN `-width` IS READ,
  # and this polls the PRECONDITION (the width has stopped moving), never the
  # asserted value — bs_wait_widths' rule. It RETURNS the width, so a budget
  # expiry still fails the caller's own comparison instead of being rescued.
  proc bz_settle_w {w {budget 200} {settle 10}} {
    set last -1 ; set same 0 ; set v 0
    for {set t 0} {$t < $budget} {incr t} {
      set v 0
      catch {set v [winfo width $w]}
      if {$v > 1} {
        if {$v == $last} { incr same } else { set same 0 ; set last $v }
        if {$same >= $settle} { return $v }
      }
      after 10 ; update
    }
    catch {set v [winfo width $w]}
    return $v
  }
  # The drawn notice, as everything about it a USER can see: how many items carry
  # the tag, the text, the wrap width, THE COLOUR and THE TOP-LEFT OF ITS BBOX.
  # `none` when nothing is drawn, so "the sentence is gone" and "the sentence is
  # there but blank" are different values.
  #
  # ⚠⚠ THE COLOUR AND THE POSITION ARE HERE BECAUSE ADVERSARIAL REVIEW FOUND THEM
  # UNPINNED — in this file and in the whole tree (`grep -rn seanote tests/`). Two
  # one-word product mutations reproduce the user's own words, "the sentence
  # vanishes from the signal pane", with every other check green:
  #   * `-fill {#8b0000}` -> `-fill [ase::theme table]` — the canvas background is
  #     `table`, so the sentence is drawn white on white. `accent` and `table` are
  #     neighbours in the same palette dict; this is one slip in a refactor.
  #   * `create text 6 4` -> `create text 600 4` — with an empty pane the
  #     scrollregion is `{0 0 0 $paneh}` (browser_flow_scrollregion), so the pane
  #     CANNOT be scrolled to it. The item exists; nobody can see it.
  # Reading the pixels Tk actually drew is the prelude's own rule for the other
  # canvas arm (`bs_sea_xy`); the notice arm had not inherited it.
  proc bz_note {c} {
    set ids {}
    if {[catch {$c find withtag seanote} ids]} { return no-pane }
    if {![llength $ids]} { return none }
    set it [lindex $ids 0]
    set tx {} ; set wd -1 ; set fl {} ; set bb {}
    catch {set tx [$c itemcget $it -text]}
    catch {set wd [$c itemcget $it -width]}
    catch {set fl [$c itemcget $it -fill]}
    catch {set bb [$c bbox $it]}
    set x -1 ; set y -1
    if {[llength $bb] == 4} { set x [lindex $bb 0] ; set y [lindex $bb 1] }
    return [list [llength $ids] $tx $wd $fl $x $y]
  }
  # 1 when the drawn sentence is INSIDE the visible pane. Not a tolerance and not
  # a guess: an empty pane's scrollregion has zero width, so anything off to the
  # right is unreachable by any gesture the user has.
  proc bz_visible {c n} {
    if {[llength $n] != 6} { return 0 }
    set x [bs_num [lindex $n 4]] ; set y [bs_num [lindex $n 5]]
    set w 0 ; set h 0
    catch {set w [winfo width $c]}
    catch {set h [winfo height $c]}
    return [expr {$x >= 0 && $y >= 0 && $x < $w && $y < $h}]
  }
  # THE SPY on the geometry trampoline. Delegates to the shipped proc, so what
  # it records is that a REAL <Configure> arrived — the leg without which every
  # "it survived the resize" claim would also hold for a resize that never
  # happened.
  proc bz_spy_on {} {
    set ::bz_nconf 0
    rename ::wviewer::browser_sea_configure ::wviewer::browser_sea_configure_bzspy
    proc ::wviewer::browser_sea_configure {token} {
      incr ::bz_nconf
      return [::wviewer::browser_sea_configure_bzspy $token]
    }
  }
  proc bz_spy_off {} {
    catch {rename ::wviewer::browser_sea_configure {}}
    catch {rename ::wviewer::browser_sea_configure_bzspy \
             ::wviewer::browser_sea_configure}
  }
  # ONE drag, in the three events Tk delivers, from the sidebar's current width
  # to `to` pixels. Answers the width the product actually applied.
  proc bz_drag {from to} {
    pcall ::wviewer::browser_grip_press wvbz $from
    set w 0
    foreach x [list [expr {($from + $to) / 2}] $to] {
      set w [pcall ::wviewer::browser_grip_motion wvbz $x]
      update
    }
    pcall ::wviewer::browser_grip_drop wvbz
    update
    return $w
  }

  set bz_names {v(x1.x2.net5) v(x1.y3.net7) v(out)}
  set bz_nrows [bz_seed $bz_names]
  set bz_ents  0
  catch {set bz_ents [llength $::wviewer::browserseaent(wvbz)]}
  # ⚠ `g:x1` IS A PURE ANCESTOR — it has sub-scopes and no own-level signals —
  # so the pane is EMPTY, which is the one state F5's canvas arm draws in.
  pcall $BZTV selection set [list {g:x1}]
  update
  set bz_w_start [pcall ::wviewer::browser_width wvbz 400]
  update
  set bz_c_start [bz_settle_w $BZC]
  # ⚠ LEG 3 IS THE SNAPSHOT THE PANE DRAWS FROM, and it is here because its
  # ABSENCE is what made the first cut of this file hollow: with `browserseaent`
  # unset every node draws nothing, and leg 4's `0` then says nothing about `g:x1`
  # being a pure ancestor. Three names in, three entries.
  # ⚠ LEG 7 READS THE CANVAS AGAINST THE WIDTH THAT WAS ASKED FOR, and that is a
  # review finding: `browser_width` RETURNS its computed pixel count whether or not
  # the `catch {$f configure -width}` did anything, so `$bz_w_start` alone says
  # nothing about the fixture. It also ties the `-12` gutter arithmetic BZ13/BZ13b
  # depend on to a frame width somebody asserted.
  check {BZ10 (FIXTURE) the sidebar is built and mapped, the inventory reached
         the PANE's own snapshot, `g:x1` is a pure ancestor so the pane is EMPTY,
         and the 400 px start width was really APPLIED to the pane} \
    [list $bz_mapped [winfo exists $BZC] $bz_nrows $bz_ents \
          [llength [$BZC find withtag cell]] $bz_w_start \
          [expr {abs($bz_c_start - $bz_w_start) <= 4}]] \
    [list 1 1 1 3 0 400 1]

  # ⚠⚠ POSITIVE CONTROL. Without it every claim below is a claim about a
  # sentence nobody has proved was ever on the pane.
  set bz_msg "showing the digital scope 'TOP' of 'bz.vcd' in the tree, but that\
 scope has no signals of its own - open one of its sub-scopes to see any"
  set bz_ok [pcall ::wviewer::browser_notice wvbz $bz_msg]
  update
  set bz_before [bz_note $BZC]
  # ⚠ LEGS 4-7 ARE REVIEW FINDINGS, EVERY ONE OF THEM A MUTATION THAT WAS GREEN:
  # the wrap width (`bs_num`, so a missing item cannot become a string compare
  # that reads true), THE COLOUR, THE VISIBLE POSITION, and F5's THIRD SURFACE —
  # the sidebar status line `$f.ph`, which this file's own prose calls one of three
  # and measured nowhere.
  check {BZ11 (POSITIVE CONTROL) the notice is DRAWN in the empty pane, in its own
         colour, inside the pane, and is on BOTH the caption and the sidebar
         status line} \
    [list $bz_ok [lindex $bz_before 0] [lindex $bz_before 1] \
          [expr {[bs_num [lindex $bz_before 2]] > 0}] \
          [lindex $bz_before 3] [bz_visible $BZC $bz_before] \
          [$BZST cget -text] [$BZF.ph cget -text]] \
    [list 1 1 $bz_msg 1 {#8b0000} 1 $bz_msg "Signal Browser\n$bz_msg"]

  # ===================== THE REPORTED GESTURE =============================
  bz_spy_on
  set bz_w_end [bz_drag 400 180]
  bz_spy_off
  set bz_c_end [bz_settle_w $BZC]
  set bz_after [bz_note $BZC]
  # ⚠ 240 IS `browser_width`'s FLOOR, not a coincidence: the drag asked for 180
  # and the shipped clamp stopped it, which is the "really narrow" end of the
  # user's report.
  check {BZ12 (THE DEFECT) after a real narrowing drag the sentence is STILL
         drawn in the pane, verbatim, in its colour, inside the NARROW pane, and
         still on the caption — and the <Configure> really arrived} \
    [list $bz_w_end [expr {$bz_c_end < $bz_c_start}] \
          [expr {$::bz_nconf > 0}] \
          [lindex $bz_after 0] [lindex $bz_after 1] [lindex $bz_after 3] \
          [bz_visible $BZC $bz_after] [$BZST cget -text]] \
    [list 240 1 1 1 $bz_msg {#8b0000} 1 $bz_msg]

  # ⚠⚠ IT SURVIVED BY BEING RE-DRAWN, NOT BY NOTHING HAPPENING. The wrap width
  # is the pane's width minus the gutter (browser_sea_draw's ⚠), so a sentence
  # left over from the wide pane would still read `-width 388` and overflow the
  # narrow one. This is the leg that separates the fix from "the Configure never
  # fired".
  #
  # ⚠ LEG 1 IS THE COUNT AND IT IS NOT REDUNDANT WITH BZ12: `bz_note` answers
  # `none` when nothing is drawn, and `[lindex none 2]` is the empty string,
  # which `expr {{} < 388}` compares AS A STRING and calls true. Without the
  # count leg both arithmetic legs would go green on a pane with no sentence at
  # all — a silent-green trap of exactly the shape this file exists to avoid.
  check {BZ13 the sentence was RE-FLOWED to the narrow pane: its wrap width
         followed the canvas} \
    [list [lindex $bz_after 0] \
          [expr {[bs_num [lindex $bz_after 2]] < [bs_num [lindex $bz_before 2]]}] \
          [expr {[bs_num [lindex $bz_after 2]] == $bz_c_end - 12}]] {1 1 1}

  # ⚠⚠ AND THE SAME READ AT A WIDTH CLEAR OF THE FLOOR — a review finding, because
  # BZ13's arithmetic is AMBIGUOUS at exactly the width BZ12 drags to.
  # `browser_width` clamps the sidebar to 240, so `bz_c_end - 12` is 228 — which is
  # also what `browser_sea_draw`'s OWN fallback (`if {$w < 80} { set w 240 }`)
  # produces. So at the narrow end "the draw read the real pane width" and "the
  # draw fell back to its constant" are the same number. One more drag, to a width
  # the clamp does not touch, tells them apart.
  bz_spy_on
  set bz_w_mid [bz_drag 240 336]
  bz_spy_off
  set bz_c_mid [bz_settle_w $BZC]
  set bz_mid_n [bz_note $BZC]
  check {BZ13b ...and the wrap width tracks a width the 240 px clamp does not
         touch, so it is the PANE's width and not the draw's fallback constant} \
    [list $bz_w_mid [lindex $bz_mid_n 0] \
          [expr {[bs_num [lindex $bz_mid_n 2]] == $bz_c_mid - 12}] \
          [expr {[bs_num [lindex $bz_mid_n 2]] != 228}] \
          [lindex $bz_mid_n 1]] \
    [list 336 1 1 1 $bz_msg]

  # ⚠⚠ AND A REAL NAVIGATION STILL CLEARS IT. This is the anti-overfix leg: a
  # notice that outlives the pane it describes is the failure the shipped clear
  # exists to prevent, and S3 (the default flipped to `keepnote 1`) is exactly
  # that mutation. TWO doors, because they are two call sites: the refresh
  # called plainly, and a treeview selection change.
  pcall ::wviewer::browser_sea_refresh wvbz
  update
  set bz_nav1 [list $::wviewer::browserseanote(wvbz) [bz_note $BZC]]
  pcall ::wviewer::browser_notice wvbz $bz_msg
  update
  set bz_reminted [lindex [bz_note $BZC] 0]
  pcall $BZTV selection set [list {g:x1.y3}]
  update
  set bz_nav2 [list $::wviewer::browserseanote(wvbz) [bz_note $BZC]]
  # ⚠⚠ DOOR 3 IS A REVIEW FINDING, AND WITHOUT IT DOOR 2 IS VARIABLE-ONLY. `g:x1.y3`
  # LISTS a name, so `browser_sea_draw`'s notice arm cannot fire there whatever
  # the variable holds — `bz_note` answers `none` for a kept notice and a cleared
  # one alike, which is exactly the read this file's header says is not enough.
  # Landing BACK on the empty node is what makes the canvas leg discriminate: a
  # notice that survived the tree navigation would be DRAWN here.
  pcall $BZTV selection set [list {g:x1}]
  update
  set bz_nav3 [list $::wviewer::browserseanote(wvbz) [bz_note $BZC] \
                    [llength [$BZC find withtag cell]]]
  check {BZ14 (ANTI-OVERFIX) a NAVIGATION still clears the notice — the plain
         refresh, a tree selection change, and the empty pane it lands back on} \
    [list $bz_nav1 $bz_reminted $bz_nav2 $bz_nav3] \
    [list [list {} none] 1 [list {} none] [list {} none 0]]

  # ⚠ AND WITH NO NOTICE LIVE, A RESIZE STILL DOES ITS ORDINARY JOB. The
  # sentinel is what makes that assertable: the shipped §7.2 caption has to be
  # WRITTEN BY THIS RESIZE, not merely still be there from before it — which is
  # the check S5 (`return $n` unconditionally) reds.
  pcall $BZTV selection set [list {g:x1}]
  update
  catch {$BZST configure -text {BZ15-SENTINEL}}
  bz_spy_on
  bz_drag 240 380
  bz_spy_off
  update
  check {BZ15 with NO notice live, a resize still re-captions the pane from the
         shipped §7.2 arm and invents no sentence} \
    [list [expr {$::bz_nconf > 0}] [$BZST cget -text] [bz_note $BZC] \
          $::wviewer::browserseanote(wvbz)] \
    [list 1 {x1 has no signals of its own} none {}]

  # ⚠ A DRAG IS DOZENS OF <Configure>s, NOT ONE. `browser_grip_motion` runs per
  # <B1-Motion>, so the keep has to hold for every one of them. (Review's
  # correction, recorded rather than dropped: this is NOT the only check a
  # ONE-SHOT keep would red — BZ12's own drag already applies two distinct widths,
  # 290 then the 240 clamp, so it spans two <Configure>s. Ten events is a stronger
  # statement of the same claim, and five rows of the table red it.)
  pcall ::wviewer::browser_notice wvbz $bz_msg
  update
  bz_spy_on
  pcall ::wviewer::browser_grip_press wvbz 380
  for {set bz_i 0} {$bz_i < 10} {incr bz_i} {
    pcall ::wviewer::browser_grip_motion wvbz [expr {380 - 20 * $bz_i}]
    update
  }
  pcall ::wviewer::browser_grip_drop wvbz
  update
  bz_spy_off
  set bz_many [bz_note $BZC]
  check {BZ16 the sentence survives a WHOLE drag — ten motion events, one
         notice, still verbatim} \
    [list [expr {$::bz_nconf >= 5}] [lindex $bz_many 0] [lindex $bz_many 1]] \
    [list 1 1 $bz_msg]

  # ⚠⚠ F5's OTHER HALF, WHICH THE CANVAS CHECKS ABOVE CANNOT SEE. The notice has
  # THREE surfaces deliberately, because the pane is not always the empty one:
  # when the gesture fell through to the analog path the tree lands on a real
  # node whose pane is FULL, `browser_sea_draw`'s canvas arm stays silent by
  # construction, and the CAPTION is what carries the reason. A resize wiped that
  # too — same one line, a surface no `find withtag seanote` can reach. So: mint
  # a notice on a node that LISTS things, resize, and read the caption.
  #
  # ⚠ THE DESIGN ROOT IS THE NODE THAT LISTS SOMETHING HERE, and it was MEASURED
  # rather than assumed: `g:x1.x2` draws ZERO cells on this seeded inventory (the
  # first cut of this check used it and read a pane that was empty, so the canvas
  # arm fired and the check was about nothing). `v(out)` is the root's own-level
  # name — the same node test_wave_sigbrowser_digital.tcl's FD23 pre-state uses
  # for the same reason. Leg 1 asserts the pre-state instead of trusting it.
  pcall $BZTV selection set [list {g:}]
  update
  set bz_cells [llength [$BZC find withtag cell]]
  pcall ::wviewer::browser_notice wvbz $bz_msg
  update
  bz_spy_on
  bz_drag 240 380
  bz_spy_off
  update
  check {BZ18 a notice on a NON-EMPTY pane survives the same resize on the
         caption, and the canvas arm stays silent} \
    [list [expr {$bz_cells > 0}] [expr {$::bz_nconf > 0}] \
          [$BZST cget -text] [bz_note $BZC] \
          [llength [$BZC find withtag cell]]] \
    [list 1 1 $bz_msg none $bz_cells]

  # ⚠ THE GUARD CONTRACT, BEHAVIOURALLY (BZ01 leg 3's twin). A garbage keep
  # argument must be a NAVIGATION and must not throw: this proc rides
  # <<TreeviewSelect>>, and an escaped error there is a modal bgerror.
  #
  # ⚠⚠ THE PRE-STATE IS ASSERTED, NOT INHERITED, AND THAT IS A REVIEW FINDING. This
  # check used to start from whatever BZ18's drag had left behind, so under any
  # mutation where a geometry event CLEARS, it degraded into "clearing an
  # already-clear notice" and stopped testing anything. Leg 1 is the notice being
  # live and DRAWN on the turn before the junk call.
  pcall $BZTV selection set [list {g:x1}]
  update
  pcall ::wviewer::browser_notice wvbz $bz_msg
  update
  set bz_junk_pre [lindex [bz_note $BZC] 0]
  set bz_junk [pcall ::wviewer::browser_sea_refresh wvbz junk]
  update
  check {BZ17 a keep argument that is not a boolean is a NAVIGATION, not a throw
         — and it really had a notice to clear} \
    [list $bz_junk_pre [bs_set $bz_junk] \
          $::wviewer::browserseanote(wvbz) [bz_note $BZC]] \
    [list 1 1 {} none]

  # =========================================================================
  # BZ19 — A NAVIGATION THAT FAILED IS STILL A NAVIGATION (review finding).
  #
  # ⚠⚠ THE FIX WIDENED AN EXISTING HOLE AND THIS IS THE PATCH FOR IT. Both of
  # `browser_refresh`'s bail-outs (`browser_rows_multi` throws, `browser_populate`
  # throws) `return` AFTER rewriting `browserseaent` — the pane's own snapshot —
  # and BEFORE the tail sea refresh, which is the one place the notice is cleared.
  # So a refresh that throws leaves a sentence describing a pane that no longer
  # exists; and since 0318 the next `<Configure>` KEEPS that sentence instead of
  # scrubbing it, because the geometry path is deliberately no longer the thing
  # that cleans up after a failed navigation.
  #
  # ⚠ AND IT IS BEHAVIOURAL FOR A MEASURED REASON: the first cut of the fix added
  # the clear WITHOUT `variable browserseanote` in `browser_refresh`, which
  # addresses a LOCAL array — the write succeeds against nothing and the `catch`
  # hides it. A source grep for the clear would have passed. This check is what
  # sees the difference.
  pcall ::wviewer::browser_notice wvbz $bz_msg
  update
  set bz_f_pre [lindex [bz_note $BZC] 0]
  set bz_sig_was $::wviewer::browsersigs(wvbz)
  set ::wviewer::browsersigs(wvbz) {v(zz.elsewhere)}
  rename ::wviewer::browser_populate ::wviewer::browser_populate_bzsaved
  proc ::wviewer::browser_populate {tv rows} { error {BZ19 forced populate failure} }
  set bz_fref [pcall ::wviewer::browser_refresh wvbz 0]
  catch {rename ::wviewer::browser_populate {}}
  rename ::wviewer::browser_populate_bzsaved ::wviewer::browser_populate
  update
  set bz_f_note $::wviewer::browserseanote(wvbz)
  set bz_f_draw [bz_note $BZC]
  # ...and the geometry event that follows must not resurrect it either
  bz_spy_on
  bz_drag 336 240
  bz_spy_off
  update
  # ⚠⚠ LEG 4 IS `1`, NOT `none`, AND THE DIFFERENCE WAS MEASURED. A bail-out does
  # not REDRAW — it returns before the tail refresh — so the canvas still holds the
  # whole OLD pane: old cells, old sentence, and the two are consistent with each
  # other. Nothing on screen is a lie yet. What must not happen is the sentence
  # surviving INTO the next draw of the new snapshot, which is legs 6 and 7: the
  # resize redraws, and the notice is gone because the variable was cleared. The
  # first cut of this check expected `none` here and was wrong about the product.
  check {BZ19 a REFRESH THAT THREW clears the notice — the canvas it had already
         drawn is left alone, and the next draw (a resize) does not bring the
         sentence back} \
    [list $bz_f_pre $bz_fref $bz_f_note \
          [lindex $bz_f_draw 0] [lindex $bz_f_draw 1] \
          [expr {$::bz_nconf > 0}] [bz_note $BZC] \
          $::wviewer::browserseanote(wvbz)] \
    [list 1 0 {} 1 $bz_msg 1 none {}]
  set ::wviewer::browsersigs(wvbz) $bz_sig_was
  pcall ::wviewer::browser_refresh wvbz 0
  update

  # ⚠ PER TOKEN, AND THE KEEP IS NOT ALLOWED TO GO LOOKING. A capture that read the
  # array without keying on `$token` (an `array get` sweep, say) would keep ANOTHER
  # viewer's sentence on THIS viewer's resize, and a one-window fixture cannot see
  # it. No second toplevel is needed to say so: a second token's note is a value in
  # the same array.
  #
  # ⚠⚠ THE CAPTION SENTINEL IS WHAT MAKES THIS CHECK BITE, AND IT WAS MEASURED: the
  # first cut read only the canvas and the two variables, and the token-blind
  # mutation passed all 17 checks. The canvas cannot see it — `browser_sea_draw`
  # reads `browserseanote($token)`, which is correctly empty for THIS token — so the
  # only visible consequence is the KEPT-NOTICE EARLY RETURN firing on a token with
  # no notice, i.e. the pane never being re-captioned. The sentinel is how "the say
  # ran" becomes assertable.
  set ::wviewer::browserseanote(wvbzOTHER) {BZ20 another window's sentence}
  pcall $BZTV selection set [list {g:x1}]
  update
  catch {$BZST configure -text {BZ20-SENTINEL}}
  bz_spy_on
  bz_drag 240 336
  bz_spy_off
  update
  set bz_other [bz_note $BZC]
  check {BZ20 a resize with THIS token's notice empty keeps nothing — another
         token's sentence is not borrowed, the pane is still re-captioned, and the
         other token's own notice is untouched} \
    [list [expr {$::bz_nconf > 0}] $bz_other \
          $::wviewer::browserseanote(wvbz) \
          [$BZST cget -text] \
          $::wviewer::browserseanote(wvbzOTHER)] \
    [list 1 none {} {x1 has no signals of its own} \
          {BZ20 another window's sentence}]
  catch {unset ::wviewer::browserseanote(wvbzOTHER)}

  catch {destroy .wvbz1}
  pcall ::wviewer::forget wvbz
  catch {dict unset ::wviewer::windows wvbz}
} else {
  puts "SKIP: BZ1x need X (no \$has_x)"
}

wvbs_finish
