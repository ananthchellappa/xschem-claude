/* File: spice_netlist.c
 *
 * This file is part of XSCHEM,
 * a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
 * simulation.
 * Copyright (C) 1998-2024 Stefan Frederik Schippers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#include "xschem.h"

static Str_hashtable model_table = {NULL, 0}; /* safe even with multiple schematics */

static const char *hier_psprint_mtime(const char *file_name)
{
  static char date[200];
  struct stat time_buf;
  struct tm *tm;
  my_strncpy(date, "xxxxxxxx_xxxxxx", S(date));
  if(!stat(file_name , &time_buf)) {
    tm=localtime(&(time_buf.st_mtime) );
    strftime(date, sizeof(date), "%Y%m%d_%H%M%S", tm);
  }
  dbg(1, "hier_psprint_mtime(): file_name=%s, date=%s\n", file_name, date);
  return date;
}

/* --------------------------------------------------------------------------
 * ⚠ THE ISSUE NUMBERS IN THIS FILE'S HIERARCHICAL-PDF COMMENTS ARE THE `op-wcard`
 * BRANCH'S NUMBERING, NOT THIS TREE'S.  DO NOT FOLLOW ONE INTO doc/claude/issues/.
 *
 * This code was ported to `fluid-editing` on 2026-09-24 from a finished batch on the
 * `op-wcard` branch. That batch's directory (doc/claude/hier_pdf_links_batch/) and its
 * eighteen issue files stayed there and are NOT in this clone -- deliberately, because
 * EVERY number they use, 1333 through 1360, is already taken HERE by a completely
 * unrelated defect: 1333 here is an op-dump reader with no caller, 1342 a simcaps
 * count, 1350 an annotation-order dump. A reader who follows one of these numbers into
 * this tree's doc/claude/issues/ will find a real file about something else entirely.
 * Read the real ones on the branch that has them:
 *     git -C <an op-wcard clone> show op-wcard:doc/claude/issues/1334-*.md
 *     git -C <an op-wcard clone> show \
 *         op-wcard:doc/claude/hier_pdf_links_batch/DECISIONS.md
 * Nothing has been renumbered, on purpose: the eighteen colliding files are committed
 * in both trees and cited from source comments and commit messages in both. Who moves,
 * if anyone, is the USER'S ruling -- carried as issue 1400 in this tree and issue 1347
 * on op-wcard, both still open.
 * ------------------------------------------------------------------------ */
/* ---------------------------------------------------------------------------
 * ISSUE 1334, THE PAGE-DESTINATION NAME SET.  Item H1b of
 * the op-wcard branch's doc/claude/hier_pdf_links_batch/, ruling DD-6.
 *
 * psprint.c's pdfmark emitter writes a `/Dest /<name> /Subtype /Link` annotation
 * for every subcircuit/primitive instance it draws, and until this set existed it
 * had no way to know whether the export would contain a page of that name. When it
 * does not, the click is a silent no-op: Ghostscript neither warns nor drops the
 * annotation, so to a reviewer the document simply reads as broken.
 *
 * TWO EARLIER ATTEMPTS ASKED THE WRONG QUESTION AND WERE BOTH REFUTED. They asked
 * "would this cell pass hier_psprint()'s page filter?" and re-derived the filter
 * (type / noprint_libs / default_schematic) from the instance's BASE symbol -- but
 * get_additional_symbols() (actions.c:5451) MINTS a separate symbol for every
 * instance-level `schematic=` override and deletes its default_schematic
 * (actions.c:5583-5587), and it is the MINTED symbol the loop below pages. Reading
 * one object and vetting the other fails in both directions, and it deleted LIVE
 * links from shipped files (xschem_library/examples/tb_test_evaluated_param.sch
 * went 2 live links -> 0 while still printing both its pages).
 *
 * SO DO NOT ASK THAT QUESTION. Ask the one that is true by construction:
 *
 *     emit a link only if this export really does contain a page whose
 *     destination name equals this link's destination name.
 *
 * Both names are minted by the SAME call, get_cell_w_ext(sanitize(...)):
 * psprint.c:1657 for the page anchor, psprint.c's pdfmark block for the link. So
 * the walk is run once in a collect-only mode (`what & 4`) that takes every branch
 * the print pass takes -- same noprint_libs filter, same subckt_table dedup, same
 * load_schematic() -- but records the anchor name instead of drawing the page. The
 * printer then does a hash lookup. Nothing reasons about WHY a page is absent, so
 * there is no second copy of the filter to drift out of agreement and no
 * base-vs-minted ambiguity left to get wrong.
 *
 * The set is deliberately keyed on exactly what the PDF keys on: a /Dest name is a
 * flat basename, so two cells of the same name in different libraries share one
 * destination. If any of them gets a page, the link DOES navigate, and keeping it
 * is correct -- the lookup can therefore never suppress a link that works.
 *
 * The cost is one extra hierarchy walk per hierarchical print (the pages are not
 * drawn; the schematics are loaded). Measured in receipts/H1b.md.
 *
 * pspage_set_valid is 0 for every caller that is not a hierarchical print, and
 * hier_psprint_dest_exists() then answers "yes" so single-page `xschem print`
 * (ps_draw(7,...), which emits no pdfmarks at all) and any future caller keep
 * today's behaviour rather than silently losing every link. */
static Str_hashtable pspage_table = {NULL, 0};
static int pspage_set_valid = 0;
/* how many distinct pages this export will contain. Item H6 needs it: a hierarchical print
 * of a schematic with no printable children is a ONE-PAGE document, and a Back button on a
 * one-page document is ink with nowhere to go. Counted here rather than by walking the hash,
 * because XINSERT_NOREPLACE already tells us whether the insert was new. */
static int pspage_count = 0;

/* ---------------------------------------------------------------------------
 * RULE-1 / ISSUE 1338, THE SCOPED HIGHLIGHT.  Item H4 of
 * the op-wcard branch's doc/claude/hier_pdf_links_batch/.  The USER RULED, 2026-09-10, verbatim:
 *
 *     "Only a symbol for a non-PDK cell that has real hierarchy (worth
 *      descending into) should have the clickable link highlight in the PDF"
 *
 * Item H3 shipped the border invisible (`ps_link_border 0`) pending exactly that
 * ruling, so this is the first change in the batch that deliberately alters what
 * a user's export looks like. Mechanically:
 *
 *     advertise a link iff its TARGET page itself contains at least one
 *     instance that also gets a page, AND the target is not in an excluded
 *     (PDK) library.
 *
 * ⚠ THE HIGHLIGHT IS SCOPED; THE LINK IS NOT. Removing the unadvertised links
 * would recreate issue 1335 (a page nothing links to) and break H1b's invariant
 * that a link exists iff a page of that name does -- the control every item in
 * this batch has been judged on. A leaf page stays clickable; it is simply not
 * advertised. Rows S82/S85 of tests/headless/test_hier_pdf_links_1333.tcl
 * assert the link set and page set are untouched.
 *
 * WHY IT LIVES HERE AND NOT IN psprint.c. Condition A is a question about the
 * DOCUMENT -- "does the target page have a paged child?" -- and the only thing
 * that knows the document is the walk that builds it. The `what & 4` collect
 * pass (issue 1334, above) already visits every page exactly once; while it is
 * standing on a page it also records one edge per instance that could carry a
 * link. Once the walk is done and the page set is complete, the edges are
 * resolved in one pass: a page is hierarchical iff one of its edges names a
 * page. NO THIRD WALK, and no second copy of any filter (DD-2): the edge's
 * child name is minted by hier_psprint_inst_dest() below, which is the SAME
 * function psprint.c's emitter calls to mint the /Dest it writes. If the two
 * ever disagreed the emitter would link one cell and the scope would reason
 * about another, which is the base-vs-minted confusion that refuted H1 and H1-2
 * (ruling DD-6). One function, two callers, so they cannot drift.
 *
 * ALIASING, STATED RATHER THAN LEFT IMPLICIT. Every table here is keyed on the
 * flat /Dest basename, because that is what a PDF destination IS -- two
 * same-named cells from different libraries share one destination. In practice
 * one destination gets exactly one page (the `subckt_table` dedup in the loop
 * below), so the question is nearly academic; where it is not, the union is
 * taken across homonyms and it is taken SEPARATELY for the two halves. A page
 * that is hierarchical under either name is worth descending into, and a
 * destination reachable under a non-excluded name is advertised. Both are the
 * permissive direction, i.e. the direction that shows a reviewer a box rather
 * than hiding one; nothing here can suppress a link, only its border.
 *
 * THE LIBRARY TEST is matched against the target page's SCHEMATIC path, not its
 * symbol path -- a page is a schematic, and this way the top page and every
 * child are tested identically with no special case. A `noprint_libs`-style
 * library pattern (`/sky130_fd_pr/`) matches either path; a pattern anchored on
 * `\.sym$` would not, and that is the one behavioural difference from
 * `noprint_libs` a reader has to know. Default list and the reasoning for it:
 * src/xschem.tcl, beside `set_ne ps_link_border`. */
static Str_hashtable psedge_table = {NULL, 0}; /* "<parent dest>\n<child dest>" */
static Str_hashtable pshier_table = {NULL, 0}; /* dests that qualify for the highlight */

/* ---------------------------------------------------------------------------
 * ITEM H6 -- THE PARENT MAP, AND WHY IT IS NOT A NEW WALK.  The user asked for
 * this twice and until now it did not exist:
 *
 *     "How difficult to add references on a child cell to have links to parent
 *      schematics?" ... "did we succeed in putting Back buttons? I know Alt-Left
 *      is a back button, but a clickable button means user can keep one hand on
 *      the mouse"
 *
 * Every link this feature wrote was one-way, symbol -> child. psprint.c now draws
 * a navigation strip on every page: a Back button (a PDF named action, which is
 * the viewer's own history Back) and a list of the sheets that instantiate this
 * cell. The list is a LIST because a cell instantiated in five places has five
 * parents -- on sky130_tests_ase/tb_bandgap, `not` is instantiated in `bandgap`
 * AND in `bandgap_opamp`, and a design that assumed one parent gets that wrong.
 *
 * THE RELATION IS ALREADY COMPUTED. psedge_table above holds one edge per
 * instance per page, recorded by item H4 to answer "does this page have paged
 * children?" -- condition A of RULE-1. Read the other way round, the SAME edge
 * set IS the parent map, so this item adds no walk, no load and no second copy of
 * hier_psprint_inst_dest()'s rule (DD-2). It resolves both directions in the one
 * pass that already existed.
 *
 * ⚠ ONE THING HAD TO MOVE, AND IT IS THE ONLY BEHAVIOURAL RISK IN THIS FILE.
 * Item H4 skipped recording edges AT ALL for a page in an excluded (PDK) library,
 * because condition B needs no edges and the library test then costs one Tcl call
 * per page instead of one per edge. That is right for the HIGHLIGHT and wrong for
 * the PARENT MAP: a child instantiated only by an excluded page would lose the
 * reference to the page that really contains it, which is a structural fact, not
 * an advertisement. So the edge is now always recorded and the exclusion travels
 * in the entry's VALUE ("x"), which hier_psprint_resolve_hier() reads for
 * condition A and the parent map ignores. The Tcl call stays once per page.
 * Suite rows S81a-S81e are the fence on condition A being unchanged by this. */
static Str_hashtable psparent_table = {NULL, 0}; /* child dest -> "\n"-joined parents */

/* `ps_hier_nav`: 0 = no strip, 1 = Back button only, 2 = parent references only,
 * 3 = both.  THE SHIPPED DEFAULT IS 0 -- the user ruled on 2026-09-24 that this
 * branch takes the export FIX with the new visible navigation OFF, because its
 * presentation is unratified. The long note beside `set_ne ps_hier_nav none` in
 * src/xschem.tcl is the record; do not flip either of them alone.
 * Read ONCE PER EXPORT beside ps_link_border, never once per page or per link
 * (issue 1346). */
static int psnav_mode = 0;

/* 0 = no border on any link, 1 = the ruling, 2 = a border on every link.
 * READ ONCE PER EXPORT, in hier_psprint() below, NOT once per link -- issue 1346
 * records that H3's two preferences are read from Tcl once per annotation
 * (313 Tcl round trips on 0_examples_top) and this item was told not to make
 * that worse. It does not: it makes it better by one, because the border string
 * psprint.c used to build with tclgetboolvar() per link now comes from
 * hier_psprint_link_border() with no Tcl at all. `ps_link_bbox` is still read
 * per link; that is 1346's, not this item's, and it is untouched here. */
static int pslink_border_mode = 1;

/* Does `path` match any regexp in $ps_link_noborder_libs?  Deliberately the same
 * shape as check_lib() (netlist.c:616-640) -- same llength/lindex/regexp idiom,
 * so a user who knows noprint_libs knows this one. It is NOT check_lib(8, ...)
 * because ruling DD-1 does not let this batch touch netlist.c: the batch's whole
 * value is that it cherry-picks onto `fluid-editing` without a source conflict.
 * If this outlives the batch it belongs in check_lib() as another bit.
 * Called once per PAGE, not once per link. */
static int ps_link_lib_excluded(const char *path)
{
  int range, i, found = 0;
  char str[PATH_MAX + 512];
  if(!path || !path[0]) return 0;
  /* guarded: psprint.c and xschem.tcl are two files, and an emitter that landed
   * without the `set_ne` line must not raise a Tcl error per page. */
  tcleval("if {[info exists ps_link_noborder_libs]} {llength $ps_link_noborder_libs} else {expr {0}}");
  range = atoi(tclresult());
  for(i = 0; i < range; ++i) {
    my_snprintf(str, S(str), "lindex $ps_link_noborder_libs %d", i);
    tcleval(str);
    my_snprintf(str, S(str), "regexp {%s} {%s}", tclresult(), path);
    tcleval(str);
    if(tclresult()[0] == '1') found = 1;
  }
  dbg(1, "ps_link_lib_excluded(): %s -> %d\n", path, found);
  return found;
}

/* THE ONE PLACE A LINK'S DESTINATION NAME IS MINTED.  Returns the /Dest name the
 * pdfmark emitter would write for instance `n`, or NULL if that instance can
 * carry no link at all. psprint.c's ps_link_pdfmark() calls it to build the
 * annotation it writes; hier_psprint_record_dest() below calls it to build the
 * parent->child edges condition A is resolved from. Two callers, one rule --
 * ruling DD-2, and the reason H4 could not simply re-ask "is this cell
 * hierarchical?" at the emitter.
 *
 * The three tests are H1a's and H1b's, unchanged and in their order:
 *   - `type` guarded, because a symbol with no `type=` attribute used to
 *     segfault the whole export (issue 1333);
 *   - subcircuit OR primitive, because hier_psprint() pages both (issue 1335);
 *   - the file resolved from the INSTANCE via get_sch_from_sym(..., n, ...),
 *     because get_additional_symbols() mints a separate symbol for every
 *     instance-level `schematic=` override and it is the MINTED symbol that gets
 *     paged. Passing -1 here asks the base symbol, which is exactly the
 *     base-vs-minted confusion that refuted H1 and H1-2 (DD-6) -- and now it
 *     would ALSO mis-scope the highlight. Suite row S84.
 * INST_UNBOUND is checked first: ps_draw_symbol() returns on it long before the
 * emitter, but the collect pass walks every instance and xctx->sym[-1] is a
 * read off the front of the array (issue 0498's shape). */
const char *hier_psprint_inst_dest(int n)
{
  static char dest[PATH_MAX];
  char fname[PATH_MAX];
  const char *type;

  if(n < 0 || n >= xctx->instances) return NULL;
  if(INST_UNBOUND(n)) return NULL;
  type = xctx->sym[xctx->inst[n].ptr].type;
  if(!type) return NULL;                                                /* issue 1333 */
  if(strcmp(type, "subcircuit") && strcmp(type, "primitive")) return NULL; /* issue 1335 */
  get_sch_from_sym(fname, xctx->inst[n].ptr + xctx->sym, n, 0);
  my_strncpy(dest, get_cell_w_ext(sanitize(fname), 0), S(dest));
  return dest;
}

/* Record the destination name ps_draw(2, ...) mints for the page now loaded.
 * MUST use the same expression as psprint.c's /DEST anchor, or the set will not
 * match what the emitter looks up.
 *
 * ALSO records this page's outgoing edges (RULE-1, condition A). The page's own
 * instances are loaded right now -- this is the only moment in the whole export
 * at which they are -- so the edges cost no extra load and no extra walk. They
 * cannot be RESOLVED yet: page 1's children are paged later, so membership of
 * the destination set is only decidable once the walk has finished. That is what
 * hier_psprint_resolve_hier() does.
 *
 * A page in an excluded library records NO edges, which is condition B: no
 * edges, no hierarchy, no highlight. Doing it here rather than at resolution
 * time means the library test runs once per page (a handful of Tcl calls)
 * instead of once per edge. */
static void hier_psprint_record_dest(void)
{
  char dest[PATH_MAX];
  int i, excl;
  my_strncpy(dest, get_cell_w_ext(sanitize(xctx->current_name), 0), S(dest));
  dbg(1, "hier_psprint_record_dest(): |%s|\n", dest);
  if(str_hash_lookup(&pspage_table, dest, "", XINSERT_NOREPLACE) == NULL) ++pspage_count;
  excl = ps_link_lib_excluded(xctx->sch[xctx->currsch]);         /* RULE-1 condition B */
  for(i = 0; i < xctx->instances; ++i) {
    const char *child = hier_psprint_inst_dest(i);
    if(child && child[0]) {
      char edge[PATH_MAX * 2];
      my_snprintf(edge, S(edge), "%s\n%s", dest, child);
      /* ITEM H6: the edge is recorded either way and the exclusion rides in the value.
       * Condition A skips an "x" edge, so the highlight is exactly what H4 shipped; the
       * parent map reads them all, because "which sheet contains this cell" is a fact
       * about the document and not an advertisement. */
      str_hash_lookup(&psedge_table, edge, excl ? "x" : "", XINSERT_NOREPLACE);
    }
  }
}

static int ps_edge_cmp(const void *a, const void *b)
{
  return strcmp(*(char * const *)a, *(char * const *)b);
}

/* Resolve the edges once the destination set is complete. TWO answers out of ONE
 * pass over the edges item H4 already records:
 *   condition A (the highlight) -- a page is worth descending into iff at least one
 *     of its own instances also gets a page. An "x" edge (a page in an excluded
 *     library, item H6's note above) does not count, which is exactly H4's rule.
 *   the PARENT MAP (item H6) -- the same edges read backwards, child -> parents.
 * Runs once per export, over a few hundred edges.
 *
 * The parent lists are SORTED, and that is not cosmetic: hash iteration order is
 * arbitrary, and an arbitrary order would put a different name first in the printed
 * strip depending on where a cell happened to land in the table. It also makes the
 * export reproducible, which is what every byte-comparison control in this batch
 * rests on. */
static void hier_psprint_resolve_hier(void)
{
  int b, i, n = 0;
  char **arr = NULL;
  char cur[PATH_MAX];
  char *val = NULL;

  str_hash_free(&pshier_table);
  str_hash_init(&pshier_table, HASHSIZE);
  str_hash_free(&psparent_table);
  str_hash_init(&psparent_table, HASHSIZE);
  for(b = 0; b < psedge_table.size; ++b) {
    Str_hashentry *e;
    for(e = psedge_table.table[b]; e; e = e->next) {
      const char *sep = strchr(e->token, '\n');
      if(!sep) continue;
      if(!(e->value && e->value[0] == 'x') &&
         str_hash_lookup(&pspage_table, sep + 1, "", XLOOKUP)) {
        char parent[PATH_MAX];
        size_t len = (size_t)(sep - e->token);
        if(len >= sizeof(parent)) len = sizeof(parent) - 1;
        memcpy(parent, e->token, len);
        parent[len] = '\0';
        dbg(1, "hier_psprint_resolve_hier(): |%s| is hierarchical\n", parent);
        str_hash_lookup(&pshier_table, parent, "", XINSERT_NOREPLACE);
      }
      ++n;
    }
  }
  if(n <= 0) return;
  arr = my_malloc(_ALLOC_ID_, sizeof(char *) * (size_t)n);
  i = 0;
  for(b = 0; b < psedge_table.size; ++b) {
    Str_hashentry *e;
    for(e = psedge_table.table[b]; e; e = e->next) {
      const char *sep = strchr(e->token, '\n');
      char parent[PATH_MAX], inv[PATH_MAX * 2];
      size_t len;
      if(!sep || i >= n) continue;
      len = (size_t)(sep - e->token);
      if(len >= sizeof(parent)) len = sizeof(parent) - 1;
      memcpy(parent, e->token, len);
      parent[len] = '\0';
      my_snprintf(inv, S(inv), "%s\n%s", sep + 1, parent); /* child \n parent */
      arr[i] = NULL;
      my_strdup(_ALLOC_ID_, &arr[i], inv);
      ++i;
    }
  }
  n = i;
  qsort(arr, (size_t)n, sizeof(char *), ps_edge_cmp);
  cur[0] = '\0';
  for(i = 0; i < n; ++i) {
    char *sep = arr[i] ? strchr(arr[i], '\n') : NULL;
    if(!sep) continue;
    *sep = '\0';
    if(strcmp(arr[i], cur)) {
      if(cur[0]) str_hash_lookup(&psparent_table, cur, val ? val : "", XINSERT);
      my_free(_ALLOC_ID_, &val);
      my_strncpy(cur, arr[i], S(cur));
    }
    if(val) my_strcat(_ALLOC_ID_, &val, "\n");
    my_strcat(_ALLOC_ID_, &val, sep + 1);
  }
  if(cur[0]) str_hash_lookup(&psparent_table, cur, val ? val : "", XINSERT);
  my_free(_ALLOC_ID_, &val);
  for(i = 0; i < n; ++i) my_free(_ALLOC_ID_, &arr[i]);
  my_free(_ALLOC_ID_, &arr);
}

/* ITEM H6. The sheets that instantiate the page whose destination name is `dest`,
 * newline separated and sorted, or NULL when there are none -- which is what the TOP
 * page of every export gets, and why it shows no `Up:` line. NULL for any caller that
 * is not a hierarchical print, so a single-page `xschem print` is untouched. */
const char *hier_psprint_page_parents(const char *dest)
{
  Str_hashentry *e;
  if(!pspage_set_valid || !dest || !dest[0]) return NULL;
  e = str_hash_lookup(&psparent_table, dest, "", XLOOKUP);
  if(!e || !e->value || !e->value[0]) return NULL;
  return e->value;
}

/* `ps_hier_nav`: none | back | up | both, with the boolean spellings accepted at the
 * two ends. THE SHIPPED DEFAULT IS `none` (src/xschem.tcl) -- the user's 2026-09-24
 * ruling, because the strip's presentation is unratified.
 *
 * ⚠ UNSET AND UNRECOGNISED ARE NOT THE SAME ANSWER, deliberately:
 *   - UNSET or EMPTY -> `none`. Nobody asked for the strip, so nothing new appears on
 *     an exported page. This is the only route by which the shipped default could be
 *     bypassed (an xschemrc doing `unset ps_hier_nav` after xschem.tcl's set_ne), and
 *     it must land on the same answer the set_ne does or "off by default" is not true.
 *     Row N24.
 *   - UNRECOGNISED (`sideways`, a typo) -> `both`. Here the user DID ask for the strip
 *     and mistyped which half, so silently deleting the navigation would hide their own
 *     request from them (H4's row S91, same rule). Row N14.
 * Read ONCE PER EXPORT (issue 1346). */
static void hier_psprint_read_nav_mode(void)
{
  const char *m = tclgetvar("ps_hier_nav");
  if(!m || !m[0]) psnav_mode = 0;
  else if(!strcmp(m, "none") || !strcmp(m, "0") || !strcmp(m, "no") ||
          !strcmp(m, "off")  || !strcmp(m, "false")) psnav_mode = 0;
  else if(!strcmp(m, "back")) psnav_mode = 1;
  else if(!strcmp(m, "up"))   psnav_mode = 2;
  else psnav_mode = 3;
  dbg(1, "hier_psprint_read_nav_mode(): |%s| -> %d\n", m ? m : "(unset)", psnav_mode);
}

/* 0 unless a hierarchical print owns a destination set: the SAME gate the /Link
 * emitter uses, so `xschem print` and every non-hierarchical caller keep exactly
 * today's output.
 *
 * ⚠ AND 0 ON A ONE-PAGE EXPORT, WHICH IS TWO THIRDS OF THE SHIPPED TREE. `xschem
 * hier_psprint` on a schematic with no printable children produces ONE page: there is
 * nothing to go back to, nothing above it, and a Back button there is ink that can never
 * do anything. Measured over 321 sheets: 216 of them are single-page, so without this the
 * feature would have put a dead button on two thirds of every export anyone runs -- and
 * the FIRST version of this item shipped exactly that, with 23 rows passing, because every
 * fixture in the suite was hierarchical. Row N23. It also means a one-page export stays
 * byte-identical to the pre-H6 binary. */
int hier_psprint_nav_mode(void)
{
  return (pspage_set_valid && pspage_count > 1) ? psnav_mode : 0;
}

/* `ps_link_border`: THREE states, not two, and the spelling is argued in
 * the op-wcard branch's doc/claude/hier_pdf_links_batch/receipts/H4.md.
 *   none / 0  -- no border on any link. H3's shipped default, and the way back.
 *   hier      -- the ruling. THE NEW DEFAULT.
 *   all  / 1  -- a border on every link. H3's `ps_link_border 1`, byte for byte.
 * `0` and `1` still parse, so an xschemrc written against H3 keeps meaning what
 * it meant. Anything unrecognised takes the default rather than silently
 * disabling the feature. Read ONCE PER EXPORT (issue 1346). */
static void hier_psprint_read_border_mode(void)
{
  const char *m = tclgetvar("ps_link_border");
  if(!m || !m[0]) pslink_border_mode = 1;
  else if(!strcmp(m, "none") || !strcmp(m, "0") || !strcmp(m, "no") ||
          !strcmp(m, "off")  || !strcmp(m, "false")) pslink_border_mode = 0;
  else if(!strcmp(m, "all")  || !strcmp(m, "1") || !strcmp(m, "yes") ||
          !strcmp(m, "on")   || !strcmp(m, "true"))  pslink_border_mode = 2;
  else pslink_border_mode = 1;
  dbg(1, "hier_psprint_read_border_mode(): |%s| -> %d\n", m ? m : "(unset)", pslink_border_mode);
}

/* The /Border (and /C) keys psprint.c's ONE pdfmark fprintf writes for a link to
 * `dest`. No Tcl, no computation: the scope decision was made once per export by
 * the collect pass, and this is a hash lookup.
 *
 * `all` deliberately ignores the library list. It is the escape hatch -- "give me
 * H3's behaviour" -- not a second scope, and a hatch that quietly applied half a
 * filter would not be one. Suite row S87.
 *
 * With no valid destination set (no hierarchical export owns one) the `hier` mode
 * cannot know what the document contains, so it answers "not advertised": the
 * conservative direction, and exactly H3's shipped output. */
const char *hier_psprint_link_border(const char *dest)
{
  if(pslink_border_mode == 2) return "/Border [0 0 1] /C [0 0 1] ";
  if(pslink_border_mode == 1 && pspage_set_valid && dest && dest[0] &&
     str_hash_lookup(&pshier_table, dest, "", XLOOKUP) != NULL) {
    return "/Border [0 0 1] /C [0 0 1] ";
  }
  return "/Border [0 0 0] ";
}

/* The only question psprint.c's pdfmark emitter asks. */
int hier_psprint_dest_exists(const char *dest)
{
  if(!pspage_set_valid) return 1; /* no walk owns a set: today's behaviour */
  if(!dest || !dest[0]) return 0;
  return str_hash_lookup(&pspage_table, dest, "", XLOOKUP) != NULL;
}

/*
 * what:
 * 1 : ps/pdf print
 * 2 : list hierarchy
 * 4 : collect the page destination names a `what & 1` run would emit (H1b, above).
 *     Draws nothing and writes no file; takes the print pass's noprint_libs filter.
 */
void hier_psprint(char **res, int what)  /* netlister driver */
{
  int i, save;
  char *subckt_name;
  char filename[PATH_MAX];
  char *abs_path = NULL;
  struct stat buf;
  Str_hashtable subckt_table = {NULL, 0};
  int save_prev_mod = xctx->prev_set_modify;
  /* issue 0498: caller's xctx->no_undo, parked while this walk owns the undo slot */
  int undo_saved;

  if(what & 1) {
    /* issue 1334: collect the destination names this export will really emit, BEFORE the
     * first page is drawn -- the links on page 1 point at children paged later, so the set
     * cannot be built as we go.
     *
     * THE SAVE/RESTORE AROUND IT IS LOAD-BEARING AND WAS FOUND BY MEASUREMENT, not by
     * reading, and it is what makes this pass a READ. There is a pre-existing fixed point
     * between the zoom and the instance bounding boxes: symbol_bbox() computes the
     * text-inflated inst[].x1..y2 at the CURRENT zoom, calc_drawing_bbox() unions those, and
     * zoom_full() then derives the next zoom from that union -- so walking the hierarchy once
     * moves the whole system one iteration along and it settles somewhere else. It is not
     * this item's doing: on the UNCHANGED binary, `xschem list_hierarchy` (the same walk)
     * immediately before `xschem hier_psprint` already rescales every page, and `xschem
     * netlist` or `xschem reload` move it too. Measured on greycnt.sch, DD-3's control:
     *   fresh session            14 rects at 61.487 x 35.135 pt   <- DD-3's number
     *   after ONE prior walk     14 rects at 61.452 x 35.116 pt   (and stable thereafter)
     * A pre-pass that left that behind would rescale every hierarchical PDF anyone prints,
     * for a set it only READS. So the zoom (save_restore_zoom, which also carries xrect[0],
     * lw and areax1..areay2) and every instance's cached bounding box are put back exactly.
     * With both restored the control is 61.487 x 35.135 again, to the digit. The underlying
     * fixed-point instability is real and is left for its own issue; it is NOT hidden here,
     * it is fenced -- suite row S13b is the fence. */
    Zoom_info pre_zi;
    double *pre_bb = NULL;
    int *pre_fl = NULL;
    char pre_name[PATH_MAX];
    int pre_n = xctx->instances, bi;
    my_strncpy(pre_name, xctx->current_name, S(pre_name));
    save_restore_zoom(1, &pre_zi);
    if(pre_n > 0) {
      pre_bb = my_malloc(_ALLOC_ID_, sizeof(double) * 8 * (size_t)pre_n);
      pre_fl = my_malloc(_ALLOC_ID_, sizeof(int) * (size_t)pre_n);
      for(bi = 0; bi < pre_n; ++bi) {
        pre_bb[8*bi+0] = xctx->inst[bi].x1;  pre_bb[8*bi+1] = xctx->inst[bi].y1;
        pre_bb[8*bi+2] = xctx->inst[bi].x2;  pre_bb[8*bi+3] = xctx->inst[bi].y2;
        pre_bb[8*bi+4] = xctx->inst[bi].xx1; pre_bb[8*bi+5] = xctx->inst[bi].yy1;
        pre_bb[8*bi+6] = xctx->inst[bi].xx2; pre_bb[8*bi+7] = xctx->inst[bi].yy2;
        pre_fl[bi] = xctx->inst[bi].flags;
      }
    }
    str_hash_free(&pspage_table);
    str_hash_init(&pspage_table, HASHSIZE);
    str_hash_free(&psedge_table);       /* RULE-1 / issue 1338: the H4 scope tables */
    str_hash_init(&psedge_table, HASHSIZE);
    pspage_set_valid = 0;
    pspage_count = 0;                                                  /* ITEM H6 */
    hier_psprint(NULL, 4);   /* the same walk; `what & 1` is clear, so it cannot recurse */
    pspage_set_valid = 1;
    /* RULE-1: the destination set is complete only now, so the edges the collect
     * pass recorded can finally be resolved. Once per export, before the prolog. */
    hier_psprint_resolve_hier();
    hier_psprint_read_border_mode();
    hier_psprint_read_nav_mode();      /* ITEM H6, once per export beside the other */
    save_restore_zoom(0, &pre_zi);
    if(pre_bb) {
      if(xctx->instances == pre_n) for(bi = 0; bi < pre_n; ++bi) {
        xctx->inst[bi].x1  = pre_bb[8*bi+0]; xctx->inst[bi].y1  = pre_bb[8*bi+1];
        xctx->inst[bi].x2  = pre_bb[8*bi+2]; xctx->inst[bi].y2  = pre_bb[8*bi+3];
        xctx->inst[bi].xx1 = pre_bb[8*bi+4]; xctx->inst[bi].yy1 = pre_bb[8*bi+5];
        xctx->inst[bi].xx2 = pre_bb[8*bi+6]; xctx->inst[bi].yy2 = pre_bb[8*bi+7];
        xctx->inst[bi].flags = pre_fl[bi];
      }
      my_free(_ALLOC_ID_, &pre_bb);
      my_free(_ALLOC_ID_, &pre_fl);
    }
    /* the walk's tail rewrites current_name to rel_sym_path(); page 1's title
     * (`ps_page_title`) prints it verbatim, so it is part of the output too. */
    my_strncpy(xctx->current_name, pre_name, S(xctx->current_name));
  }
  save = xctx->do_copy_area;
  xctx->do_copy_area = 0;
  if((what & 1)  && !ps_draw(1, 1, 0)) return; /* prolog */
  /* issue 0498: shield this walk's own save/restore pair from a leaked `xschem set no_undo 1`
   * (see undo_shield_push(), netlist.c). UNCONDITIONAL: hier_psprint always descends, so the
   * pop_undo(2, 0) / pop_undo(4, 0) below are always owed. The one early return above this
   * point is before the push, so the tail is the only exit that must drop the shield. */
  undo_saved = undo_shield_push();
  xctx->push_undo();
  str_hash_init(&subckt_table, HASHSIZE);
  zoom_full(0, 0, 1 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
  if(what & 1) ps_draw(2, 1, 0); /* page */
  if(what & 4) hier_psprint_record_dest(); /* issue 1334 */
  if(what & 2) { /* print cellname */
    my_strcat(_ALLOC_ID_, res, hier_psprint_mtime(xctx->sch[xctx->currsch]));
    my_strcat(_ALLOC_ID_, res, "  {");
    my_strcat(_ALLOC_ID_, res, xctx->sch[xctx->currsch]);
    my_strcat(_ALLOC_ID_, res, "}\n");
  }
  dbg(1,"--> %s\n", get_cell(xctx->sch[xctx->currsch], 0) );
  unselect_all(1);
  remove_symbols(); /* ensure all unused symbols purged before descending hierarchy */
  /* reload data without popping undo stack, this populates embedded symbols if any */
  xctx->pop_undo(2, 0);
  /* link_symbols_to_instances(-1); */ /* done in xctx->pop_undo() */
  my_strdup(_ALLOC_ID_, &xctx->sch_path[xctx->currsch+1], xctx->sch_path[xctx->currsch]);
  my_strcat(_ALLOC_ID_, &xctx->sch_path[xctx->currsch+1], "->netlisting");
  xctx->sch_path_hash[xctx->currsch+1] = 0;
  xctx->currsch++;
  subckt_name=NULL;
  get_additional_symbols(1);
  for(i=0;i<xctx->symbols; ++i)
  {
    int flag;
    /* for printing we process also symbols that have *_ignore attribute */
    if(!xctx->sym[i].type || !xctx->sym[i].name || !xctx->sym[i].name[0]) continue; /* can not descend into */
    my_strdup2(_ALLOC_ID_, &abs_path, abs_sym_path(tcl_hook2(xctx->sym[i].name), ""));
    /* `what & 4` is the issue-1334 collect pass and must see exactly what the print
     * pass sees; `xschem list_hierarchy` (what == 2) keeps its own nolist_libs. */
    if(what & 5) flag = check_lib(2, abs_path); /* noprint_libs */
    else flag = check_lib(4, abs_path); /* nolist_libs */
    if(flag && (!strcmp(xctx->sym[i].type, "subcircuit") || !strcmp(xctx->sym[i].type, "primitive")))
    {
      /* xctx->sym can be SCH or SYM, use hash to avoid writing duplicate subckt */
      my_strdup(_ALLOC_ID_, &subckt_name, get_cell(xctx->sym[i].name, 0));
      get_sch_from_sym(filename, xctx->sym + i, -1, 0);
      if (str_hash_lookup(&subckt_table, subckt_name, "", XINSERT_NOREPLACE)==NULL)
      {
        const char *default_schematic;
        /* do not insert symbols with default_schematic attribute set to ignore in hash since these symbols
         * will not be processed by *_block_netlist() */
        default_schematic = get_tok_value(xctx->sym[i].prop_ptr, "default_schematic", 0);
        if(!strcmp(default_schematic, "ignore")) {
          continue;
        }
        if(is_generator(filename) || !stat(filename, &buf)) {
          if(str_hash_lookup(&subckt_table, get_cell_w_ext(filename, 0), "", XINSERT_NOREPLACE)==NULL) {
            /* for printing we go down to bottom regardless of spice_stop attribute */
            dbg(1, "hier_psprint(): loading file: |%s|\n", filename);
            load_schematic(1,filename, 0, 1);
            get_additional_symbols(1);
            /* do a zoom with draw, this is needed to load embedded images into r->extraptr
             *        |   */
            zoom_full(1, 0, 1 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
            if(what & 1) ps_draw(2, 1, 0); /* page */
            if(what & 4) hier_psprint_record_dest(); /* issue 1334 */
            if(what & 2) { /* print cellname */
              my_strcat(_ALLOC_ID_, res, hier_psprint_mtime(xctx->sch[xctx->currsch]));
              my_strcat(_ALLOC_ID_, res, "  {");
              my_strcat(_ALLOC_ID_, res, xctx->sch[xctx->currsch]);
              my_strcat(_ALLOC_ID_, res, "}\n");
            }
            dbg(1,"--> %s\n", get_cell(xctx->sch[xctx->currsch], 0) );
          }
        }
      }
    }
  }
  /* can not free additional syms since load_schematic() above may have loaded additional syms */
  /* get_additional_symbols(0); */
  my_free(_ALLOC_ID_, &abs_path);
  str_hash_free(&subckt_table);
  my_free(_ALLOC_ID_, &subckt_name);
  my_free(_ALLOC_ID_, &xctx->sch[xctx->currsch]);
  xctx->currsch--;
  unselect_all(1);
  remove_symbols();
  xctx->pop_undo(4, 0);
  xctx->prev_set_modify = save_prev_mod;
  my_strncpy(xctx->current_name, rel_sym_path(xctx->sch[xctx->currsch]), S(xctx->current_name));
  undo_shield_pop(undo_saved); /* issue 0498: every exit path, I6 */
  xctx->do_copy_area = save;
  if(what & 1) ps_draw(4, 1, 0); /* trailer */
  if(what & 1) { /* issue 1334: the set belongs to this export only */
    pspage_set_valid = 0;
    str_hash_free(&pspage_table);
    str_hash_free(&psedge_table);       /* RULE-1 / issue 1338 */
    str_hash_free(&pshier_table);
    str_hash_free(&psparent_table);     /* ITEM H6 */
  }
}

static char *model_name_result = NULL; /* safe even with multiple schematics */

/* THE MODEL DEDUP KEY -- casemode item 14(b). doc/claude/specs/raw_case_mode.md
 * section 14. `keep_case` is 1 only under `distinguish`.
 *
 * The fold is CORRECT under fold/preserve and stays: SPICE model and subckt
 * identity really is case-insensitive there, so `.SUBCKT NAND2` is callable as
 * `nand2` and two device_model attributes spelling one model differently must
 * hash to one entry and be emitted once. Only `distinguish` makes `NAND2` and
 * `nand2` two different models, and there emitting one of them would drop a
 * model the deck needs.
 *
 * The narrowing is deliberately partial: the CARD KEYWORD is still located on a
 * folded copy, so `.SUBCKT`/`.Model` are recognised in every mode. Only the
 * IDENTITY -- the model name and the token after it, which is what the key is
 * built from -- follows the mode. Two spellings of one card keyword name the
 * same model, so merging them is right whatever the mode; two spellings of one
 * model NAME do not, under `distinguish`.
 *
 * Note the fold used to feed the sscanf() parse as well as the key, which is why
 * the literal `.subckt ` in the format string is gone: with a verbatim source
 * string a `.SUBCKT` card would not match that literal, sscanf would return 0,
 * and the whole card would become the key. The keyword is skipped by LENGTH
 * instead -- strtolower() is byte-wise and length-preserving, so the offset
 * found in the folded copy is the offset in the original. */
static char *model_name(const char *m, int keep_case)
{
  char *m_lower = NULL;
  char *modelname = NULL;
  char *ptr;
  const char *src;
  int n;
  size_t l = strlen(m) + 1;
  my_strdup(_ALLOC_ID_, &m_lower, m);
  strtolower(m_lower);
  src = keep_case ? m : m_lower;   /* what the KEY is built from */
  my_realloc(_ALLOC_ID_, &modelname, l);
  my_realloc(_ALLOC_ID_, &model_name_result, l);
  if((ptr = strstr(m_lower, ".subckt"))) {
    n = sscanf(src + (ptr - m_lower) + 7, " %s %s", model_name_result, modelname);
  } else if((ptr = strstr(m_lower, ".model"))) {
    n = sscanf(src + (ptr - m_lower) + 6, " %s %s", model_name_result, modelname);
  } else {
     n = sscanf(src, " %s %s", model_name_result, modelname);
  }
  if(n<2) my_strncpy(model_name_result, src, l);
  else {
    /* build a hash key value with no spaces to make device_model attributes with different spaces equivalent*/
    my_strcat(_ALLOC_ID_, &model_name_result, modelname);
  }
  my_free(_ALLOC_ID_, &modelname);
  my_free(_ALLOC_ID_, &m_lower);
  return model_name_result;
}

static int spice_netlist(FILE *fd, int spice_stop )
{
  int err = 0;
  int i, flag = 0;
  const char *type;
  int lvs_netlist =  tclgetboolvar("lvs_netlist");
  int top_sub = lvs_netlist || tclgetboolvar("top_is_subckt");
  int lvs_ignore = tclgetboolvar("lvs_ignore");
  /* casemode item 14(b): the dedup key keeps its fold unless `distinguish`.
   * Resolved once per level rather than per instance -- it reads a Tcl var. */
  int keep_model_case = (netlist_case_mode() == RAW_CASE_DISTINGUISH);
  if(lvs_netlist) my_strdup(_ALLOC_ID_, &xctx->format, "lvs_format");
  else my_strdup(_ALLOC_ID_, &xctx->format, xctx->custom_format);
  if(!spice_stop) {
    dbg(1, "spice_netlist(): invoke prepare_netlist_structs for %s\n", xctx->current_name);
    xctx->prep_net_structs = 0;
    err |= prepare_netlist_structs(1);
    err |= traverse_node_hash();  /* print all warnings about unconnected floatings etc */
    /* casemode item 14(a): warn where xschem and the simulator disagree about how
     * many nets this level has. Here and not inside traverse_node_hash() for two
     * reasons: this is the per-LEVEL spice pass, so a collision confined to a
     * subcircuit body is reported (the one upstream misses under `fold`), and
     * traverse_node_hash() is also the interactive show_unconnected_pins() pass,
     * where a question about a simulator run has no business firing.
     * WARN, NOT ERROR (C2): the count is deliberately not OR-ed into `err`. */
    netlist_case_collision_check();
    for(i=0;i<xctx->instances; ++i) /* print first ipin/opin defs ... */
    {
     if(skip_instance(i, 1, lvs_ignore)) continue;
     type = (xctx->inst[i].ptr+ xctx->sym)->type;
     if( type && IS_PIN(type) ) {
       if(top_sub && !flag) {
         fprintf(fd, "*.PININFO ");
         flag = 1;
       }
       if(top_sub) {
         int d = 'X';
         if(!strcmp(type, "ipin")) d = 'I';
         if(!strcmp(type, "opin")) d = 'O';
         if(!strcmp(type, "iopin")) d = 'B';
         fprintf(fd, "%s:%c ",xctx->inst[i].lab, d);
       } else {
         print_spice_element(fd, i) ;  /* this is the element line  */
       }
     }
    }
    if(top_sub) fprintf(fd, "\n");
    for(i=0;i<xctx->instances; ++i) /* ... then print other lines */
    {
     if(skip_instance(i, 1, lvs_ignore)) continue;
     type = (xctx->inst[i].ptr+ xctx->sym)->type;

     if( type && !IS_LABEL_OR_PIN(type) ) {
       /* already done in global_spice_netlist */
       if(!strcmp(type,"netlist_commands") && xctx->netlist_count==0) continue;
       if(xctx->netlist_count &&
          !strboolcmp(get_tok_value(xctx->inst[i].prop_ptr, "only_toplevel", 0), "true")) continue;
       if(!strcmp(type,"netlist_commands")) {
         fprintf(fd,"**** begin user architecture code\n");
         print_spice_element(fd, i) ;  /* this is the element line  */
         fprintf(fd,"**** end user architecture code\n");
       } else {
         char *val = NULL;
         const char *m;
         if(print_spice_element(fd, i)) {
           fprintf(fd, "**** end_element\n");
         }
         /* hash device_model attribute if any */
         my_strdup2(_ALLOC_ID_, &val, get_tok_value(xctx->inst[i].prop_ptr, "device_model", 2));
         m = val;
         if(strchr(val, '@')) m = translate(i, val);
         else m = tcl_hook2(m);
         if(m[0]) str_hash_lookup(&model_table, model_name(m, keep_model_case), m, XINSERT);
         else {
           my_strdup2(_ALLOC_ID_, &val,
               get_tok_value(xctx->sym[xctx->inst[i].ptr].prop_ptr, "device_model", 2));
           m = val;
           if(strchr(val, '@')) m = translate(i, val);
           else m = tcl_hook2(m);
           if(m[0]) str_hash_lookup(&model_table, model_name(m, keep_model_case), m, XINSERT);
         }
         my_free(_ALLOC_ID_, &model_name_result);
         my_free(_ALLOC_ID_, &val);
       }
     }
    }
  }
  if(!spice_stop && !xctx->netlist_count) redraw_hilights(0); /* draw_hilight_net(1); */
  return err;
}

/* alert: if set show alert if file missing */
int global_spice_netlist(int global, int alert)  /* netlister driver */
{
 int err = 0;
 int first;
 FILE *fd;
 const char *str_tmp;
 int multip;
 unsigned int *stored_flags;
 /* issue 0498: stored_flags is sized at the ENTRY instance count but was read back
  * over the CURRENT one. Nothing but pop_undo() enforces "those two are equal", and
  * xctx->no_undo silently disables pop_undo -- so a leaked no_undo turned the restore
  * loop below into a heap over-read that fed garbage into xctx->inst[].color and took
  * draw_hilight_net() down. Keep the size the loop must respect. */
 int stored_flags_n;
 /* issue 0498: caller's xctx->no_undo, parked while this walk owns the undo slot */
 int undo_saved;
 int i;
 const char *type;
 char *place=NULL;
 char netl_filename[PATH_MAX]; /* overflow safe 20161122 */
 char cellname[PATH_MAX]; /* 20081211 overflow safe 20161122 */
 char *subckt_name;
 char *abs_path = NULL;
 int split_f;
 Str_hashtable subckt_table = {NULL, 0};
 Str_hashentry *model_entry;
 int save_prev_mod = xctx->prev_set_modify;
 struct stat buf;
 char *top_symbol_name = NULL;
 /* if top level has a symbol use it for pin ordering
  * top_symbol_name == 1: a symbol file matching schematic has been found.
  * top_symbol_name == 3: the found symbol has type=subcircuit and has ports */
 int found_top_symbol = 0;
 int npins = 0; /* top schematic number of i/o ports */
 Sch_pin_record *pinnumber_list = NULL; /* list of top sch i/o ports ordered wrt sim_pinnumber attr */
 int uppercase_subckt = tclgetboolvar("uppercase_subckt");
 int lvs_netlist =  tclgetboolvar("lvs_netlist");
 int top_sub = lvs_netlist || tclgetboolvar("top_is_subckt");
 int lvs_ignore = tclgetboolvar("lvs_ignore");

 if(lvs_netlist) my_strdup(_ALLOC_ID_, &xctx->format, "lvs_format");
 else  my_strdup(_ALLOC_ID_, &xctx->format, xctx->custom_format);
 exit_code = 0; /* reset exit code */
 split_f = tclgetboolvar("split_files");
 dbg(1, "global_spice_netlist(): invoking push_undo()\n");
 /* issue 0498: shield this walk's own save/restore pair from a leaked
  * `xschem set no_undo 1` (see undo_shield_push(), netlist.c). Gated on `global`:
  * a non-global run owes no pop_undo, so it must not be made to push either. */
 undo_saved = global ? undo_shield_push() : xctx->no_undo;
 xctx->push_undo();
 xctx->netlist_unconn_cnt=0; /* unique count of unconnected pins while netlisting */
 statusmsg("",2);  /* clear infowindow */
 str_hash_init(&subckt_table, HASHSIZE);
 str_hash_init(&model_table, HASHSIZE);
 record_global_node(2, NULL, NULL); /* delete list of global nodes */
 bus_char[0] = bus_char[1] = '\0';
 xctx->hiersep[0]='.'; xctx->hiersep[1]='\0';
 str_tmp = tclgetvar("bus_replacement_char");
 if(str_tmp && str_tmp[0] && str_tmp[1]) {
   bus_char[0] = str_tmp[0];
   bus_char[1] = str_tmp[1];
 }
 xctx->netlist_count=0;
 my_snprintf(netl_filename, S(netl_filename), "%s/.%s_%d",
   tclgetvar("netlist_dir"), get_cell(xctx->sch[xctx->currsch], 0), getpid());
 dbg(1, "global_spice_netlist(): opening %s for writing\n",netl_filename);
 fd=fopen(netl_filename, "w");
 if(fd==NULL) {
   dbg(0, "global_spice_netlist(): problems opening netlist file\n");
   undo_shield_pop(undo_saved); /* issue 0498: every exit path, I6 */
   return 1;
 }
 fprintf(fd, "** sch_path: %s\n", xctx->sch[xctx->currsch]);

 if(xctx->netlist_name[0]) {
   my_snprintf(cellname, S(cellname), "%s", get_cell_w_ext(xctx->netlist_name, 0));
 } else {
   my_snprintf(cellname, S(cellname), "%s.spice", get_cell(xctx->sch[xctx->currsch], 0));
 }

 first = 0;
 for(i=0;i<xctx->instances; ++i) /* print netlist_commands of top level cell with 'place=header' property */
 {
  if(skip_instance(i, 1, lvs_ignore)) continue;
  type = (xctx->inst[i].ptr+ xctx->sym)->type;
  my_strdup(_ALLOC_ID_, &place,get_tok_value(xctx->sym[xctx->inst[i].ptr].prop_ptr,"place",0));
  if( type && !strcmp(type,"netlist_commands") ) {
   if(!place) {
     my_strdup(_ALLOC_ID_, &place,get_tok_value(xctx->inst[i].prop_ptr,"place",0));
   }
   if(place && !strcmp(place, "header" )) {
     if(first == 0) fprintf(fd,"**** begin user header code\n");
     ++first;
     print_spice_element(fd, i) ;  /* this is the element line  */
   }
  }
 }
 if(first) fprintf(fd,"**** end user header code\n");

 /* netlist_options */
 for(i=0;i<xctx->instances; ++i) {
   if(skip_instance(i, 1, lvs_ignore)) continue;
   if(!(xctx->inst[i].ptr+ xctx->sym)->type) continue;
   if( !strcmp((xctx->inst[i].ptr+ xctx->sym)->type,"netlist_options") ) {
     netlist_options(i);
   }
 }
 if(!top_sub) fprintf(fd,"**");
 if(uppercase_subckt)
   fprintf(fd,".SUBCKT %s", get_cell(xctx->sch[xctx->currsch], 0));
 else
   fprintf(fd,".subckt %s", get_cell(xctx->sch[xctx->currsch], 0));
 pinnumber_list = sort_schematic_pins(&npins); /* sort pins according to sim_pinnumber attr */

 /* print top subckt ipin/opins */
 my_strdup2(_ALLOC_ID_, &top_symbol_name, abs_sym_path(add_ext(xctx->current_name, ".sym"), ""));
 if(!stat(top_symbol_name, &buf)) { /* if top level has a symbol use the symbol for pin ordering */
   dbg(1, "found top level symbol %s\n", top_symbol_name);
   load_sym_def(top_symbol_name, NULL);
   found_top_symbol = 1;
   if(xctx->sym[xctx->symbols - 1].type != NULL &&
     /* only use the symbol if it has pins and is a subcircuit ? */
     /* !strcmp(xctx->sym[xctx->symbols - 1].type, "subcircuit") && */
       xctx->sym[xctx->symbols - 1].rects[PINLAYER] > 0) {
     fprintf(fd," ");
     print_spice_subckt_nodes(fd, xctx->symbols - 1);
     found_top_symbol = 3;
     err |= sym_vs_sch_pins(xctx->symbols - 1);
   }
   remove_symbol(xctx->symbols - 1);
 }
 my_free(_ALLOC_ID_, &top_symbol_name);
 if(found_top_symbol != 3) {
   for(i=0;i<npins; ++i) {
     int n = pinnumber_list[i].n;
     str_tmp = expandlabel ( (xctx->inst[n].lab ? xctx->inst[n].lab : ""), &multip);
     /*must handle  invalid node names */
     fprintf(fd, " %s", str_tmp ? str_tmp : "<NULL>" );
   }
 }
 my_free(_ALLOC_ID_, &pinnumber_list);
 fprintf(fd,"\n");

 /* ISSUE 1201, GUARD AS-MODE. Everything between here and auto_spec_end() at
  * the tail of this function is the ONE window in which the netlister may write
  * a specialised copy of a cell for a setting a designer typed on one copy of
  * it. It is opened here and nowhere else: the GUI, descend, hier_psprint()
  * (printing a hierarchy is not writing a deck) and the Spectre, VHDL, Verilog
  * and tEDAx netlisters all keep exactly today's behaviour.
  *
  * ⚠ IT MUST OPEN BEFORE THIS LINE, NOT AT get_additional_symbols() BELOW, and
  * that is measured, not stylistic. spice_netlist() here writes the TOP sheet's
  * own call lines, and the cell name on a call line comes from get_sym_name().
  * Opened any later, the deck grew the specialised cell bodies while every call
  * line above them still named the plain cell -- bodies nothing called, and the
  * designer's setting still nowhere. spice_block_netlist()'s own
  * get_additional_symbols(1) and spice_netlist() are both inside this window,
  * so sub-sheets specialise too. See src/actions.c.
  *
  * ISSUE 1204, AND IT IS WHY THE ARGUMENT IS `global` AND NOT 1. `global` is 0
  * when the user asked for a netlist of just the sheet on screen -- Shift-N, or
  * `xschem netlist -nohier`: that run writes THIS sheet and stops. The
  * specialised cell bodies are written further down by get_additional_symbols(1)
  * inside the `if(global)` block, so a single-sheet run that minted names would
  * put call lines into the deck naming cell bodies that run never writes -- a
  * deck no simulator accepts, and a regression on a mode that worked before this
  * feature. So the window still OPENS on both arms, because the classification
  * and its caches are wanted on both, but on the single-sheet arm it mints no
  * names: GUARD AS-WHOLE, src/actions.c. The batch `xschem -n` CLI netlist
  * passes 1 and is unaffected.
  *
  * ISSUE 1218: the door named here used to be a checkbutton this build does not
  * have. The real doors are the two above -- name what the user can see. */
 auto_spec_begin(global);
 err |= spice_netlist(fd, 0);

 first = 0;
 for(i=0;i<xctx->instances; ++i) /* print netlist_commands of top level cell with no 'place=end' property
                                   and no place=header */
 {
  if(skip_instance(i, 1, lvs_ignore)) continue;
  type = (xctx->inst[i].ptr+ xctx->sym)->type;
  my_strdup(_ALLOC_ID_, &place,get_tok_value(xctx->sym[xctx->inst[i].ptr].prop_ptr,"place",0));
  if( type && !strcmp(type,"netlist_commands") ) {
   if(!place) {
     my_strdup(_ALLOC_ID_, &place,get_tok_value(xctx->inst[i].prop_ptr,"place",0));
   }
   if(!place || (strcmp(place, "end") && strcmp(place, "header")) ) {
     if(first == 0) fprintf(fd,"**** begin user architecture code\n");
     ++first;
     print_spice_element(fd, i) ;  /* this is the element line  */
   }
  }
 }

 xctx->netlist_count++;

 if(xctx->schprop && xctx->schprop[0]) {
   if(first == 0) fprintf(fd,"**** begin user architecture code\n");
   ++first;
   fprintf(fd, "%s\n", xctx->schprop);
 }
 if(first) fprintf(fd,"**** end user architecture code\n");
 /* /20100217 */

 if(!top_sub) fprintf(fd,"**");
 if(uppercase_subckt)
   fprintf(fd, ".ENDS\n");
 else
   fprintf(fd, ".ends\n");


 if(split_f) {
   int save;
   fclose(fd);
   save = xctx->netlist_type;
   xctx->netlist_type = CAD_SPICE_NETLIST;
   set_tcl_netlist_type();
   tcl_call_mid("netlist", netl_filename, "noshow", cellname);
   xctx->netlist_type = save;
   set_tcl_netlist_type();

   if(debug_var==0) xunlink(netl_filename);
 }

 /* warning if two symbols perfectly overlapped */
 err |= warning_overlapped_symbols(0);
 /* preserve current level instance flags before descending hierarchy for netlisting, restore later */
 stored_flags_n = xctx->instances;
 stored_flags = my_calloc(_ALLOC_ID_, stored_flags_n, sizeof(unsigned int));
 for(i=0;i<stored_flags_n; ++i) stored_flags[i] = xctx->inst[i].color;

 if(global)
 {
   int saved_hilight_nets = xctx->hilight_nets;
   int web_url = is_from_web(xctx->current_dirname);
   char *current_dirname_save = NULL;

   my_strdup2(_ALLOC_ID_, &current_dirname_save, xctx->current_dirname);
   unselect_all(1);
   /* ensure all unused symbols purged before descending hierarchy */
   if(!tclgetboolvar("keep_symbols")) remove_symbols();
   /* reload data without popping undo stack, this populates embedded symbols if any */
   dbg(1, "global_spice_netlist(): invoking pop_undo(2, 0)\n");
   xctx->pop_undo(2, 0);
   /* link_symbols_to_instances(-1); */ /* done in xctx->pop_undo() */
   my_strdup(_ALLOC_ID_, &xctx->sch_path[xctx->currsch+1], xctx->sch_path[xctx->currsch]);
   my_strcat(_ALLOC_ID_, &xctx->sch_path[xctx->currsch+1], "->netlisting");
   xctx->sch_path_hash[xctx->currsch+1] = 0;
   xctx->currsch++;
   subckt_name=NULL;
   dbg(2, "global_spice_netlist(): last defined symbol=%d\n",xctx->symbols);
   get_additional_symbols(1);
   for(i=0;i<xctx->symbols; ++i)
   {
    if(xctx->sym[i].flags & (SPICE_IGNORE | SPICE_SHORT)) continue;
    if(lvs_ignore && (xctx->sym[i].flags & LVS_IGNORE)) continue;
    if(!xctx->sym[i].type) continue;
    /* store parent symbol template attr (before descending into it) and parent instance prop_ptr
     * into xctx->hier_attr[0].templ and xctx->hier_attr[0.prop_ptr,
     * to resolve subschematic instances with model=@modp in format string,
     * modp will be first looked up in instance prop_ptr string, and if not found
     * in parent symbol template string */
    my_strdup(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch - 1].templ,
              tcl_hook2(xctx->sym[i].templ));
    /* only additional symbols (created with instance schematic=... attr) will have this attribute */
    my_strdup(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch - 1].prop_ptr,
              tcl_hook2(xctx->sym[i].parent_prop_ptr));
    my_strdup(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch - 1].sym_extra,
      get_tok_value(xctx->sym[i].prop_ptr, "extra", 0));
    my_strdup(_ALLOC_ID_, &abs_path, abs_sym_path(xctx->sym[i].name, ""));
    if(strcmp(xctx->sym[i].type,"subcircuit")==0 && check_lib(1, abs_path))
    {
      if(!web_url) {
        tcl_call("get_directory", xctx->sch[xctx->currsch - 1], NULL, NULL);
        my_strncpy(xctx->current_dirname, tclresult(),  S(xctx->current_dirname));
      }
      /* xctx->sym can be SCH or SYM, use hash to avoid writing duplicate subckt */
      my_strdup(_ALLOC_ID_, &subckt_name, get_cell(xctx->sym[i].name, 0));
      dbg(1, "global_spice_netlist(): subckt_name=%s\n", subckt_name);
      if (str_hash_lookup(&subckt_table, subckt_name, "", XLOOKUP)==NULL)
      {
        /* do not insert symbols with default_schematic attribute set to ignore in hash since these symbols
         * will not be processed by *_block_netlist() */
        if(strcmp(get_tok_value(xctx->sym[i].prop_ptr, "default_schematic", 0), "ignore"))
          str_hash_lookup(&subckt_table, subckt_name, "", XINSERT);
        if( split_f && strboolcmp(get_tok_value(xctx->sym[i].prop_ptr,"vhdl_netlist",0),"true")==0 )
          err |= vhdl_block_netlist(fd, i, alert);
        else if(split_f && strboolcmp(get_tok_value(xctx->sym[i].prop_ptr,"verilog_netlist",0),"true")==0 )
          err |= verilog_block_netlist(fd, i, alert);
        else if(split_f && strboolcmp(get_tok_value(xctx->sym[i].prop_ptr,"spectre_netlist",0),"true")==0 )
          err |= spectre_block_netlist(fd, i, alert);
        else
          if( strboolcmp(get_tok_value(xctx->sym[i].prop_ptr,"spice_primitive",0),"true") )
            err |= spice_block_netlist(fd, i, alert);
      }
    }
   }
   if(xctx->hier_attr[xctx->currsch - 1].templ)
     my_free(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch - 1].templ);
   if(xctx->hier_attr[xctx->currsch - 1].prop_ptr)
     my_free(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch - 1].prop_ptr);
   if(xctx->hier_attr[xctx->currsch - 1].sym_extra)
     my_free(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch - 1].sym_extra);
   my_free(_ALLOC_ID_, &abs_path);
   /* get_additional_symbols(0); */
   my_free(_ALLOC_ID_, &subckt_name);
   /*clear_drawing(); */
   my_free(_ALLOC_ID_, &xctx->sch[xctx->currsch]);
   xctx->currsch--;
   unselect_all(1);
   dbg(1, "global_spice_netlist(): invoking pop_undo(0, 0)\n");
   /* symbol vs schematic pin check, we do it here since now we have ALL symbols loaded */
   err |= sym_vs_sch_pins(-1);
   if(!tclgetboolvar("keep_symbols")) remove_symbols();
   xctx->pop_undo(4, 0);
   xctx->prev_set_modify = save_prev_mod;
   if(web_url) {
     my_strncpy(xctx->current_dirname, current_dirname_save, S(xctx->current_dirname));
   } else {
     tcl_call("get_directory", xctx->sch[xctx->currsch], NULL, NULL);
     my_strncpy(xctx->current_dirname, tclresult(),  S(xctx->current_dirname));
   }
   my_strncpy(xctx->current_name, rel_sym_path(xctx->sch[xctx->currsch]), S(xctx->current_name));
   dbg(1, "spice_netlist(): invoke prepare_netlist_structs for %s\n", xctx->current_name);
   err |= prepare_netlist_structs(1); /* so 'lab=...' attributes for unnamed nets are set */
   if(!xctx->hilight_nets) xctx->hilight_nets = saved_hilight_nets;
   my_free(_ALLOC_ID_, &current_dirname_save);
 }
 /* restore hilight flags from errors found analyzing top level before descending hierarchy */
 for(i=0; i<stored_flags_n && i<xctx->instances; ++i)
   if(!xctx->inst[i].color) xctx->inst[i].color = stored_flags[i];
 propagate_hilights(1, 0, XINSERT_NOREPLACE);
 draw_hilight_net(1);
 my_free(_ALLOC_ID_, &stored_flags);

 /* print globals nodes found in netlist 28032003 */
 if(!split_f) {
   record_global_node(0,fd,NULL);
   /* record_global_node(2, NULL, NULL); */ /* delete list --> do it in xwin_exit() */
 }

 /* =================================== 20121223 */
 first = 0;
 if(!split_f) {
   for(i=0;i<xctx->instances; ++i) /* print netlist_commands of top level cell with 'place=end' property */
   {
    if(skip_instance(i, 1, lvs_ignore)) continue;
    type = (xctx->inst[i].ptr+ xctx->sym)->type;
    my_strdup(_ALLOC_ID_, &place,get_tok_value(xctx->sym[xctx->inst[i].ptr].prop_ptr,"place",0));
    if( type && !strcmp(type,"netlist_commands") ) {
     if(place && !strcmp(place, "end" )) {
       if(first == 0) fprintf(fd,"**** begin user architecture code\n");
       ++first;
       print_spice_element(fd, i) ;
     } else {
       my_strdup(_ALLOC_ID_, &place,get_tok_value(xctx->inst[i].prop_ptr,"place",0));
       if(place && !strcmp(place, "end" )) {
         if(first == 0) fprintf(fd,"**** begin user architecture code\n");
         ++first;
         print_spice_element(fd, i) ;
       }
     }
    } /* netlist_commands */
   }

 }
 /* print device_model attributes */
 for(i=0;i<model_table.size; ++i) {
   model_entry=model_table.table[i];
   while(model_entry) {
     if(first == 0) fprintf(fd,"**** begin user architecture code\n");
     ++first;
     fprintf(fd, "%s\n",  model_entry->value);
     model_entry = model_entry->next;
   }
 }
 str_hash_free(&model_table);
 str_hash_free(&subckt_table);
 if(first) fprintf(fd,"**** end user architecture code\n");


 /* 20150922 added split_files check */
 if( !top_sub && !split_f) fprintf(fd, ".end\n");

 dbg(1, "global_spice_netlist(): starting awk on netlist!\n");


 if(!split_f) {
   fclose(fd);
   if(tclgetboolvar("netlist_show")) {
    tcl_call_mid("netlist", netl_filename, "show", cellname);
   }
   else {
    tcl_call_mid("netlist", netl_filename, "noshow", cellname);
   }
   if(!debug_var) xunlink(netl_filename);
 }
 /* ISSUE 1201: close the window and throw away everything it remembered,
  * including the answers read off disk about which cell drawing uses which
  * setting -- a file may be edited between two netlist runs of one session, and
  * an answer kept past the end of a run is an answer about a file that no
  * longer says that. The only return between auto_spec_begin() above and here
  * is the fopen failure, which is upstream of the begin. */
 auto_spec_end();
 my_free(_ALLOC_ID_, &place);
 xctx->netlist_count = 0;
 tclvareval("show_infotext ", my_itoa(err), NULL); /* critical error: force ERC window showing */
 exit_code = err ? 10 : 0;
 undo_shield_pop(undo_saved); /* issue 0498: every exit path, I6 */
 return err;
}

/* alert: if set show alert if file missing */
int spice_block_netlist(FILE *fd, int i, int alert)
{
  int err = 0;
  int spice_stop=0;
  char netl_filename[PATH_MAX];
  char cellname[PATH_MAX];
  char filename[PATH_MAX];
  /* int j; */
  /* int multip; */
  char *extra=NULL;
  int split_f;
  char *sym_def = NULL;
  char *name = NULL;
  const char *default_schematic;
  int uppercase_subckt = tclgetboolvar("uppercase_subckt");

  split_f = tclgetboolvar("split_files");

  if(!strboolcmp( get_tok_value(xctx->sym[i].prop_ptr,"spice_stop",0),"true") )
     spice_stop=1;
  else
     spice_stop=0;
  if(!strcmp(get_tok_value(xctx->sym[i].prop_ptr, "format", 0), "")) {
    return err;
  }
  get_sch_from_sym(filename, xctx->sym + i, -1, 0);
  default_schematic = get_tok_value(xctx->sym[i].prop_ptr, "default_schematic", 0);
  if(!strcmp(default_schematic, "ignore")) {
    return err;
  }
  my_strdup(_ALLOC_ID_, &name, tcl_hook2(xctx->sym[i].name));

  dbg(1, "spice_block_netlist(): filename=%s\n", filename);
  if(split_f) {
    my_snprintf(netl_filename, S(netl_filename), "%s/.%s_%d",
         tclgetvar("netlist_dir"), get_cell(name, 0), getpid());
    dbg(1, "spice_block_netlist(): split_files: netl_filename=%s\n", netl_filename);
    fd=fopen(netl_filename, "w");
    if(!fd) {
      dbg(0, "spice_block_netlist(): unable to write file %s\n", netl_filename);
      err = 1;
      goto err;
    }
    my_snprintf(cellname, S(cellname), "%s.spice", get_cell(name, 0));
  }
  fprintf(fd, "\n* expanding   symbol:  %s # of pins=%d\n", name,xctx->sym[i].rects[PINLAYER] );
  if(xctx->sym[i].base_name) fprintf(fd, "** sym_path: %s\n", abs_sym_path(xctx->sym[i].base_name, ""));
  else fprintf(fd, "** sym_path: %s\n", sanitized_abs_sym_path(name, ""));
  my_strdup(_ALLOC_ID_, &sym_def, get_tok_value(xctx->sym[i].prop_ptr,"spice_sym_def",0));
  if(sym_def) {
    char *symname_attr = NULL;
    const char *translated_sym_def;
    my_mstrcat(_ALLOC_ID_, &symname_attr, "symname=", get_cell(name, 0), NULL);
    translated_sym_def = translate3(sym_def, 1, xctx->sym[i].templ, symname_attr, NULL, NULL);
    my_free(_ALLOC_ID_, &symname_attr);
    fprintf(fd, "%s\n", translated_sym_def);
    my_free(_ALLOC_ID_, &sym_def);
  } else {
    const char *s = get_tok_value(xctx->sym[i].templ, "model",0);
    if(!s[0]) s = get_cell(sanitize(name), 0);
    fprintf(fd, "** sch_path: %s\n", sanitized_abs_sym_path(filename, ""));
    if(uppercase_subckt)
      fprintf(fd, ".SUBCKT %s ", s);
     else
      fprintf(fd, ".subckt %s ", s);
    print_spice_subckt_nodes(fd, i);

    my_strdup(_ALLOC_ID_, &extra, get_tok_value(xctx->sym[i].prop_ptr,"extra",0) );
    /* this is now done in print_spice_subckt_nodes */
    /*
     * fprintf(fd, "%s ", extra ? extra : "" );
     */

    /* 20081206 new get_sym_template does not return token=value pairs where token listed in extra */
    fprintf(fd, "%s", get_sym_template(xctx->sym[i].templ, extra));
    my_free(_ALLOC_ID_, &extra);
    fprintf(fd, "\n");

    spice_stop ? load_schematic(0,filename, 0, alert) : load_schematic(1,filename, 0, alert);
    get_additional_symbols(1);
    err |= spice_netlist(fd, spice_stop);  /* 20111113 added spice_stop */
    err |= warning_overlapped_symbols(0);
    if(xctx->schprop && xctx->schprop[0]) {
      fprintf(fd,"**** begin user architecture code\n");
      fprintf(fd, "%s\n", xctx->schprop);
      fprintf(fd,"**** end user architecture code\n");
    }
    if(uppercase_subckt)
      fprintf(fd, ".ENDS\n\n");
    else
      fprintf(fd, ".ends\n\n");
  }
  if(split_f) {
    int save;
    fclose(fd);
    save = xctx->netlist_type;
    xctx->netlist_type = CAD_SPICE_NETLIST;
    set_tcl_netlist_type();
    tcl_call_mid("netlist", netl_filename, "noshow", cellname);
    xctx->netlist_type = save;
    set_tcl_netlist_type();
    if(debug_var==0) xunlink(netl_filename);
  }
  err:
  xctx->netlist_count++;
  my_free(_ALLOC_ID_, &name);
  return err;
}

/* GENERIC PURPOSE HASH TABLE */


/*    token        value      what    ... what ...
 * --------------------------------------------------------------------------
 * "whatever"    "whatever"  XINSERT     insert in hash table if not in.
 *                                      if already present update value if not NULL,
 *                                      return entry address if found and updated, else NULL.
 * "whatever"    "whatever"  XINSERT_NOREPLACE   same as XINSERT but do not replace existing value
 *                                      return NULL if not found.
 * "whatever"    "whatever"  XLOOKUP     lookup in hash table,return entry addr.
 *                                      return NULL if not found
 * "whatever"    "whatever"  XDELETE     delete entry if found,return NULL
 */
Str_hashentry *str_hash_lookup(Str_hashtable *hashtable, const char *token, const char *value, int what)
{
  unsigned int hashcode, idx;
  Str_hashentry **preventry;
  int size = hashtable->size;
  Str_hashentry **table = hashtable->table;

  if(token==NULL || size == 0 || table == NULL) return NULL;
  hashcode=str_hash(token);
  idx=hashcode % size;
  preventry=&table[idx];
  while(1)
  {
    if( !(*preventry) )          /* empty slot */
    {
      if(what==XINSERT || what == XINSERT_NOREPLACE)            /* insert data */
      {
        Str_hashentry *entry = (Str_hashentry *)my_malloc(_ALLOC_ID_, sizeof( Str_hashentry ));
        entry->next=NULL;
        entry->token=NULL;
        entry->value=NULL;
        my_strdup2(_ALLOC_ID_, &entry->token, token);
        my_strdup2(_ALLOC_ID_, &entry->value, value);
        entry->hash=hashcode;
        *preventry=entry;
      }
      return NULL; /* if element inserted return NULL since it was not in table */
    }
    if( (*preventry) -> hash==hashcode && strcmp(token,(*preventry)->token)==0 ) /* found a matching token */
    {
      if(what==XDELETE)             /* remove token from the hash table ... */
      {
        Str_hashentry *saveptr;
        saveptr=(*preventry)->next;
        my_free(_ALLOC_ID_, &(*preventry)->token);
        my_free(_ALLOC_ID_, &(*preventry)->value);
        my_free(_ALLOC_ID_, &(*preventry));
        *preventry=saveptr;
      }
      else if(value && what == XINSERT ) {
        my_strdup2(_ALLOC_ID_, &(*preventry)->value, value);
      }
      return (*preventry);   /* found matching entry, return the address */
    }
    preventry=&(*preventry)->next; /* descend into the list. */
  }
}

void str_hash_init(Str_hashtable *hashtable, int size)
{
  if(hashtable->size !=0 || hashtable->table != NULL) {
    dbg(0, "str_hash_init(): Warning hash table not empty, possible data leak\n");
  }
  hashtable->size = size;
  hashtable->table = my_calloc(_ALLOC_ID_, size, sizeof(Str_hashentry *));
}

static void str_hash_free_entry(Str_hashentry *entry)
{
  Str_hashentry *tmp;
  while( entry ) {
    tmp = entry -> next;
    my_free(_ALLOC_ID_, &(entry->token));
    my_free(_ALLOC_ID_, &(entry->value));
    my_free(_ALLOC_ID_, &entry);
    entry = tmp;
  }
}


void str_hash_free(Str_hashtable *hashtable)
{
  if(hashtable->table) {
    int i;
    Str_hashentry **table = hashtable->table;
    for(i=0;i < hashtable->size; ++i)
    {
      str_hash_free_entry( table[i] );
      table[i] = NULL;
    }
    if(hashtable->table) my_free(_ALLOC_ID_, &(hashtable->table));
    hashtable->size = 0;
  }
}

/* GENERIC PURPOSE INT HASH TABLE */

/*    token        value      what    ... what ...
 * --------------------------------------------------------------------------
 * "whatever"    "whatever"  XINSERT     insert in hash table if not in.
 *                                       if already present update value if not NULL,
 *                                       return new entry address.
 * "whatever"    "whatever"  XINSERT_NOREPLACE   same as XINSERT but do not replace existing value
 *                                       return NULL if not found.
 * "whatever"    "whatever"  XLOOKUP     lookup in hash table,return entry addr.
 *                                       return NULL if not found
 * "whatever"    "whatever"  XDELETE     delete entry if found,return NULL
 */
Int_hashentry *int_hash_lookup(Int_hashtable *hashtable, const char *token, const int value, int what)
{
  unsigned int hashcode, idx;
  Int_hashentry **preventry;
  int size = hashtable->size;
  Int_hashentry **table = hashtable->table;

  if(token==NULL || size == 0 || table == NULL) return NULL;
  hashcode=str_hash(token);
  idx=hashcode % size;
  preventry=&table[idx];
  while(1)
  {
    if( !(*preventry) )          /* empty slot */
    {
      if(what==XINSERT || what == XINSERT_NOREPLACE)            /* insert data */
      {
        Int_hashentry *entry = (Int_hashentry *)my_malloc(_ALLOC_ID_, sizeof( Int_hashentry ));
        entry->next=NULL;
        entry->token=NULL;
        my_strdup2(_ALLOC_ID_, &entry->token, token);
        entry->value = value;
        entry->hash=hashcode;
        *preventry=entry;
      }
      return NULL; /* if element inserted return NULL since it was not in table */
    }
    if( (*preventry) -> hash==hashcode && strcmp(token,(*preventry)->token)==0 ) /* found a matching token */
    {
      if(what==XDELETE)             /* remove token from the hash table ... */
      {
        Int_hashentry *saveptr;
        saveptr=(*preventry)->next;
        my_free(_ALLOC_ID_, &(*preventry)->token);
        my_free(_ALLOC_ID_, &(*preventry));
        *preventry=saveptr;
      }
      else if(what == XINSERT ) {
        (*preventry)->value = value;
      }
      return *preventry;   /* found matching entry, return the address */
    }
    preventry=&(*preventry)->next; /* descend into the list. */
  }
}

void int_hash_init(Int_hashtable *hashtable, int size)
{
  if(hashtable->size !=0 || hashtable->table != NULL) {
    dbg(0, "int_hash_init(): Warning hash table not empty, possible data leak\n");
  }
  hashtable->size = size;
  hashtable->table = my_calloc(_ALLOC_ID_, size, sizeof(Int_hashentry *));
}

static void int_hash_free_entry(Int_hashentry *entry)
{
  Int_hashentry *tmp;
  while( entry ) {
    tmp = entry -> next;
    my_free(_ALLOC_ID_, &(entry->token));
    my_free(_ALLOC_ID_, &entry);
    entry = tmp;
  }
}


void int_hash_free(Int_hashtable *hashtable)
{
  if(hashtable->table) {
    int i;
    Int_hashentry **table = hashtable->table;
    for(i=0;i < hashtable->size; ++i)
    {
      int_hash_free_entry( table[i] );
      table[i] = NULL;
    }
    my_free(_ALLOC_ID_, &(hashtable->table));
    hashtable->size = 0;
  }
}



/* GENERIC PURPOSE PTR HASH TABLE */

/*    token        value      what    ... what ...
 * --------------------------------------------------------------------------
 * "whatever"    "whatever"  XINSERT     insert in hash table if not in.
 *                                       if already present update value if not NULL,
 *                                       return new entry address.
 * "whatever"    "whatever"  XINSERT_NOREPLACE   same as XINSERT but do not replace existing value
 *                                       return NULL if not found.
 * "whatever"    "whatever"  XLOOKUP     lookup in hash table,return entry addr.
 *                                       return NULL if not found
 * "whatever"    "whatever"  XDELETE     delete entry if found,return NULL
 */
Ptr_hashentry *ptr_hash_lookup(Ptr_hashtable *hashtable, const char *token, void *const value, int what)
{
  unsigned int hashcode, idx;
  Ptr_hashentry **preventry;
  int size = hashtable->size;
  Ptr_hashentry **table = hashtable->table;

  if(token==NULL || size == 0 || table == NULL) return NULL;
  hashcode=str_hash(token);
  idx=hashcode % size;
  preventry=&table[idx];
  while(1)
  {
    if( !(*preventry) )          /* empty slot */
    {
      if(what==XINSERT || what == XINSERT_NOREPLACE)            /* insert data */
      {
        Ptr_hashentry *entry = (Ptr_hashentry *)my_malloc(_ALLOC_ID_, sizeof( Ptr_hashentry ));
        entry->next=NULL;
        entry->token=NULL;
        my_strdup2(_ALLOC_ID_, &entry->token, token);
        entry->value = value;
        entry->hash=hashcode;
        *preventry=entry;
      }
      return NULL; /* if element inserted return NULL since it was not in table */
    }
    if( (*preventry) -> hash==hashcode && strcmp(token,(*preventry)->token)==0 ) /* found a matching token */
    {
      if(what==XDELETE)             /* remove token from the hash table ... */
      {
        Ptr_hashentry *saveptr;
        saveptr=(*preventry)->next;
        my_free(_ALLOC_ID_, &(*preventry)->token);
        my_free(_ALLOC_ID_, &(*preventry));
        *preventry=saveptr;
      }
      else if(what == XINSERT ) {
        (*preventry)->value = value;
      }
      return (*preventry);   /* found matching entry, return the address */
    }
    preventry=&(*preventry)->next; /* descend into the list. */
  }
}

void ptr_hash_init(Ptr_hashtable *hashtable, int size)
{
  if(hashtable->size !=0 || hashtable->table != NULL) {
    dbg(0, "ptr_hash_init(): Warning hash table not empty, possible data leak\n");
  }
  hashtable->size = size;
  hashtable->table = my_calloc(_ALLOC_ID_, size, sizeof(Ptr_hashentry *));
}

static void ptr_hash_free_entry(Ptr_hashentry *entry)
{
  Ptr_hashentry *tmp;
  while( entry ) {
    tmp = entry -> next;
    my_free(_ALLOC_ID_, &(entry->token));
    my_free(_ALLOC_ID_, &entry);
    entry = tmp;
  }
}


void ptr_hash_free(Ptr_hashtable *hashtable)
{
  if(hashtable->table) {
    int i;
    Ptr_hashentry **table = hashtable->table;
    for(i=0;i < hashtable->size; ++i)
    {
      ptr_hash_free_entry( table[i] );
      table[i] = NULL;
    }
    my_free(_ALLOC_ID_, &(hashtable->table));
    hashtable->size = 0;
  }
}
