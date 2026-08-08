/* File: check.c
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
#ifdef __unix__
#include <sys/select.h> /* select() */
#endif
static int check_includes(double x1a, double y1a, double x2a, double y2a,
                   double x1b, double y1b, double x2b, double y2b)
{
  if( x1b >= x1a && x2b <= x2a && y1b >= y1a && y2b <= y2a &&
      ( (x2a-x1a)*(y2b-y1b) == (x2b-x1b)*(y2a-y1a) ) /* parallel */
  ) {
    return 1;
  }
  return 0;
}

static int check_breaks(double x1, double y1, double x2, double y2, double x, double y)
{
  if( ( (x > x1 && x < x2) || (y > y1 && y < y2) ) &&
      ( (x2-x1)*(y-y1) == (x-x1)*(y2-y1) ) /* parallel */
  ) {
    return 1;
  }
  return 0;
}


/* predicates for wire_delete_compact() — see wire lifecycle census */
static int wire_doomed_flagged(int n, void *arg)
{
  return ((unsigned short *)arg)[n];
}

void update_conn_cues(int layer, int draw_cues, int dr_win)
{
  int k, i, l, sqx, sqy, save_draw;
  Wireentry *wptr;
  double x0, y0;
  double x1, y1, x2, y2;
  Wireentry *wireptr;
  xWire * const wire = xctx->wire;
  Iterator_ctx ctx;

  hash_wires(); /* must be done also if wires==0 to clear wire_spatial_table */
  if(!xctx->wires) return;
  if(!xctx->draw_dots) return;
  if(xctx->cadhalfdotsize*xctx->mooz<0.7) return;
  x1 = X_TO_XSCHEM(xctx->areax1);
  y1 = Y_TO_XSCHEM(xctx->areay1);
  x2 = X_TO_XSCHEM(xctx->areax2);
  y2 = Y_TO_XSCHEM(xctx->areay2);
  for(init_wire_iterator(&ctx, x1, y1, x2, y2); ( wireptr = wire_iterator_next(&ctx) ) ;) {
    k=wireptr->n;
    if(skip_wire(k)) continue;
    /* optimization when editing small areas (detailed zoom)  of a huge schematic */
    if(LINE_OUTSIDE(wire[k].x1, wire[k].y1, wire[k].x2, wire[k].y2, x1, y1, x2, y2)) continue;
    for(l = 0;l < 2; ++l) {
      if(l==0 ) {
        if(wire[k].end1 !=-1) continue;
        wire[k].end1=0;
        x0 = wire[k].x1;
        y0 = wire[k].y1;
      } else {
        if(wire[k].end2 !=-1) continue;
        wire[k].end2=0;
        x0 = wire[k].x2;
        y0 = wire[k].y2;
      }
      get_square(x0, y0, &sqx, &sqy);
      for(wptr = xctx->wire_spatial_table[sqx][sqy] ; wptr ; wptr = wptr->next) {
        i = wptr->n;
        if(skip_wire(i)) continue;
        if(i == k) {
          continue; /* no check wire against itself */
        }
        if( touch(wire[i].x1, wire[i].y1, wire[i].x2, wire[i].y2, x0,y0) ) {
          if( (x0 != wire[i].x1 && x0 != wire[i].x2) ||
              (y0 != wire[i].y1 && y0 != wire[i].y2) ) {
            if(l == 0) wire[k].end1 += 2;
            else     wire[k].end2 += 2;
          } else {
            if(l == 0) wire[k].end1 += 1;
            else     wire[k].end2 += 1;
          }
        }
      }
    }
  }
  dbg(3, "update_conn_cues(): check3\n");
  if(draw_cues) {
    save_draw = xctx->draw_window; xctx->draw_window = dr_win;
    for(init_wire_iterator(&ctx, x1, y1, x2, y2); ( wireptr = wire_iterator_next(&ctx) ) ;) {
      i = wireptr->n;
      if(skip_wire(i)) continue;
      /* optimization when editing small areas (detailed zoom)  of a huge schematic */
      if(LINE_OUTSIDE(wire[i].x1, wire[i].y1,
                      wire[i].x2, wire[i].y2, x1, y1, x2, y2)) continue;
      if( wire[i].end1 >1 ) {
        filledarc(layer, ADD, wire[i].x1, wire[i].y1, xctx->cadhalfdotsize, 0, 360);
      }
      if( wire[i].end2 >1 ) {
        filledarc(layer, ADD, wire[i].x2, wire[i].y2, xctx->cadhalfdotsize, 0, 360);
      }
    }
    filledarc(layer, END, 0.0, 0.0, 0.0, 0.0, 0.0);
    xctx->draw_window = save_draw;
  }
}

void sleep_ms(int milliseconds)
{
  #ifdef __unix__
  struct timeval tv;
  tv.tv_sec = milliseconds / 1000;
  tv.tv_usec = milliseconds % 1000 * 1000;
  select(0, NULL, NULL, NULL, &tv);
  #else
  Sleep(milliseconds);
  #endif
}

/* start = 0: initialize timer
 * start = 1: return elapsed time since previous call
 * start = 2: return total time from initialize */
double timer(int start)
{
  /* used only for test mode. No problem with switching schematic context */
  static double st, cur, lap; /* safe to keep even with multiple schematics */
  if(start == 0) return lap = st = (double) clock() / CLOCKS_PER_SEC;
  else if(start == 1) {
    double prevlap = lap;
    lap = cur = (double) clock() / CLOCKS_PER_SEC;
    return cur - prevlap;
  } else {
    cur = (double) clock() / CLOCKS_PER_SEC;
    return cur - st;
  }
}

static int touches_inst_pin(double x, double y, int inst); /* defined below; reused here */

/* doc/claude/specs/wire_label_ride.md §5.2: is instance i a NET LABEL, i.e. an instance whose
 * symbol type is exactly "label"? A net label's PINLAYER rect is a NAMING ANCHOR, not copper
 * geometry: it must not mint a connecting stub during a drag (R1), must not split a wire (R2,
 * S2) and must not block a collinear merge -- its own connection is carried by the per-gesture
 * rider set instead (§5.3).
 * Deliberately strcmp(type, "label") and NOT the IS_LABEL_OR_PIN macro: ipin / opin / iopin are
 * real hierarchy terminals and every current behaviour of theirs is preserved. Deliberately not
 * IS_LABEL_SH_OR_PIN either -- `scope` and `show_label` are out of scope here, and `bus_tap` is a
 * genuine two-pin copper object.
 * Exported: the three consumers live in check.c, actions.c and move.c. */
int inst_is_netlabel(int i)
{
  const char *type;
  if(i < 0 || i >= xctx->instances) return 0;
  if(xctx->inst[i].ptr < 0) return 0;               /* unlinked symbol: no type to ask about */
  type = (xctx->inst[i].ptr + xctx->sym)->type;
  return type && !strcmp(type, "label");
}

/* Return 1 if any instance PIN coincides EXACTLY with (x, y). Pin-labels and bus_taps are just
 * instances carrying PINLAYER pins, so they are covered too.
 * Used by trim_wires' collinear-rejoin to REFUSE welding two segments across an
 * attachment point (an instance pin between them is a meaningful segment
 * boundary for click-selection). Exact double compare (delegated to touches_inst_pin) is
 * correct here: pin coords and wire endpoints are on-grid, so a genuine attachment matches
 * exactly; a pin merely NEAR the wire is not an attachment (and is not connected either --
 * see doc/claude/specs/wire_segment_splitting.md, W0 + Hazard H2).
 * Only called (when splitting is active) from the merge branch after the cheap
 * end1/end2==0 test, i.e. for the rare degree-2 collinear joints trim would collapse.
 *
 * skip_labels: 1 = a type=label instance's pin is NOT a boundary, so two collinear halves
 *   meeting at a net label WELD (doc/claude/specs/wire_label_ride.md R2, change #7). This is
 *   the MATCHED PAIR of break_wires_at_attach_points()' label skip (change #6) and must never
 *   ship without it: relax the splitter alone and a wire that was split at a label can never
 *   re-weld -- a permanent, invisible fragment. Relax the merge alone and every edit splits at
 *   the label and immediately welds it back, churning set_modify() for nothing.
 *   0 = pre-S2 behaviour: any pin, label or device, blocks the weld.
 * The caller decides, from `label_splits_wires`; a DEVICE pin blocks the weld either way. */
static int any_inst_pin_at(double x, double y, int skip_labels)
{
  int i;
  for(i = 0; i < xctx->instances; ++i) {
    if(skip_labels && inst_is_netlabel(i)) continue;
    if(touches_inst_pin(x, y, i)) return 1;
  }
  return 0;
}

/* Cadence net-label drop constraint (doc/claude/specs/add_wire_label.md): return 1 if (x,y)
 * lands on COPPER -- ON any wire segment (touch(), endpoints included) OR EXACTLY on an
 * instance PINLAYER pin (touches_inst_pin(), exact on-grid compare, covers net-labels /
 * pin-labels / bus_taps which are just instances carrying PINLAYER pins). SELECTED wires and
 * instances are skipped so the label PREVIEW being placed (it is selected) never satisfies the
 * rule against its own pin. Used by the add_wire_label drop gate. */
int point_on_wire_or_pin(double x, double y)
{
  int i;
  for(i = 0; i < xctx->wires; ++i) {
    if(xctx->wire[i].sel == SELECTED) continue;
    if(touch(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2, x, y))
      return 1;
  }
  for(i = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].sel == SELECTED) continue;
    if(touches_inst_pin(x, y, i)) return 1;
  }
  return 0;
}

void trim_wires(void)
{
  int k, sqx, sqy, doloops;
  double x0, y0;
  int j, i, changed;
  int includes, breaks;
  Wireentry *wptr;
  unsigned short *wireflag=NULL;
  /* The pin-aware-merge guard (below) only matters when wire auto-splitting is active, and
   * gating it here keeps default (autotrim off) trim/join behaviour byte-for-byte unchanged
   * -- spec D2. It also short-circuits the O(inst*pins) any_inst_pin_at() away entirely on
   * the default path. See doc/claude/specs/wire_segment_splitting.md. */
  int split_active = tclgetboolvar("autotrim_wires");
  /* A net label does not cut copper (doc/claude/specs/wire_label_ride.md R2, change #7). This is
   * its OWN gate, deliberately not folded into split_active: split_active exists to keep the
   * DEFAULT (autotrim off) trim/join byte-for-byte identical (spec D2) and to short-circuit the
   * O(inst*pins) probe off that path, while label_splits_wires decides only WHICH pins count as a
   * boundary once splitting is active. Sharing one flag would make the escape hatch unable to
   * restore pre-S2 behaviour, and would make the label rule depend on autotrim in the merge but
   * not in the splitter. Device-pin behaviour is unaffected in either autotrim mode. */
  int label_splits = tclgetboolvar("label_splits_wires");

  doloops = 0;
  xctx->prep_hash_wires = 0;
  /* timer(0); */
  do {
    /* dbg(1, "trim_wires(): start: %g\n", timer(1)); */
    changed = 0;
    ++doloops;
    hash_wires(); /* end1 and end2 reset to -1 */
    /* dbg(1, "trim_wires(): hash_wires_1: %g\n", timer(1)); */

    /* break all wires */
    for(i=0;i<xctx->wires; ++i) {
      int hashloopcnt = 0;
      if(skip_wire(i)) continue;
      x0 = xctx->wire[i].x1;
      y0 = xctx->wire[i].y1;
      get_square(x0, y0, &sqx, &sqy);
      k=1;
      for(wptr = xctx->wire_spatial_table[sqx][sqy] ; ; wptr = wptr->next) {
        if(!wptr) {
          if(k == 1) {
            x0 = xctx->wire[i].x2;
            y0 = xctx->wire[i].y2;
            get_square(x0, y0, &sqx, &sqy);
            wptr = xctx->wire_spatial_table[sqx][sqy];
            k = 2;
            if(!wptr) break;
          } else break;
        }
        j = wptr->n;
        if(i == j) continue;
        if(skip_wire(j)) continue;
        ++hashloopcnt;
        breaks = check_breaks(xctx->wire[j].x1, xctx->wire[j].y1, xctx->wire[j].x2, xctx->wire[j].y2, x0, y0);
        if(breaks) { /* wire[i] breaks wire[j] */
          dbg(2, "trim_wires(): %d (%g %g %g %g) breaks %d (%g %g %g %g) in (%g, %g)\n", i,
            xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2,
            j,
            xctx->wire[j].x1, xctx->wire[j].y1, xctx->wire[j].x2, xctx->wire[j].y2,
            x0, y0
          );
          {
            unsigned short newsel;
            if(xctx->wire[j].sel == SELECTED1) {
              newsel = SELECTED1;
              xctx->wire[j].sel = 0;
            } else if(xctx->wire[j].sel == SELECTED2) {
              newsel = 0;
              xctx->wire[j].sel = SELECTED2;
            } else if(xctx->wire[j].sel == SELECTED) {
              newsel = SELECTED;
              xctx->wire[j].sel = SELECTED;
            } else {
              newsel = 0;
              xctx->wire[j].sel = 0;
            }
            wire_store_split(j, x0, y0, newsel);
          }
          xctx->wire[j].x1 = x0;
          xctx->wire[j].y1 = y0;
          i--; /* redo current i iteration, since we break the 'j' loop due to changed wire hash table */
          hash_wire(XDELETE, j, 0); /* rehash since endpoint x1, y1 changed */
          hash_wire(XINSERT, j, 0);
          changed = 1;
          break;
        }
      }
      dbg(2, "trim_wires(): hashloopcnt = %d, wires = %d\n", hashloopcnt, xctx->wires);
    }
    /* dbg(1, "trim_wires(): break: %g\n", timer(1)); */
    /* reduce included wires */
    my_realloc(_ALLOC_ID_, &wireflag, xctx->wires*sizeof(unsigned short));
    memset(wireflag, 0, xctx->wires*sizeof(unsigned short));
    for(i=0;i<xctx->wires; ++i) {
      if(wireflag[i]) continue;
      if(skip_wire(i)) continue;
      x0 = xctx->wire[i].x1;
      y0 = xctx->wire[i].y1;
      get_square(x0, y0, &sqx, &sqy);
      k=1;
      for(wptr = xctx->wire_spatial_table[sqx][sqy] ; ; wptr = wptr->next) {
        if(!wptr) {
          if(k == 1) {
            x0 = xctx->wire[i].x2;
            y0 = xctx->wire[i].y2;
            get_square(x0, y0, &sqx, &sqy);
            wptr = xctx->wire_spatial_table[sqx][sqy];
            k = 2;
            if(!wptr) break;
          } else break;
        }
        j = wptr->n;
        if(skip_wire(j)) continue;
        if(i == j || wireflag[j]) continue;

        includes = check_includes(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2,
                                  xctx->wire[j].x1, xctx->wire[j].y1, xctx->wire[j].x2, xctx->wire[j].y2);
        if(includes) {
          dbg(2, "trim_wires(): %d (%g %g %g %g) include %d (%g %g %g %g)\n", i,
            xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2,
            j,
            xctx->wire[j].x1, xctx->wire[j].y1, xctx->wire[j].x2, xctx->wire[j].y2
          );
          wireflag[j] = 1;
        }
      }
    }
    /* dbg(1, "trim_wires(): included: %g\n", timer(1)); */

    /* delete wires */
    j = wire_delete_compact(wire_doomed_flagged, wireflag);
    if(j) {
      xctx->prep_hash_wires=0;
      changed = 1;
    }
    /* dbg(1, "trim_wires(): delete_1: %g\n", timer(1)); */

    /* after wire deletions full rehash is needed */
    hash_wires();

    my_realloc(_ALLOC_ID_, &wireflag, xctx->wires*sizeof(unsigned short));
    memset(wireflag, 0, xctx->wires*sizeof(unsigned short));
    /* dbg(1, "trim_wires(): hash_wires_2: %g\n", timer(1)); */

    /* update endpoint (end1, end2) connection counters */
    for(i=0;i<xctx->wires; ++i) {
      x0 = xctx->wire[i].x1;
      y0 = xctx->wire[i].y1;
      xctx->wire[i].end1 = xctx->wire[i].end2 = 0;
      if(skip_wire(i)) continue;
      get_square(x0, y0, &sqx, &sqy);
      k=1;
      for(wptr = xctx->wire_spatial_table[sqx][sqy] ; ; wptr = wptr->next) {
        if(!wptr) {
          if(k == 1) {
            x0 = xctx->wire[i].x2;
            y0 = xctx->wire[i].y2;
            get_square(x0, y0, &sqx, &sqy);
            wptr = xctx->wire_spatial_table[sqx][sqy];
            k = 2;
            if(!wptr) break;
          } else break;
        }
        j = wptr->n;
        if(skip_wire(j)) continue;
        if(i == j) continue;
        if( touch(xctx->wire[j].x1, xctx->wire[j].y1, xctx->wire[j].x2, xctx->wire[j].y2, x0,y0) ) {
          /* not parallel */
          if( (xctx->wire[i].x2 -  xctx->wire[i].x1) * (xctx->wire[j].y2 -  xctx->wire[j].y1) !=
              (xctx->wire[j].x2 -  xctx->wire[j].x1) * (xctx->wire[i].y2 -  xctx->wire[i].y1)) {
            /* wire[i] touches wire[j] in an inner point, not at edge */
            if( (x0 != xctx->wire[j].x1 && x0 != xctx->wire[j].x2) ||
                (y0 != xctx->wire[j].y1 && y0 != xctx->wire[j].y2) ) {
              if(k == 1) xctx->wire[i].end1 += 2;
              else       xctx->wire[i].end2 += 2;
            } else {
              if(k == 1) xctx->wire[i].end1 += 1;
              else       xctx->wire[i].end2 += 1;
            }
          }
        }
      }
    }
    /* dbg(1, "trim_wires(): endpoints: %g\n", timer(1)); */

    /* merge parallel touching (in wire[i].x2, wire[i].y2) wires */
    for(i=0;i<xctx->wires; ++i) {
      if(wireflag[i]) continue;
      if(skip_wire(i)) continue;
      x0 = xctx->wire[i].x2;
      y0 = xctx->wire[i].y2;
      get_square(x0, y0, &sqx, &sqy);
      for(wptr = xctx->wire_spatial_table[sqx][sqy] ; wptr ; wptr = wptr->next) {
        j = wptr->n;
        if(skip_wire(j)) continue;
        if(i == j || wireflag[j]) continue;
        if( touch(xctx->wire[j].x1, xctx->wire[j].y1, xctx->wire[j].x2, xctx->wire[j].y2, x0,y0) &&
            /* parallel */
            (xctx->wire[i].x2 -  xctx->wire[i].x1) * (xctx->wire[j].y2 -  xctx->wire[j].y1) ==
            (xctx->wire[j].x2 -  xctx->wire[j].x1) * (xctx->wire[i].y2 -  xctx->wire[i].y1) &&
            /* touch in wire[j].x1, wire[j].y1 */
            xctx->wire[j].x1 == x0 && xctx->wire[j].y1 == y0 &&
            /* no other connecting wires */
            xctx->wire[i].end2 == 0 && xctx->wire[j].end1 == 0 &&
            /* and (when splitting is active) no instance pin at the joint: an attachment there
             * is a meaningful segment boundary, do not weld across it (W0 -- pin-aware merge).
             * Also gives free auto-rejoin when the pin is later removed. Gated on split_active
             * so default trim/join is unchanged (D2). A NET LABEL is excluded unless
             * label_splits_wires is set: it names copper, it does not cut it (wire_label_ride.md
             * R2, change #7 -- the matched pair of the splitter's label skip). THIS IS THE ONLY
             * LIVE CONSUMER of any_inst_pin_at(): merge_collinear_wires' pin-aware arm is
             * unreachable today (its sole caller, save.c, is pin-blind). */
            (!split_active || !any_inst_pin_at(x0, y0, !label_splits)) ) {
          dbg(2, "trim_wires(): i=%d merged with j=%d\n", i, j);
          xctx->wire[i].x2 = xctx->wire[j].x2;
          xctx->wire[i].y2 = xctx->wire[j].y2;
          if(xctx->wire[j].sel) xctx->wire[i].sel = xctx->wire[j].sel;
          wireflag[j] = 1;
          break;
        }
      }
    }
    /* dbg(1, "trim_wires(): merge: %g\n", timer(1)); */

    /* delete wires */
    for(i=0;i<xctx->wires; ++i) {
      xctx->wire[i].end1 = xctx->wire[i].end2 = -1; /* reset all endpoints we recalculate all at end */
    }
    j = wire_delete_compact(wire_doomed_flagged, wireflag);
    if(j) {
      xctx->prep_hash_wires=0; /* after wire deletions full rehash is needed */
      changed = 1;
    }
    /* dbg(1, "trim_wires(): delete_2: %g\n", timer(1)); */

    if(changed) {
      xctx->need_reb_sel_arr = 1;
      xctx->prep_net_structs=0;
      xctx->prep_hi_structs=0;
      set_modify(1);
    }
  } while(changed);
  dbg(1, "trim_wires(): doloops=%d changed=%d\n", doloops, changed);
  my_free(_ALLOC_ID_, &wireflag);
  update_conn_cues(WIRELAYER, 0, 0);
}

static int touches_inst_pin(double x, double y, int inst)
{
  int rects, r;
  double x0, y0;
  int touches = 0;
  if((xctx->inst[inst].ptr >= 0)) {
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r=0;r<rects;r++)
    {
      get_inst_pin_coord(inst, r, &x0, &y0);
      if(x == x0 && y == y0) {
        touches = 1;
        break;
      }
    }
  }
  dbg(1, "touches_inst_pin(): %g %g : touches =%d on inst %d\n", x, y, touches, inst);
  return touches;
}

/* return 2 if x0, y0 is on the segment
 * return 1 if x0, y0 is less than cadsnap (10) from the segment
 * return 0 if nothing will be cut (mouse too far away or degenerated segment)
 * In this case x0, y0 are reset to the closest point on the segment */
static int closest_point_calculation(double x1, double y1, double x2, double y2,
                                     double *x0, double *y0, int align)
{
  double projection, sq_distance, x3, y3;
  double cs = tclgetdoublevar("cadsnap"), sq_cs;
  int ret = 0;

  sq_cs = cs * cs; /* get squared value to compare with squared distance */

  if(x1 == x2 && y1 == y2) {
    ret = 0;
  } else {
    projection = (x2 - x1) * (*x0 - x1) + (y2 - y1) * (*y0 - y1);
    projection /= (x2 - x1) * ( x2 - x1) + (y2 - y1) * (y2 - y1);
    x3 = x1 + projection * (x2 - x1);
    y3 = y1 + projection * (y2 - y1);
    sq_distance = (*x0 - x3) * (*x0 - x3) + (*y0 - y3) * (*y0 - y3);
    if(projection <= 1 && projection >= 0) { /* point is within x1,y1 - x2,y2 */
      if(sq_distance == 0) ret = 2;
      else if(sq_distance <  sq_cs) ret = 1;
    }
    dbg(1, "x3 = %g y3=%g dist=%g ret=%d\n", x3, y3, sqrt(sq_distance), ret);
  }

  if(ret == 1) {
    if(align) {
      *x0 = my_round(x3 / cs) * cs;
      *y0 = my_round(y3 / cs) * cs;
    } else {
      *x0 = x3;
      *y0 = y3;
    }
    /* if ret == 2 leave x0 and y0 as they are since x0,y0 already touches wire */
  }
  return ret;
}

void break_wires_at_point(double x0, double y0, int align)
{
  int r, i, sqx, sqy;
  Wireentry *wptr;
  int changed=0;
  double x1, y1, x2, y2;

  dbg(1, "break_wires_at_pins(): processing pin %g %g\n", x0, y0);
  get_square(x0, y0, &sqx, &sqy);
  for(wptr=xctx->wire_spatial_table[sqx][sqy]; wptr; wptr=wptr->next) {
    i = wptr->n;
    x1 = xctx->wire[i].x1;
    y1 = xctx->wire[i].y1;
    x2 = xctx->wire[i].x2;
    y2 = xctx->wire[i].y2;
    r = closest_point_calculation(x1, y1, x2, y2, &x0, &y0, align);
    if( r != 0 && (r == 1 || touch(x1, y1, x2, y2, x0,y0) )) {
      if( (x0 != x1 && x0 != x2) ||
          (y0 != y1 && y0 != y2) ) {
        dbg(1, "break_wires_at_point(): processing wire %d: %g %g %g %g\n",
            i, xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2);
        if(!changed) { xctx->push_undo(); changed=1;}
        wire_store_split(i, x0, y0, 0);
        xctx->need_reb_sel_arr=1;
        xctx->wire[i].x1 = x0;
        xctx->wire[i].y1 = y0;
        xctx->wire[i].sel = 0;
        xctx->wire[i].end1 = 1;
      } /* if( (x0!=xctx->wire[i].x1 && x0!=xctx->wire[i].x2) || ... ) */
    } /* if( touch(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2, x0,y0) ) */
  } /* for(wptr=xctx->wire_spatial_table[sqx][sqy]; wptr; wptr=wptr->next) */
  if(changed) {
    int w = xctx->draw_window;
    int p = xctx->draw_pixmap;
    xctx->need_reb_sel_arr = 1;
    rebuild_selected_array();
    draw();
    xctx->draw_window = 1;
    xctx->draw_pixmap = 0;
    filledarc(PINLAYER, NOW, x0, y0, xctx->cadhalfdotsize, 0, 360);
    xctx->draw_window = w;
    xctx->draw_pixmap = p;

  }
}

/* if remove=1 is given wires that are all inside instance bboxes are deleted */
void break_wires_at_pins(int remove)
{
  int k, i, j, r, rects, sqx, sqy;
  Wireentry *wptr;
  double x0, y0;
  int changed=0;
  int deleted_wire = 0;
  hash_wires();
  rebuild_selected_array();

  /* break wires that touch selected instance pins */
  for(j=0;j<xctx->lastsel; ++j) if(xctx->sel_array[j].type==ELEMENT) {
    k = xctx->sel_array[j].n;
    if( (rects = (xctx->inst[k].ptr+ xctx->sym)->rects[PINLAYER]) > 0 )
    {
      for(r=0;r<rects;r++) {
        get_inst_pin_coord(k, r, &x0, &y0);
        dbg(1, "break_wires_at_pins(): processing pin %g %g\n", x0, y0);
        get_square(x0, y0, &sqx, &sqy);
        for(wptr=xctx->wire_spatial_table[sqx][sqy]; wptr; wptr=wptr->next) {
          i = wptr->n;
          if( touch(xctx->wire[i].x1, xctx->wire[i].y1,
                    xctx->wire[i].x2, xctx->wire[i].y2, x0,y0) ) {
            if( (x0!=xctx->wire[i].x1 && x0!=xctx->wire[i].x2) ||
                (y0!=xctx->wire[i].y1 && y0!=xctx->wire[i].y2) ) {
              dbg(1, "break_wires_at_pins(): processing wire %d: %g %g %g %g\n",
                  i, xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2);
              if(!changed) { xctx->push_undo(); changed=1;}
              if(!remove || !RECT_INSIDE(xctx->wire[i].x1, xctx->wire[i].y1, x0, y0,
                             xctx->inst[k].xx1, xctx->inst[k].yy1, xctx->inst[k].xx2, xctx->inst[k].yy2)
                             || (!touches_inst_pin(xctx->wire[i].x1, xctx->wire[i].y1, k) && xctx->wire[i].end1 > 0)
                ) {
                wire_store_split(i, x0, y0, xctx->wire[i].sel);
                xctx->need_reb_sel_arr=1;
              } else {
                deleted_wire = 1;
              }
              xctx->wire[i].x1 = x0;
              xctx->wire[i].y1 = y0;
              xctx->wire[i].end1 = 1;
              if(remove && RECT_INSIDE(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2,
                  xctx->inst[k].xx1, xctx->inst[k].yy1, xctx->inst[k].xx2, xctx->inst[k].yy2)) {

                if(touches_inst_pin(xctx->wire[i].x2, xctx->wire[i].y2, k) || xctx->wire[i].end2 == 0) {
                  dbg(1, "break_wires_at_pins(): wire %d needs to be deleted: %g %g %g %g\n",
                          i, xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2);
                  /* mark for deletion only if no other nets attached */
                  xctx->wire[i].sel = SELECTED4; /* use a special flag to later delete these wires
                                                  * only and not other seleted wires */
                  dbg(1, "break_wires_at_pins(): mark wire %d for deletion: end2=%d\n", i, xctx->wire[i].end2);
                }
              }
            } /* if( (x0!=xctx->wire[i].x1 && x0!=xctx->wire[i].x2) || ... ) */
            else if(remove) {
              int t1 = touches_inst_pin(xctx->wire[i].x1, xctx->wire[i].y1, k);
              int t2 = touches_inst_pin(xctx->wire[i].x2, xctx->wire[i].y2, k);
              int e1 = xctx->wire[i].end1;
              int e2 = xctx->wire[i].end2;
              int inside = RECT_INSIDE(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2,
                           xctx->inst[k].xx1, xctx->inst[k].yy1, xctx->inst[k].xx2, xctx->inst[k].yy2);
              dbg(1, "i=%d, t1=%d, t2=%d, e1=%d, e2=%d\n", i, t1, t2, e1, e2);
              if(inside && ( (t1 && t2) || (t1 && e2 == 0) || (t2 && e1 == 0) )) {
                xctx->wire[i].sel = SELECTED4;
                if(!changed) { xctx->push_undo(); changed=1;}
              }
            }
          } /* if( touch(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2, x0,y0) ) */
        } /* for(wptr=xctx->wire_spatial_table[sqx][sqy]; wptr; wptr=wptr->next) */
      } /* for(r=0;r<rects;r++) */
    } /* if( (rects = (xctx->inst[k].ptr+ xctx->sym)->rects[PINLAYER]) > 0 ) */
  } /* for(j=0;j<xctx->lastsel; ++j) if(xctx->sel_array[j].type==ELEMENT) */

  if(remove) {
    if(delete_wires(SELECTED4)) {
      deleted_wire = 1;
    }
  }
  /* break wires that touch selected wires */
  rebuild_selected_array();
  for(j=0;j<xctx->lastsel; ++j) if(xctx->sel_array[j].type==WIRE) {
  /* for(k=0; k < xctx->wires; ++k) { */
    int l;

    k = xctx->sel_array[j].n;
    for(l=0;l<2; ++l) {
      if(l==0 ) {
        x0 = xctx->wire[k].x1;
        y0 = xctx->wire[k].y1;
      } else {
        x0 = xctx->wire[k].x2;
        y0 = xctx->wire[k].y2;
      }
      get_square(x0, y0, &sqx, &sqy);
      /* printf("  k=%d, x0=%g, y0=%g\n", k, x0, y0); */
      for(wptr=xctx->wire_spatial_table[sqx][sqy] ; wptr ; wptr = wptr->next) {
        i = wptr->n;
        /* printf("check wire %d to wire %d\n", k, i); */
        if(i==k) {
          continue; /* no check wire against itself */
        }
        if( touch(xctx->wire[i].x1, xctx->wire[i].y1,
                  xctx->wire[i].x2, xctx->wire[i].y2, x0,y0) )
        {
          if( (x0!=xctx->wire[i].x1 && x0!=xctx->wire[i].x2) ||
              (y0!=xctx->wire[i].y1 && y0!=xctx->wire[i].y2) ) {
            /* printf("touch in mid point: %d\n", l+1); */
            if(!changed) { xctx->push_undo(); changed=1;}
            {
              int n = wire_store_split(i, x0, y0, SELECTED);
              set_first_sel(WIRE, n, 0);
            }
            xctx->need_reb_sel_arr=1;
            xctx->wire[i].x1 = x0;
            xctx->wire[i].y1 = y0;
            xctx->wire[i].end1 = 1;
          }
        }
      }
    }
  }
  if(changed) {
    set_modify(1);
    xctx->prep_net_structs=0;
    xctx->prep_hi_structs=0;
    xctx->prep_hash_wires=0;
    prepare_netlist_structs(0);
    if(deleted_wire) {
      if(tclgetboolvar("autotrim_wires")) trim_wires();
      update_conn_cues(WIRELAYER, 0, 0);
      draw();
    }
  }

}

/* Split every wire at every interior instance-pin / net-label attachment point, so each
 * inter-attachment span becomes an independent (clickable) wire object. Connectivity is
 * coordinate-based and unchanged (INV-1). In-memory only: coalesce-on-save (W4,
 * merge_collinear_wires) re-joins these attachment-pin splits on save so the .sch stays
 * byte-stable (D1). Uses the EXACT stored pin coordinate (get_inst_pin_coord) and requires
 * a true touch(), so a pin merely NEAR the wire neither splits nor connects (Hazard H2);
 * splits only where a pin coincides with a wire's interior, never at a bare X-crossing
 * (Hazard H3). Does NOT push_undo -- the caller owns undo (load: no push; edit: caller
 * pushes). Returns the number of splits performed.
 * See doc/claude/specs/wire_segment_splitting.md (W1). */
int break_wires_at_attach_points(void)
{
  int k, i, r, rects, sqx, sqy;
  Wireentry *wptr;
  double x0, y0;
  int nsplit = 0;
  /* doc/claude/specs/wire_label_ride.md R2 (change #6): a type=label instance's PINLAYER rect is
   * a NAMING ANCHOR, not copper geometry, so by default it is not a segment boundary and does not
   * split. Read once per sweep. Matched pair with any_inst_pin_at()'s skip_labels above -- see the
   * comment there for why relaxing one without the other is a bug either way. */
  int label_splits = tclgetboolvar("label_splits_wires");

  /* Force a fresh spatial table: hash_wires() no-ops when prep_hash_wires==1 (netlist.c),
   * and an earlier prepare_netlist_structs / check_collapsing_objects in the load path may
   * have built it (or left it stale after a wire deletion). Walking a stale table would
   * read reindexed / out-of-range wire slots. trim_wires() takes the same precaution. */
  xctx->prep_hash_wires = 0;
  hash_wires();
  for(k = 0; k < xctx->instances; ++k) {
    if(xctx->inst[k].ptr < 0) continue;
    /* R2: a net label names the copper it taps, it does not cut it. What actually binds it to the
     * net is touch() in name_attached_inst_to_net() (netlist.c), which is interior-inclusive, so
     * the split was never the connection -- corpus-verified connectivity-neutral over 5393 label
     * instances / a 244-schematic SPICE A/B (spec section 9). Only the CLICK granularity at a
     * label is given up; a device pin keeps it (the resistor-tap case is the loop's next
     * iteration, untouched). */
    if(!label_splits && inst_is_netlabel(k)) continue;
    rects = (xctx->inst[k].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; ++r) {
      get_inst_pin_coord(k, r, &x0, &y0);
      get_square(x0, y0, &sqx, &sqy);
      for(wptr = xctx->wire_spatial_table[sqx][sqy]; wptr; wptr = wptr->next) {
        i = wptr->n;
        if( touch(xctx->wire[i].x1, xctx->wire[i].y1,
                  xctx->wire[i].x2, xctx->wire[i].y2, x0, y0) ) {
          /* strictly interior: (x0,y0) not coincident with either endpoint */
          if( (x0 != xctx->wire[i].x1 && x0 != xctx->wire[i].x2) ||
              (y0 != xctx->wire[i].y1 && y0 != xctx->wire[i].y2) ) {
            wire_store_split(i, x0, y0, xctx->wire[i].sel); /* head [old x1..x0], keeps prop/node */
            xctx->wire[i].x1 = x0;                          /* tail becomes [x0..old x2] */
            xctx->wire[i].y1 = y0;
            xctx->wire[i].end1 = 1;
            xctx->need_reb_sel_arr = 1;
            ++nsplit;
          }
        }
      }
    }
  }
  if(nsplit) {
    /* the wire array changed: invalidate every derived cache (matching
     * break_wires_at_pins), so a later netlist/hilight rebuilds against the new geometry.
     * Harmless at load (both already 0) but required when called from edit paths (W3). */
    xctx->prep_hash_wires = 0;
    xctx->prep_net_structs = 0;
    xctx->prep_hi_structs = 0;
  }
  return nsplit;
}

/* Canonical read/edit-time wire-segment maintenance (the caller gates this on
 * autotrim_wires): first split at attachment points, then trim_wires() performs
 * T-junction splits, the PIN-AWARE collinear merge (W0) and the degenerate cull. The order
 * matters -- splitting first, then a pin-aware merge that cannot undo the pin-splits.
 * See doc/claude/specs/wire_segment_splitting.md (W1/W3). */
void maintain_wire_segments(void)
{
  break_wires_at_attach_points();
  trim_wires();
}

/* Prop strings equal (NULL treated as empty). The save-time coalescer requires identical
 * prop_ptr before welding two segments so a user who diverges one segment's attributes keeps
 * that boundary on disk (Hazard H7 -- nothing is silently lost). */
static int wire_prop_eq(const char *a, const char *b)
{
  return !strcmp(a ? a : "", b ? b : "");
}

/* Coalesce a scratch array of wires IN PLACE: re-join every maximal run of collinear,
 * same-prop, abutting segments whose shared joints carry no OTHER (non-collinear) wire
 * endpoint -- a real T-junction stays split. This is the inverse of the read-time split
 * (break_wires_at_attach_points), so a single-N file that was split into clickable segments
 * in memory round-trips to the identical single-N file on disk (spec D1 / W4, section 6.3).
 *
 * `list` MUST be a private copy of the wire records (see the save path in save.c): entries
 * are shallow -- prop_ptr/node are BORROWED from xctx->wire[], never freed or mutated here;
 * only the geometry (x1..y2) of a surviving segment is rewritten. xctx->wire[] is untouched,
 * so the live segmented array (the user's clickable segments) survives a save intact.
 *
 * ignore_pins: 1 = pin-blind -- coalesce ACROSS an attachment pin / net-label, because the
 *   pin is only a SELECTION boundary, not a topology node: the .sch must not persist the
 *   split (the save path uses this). 0 = pin-aware -- refuse to weld across an instance pin,
 *   matching trim_wires' in-memory W0 merge (provided for a future unification of the two
 *   merge sites; not on the current save path).
 * Unlike trim_wires' in-place merge, this ALWAYS requires identical prop_ptr (H7).
 * Returns the compacted survivor count.
 * See doc/claude/specs/wire_segment_splitting.md (W4). */
int merge_collinear_wires(xWire *list, int n, int ignore_pins)
{
  int i, j, e, k, changed;
  int skip_labels;
  char *dead;
  if(n < 2) return n;
  /* Kept in step with trim_wires' merge (wire_label_ride.md change #7): a net label is not a weld
   * barrier unless label_splits_wires is set. CONSISTENCY ONLY, NOT A BEHAVIOUR CHANGE -- the
   * pin-aware arm below is unreachable on the current call graph (the sole caller, save_wire() in
   * save.c, passes ignore_pins = 1), which is also why the Tcl read is skipped in that case. */
  skip_labels = ignore_pins ? 0 : !tclgetboolvar("label_splits_wires");
  dead = my_calloc(_ALLOC_ID_, n, sizeof(char));
  do {
    changed = 0;
    for(i = 0; i < n; ++i) {
      if(dead[i]) continue;
      /* try to absorb a collinear neighbour at either open end of wire i */
      for(e = 0; e < 2; ++e) {
        double px = (e == 0) ? list[i].x1 : list[i].x2;
        double py = (e == 0) ? list[i].y1 : list[i].y2;
        double dxi = list[i].x2 - list[i].x1, dyi = list[i].y2 - list[i].y1;
        int branch = 0, partner = -1;
        if(!ignore_pins && any_inst_pin_at(px, py, skip_labels)) continue;
        for(j = 0; j < n; ++j) {
          double dxj, dyj;
          int parallel, tj;
          if(dead[j] || j == i) continue;
          dxj = list[j].x2 - list[j].x1; dyj = list[j].y2 - list[j].y1;
          parallel = (dxi * dyj == dxj * dyi);
          tj = touch(list[j].x1, list[j].y1, list[j].x2, list[j].y2, px, py);
          if(!tj) continue;
          if(!parallel) { branch = 1; break; } /* real electrical node here: never weld across it */
          /* a collinear wire touching the joint is a merge candidate only if it ENDS there
           * (endpoint match) and carries an identical prop_ptr */
          if( ((px == list[j].x1 && py == list[j].y1) ||
               (px == list[j].x2 && py == list[j].y2)) &&
              partner < 0 && wire_prop_eq(list[i].prop_ptr, list[j].prop_ptr) ) {
            partner = j;
          }
        }
        if(branch || partner < 0) continue;
        /* extend i to the extreme span of {i, partner} along i's direction, drop partner.
         * Projecting all four endpoints handles any collinear orientation and preserves the
         * original endpoint ordering (so a byte-identical record comes back). */
        {
          double px4[4], py4[4], tmin, tmax, dx, dy;
          int m, imin = 0, imax = 0;
          px4[0] = list[i].x1;       py4[0] = list[i].y1;
          px4[1] = list[i].x2;       py4[1] = list[i].y2;
          px4[2] = list[partner].x1; py4[2] = list[partner].y1;
          px4[3] = list[partner].x2; py4[3] = list[partner].y2;
          dx = dxi; dy = dyi;
          if(dx == 0 && dy == 0) { /* degenerate i: fall back to partner's direction */
            dx = list[partner].x2 - list[partner].x1;
            dy = list[partner].y2 - list[partner].y1;
          }
          tmin = tmax = px4[0] * dx + py4[0] * dy;
          for(m = 1; m < 4; ++m) {
            double t = px4[m] * dx + py4[m] * dy;
            if(t < tmin) { tmin = t; imin = m; }
            if(t > tmax) { tmax = t; imax = m; }
          }
          list[i].x1 = px4[imin]; list[i].y1 = py4[imin];
          list[i].x2 = px4[imax]; list[i].y2 = py4[imax];
        }
        dead[partner] = 1;
        changed = 1;
        e = -1; /* rescan both (now-extended) ends of the enlarged wire i */
      }
    }
  } while(changed);
  /* compact survivors to the front, order-preserving */
  k = 0;
  for(i = 0; i < n; ++i) if(!dead[i]) { if(k != i) list[k] = list[i]; ++k; }
  my_free(_ALLOC_ID_, &dead);
  return k;
}
