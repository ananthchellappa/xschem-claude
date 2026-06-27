# Course: The Wire That Wouldn't Complete

### An anatomy of an emergent, configuration-dependent bug — how it was born, why it
### hid, which assumptions sabotaged reproduction, and how it was finally fixed

This is a self-paced course built around a real fix in xschem (issue 0018, commit
`fix(wire): don't let selection-overlay redraw clobber manhattan_lines`). Read each
tiny section, then answer its self-test question from memory. The answers are at the
bottom, printed as **reflected (reversed) text** — readable with a little effort or a
mirror, so you commit before you peek. Don't reverse them with a tool on the first try.

Concept map: *shared mutable global state*, *side effects in drawing code*, *emergent
/ interaction bugs*, *faithful reproduction*, *false correlations from leftover state*,
*hollow green tests*, *root cause vs. call site*, *containment via save/restore*.

---

## 1. A bug is born: a drawing routine that writes shared state

Start with the smallest fact. `drawtemp_manhattanline()` exists to *paint* a wire as an
L-shaped (manhattan) pair of segments. To know which way the L bends it consults a global,
`xctx->manhattan_lines` (1 = horizontal-first, 2 = vertical-first). When asked to draw a
wire whose bend direction isn't known yet, it calls `recompute_orthogonal_manhattanline()`,
which *writes* `manhattan_lines` from that line's own dx/dy. So a function whose job is
"draw this line" also *mutates global program state* as a side effect. On its own that
looked harmless: the caller wanted the line drawn manhattan, and the global was "about to be
set anyway." That single design choice is the seed of the bug.

**Q1.** Why is it risky for a routine named `drawtemp_manhattanline` (a *drawing* function) to write to a global like `manhattan_lines`?

---

## 2. Ownership: who is the global *for*?

`manhattan_lines` is really *gesture state*: it belongs to the one wire or line the user is
currently drawing. It is set deliberately in `redraw_w_a_l_r_p_z_rubbers()` (the rubber-band
redraw of the active wire) and in `place_moved_wire()` (committing a moved wire). Those are
the legitimate owners, and crucially each recomputes the value *itself, right before it uses
it*. The trouble is that nothing in the type system or naming says "this global is owned by
the active gesture." Any code that calls `recompute...` — even to draw something unrelated —
silently takes the wheel.

**Q2.** What property of the legitimate owners (`redraw_w_a_l_r_p_z_rubbers`, `place_moved_wire`) ends up protecting them from the bug?

---

## 3. The collision: two features that never meant to meet

Now combine features. While you draw a new wire, every mouse motion repaints the rubber
band, and *under* it the selection overlay is redrawn so selected objects stay visible:
`new_wire(RUBBER)` -> `restore_selection()` -> `draw_selection()`. For a selected *wire*,
`draw_selection()` strokes it with `drawtemp_manhattanline(..., force_manhattan=1)`. That
`force_manhattan=1` recomputes `manhattan_lines` from the *selected* wire's geometry — on
every motion of the wire you are drawing. A vertical selected wire forces vertical-first
while you draw horizontally. Two unrelated features (selection highlighting and orthogonal
wire drawing) share one global, and the highlight quietly overwrites the draw.

**Q3.** Name the two independently-reasonable features that, by sharing one global, combine into the bug.

---

## 4. From corruption to symptom: how 'wire vanishes' happens

A clobbered global doesn't always show. With `persistent_command` on (the reported config),
the completing click runs `start_wire()`, which copies `constr_mv = manhattan_lines` and
then *constrains* the rubber endpoint to one axis. With the wrong (vertical-first) value, a
horizontal wire's endpoint is snapped back to its start x: the segment becomes zero-length,
so `new_wire(PLACE)` stores nothing. The rubber band keeps following; the wire never lands.
The same corruption with `persistent_command` *off* merely draws an odd L but still stores —
so the visible symptom depends on yet another setting.

**Q4.** Why did the failure show up as 'cannot complete the wire' specifically under `persistent_command`, when a plain click-to-place mode would still have stored a wire?

---

## 5. Why these bugs hide: emergence, not a single faulty line

No single line here is 'wrong.' `drawtemp_manhattanline` correctly draws an L.
`draw_selection` correctly repaints selection. `start_wire` correctly applies a manhattan
constraint. The defect is *emergent*: it appears only at the intersection of orthogonal
wiring + a selected wire + a perpendicular new wire + persistent mode. Each feature was
tested in isolation and worked. Bugs like this live in the spaces *between* features, which
is exactly where unit tests and code review tend not to look.

**Q5.** Why can every individual function involved be 'correct' while the program still has a real bug?

---

## 6. The first trap: reproducing with the wrong assumptions

The investigator first tried to reproduce with hand-picked settings (cadence on, infix off)
and *could not* — across many combinations the wire always completed. The hidden assumption
was that the defaults under test matched the user's environment. They did not: the real
trigger lived in `src/cadence_style_rc` (`orthogonal_wiring 1`, `persistent_command 1`,
...). A bug you can't reproduce is a bug you can't understand; and you can't reproduce what
you mis-configure.

**Q6.** What single assumption about the *environment* blocked reproduction for most of the investigation?

---

## 7. The second trap: false signals from shared process state

An early script ran the 'selected' and 'not selected' cases back-to-back in one process and
showed a clean 'selection breaks it' split — convincing, and wrong. A different global
(`prev_rubber`) carried over between the two runs, manufacturing the correlation. Running
each case in its *own process* erased it. Lesson: state that outlives one logical operation
will happily fake a correlation between unrelated things.

**Q7.** How did running each case in a separate process change the conclusion, and what does that tell you about back-to-back tests?

---

## 8. The third trap: a green test that proves nothing useful

Mid-investigation a fix was written (resetting `prev_rubber`) with a test that passed and
was even sabotage-checked. It was still the *wrong* fix: it addressed a narrow, different
edge case that was never the user's bug. A green test only certifies the scenario it
encodes. If that scenario isn't the user's actual failure, green means 'my unrelated thing
works,' not 'the bug is fixed.'

**Q8.** A fix had a passing, sabotage-verified test and was still wrong. What did the green test fail to guarantee?

---

## 9. Turning the lights on: trace the value, not the vibes

Once reproduced, the method was blunt and decisive: print `manhattan_lines` and log *every*
call to `recompute_orthogonal_manhattanline` with its inputs. The log showed two recomputes
per motion — one for the wire being drawn (correct, =1) and one on the selected wire's
coordinates (=2) that ran last and won. Instrumenting the exact suspect value converts an
argument about what 'should' happen into a record of what *did*.

**Q9.** Why is logging the actual value and its writers more reliable than reasoning about what the dispatch 'should' do?

---

## 10. Root cause vs. call site: fix the source

The first instinct was to save/restore `manhattan_lines` around the one `draw_selection`
call in `restore_selection`. It failed: `draw_selection` is reached from many call sites, so
the leak persisted. The leak's *source* is `drawtemp_manhattanline` itself. Fixing there —
save on entry, restore after drawing when `force_manhattan` was set — plugs it for every
caller at once. Prefer the narrowest point that covers *all* paths, not the first path you
happen to be looking at.

**Q10.** Why did wrapping the `restore_selection` call site fail, and why is `drawtemp_manhattanline` the right place instead?

---

## 11. Don't break the honest callers

Save/restore is only safe if no caller *relied* on the leak. The check: the move-commit path
(`place_moved_wire`) and the live wire/line draw both recompute `manhattan_lines` themselves
before reading it, so they never depended on `drawtemp` leaving it behind. That is why the
orthogonal move/gesture tests stayed green. Before neutralizing a side effect, prove nobody
downstream was (accidentally) depending on it.

**Q11.** Before removing a side effect, what must you verify about the code that runs after it?

---

## 12. Proving the fix: make red, then green

The regression test drives the real press/motion/release dispatch under the reported config,
asserting a perpendicular wire completes with a wire selected (and the symmetric direction,
plus a nothing-selected guard). It is *sabotage-verified*: deleting the restore line turns
the selected-wire cases red while the guard stays green. A test you have never seen fail for
the right reason is not yet a regression test.

**Q12.** What does sabotage-verification (deleting the fix and watching the test go red) prove that a merely-passing test does not?

---

## 13. The transferable lesson

Shared mutable global state + a helper that writes it as a side effect = action at a
distance. The cure pattern is containment: a transient operation that must touch shared
state should save it and restore it, so it cannot corrupt the state's true owner. When you
must hunt such a bug: reproduce faithfully first (right config, isolated process), trace the
real value, fix at the source, prove no honest caller depended on the side effect, and make
the test fail before it passes.

**Q13.** State, in one sentence, the general containment rule this bug teaches for transient code that must touch shared global state.

---

## Answers (reflected text — read right-to-left, or hold to a mirror)

Each line is the answer with its characters reversed. Decode the ones you want to check.

**A1.** `.)ecnatsid a ta noitca( noitarepo evitca eht reets yltnelis tniaper detalernu na stel ti gnitirw repleh gniward a ;nward gnieb si eriw revetahw yb denwo etats erutseg si labolg taht esuaceB`

**A2.** `.meht tceffa ot hguone gnol evivrus tonnac eulav derebbolc ro elats a os ,ti sdaer ti erofeb yletaidemmi flesti senil_nattahnam setupmocer renwo etamitigel hcaE`

**A3.** `.sdeen ward eht eulav eht setirwrevo tniaper thgilhgih eht os ,labolg eno erahs yeht ;)senil_nattahnam( gniward eriw lanogohtro dna )seriw detceles gniwarder noitceles_ward( gnithgilhgih noitceleS`

**A4.** `.eriw )tneb-sim( eht erots llits dluow edom ecalp nialp elihw ,htgnel orez ot tnemges ralucidneprep eht sespalloc sixa gnorw eht ;sixa eno ot rebbur eht sniartsnoc dna vm_rtsnoc otni senil_nattahnam seipoc eriw_trats s'edom tnetsisrep esuaceB`

**A5.** `.kool ylerar weiver dna stset tinu erehw ,meht neewteb ecaps eht ni sevil gub eht ;enola tcerroc hcae ,serutaef lareves fo noitcaretni eht ni ylno stsixe ti :tnegreme si tcefed eht esuaceB`

**A6.** `.delbane reven stset ylrae eht hcihw ,)dnammoc_tnetsisrep dna gniriw_lanogohtro( sgnittes cr_elyts_ecnedac eht saw reggirt laer eht ;s'resu eht dehctam tset rednu noitarugifnoc eht taht noitpmussa ehT`

**A7.** `.esac hcae etalosi os ,snoitalerroc erutcafunam nac etats devil-gnol ;knil noitceles eht dekaf dna snur neewteb dekael )rebbur_verp( labolg tnereffid a :noitalerroc eslaf a devomer tI`

**A8.** `.xif detalernu na deifitrec ti os ,decudorper neeb reven dah hcihw ,eruliaf lautca s'resu eht saw oiranecs taht eetnaraug ton did ti ;skrow oiranecs dedocne eht taht ylno deetnaraug tI`

**A9.** `.now yllautca taht eriw detceles eht no etupmocer artxe eht gnisopxe ,neppah did tahw sdrocer retirw yreve dna eulav tcepsus eht gniggol ;neppah dluohs tahw setats gninosaer esuaceB`

**A10.** `.srellac lla srevoc ereht gnixif os ,etupmocer eht fo ecruos elgnis eht si enilnattahnam_pmetward ;esle erehwyreve kael eht sevael eno gnidraug os ,setis llac ynam morf dehcaer si noitceles_ward`

**A11.** `.meht kaerb tonnac kael eht gnivomer os ,sevlesmeht senil_nattahnam etupmocer shtap ward-evil dna timmoc-evom eht ereh :tceffe edis eht no dedneped edoc maertsnwod on tahT`

**A12.** `.)tset wolloh a( gub eht ot detalernu snosaer rof neerg eb dluoc tset gnissap-ylerem a ;noisserger a hctac dluow dna xif eht sesicrexe yllautca tset eht sevorp tI`

**A13.** `.renwo laer s'etats eht tpurroc reven nac ti os ,tixe no ti erotser dna yrtne no eulav eht evas dluohs etats labolg derahs hcuot tsum taht edoc tneisnarT`
