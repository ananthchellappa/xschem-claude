/* File: flyline.c
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

/* Hover fly-lines -- read-only implicit-connectivity query, shared by the `xschem flylines`
 * command (scheduler.c) and the on-screen overlay (draw_flylines). See
 * doc/claude/specs/hover_flylines.md and doc/claude/suggestions/flyline_implementation_plan.md.
 *
 * INVARIANT (C1): every routine here is pure read-only -- it must NEVER write hilight_table,
 * inst.color, .sel, the modify flag, or saved bytes. It reads xctx object arrays + spatial
 * hashes and produces a FlyResult describing where fly-lines would go; drawing them is the
 * caller's job. This is the load-bearing correctness rule of the whole feature. */

#include "xschem.h"

/* Resolve the net-name token carried by a picked object, mirroring the switch in
 * hilight_net() (hilight.c): a wire carries its net in .node; a net-label / pin symbol
 * carries it in .node[0]; a picked instance pin carries it in .node[pin]. Returns a
 * pointer into xctx (do NOT free) or NULL when the object has no single net. Read-only (C1). */
const char *flyline_net_of(unsigned short type, int n, unsigned int col)
{
  if(type == WIRE) {
    if(n >= 0 && n < xctx->wires) return xctx->wire[n].node;
  } else if(type == ELEMENT) {
    if(n >= 0 && n < xctx->instances) {
      char *symtype = (xctx->inst[n].ptr + xctx->sym)->type;
      if(symtype && xctx->inst[n].node && IS_LABEL_SH_OR_PIN(symtype))
        return xctx->inst[n].node[0];
    }
  } else if(type == INST_PIN) {
    if(n >= 0 && n < xctx->instances && xctx->inst[n].node) return xctx->inst[n].node[col];
  }
  return NULL;
}

/* Hub point: the point on the hovered object CLOSEST to the pointer (mx,my), used as the star's
 * segment ORIGIN in the at/hover form (doc/claude/suggestions/flyline_hub_at_cursor_plan.md). So
 * fly-lines emanate from exactly where the cursor is rather than from the cluster's canonical
 * anchor (which for a wire is the midpoint). Pure read-only geometry over xctx->wire[] / pin
 * coords -- no state writes (invariant C1). Falls back to (mx,my) when the pick has no geometry.
 *  WIRE     : clamp-projection of (mx,my) onto segment wire[pick.n], t in [0,1]
 *  INST_PIN : the picked pin coord (a point)
 *  ELEMENT  : the label/pin symbol's pin 0 coord (a point) */
void flyline_hub_point(const Selected *pick, double mx, double my, double *hx, double *hy)
{
  *hx = mx; *hy = my;                          /* fallback: the raw pointer */
  if(!pick) return;
  if(pick->type == WIRE) {
    if(pick->n >= 0 && pick->n < xctx->wires) {
      xWire *w = &xctx->wire[pick->n];
      double dx = w->x2 - w->x1, dy = w->y2 - w->y1;
      double len2 = dx * dx + dy * dy, t;
      if(len2 <= 0.0) { *hx = w->x1; *hy = w->y1; return; }   /* zero-length wire guard */
      t = ((mx - w->x1) * dx + (my - w->y1) * dy) / len2;
      if(t < 0.0) t = 0.0; else if(t > 1.0) t = 1.0;          /* clamp to the segment */
      *hx = w->x1 + t * dx; *hy = w->y1 + t * dy;
    }
  } else if(pick->type == INST_PIN) {
    if(pick->n >= 0 && pick->n < xctx->instances &&
       (xctx->inst[pick->n].ptr + xctx->sym)->rects[PINLAYER] > (int)pick->col)
      get_inst_pin_coord(pick->n, (int)pick->col, hx, hy);
  } else if(pick->type == ELEMENT) {
    if(pick->n >= 0 && pick->n < xctx->instances &&
       (xctx->inst[pick->n].ptr + xctx->sym)->rects[PINLAYER] > 0)
      get_inst_pin_coord(pick->n, 0, hx, hy);
  }
}

/* union-find with path halving */
static int flyline_uf_find(int *parent, int a)
{
  while(parent[a] != a) { parent[a] = parent[parent[a]]; a = parent[a]; }
  return a;
}

/* Physical touch between two members of the SAME net -- the edge relation whose connected
 * components are the clusters fly-lines link. Mirrors check_connected_nets (select.c): wires
 * touch at a shared point / T-junction, a pin touches a wire when its point lies on the wire,
 * two bare pins touch when coincident. Read-only (invariant C1). */
static int flyline_members_touch(const FlyMember *a, const FlyMember *b)
{
  if(a->kind == 0 && b->kind == 0) {
    xWire *wa = &xctx->wire[a->idx], *wb = &xctx->wire[b->idx];
    return touch(wa->x1, wa->y1, wa->x2, wa->y2, wb->x1, wb->y1) ||
           touch(wa->x1, wa->y1, wa->x2, wa->y2, wb->x2, wb->y2) ||
           touch(wb->x1, wb->y1, wb->x2, wb->y2, wa->x1, wa->y1) ||
           touch(wb->x1, wb->y1, wb->x2, wb->y2, wa->x2, wa->y2);
  } else if(a->kind == 0) {                 /* a wire, b pin */
    xWire *wa = &xctx->wire[a->idx];
    return touch(wa->x1, wa->y1, wa->x2, wa->y2, b->x, b->y);
  } else if(b->kind == 0) {                 /* a pin, b wire */
    xWire *wb = &xctx->wire[b->idx];
    return touch(wb->x1, wb->y1, wb->x2, wb->y2, a->x, a->y);
  } else {                                  /* both pins */
    return a->x == b->x && a->y == b->y;
  }
}

/* Is the single bit `needle` one of the comma-separated bits in `hay`? Exact, length-checked. */
static int flyline_bit_in_list(const char *needle, const char *hay)
{
  size_t nl = strlen(needle);
  const char *p = hay;
  while(p && *p) {
    const char *comma = strchr(p, ',');
    size_t len = comma ? (size_t)(comma - p) : strlen(p);
    if(len == nl && !strncmp(p, needle, nl)) return 1;
    if(!comma) break;
    p = comma + 1;
  }
  return 0;
}

/* Do two net-name tokens denote the same net on at least one bit? Fast path for identical
 * scalars/buses; otherwise expandlabel() both into comma-separated bit lists and test overlap.
 * This is the bus aggregate-per-label rule: a bus label matches every object sharing any of its
 * bits (e.g. A[1:0] links A[0]), yet stays bit-precise (A[1] does not match A[0]). Read-only. */
/* Not static: the pin-rename propagation needs the same bit-precise comparator to
 * detect a bus label that overlaps a renamed pin without matching it exactly
 * (doc/claude/specs/pin_rename_propagation.md). Behaviour unchanged. */
int flyline_same_net(const char *a, const char *b)
{
  int ma, mb, match = 0;
  char *ea = NULL, *eb = NULL;
  const char *p;
  if(!a || !b) return 0;
  if(!strcmp(a, b)) return 1;
  /* expandlabel returns a shared buffer -- strdup each result before the next call clobbers it */
  my_strdup(_ALLOC_ID_, &ea, expandlabel(a, &ma));
  my_strdup(_ALLOC_ID_, &eb, expandlabel(b, &mb));
  if(ea && eb) {
    for(p = ea; p && *p && !match; ) {
      const char *comma = strchr(p, ',');
      size_t len = comma ? (size_t)(comma - p) : strlen(p);
      char bit[256];
      if(len < sizeof(bit)) {
        memcpy(bit, p, len); bit[len] = '\0';
        if(flyline_bit_in_list(bit, eb)) match = 1;
      }
      if(!comma) break;
      p = comma + 1;
    }
  }
  my_free(_ALLOC_ID_, &eb);
  my_free(_ALLOC_ID_, &ea);
  return match;
}

/* Compute the fly-line set for a net (doc/claude/specs/hover_flylines.md §5). `netname` is the
 * already-resolved target net (net-form: user name; at-form: flyline_net_of() of the picked
 * object). When `have_pick`, `pick` is the hovered object and its cluster becomes the hub, and
 * (mx,my) is the pointer -- the star's segment ORIGIN is then the point on the hovered object
 * closest to (mx,my) (flyline_hub_point), so lines emanate from the cursor rather than the
 * cluster's canonical anchor (see suggestions/flyline_hub_at_cursor_plan.md). Otherwise the hub
 * is cluster 0 and its anchor is the origin (mx,my ignored). Destinations, clustering, and the
 * clusters{} anchors are unchanged either way. Fills *res (free with flyline_result_free()).
 * PRECONDITION: prepare_netlist_structs(0) has run so wire[].node / inst[].node are current.
 * Pure read-only (invariant C1). */
void flyline_compute(const char *netname, int have_pick, const Selected *pick,
                     double mx, double my, FlyResult *res)
{
  FlyMember *mem = NULL;
  int nmem = 0, mem_alloc = 0, a, b;
  int hub_member = -1;              /* member index of the hovered object (at-form), else -1 */
  int is_global = 0;
  int show_globals = tclgetboolvar("flylines_show_globals");
  int cap = tclgetintvar("flylines_cap");

  memset(res, 0, sizeof(*res));
  if(cap <= 0) cap = 32;            /* C fallback if the tcl default is unset */

  /* A6: auto-named nets (get_unnamed_node -> "#netN", the node[0]=='#' marker) are unique per
   * physical cluster and can never connect implicitly -- exclude them (empty result).
   * Deliberately LOOSE, not is_auto_net_name() (issue 0156): '#' is reserved for the engine, so a
   * user-authored '#foo' is a namespace violation ERC warns about -- excluding it here too is the
   * conservative reading, and a star on it would be meaningless either way. */
  if(netname && netname[0] == '#') netname = NULL;
  if(!(netname && netname[0])) return;   /* no net -> empty result */

  my_strdup(_ALLOC_ID_, &res->net, netname);
  /* A8: global/bang-net policy. record_global_node(3,..) is a read-only lookup. A global
   * (vdd!/gnd!/0) touches the whole schematic, so it is suppressed unless flylines_show_globals;
   * when shown, the star is capped at flylines_cap nearest clusters. */
  is_global = (record_global_node(3, NULL, netname) != 0);
  res->is_global = is_global;
  if(is_global && !show_globals) return; /* suppressed: net+global reported, geometry empty */

  /* A2 members: every wire whose .node matches and every instance pin whose .node[p] matches
   * (bounded by rects[PINLAYER], as propagate_hilights does). flyline_same_net is bus-bit aware
   * (A7). Member record = {kind index pin x y}; the list index is the handle clusters use. */
  {
    int i, p, rects;
    double x, y;
    for(i = 0; i < xctx->wires; ++i) {
      if(flyline_same_net(xctx->wire[i].node, netname)) {
        if(nmem >= mem_alloc) { mem_alloc = mem_alloc ? mem_alloc * 2 : 16;
          my_realloc(_ALLOC_ID_, &mem, mem_alloc * sizeof(FlyMember)); }
        mem[nmem].kind = 0; mem[nmem].idx = i; mem[nmem].pin = -1;
        mem[nmem].x = (xctx->wire[i].x1 + xctx->wire[i].x2) / 2.0;
        mem[nmem].y = (xctx->wire[i].y1 + xctx->wire[i].y2) / 2.0;
        if(have_pick && pick->type == WIRE && pick->n == i) hub_member = nmem;
        ++nmem;
      }
    }
    for(i = 0; i < xctx->instances; ++i) {
      if(!xctx->inst[i].node) continue;
      rects = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
      for(p = 0; p < rects; ++p) {
        if(flyline_same_net(xctx->inst[i].node[p], netname)) {
          if(nmem >= mem_alloc) { mem_alloc = mem_alloc ? mem_alloc * 2 : 16;
            my_realloc(_ALLOC_ID_, &mem, mem_alloc * sizeof(FlyMember)); }
          get_inst_pin_coord(i, p, &x, &y);
          mem[nmem].kind = 1; mem[nmem].idx = i; mem[nmem].pin = p;
          mem[nmem].x = x; mem[nmem].y = y;
          if(have_pick && pick->n == i &&
             ((pick->type == ELEMENT && p == 0) || (pick->type == INST_PIN && (int)pick->col == p)))
            hub_member = nmem;
          ++nmem;
        }
      }
    }
  }
  res->mem = mem;
  res->nmem = nmem;
  if(nmem == 0) return;

  /* A3: union-find physical clustering. A4: per-cluster anchor. A5: star segments from the hub
   * (hovered cluster for the at-form, cluster 0 otherwise) to every other cluster -- so N
   * clusters yield N-1 segments and a single-cluster net (incl. an already-wired pair) yields
   * none (the implicit-only rule). */
  {
    int *parent = my_malloc(_ALLOC_ID_, nmem * sizeof(int));
    int *root2clu = my_malloc(_ALLOC_ID_, nmem * sizeof(int));
    int *clu = my_malloc(_ALLOC_ID_, nmem * sizeof(int));
    int nclu = 0, c, hub;
    double *cx, *cy; int *cpin, *cany;
    for(a = 0; a < nmem; ++a) { parent[a] = a; root2clu[a] = -1; }
    for(a = 0; a < nmem; ++a) for(b = a + 1; b < nmem; ++b) {
      if(flyline_members_touch(&mem[a], &mem[b])) {
        int ra = flyline_uf_find(parent, a), rb = flyline_uf_find(parent, b);
        if(ra != rb) parent[ra] = rb;
      }
    }
    /* assign cluster ordinals in first-appearance order */
    for(a = 0; a < nmem; ++a) {
      int r = flyline_uf_find(parent, a);
      if(root2clu[r] == -1) root2clu[r] = nclu++;
      clu[a] = root2clu[r];
    }
    hub = (hub_member >= 0) ? clu[hub_member] : 0;
    /* per-cluster anchor: prefer a pin member's coord, else the first member's point */
    cx = my_malloc(_ALLOC_ID_, nclu * sizeof(double));
    cy = my_malloc(_ALLOC_ID_, nclu * sizeof(double));
    cpin = my_malloc(_ALLOC_ID_, nclu * sizeof(int));
    cany = my_malloc(_ALLOC_ID_, nclu * sizeof(int));
    for(c = 0; c < nclu; ++c) { cpin[c] = 0; cany[c] = 0; cx[c] = 0.0; cy[c] = 0.0; }
    for(a = 0; a < nmem; ++a) {
      c = clu[a];
      if(!cany[c]) { cx[c] = mem[a].x; cy[c] = mem[a].y; cany[c] = 1; }
      if(!cpin[c] && mem[a].kind == 1) { cx[c] = mem[a].x; cy[c] = mem[a].y; cpin[c] = 1; }
    }
    res->clu = clu;
    res->nclu = nclu;
    res->cx = cx;
    res->cy = cy;
    res->hub = hub;
    /* emit star segments hub -> the `cap` nearest other clusters (A8). If there are more other
     * clusters than the cap, keep the nearest ones and flag capped. */
    {
      int others = nclu - 1, emit = others, e;
      /* Segment ORIGIN: the cursor hub point when hovering (at-form), else the hub cluster's
       * canonical anchor (net-form). Nearest-cluster selection below still measures from the
       * anchor cx[hub]/cy[hub] so the cap picks the SAME destinations as before -- only the
       * emitted origin coordinate moves (plan H0). */
      double ox = cx[hub], oy = cy[hub];
      char *used = my_malloc(_ALLOC_ID_, nclu * sizeof(char));
      if(have_pick) flyline_hub_point(pick, mx, my, &ox, &oy);
      if(others > cap) { emit = cap; res->capped = 1; }
      if(emit > 0) {
        res->sx1 = my_malloc(_ALLOC_ID_, emit * sizeof(double));
        res->sy1 = my_malloc(_ALLOC_ID_, emit * sizeof(double));
        res->sx2 = my_malloc(_ALLOC_ID_, emit * sizeof(double));
        res->sy2 = my_malloc(_ALLOC_ID_, emit * sizeof(double));
      }
      for(c = 0; c < nclu; ++c) used[c] = 0;
      used[hub] = 1;
      for(e = 0; e < emit; ++e) {
        int bestc = -1; double bestd = 0.0;
        for(c = 0; c < nclu; ++c) {
          double dx, dy, d2;
          if(used[c]) continue;
          dx = cx[c] - cx[hub]; dy = cy[c] - cy[hub]; d2 = dx * dx + dy * dy;
          if(bestc < 0 || d2 < bestd) { bestc = c; bestd = d2; }
        }
        if(bestc < 0) break;
        used[bestc] = 1;
        res->sx1[res->nseg] = ox; res->sy1[res->nseg] = oy;
        res->sx2[res->nseg] = cx[bestc]; res->sy2[res->nseg] = cy[bestc];
        ++res->nseg;
      }
      my_free(_ALLOC_ID_, &used);
    }
    my_free(_ALLOC_ID_, &cany); my_free(_ALLOC_ID_, &cpin);
    my_free(_ALLOC_ID_, &root2clu);
    my_free(_ALLOC_ID_, &parent);
  }
}

/* Release everything flyline_compute() allocated into *res and re-zero it. Read-only w.r.t. the
 * schematic (frees only the query's own scratch). */
void flyline_result_free(FlyResult *res)
{
  if(!res) return;
  if(res->net) my_free(_ALLOC_ID_, &res->net);
  if(res->mem) my_free(_ALLOC_ID_, &res->mem);
  if(res->clu) my_free(_ALLOC_ID_, &res->clu);
  if(res->cx) my_free(_ALLOC_ID_, &res->cx);
  if(res->cy) my_free(_ALLOC_ID_, &res->cy);
  if(res->sx1) my_free(_ALLOC_ID_, &res->sx1);
  if(res->sy1) my_free(_ALLOC_ID_, &res->sy1);
  if(res->sx2) my_free(_ALLOC_ID_, &res->sx2);
  if(res->sy2) my_free(_ALLOC_ID_, &res->sy2);
  memset(res, 0, sizeof(*res));
}
