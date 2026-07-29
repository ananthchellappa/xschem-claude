/* File: move.c
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
#include <stdarg.h>   /* fluid-reroute FLUID_TRACE diagnostic (issue 0083) */


void flip_rotate_ellipse(xRect *r, int rot, int flip)
{
  if(r->ellipse_a == -1) return;
  else if(r->ellipse_b == 360) return;
  else {
    char str[100];
    if(flip) {
      r->ellipse_a = 180 - r->ellipse_a - r->ellipse_b;
      my_snprintf(str, S(str), "%d,%d", r->ellipse_a, r->ellipse_b);
      my_strdup2(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ellipse", str));
    }
    if(rot) {
      if(rot == 3) {
        r->ellipse_a += 90;
      } else if(rot == 2) {
        r->ellipse_a += 180;
      } else if(rot == 1) {
        r->ellipse_a += 270;
      }
      r->ellipse_a %= 360;
      my_snprintf(str, S(str), "%d,%d", r->ellipse_a, r->ellipse_b);
      my_strdup2(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ellipse", str));
    }
  }
}

void rebuild_selected_array() /* can be used only if new selected set is lower */
                              /* that is, xctx->sel_array[] size can not increase */
{
 int i,c;

 dbg(2, "rebuild selected array\n");
 if(!xctx->need_reb_sel_arr) return;
 xctx->lastsel=0;
 for(i=0;i<xctx->texts; ++i)
  if(xctx->text[i].sel)
  {
   check_selected_storage();
   xctx->sel_array[xctx->lastsel].type = xTEXT;
   xctx->sel_array[xctx->lastsel].n = i;
   xctx->sel_array[xctx->lastsel++].col = TEXTLAYER;
  }
 for(i=0;i<xctx->instances; ++i)
  if(xctx->inst[i].sel)
  {
   check_selected_storage();
   xctx->sel_array[xctx->lastsel].type = ELEMENT;
   xctx->sel_array[xctx->lastsel].n = i;
   xctx->sel_array[xctx->lastsel++].col = WIRELAYER;
  }
 /* emit one INST_PIN entry per selected pin (pin_selection.md). This is independent
  * of inst.sel, so a pins-only instance contributes pin entries but no ELEMENT entry.
  * Scan is bounded by min(pin count, pin_sel_size) so a symbol pin-count change can
  * never read past the allocation. */
 for(i=0;i<xctx->instances; ++i)
  if(xctx->inst[i].pin_sel && xctx->inst[i].ptr >= 0)
  {
   int p, rects = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
   int lim = rects < xctx->inst[i].pin_sel_size ? rects : xctx->inst[i].pin_sel_size;
   for(p = 0; p < lim; ++p) if(xctx->inst[i].pin_sel[p])
   {
    check_selected_storage();
    xctx->sel_array[xctx->lastsel].type = INST_PIN;
    xctx->sel_array[xctx->lastsel].n = i;
    xctx->sel_array[xctx->lastsel++].col = (unsigned int)p;
   }
  }
 for(i=0;i<xctx->wires; ++i)
  if(xctx->wire[i].sel)
  {
   check_selected_storage();
   xctx->sel_array[xctx->lastsel].type = WIRE;
   xctx->sel_array[xctx->lastsel].n = i;
   xctx->sel_array[xctx->lastsel++].col = WIRELAYER;
  }
 for(c=0;c<cadlayers; ++c)
 {
  for(i=0;i<xctx->arcs[c]; ++i)
   if(xctx->arc[c][i].sel)
   {
    check_selected_storage();
    xctx->sel_array[xctx->lastsel].type = ARC;
    xctx->sel_array[xctx->lastsel].n = i;
    xctx->sel_array[xctx->lastsel++].col = c;
   }
  for(i=0;i<xctx->rects[c]; ++i)
   if(xctx->rect[c][i].sel)
   {
    check_selected_storage();
    xctx->sel_array[xctx->lastsel].type = xRECT;
    xctx->sel_array[xctx->lastsel].n = i;
    xctx->sel_array[xctx->lastsel++].col = c;
   }
  for(i=0;i<xctx->lines[c]; ++i)
   if(xctx->line[c][i].sel)
   {
    check_selected_storage();
    xctx->sel_array[xctx->lastsel].type = LINE;
    xctx->sel_array[xctx->lastsel].n = i;
    xctx->sel_array[xctx->lastsel++].col = c;
   }
  for(i=0;i<xctx->polygons[c]; ++i)
   if(xctx->poly[c][i].sel)
   {
    check_selected_storage();
    xctx->sel_array[xctx->lastsel].type = POLYGON;
    xctx->sel_array[xctx->lastsel].n = i;
    xctx->sel_array[xctx->lastsel++].col = c;
   }
 }
 if(xctx->lastsel==0) {
   xctx->ui_state &= ~SELECTION;
   set_first_sel(0, -1, 0);
 } else xctx->ui_state |= SELECTION;
 xctx->need_reb_sel_arr=0;
}

/* predicate for wire_delete_compact() — see wire lifecycle census */
static int wire_doomed_degenerate(int n, void *arg)
{
  (void)arg;
  return xctx->wire[n].x1==xctx->wire[n].x2 && xctx->wire[n].y1 == xctx->wire[n].y2;
}

void check_collapsing_objects()
{
  int  j,i, c;
  int found=0;

  j = wire_delete_compact(wire_doomed_degenerate, NULL);
  if(j) found=1;

 /* option: remove degenerated lines  */
   for(c=0;c<cadlayers; ++c)
   {
    j = 0;
    for(i=0;i<xctx->lines[c]; ++i)
    {
     if(xctx->line[c][i].x1==xctx->line[c][i].x2 && xctx->line[c][i].y1 == xctx->line[c][i].y2)
     {
      my_free(_ALLOC_ID_, &xctx->line[c][i].prop_ptr);
      found=1;
      ++j;
      continue;
     }
     if(j)
     {
      xctx->line[c][i-j] = xctx->line[c][i];
     }
    }
    xctx->lines[c] -= j;
   }
   for(c=0;c<cadlayers; ++c)
   {
    j = 0;
    for(i=0;i<xctx->rects[c]; ++i)
    {
     if(xctx->rect[c][i].x1==xctx->rect[c][i].x2 || xctx->rect[c][i].y1 == xctx->rect[c][i].y2)
     {
      my_free(_ALLOC_ID_, &xctx->rect[c][i].prop_ptr);
      set_rect_extraptr(0, &xctx->rect[c][i]);
      found=1;
      ++j;
      continue;
     }
     if(j)
     {
      xctx->rect[c][i-j] = xctx->rect[c][i];
     }
    }
    xctx->rects[c] -= j;
   }

  if(found) {
    xctx->need_reb_sel_arr=1;
    rebuild_selected_array();
  }
}

static void update_symbol_bboxes(short rot, short flip)
{
  int i, n;
  short save_flip, save_rot;

  for(i=0;i<xctx->movelastsel; ++i)
  {
    n = xctx->sel_array[i].n;
    dbg(1, "update_symbol_bboxes(): i=%d, movelastsel=%d, n=%d\n", i, xctx->movelastsel, n);
    if(xctx->sel_array[i].type == ELEMENT) {
      if(n < 0 || n >= xctx->instances || xctx->inst[n].ptr < 0) continue; /* stale/unlinked: symbol_bbox would read sym[ptr<0] */
      dbg(1, "update_symbol_bboxes(): symbol flip=%d, rot=%d\n",  xctx->inst[n].flip, xctx->inst[n].rot);
      save_flip = xctx->inst[n].flip;
      save_rot = xctx->inst[n].rot;
      xctx->inst[n].flip = flip ^ xctx->inst[n].flip;
      xctx->inst[n].rot = (xctx->inst[n].rot + rot) & 0x3;
      symbol_bbox(n, &xctx->inst[n].x1, &xctx->inst[n].y1, &xctx->inst[n].x2, &xctx->inst[n].y2 );
      xctx->inst[n].rot = save_rot;
      xctx->inst[n].flip = save_flip;
    }
  }
}

static void draw_selection_impl(GC g, int interruptable);

/* incremental_wire_reroute.md Phase II: while a fluid stretch RUBBER step has LIVE-COMMITTED the
 * moved geometry (xctx->fluid_reroute_dirty), the inst/wire/text coords ALREADY include the FULL
 * move transform -- the translation delta AND (Case 4b: a rotated/flipped stretch reroutes live)
 * the ROTATION(move_rot,move_flip) baked in by the shared commit block. xctx->deltax/deltay are
 * deliberately kept equal to the accumulated total (and move_rot/move_flip kept set) so the eventual
 * interactive END (move_objects(END,0,0,0)) can consume them (move.c live-commit tail), but the
 * selection OVERLAY must NOT re-apply either: draw_selection_impl draws each object at
 * ROTATION(move_rot,move_flip,pivot,coord)+delta, so on already-committed coords that re-adds the
 * transform. An external full redraw (window Expose, hover, `xschem redraw`, crosshair) firing
 * BETWEEN RUBBER frames -- or the live step's own repaint tail -- would otherwise paint a ghost one
 * displacement beyond the real instance (translation: origin+2*delta, issue 0080) and, once a
 * mid-drag ALT-R/F rotated the committed geometry, a SECOND rotation about the pivot lands the
 * selection-highlight ghost in a wholly wrong place (issue 0115). Neutralize the WHOLE move
 * transform (delta + rot + flip + rotatelocal) for the duration of the overlay draw so it paints the
 * committed objects as-is, and restore after so END still sees the accumulated total. The wrapper
 * (vs an inline zero) guarantees the restore on every early-return path inside the body
 * (interruptable resume, tiled-fill fast path). Gated on fluid_reroute_dirty, which is only ever set
 * when fluid_editing was on at START => default-off is byte-identical (and the translation-only
 * fluid path already has move_rot==move_flip==0, so it stays byte-identical to the 0080 fix). */
void draw_selection(GC g, int interruptable)
{
  if(xctx->fluid_reroute_dirty) {
    double sv_dx = xctx->deltax, sv_dy = xctx->deltay;
    short sv_rot = xctx->move_rot, sv_flip = xctx->move_flip, sv_rotlocal = xctx->rotatelocal;
    xctx->deltax = 0.0; xctx->deltay = 0.0;
    xctx->move_rot = 0; xctx->move_flip = 0; xctx->rotatelocal = 0;
    draw_selection_impl(g, interruptable);
    xctx->deltax = sv_dx; xctx->deltay = sv_dy;
    xctx->move_rot = sv_rot; xctx->move_flip = sv_flip; xctx->rotatelocal = sv_rotlocal;
  } else {
    draw_selection_impl(g, interruptable);
  }
}

static void draw_selection_impl(GC g, int interruptable)
{
  int i, c, k, n;
  double  angle; /* arc */
  #if HAS_CAIRO==1
  int customfont;
  #endif
  dbg(1,"draw_selection, %s, lastsel=%d\n", g == xctx->gctiled ? "gctiled" : "gcselect", xctx->lastsel);
  if(g != xctx->gctiled) xctx->movelastsel = xctx->lastsel;

  if((fix_broken_tiled_fill || !_unix) && g == xctx->gctiled && xctx->movelastsel > 800) {
    MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0], xctx->xrect[0].x, xctx->xrect[0].y,
          xctx->xrect[0].width, xctx->xrect[0].height, xctx->xrect[0].x, xctx->xrect[0].y);
    return;
  }
  for(i=0;i<xctx->movelastsel; ++i)
  {
   short int tmp_rot;
   c = xctx->sel_array[i].col;n = xctx->sel_array[i].n;
   switch(xctx->sel_array[i].type)
   {
    case xTEXT:
     if(xctx->rotatelocal) {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->text[n].x0, xctx->text[n].y0,
         xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
     }
     #if HAS_CAIRO==1
     customfont =  set_text_custom_font(&xctx->text[n]);
     #endif
     draw_temp_string(g,ADD, get_text_floater(n),
      (xctx->text[n].rot +
      ( (xctx->move_flip && (xctx->text[n].rot & 1) ) ? xctx->move_rot+2 : xctx->move_rot) ) & 0x3,
       xctx->text[n].flip^xctx->move_flip, xctx->text[n].hcenter, xctx->text[n].vcenter,
       xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
       xctx->text[n].xscale, xctx->text[n].yscale);
     #if HAS_CAIRO==1
     if(customfont) {
       cairo_restore(xctx->cairo_ctx);
     }
     #endif

     break;
    case xRECT:
     if(xctx->rotatelocal) {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
         xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
         xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
     }
     if(xctx->rect[c][n].sel==SELECTED)
     {
       RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
       drawtemprect(g, ADD, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay);
     }
     else if(xctx->rect[c][n].sel==SELECTED1)
     {
      xctx->rx1+=xctx->deltax;
      xctx->ry1+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==SELECTED2)
     {
      xctx->rx2+=xctx->deltax;
      xctx->ry1+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==SELECTED3)
     {
      xctx->rx1+=xctx->deltax;
      xctx->ry2+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==SELECTED4)
     {
      xctx->rx2+=xctx->deltax;
      xctx->ry2+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==(SELECTED1|SELECTED2))
     {
      xctx->ry1+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==(SELECTED3|SELECTED4))
     {
      xctx->ry2+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==(SELECTED1|SELECTED3))
     {
      xctx->rx1+=xctx->deltax;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==(SELECTED2|SELECTED4))
     {
      xctx->rx2+=xctx->deltax;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     break;
    case POLYGON:
     {
      int bezier;
      double *x = my_malloc(_ALLOC_ID_, sizeof(double) *xctx->poly[c][n].points);
      double *y = my_malloc(_ALLOC_ID_, sizeof(double) *xctx->poly[c][n].points);
      bezier = 2 + !strboolcmp(get_tok_value(xctx->poly[c][n].prop_ptr, "bezier", 0), "true");
      if(xctx->poly[c][n].sel==SELECTED || xctx->poly[c][n].sel==SELECTED1) {
        for(k=0;k<xctx->poly[c][n].points; ++k) {
          if( xctx->poly[c][n].sel==SELECTED || xctx->poly[c][n].selected_point[k]) {
            if(xctx->rotatelocal) {
              ROTATION(xctx->move_rot, xctx->move_flip, xctx->poly[c][n].x[0], xctx->poly[c][n].y[0],
                       xctx->poly[c][n].x[k], xctx->poly[c][n].y[k], xctx->rx1,xctx->ry1);
            } else {
              ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->poly[c][n].x[k], xctx->poly[c][n].y[k], xctx->rx1,xctx->ry1);
            }
            x[k] = xctx->rx1 + xctx->deltax;
            y[k] = xctx->ry1 + xctx->deltay;
          } else {
            x[k] = xctx->poly[c][n].x[k];
            y[k] = xctx->poly[c][n].y[k];
          }
        }
        drawtemppolygon(g, NOW, x, y, xctx->poly[c][n].points, bezier);
      }
      my_free(_ALLOC_ID_, &x);
      my_free(_ALLOC_ID_, &y);
     }
     break;

    case WIRE:
     if(xctx->rotatelocal) {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->wire[n].x1, xctx->wire[n].y1,
         xctx->wire[n].x1, xctx->wire[n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->wire[n].x1, xctx->wire[n].y1,
         xctx->wire[n].x2, xctx->wire[n].y2, xctx->rx2,xctx->ry2);
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->wire[n].x1, xctx->wire[n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->wire[n].x2, xctx->wire[n].y2, xctx->rx2,xctx->ry2);
     }

     ORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
     if(xctx->wire[n].sel==SELECTED)
     {
      double x1 = xctx->rx1 + xctx->deltax;
      double y1 = xctx->ry1 + xctx->deltay;
      double x2 = xctx->rx2 + xctx->deltax;
      double y2 = xctx->ry2 + xctx->deltay;
      dbg(1, "draw_selection() wire: %g %g - %g %g  manhattan=%d\n", x1, y1, x2, y2, xctx->manhattan_lines);
      if(xctx->wire[n].bus == -1.0) {
        drawtemp_manhattanline(g, THICK, x1, y1, x2, y2, 1);
      } else {
        drawtemp_manhattanline(g, ADD, x1, y1, x2, y2, 1);
      }
     }
     else if(xctx->wire[n].sel==SELECTED1)
     {
      double x1 = xctx->rx1 + xctx->deltax;
      double y1 = xctx->ry1 + xctx->deltay;
      double x2 = xctx->rx2;
      double y2 = xctx->ry2;
      dbg(1, "draw_selection() wire: %g %g - %g %g  manhattan=%d\n", x1, y1, x2, y2, xctx->manhattan_lines);
      if(xctx->wire[n].bus == -1.0) {
        drawtemp_manhattanline(g, THICK, x2, y2, x1, y1, 1);
      } else {
        drawtemp_manhattanline(g, ADD, x2, y2, x1, y1, 1);
      }
     }
     else if(xctx->wire[n].sel==SELECTED2)
     {
      double x1 = xctx->rx1;
      double y1 = xctx->ry1;
      double x2 = xctx->rx2 + xctx->deltax;
      double y2 = xctx->ry2 + xctx->deltay;
      dbg(1, "draw_selection() wire: %g %g - %g %g  manhattan=%d\n", x1, y1, x2, y2, xctx->manhattan_lines);
      if(xctx->wire[n].bus == -1.0) {
        drawtemp_manhattanline(g, THICK, x1, y1, x2, y2, 1);
      } else {
        drawtemp_manhattanline(g, ADD, x1, y1, x2, y2, 1);
      }
     }
     break;
    case LINE:
     if(xctx->rotatelocal) {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->line[c][n].x1, xctx->line[c][n].y1,
         xctx->line[c][n].x1, xctx->line[c][n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->line[c][n].x1, xctx->line[c][n].y1,
         xctx->line[c][n].x2, xctx->line[c][n].y2, xctx->rx2,xctx->ry2);
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->line[c][n].x1, xctx->line[c][n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->line[c][n].x2, xctx->line[c][n].y2, xctx->rx2,xctx->ry2);
     }
     ORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
     if(xctx->line[c][n].sel==SELECTED)
     {
       if(xctx->line[c][n].bus == -1.0)
         drawtempline(g, THICK, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay);
       else
         drawtempline(g, ADD, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay);
     }
     else if(xctx->line[c][n].sel==SELECTED1)
     {
       if(xctx->line[c][n].bus == -1.0)
         drawtempline(g, THICK, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay, xctx->rx2, xctx->ry2);
       else
         drawtempline(g, ADD, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay, xctx->rx2, xctx->ry2);
     }
     else if(xctx->line[c][n].sel==SELECTED2)
     {
       if(xctx->line[c][n].bus == -1.0)
         drawtempline(g, THICK, xctx->rx1, xctx->ry1, xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay);
       else
         drawtempline(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay);
     }
     break;
    case ARC:
     if(xctx->rotatelocal) {
       /* rotate center wrt itself: do nothing */
       xctx->rx1 = xctx->arc[c][n].x;
       xctx->ry1 = xctx->arc[c][n].y;
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->arc[c][n].x, xctx->arc[c][n].y, xctx->rx1,xctx->ry1);
     }
     angle = xctx->arc[c][n].a;
     if(xctx->move_flip) {
       angle = 270.*xctx->move_rot+180.-xctx->arc[c][n].b-xctx->arc[c][n].a;
     } else {
       angle = xctx->arc[c][n].a+xctx->move_rot*270.;
     }
     angle = fmod(angle, 360.);
     if(angle<0.) angle+=360.;
     if(xctx->arc[c][n].sel==SELECTED) {
       drawtemparc(g, ADD, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                xctx->arc[c][n].r, angle, xctx->arc[c][n].b);
     } else if(xctx->arc[c][n].sel==SELECTED1) {
       drawtemparc(g, ADD, xctx->rx1, xctx->ry1,
                fabs(xctx->arc[c][n].r+xctx->deltax), angle, xctx->arc[c][n].b);
     } else if(xctx->arc[c][n].sel==SELECTED3) {
       angle = my_round(fmod(atan2(-xctx->deltay, xctx->deltax)*180./XSCH_PI+xctx->arc[c][n].b, 360.));
       if(angle<0.) angle +=360.;
       if(angle==0) angle=360.;
       drawtemparc(g, ADD, xctx->rx1, xctx->ry1, xctx->arc[c][n].r, xctx->arc[c][n].a, angle);
     } else if(xctx->arc[c][n].sel==SELECTED2) {
       angle = my_round(fmod(atan2(-xctx->deltay, xctx->deltax)*180./XSCH_PI+angle, 360.));
       if(angle<0.) angle +=360.;
       drawtemparc(g, ADD, xctx->rx1, xctx->ry1, xctx->arc[c][n].r, angle, xctx->arc[c][n].b);
     }
     break;
    case ELEMENT:
     if(xctx->rotatelocal) {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->inst[n].x0, xctx->inst[n].y0,
         xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
     }
     tmp_rot = (xctx->move_flip & xctx->inst[n].rot & 1) ?
                0x3 & (xctx->move_rot + 2) : xctx->move_rot;
     for(k=0;k<cadlayers; ++k) {
       draw_temp_symbol(ADD, g, n, k, xctx->move_flip,
         tmp_rot,
         xctx->rx1-xctx->inst[n].x0+xctx->deltax,xctx->ry1-xctx->inst[n].y0+xctx->deltay);
     }
     break;
    case INST_PIN: {
      /* selected instance pin (pin_selection.md D4): a box + diagonal cross centered on
       * the pin point, stroked in the SELECTION colour (SELLAYER). MUST NOT use the
       * pin's own layer colour -- pins are usually drawn in PINLAYER (often red), so a
       * PINLAYER marker is invisible on the pin. The box+X *shape* is what distinguishes
       * it from the whole-instance outline. Pins are inert, so it ignores any
       * in-progress move offset and sits on the true pin. NOW mode -> uses its own GC,
       * independent of the ADD/END batch flushed with g. Erase pass (g==gctiled)
       * restores the box region, which also covers the cross. */
      double px, py, h = PIN_SEL_HANDLE_H;
      GC mg = (g == xctx->gctiled) ? xctx->gctiled : xctx->gc[SELLAYER];
      get_inst_pin_coord(n, (int)c, &px, &py);
      drawtemprect(mg, NOW, px - h, py - h, px + h, py + h);
      if(g != xctx->gctiled) {
        drawtempline(mg, NOW, px - h, py - h, px + h, py + h);
        drawtempline(mg, NOW, px - h, py + h, px + h, py - h);
      }
      break;
    }
   }
#ifdef __unix__
   if(interruptable && pending_events())
   {
    drawtemparc(g, END, 0.0, 0.0, 0.0, 0.0, 0.0);
    drawtemprect(g, END, 0.0, 0.0, 0.0, 0.0);
    drawtempline(g, END, 0.0, 0.0, 0.0, 0.0);
    xctx->movelastsel = i+1;
    return;
   }
#else
   if (interruptable)
   {
     drawtemparc(g, END, 0.0, 0.0, 0.0, 0.0, 0.0);
     drawtemprect(g, END, 0.0, 0.0, 0.0, 0.0);
     drawtempline(g, END, 0.0, 0.0, 0.0, 0.0);
     xctx->movelastsel = i + 1;
     return;
   }
#endif
  } /* for(i=0;i<xctx->movelastsel; ++i) */
  drawtemparc(g, END, 0.0, 0.0, 0.0, 0.0, 0.0);
  drawtemprect(g, END, 0.0, 0.0, 0.0, 0.0);
  drawtempline(g, END, 0.0, 0.0, 0.0, 0.0);
  xctx->movelastsel = i;
}

/* sel: if set to 1 change references only on selected items, like in a copy operation.
 * If set to 0 operate on all objects with matching name=... attribute */
void update_attached_floaters(const char *from_name, int inst, int sel)
{
  int i, c;
  char *to_name = xctx->inst[inst].instname;
  const char *attach = get_tok_value(xctx->inst[inst].prop_ptr, "attach", 0);
  char *new_attach;

  if(!from_name || !from_name[0]) return;
  if(!to_name || !to_name[0]) return;
  if(!attach[0]) return;

     new_attach = str_replace(attach, from_name, to_name, 1, 1);
     my_strdup(_ALLOC_ID_, &xctx->inst[inst].prop_ptr,
               subst_token(xctx->inst[inst].prop_ptr, "attach", new_attach) );

     for(c = 0; c < cadlayers; c++) {
      for(i = 0; i < xctx->rects[c]; i++) {
        if(!sel || xctx->rect[c][i].sel == SELECTED) {
          if( !strcmp(from_name, get_tok_value(xctx->rect[c][i].prop_ptr, "name", 0))) {
            my_strdup(_ALLOC_ID_, &xctx->rect[c][i].prop_ptr,
                      subst_token(xctx->rect[c][i].prop_ptr, "name", to_name) );
          }
          if(c == GRIDLAYER) {
            const char *node = get_tok_value(xctx->rect[c][i].prop_ptr, "node", 2);
            if(node && node[0]) {
              const char *new_node = str_replace(node, from_name, to_name, 1, -1);
              my_strdup(_ALLOC_ID_, &xctx->rect[c][i].prop_ptr,
                   subst_token(xctx->rect[c][i].prop_ptr, "node", new_node));
            }
          }
        }
      }
      for(i = 0; i < xctx->lines[c]; i++) {
        if((!sel || xctx->line[c][i].sel == SELECTED) &&
           !strcmp(from_name, get_tok_value(xctx->line[c][i].prop_ptr, "name", 0))) {
          my_strdup(_ALLOC_ID_, &xctx->line[c][i].prop_ptr,
                    subst_token(xctx->line[c][i].prop_ptr, "name", to_name) );
        }
      }

      for(i = 0; i < xctx->polygons[c]; i++) {
        if((!sel || xctx->poly[c][i].sel == SELECTED) &&
           !strcmp(from_name, get_tok_value(xctx->poly[c][i].prop_ptr, "name", 0))) {
          my_strdup(_ALLOC_ID_, &xctx->poly[c][i].prop_ptr,
                    subst_token(xctx->poly[c][i].prop_ptr, "name", to_name) );

        }
      }
      for(i = 0; i < xctx->arcs[c]; i++) {
        if((!sel || xctx->arc[c][i].sel == SELECTED) &&
           !strcmp(from_name, get_tok_value(xctx->arc[c][i].prop_ptr, "name", 0))) {
          my_strdup(_ALLOC_ID_, &xctx->arc[c][i].prop_ptr,
                    subst_token(xctx->arc[c][i].prop_ptr, "name", to_name) );
        }
      }
    }
    for(i = 0; i < xctx->wires; i++) {
      if((!sel || xctx->wire[i].sel == SELECTED) &&
           !strcmp(from_name, get_tok_value(xctx->wire[i].prop_ptr, "name", 0))) {
          my_strdup(_ALLOC_ID_, &xctx->wire[i].prop_ptr,
                    subst_token(xctx->wire[i].prop_ptr, "name", to_name) );
      }
    }
    for(i = 0; i < xctx->texts; i++) {
      if((!sel || xctx->text[i].sel == SELECTED) &&
           !strcmp(from_name, get_tok_value(xctx->text[i].prop_ptr, "name", 0))) {
          my_strdup(_ALLOC_ID_, &xctx->text[i].prop_ptr,
                    subst_token(xctx->text[i].prop_ptr, "name", to_name) );
        set_text_flags(&xctx->text[i]);
      }
    }
}


void copy_objects(int what)
{
  int tmpi, c, i, n, k /*, tmp */ ;
  double angle, dtmp;
  int newpropcnt;
  double tmpx, tmpy;
  char *estr = NULL;

  #if HAS_CAIRO==1
  int customfont;
  #endif

  if(what & START)
  {
   xctx->rotatelocal=0;
   dbg(1, "copy_objects(): START copy\n");
   rebuild_selected_array();
   /* read-only backstop (issue 0041): refuse to begin a copy-place below the entry
    * guards; placed with the lastsel==0 early return so a refused START leaves the same
    * clean state (see move_objects START). */
   if(begin_edit("copy")) return;
   if(xctx->lastsel==0) return;
   update_symbol_bboxes(0, 0);
   if(xctx->connect_by_kissing == 2) xctx->kissing = connect_by_kissing();
   else xctx->kissing = 0;

   save_selection(1);
   xctx->deltax = xctx->deltay = 0.0;
   xctx->movelastsel = xctx->lastsel;
   xctx->x1=xctx->mousex_snap;xctx->y1=xctx->mousey_snap;
   xctx->move_flip = 0;xctx->move_rot = 0;
   xctx->ui_state|=STARTCOPY;
  }
  if(what & ABORT)                               /* abort operation */
  {
   draw_selection(xctx->gctiled,0);

   if(xctx->kissing) {
     pop_undo(0, 0);
     check_collapsing_objects(); /* sweep degenerate kiss stubs (see move_objects ABORT) */
   }
   /* Always clear the kissing request on abort (see move_objects ABORT): a
    * stale connect_by_kissing == 2 would leak into the next gesture. */
   if(xctx->connect_by_kissing == 2) xctx->connect_by_kissing = 0;

   xctx->move_rot = xctx->move_flip = 0;
   xctx->deltax = xctx->deltay = 0.;
   xctx->ui_state&=~STARTCOPY;
   update_symbol_bboxes(0, 0);
  }
  if(what & RUBBER)                              /* draw objects while moving */
  {
   if(xctx->mousex_snap == xctx->x2 && xctx->mousey_snap == xctx->y2) return;
   xctx->x2=xctx->mousex_snap;xctx->y2=xctx->mousey_snap;
   draw_selection(xctx->gctiled,0);
   xctx->deltax = xctx->x2-xctx->x1; xctx->deltay = xctx->y2 - xctx->y1;
  }
  if(what & ROTATELOCAL ) {
   xctx->rotatelocal=1;
  }
  if(what & ROTATE) {
   draw_selection(xctx->gctiled,0);
   xctx->move_rot= (xctx->move_rot+1) & 0x3;
   update_symbol_bboxes(xctx->move_rot, xctx->move_flip);
  }
  if(what & FLIP)
  {
   draw_selection(xctx->gctiled,0);
   xctx->move_flip = !xctx->move_flip;
   update_symbol_bboxes(xctx->move_rot, xctx->move_flip);
  }
  if(what & END)                                 /* copy selected objects */
  {
    int l, firstw, firsti;

    dbg(1, "end copy: unlink sel_file\n");
    xunlink(sel_file);
    if(xctx->deltax != 0 || xctx->deltay != 0) set_first_sel(0, -1, 0); /* reset first selected object */
    if(xctx->connect_by_kissing == 2) xctx->connect_by_kissing = 0;

    newpropcnt=0;

    /* button released after clicking elements, without moving... do nothing */
    if(xctx->drag_elements && xctx->deltax==0 && xctx->deltay == 0) {
       xctx->ui_state &= ~STARTCOPY;
       return;
    }

    if( !xctx->kissing ) {
      dbg(1, "copy_objects(): push undo state\n");
      xctx->push_undo();
    }

    /* calculate moving symbols bboxes before actually doing the copy */
    firstw = firsti = 1;
    draw_selection(xctx->gctiled,0);
    update_symbol_bboxes(0, 0);

    /* P4 (cadence_pin_name_text.md): a pin's name view is a DERIVED object, never copied.
     * Drop any selected name views from the copy set; each copied pin regenerates its own
     * view below (synth_pin_views), bound to the copy's fresh id -- otherwise the view would
     * be duplicated as a stray real text still bound to the ORIGINAL pin. */
    {
      int t, dropped = 0;
      for(t = 0; t < xctx->texts; ++t)
        if(xctx->text[t].owner_pin_id && xctx->text[t].sel) { xctx->text[t].sel = 0; dropped = 1; }
      if(dropped) { xctx->need_reb_sel_arr = 1; rebuild_selected_array(); }
    }

    for(i=0;i<xctx->lastsel; ++i)
    {
      n = xctx->sel_array[i].n;
      if(xctx->sel_array[i].type == WIRE)
      {
        xctx->prep_hash_wires=0;
        firstw = 0;
        check_wire_storage();
        if(xctx->rotatelocal) {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->wire[n].x1, xctx->wire[n].y1,
            xctx->wire[n].x1, xctx->wire[n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->wire[n].x1, xctx->wire[n].y1,
            xctx->wire[n].x2, xctx->wire[n].y2, xctx->rx2,xctx->ry2);
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->wire[n].x1, xctx->wire[n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->wire[n].x2, xctx->wire[n].y2, xctx->rx2,xctx->ry2);
        }
        if( xctx->wire[n].sel & (SELECTED|SELECTED1) )
        {
         xctx->rx1+=xctx->deltax;
         xctx->ry1+=xctx->deltay;
        }
        if( xctx->wire[n].sel & (SELECTED|SELECTED2) )
        {
         xctx->rx2+=xctx->deltax;
         xctx->ry2+=xctx->deltay;
        }
        tmpx=xctx->rx1; /* used as temporary storage */
        tmpy=xctx->ry1;
        ORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
        if( tmpx == xctx->rx2 &&  tmpy == xctx->ry2)
        {
         if(xctx->wire[n].sel == SELECTED1) xctx->wire[n].sel = SELECTED2;
         else if(xctx->wire[n].sel == SELECTED2) xctx->wire[n].sel = SELECTED1;
        }
        xctx->sel_array[i].n=xctx->wires;
        storeobject(-1, xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2,WIRE,0,xctx->wire[n].sel,xctx->wire[n].prop_ptr);
        xctx->wire[n].sel=0;

        l = xctx->wires -1;
      }
    }

    for(k=0;k<cadlayers; ++k)
    {
     for(i=0;i<xctx->lastsel; ++i)
     {
      c = xctx->sel_array[i].col;n = xctx->sel_array[i].n;
      switch(xctx->sel_array[i].type)
      {
       case LINE:
        if(c!=k) break;
        if(xctx->rotatelocal) {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->line[c][n].x1, xctx->line[c][n].y1,
            xctx->line[c][n].x1, xctx->line[c][n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->line[c][n].x1, xctx->line[c][n].y1,
            xctx->line[c][n].x2, xctx->line[c][n].y2, xctx->rx2,xctx->ry2);
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->line[c][n].x1, xctx->line[c][n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->line[c][n].x2, xctx->line[c][n].y2, xctx->rx2,xctx->ry2);
        }
        if( xctx->line[c][n].sel & (SELECTED|SELECTED1) )
        {
         xctx->rx1+=xctx->deltax;
         xctx->ry1+=xctx->deltay;
        }
        if( xctx->line[c][n].sel & (SELECTED|SELECTED2) )
        {
         xctx->rx2+=xctx->deltax;
         xctx->ry2+=xctx->deltay;
        }
        tmpx=xctx->rx1;
        tmpy=xctx->ry1;
        ORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
        if( tmpx == xctx->rx2 &&  tmpy == xctx->ry2)
        {
         if(xctx->line[c][n].sel == SELECTED1) xctx->line[c][n].sel = SELECTED2;
         else if(xctx->line[c][n].sel == SELECTED2) xctx->line[c][n].sel = SELECTED1;
        }
        xctx->sel_array[i].n=xctx->lines[c];
        storeobject(-1, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2, LINE, c,
           xctx->line[c][n].sel, xctx->line[c][n].prop_ptr);
        xctx->line[c][n].sel=0;

        l = xctx->lines[c] - 1;
        break;

       case POLYGON:
        if(c!=k) break;
        {
          xPoly *p = &xctx->poly[c][n];
          double bx1 = 0.0, by1 = 0.0, bx2 = 0.0, by2 = 0.0;
          double *x = my_malloc(_ALLOC_ID_, sizeof(double) *p->points);
          double *y = my_malloc(_ALLOC_ID_, sizeof(double) *p->points);
          int j;
          for(j=0; j<p->points; ++j) {
            if( p->sel==SELECTED || p->selected_point[j]) {
              if(xctx->rotatelocal) {
                ROTATION(xctx->move_rot, xctx->move_flip, p->x[0], p->y[0], p->x[j], p->y[j], xctx->rx1,xctx->ry1);
              } else {
                ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1, p->x[j], p->y[j], xctx->rx1,xctx->ry1);
              }
              x[j] = xctx->rx1+xctx->deltax;
              y[j] = xctx->ry1+xctx->deltay;
            } else {
              x[j] = p->x[j];
              y[j] = p->y[j];
            }
            if(j==0 || x[j] < bx1) bx1 = x[j];
            if(j==0 || y[j] < by1) by1 = y[j];
            if(j==0 || x[j] > bx2) bx2 = x[j];
            if(j==0 || y[j] > by2) by2 = y[j];
          }
          xctx->sel_array[i].n=xctx->polygons[c];
          store_poly(-1, x, y, p->points, c, p->sel, p->prop_ptr);
          p->sel=0;
          my_free(_ALLOC_ID_, &x);
          my_free(_ALLOC_ID_, &y);
        }
        break;
       case ARC:
        if(c!=k) break;
        if(xctx->rotatelocal) {
          /* rotate center wrt itself: do nothing */
          xctx->rx1 = xctx->arc[c][n].x;
          xctx->ry1 = xctx->arc[c][n].y;
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->arc[c][n].x, xctx->arc[c][n].y, xctx->rx1,xctx->ry1);
        }
        angle = xctx->arc[c][n].a;
        if(xctx->move_flip) {
          angle = 270.*xctx->move_rot+180.-xctx->arc[c][n].b-xctx->arc[c][n].a;
        } else {
          angle = xctx->arc[c][n].a+xctx->move_rot*270.;
        }
        angle = fmod(angle, 360.);
        if(angle<0.) angle+=360.;
        xctx->arc[c][n].sel=0;
        xctx->sel_array[i].n=xctx->arcs[c];

        store_arc(-1, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                   xctx->arc[c][n].r, angle, xctx->arc[c][n].b, c, SELECTED, xctx->arc[c][n].prop_ptr);

        l = xctx->arcs[c] - 1;
        break;

       case xRECT:
        if(c!=k) break;
        if(xctx->rotatelocal) {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
            xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
            xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
        }
        RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
        xctx->rect[c][n].sel=0;
        xctx->sel_array[i].n=xctx->rects[c];
        /* following also clears extraptr */
        storeobject(-1, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                   xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay,xRECT, c, SELECTED, xctx->rect[c][n].prop_ptr);
        l = xctx->rects[c] - 1;
        flip_rotate_ellipse(&xctx->rect[c][l], xctx->move_rot, xctx->move_flip);
        /* The prop_ptr was cloned verbatim just above, so a copied GRAPH would
         * carry the ORIGINAL marker numbers -- and window-wide uniqueness is what
         * graph_marker_find / `prev` / the selection / delete all rest on. This
         * is the second duplication door; the first is merge_box (paste.c).
         * Note the ordering differs from merge_box's: storeobject has ALREADY
         * registered the new rect here, so the numbering scan sees it and the
         * base comes out above both copies. doc/claude/specs/graph_markers.md */
        if(xctx->rect[c][l].flags & 1) graph_marker_renumber_rect(&xctx->rect[c][l]);
        break;

       case xTEXT:
        if(k!=TEXTLAYER) break;
        check_text_storage();
        if(xctx->rotatelocal) {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->text[n].x0, xctx->text[n].y0,
           xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
        }
        xctx->text[xctx->texts].txt_ptr=NULL;
        my_strdup2(_ALLOC_ID_, &xctx->text[xctx->texts].txt_ptr,xctx->text[n].txt_ptr);
        xctx->text[n].sel=0;
         dbg(2, "copy_objects(): current str=%s\n",
          xctx->text[xctx->texts].txt_ptr);
        xctx->text[xctx->texts].x0=xctx->rx1+xctx->deltax;
        xctx->text[xctx->texts].y0=xctx->ry1+xctx->deltay;
        xctx->text[xctx->texts].rot=(xctx->text[n].rot +
         ( (xctx->move_flip && (xctx->text[n].rot & 1) ) ? xctx->move_rot+2 : xctx->move_rot) ) & 0x3;
        xctx->text[xctx->texts].flip=xctx->move_flip^xctx->text[n].flip;
        set_first_sel(xTEXT, xctx->texts, 0);
        xctx->text[xctx->texts].sel=SELECTED;
        xctx->text[xctx->texts].prop_ptr=NULL;
        xctx->text[xctx->texts].font=NULL;
        xctx->text[xctx->texts].floater_instname=NULL;
        xctx->text[xctx->texts].floater_ptr=NULL;
        xctx->text[xctx->texts].owner_pin_id=0; /* copied text is real; P4 handles view-aware copy */
        my_strdup2(_ALLOC_ID_, &xctx->text[xctx->texts].prop_ptr, xctx->text[n].prop_ptr);
        my_strdup2(_ALLOC_ID_, &xctx->text[xctx->texts].floater_ptr, xctx->text[n].floater_ptr);
        my_strdup2(_ALLOC_ID_, &xctx->text[xctx->texts].floater_instname, xctx->text[n].floater_instname);
        set_text_flags(&xctx->text[xctx->texts]);
        xctx->text[xctx->texts].xscale=xctx->text[n].xscale;
        xctx->text[xctx->texts].yscale=xctx->text[n].yscale;

        l = xctx->texts;

        #if HAS_CAIRO==1 /* bbox after copy */
        customfont = set_text_custom_font(&xctx->text[l]);
        #endif
        estr = my_expand(get_text_floater(l), tclgetintvar("tabstop"));
        text_bbox(estr, xctx->text[l].xscale,
          xctx->text[l].yscale, xctx->text[l].rot,xctx->text[l].flip,
          xctx->text[l].hcenter, xctx->text[l].vcenter,
          xctx->text[l].x0, xctx->text[l].y0,
          &xctx->rx1,&xctx->ry1, &xctx->rx2,&xctx->ry2, &tmpi, &dtmp);
        my_free(_ALLOC_ID_, &estr);
        #if HAS_CAIRO==1
        if(customfont) {
          cairo_restore(xctx->cairo_ctx);
        }
        #endif

        xctx->sel_array[i].n=xctx->texts;
        text_register(xctx->texts);
         dbg(2, "copy_objects(): done copy string\n");
        break;
       default:
        break;
      } /* end switch(xctx->sel_array[i].type) */
     } /* end for(i=0;i<xctx->lastsel; ++i) */


    } /* end for(k=0;k<cadlayers; ++k) */

    for(i = 0; i < xctx->lastsel; ++i) {
      n = xctx->sel_array[i].n;
      if(xctx->sel_array[i].type == ELEMENT) {
        xctx->prep_hash_inst = 0;
        firsti = 0;
        check_inst_storage();
        if(xctx->rotatelocal) {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->inst[n].x0, xctx->inst[n].y0,
             xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
        }
        xctx->inst[xctx->instances] = xctx->inst[n];
        xctx->inst[xctx->instances].prop_ptr=NULL;
        xctx->inst[xctx->instances].instname=NULL;
        xctx->inst[xctx->instances].lab=NULL;
        xctx->inst[xctx->instances].node=NULL;
        xctx->inst[xctx->instances].name=NULL;
        xctx->inst[xctx->instances].pin_sel=NULL;      /* transient pin selection: the copy
                                                        * must NOT alias the source's heap
                                                        * pin_sel buffer (pin_selection.md) */
        xctx->inst[xctx->instances].pin_sel_size=0;
        my_strdup2(_ALLOC_ID_, &xctx->inst[xctx->instances].name, xctx->inst[n].name);
        my_strdup2(_ALLOC_ID_, &xctx->inst[xctx->instances].prop_ptr, xctx->inst[n].prop_ptr);
        my_strdup2(_ALLOC_ID_, &xctx->inst[xctx->instances].lab, xctx->inst[n].lab);
        xctx->inst[n].sel=0;
        xctx->inst[xctx->instances].embed = xctx->inst[n].embed;
        xctx->inst[xctx->instances].flags = xctx->inst[n].flags;
        xctx->inst[xctx->instances].color = -10000;
        xctx->inst[xctx->instances].x0 = xctx->rx1+xctx->deltax;
        xctx->inst[xctx->instances].y0 = xctx->ry1+xctx->deltay;
        set_first_sel(ELEMENT, xctx->instances, 0);
        xctx->inst[xctx->instances].sel = SELECTED;
        xctx->inst[xctx->instances].rot = (xctx->inst[xctx->instances].rot + ( (xctx->move_flip &&
           (xctx->inst[xctx->instances].rot & 1) ) ? xctx->move_rot+2 : xctx->move_rot) ) & 0x3;
        xctx->inst[xctx->instances].flip = (xctx->move_flip? !xctx->inst[n].flip:xctx->inst[n].flip);
        my_strdup2(_ALLOC_ID_, &xctx->inst[xctx->instances].instname, xctx->inst[n].instname);
        /* the newpropcnt argument is zero for the 1st call and used in  */
        /* new_prop_string() for cleaning some internal caches. */
        if(!newpropcnt) hash_names(-1, XINSERT);
        newpropcnt++;
        new_prop_string(xctx->instances, xctx->inst[n].prop_ptr, /* sets also inst[].instname */
          tclgetboolvar("disable_unique_names"));

        update_attached_floaters(xctx->inst[n].instname, xctx->instances, 1);

        hash_names(xctx->instances, XINSERT);
        inst_register(xctx->instances); /* symbol_bbox calls translate and translate must have updated xctx->instances */
        symbol_bbox(xctx->instances-1,
             &xctx->inst[xctx->instances-1].x1, &xctx->inst[xctx->instances-1].y1,
             &xctx->inst[xctx->instances-1].x2, &xctx->inst[xctx->instances-1].y2);
      } /* if(xctx->sel_array[i].type == ELEMENT) */
    }  /* for(i = 0; i < xctx->lastsel; ++i) */
    xctx->need_reb_sel_arr=1;
    rebuild_selected_array();
    /* P4: regenerate name views for the just-copied pins. Each copy got a fresh xRect.id
     * (storeobject), so synth_pin_views() binds a NEW view to it; idempotent + symbol-mode
     * gated, so the original pins' existing views are left alone. */
    synth_pin_views();
    if(!firsti || !firstw) {
      xctx->prep_net_structs=0;
      xctx->prep_hi_structs=0;
    }
    /* build after copying and after recalculating prepare_netlist_structs() */
    check_collapsing_objects();
    /* W3: a moved/copied instance may drop a pin onto a wire (split) or lift one off (rejoin);
     * maintain re-splits at attachment points then pin-aware-merges. Gated on autotrim_wires;
     * undo owned by the enclosing move. See doc/claude/specs/wire_segment_splitting.md (W3). */
    if(tclgetboolvar("autotrim_wires")) maintain_wire_segments();
    if(xctx->hilight_nets) {
      propagate_hilights(1, 1, XINSERT_NOREPLACE);
    }
    xctx->ui_state &= ~STARTCOPY;
    xctx->x1 = xctx->y1 = xctx->x2 = xctx->y2 = xctx->deltax = xctx->deltay = 0;
    xctx->move_rot = xctx->move_flip = 0;
    set_modify(1); /* must be done before draw() if floaters are present to force cached values update */
    draw();
    xctx->rotatelocal=0;
  } /* if(what & END) */
  draw_selection(xctx->gc[SELLAYER], 0);
  if(tclgetboolvar("draw_crosshair")) draw_crosshair(3, 0); /* what = 1(clear) + 2(draw) */
}


/* order wire points and swap SELECTED1 / SELECTED2 if needed */
static void order_wire_points(int n)
{
  xWire * const wire = xctx->wire;
  double x1, y1;

  x1=wire[n].x1;
  y1=wire[n].y1;
  ORDER(wire[n].x1, wire[n].y1, wire[n].x2, wire[n].y2);
  if( x1 == wire[n].x2 && y1 == wire[n].y2) /* wire points reversed, so swap SELECTEDn */
  {
   if(wire[n].sel == SELECTED1) wire[n].sel = SELECTED2;
   else if(wire[n].sel == SELECTED2) wire[n].sel = SELECTED1;
  }
}

/* Phase III obstacle-aware L-orientation flip (defined below, next to the fluid snapshot code). */
static int fluid_ml_blocked(int ml, int sel1);
/* Phase IV P6 (min-bend): bias the fluid L orientation to a straight along-normal pin exit so the
 * P3 escape stub is unnecessary (defined below, after the fluid snapshot statics). */
static int fluid_p6_bias_ml(int sel1);
/* issue 0085 (blind-elbow diagonal fallback): full hazard classification of an L orientation --
 * superset of fluid_ml_blocked -- and its severity ranking (defined below, after the Layer-2
 * segment-test helpers they reuse). */
static int fluid_ml_hazards(int ml, int sel1);
static int fluid_mlh_sev(int h);
/* issue 0086 (future-blind elbow tie-break): does the L implied by `ml` lay copper on a co-moving
 * foreign-net pin's FINAL (post-remaining-legs) landing point? Tie-break input only (defined below,
 * after fluid_ml_hazards). */
static int fluid_ml_future_covers(int ml, int sel1);
/* pin-inclusive body-box helpers (0130/0133), defined far below but needed up here by
 * insert_exit_stubs (issue 0132 after_34: decline an exit-stub slide that would thread the pin body). */
static int fluid_inst_body_box(int i, double *bx1, double *by1, double *bx2, double *by2);
static int fluid_seg_crosses_sel_body(double x1, double y1, double x2, double y2);
static int fluid_seg_crosses_stationary_body(double x1, double y1, double x2, double y2); /* 0135 D2 */
/* issue 0086 companion: future-aware corner-slide decline (defined next to fluid_ml_future_covers) */
static int fluid_slide_future_hazard(int n, double fx, double fy, double mx, double my);
void fltrace(const char *fmt, ...);
/* issue 0091 (per-component "selection wins"): mark every wire touch-connected to a user-selected
 * wire so the END redundant-route cleanup leaves the user's own net(s) untouched (defined after
 * fluid_wire_reach_set, the flood it uses). */
static void fluid_mark_user_protected(unsigned char *prot);
/* issue 0092 (along-axis wire-drag overshoot): after a fluid stretch drags a same-net wire ALONG its own
 * axis, a dangling overshoot stub + solder dot is left instead of the riser being shoved. This END pass
 * shoves the riser column (or trims the stub) -- defined after fluid_straighten_reversals (shares its
 * partition-verify helpers). */
static void fluid_collapse_axis_overshoot_stub(void);
/* issue 0094 (group drag lands a moved device's off-net pin on a foreign backbone): a rip-up END pass that
 * un-shorts a move-created DEVICE MERGE by sliding the foreign backbone off the invader pin onto its
 * sibling's line, letting fluid_straighten_reversals prune the orphaned tails. */
static int fluid_ripup_foreign_pin_short(void);
/* issue 0094 tail: delete the fresh dangling backbone stub the rip-up + straighten can leave past the
 * sibling pin (connectivity-verified). Only called when the rip-up fired => strict no-op otherwise. */
static void fluid_prune_novel_orphan_stub(void);

/* xctx->{rx1, ry1} and xctx->{rx2, ry2} are the two line points after the move.
 * they are not guaranteed to be ordered (since only one of the two points may have changed)
 * so this must be taken care for */
static void place_moved_wire(int n, int orthogonal_wiring)
{
  xWire * const wire = xctx->wire;


  /* Need to dynamically assign `manhattan_lines` to each wire. Otherwise, a single
   * `manhattan_lines` value gets forced on all wires connected to a moved object*/
  if(orthogonal_wiring) {
    recompute_orthogonal_manhattanline(xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
    /* incremental_wire_reroute.md Phase III (§5/§6): obstacle-aware L-orientation selection. The
     * naive manhattan L can lay one of its two legs straight across a STATIONARY device between two
     * of its distinct-net pins -- a P2 short (R18's M-riser leg sweeping through ammeter v8). If the
     * orientation recompute chose is blocked and the OTHER orientation is clear, flip
     * manhattan_lines: the four placement branches below then lay the clean L between the SAME two
     * endpoints (rx1,ry1)-(rx2,ry2), so connectivity (P1) is unchanged by construction. Gated on
     * fluid_editing (default off => never flips => byte-identical), a valid START name snapshot,
     * and a stretching (single-endpoint) wire. Pure function of (snapshot, rx1..ry2)
     * => deterministic and release==stepwise (recompute yields only ml 1 or 2).
     * rotate_keep_connected_stretch.md Case 4b: the old `move_rot==0 && move_flip==0` guard is
     * lifted -- under a rotated/flipped stretch rx1..ry2 are the final rotated endpoints (crux (a)
     * keeps the anchored end pristine), so this obstacle-aware orientation pick still avoids
     * shorts on the SAME two endpoints. It only CHOOSES between two connecting L orientations, so
     * even if a hazard helper misjudges a rotated layout the worst case is a suboptimal-but-
     * connecting L (== the pre-4b basic L) -- it can never disconnect. */
    if(tclgetboolvar("fluid_editing") &&
       (wire[n].sel == SELECTED1 || wire[n].sel == SELECTED2)) {
      int sel1 = (wire[n].sel == SELECTED1);
      int ml0 = xctx->manhattan_lines, ml1 = (ml0 == 1) ? 2 : 1;
      /* fluid_ml_hazards() returns 0 when there is no START name snapshot, so no flip fires unless a
       * fluid stretch armed one -- the snapshot-presence gate lives inside the helper (its statics
       * are declared below this function). issue 0085: the old fluid_ml_blocked test (stationary
       * device two-pin bridge only) was blind to the L plowing a CO-MOVING pin (the moved device's
       * own far pin) and to a T-contact with a stationary wire's endpoint (C12's stub, after_5.sch),
       * so it picked "clean" orientations that shorted. fluid_ml_hazards classifies all four classes;
       * pick the orientation with the strictly LOWER severity (fluid_mlh_sev: pristine-net-verified
       * classes outrank the heuristic stray-contact class, so a proven device bridge still flips to a
       * merely stray-flagged orientation exactly as the old code did). Ties keep ml0 -- when both are
       * hazardous the 0085 partition re-check + rigid-relay fallback in move_objects owns P2. */
      int h0 = fluid_ml_hazards(ml0, sel1);
      int h1 = fluid_ml_hazards(ml1, sel1);
      int s0 = fluid_mlh_sev(h0), s1 = fluid_mlh_sev(h1);
      if(h0 || h1)
        fltrace("FLTRACE elbow: wire=%d sel1=%d ml0=%d h0=0x%x h1=0x%x -> ml=%d r1=(%g,%g) r2=(%g,%g)\n",
                n, sel1, ml0, h0, h1, (s1 < s0) ? ml1 : ml0,
                xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
      if(s1 < s0) {
        xctx->manhattan_lines = ml1;                 /* P2 obstacle flip (Phase III + 0085 classes) */
      } else if(!s0 && !s1) {
        /* issue 0086: future-aware tie-break, BEFORE the P6 bias. Both orientations are P2-clear
         * for THIS leg, but during leg 0 of the 0081 X-then-Y decomposition one of them can paint
         * the corridor a co-moving pin lands in after leg 1 -- where the follow stretch is
         * degenerate (a straight extension, no elbow freedom) so the short is unavoidable and the
         * whole attempt collapses to the rigid diagonal relay (before_3.sch -> after_6.sch: leg-0's
         * H-first corner at (-250,-90) == R18.M's final landing). If exactly one orientation avoids
         * every future landing, pick it; on a tie (both clear / both covered) fall through to P6
         * exactly as before. fluid_leg_future_* are zero outside decomposed legs => inert there. */
        int f0 = fluid_ml_future_covers(ml0, sel1);
        int f1 = fluid_ml_future_covers(ml1, sel1);
        if(f0 && !f1) {
          xctx->manhattan_lines = ml1;               /* only ml1 avoids the future landing */
        } else if(f0 == f1) {
        /* Phase IV P6 (min-bend): both orientations are P2-clear, so the choice is free BELOW P2 in
         * the conflict order (P1=P2 > P3 > P5 > P4 > P7 > P6). Prefer the orientation whose pin leg
         * exits ALONG the moving pin's escape normal -- a straight P3 exit that insert_exit_stubs then
         * SKIPS (move.c:1648-1649), removing the redundant escape-stub staircase bend at IDENTICAL
         * length. Returns 0 (keep ml0) unless the along-normal orientation is a proven, strict win. */
          int p6 = fluid_p6_bias_ml(sel1);
          if(p6) xctx->manhattan_lines = p6;
        }
        /* (!f0 && f1): keep ml0; P6 must not flip INTO the future-covered orientation */
        /* trace AFTER the whole decision (incl. P6) so `-> ml=` is the COMMITTED orientation --
         * review wf_b333bd95: printing the pre-P6 guess misreported the f0==f1 case */
        if(f0 || f1)
          fltrace("FLTRACE elbow-future: wire=%d sel1=%d ml0=%d f0=%d f1=%d -> ml=%d\n",
                  n, sel1, ml0, f0, f1, xctx->manhattan_lines);
      }
      /* (s0 <= s1, either hazardous): keep ml0 -- no strictly better orientation exists; the Layer-2
       * stop-short detour (pin-incident device straddles) and the 0085 attempt-2 rigid relay (all
       * remaining classes) own P2 downstream. */
    }
  }

  /* wire x1,y1 point was moved
   *
   *                          x1,y1(old)       rx2,ry2
   *           -----------------o-----------------o
   *          |       (H)
   * selected |(V)
   *          |
   *          o
   *       rx1,ry1(new)
   */
  if(wire[n].sel == SELECTED1 && (xctx->manhattan_lines & 1)) /* H - V */
  {
   int last;
   wire[n].x1 = xctx->rx1;
   wire[n].y1 = xctx->ry1;
   wire[n].x2 = xctx->rx1;
   wire[n].y2 = xctx->ry2;
   order_wire_points(n);
   if( xctx->rx1 != xctx->rx2) {
     /* the L-jog's second leg is the SAME net as wire[n] -> inherit its prop (the bus
      * label etc.). Matters when the original wire[n] degenerates to zero length and is
      * collapsed away (a colinear slide): this stored segment is then the survivor, so
      * dropping the prop here loses the wire's lab= entirely (TC12/R19). */
     storeobject(-1, xctx->rx1,xctx->ry2,xctx->rx2,xctx->ry2,WIRE,0,0,wire[n].prop_ptr);
     last = xctx->wires-1;
     order_wire_points(last);
   }
  }

  /* wire x2,y2 point was moved
   *
   *        rx1,ry1            x2,y2(old)
   *           o-----------------o-----------------
   *                                      (H)      |
   *                                            (V)| selected
   *                                               |
   *                                               o
   *                                            rx2,ry2(new)
   */
  else if(wire[n].sel == SELECTED2 && (xctx->manhattan_lines & 1)) /* H - V */
  {
   int last;
   wire[n].x1 = xctx->rx2;
   wire[n].y1 = xctx->ry1;
   wire[n].x2 = xctx->rx2;
   wire[n].y2 = xctx->ry2;
   order_wire_points(n);
   if( xctx->rx1 != xctx->rx2) {
     storeobject(-1, xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry1,WIRE,0,0,wire[n].prop_ptr);
     last = xctx->wires-1;
     order_wire_points(last);
   }
  }

  /* wire x1,y1 point was moved
   *
   *                           x1,y1(old)       rx2,ry2
   *                             o-----------------o
   *                                               |
   *                                            (V)|
   *                  (H) selected                 |
   *           o-----------------------------------
   *        rx1,ry1(new)
   */
  else if(wire[n].sel == SELECTED1 && (xctx->manhattan_lines & 2)) /* V - H */
  {
   int last;
   wire[n].x1 = xctx->rx1;
   wire[n].y1 = xctx->ry1;
   wire[n].x2 = xctx->rx2;
   wire[n].y2 = xctx->ry1;
   order_wire_points(n);
   if( xctx->ry1 != xctx->ry2) {
     storeobject(-1, xctx->rx2,xctx->ry1,xctx->rx2,xctx->ry2,WIRE,0,0,wire[n].prop_ptr);
     last = xctx->wires-1;
     order_wire_points(last);
   }
  }

  /* wire x2,y2 point was moved
   *
   *        rx1,ry1            x2,y2(old)
   *           o-----------------o
   *           |
   *           |(V)
   *           |      (H) selected
   *            -----------------------------------o
   *                                            rx2,ry2(new)
   */
  else if(wire[n].sel == SELECTED2 && (xctx->manhattan_lines & 2)) /* V - H */
  {
   int last;
   wire[n].x1 = xctx->rx1;
   wire[n].y1 = xctx->ry2;
   wire[n].x2 = xctx->rx2;
   wire[n].y2 = xctx->ry2;
   order_wire_points(n);
   if( xctx->ry1 != xctx->ry2) {
     storeobject(-1, xctx->rx1,xctx->ry1,xctx->rx1,xctx->ry2,WIRE,0,0,wire[n].prop_ptr);
     last = xctx->wires-1;
     order_wire_points(last);
   }
  }

  else /* no manhattan or traslation since both line points moved */
  {
   wire[n].x1 = xctx->rx1;
   wire[n].y1 = xctx->ry1;
   wire[n].x2 = xctx->rx2;
   wire[n].y2 = xctx->ry2;
   order_wire_points(n);
  }
}

/* Does (x,y) coincide with instance pin (px,py)? Tolerance = cadsnap/2, the SAME
 * predicate select_attached_nets()'s endpoint_near() (select.c) uses to grab wires
 * for stretching -- so the two ends of the stretch pipeline agree on "on the pin":
 * a wire grabbed at a sub-grid-near pin is recognized by the corner-slide pin tests
 * too, instead of the corner-slide silently failing its exact `==` test and letting
 * the wire jog (issue 0046). Exact on grid-aligned designs (endpoints sit on pins,
 * and adjacent pins are cadsnap apart > cadsnap/2, so no false neighbour match). */
static int point_near_pin(double px, double py, double x, double y)
{
  double tol = tclgetdoublevar("cadsnap") / 2.0;
  if(tol < 1e-6) tol = 1e-6;
  return fabs(px - x) <= tol && fabs(py - y) <= tol;
}

/* Is (px,py) a point where a straight STATIONARY wire run -- PERPENDICULAR to the current
 * move axis -- passes THROUGH? Two collinear, oppositely-directed stationary wire endpoints
 * meeting there is the signature of a mid-span TAP that the wire-segment-splitting feature
 * broke into abutting collinear segments (doc/claude/specs/wire_segment_splitting.md).
 * Dragging the shared endpoint of such a PERPENDICULAR run bends it off-axis -> a detour;
 * so a stub anchored there (or a perpendicular slide candidate whose far end lands there)
 * must JOG/stay put instead of sliding.
 *
 * The run must be PERPENDICULAR to the move: a run PARALLEL to the move slides cleanly ALONG
 * itself (a device tapping a rail/bus and dragged along it -- the corner-slide we must NOT
 * suppress), so those are deliberately NOT reported. Uses xctx->deltax/deltay (the move axis,
 * valid inside compute_wire_slide, the sole caller). Mirrors select.c wire_through_tap_arm();
 * exact == compare -- split points sit on exact grid-aligned pin coords. */
static int point_is_collinear_pass(double px, double py)
{
  int a, b;
  double ax, ay, bx, by, cross, dot;
  for(a = 0; a < xctx->wires; a++) {
    if(xctx->wire[a].sel) continue; /* only STATIONARY wires form a "staying-put" run */
    if(xctx->wire[a].x1 == px && xctx->wire[a].y1 == py)      { ax = xctx->wire[a].x2 - px; ay = xctx->wire[a].y2 - py; }
    else if(xctx->wire[a].x2 == px && xctx->wire[a].y2 == py) { ax = xctx->wire[a].x1 - px; ay = xctx->wire[a].y1 - py; }
    else continue;
    if(ax == 0 && ay == 0) continue;
    /* keep only runs PERPENDICULAR to the move (vertical move -> horizontal run ay==0, and
     * vice-versa); a run parallel to the move slides cleanly and must not be blocked. */
    if(xctx->deltay != 0.0 && ay != 0.0) continue;
    if(xctx->deltax != 0.0 && ax != 0.0) continue;
    for(b = a + 1; b < xctx->wires; b++) {
      if(xctx->wire[b].sel) continue;
      if(xctx->wire[b].x1 == px && xctx->wire[b].y1 == py)      { bx = xctx->wire[b].x2 - px; by = xctx->wire[b].y2 - py; }
      else if(xctx->wire[b].x2 == px && xctx->wire[b].y2 == py) { bx = xctx->wire[b].x1 - px; by = xctx->wire[b].y1 - py; }
      else continue;
      if(bx == 0 && by == 0) continue;
      cross = ax * by - ay * bx;   /* 0  => collinear      */
      dot   = ax * bx + ay * by;   /* <0 => opposite sense */
      if(cross == 0 && dot < 0) return 1;
    }
  }
  return 0;
}

/* is (x,y) on a pin of a FIXED (non-selected, i.e. non-moving) instance? */
static int point_on_fixed_pin(double x, double y)
{
  int inst, r, rects;
  double px, py;
  for(inst = 0; inst < xctx->instances; inst++) {
    if(xctx->inst[inst].sel) continue;       /* skip moving instances */
    if(xctx->inst[inst].ptr < 0) continue;
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; r++) {
      get_inst_pin_coord(inst, r, &px, &py);
      if(point_near_pin(px, py, x, y)) return 1;
    }
  }
  return 0;
}

/* is (x,y) on a pin of a MOVING (selected) instance? The corner-slide only applies
 * when the stretch is DRIVEN by a moving instance pin. A wire grabbed at a wire-wire
 * junction (its moving end coincides with a dragged wire's endpoint, not a pin) must
 * stay anchored at that junction, not slide (issue 0014). */
static int point_on_moving_pin(double x, double y)
{
  int inst, r, rects;
  double px, py;
  for(inst = 0; inst < xctx->instances; inst++) {
    if(!xctx->inst[inst].sel) continue;      /* only MOVING instances */
    if(xctx->inst[inst].ptr < 0) continue;
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; r++) {
      get_inst_pin_coord(inst, r, &px, &py);
      if(point_near_pin(px, py, x, y)) return 1;
    }
  }
  return 0;
}

/* D1/D2 (hardening sprint Track D -- WIRING.md §2.3, §7.9 / backlog R2): the single home for all fluid
 * move state. The four START snapshots every consumer reads (armed once at move START by
 * fluid_gesture_arm(); freed once at the real END/ABORT and at clear_schematic buffer teardown by
 * fluid_gesture_free() -- the single-instance lifecycle is structural: arm DETECTS a still-armed prior
 * gesture and recovers+logs it), PLUS the hand-down "hidden parameter" scratch fields (D2), each valid
 * only inside a stated sub-gesture window. Zero-init at rest is safe: every scratch field is WRITTEN
 * before it is READ within its window (the -1 doom watermarks feed n >= watermark over wire indices
 * >= 0, for which -1 and 0 are equivalent). The instance x pin walk that position-indexes snap_id /
 * snap_pinnet / geo_snap_id must be replicated byte-identically in every consumer (landmine §7.5).
 * Declared HERE (ahead of fluid_slide_push_through, the first field consumer) so all fluid code sees it. */
typedef struct { double x1, y1, x2, y2; char *lab; } fluid_startwire_t;
typedef struct {
  /* --- START snapshots (validity window: one whole gesture; armed/freed via arm/free) --- */
  int    *snap_id;         /* canonical NAME partition id per instance pin, captured at START. Keyed to
                            * pin POSITION not net name (a pure #net rename yields an identical vector). */
  int     snap_npins;      /* 0 => no valid snapshot */
  char  **snap_pinnet;     /* strdup'd resolved net NAME (or NULL) per instance pin at START -- for the
                            * device-merge P2 check (spec §9); node[] itself is freed/rebuilt per move. */
  int    *geo_snap_id;     /* issue 0104: GEOMETRIC pin partition (fluid_loop_partition rep[] over the
                            * pristine wires). The NAME snapshot above merges geometrically disjoint
                            * same-name islands (multi-island GND/VDD) and is blind to netlist-ignored
                            * wires (spice_ignore skips prepare_netlist_structs' hashing), so a
                            * geometry-vs-name compare either never fires or blesses deleting pristine
                            * copper only the geometry sees (review wf_506236ef). */
  int     geo_snap_npins;  /* 0 => no valid geometric snapshot */
  fluid_startwire_t *start_wire; /* issue 0088: START wire set (order-normalized endpoints + raw lab=
                            * token). The redundant-loop cleanup requires the collapsed cycle to contain
                            * >=1 edge THIS drag produced (absent from this set) -- the novelty scope (H3)
                            * that keeps it off pre-existing user copper. Constant across the gesture. */
  int     start_nwire;     /* 0 => no snapshot => fluid_wire_is_novel() fails safe (not novel) */
  /* --- D2: hand-down "hidden parameter" scratch (WIRING §7.9), each with its VALIDITY WINDOW.
   *     Byte-identical fold: all are set-before-read within their window (see the header note). --- */
  int     slide_pushthrough_on; /* window: one ATTEMPT. issue 0109: attempts >= 1 of the P2 safety net
                            * re-run the commit with the push-through slide OFF (set = attempt==0 at each
                            * attempt top; reset =1 at gesture END so a push-through that damaged the
                            * pin-partition rolls back to the exact pre-0109 route). */
  double  leg_future_dx, leg_future_dy; /* window: one LEG. issue 0086: unapplied delta of the LATER
                            * decomposition legs, read by the leg-0 elbow tie-break (fluid_ml_future_covers);
                            * 0 outside decomposed legs (single-pass moves / attempts 1-2). */
  double  stretch_premove_x, stretch_premove_y; /* window: one place_moved_wire() call. issue 0100:
                            * PRISTINE pre-move coords of the follow wire's moving endpoint, handed to
                            * fluid_ml_hazards so the pre-move pin lookup need not invert a rotation about
                            * an ASSUMED pivot (wrong under ALT-R/ALT-F rotatelocal). */
  int     stretch_premove_valid; /* window: one place_moved_wire() call; gates the two _premove_ fields. */
  int     jog_doomed_from; /* window: one fluid_jog_pin_off_backbone ci-iteration. Watermark for
                            * fluid_jog_is_doomed (wire_delete_compact): wires with index >= this are doomed.
                            * Set at each ci top before the delete; never read at its init value. */
  int     manh_doomed_from;/* window: one fluid_try_reanchor call / one manhattanize ci-iteration. Watermark
                            * for fluid_manh_is_doomed; set at each entry before the delete. */
} Fluid_gesture;
static Fluid_gesture fluid_g;       /* the one gesture context; zero-init at rest => no snapshot, neutral scratch */
static int fluid_gesture_armed = 0; /* D1 lifecycle tripwire: 1 between arm and free (single-free) */

/* Exact electrical touch of two closed axis-aligned (or degenerate) segments: an endpoint of one
 * lies on the other's span (covers T contacts and collinear overlap -- for 1-D intervals an
 * overlap always contains an endpoint). Interior X crossings do NOT touch (WIRING.md §1.2).
 * Returns 0 for diagonal inputs (pre-elbow follower spans): no exact claim is possible there,
 * the bbox rule alone governs them. */
static int fluid_seg_exact_touch(double ax1, double ay1, double ax2, double ay2,
                                 double bx1, double by1, double bx2, double by2)
{
  double axlo = ax1 < ax2 ? ax1 : ax2, axhi = ax1 < ax2 ? ax2 : ax1;
  double aylo = ay1 < ay2 ? ay1 : ay2, ayhi = ay1 < ay2 ? ay2 : ay1;
  double bxlo = bx1 < bx2 ? bx1 : bx2, bxhi = bx1 < bx2 ? bx2 : bx1;
  double bylo = by1 < by2 ? by1 : by2, byhi = by1 < by2 ? by2 : by1;
  if(ax1 != ax2 && ay1 != ay2) return 0;               /* diagonal: bbox rule governs */
  if(bx1 != bx2 && by1 != by2) return 0;
  if(bxlo <= ax1 && ax1 <= bxhi && bylo <= ay1 && ay1 <= byhi) return 1;   /* A endpoints on B */
  if(bxlo <= ax2 && ax2 <= bxhi && bylo <= ay2 && ay2 <= byhi) return 1;
  if(axlo <= bx1 && bx1 <= axhi && aylo <= by1 && by1 <= ayhi) return 1;   /* B endpoints on A */
  if(axlo <= bx2 && bx2 <= axhi && aylo <= by2 && by2 <= ayhi) return 1;
  return 0;
}

/* 0109 landing-guard helper (bred by wireedit 36d/38B): would moving a wire from span
 * (ox1,oy1)-(ox2,oy2) to (nx1,ny1)-(nx2,ny2) introduce a NEW contact with a STATIONARY wire
 * resolved to a net other than nf? Two rules per obstacle wire:
 * 1. NEW bbox overlap (shove-grade conservative: a new interior X crossing counts, matching
 *    fluid_seg_hits_foreign_wire's contract). A pair that already bbox-touched pre-move is
 *    grandfathered -- a long riser that legitimately crosses a distant bus keeps crossing it
 *    wherever it lands (before_8: the #net3 riser x-crosses the #net1 feed row both before and
 *    after the vacating slide; declining on that pre-existing crossing killed the 0109 repair).
 * 2. NEW exact endpoint-on-span touch, checked REGARDLESS of the grandfather (wireedit 52,
 *    review wf_bfc3c5e4): a pre-existing inert X crossing must not amnesty an electrically
 *    REAL weld with the same wire -- kind-blind grandfathering re-opened the 36d class.
 * Requires a fresh wire[].node cache (caller runs prepare_netlist_structs(0)); NULL/empty/
 * same-net nodes are fine to touch. */
static int fluid_pushthrough_new_foreign_contact(double ox1, double oy1, double ox2, double oy2,
                                                 double nx1, double ny1, double nx2, double ny2,
                                                 const char *nf)
{
  int m;
  double oxlo = ox1 < ox2 ? ox1 : ox2, oxhi = ox1 < ox2 ? ox2 : ox1;
  double oylo = oy1 < oy2 ? oy1 : oy2, oyhi = oy1 < oy2 ? oy2 : oy1;
  double nxlo = nx1 < nx2 ? nx1 : nx2, nxhi = nx1 < nx2 ? nx2 : nx1;
  double nylo = ny1 < ny2 ? ny1 : ny2, nyhi = ny1 < ny2 ? ny2 : ny1;
  for(m = 0; m < xctx->wires; ++m) {
    double wx1, wy1, wx2, wy2, clo, chi, dlo, dhi;
    const char *wn;
    int bbox_new, bbox_old;
    if(xctx->wire[m].sel) continue;                     /* moving wires are not obstacles */
    wn = xctx->wire[m].node;
    if(!wn || !wn[0]) continue;                         /* unresolved -> treat as same-net (skip) */
    if(nf && nf[0] && !strcmp(wn, nf)) continue;        /* same net -> a legitimate touch */
    wx1 = xctx->wire[m].x1; wy1 = xctx->wire[m].y1; wx2 = xctx->wire[m].x2; wy2 = xctx->wire[m].y2;
    clo = wx1 < wx2 ? wx1 : wx2; chi = wx1 < wx2 ? wx2 : wx1;
    dlo = wy1 < wy2 ? wy1 : wy2; dhi = wy1 < wy2 ? wy2 : wy1;
    bbox_new = (nxlo <= chi && clo <= nxhi && nylo <= dhi && dlo <= nyhi);
    if(!bbox_new) continue;                             /* final: no contact of any kind */
    bbox_old = (oxlo <= chi && clo <= oxhi && oylo <= dhi && dlo <= oyhi);
    if(!bbox_old) return 1;                             /* rule 1: brand-new bbox contact */
    /* rule 2: grandfathered pair -- still decline if the final geometry makes an exact
     * electrical touch the pristine geometry did not have */
    if(fluid_seg_exact_touch(nx1, ny1, nx2, ny2, wx1, wy1, wx2, wy2) &&
       !fluid_seg_exact_touch(ox1, oy1, ox2, oy2, wx1, wy1, wx2, wy2)) return 1;
  }
  return 0;
}

/* Push-through corner slide (issue 0109). A follow wire PARALLEL to a pure-axis move whose pin
 * is dragged strictly PAST the far (anchored) end used to just stretch straight THROUGH the
 * anchor -- across the perpendicular riser footed there and across the sibling pin travelling on
 * the same row -- welding distinct nets (before_8.sch: R18 dragged (-110,0) -> after_26.sch, the
 * device shorted out). When every other wire at the anchor is a stationary PERPENDICULAR corner
 * leg, promote the stub AND those legs to full SELECTED so they TRANSLATE with the pin (the
 * riser vacates the row), and partial-select the wires cornered at each promoted leg's far end
 * so they stretch to follow -- the same neighbour-drag rule the perpendicular corner-slide uses.
 * Declines (plain stretch, pre-0109 geometry) when the anchor sits on any pin, is a collinear
 * pass-through tap, dangles free, when a corner wire is itself part of the move, or on a
 * future-landing hazard. Gated on fluid_editing + tool-owned-only follow set; the pure-axis P2
 * safety net (leg_snap, armed for exactly this gate) partition-verifies the commit and retries
 * with fluid_g.slide_pushthrough_on cleared if the promoted route damaged connectivity.
 * See doc/claude/issues/0109-fluid-drag-through-anchor-collinear-short.md.
 * Returns 1 when it promoted (caller re-runs its fixpoint scan). */
static int fluid_slide_push_through(int n)
{
  int m, nperp = 0, dxnz = (xctx->deltax != 0.0);
  double fx, fy, mx, my, a_m, a_f, d;
  xWire * const wire = xctx->wire;

  if(!fluid_g.slide_pushthrough_on) return 0;
  if(!tclgetboolvar("fluid_editing")) return 0;
  if(xctx->fluid_startsel_wires != 0) return 0;    /* tool-owned follow set only (matches the net's gate) */
  if(wire[n].sel == SELECTED1) { fx = wire[n].x2; fy = wire[n].y2; mx = wire[n].x1; my = wire[n].y1; }
  else                         { fx = wire[n].x1; fy = wire[n].y1; mx = wire[n].x2; my = wire[n].y2; }
  if(!point_on_moving_pin(mx, my)) return 0;       /* stretch must be driven by a dragged pin */
  d   = dxnz ? xctx->deltax : xctx->deltay;
  a_m = dxnz ? mx : my;
  a_f = dxnz ? fx : fy;
  if((a_f - a_m) * d <= 0.0) return 0;             /* pin moves AWAY from the anchor: plain stretch */
  if(fabs(d) <= fabs(a_f - a_m)) return 0;         /* pin stops at/before the anchor: plain stretch */
  if(point_on_fixed_pin(fx, fy)) return 0;         /* anchored on a fixed pin: must jog to keep it */
  if(point_on_moving_pin(fx, fy)) return 0;        /* both ends pin-driven: not a slide corner */
  if(point_is_collinear_pass(fx, fy)) return 0;    /* straight run passes through: a tap, not a corner */
  if(fluid_slide_future_hazard(n, fx, fy, mx, my)) return 0;
  for(m = 0; m < xctx->wires; m++) {
    int at1, at2, perp;
    if(m == n) continue;
    at1 = (wire[m].x1 == fx && wire[m].y1 == fy);
    at2 = (wire[m].x2 == fx && wire[m].y2 == fy);
    if(!at1 && !at2) continue;
    if(wire[m].sel) return 0;                      /* corner wire already part of the move: decline */
    perp = dxnz ? (wire[m].x1 == wire[m].x2 && wire[m].y1 != wire[m].y2)
                : (wire[m].y1 == wire[m].y2 && wire[m].x1 != wire[m].x2);
    if(!perp) return 0;                            /* parallel/diagonal continuation: decline */
    if(fluid_slide_future_hazard(m, at1 ? wire[m].x2 : wire[m].x1,
                                    at1 ? wire[m].y2 : wire[m].y1, fx, fy)) return 0;
    nperp++;
  }
  if(nperp == 0) return 0;                         /* free dangling anchor: keep the plain stretch */
  /* Landing guard (wireedit 36d/38B regression of the first 0109 landing): no wire this
   * promotion reshapes may make a NEW contact with stationary foreign-net copper. The leg_snap
   * partition verify downstream is PIN-indexed -- it cannot see a pin-less or label-only net, so
   * a promoted leg T-ing onto a foreign wire endpoint sails through it (test_wireedit_36 shape d
   * welded NY into NA; only the log-only backstop noticed). Contact = closed-bbox overlap
   * (shove-grade conservative: a new interior X crossing also declines, test_wireedit_38 B), but
   * pre-existing pair contacts are grandfathered -- see fluid_pushthrough_new_foreign_contact.
   * ANY new contact declines to the plain-stretch baseline (never worse; the attempt ladder still
   * guards the pin-visible failure modes). The follower spans may be diagonal pre-elbow; their
   * bbox is a conservative superset of the re-laid L. prepare_netlist_structs(0) is only paid
   * AFTER every structural gate passed (rare), never on a plain drag. */
  {
    const char *nf;
    double ddx = xctx->deltax, ddy = xctx->deltay;
    prepare_netlist_structs(0);        /* fresh wire[].node cache; geometry is untouched so far */
    nf = wire[n].node;
    if(fluid_pushthrough_new_foreign_contact(wire[n].x1, wire[n].y1, wire[n].x2, wire[n].y2,
                                             wire[n].x1 + ddx, wire[n].y1 + ddy,
                                             wire[n].x2 + ddx, wire[n].y2 + ddy, nf)) {
      fltrace("FLTRACE slide: wire=%d push-through DECLINE (stub lands on foreign wire)\n", n);
      return 0;
    }
    for(m = 0; m < xctx->wires; m++) {
      double ox, oy;
      int q;
      if(m == n) continue;
      if(wire[m].x1 == fx && wire[m].y1 == fy)      { ox = wire[m].x2; oy = wire[m].y2; }
      else if(wire[m].x2 == fx && wire[m].y2 == fy) { ox = wire[m].x1; oy = wire[m].y1; }
      else continue;
      if(fluid_pushthrough_new_foreign_contact(wire[m].x1, wire[m].y1, wire[m].x2, wire[m].y2,
                                               wire[m].x1 + ddx, wire[m].y1 + ddy,
                                               wire[m].x2 + ddx, wire[m].y2 + ddy, nf)) {
        fltrace("FLTRACE slide: wire=%d push-through DECLINE (corner leg %d lands on foreign wire)\n",
                n, m);
        return 0;
      }
      for(q = 0; q < xctx->wires; q++) {           /* the stretch-followers' final spans too */
        double qx, qy;
        if(q == m || q == n) continue;
        if(wire[q].x1 == ox && wire[q].y1 == oy)      { qx = wire[q].x2; qy = wire[q].y2; }
        else if(wire[q].x2 == ox && wire[q].y2 == oy) { qx = wire[q].x1; qy = wire[q].y1; }
        else continue;
        if(fluid_pushthrough_new_foreign_contact(ox, oy, qx, qy,
                                                 ox + ddx, oy + ddy, qx, qy, nf)) {
          fltrace("FLTRACE slide: wire=%d push-through DECLINE (follower %d lands on foreign wire)\n",
                  n, q);
          return 0;
        }
      }
    }
  }
  fltrace("FLTRACE slide: wire=%d PUSH-THROUGH anchor=(%g,%g) pin=(%g,%g) d=%g (%d corner leg(s))\n",
          n, fx, fy, mx, my, d, nperp);
  wire[n].sel = SELECTED;                          /* the stub translates with the pin */
  for(m = 0; m < xctx->wires; m++) {
    double ox, oy;
    int q;
    if(m == n) continue;
    if(wire[m].x1 == fx && wire[m].y1 == fy)      { ox = wire[m].x2; oy = wire[m].y2; }
    else if(wire[m].x2 == fx && wire[m].y2 == fy) { ox = wire[m].x1; oy = wire[m].y1; }
    else continue;
    wire[m].sel = SELECTED;                        /* each corner leg translates too */
    for(q = 0; q < xctx->wires; q++) {             /* wires cornered at its far end stretch to follow */
      if(q == m || q == n) continue;
      if(wire[q].x1 == ox && wire[q].y1 == oy && !(wire[q].sel & (SELECTED | SELECTED1)))
        select_wire(q, SELECTED1, 3, 0);
      if(wire[q].x2 == ox && wire[q].y2 == oy && !(wire[q].sel & (SELECTED | SELECTED2)))
        select_wire(q, SELECTED2, 3, 0);
    }
  }
  return 1;
}

/* Corner-slide (wire-editing Phase 4, Issues D1/D2/D4 -> R7/R8). After a stretch
 * move has partially selected the wires attached to the moved pins (one endpoint
 * each, via select_attached_nets()), a wire that runs PERPENDICULAR to the move
 * and forms a CORNER with another wire should SLIDE: translate so the corner moves
 * with the pin, rather than freezing while place_moved_wire() grows a jog stub at
 * the moved end (the "frozen corner + spurious stub" of Issue D1/D2).
 *
 * Rule, iterated to a fixpoint so a chain of corners slides together:
 *   - take each partially-selected (single-endpoint) wire perpendicular to the move;
 *   - require its MOVING endpoint to sit on a MOVING instance pin -- i.e. the stretch
 *     is driven by a dragged component, not by a dragged wire. A wire grabbed at a
 *     wire-wire junction (moving end on another wire's endpoint, no pin there) stays
 *     anchored, so dragging a wire never pulls a perpendicular wire off the junction
 *     (issue 0014);
 *   - if its FAR (non-moving) endpoint sits on a FIXED instance pin, leave it alone
 *     -> it must JOG to keep that connection (guard R18/TC15);
 *   - else if the far endpoint is a free dangling end (no other wire there), leave
 *     it alone -> it JOGS, anchoring the free end (TC3);
 *   - else (the far end meets another wire = a corner) PROMOTE it to a full
 *     selection so both endpoints translate, and select the coincident endpoint of
 *     every neighbour wire at that corner so they stretch to follow (R2).
 *
 * Caller guards this to orthogonal-wiring, axis-aligned, non-rotating moves.
 * Uses xctx->deltax/deltay only to know the move axis. Rebuilds sel_array so the
 * move-commit loop visits the promoted/propagated wires. */
static void compute_wire_slide(void)
{
  int n, m, changed;
  double fx, fy;                        /* far (non-moving) endpoint of wire n */
  double mx, my;                        /* moving (selected) endpoint of wire n */
  int dxnz = (xctx->deltax != 0.0);     /* horizontal move */
  int dynz = (xctx->deltay != 0.0);     /* vertical move */
  xWire * const wire = xctx->wire;

  if(dxnz == dynz) return;              /* not a pure axis-aligned move: nothing to do */

  do {
    changed = 0;
    for(n = 0; n < xctx->wires; n++) {
      int has_corner = 0;
      /* only single-endpoint (stretching) wires; SELECTED (full) and 0 are skipped */
      if(wire[n].sel != SELECTED1 && wire[n].sel != SELECTED2) continue;
      /* perpendicular to the move? vertical move -> horizontal wire, and vice-versa.
       * A wire PARALLEL to the move gets the push-through slide check (issue 0109): the pin
       * dragged strictly past its anchor promotes the anchor's corner legs to translate along. */
      if((dynz && wire[n].y1 != wire[n].y2) || (dxnz && wire[n].x1 != wire[n].x2)) {
        if((dynz ? (wire[n].x1 == wire[n].x2 && wire[n].y1 != wire[n].y2)
                 : (wire[n].y1 == wire[n].y2 && wire[n].x1 != wire[n].x2)) &&
           fluid_slide_push_through(n)) changed = 1;
        continue;
      }
      /* far endpoint = the one NOT selected; moving endpoint = the selected one */
      if(wire[n].sel == SELECTED1) { fx = wire[n].x2; fy = wire[n].y2; mx = wire[n].x1; my = wire[n].y1; }
      else                         { fx = wire[n].x1; fy = wire[n].y1; mx = wire[n].x2; my = wire[n].y2; }
      /* (a) slide only when the moving end is driven by a moving instance pin; a wire
       * grabbed at a wire-wire junction stays anchored there (issue 0014) */
      if(!point_on_moving_pin(mx, my)) continue;
      /* never slide a wire off a fixed pin -> let it jog (keeps the connection) */
      if(point_on_fixed_pin(fx, fy)) continue;
      /* far end where a straight run passes through (a split mid-span tap) is not a
       * corner: jog/stay so moving a tap never drags the through-wire (the kiss stub
       * dropped at such a tap stays a clean single stub). */
      if(point_is_collinear_pass(fx, fy)) continue;
      /* a corner needs another wire endpoint coincident with the far end */
      for(m = 0; m < xctx->wires; m++) {
        if(m == n) continue;
        if((wire[m].x1 == fx && wire[m].y1 == fy) ||
           (wire[m].x2 == fx && wire[m].y2 == fy)) { has_corner = 1; break; }
      }
      if(!has_corner) continue;        /* free dangling far end -> jog (TC3) */
      /* issue 0086: the corner slide is a P4 aesthetic -- decline it when the slid copper (or a
       * dragged neighbour's stretched run) would park on a co-moving foreign-net pin's FINAL
       * landing point, because the later decomposition leg then has NO elbow freedom left and the
       * short is guaranteed. Declining falls back to the ordinary jog relay, whose hazard-aware
       * elbow (fluid_ml_hazards + fluid_ml_future_covers) picks a clean L. Inert outside
       * decomposed fluid legs (fluid_leg_future_* zero => helper returns 0). */
      if(fluid_slide_future_hazard(n, fx, fy, mx, my)) {
        fltrace("FLTRACE slide: wire=%d corner=(%g,%g) DECLINE (future pin landing on slid copper)\n",
                n, fx, fy);
        continue;
      }
      /* issue 0086 review (wf_b333bd95 F1): the corner is SHARED. Accepting THIS slide promotes
       * every co-candidate wire at the corner whose OTHER end is already pin-grabbed to full
       * SELECTED (the loop below adds the second flag; select_wire folds SELECTED1|SELECTED2 to
       * SELECTED, select.c:965) -- a RIGID translate of exactly the copper that co-candidate's own
       * hazard test would (or did) decline, bypassing the 0086 decline entirely and, order-
       * dependently, even skipping its candidacy test (line 1465 skips SELECTED). So veto the
       * whole corner group: if any co-candidate that would fold to full SELECTED is itself
       * future-hazardous as a rigid slide, this wire must jog too. Inert outside decomposed
       * fluid legs (fluid_slide_future_hazard returns 0). */
      {
        int hz = 0;
        for(m = 0; m < xctx->wires && !hz; m++) {
          if(m == n) continue;
          if(wire[m].x1 == fx && wire[m].y1 == fy && (wire[m].sel & SELECTED2) &&
             fluid_slide_future_hazard(m, fx, fy, wire[m].x2, wire[m].y2)) hz = 1;
          if(wire[m].x2 == fx && wire[m].y2 == fy && (wire[m].sel & SELECTED1) &&
             fluid_slide_future_hazard(m, fx, fy, wire[m].x1, wire[m].y1)) hz = 1;
        }
        if(hz) {
          fltrace("FLTRACE slide: wire=%d corner=(%g,%g) DECLINE (co-candidate at corner is future-hazardous)\n",
                  n, fx, fy);
          continue;
        }
      }

      /* slide: translate this wire, drag the neighbour endpoints at the corner */
      wire[n].sel = SELECTED;
      changed = 1;
      for(m = 0; m < xctx->wires; m++) {
        if(m == n) continue;
        if(wire[m].x1 == fx && wire[m].y1 == fy && !(wire[m].sel & (SELECTED | SELECTED1))) {
          select_wire(m, SELECTED1, 3, 0); changed = 1;
        }
        if(wire[m].x2 == fx && wire[m].y2 == fy && !(wire[m].sel & (SELECTED | SELECTED2))) {
          select_wire(m, SELECTED2, 3, 0); changed = 1;
        }
      }
    }
  } while(changed);

  rebuild_selected_array();
}

/* is (x,y) on a pin of ANY instance (moving or fixed)? */
static int point_on_any_pin(double x, double y)
{
  return point_on_fixed_pin(x, y) || point_on_moving_pin(x, y);
}

/* does any wire other than `self` touch (x,y) (endpoint OR mid-span)? */
static int point_on_other_wire(double x, double y, int self)
{
  int m;
  for(m = 0; m < xctx->wires; m++) {
    if(m == self) continue;
    if(touch(xctx->wire[m].x1, xctx->wire[m].y1, xctx->wire[m].x2, xctx->wire[m].y2, x, y))
      return 1;
  }
  return 0;
}

/* does any wire other than `self` that touches (x,y) carry net name `lab`? Used to
 * confirm the moved pin STAYS on the stub's net once the stub is dropped -- the
 * connectivity-preserving condition for removing a named stub (issue 0040). Compares
 * the `lab` prop token, which prepare_netlist_structs() has baked with the wire's
 * derived net name; `lab` is the caller's own COPY of the stub's token (get_tok_value
 * returns a shared buffer the loop below reuses). */
static int other_wire_same_lab(double x, double y, int self, const char *lab)
{
  int m;
  for(m = 0; m < xctx->wires; m++) {
    if(m == self) continue;
    if(!touch(xctx->wire[m].x1, xctx->wire[m].y1, xctx->wire[m].x2, xctx->wire[m].y2, x, y)) continue;
    if(!strcmp(lab, get_tok_value(xctx->wire[m].prop_ptr, "lab", 0))) return 1;
  }
  return 0;
}

/* predicate for wire_delete_compact(): delete wires flagged in the arg array */
static int wire_doomed_flag(int n, void *arg) { return ((unsigned short *)arg)[n]; }

/* was (x,y) an endpoint of a wire this stretch move grabbed? (coordinate snapshot
 * taken in select_attached_nets before the commit re-creates the wires) */
static int coord_was_grabbed(double x, double y)
{
  int k;
  for(k = 0; k < xctx->stretch_grabbed_n; k++)
    if(xctx->stretch_grabbed_xy[2*k] == x && xctx->stretch_grabbed_xy[2*k+1] == y) return 1;
  return 0;
}

/* Move-scoped orphan removal (wire-editing Phase 5, Issue D3 -> R12, TC9). A stretch
 * move of a component can leave a redundant dangling stub hanging off the moved pin:
 * a wire with exactly ONE endpoint free (on no pin and no other wire) whose other
 * endpoint sits on the MOVED component's pin while that pin is ALREADY served by
 * another wire. Such a stub carries no connection of its own and can be dropped
 * without changing connectivity (the bad2 residue: a vertical tail off pin M that
 * the horizontal rail already connects). Scoped tightly so it never over-reaches:
 *   - the FREE endpoint must match an endpoint of a wire THIS move grabbed (the
 *     coordinate snapshot from select_attached_nets), so a pre-existing wire the
 *     moved pin merely landed on -- a distinct net -- is never deleted (TC11). We
 *     scope by captured geometry, not the live wire id/sel bits, because the
 *     kissing/commit pipeline re-creates the wires (re-minting ids, clearing sel)
 *     before move END;
 *   - the kept (non-free) endpoint must be on a MOVING instance pin, so only stubs
 *     at the moved pin are candidates (stubs on fixed pins are untouched);
 *   - that pin must ALSO be touched by another wire, so removal never disconnects a
 *     pin the stub alone reached (R16 no accidental break);
 *   - a wire with both ends free, or both ends connected, is left alone.
 * Gated on stretch_select and run after trim_wires() so it sees merged/deduped
 * geometry (else an overlapping colinear pair would look like a stub-on-a-wire). */
static void remove_move_orphan_wires(void)
{
  int i, removed = 0;
  unsigned short *doomed = NULL;
  if(xctx->wires == 0) return;
  my_realloc(_ALLOC_ID_, &doomed, xctx->wires * sizeof(unsigned short));
  memset(doomed, 0, xctx->wires * sizeof(unsigned short));
  for(i = 0; i < xctx->wires; i++) {
    int free1, free2;
    double ax, ay, bx, by, fx, fy, kx, ky;
    ax = xctx->wire[i].x1; ay = xctx->wire[i].y1;
    bx = xctx->wire[i].x2; by = xctx->wire[i].y2;
    free1 = !point_on_any_pin(ax, ay) && !point_on_other_wire(ax, ay, i);
    free2 = !point_on_any_pin(bx, by) && !point_on_other_wire(bx, by, i);
    if(free1 == free2) continue;                  /* need exactly one free (dangling) end */
    if(free1) { fx = ax; fy = ay; kx = bx; ky = by; }   /* free / kept endpoints */
    else      { fx = bx; fy = by; kx = ax; ky = ay; }
    /* the free end must descend from a wire THIS move grabbed -- so a pre-existing
     * wire the moved pin merely landed on (TC11) is never deleted */
    if(!coord_was_grabbed(fx, fy)) continue;
    /* kept end must be on a MOVED pin (this move produced/dragged the stub there) ... */
    if(!point_on_moving_pin(kx, ky)) continue;
    /* ... and that pin must be redundantly served by another wire, else the stub is
     * the sole link to the pin and must stay */
    if(!point_on_other_wire(kx, ky, i)) continue;
    /* A named stub is dropped only when the moved pin STAYS on that same net via another
     * wire; otherwise deleting it would silently rename/lose the node (issue 0040). Compare
     * the net name against the serving wires -- NOT merely test lab non-empty:
     * prepare_netlist_structs() bakes the derived net name into EVERY named-net wire's
     * prop_ptr lab=, so a non-empty test wrongly protected ordinary same-net stubs (it
     * broke the redundant-stub cleanup, TC9). An anonymous stub (empty lab) stays removable
     * on the geometric point_on_other_wire redundancy above, as before. */
    {
      char *stublab = NULL;
      int keep;
      my_strdup(_ALLOC_ID_, &stublab, get_tok_value(xctx->wire[i].prop_ptr, "lab", 0));
      keep = (stublab && stublab[0] && !other_wire_same_lab(kx, ky, i, stublab));
      my_free(_ALLOC_ID_, &stublab);
      if(keep) continue;
    }
    doomed[i] = 1;
    removed++;
  }
  if(removed) {
    wire_delete_compact(wire_doomed_flag, doomed);
    xctx->prep_hash_wires = 0;
    xctx->prep_net_structs = 0;
    xctx->prep_hi_structs = 0;
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
    /* the trim is otherwise invisible -- tell the user a redundant wire was auto-removed
     * so a post-move connectivity change is never silent (issue 0040) */
    if(has_x) {
      char msg[80];
      my_snprintf(msg, S(msg), "auto-removed %d redundant wire%s after move",
                  removed, removed == 1 ? "" : "s");
      tclvareval("if {[info procs ciw_echo] ne {}} {ciw_echo {", msg, "}}", NULL);
    }
  }
  my_free(_ALLOC_ID_, &doomed);
}

/* Exit-stub preservation (wire-editing Phase 6, Issue E -> R13, TC10; nice_drag_rerouting
 * Phase 3 §8). The "dream": after a stretch move, a short stub leaves each moved pin along
 * the pin's OUTWARD NORMAL (its natural lead direction) before the route's first bend, so the
 * wire physically exits the pin the way the symbol draws its lead rather than turning
 * immediately. A uniform, symbol-driven rule (the most predictable one -- Issue E).
 *
 * For each MOVING (selected) instance pin carrying exactly one attached wire (the
 * route's first leg):
 *   - the pin's outward normal comes from get_pin_escape_normal() (nice_drag_rerouting §6:
 *     nearest body edge; e.g. res.sym pin M sits at the top edge so it exits +y). This
 *     replaced the earlier crude centroid dominant-axis heuristic; the two agree on
 *     symmetric symbols and the getter is better on asymmetric/corner pins.
 *   - if the first leg already runs ALONG that normal (a straight exit) leave it: a
 *     colinear stub would just be merged back by trim_wires, and a straight exit can't
 *     cross the symbol body, so no stub is needed;
 *   - if the first leg runs PERPENDICULAR to the normal (it bends right at the pin),
 *     SLIDE that leg one minor grid out along the normal and fill the gap at the pin
 *     with the short stub. The leg's far endpoint is dragged the same one grid so the
 *     leg stays axis-aligned, and every wire endpoint coincident with that far end is
 *     dragged too, so the connected riser/corner follows -- the route stays Manhattan
 *     and electrically identical (same net, still connected: G1/R16, netlist unchanged).
 *
 * Guards mirror compute_wire_slide: never pull a leg's far end off a FIXED pin (would
 * disconnect it); only when the far end meets another wire (a real corner/route, not a
 * lone dangling stub). Stub length = one minor grid (cadsnap) -- the grid the route
 * snaps to (the fixtures pin cadsnap=10; documented constant).
 *
 * Runs at move END AFTER trim_wires()/remove_move_orphan_wires() so the cleanup never
 * eats the freshly inserted stub (and the perpendicular bend just past it keeps it from
 * looking like a colinear degree-2 merge candidate anyway). Gated on wire_exit_stub
 * (default OFF): the biggest behavior change in the plan, shipped dark. */
/* Stored wires MUST be coordinate-ordered (x1<x2, or x1==x2 && y1<y2). touch() (clip.c) --
 * used by the netlister's name_attached_inst_to_net() to bind an instance pin to the wire that
 * reaches it -- documents this as its precondition ("works if segments are given left to
 * right") and returns 0 on an unordered wire. An exit stub is stored pin->tip, so a -x/-y
 * escape normal (tip below/left of the pin) yields an UNORDERED wire whose touch() then fails,
 * silently dropping the pin onto a fresh #net (the Phase-3 disconnect: a +y stub was ordered
 * by luck and bound, a -y stub was not). Normalize every wire this function rewrites. */
static void order_wire_coords(int n)
{
  xWire *w = &xctx->wire[n];
  if(w->x1 > w->x2 || (w->x1 == w->x2 && w->y1 > w->y2)) {
    double t;
    t = w->x1; w->x1 = w->x2; w->x2 = t;
    t = w->y1; w->y1 = w->y2; w->y2 = t;
  }
}

/* issue 0134: does segment (ax,ay)-(bx,by) touch a stationary wire whose net label DIFFERS from
 * mylab (a caller-owned COPY -- get_tok_value shares a buffer)? The documented no-short gap in
 * insert_exit_stubs: sliding an exit leg one grid can land it on a neighbour bus one grid away
 * (after_38 REF's y=-140 backbone slid north onto LED's y=-150 bus). excl is the leg being slid. */
static int fluid_seg_touches_foreign_lab(double ax, double ay, double bx, double by,
                                         const char *mylab, int excl)
{
  int m;
  /* touch() (clip.c) requires its FIRST segment ordered left-to-right / bottom-to-top, else the two
   * "does the foreign wire's ENDPOINT lie on MY span" probes silently return 0. Callers pass this segment
   * pin->tip, REVERSED for a -x/-y escape normal (0135 D2's multi-grid stub/leg span an interior a foreign
   * endpoint can land on). Order it here so all four probes are valid (stored wires are already ordered).
   * Review wf_ae8e4446; no test outcome changes (verified) -- also hardens the 0134 single-grid slide. */
  if(ax > bx || (ax == bx && ay > by)) { double t; t = ax; ax = bx; bx = t; t = ay; ay = by; by = t; }
  for(m = 0; m < xctx->wires; m++) {
    xWire *w;
    if(m == excl) continue;
    w = &xctx->wire[m];
    if(!(touch(ax, ay, bx, by, w->x1, w->y1) || touch(ax, ay, bx, by, w->x2, w->y2) ||
         touch(w->x1, w->y1, w->x2, w->y2, ax, ay) || touch(w->x1, w->y1, w->x2, w->y2, bx, by)))
      continue;
    if(strcmp(mylab ? mylab : "", get_tok_value(w->prop_ptr, "lab", 0))) return 1;
  }
  return 0;
}

static void insert_exit_stubs(void)
{
  int inst, r, rects, n, m;
  double grid = tclgetdoublevar("cadsnap");
  int nwires0 = xctx->wires;   /* snapshot: stubs stored below (index >= nwires0) must NOT re-enter
                                * the pin/corner scans of later pins/instances (issue 0047) */
  if(grid <= 0.0) grid = 1.0;
  for(inst = 0; inst < xctx->instances; inst++) {
    const char *itype;
    if(!xctx->inst[inst].sel) continue;        /* only MOVING instances */
    if(xctx->inst[inst].ptr < 0) continue;
    itype = xctx->sym[xctx->inst[inst].ptr].type;
    if(itype && !strcmp(itype, "label")) continue;  /* net labels have no body/escape (§2) */
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; r++) {
      double px, py, nx, ny, sx, sy, fx, fy, nfx, nfy;
      int wfound = -1, endsel = 0, cnt = 0, has_corner = 0;
      get_inst_pin_coord(inst, r, &px, &py);
      /* outward escape normal (nice_drag_rerouting §6, geometry nearest-edge -- replaces the
       * old crude centroid dominant-axis heuristic; agrees with it on symmetric symbols like
       * res, better on asymmetric/corner pins). */
      get_pin_escape_normal(inst, r, &nx, &ny);
      if(nx == 0.0 && ny == 0.0) continue;
      /* exactly one wire endpoint exactly on the pin = the route's first leg */
      for(n = 0; n < nwires0; n++) {
        if(xctx->wire[n].x1 == px && xctx->wire[n].y1 == py)      { cnt++; wfound = n; endsel = 1; }
        else if(xctx->wire[n].x2 == px && xctx->wire[n].y2 == py) { cnt++; wfound = n; endsel = 2; }
      }
      if(cnt != 1) continue;
      n = wfound;
      if(endsel == 1) { fx = xctx->wire[n].x2; fy = xctx->wire[n].y2; }
      else            { fx = xctx->wire[n].x1; fy = xctx->wire[n].y1; }
      /* need the first leg PERPENDICULAR to the normal: vertical normal -> horizontal
       * leg, horizontal normal -> vertical leg. A leg colinear with the normal (straight
       * exit) or diagonal is left alone. */
      if(ny != 0.0 && xctx->wire[n].y1 != xctx->wire[n].y2) continue; /* vert normal needs horiz leg */
      if(nx != 0.0 && xctx->wire[n].x1 != xctx->wire[n].x2) continue; /* horiz normal needs vert leg */
      /* never pull the far end off a fixed (non-moving) pin -> would disconnect it */
      if(point_on_fixed_pin(fx, fy)) continue;
      /* require a real corner/route at the far end (another wire endpoint there) */
      for(m = 0; m < nwires0; m++) {
        if(m == n) continue;
        if((xctx->wire[m].x1 == fx && xctx->wire[m].y1 == fy) ||
           (xctx->wire[m].x2 == fx && xctx->wire[m].y2 == fy)) { has_corner = 1; break; }
      }
      if(!has_corner) continue;

      /* slide the pin-incident perpendicular leg out along the escape normal and fill the pin gap with
       * a short exit stub. DISTANCE: normally ONE grid (a cosmetic lead stub). Two per-distance guards
       * (both gated fluid_editing so the legacy wire_exit_stub path is byte-identical):
       *
       * (0132 after_34) body-cross DECLINE: get_pin_escape_normal used to read the TEXT-INFLATED
       *   inst.x1..y2 nearest-edge and mis-pick an INWARD normal for a near-corner pin, sliding a clean
       *   over-the-top feed back THROUGH the moved instance's OWN pin-inclusive body. If the stub or the
       *   slid leg threads the body (PIN-INCLUSIVE box, escape-normal exempt), that distance is rejected.
       *   (Post-0134 get_pin_escape_normal returns the true LEAD normal in fluid mode, so a true outward
       *   normal slides AWAY from the body and is exempt; ordinary device feeds are untouched.)
       * (0134 after_38) foreign-short DECLINE: an exit-leg slide can shift one grid onto a neighbour bus
       *   one grid away (REF's backbone sliding north onto LED's bus), re-shorting two nets a de-shorter
       *   just separated. If the stub or slid leg lands on a DIFFERENT net's copper, that distance is
       *   rejected.
       *
       * issue 0135 D2 -- OUTWARD SEARCH: when the CURRENT feed leg already grazes/crosses this instance's
       * OWN pin-inclusive body, one grid may not clear the body OR may land the slid leg on a neighbour
       * bus (after_39 REF: a moved north-input pin whose translated feed runs along the body top edge; the
       * two-leg decomposition PURE-TRANSLATES the whole-selected feed so the elbow/P6 layer never
       * re-orients it, and the single-grid slide to y=-130 lands on LED's row). Search outward along the
       * normal for the NEAREST distance whose slid leg passes BOTH guards (clears the body AND shorts no
       * foreign net) and slide there. A grazing feed is already wrong, so any body-clear short-free row is
       * a strict improvement (P5 body-clearance dominates P6 min-bend); if none is found within the cap the
       * feed is left exactly as-is (never worse -- the D1 body-shove decline is the safety net). A
       * NON-grazing leg keeps dmax==1 => the historical single-grid behaviour byte-identical. Instances are
       * committed to POST-move coords here (ELEMENT loop ran; inst still SELECTED), so no delta shift is
       * needed. The search adds a third per-distance guard (stationary-body cross, grazing-only) so the
       * longer slid backbone cannot walk through ANOTHER device (P5).
       *
       * WHY GEOMETRIC GUARDS, NO PARTITION SNAPSHOT: the slide never DISCONNECTS by construction -- the pin
       * gap is filled by the stub and the far corner + every wire on it are dragged together, so the net
       * stays whole; the only failure mode is a SHORT onto foreign copper, exactly what the foreign-lab
       * guard rejects (identical mechanism to the shipped 0134 single-grid slide). A mem_snapshot verify is
       * the wrong tool here: mem_restore_slot() unselect_all()s, which would strip the inst .sel the pin
       * loop iterates on and silently skip every later pin. The residual gap (a short onto an UNLABELED
       * distinct net, both lab="") is pre-existing/shared with 0134 and is backstopped at END by the B3
       * fluid_check_move_invariants rollback-or-refuse (fluid_enforce_invariants) and the D1 shove-decline.
       * DEFERRED (adversarial review wf_ae8e4446, CONFIRMED minor): the neighbour-drag below (lines ~2144-2148)
       * re-routes every OTHER wire at the corner to the far end WITHOUT re-checking its swept span; the
       * outward search widens that (grazing + up to `dmax` grids), so a same-net corner backbone could sweep
       * onto foreign copper unseen. A guard that validated the neighbours' post-drag spans over-fired on the
       * legitimate SAME-NET T-tap CARRY this pass exists to perform (test_wireedit_31) -- distinguishing a
       * carried same-net tap from a swept foreign backbone needs real net resolution, which this geometric P3
       * pass deliberately avoids; the realistic case is B3-backstopped, so it is left as a documented limit.
       * WIRING.md §11.9b / §11 item 14 / §11.9a. KNOWN LIMITATION (adversarial review wf_ea9a847a):
       * fluid_seg_crosses_sel_body's escape exemption uses the box-CENTRE dominant axis (aspect-ratio-blind)
       * -- can mis-judge a genuinely-outward slide on a WIDE/TALL near-corner pin and decline a legit stub;
       * never worse (the kept route is connected, Manhattan and body-clear). Same approximation as 0130/0133. */
      {
        int fe = tclgetboolvar("fluid_editing");
        int graze = fe && fluid_seg_crosses_sel_body(px, py, fx, fy);   /* D2 trigger: feed threads own body */
        int dmax = graze ? 6 : 1, d, found = 0;
        for(d = 1; d <= dmax && !found; d++) {
          double tsx = px + d * grid * nx, tsy = py + d * grid * ny;    /* stub tip = leg's new pin end */
          double tfx = fx + d * grid * nx, tfy = fy + d * grid * ny;    /* leg's new far (corner) end   */
          /* (0132) still THREADS the moved instance's own PIN-INCLUSIVE body: not cleared yet -- keep
           * searching outward (the point of the D2 walk is to get the feed off its own body edge). */
          if(fe && (fluid_seg_crosses_sel_body(px, py, tsx, tsy) ||
                    fluid_seg_crosses_sel_body(tsx, tsy, tfx, tfy))) continue;
          /* (0135) a STATIONARY device blocks the outward direction: the exit stub is a LOCAL beautifier,
           * not a global router -- NEVER detour a feed past another device (that is the reroute/
           * manhattanize layers' job). STOP the search and DECLINE (leave the feed as-is, never worse).
           * This is the guard that keeps the D2 walk from flinging R18's grazing P feed 8 grids north past
           * C12 in the 0090 multi-gesture staircase (which then cascades). Grazing-only, so the cosmetic
           * single-grid slide stays byte-identical. */
          if(fe && graze && (fluid_seg_crosses_stationary_body(px, py, tsx, tsy) ||
                             fluid_seg_crosses_stationary_body(tsx, tsy, tfx, tfy))) break;
          if(fe) {                                            /* (0134) shorts a neighbour bus at this row */
            char *nlab = NULL;
            int foreign;
            my_strdup(_ALLOC_ID_, &nlab, get_tok_value(xctx->wire[n].prop_ptr, "lab", 0));
            foreign = fluid_seg_touches_foreign_lab(px, py, tsx, tsy, nlab, n) ||
                      fluid_seg_touches_foreign_lab(tsx, tsy, tfx, tfy, nlab, n);
            my_free(_ALLOC_ID_, &nlab);
            if(foreign) continue;                             /* try further out (a farther row may be free) */
          }
          sx = tsx; sy = tsy; nfx = tfx; nfy = tfy; found = 1; /* first body-clear, device-clear, short-free row */
        }
        if(!found) {
          fltrace("FLTRACE exitstub: DECLINE slide inst=%d pin=%d n=(%g,%g) graze=%d dmax=%d -- no clean row\n",
                  inst, r, nx, ny, graze, dmax);
          continue;
        }
        if(graze)
          fltrace("FLTRACE exitstub: D2 outward slide inst=%d pin=%d n=(%g,%g) -> stub=(%g,%g) far=(%g,%g)\n",
                  inst, r, nx, ny, sx, sy, nfx, nfy);
      }
      for(m = 0; m < nwires0; m++) {                /* drag every neighbour at the corner */
        if(m == n) continue;
        if(xctx->wire[m].x1 == fx && xctx->wire[m].y1 == fy) { xctx->wire[m].x1 = nfx; xctx->wire[m].y1 = nfy; order_wire_coords(m); }
        if(xctx->wire[m].x2 == fx && xctx->wire[m].y2 == fy) { xctx->wire[m].x2 = nfx; xctx->wire[m].y2 = nfy; order_wire_coords(m); }
      }
      if(endsel == 1) { xctx->wire[n].x1 = sx; xctx->wire[n].y1 = sy; xctx->wire[n].x2 = nfx; xctx->wire[n].y2 = nfy; }
      else            { xctx->wire[n].x2 = sx; xctx->wire[n].y2 = sy; xctx->wire[n].x1 = nfx; xctx->wire[n].y1 = nfy; }
      order_wire_coords(n);                          /* keep the slid leg ordered (touch() precond) */
      /* fill the gap at the pin with the short exit stub (inherits the leg's net prop); stored
       * pin->tip, so ORDER it -- a -x/-y escape normal would otherwise store it unordered and
       * touch() would fail to bind the pin (the disconnect). */
      storeobject(-1, px, py, sx, sy, WIRE, 0, 0, xctx->wire[n].prop_ptr);
      order_wire_coords(xctx->wires - 1);            /* the just-appended stub is the last wire */
    }
  }
  xctx->prep_hash_wires = 0;
  xctx->prep_net_structs = 0;
  xctx->prep_hi_structs = 0;
  xctx->need_reb_sel_arr = 1;
  set_modify(1);
}

/* issue 0134 (candidate #1): the pin's TRUE outward normal from the symbol LEAD geometry, replacing
 * the text-inflated-bbox nearest-edge PROXY below on the pins where the proxy mis-picks (asymmetric
 * symbols, corner pins, and the same pin under rotation). A symbol pin is a PINLAYER rect whose CENTRE
 * (in SYMBOL coords) is the connection tip; the pin's short connector LEAD is a LINE record with one
 * endpoint exactly at that tip (its other endpoint sits at the body edge). Outward (symbol) = tip -
 * inner_end; a direction vector, so transform it by the instance rot/flip about pivot (0,0) -- ROTATION
 * is linear, so rotating the difference == the difference of rotations, and flip correctly negates the
 * x-component. NB `dir=in|out` is ELECTRICAL only (two in-pins share an edge), never a geometric normal,
 * so it is NOT read here -- the lead segment is the geometry.
 *
 * Robustness: scan lines on ALL layers (device leads live on SYMLAYER, but ipin/opin leads on PINLAYER),
 * disambiguated by the EXACT endpoint==tip match -- a body outline / device-graphic line never ends on a
 * pin tip (the lead offsets the pin from the body). Multiple leads meeting one pin (an nmos gate has two)
 * are fine while they agree on axis; a diagonal lead or a cross-axis disagreement => ambiguous => return 0
 * (caller keeps the nearest-edge proxy). Strictly MORE accurate than the proxy on asymmetric/corner pins
 * (solar_ctl TRIANG under rot1: symbol +x lead -> world +y/south, where the proxy TIES OUT to Left and
 * staircases); on symmetric symbols (res/capa: pin on the body axis, lead == nearest edge) the two agree,
 * so the result is unchanged there. Returns 1 with a unit world axis in (*nx,*ny), else 0. */
static int get_pin_lead_normal(int i, int r, double *nx, double *ny)
{
  xSymbol *sym;
  xRect *rct;
  int layer, k, rects, found = 0, sx = 0, sy = 0;
  double pcx, pcy, rdx, rdy;
  short rot, flip;
  *nx = 0.0; *ny = 0.0;
  if(i < 0 || i >= xctx->instances || xctx->inst[i].ptr < 0) return 0;
  sym = xctx->inst[i].ptr + xctx->sym;
  rects = sym->rects[PINLAYER];
  if(r < 0 || r >= rects) return 0;
  rct = sym->rect[PINLAYER];
  pcx = (rct[r].x1 + rct[r].x2) / 2.0;             /* pin tip in SYMBOL coords */
  pcy = (rct[r].y1 + rct[r].y2) / 2.0;
  for(layer = 0; layer < cadlayers; layer++) {
    for(k = 0; k < sym->lines[layer]; k++) {
      xLine *ln = &sym->line[layer][k];
      double ox, oy, dx, dy;
      int csx, csy;
      if(ln->x1 == pcx && ln->y1 == pcy)      { ox = ln->x2; oy = ln->y2; }
      else if(ln->x2 == pcx && ln->y2 == pcy) { ox = ln->x1; oy = ln->y1; }
      else continue;
      dx = pcx - ox; dy = pcy - oy;                /* outward = tip - inner end */
      if(dx != 0.0 && dy != 0.0) continue;         /* diagonal lead: not an axis normal */
      if(dx == 0.0 && dy == 0.0) continue;         /* zero-length: ignore */
      csx = dx > 0.0 ? 1 : (dx < 0.0 ? -1 : 0);
      csy = dy > 0.0 ? 1 : (dy < 0.0 ? -1 : 0);
      if(!found) { sx = csx; sy = csy; found = 1; }
      else if(csx != sx || csy != sy) return 0;    /* leads disagree on axis: ambiguous */
    }
  }
  if(!found) return 0;
  rot = xctx->inst[i].rot; flip = xctx->inst[i].flip;
  ROTATION(rot, flip, 0.0, 0.0, (double)sx, (double)sy, rdx, rdy);   /* rotate the DIRECTION vector */
  *nx = rdx > 0.0 ? 1.0 : (rdx < 0.0 ? -1.0 : 0.0);
  *ny = rdy > 0.0 ? 1.0 : (rdy < 0.0 ? -1.0 : 0.0);
  return (*nx != 0.0) ^ (*ny != 0.0);              /* exactly one axis, else treat as unresolved */
}

/* Phase 2 (doc/claude/specs/nice_drag_rerouting.md §6; geometry-only per the resolved §10.1):
 * outward escape normal of pin r of instance i -- the axis direction a wire should leave the
 * pin, perpendicular to the pin's edge. PRIMARY source (issue 0134, fluid mode): the symbol LEAD
 * geometry (get_pin_lead_normal above) -- the true outward axis, correct on asymmetric/corner pins.
 * FALLBACK (and the legacy wire_exit_stub path with fluid_editing off, kept byte-identical): the
 * nearest-edge PROXY -- the pin's WORLD coordinate vs the instance's WORLD bounding box (already
 * rotated/translated), ties broken L,R,B,T, identical to the Tcl reference predicates.tcl
 * pin_escape_normal which this ports. The proxy is crude on ambiguous pins (corner, near-centre/bulk,
 * text-skewed bbox); the lead source removes that crudeness where a clean lead resolves. Returns a
 * unit axis vector in (*nx,*ny), or (0,0) if invalid. */
void get_pin_escape_normal(int i, int r, double *nx, double *ny)
{
  double px, py, x1, y1, x2, y2, dl, dr, db, dt, m, t;
  *nx = 0.0; *ny = 0.0;
  if(i < 0 || i >= xctx->instances || xctx->inst[i].ptr < 0) return;
  /* issue 0134: prefer the TRUE lead-geometry normal in fluid mode (accurate on asymmetric/corner
   * pins where the nearest-edge proxy below ties out -- e.g. solar_ctl TRIANG under rot1). Gated
   * fluid_editing so the legacy wire_exit_stub path (fluid off) stays byte-identical to the proxy,
   * and (0,0)/ambiguous leads fall through to the proxy unchanged. */
  if(tclgetboolvar("fluid_editing") && get_pin_lead_normal(i, r, nx, ny)) return;
  get_inst_pin_coord(i, r, &px, &py);          /* pin world coord */
  x1 = xctx->inst[i].x1; y1 = xctx->inst[i].y1;    /* instance world bbox */
  x2 = xctx->inst[i].x2; y2 = xctx->inst[i].y2;
  if(x1 > x2) { t = x1; x1 = x2; x2 = t; }
  if(y1 > y2) { t = y1; y1 = y2; y2 = t; }
  dl = fabs(px - x1); dr = fabs(px - x2);
  db = fabs(py - y1); dt = fabs(py - y2);
  m = dl;
  if(dr < m) m = dr;
  if(db < m) m = db;
  if(dt < m) m = dt;
  if(m == dl)      { *nx = -1.0; *ny =  0.0; } /* nearest edge -> outward normal (tie: L,R,B,T) */
  else if(m == dr) { *nx =  1.0; *ny =  0.0; }
  else if(m == db) { *nx =  0.0; *ny = -1.0; }
  else             { *nx =  0.0; *ny =  1.0; }
}

/* Fluid-editing Phase 1 (doc/claude/specs/nice_drag_rerouting.md §8): runtime invariant guards
 * at move END. Non-fatal, log-only, gated on fluid_editing (default off => never run => every
 * move byte-identical). Bring the Phase-0 golden predicates P1/P2 into the interactive runtime
 * so a fast-path reroute that shorts/merges/disconnects a net is caught the moment it happens.
 * Two complementary checks, because a net-label's own pin node echoes its intended name and so
 * cannot see a merge, while the wire-level resolved names cannot cheaply see a disconnect:
 *   - no-short (P2): every net label still sits on a wire whose resolved node equals the
 *     label's own net (uses WIRE nodes; the merge the echo hides -- F5.P2).
 *   - connectivity (P1): the partition of instance pins into nets is unchanged across the move
 *     (uses instance pin nodes; catches a pin torn off its net -- a disconnect).
 *
 * The partition compare uses a CANONICAL first-seen relabeling: walking instance pins in a
 * fixed order, each new net name gets the next integer id. Ids are therefore keyed to pin
 * POSITION, not net name, so a pure #net rename (same groups, different auto-name) yields an
 * identical id vector (no false positive), while a real regrouping shifts it. The per-pin diff
 * COUNT is approximate (one real change can cascade later ids), but "any difference" is an
 * exact detector of a partition change. Snapshot taken at move START (pre-motion geometry). */

static int  fluid_move_failsafes = 0; /* B4: per-gesture count of fluid helpers that fail-safe no-op'd */
/* B4 (hardening sprint Track B): a fluid healer/placement pass that fail-safe bails because its START
 * snapshot is missing or the instance set changed mid-gesture has SILENTLY degraded to naive routing --
 * "engine gave up" then looks identical to "clean". Wrap each such bail's condition so the count
 * surfaces (published to fluid_last_move_failsafes at END, fltraced). Byte-identical: only counts the
 * bail, never alters the condition or the control flow. */
static int fluid_failsafe(int bail) { if(bail) ++fluid_move_failsafes; return bail; }
static int fluid_loop_partition(unsigned short *doomed, int *rep); /* defined below (0088 block) */

/* order a wire's endpoints canonically ((x1,y1) <= (x2,y2), x-major) so two records of the SAME span
 * (possibly stored reversed) normalize identically -- used by the 0088 START snapshot + novelty test. */
static void fluid_wire_norm_pts(double x1, double y1, double x2, double y2,
                                double *ax, double *ay, double *bx, double *by)
{
  if(x1 < x2 || (x1 == x2 && y1 <= y2)) { *ax = x1; *ay = y1; *bx = x2; *by = y2; }
  else                                  { *ax = x2; *ay = y2; *bx = x1; *by = y1; }
}
static void fluid_discard_snapshot(void);

/* Diagnostic trace of the fluid stretch/reroute path (issue 0083 debugging aid, requested by the user
 * to make the exact path through move_objects/the reroute layers visible for a REAL interactive drag --
 * WSLg headless-gesture repro is unusable, so the user launches with FLUID_TRACE=1, does the gesture,
 * and shares the captured stderr). OFF by default (env unset) => single cached int compare per trace
 * point, no output, no behaviour change. To use: `FLUID_TRACE=1 src/xschem ... 2>/tmp/fltrace.log`,
 * then `grep FLTRACE /tmp/fltrace.log`. Trace lines go to errfp (stderr) via dbg(0,...). */
/* FLUID_TRACE state + open file, promoted to file scope so the Help>Debug menu
 * (`xschem fluid_trace start|stop`) can rotate the file and toggle tracing at RUNTIME, not only
 * from the FLUID_TRACE env var at launch. fltrace_enabled: -1 = not yet consulted (lazy env read),
 * 0 = off, 1 = on. */
static FILE *fltrace_fp = NULL;
static int   fltrace_enabled = -1;
static char  fltrace_curpath[1024] = "";

int fluid_trace_on(void)
{
  if(fltrace_enabled < 0) {
    const char *e = getenv("FLUID_TRACE");
    fltrace_enabled = (e && *e && *e != '0') ? 1 : 0;
  }
  return fltrace_enabled;
}
/* Write a trace line to a DEDICATED file -- NOT stderr/dbg: a windowed (GUI) launch detaches and
 * freopen()s stderr to /dev/null (main.c), and --logdir points the action log elsewhere, so a shell
 * `2>file` capture is EMPTY for a real interactive drag. The env-launch file is $FLUID_TRACE when that
 * looks like a path (contains '/'), else /tmp/xschem_fltrace.log; a runtime start() overrides it.
 * Opened once (truncated), flushed per line so a killed session still has the trace. OFF => returns
 * immediately, nothing opened/written. */
void fltrace(const char *fmt, ...)
{
  va_list ap;
  if(!fluid_trace_on()) return;
  if(!fltrace_fp) {
    const char *e = getenv("FLUID_TRACE");
    const char *path = (e && strchr(e, '/')) ? e : "/tmp/xschem_fltrace.log";
    fltrace_fp = fopen(path, "w");
    if(fltrace_fp) my_strncpy(fltrace_curpath, path, S(fltrace_curpath));
    else { fltrace_enabled = 0; return; }   /* open failed: disable so we don't retry every line */
  }
  va_start(ap, fmt);
  vfprintf(fltrace_fp, fmt, ap);
  va_end(ap);
  fflush(fltrace_fp);
}
/* Runtime FLUID_TRACE control for the Help>Debug menu (issue 0123). start(path): rotate to a fresh
 * (truncated) file and enable tracing -- returns the open path, or "" on open failure. stop():
 * flush+close and disable -- returns the last path (for a "wrote X" message). The caller (Tcl) picks
 * a PID-named path, so the C side stays portable. */
const char *fltrace_runtime_start(const char *path)
{
  if(fltrace_fp) { fflush(fltrace_fp); fclose(fltrace_fp); fltrace_fp = NULL; }
  if(!path || !path[0]) path = "/tmp/xschem_fltrace.log";
  fltrace_fp = fopen(path, "w");
  if(fltrace_fp) { my_strncpy(fltrace_curpath, path, S(fltrace_curpath)); fltrace_enabled = 1; }
  else { fltrace_curpath[0] = '\0'; fltrace_enabled = 0; }
  return fltrace_curpath;
}
const char *fltrace_runtime_stop(void)
{
  if(fltrace_fp) { fflush(fltrace_fp); fclose(fltrace_fp); fltrace_fp = NULL; }
  fltrace_enabled = 0;
  return fltrace_curpath;
}
/* Compact ui_state bitmask -> static string, for FLUID_TRACE forensics (issue 0123 arm desync: the
 * STARTMOVE-vs-START_SYMPIN split that mis-routes a placement click into a tip-grab). */
const char *fltrace_uistate(unsigned int s)
{
  static char b[256];
  b[0] = '\0';
  if(s & STARTWIRE)    strcat(b, "STARTWIRE|");
  if(s & STARTSELECT)  strcat(b, "STARTSELECT|");
  if(s & SELECTION)    strcat(b, "SELECTION|");
  if(s & STARTMOVE)    strcat(b, "STARTMOVE|");
  if(s & STARTCOPY)    strcat(b, "STARTCOPY|");
  if(s & STARTMERGE)   strcat(b, "STARTMERGE|");
  if(s & STARTZOOM)    strcat(b, "STARTZOOM|");
  if(s & STARTPAN)     strcat(b, "STARTPAN|");
  if(s & PLACE_TEXT)   strcat(b, "PLACE_TEXT|");
  if(s & PLACE_SYMBOL) strcat(b, "PLACE_SYMBOL|");
  if(s & START_SYMPIN) strcat(b, "START_SYMPIN|");
  if(!b[0]) return "0";
  b[strlen(b) - 1] = '\0';   /* drop the trailing '|' */
  return b;
}

/* Phase IV P6 (min-bend): outward escape normal of the MOVING, non-label instance pin coincident
 * with (x,y). Same pin walk + tolerance (point_near_pin) as insert_exit_stubs, and reads the SAME
 * get_pin_escape_normal the P3 stub layer uses, so P6 and P3 can never disagree about "along the
 * normal" (even when the normal is a crude nearest-edge axis on a bulk/corner pin). Returns 1 with a
 * clean single-axis (*nx,*ny); 0 if (x,y) is not on a moving pin or the normal is zero/ambiguous. */
static int fluid_moving_pin_normal(double x, double y, double *nx, double *ny)
{
  int inst, r, rects;
  double px, py;
  *nx = 0.0; *ny = 0.0;
  for(inst = 0; inst < xctx->instances; inst++) {
    const char *itype;
    if(!xctx->inst[inst].sel || xctx->inst[inst].ptr < 0) continue;   /* only MOVING instances */
    itype = xctx->sym[xctx->inst[inst].ptr].type;
    if(itype && !strcmp(itype, "label")) continue;                    /* labels have no body (§2) */
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; r++) {
      get_inst_pin_coord(inst, r, &px, &py);
      /* EXACT match, not point_near_pin's cadsnap/2 tolerance: insert_exit_stubs binds the pin-leg by
       * exact endpoint == (move.c:1655), so P6 must use the same equality or a NON-incident neighbour
       * pin within tolerance (dense/corner symbol, declared earlier) would supply the wrong normal and
       * P6 and P3 would disagree -- biasing the wrong axis (adversarial review wf_6e97238b, pin-binding
       * finding). On grid-aligned designs the endpoint sits exactly on its pin; a sub-grid-near endpoint
       * simply declines (P6 is a bonus), which is safe. */
      if(px == x && py == y) {
        get_pin_escape_normal(inst, r, nx, ny);
        return (*nx != 0.0) ^ (*ny != 0.0);          /* exactly one axis nonzero, else decline */
      }
    }
  }
  return 0;
}

/* Phase IV P6 length veto: is there a STATIONARY wire incident at the anchor (fx,fy) running ALONG
 * the escape-normal axis? If so, the baseline PERPENDICULAR arrival leg is colinear with it and trim
 * absorbs that leg (no corner), so biasing to the along-normal orientation would only ADD length
 * (the cont=down/cont=up loser in the empirical sweep). Decline in that case. The follow wire itself
 * (always .sel here) is skipped by the .sel filter, so it is never mistaken for a continuation. */
static int fluid_anchor_absorbs_along_normal(double fx, double fy, double nx, double ny)
{
  int m;
  for(m = 0; m < xctx->wires; m++) {
    int at, vert, horiz;
    if(xctx->wire[m].sel) continue;                  /* only stationary (non-moving) continuations */
    at = (xctx->wire[m].x1 == fx && xctx->wire[m].y1 == fy) ||
         (xctx->wire[m].x2 == fx && xctx->wire[m].y2 == fy);
    if(!at) continue;
    vert  = (xctx->wire[m].x1 == xctx->wire[m].x2) && (xctx->wire[m].y1 != xctx->wire[m].y2);
    horiz = (xctx->wire[m].y1 == xctx->wire[m].y2) && (xctx->wire[m].x1 != xctx->wire[m].x2);
    if(ny != 0.0 && vert)  return 1;                 /* vertical normal, vertical continuation */
    if(nx != 0.0 && horiz) return 1;                 /* horizontal normal, horizontal continuation */
  }
  return 0;
}

/* Phase IV P6 P5-guard (adversarial review wf_6e97238b): does the axis-aligned segment (x1,y1)-(x2,y2)
 * pass through the STRICT interior of any non-label instance body of the selected obstacle class --
 * moved=0: STATIONARY bodies (the historical guard: the moving instance's own body is excluded, so
 * the pin's own leg root is never flagged); moved=1: MOVING (selected) bodies only (issue 0111: the
 * pin-landing FAR collapse is a brand-new route choice, so unlike the legacy slides it must also
 * clear the moved device itself -- test_wireedit_48's A case drove the far-collapsed leg through the
 * dragged body). The both-P2-clear arm only proved no device SHORT (fluid_ml_blocked tests
 * two-distinct-pin straddle, not a body crossing), so a foreign device whose pins lie OFF the
 * along-normal axis has b=0 yet its body sits on the leg -- P6 would drive the straight exit through
 * it (a P5 break, and P5 > P6). Box = inst world bbox (symbol_bbox, move.c:221, the same box the
 * reroute layers use). */
static int fluid_seg_crosses_body(double x1, double y1, double x2, double y2, int moved, int notext)
{
  int i;
  for(i = 0; i < xctx->instances; i++) {
    double bx1, by1, bx2, by2, t, slo, shi;
    const char *itype;
    if(moved ? !xctx->inst[i].sel : (int)xctx->inst[i].sel) continue; /* obstacle class select */
    if(xctx->inst[i].ptr < 0) continue;
    itype = xctx->sym[xctx->inst[i].ptr].type;
    if(itype && !strcmp(itype, "label")) continue;                   /* labels have no body (§2) */
    /* notext (issue 0138): use the instance bbox WITHOUT texts (xx1..yy2, the real drawn body) instead of
     * the text-inflated world bbox (x1..y2). A wire may legally route under a device's @name text (it is
     * not copper); the min-copper escape reclaim must not decline a stub that merely grazes that text
     * (before_41 R1's 1-grid escape at y=60 sits above R1's real body but inside its text bbox). Existing
     * callers pass notext=0 and are byte-identical. */
    if(notext) { bx1 = xctx->inst[i].xx1; by1 = xctx->inst[i].yy1; bx2 = xctx->inst[i].xx2; by2 = xctx->inst[i].yy2; }
    else       { bx1 = xctx->inst[i].x1;  by1 = xctx->inst[i].y1;  bx2 = xctx->inst[i].x2;  by2 = xctx->inst[i].y2; }
    if(bx1 > bx2) { t = bx1; bx1 = bx2; bx2 = t; }
    if(by1 > by2) { t = by1; by1 = by2; by2 = t; }
    if(x1 == x2) {                                                    /* vertical segment at x1 */
      if(x1 <= bx1 || x1 >= bx2) continue;                            /* not strictly inside x-span */
      slo = y1 < y2 ? y1 : y2; shi = y1 < y2 ? y2 : y1;
      if(!(slo < by2 && shi > by1)) continue;                        /* misses the open y-interior */
    } else if(y1 == y2) {                                             /* horizontal segment at y1 */
      if(y1 <= by1 || y1 >= by2) continue;
      slo = x1 < x2 ? x1 : x2; shi = x1 < x2 ? x2 : x1;
      if(!(slo < bx2 && shi > bx1)) continue;
    } else continue;
    if(moved) {
      /* issue 0111 (mirrors predicates.tcl p5_no_body_cross, tightened per review
       * wf_bb7bb60e): a wire that leaves one of THIS instance's pins along the pin's OUTWARD
       * escape normal is its own feed leg, not a body crossing -- the world bbox is
       * text-inflated, so such a leg routinely overlaps it (after_28.sch: the far collapse's
       * extended lead run at y=-90 into R18's P pin). The outward-direction test (not a bare
       * endpoint match) keeps a pin-anchored leg extended INWARD through the drawn body
       * flagged. Stationary obstacles keep the historical no-exemption behavior. */
      int r, rects = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER], exempt = 0;
      for(r = 0; r < rects && !exempt; r++) {
        double px, py, nx, ny, fx, fy;
        get_inst_pin_coord(i, r, &px, &py);
        if(x1 == px && y1 == py)      { fx = x2; fy = y2; }
        else if(x2 == px && y2 == py) { fx = x1; fy = y1; }
        else continue;
        get_pin_escape_normal(i, r, &nx, &ny);
        if(nx * (fx - px) + ny * (fy - py) > 0.0) exempt = 1;
      }
      if(exempt) continue;
    }
    return 1;
  }
  return 0;
}

static int fluid_seg_crosses_stationary_body(double x1, double y1, double x2, double y2)
{
  return fluid_seg_crosses_body(x1, y1, x2, y2, 0, 0);
}

/* Phase IV P6 length veto (pin end; adversarial review wf_6e97238b, length finding). Complements
 * fluid_anchor_absorbs_along_normal (anchor end): decline if a STATIONARY wire lies colinear with and
 * overlaps the BASELINE perpendicular pin-leg -- the pin's ROW for a vertical normal, its COLUMN for a
 * horizontal normal, spanning from the pin toward the anchor. autotrim dedups that overlap in the
 * baseline route but NOT in the along-normal route, so biasing would only ADD copper (and saves 0
 * bends: with a wire already on the pin row, insert_exit_stubs does not staircase). px,py = moved pin;
 * fx,fy = anchor. BLIND SPOT (pre-existing, non-correctness, re-review wf_3d079dd2): a corridor wire
 * that CROSSES the pin is grabbed by connect_by_kissing as a MOVING (.sel) follow wire, so the
 * stationary-only scan below skips it and P6 may add bends+length in that narrow case (reproduces on
 * the guard-free binary too; all predicates hold). Left as a documented quality limitation. */
static int fluid_perp_pinleg_absorbs(double px, double py, double fx, double fy, double nx, double ny)
{
  int m;
  double lo, hi, wlo, whi;
  for(m = 0; m < xctx->wires; m++) {
    if(xctx->wire[m].sel) continue;                                  /* stationary wires only */
    if(ny != 0.0) {                                                  /* vertical normal: baseline leg is horizontal at y=py */
      if(xctx->wire[m].y1 != py || xctx->wire[m].y2 != py) continue; /* stationary horizontal wire on the pin row */
      lo = px < fx ? px : fx; hi = px < fx ? fx : px;
      wlo = xctx->wire[m].x1 < xctx->wire[m].x2 ? xctx->wire[m].x1 : xctx->wire[m].x2;
      whi = xctx->wire[m].x1 < xctx->wire[m].x2 ? xctx->wire[m].x2 : xctx->wire[m].x1;
    } else {                                                         /* horizontal normal: baseline leg is vertical at x=px */
      if(xctx->wire[m].x1 != px || xctx->wire[m].x2 != px) continue;
      lo = py < fy ? py : fy; hi = py < fy ? fy : py;
      wlo = xctx->wire[m].y1 < xctx->wire[m].y2 ? xctx->wire[m].y1 : xctx->wire[m].y2;
      whi = xctx->wire[m].y1 < xctx->wire[m].y2 ? xctx->wire[m].y2 : xctx->wire[m].y1;
    }
    if((lo > wlo ? lo : wlo) < (hi < whi ? hi : whi)) return 1;      /* positive-length overlap */
  }
  return 0;
}

/* Phase IV P6 (min-bend, doc/claude/specs/incremental_wire_reroute.md §8 / nice_drag_rerouting §4):
 * among the two equal-length manhattan L orientations for a fluid follow wire, return the one whose
 * pin-incident leg exits ALONG the moving pin's escape normal (a straight P3 exit), or 0 to keep the
 * caller's baseline. Called ONLY from the both-P2-clear arm of place_moved_wire, so P2 > P6 holds by
 * construction (a P2-mandated flip already dominates; a both-blocked case is left to the Layer-2
 * reroute). Pure function of (START snapshot, xctx->rx1..ry2, moving-instance geometry) => determin-
 * istic and release==stepwise. DECLINES (returns 0) when: no armed START snapshot (P2 not verifi-
 * able); the moved endpoint is not on a moving non-label pin, or its normal is ambiguous/zero; the
 * anchor is NOT strictly on the outward-normal side (an away escape is a genuine P3-mandated stub --
 * biasing inward would make insert_exit_stubs skip a leg that actually enters the body, silently
 * breaking P3/P5); or a stationary along-normal continuation at the anchor would make the route
 * LONGER (length veto). sel1 selects which endpoint moved (SELECTED1 => rx1,ry1 is the pin). */
static int fluid_p6_bias_ml(int sel1)
{
  double px, py, fx, fy, nx, ny;
  int along;
  if(!fluid_g.snap_pinnet) return 0;                   /* P2-clear must be PROVEN, not merely unqueried */
  /* If the user EXPLICITLY forces literal exit stubs (wire_exit_stub, a user-facing Options toggle,
   * default OFF and NOT set by cadence_style_rc), respect that and stand down: P6's along-normal
   * straight exit would optimize the requested stub away. The normal fluid flow (wire_exit_stub off)
   * still gets the min-bend straight exit. */
  if(tclgetboolvar("wire_exit_stub")) return 0;
  px = sel1 ? xctx->rx1 : xctx->rx2;                 /* moved (post-move) pin endpoint */
  py = sel1 ? xctx->ry1 : xctx->ry2;
  fx = sel1 ? xctx->rx2 : xctx->rx1;                 /* fixed anchor endpoint */
  fy = sel1 ? xctx->ry2 : xctx->ry1;
  /* The moving instance coords are NOT yet committed when place_moved_wire runs (inst.x0 is written
   * later, move.c:3302), so get_inst_pin_coord() still reports the PRE-move pin. The wire endpoint
   * (px,py) is already delta-applied, so match the pin at the PRE-move point (px-delta). The escape
   * normal is translation-invariant, so the pre-move normal equals the post-move one. */
  if(!fluid_moving_pin_normal(px - xctx->deltax, py - xctx->deltay, &nx, &ny)) return 0;
  along = (ny != 0.0) ? 1 : 2;                       /* ny!=0 -> vertical pin-leg (ml=1); else ml=2 */
  /* toward gate: anchor strictly on the OUTWARD-normal side of the moved pin (else it is a real, */
  /* P3-mandated away-escape -- leave it to insert_exit_stubs). */
  if(ny != 0.0) { if(ny * (fy - py) <= 0.0) return 0; }
  else          { if(nx * (fx - px) <= 0.0) return 0; }
  if(fluid_anchor_absorbs_along_normal(fx, fy, nx, ny)) return 0;   /* length veto (anchor end) */
  if(fluid_perp_pinleg_absorbs(px, py, fx, fy, nx, ny)) return 0;   /* length veto (pin end, Finding 3) */
  /* P5 (P5 > P6): the along-normal L must not drive either leg through a stationary foreign device
   * body -- the both-P2-clear arm proved no short, not no body cross (Finding 1). L legs by orientation
   * (place_moved_wire branches): along==1 => vertical pin-leg then horizontal arrival; along==2 =>
   * horizontal pin-leg then vertical arrival. Both legs run between the SAME (px,py) and (fx,fy). */
  if(along == 1) {
    if(fluid_seg_crosses_stationary_body(px, py, px, fy)) return 0;  /* vertical pin-leg   */
    if(fluid_seg_crosses_stationary_body(px, fy, fx, fy)) return 0;  /* horizontal arrival */
  } else {
    if(fluid_seg_crosses_stationary_body(px, py, fx, py)) return 0;  /* horizontal pin-leg */
    if(fluid_seg_crosses_stationary_body(fx, py, fx, fy)) return 0;  /* vertical arrival   */
  }
  return along;
}

/* total number of instance pins in the current schematic */
static int fluid_count_pins(void)
{
  int i, tot = 0;
  for(i = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;                  /* unlinked symbol (see move.c:1274) */
    tot += (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
  }
  return tot;
}

/* fill out[] (sized >= maxpins) with the canonical first-seen partition id of each instance
 * pin; return the number written. prepare_netlist_structs() must have run. */
static int fluid_build_partition(int *out, int maxpins)
{
  int i, p, j, k = 0, nextid = 0, nnames = 0;
  const char **names;
  int *nameid;
  if(maxpins <= 0) return 0;
  names  = my_malloc(_ALLOC_ID_, maxpins * sizeof(char *)); /* net name -> id, first-seen list */
  nameid = my_malloc(_ALLOC_ID_, maxpins * sizeof(int));    /* (upper bound: one per pin) */
  for(i = 0; i < xctx->instances && k < maxpins; ++i) {
    int npins;
    if(xctx->inst[i].ptr < 0) continue;                  /* skip identically to fluid_count_pins */
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    for(p = 0; p < npins && k < maxpins; ++p) {
      const char *nm = xctx->inst[i].node ? xctx->inst[i].node[p] : NULL;
      int id = -1;
      if(nm && nm[0]) {
        for(j = 0; j < nnames; ++j) if(!strcmp(names[j], nm)) { id = nameid[j]; break; }
        if(id < 0) { names[nnames] = nm; nameid[nnames] = nextid; ++nnames; id = nextid++; }
      } else {
        id = nextid++;                                   /* unconnected pin -> unique singleton */
      }
      out[k++] = id;
    }
  }
  my_free(_ALLOC_ID_, &names);
  my_free(_ALLOC_ID_, &nameid);
  return k;
}

/* capture the pre-move connectivity partition (called at move START) */
static void fluid_snapshot_partition(void)
{
  int tot, p, k, i;
  fluid_discard_snapshot();                 /* free any prior snapshot (id + pin-name arrays) */
  if(!tclgetboolvar("fluid_editing")) return;
  prepare_netlist_structs(0);
  tot = fluid_count_pins();
  if(tot <= 0) return;
  fluid_g.snap_id = my_malloc(_ALLOC_ID_, tot * sizeof(int));
  fluid_g.snap_npins = fluid_build_partition(fluid_g.snap_id, tot);
  /* Parallel capture of each pin's resolved net NAME (strdup -- node[] is freed/rebuilt across the
   * move). The device-merge P2 check (spec §9) needs both pins be NAMED pre-move: an unconnected
   * pin joining a net is a connect (P1's job), not a device short. Same walk order + skip rule as
   * fluid_build_partition, so index k lines up with fluid_g.snap_id. */
  fluid_g.snap_pinnet = my_malloc(_ALLOC_ID_, fluid_g.snap_npins * sizeof(char *));
  k = 0;
  for(i = 0; i < xctx->instances && k < fluid_g.snap_npins; ++i) {
    int npins;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    for(p = 0; p < npins && k < fluid_g.snap_npins; ++p) {
      const char *nm = xctx->inst[i].node ? xctx->inst[i].node[p] : NULL;
      fluid_g.snap_pinnet[k] = NULL;
      if(nm && nm[0]) my_strdup(_ALLOC_ID_, &fluid_g.snap_pinnet[k], nm);
      ++k;
    }
  }
  /* issue 0088: snapshot the START wire set for the novelty scope (H3). Order-normalize endpoints so
   * a later re-created identical wire (same span, possibly reversed) is recognized as NOT novel. */
  fluid_g.start_nwire = xctx->wires;
  if(fluid_g.start_nwire > 0) {
    fluid_g.start_wire = my_malloc(_ALLOC_ID_, fluid_g.start_nwire * sizeof(fluid_startwire_t));
    for(i = 0; i < fluid_g.start_nwire; ++i) {
      double ax, ay, bx, by;
      fluid_wire_norm_pts(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2,
                          &ax, &ay, &bx, &by);
      fluid_g.start_wire[i].x1 = ax; fluid_g.start_wire[i].y1 = ay;
      fluid_g.start_wire[i].x2 = bx; fluid_g.start_wire[i].y2 = by;
      fluid_g.start_wire[i].lab = NULL;
      my_strdup(_ALLOC_ID_, &fluid_g.start_wire[i].lab, get_tok_value(xctx->wire[i].prop_ptr, "lab", 0));
    }
  }
  /* issue 0104: GEOMETRIC partition at START (see the fluid_g.geo_snap_id declaration). Captured on the
   * same pristine geometry as the wire snapshot above; pure touch(), no netlist dependency. */
  fluid_g.geo_snap_id = my_malloc(_ALLOC_ID_, tot * sizeof(int));
  fluid_g.geo_snap_npins = fluid_loop_partition(NULL, fluid_g.geo_snap_id);
}

/* free the snapshot without comparing (called on move ABORT, at each new START, and after each
 * END compare). Frees both the partition-id array and the strdup'd per-pin net-name array. */
static void fluid_discard_snapshot(void)
{
  int k;
  if(fluid_g.snap_pinnet) {
    for(k = 0; k < fluid_g.snap_npins; ++k) my_free(_ALLOC_ID_, &fluid_g.snap_pinnet[k]);
    my_free(_ALLOC_ID_, &fluid_g.snap_pinnet);
  }
  if(fluid_g.start_wire) {                                  /* issue 0088 START wire snapshot */
    for(k = 0; k < fluid_g.start_nwire; ++k) my_free(_ALLOC_ID_, &fluid_g.start_wire[k].lab);
    my_free(_ALLOC_ID_, &fluid_g.start_wire);
  }
  fluid_g.start_nwire = 0;
  my_free(_ALLOC_ID_, &fluid_g.geo_snap_id);                /* issue 0104 geometric partition snapshot */
  fluid_g.geo_snap_npins = 0;
  my_free(_ALLOC_ID_, &fluid_g.snap_id);
  fluid_g.snap_npins = 0;
}

/* D1 (Track D): gesture-snapshot lifecycle wrappers. fluid_gesture_arm() takes the four START
 * snapshots (fluid_snapshot_partition, itself a no-op when fluid_editing is off) at move START;
 * fluid_gesture_free() releases them. A gesture is normally closed on one of three paths, each
 * freeing once: real move END (via the invariant check), move ABORT, and buffer teardown
 * (clear_schematic(), mirroring fluid_reroute_discard). A few DEFERRED WIRING §11.10 paths (Delete or
 * descend 'e' pressed mid-STARTMOVE) abandon a gesture without reaching any of those, leaking the
 * armed context; arm DETECTS that (armed at arm time), frees the leaked snapshot, and logs it -- it
 * does NOT abort (this sprint rolls back / refuses corruption rather than crashing, and risk #10 is
 * out of D1's scope). This stays byte-identical to the pre-D1 code, which recovered the same way
 * (fluid_snapshot_partition's own leading discard); the dbg/fltrace only fires on the leak path (never
 * on the clean suite) and is the single-free tripwire D2 exercises by deliberately skipping a free. */
static void fluid_gesture_arm(void)
{
  if(fluid_gesture_armed) {
    dbg(0, "fluid_editing: fluid_gesture_arm() re-armed while a prior gesture was still armed -- it "
           "leaked its snapshot (WIRING risk #11.10 mid-STARTMOVE abandon); recovering\n");
    /* issue 0123: stamp ui_state + sympin_preview so the leak's origin is visible -- a STARTMOVE-less
     * arm while START_SYMPIN/sympin_preview is live is the placement-click desync that mis-routes to
     * a tip-grab. */
    fltrace("FLTRACE move: fluid_gesture_arm leaked-armed recover (single-free tripwire) "
            "at ui=%s sympin_preview=%d\n", fltrace_uistate(xctx->ui_state), xctx->sympin_preview);
    fluid_gesture_free();
  }
  fluid_snapshot_partition();
  fluid_gesture_armed = 1;
  fltrace("FLTRACE move: fluid_gesture_arm ui=%s sympin_preview=%d snap_npins=%d\n",
          fltrace_uistate(xctx->ui_state), xctx->sympin_preview, fluid_g.snap_npins);
}
void fluid_gesture_free(void)   /* NOT static: clear_schematic() (actions.c) closes the gesture too */
{
  fluid_discard_snapshot();
  fluid_gesture_armed = 0;
}

/* incremental_wire_reroute.md §9 -- general device-pin-merge no-short (P2). The label-centric P2
 * pass below only sees a net-LABEL merge; a DEVICE short (a reroute laying a leg across a foreign
 * device between two of its pins) merges two nets with no label involved. Detect it directly: any
 * instance (skip net labels -- node[] echoes lab=) with two pins that were on DISTINCT named nets
 * at START and now resolve to the SAME net = a merge. Requires the START name snapshot; both pins
 * must be named at both times (an unconnected pin is P1's concern). Returns the merge count. */
static int fluid_check_device_merge(void)
{
  int i, p, q, k = 0, merges = 0;
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return 0;
  if(fluid_count_pins() != fluid_g.snap_npins) return 0;   /* instance set changed: not comparable */
  for(i = 0; i < xctx->instances; ++i) {
    int npins, base;
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;                  /* skip identically to the snapshot walk */
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;                                /* advance k for EVERY instance incl. labels */
    if(k > fluid_g.snap_npins) break;                      /* structure drift guard */
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(type && !strcmp(type, "label")) continue;         /* net label pins echo lab=; not a device */
    for(p = 0; p < npins; ++p) {
      const char *bp = fluid_g.snap_pinnet[base + p];
      const char *ap = (xctx->inst[i].node && xctx->inst[i].node[p]) ? xctx->inst[i].node[p] : NULL;
      if(!bp || !bp[0] || !ap || !ap[0]) continue;
      for(q = p + 1; q < npins; ++q) {
        const char *bq = fluid_g.snap_pinnet[base + q];
        const char *aq = (xctx->inst[i].node && xctx->inst[i].node[q]) ? xctx->inst[i].node[q] : NULL;
        if(!bq || !bq[0] || !aq || !aq[0]) continue;
        if(strcmp(bp, bq) && !strcmp(ap, aq)) {          /* distinct before, one net now => merged */
          ++merges;
          dbg(0, "fluid_editing INVARIANT (P2 device): instance '%s' pins %d,%d were on distinct "
                 "nets ('%s','%s'), now both on '%s' after move -- device short/merge\n",
                 xctx->inst[i].instname, p, q, bp, bq, ap);
        }
      }
    }
  }
  return merges;
}

/* Count instance pins whose connectivity partition changed vs the START snapshot -- the COMPLETE
 * P1/P2 signal for the diagonal-decomposition fallback: a device merge, a merge onto a single-pin
 * net LABEL (invisible to the two-pin fluid_check_device_merge above), AND a disconnect all show up
 * as a changed canonical partition id. No net-rename false positive: the ids are canonical first-seen
 * keyed to pin POSITION order, so a #net rename yields an identical vector (same as the Phase-1
 * disconnect guard in fluid_check_move_invariants). A merge onto a pin-LESS wire net is correctly
 * NOT counted (no device pin changed net). Requires node[] fresh (prepare_netlist_structs) + the
 * START id snapshot. Same body as the P1 block of fluid_check_move_invariants, factored for reuse. */
static int fluid_partition_changed(void)
{
  int tot, m, k, changed = 0, *now;
  if(!fluid_g.snap_id || fluid_g.snap_npins <= 0) return 0;
  tot = fluid_count_pins();
  if(tot != fluid_g.snap_npins) return 0;              /* instance set changed: not comparable */
  now = my_malloc(_ALLOC_ID_, tot * sizeof(int));
  m = fluid_build_partition(now, tot);
  if(m == fluid_g.snap_npins)
    for(k = 0; k < m; ++k) if(now[k] != fluid_g.snap_id[k]) ++changed;
  /* FLUID_TRACE forensics: name each changed pin (live net vs pristine snapshot net) so a
   * partition rollback in the attempt loop is diagnosable from the trace alone. */
  if(changed && fluid_trace_on()) {
    int i, p, kk = 0;
    for(i = 0; i < xctx->instances && kk < m; ++i) {
      int npins;
      if(xctx->inst[i].ptr < 0) continue;
      npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
      for(p = 0; p < npins && kk < m; ++p, ++kk) {
        if(now[kk] == fluid_g.snap_id[kk]) continue;
        {
          double px, py;
          const char *nm = xctx->inst[i].node ? xctx->inst[i].node[p] : NULL;
          const char *sn = (fluid_g.snap_pinnet && kk < fluid_g.snap_npins) ? fluid_g.snap_pinnet[kk] : NULL;
          get_inst_pin_coord(i, p, &px, &py);
          fltrace("FLTRACE pchg:   %s pin %d (%g,%g) snap=%s(id %d) now=%s(id %d)\n",
                  xctx->inst[i].instname ? xctx->inst[i].instname : "?", p, px, py,
                  sn ? sn : "-", fluid_g.snap_id[kk], nm ? nm : "-", now[kk]);
        }
      }
    }
  }
  my_free(_ALLOC_ID_, &now);
  return changed;
}

/* ==== issue 0088: collapse a redundant same-net wire loop left by a declined corner-slide ========
 * doc/claude/issues/0088-fluid-reroute-redundant-samenet-loop.md. A fluid stretch can commit a
 * CORRECT per-leg route (the 0086/0087 short guard declines a corner-slide, so a stale detour elbow
 * survives) yet leave the moved pin back on its riser column, so the pristine wire + the stale detour
 * join the SAME two rows by two parallel same-net paths -- a redundant rectangle on one net. It is not
 * a short (all one net); it is junk copper no existing END pass removes (trim only merges/dedups;
 * remove_move_orphan_wires only drops single-free-end stubs, never a fully-connected cycle).
 *
 * This pass is DELETE-ONLY and connectivity-VERIFIED: it greedily doo­ms candidate wires, keeping a
 * doom only when the geometric pin-partition is byte-preserved (so no device/label pin is ever
 * stranded and -- delete-only -- no two nets ever merge). Scoped to THIS drag's copper (novelty +
 * seed) so pre-existing user rings/danglers are untouched, and it is a strict no-op unless an actual
 * removable cycle exists. Gated by the caller (fluid_editing default off => byte-identical). */

/* union-find find with path-halving over an int parent array */
static int fluid_uf_find(int *par, int i) { while(par[i] != i) { par[i] = par[par[i]]; i = par[i]; } return i; }

/* is wire e NOVEL -- absent (span+lab) from the move-START wire set? Fail-safe: no snapshot => 0. */
static int fluid_wire_is_novel(int e)
{
  double ax, ay, bx, by; const char *lab; int j;
  if(fluid_g.start_nwire == 0 || !fluid_g.start_wire) return 0;
  fluid_wire_norm_pts(xctx->wire[e].x1, xctx->wire[e].y1, xctx->wire[e].x2, xctx->wire[e].y2,
                      &ax, &ay, &bx, &by);
  lab = get_tok_value(xctx->wire[e].prop_ptr, "lab", 0);
  for(j = 0; j < fluid_g.start_nwire; ++j)
    if(fluid_g.start_wire[j].x1 == ax && fluid_g.start_wire[j].y1 == ay &&
       fluid_g.start_wire[j].x2 == bx && fluid_g.start_wire[j].y2 == by &&
       !strcmp(fluid_g.start_wire[j].lab ? fluid_g.start_wire[j].lab : "", lab ? lab : ""))
      return 0;                                          /* present at START => not this-drag copper */
  return 1;
}

/* is wire e's SPAN absent from the move-START wire set (endpoints only, lab-independent)? Two wires
 * cannot share a span (trim dedups), so a span present at START IS the same physical wire -- pre-
 * existing copper, never this-drag. Unlike fluid_wire_is_novel this ignores lab=, so an auto #net that
 * merely RENUMBERED across the move (a ring added on its own net shifts every other #net's number) is
 * still recognised as pre-existing. The straightener needs that: novelty is its PRIMARY scope gate
 * (it mutates non-seed copper via the tail-retract), so a renumber false-positive would let it reshape
 * an untouched user ring (test_wireedit_45 cases G/D). Fail-safe: no snapshot => 0 (not novel). */
static int fluid_wire_is_novel_span(int e)
{
  double ax, ay, bx, by; int j;
  if(fluid_g.start_nwire == 0 || !fluid_g.start_wire) return 0;
  fluid_wire_norm_pts(xctx->wire[e].x1, xctx->wire[e].y1, xctx->wire[e].x2, xctx->wire[e].y2,
                      &ax, &ay, &bx, &by);
  for(j = 0; j < fluid_g.start_nwire; ++j)
    if(fluid_g.start_wire[j].x1 == ax && fluid_g.start_wire[j].y1 == ay &&
       fluid_g.start_wire[j].x2 == bx && fluid_g.start_wire[j].y2 == by) return 0;
  return 1;
}

/* issue 0139 (after_42): is wire e a PIN-TRACKED SHRINK of pre-existing copper -- a NOVEL-span wire that
 * is nonetheless the same physical backbone as a START wire, only shortened because one end tracked a
 * MOVED pin's column across the gesture? On a two-gesture connected-drag of solar_ctl the LED #net1
 * through-body trunk's right end followed the LED column inward (x2 90->80 under the -10 x-delta), so its
 * span is no longer byte-identical to the per-gesture start snapshot and fluid_wire_is_novel_span() reads
 * it as this-drag copper. It is NOT: fluid_shove_jog_separated_trunk's PRE-EXISTING gate (move.c ~7510)
 * meant to exclude a FRESH reroute detour leg (test_wireedit_36 case j), not a shrink of a user backbone.
 * The discriminator (BOTH required): the wire lies COLLINEAR strictly inside a START wire's along-
 * footprint AND has an along-endpoint sitting exactly on a MOVED pin's along-coord (the end the pin
 * dragged). NOTE the second test is deliberately NOT scoped to the trunk's own column/net -- it matches
 * ANY moved pin's along-coord (a pin one JOG off the trunk row IS the after_42 case: the LED pin at
 * (80,-160) shares only the trunk endpoint's COLUMN x=80, not its row, so a "pin on column tc" test would
 * wrongly reject it). That looseness is intentional and safe: this only re-admits a wire novel_span
 * already flagged, and every downstream trunk-shove gate still binds -- the FOLLOW-net gate (move.c
 * ~7625: a moved pin must carry the trunk's node) confines it to the gesture's own copper, and the
 * body-free precheck + DOUBLE partition-verify with exact revert backstop the reshape. So a stray
 * along-match (a fresh detour leg that happens to share a pin's coord) degrades at worst to a decline or
 * a connectivity-preserving cosmetic reshape -- never a short/merge/rename. Span-only + pin-geometry
 * (lab-independent, mirrors novel_span). `xmove`: the shove axis of the calling pass (xmove => a VERTICAL
 * candidate at column tc; else a HORIZONTAL candidate at row tc). Fail-safe: no snapshot => 0 (defer to
 * novel_span). */
static int fluid_wire_pretracked_shrink(int e, int xmove)
{
  double ax, ay, bx, by, tc, lo, hi;
  int i, p, j, spanheld = 0, pintracked = 0;
  if(fluid_g.start_nwire == 0 || !fluid_g.start_wire) return 0;
  fluid_wire_norm_pts(xctx->wire[e].x1, xctx->wire[e].y1, xctx->wire[e].x2, xctx->wire[e].y2,
                      &ax, &ay, &bx, &by);
  if(xmove) { if(ax != bx) return 0; tc = ax; lo = ay; hi = by; }  /* vertical trunk, column tc, y-run */
  else      { if(ay != by) return 0; tc = ay; lo = ax; hi = bx; }  /* horizontal trunk, row tc, x-run */
  /* a START wire collinear on the same line whose along-span CONTAINS [lo,hi] (pre-existing footprint) */
  for(j = 0; j < fluid_g.start_nwire && !spanheld; ++j) {
    fluid_startwire_t *s = &fluid_g.start_wire[j];
    if(xmove) { if(s->x1 == tc && s->x2 == tc && s->y1 <= lo && s->y2 >= hi) spanheld = 1; }
    else      { if(s->y1 == tc && s->y2 == tc && s->x1 <= lo && s->x2 >= hi) spanheld = 1; }
  }
  if(!spanheld) return 0;
  /* an along-endpoint of e sits on a MOVED pin's along-coord (that end tracked the pin's column) */
  for(i = 0; i < xctx->instances && !pintracked; ++i) {
    int np;
    if(xctx->inst[i].sel != SELECTED || xctx->inst[i].ptr < 0) continue;
    np = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    for(p = 0; p < np; ++p) {
      double px, py, pa;
      get_inst_pin_coord(i, p, &px, &py);
      pa = xmove ? py : px;
      if(pa == lo || pa == hi) { pintracked = 1; break; }
    }
  }
  return pintracked;
}

/* does wire k carry an EXPLICIT (user-meaningful) lab= -- a non-empty name that is not a bare auto
 * #net, or any bus range? The straightener slides/deletes only tool-generated auto copper: reshaping a
 * wire that solely carries an explicit name could silently RENAME its net (the geometric pin-partition
 * is unchanged, so the partition verify would NOT catch it). Conservative -- declines the whole reshape
 * rather than risk a rename.
 *
 * "auto" is `is_auto_net_name()` (strictly "#net<digits>", netlist.c), NOT a bare `lab[0]=='#'` test
 * (issue 0162, WIRING.md open risk 15). `#` is RESERVED for the engine as of issue 0156, but nothing
 * rewrites an EXISTING file, and only addlabel::name_ok refuses NEW ones -- so a user can still have a
 * `lab=#foo` net, and the old test read it as tool copper and let every de-shorter reshape it. The
 * engine only ever generates "#net<N>", so the strict test is exactly the "is this mine to reshape?"
 * question. Measured on the 0105 topology: with the backbone named `#foo`, the jog rebuilt the user's
 * net (16 -> 17 wires) where a `VDD` backbone is a repair blackout and the move is REFUSED. */
static int fluid_wire_explicit_lab(int k)
{
  const char *lab = get_tok_value(xctx->wire[k].prop_ptr, "lab", 0);
  return lab && lab[0] && (!is_auto_net_name(lab) || strpbrk(lab, "[:") != NULL);
}

/* touch-degree of point (x,y): number of wires whose segment covers it. `doomed` (if non-NULL) skips
 * doomed wires; `excl` (if >=0) skips that index. With doomed=NULL,excl=-1 => the pass-ENTRY degree. */
static int fluid_deg_at(double x, double y, unsigned short *doomed, int excl)
{
  int m, c = 0;
  for(m = 0; m < xctx->wires; ++m) {
    if(m == excl) continue;
    if(doomed && doomed[m]) continue;
    if(touch(xctx->wire[m].x1, xctx->wire[m].y1, xctx->wire[m].x2, xctx->wire[m].y2, x, y)) ++c;
  }
  return c;
}

/* Canonical geometric pin-partition over ALIVE (!doomed) wires. rep[k] gets the smallest pin index
 * sharing pin k's touch-connected wire component (or a unique id if pin k is on no alive wire), so
 * two partitions are EQUAL iff they induce the same equivalence classes on the instance pins --
 * independent of union-find numbering. Pure geometry (touch): reproduces the netlister's endpoint +
 * mid-span-T connectivity, and is immune to a stale node[] lab. Pin walk mirrors fluid_build_partition
 * (same skip rule / order). Returns the pin count. */
static int fluid_loop_partition(unsigned short *doomed, int *rep)
{
  int W = xctx->wires, i, j, np = 0, inst, r, rects;
  int *par, *comp;
  double px, py;
  par  = my_malloc(_ALLOC_ID_, (W > 0 ? W : 1) * sizeof(int));
  comp = my_malloc(_ALLOC_ID_, (fluid_count_pins() > 0 ? fluid_count_pins() : 1) * sizeof(int));
  for(i = 0; i < W; ++i) par[i] = i;
  /* a zero-length (point) wire carries no connectivity, but touch() mishandles a degenerate segment
   * (its collinear test is trivially 0==0 and the axis branch ignores the off-axis coord), so a point
   * on row y would spuriously union EVERY wire touching that row. Skip degenerate wires -- correct for
   * all callers (check_collapsing_objects normally drops them; the straightener verifies mid-collapse
   * geometry where one exists transiently). */
  for(i = 0; i < W; ++i) {
    if(doomed && doomed[i]) continue;
    if(xctx->wire[i].x1 == xctx->wire[i].x2 && xctx->wire[i].y1 == xctx->wire[i].y2) continue;
    for(j = i + 1; j < W; ++j) {
      if(doomed && doomed[j]) continue;
      if(xctx->wire[j].x1 == xctx->wire[j].x2 && xctx->wire[j].y1 == xctx->wire[j].y2) continue;
      if(touch(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2, xctx->wire[j].x1, xctx->wire[j].y1) ||
         touch(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2, xctx->wire[j].x2, xctx->wire[j].y2) ||
         touch(xctx->wire[j].x1, xctx->wire[j].y1, xctx->wire[j].x2, xctx->wire[j].y2, xctx->wire[i].x1, xctx->wire[i].y1) ||
         touch(xctx->wire[j].x1, xctx->wire[j].y1, xctx->wire[j].x2, xctx->wire[j].y2, xctx->wire[i].x2, xctx->wire[i].y2)) {
        int ri = fluid_uf_find(par, i), rj = fluid_uf_find(par, j);
        if(ri != rj) par[ri] = rj;
      }
    }
  }
  for(inst = 0; inst < xctx->instances; ++inst) {
    if(xctx->inst[inst].ptr < 0) continue;
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; ++r) {
      int cc = -1;
      get_inst_pin_coord(inst, r, &px, &py);
      for(i = 0; i < W; ++i) {
        if(doomed && doomed[i]) continue;
        if(xctx->wire[i].x1 == xctx->wire[i].x2 && xctx->wire[i].y1 == xctx->wire[i].y2) continue;
        if(touch(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2, px, py)) { cc = fluid_uf_find(par, i); break; }
      }
      comp[np] = (cc >= 0) ? cc : (W + 1 + np);          /* floating pin => unique singleton */
      ++np;
    }
  }
  for(i = 0; i < np; ++i) {                              /* canonicalize: first pin sharing this comp */
    rep[i] = i;
    for(j = 0; j < i; ++j) if(comp[j] == comp[i]) { rep[i] = rep[j]; break; }
  }
  my_free(_ALLOC_ID_, &par);
  my_free(_ALLOC_ID_, &comp);
  return np;
}

static int fluid_part_equal(int *a, int *b, int n) { int k; for(k = 0; k < n; ++k) if(a[k] != b[k]) return 0; return 1; }

/* A3-f/g: refuse to seed the collapse on a wire that carries a mid-span TAP (another alive wire's
 * endpoint or a pin strictly interior to it, or a split-through collinear pass at an endpoint) --
 * collapsing such a run would surprise; the partition verify would revert an unsafe one anyway, this
 * just declines early. */
static int fluid_loop_interior_clean(int e, unsigned short *doomed)
{
  double ex1 = xctx->wire[e].x1, ey1 = xctx->wire[e].y1, ex2 = xctx->wire[e].x2, ey2 = xctx->wire[e].y2;
  int m, inst, r, rects;
  double qx, qy;
  for(m = 0; m < xctx->wires; ++m) {
    if(m == e) continue;
    if(doomed && doomed[m]) continue;
    /* an endpoint of m strictly interior to e => a T-tap on e */
    if(touch(ex1, ey1, ex2, ey2, xctx->wire[m].x1, xctx->wire[m].y1) &&
       !(xctx->wire[m].x1 == ex1 && xctx->wire[m].y1 == ey1) &&
       !(xctx->wire[m].x1 == ex2 && xctx->wire[m].y1 == ey2)) return 0;
    if(touch(ex1, ey1, ex2, ey2, xctx->wire[m].x2, xctx->wire[m].y2) &&
       !(xctx->wire[m].x2 == ex1 && xctx->wire[m].y2 == ey1) &&
       !(xctx->wire[m].x2 == ex2 && xctx->wire[m].y2 == ey2)) return 0;
  }
  for(inst = 0; inst < xctx->instances; ++inst) {         /* a pin strictly interior to e */
    if(xctx->inst[inst].ptr < 0) continue;
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; ++r) {
      get_inst_pin_coord(inst, r, &qx, &qy);
      if(touch(ex1, ey1, ex2, ey2, qx, qy) &&
         !(qx == ex1 && qy == ey1) && !(qx == ex2 && qy == ey2)) return 0;
    }
  }
  if(point_is_collinear_pass(ex1, ey1) || point_is_collinear_pass(ex2, ey2)) return 0; /* split through-tap */
  return 1;
}

/* Is wire e a CHORD given the current `doomed` mask -- do its two endpoints stay connected to EACH
 * OTHER through OTHER alive wires when e is removed? Only a chord is redundant (its removal cannot
 * disconnect anything); a tree edge / dangling / sole-pin-net wire is NOT a chord, so this is the
 * cycle-membership gate that stops the pass from deleting legitimate acyclic routing (a lone pin is a
 * partition singleton with or without its wires, so the partition check alone would wrongly allow it). */
static int fluid_is_chord(int e, unsigned short *doomed)
{
  int W = xctx->wires, i, j, ra = -1, rb = -1;
  int *par;
  double ax = xctx->wire[e].x1, ay = xctx->wire[e].y1, bx = xctx->wire[e].x2, by = xctx->wire[e].y2;
  if(W < 2) return 0;
  par = my_malloc(_ALLOC_ID_, W * sizeof(int));
  for(i = 0; i < W; ++i) par[i] = i;
  for(i = 0; i < W; ++i) {
    if(i == e || (doomed && doomed[i])) continue;
    for(j = i + 1; j < W; ++j) {
      if(j == e || (doomed && doomed[j])) continue;
      if(touch(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2, xctx->wire[j].x1, xctx->wire[j].y1) ||
         touch(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2, xctx->wire[j].x2, xctx->wire[j].y2) ||
         touch(xctx->wire[j].x1, xctx->wire[j].y1, xctx->wire[j].x2, xctx->wire[j].y2, xctx->wire[i].x1, xctx->wire[i].y1) ||
         touch(xctx->wire[j].x1, xctx->wire[j].y1, xctx->wire[j].x2, xctx->wire[j].y2, xctx->wire[i].x2, xctx->wire[i].y2)) {
        int ri = fluid_uf_find(par, i), rj = fluid_uf_find(par, j);
        if(ri != rj) par[ri] = rj;
      }
    }
  }
  for(i = 0; i < W; ++i) {
    if(i == e || (doomed && doomed[i])) continue;
    if(ra < 0 && touch(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2, ax, ay)) ra = fluid_uf_find(par, i);
    if(rb < 0 && touch(xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2, bx, by)) rb = fluid_uf_find(par, i);
  }
  my_free(_ALLOC_ID_, &par);
  return (ra >= 0 && ra == rb);
}

/* Did a wire component this drag REACHES already contain a CYCLE at move START? If so that net carries
 * pre-existing USER-drawn loop copper, and the collapse is declined wholesale -- the pass only removes
 * redundancy THIS drag created, never touches a net the user already looped (issue 0088 reviews
 * wf_fce167ed / wf_257dddae: else the collapse eats an untouched user ring sharing a junction, a lone
 * pin's own loop, or a loop the moved pin LANDS ON). Computed PURELY from START data -- the
 * fluid_g.start_wire[] snapshot + coord_was_grabbed -- plus the live moving-pin positions, so it is
 * immune to the trim_wires coordinate drift a live-geometry match suffers.
 *
 * The graph is TAP-AWARE: each START wire is split at every node lying on its span (endpoints AND
 * mid-span T-taps of other wires), so a user loop closing through a tap is modelled as a cycle exactly
 * as touch()/the netlister sees it -- an endpoint-only graph is tap-BLIND and reads such a loop as a
 * tree (review wf_257dddae F1). A REACHED component is one whose node is grabbed (old-position net) OR
 * on a live moving pin (the drag's destination). A reached component has a cycle iff, over its
 * tap-split edges, edges >= nodes. Zero-length START wires are skipped (they add no sub-edge, so they
 * cannot masquerade as a self-loop -- review F3). */
static int fluid_start_grabbed_component_has_cycle(void)
{
  int nw = fluid_g.start_nwire, i, j, nn = 0, ne = 0, ecap = 0, result = 0;
  double *nx, *ny, *onpos;
  int *par, *ecount, *ncount, *reach, *onlist, *eu = NULL, *ev = NULL;
  if(nw <= 1 || !fluid_g.start_wire) return 0;
  nx = my_malloc(_ALLOC_ID_, 2 * nw * sizeof(double));
  ny = my_malloc(_ALLOC_ID_, 2 * nw * sizeof(double));
  for(i = 0; i < nw; ++i) {                               /* intern distinct endpoint coords -> nodes */
    double px[2], py[2]; int e;
    px[0] = fluid_g.start_wire[i].x1; py[0] = fluid_g.start_wire[i].y1;
    px[1] = fluid_g.start_wire[i].x2; py[1] = fluid_g.start_wire[i].y2;
    for(e = 0; e < 2; ++e) {
      int found = -1;
      for(j = 0; j < nn; ++j) if(nx[j] == px[e] && ny[j] == py[e]) { found = j; break; }
      if(found < 0) { nx[nn] = px[e]; ny[nn] = py[e]; ++nn; }
    }
  }
  par    = my_malloc(_ALLOC_ID_, (nn > 0 ? nn : 1) * sizeof(int));
  onlist = my_malloc(_ALLOC_ID_, (nn > 0 ? nn : 1) * sizeof(int));
  onpos  = my_malloc(_ALLOC_ID_, (nn > 0 ? nn : 1) * sizeof(double));
  for(j = 0; j < nn; ++j) par[j] = j;
  for(i = 0; i < nw; ++i) {                               /* split each wire at every node on its span */
    double wx1 = fluid_g.start_wire[i].x1, wy1 = fluid_g.start_wire[i].y1;
    double wx2 = fluid_g.start_wire[i].x2, wy2 = fluid_g.start_wire[i].y2;
    int m = 0, a;
    if(wx1 == wx2 && wy1 == wy2) continue;                /* zero-length: no sub-edge (review F3) */
    for(j = 0; j < nn; ++j)
      if(touch(wx1, wy1, wx2, wy2, nx[j], ny[j])) {
        onlist[m] = j;
        onpos[m]  = (wx2 != wx1) ? (nx[j] - wx1) / (wx2 - wx1) : (ny[j] - wy1) / (wy2 - wy1);
        ++m;
      }
    for(a = 1; a < m; ++a) {                              /* insertion-sort nodes along the wire */
      int t = onlist[a]; double tp = onpos[a]; int b = a - 1;
      while(b >= 0 && onpos[b] > tp) { onlist[b+1] = onlist[b]; onpos[b+1] = onpos[b]; --b; }
      onlist[b+1] = t; onpos[b+1] = tp;
    }
    for(a = 1; a < m; ++a) {                              /* consecutive sub-edges */
      int u = onlist[a-1], v = onlist[a], ru, rv, t, dup = 0;
      if(u == v) continue;
      /* dedup: overlapping/duplicate collinear START wires would emit the SAME sub-edge twice, a
       * multigraph that inflates the edge count and would over-decline (audit wf_d53bd986 nit). Count
       * the SIMPLE graph so edges>=nodes is an exact cycle test. */
      for(t = 0; t < ne; ++t)
        if((eu[t] == u && ev[t] == v) || (eu[t] == v && ev[t] == u)) { dup = 1; break; }
      if(dup) continue;
      if(ne >= ecap) { ecap = ecap ? ecap * 2 : 32;
        my_realloc(_ALLOC_ID_, &eu, ecap * sizeof(int)); my_realloc(_ALLOC_ID_, &ev, ecap * sizeof(int)); }
      eu[ne] = u; ev[ne] = v; ++ne;
      ru = fluid_uf_find(par, u); rv = fluid_uf_find(par, v);
      if(ru != rv) par[ru] = rv;
    }
  }
  ecount = my_malloc(_ALLOC_ID_, (nn > 0 ? nn : 1) * sizeof(int));
  ncount = my_malloc(_ALLOC_ID_, (nn > 0 ? nn : 1) * sizeof(int));
  reach  = my_malloc(_ALLOC_ID_, (nn > 0 ? nn : 1) * sizeof(int));
  for(j = 0; j < nn; ++j) { ecount[j] = 0; ncount[j] = 0; reach[j] = 0; }
  for(j = 0; j < nn; ++j) {
    int r = fluid_uf_find(par, j);
    ncount[r]++;                                          /* nodes per component root */
    if(coord_was_grabbed(nx[j], ny[j]) || point_on_moving_pin(nx[j], ny[j])) reach[r] = 1;
  }
  for(i = 0; i < ne; ++i) ecount[fluid_uf_find(par, eu[i])]++;      /* sub-edges per component root */
  for(j = 0; j < nn; ++j) {
    int r = fluid_uf_find(par, j);
    if(r == j && reach[r] && ecount[r] >= ncount[r]) { result = 1; break; }
  }
  my_free(_ALLOC_ID_, &nx);   my_free(_ALLOC_ID_, &ny);
  my_free(_ALLOC_ID_, &par);  my_free(_ALLOC_ID_, &onlist); my_free(_ALLOC_ID_, &onpos);
  my_free(_ALLOC_ID_, &ecount); my_free(_ALLOC_ID_, &ncount); my_free(_ALLOC_ID_, &reach);
  if(eu) my_free(_ALLOC_ID_, &eu);
  if(ev) my_free(_ALLOC_ID_, &ev);
  return result;
}

/* Is wire kk a doomable candidate given the current `doomed` mask? A SEED (this drag grabbed an end,
 * or it is incident to a MOVED pin) that is a CHORD with a clean interior, OR an exposed DEAD-END
 * adjacent to an already-doomed wire (same component by construction) whose freed ends are former
 * junctions -- never a bus, never the sole carrier of an explicit (non-#) label, never a born-free
 * user dangler tip, never an acyclic (tree / dangling / sole-pin-net) wire. */
static int fluid_loop_eligible(int kk, unsigned short *doomed, int *predeg1, int *predeg2)
{
  int W = xctx->wires, mm, seed, adj = 0, endbad = 0;
  const char *lab;
  if(doomed[kk]) return 0;
  if(xctx->wire[kk].bus != 0.0) return 0;                  /* A3-d: no buses in v1 */
  lab = get_tok_value(xctx->wire[kk].prop_ptr, "lab", 0);
  if(lab && strpbrk(lab, "[:")) return 0;                  /* bus label */
  /* H2 / issue 0040: never doom the SOLE carrier of an EXPLICIT label (an AUTO "#net<N>" label
   * regenerates, so it is exempt). The exemption is `is_auto_net_name()`, not `lab[0]=='#'` --
   * a user-authored `lab=#foo` is NOT regenerable and must be protected like any other name
   * (issue 0162; same swap as fluid_wire_explicit_lab above). get_tok_value returns a SHARED buffer,
   * so copy this wire's lab before the inner get_tok_value calls overwrite it (else `lab` dangles --
   * valgrind invalid read). */
  if(lab && lab[0] && !is_auto_net_name(lab)) {
    char *labcopy = NULL;
    int keeps = 0;
    my_strdup(_ALLOC_ID_, &labcopy, lab);
    for(mm = 0; mm < W; ++mm) {
      if(mm == kk || doomed[mm]) continue;
      if(!strcmp(get_tok_value(xctx->wire[mm].prop_ptr, "lab", 0), labcopy)) { keeps = 1; break; }
    }
    my_free(_ALLOC_ID_, &labcopy);
    if(!keeps) return 0;
  }
  seed = (coord_was_grabbed(xctx->wire[kk].x1, xctx->wire[kk].y1) ||
          coord_was_grabbed(xctx->wire[kk].x2, xctx->wire[kk].y2) ||
          point_on_moving_pin(xctx->wire[kk].x1, xctx->wire[kk].y1) ||
          point_on_moving_pin(xctx->wire[kk].x2, xctx->wire[kk].y2)) &&
         fluid_is_chord(kk, doomed) &&                    /* cycle-membership: only a chord is redundant */
         fluid_loop_interior_clean(kk, doomed);
  if(seed) return 1;
  for(mm = 0; mm < W && !adj; ++mm) {                      /* DEAD-END: shares an endpoint with a doomed wire */
    if(mm == kk || !doomed[mm]) continue;
    if((xctx->wire[mm].x1 == xctx->wire[kk].x1 && xctx->wire[mm].y1 == xctx->wire[kk].y1) ||
       (xctx->wire[mm].x2 == xctx->wire[kk].x1 && xctx->wire[mm].y2 == xctx->wire[kk].y1) ||
       (xctx->wire[mm].x1 == xctx->wire[kk].x2 && xctx->wire[mm].y1 == xctx->wire[kk].y2) ||
       (xctx->wire[mm].x2 == xctx->wire[kk].x2 && xctx->wire[mm].y2 == xctx->wire[kk].y2)) adj = 1;
  }
  if(!adj) return 0;
  /* each endpoint must stay connected to another alive wire, OR be a former junction (predeg>=2) that
   * is not a pin -- so a pre-existing user dangler tip (predeg<=1, no pin) is never pruned (A3-e), and
   * a pin end that would strand is left to the partition verify to revert. */
  if(fluid_deg_at(xctx->wire[kk].x1, xctx->wire[kk].y1, doomed, kk) == 0 &&
     !point_on_any_pin(xctx->wire[kk].x1, xctx->wire[kk].y1) && predeg1[kk] <= 1) endbad = 1;
  if(fluid_deg_at(xctx->wire[kk].x2, xctx->wire[kk].y2, doomed, kk) == 0 &&
     !point_on_any_pin(xctx->wire[kk].x2, xctx->wire[kk].y2) && predeg2[kk] <= 1) endbad = 1;
  return !endbad;
}

static void fluid_remove_redundant_loops(void)
{
  int W = xctx->wires, i, k, np, removed = 0, progress, novel = 0, ncand;
  int *cand;
  unsigned short *doomed;
  int *base, *now;
  int *predeg1, *predeg2;                                 /* pass-ENTRY touch-degree of each endpoint */
  unsigned char *prot;                                    /* issue 0091: user-selected components to leave */
  struct { double x1, y1, x2, y2; char *prop; } *sav = NULL;
  int nsav = 0;

  fltrace("FLTRACE loop: ENTER W=%d start_nwire=%d\n", W, fluid_g.start_nwire);
  if(W < 3) return;                                       /* fewer than 3 wires => no simple cycle */
  /* issue 0088 review wf_fce167ed: if the dragged net already carried a loop at START, that is
   * pre-existing USER copper -- decline the whole collapse (never touch a net the user looped). */
  if(fluid_start_grabbed_component_has_cycle()) {
    fltrace("FLTRACE loop: DECLINE (grabbed net had a pre-existing START cycle)\n");
    return;
  }

  doomed  = my_malloc(_ALLOC_ID_, W * sizeof(unsigned short)); memset(doomed, 0, W * sizeof(unsigned short));
  cand    = my_malloc(_ALLOC_ID_, W * sizeof(int));
  base    = my_malloc(_ALLOC_ID_, (fluid_count_pins() > 0 ? fluid_count_pins() : 1) * sizeof(int));
  now     = my_malloc(_ALLOC_ID_, (fluid_count_pins() > 0 ? fluid_count_pins() : 1) * sizeof(int));
  predeg1 = my_malloc(_ALLOC_ID_, W * sizeof(int));
  predeg2 = my_malloc(_ALLOC_ID_, W * sizeof(int));
  prot    = my_malloc(_ALLOC_ID_, W * sizeof(unsigned char));
  fluid_mark_user_protected(prot);                       /* issue 0091: never doom the user's own net */
  for(i = 0; i < W; ++i) {
    predeg1[i] = fluid_deg_at(xctx->wire[i].x1, xctx->wire[i].y1, NULL, -1);
    predeg2[i] = fluid_deg_at(xctx->wire[i].x2, xctx->wire[i].y2, NULL, -1);
  }
  np = fluid_loop_partition(NULL, base);                  /* BASE: nothing doomed */

  /* Greedy: each round COLLECT every currently-eligible candidate, sort by canonical normalized span
   * (H1 determinism -- independent of .sch record order), then TRY EACH ONCE: tentatively doom it
   * (geometry UNCHANGED -- mask only) and keep the doom iff the pin-partition is byte-preserved. Trying
   * each once (not re-picking the global min) is essential: a bridge like the riser reverts, and the
   * loop must still go on to try the redundant chords. Dooming a chord exposes its former junctions as
   * prunable dead-ends, so re-collect and repeat to a fixpoint. */
  progress = 1;
  while(progress) {
    int c;
    progress = 0;
    ncand = 0;
    for(k = 0; k < W; ++k) if(!prot[k] && fluid_loop_eligible(k, doomed, predeg1, predeg2)) cand[ncand++] = k;
    for(c = 0; c < ncand; ++c) {                          /* selection-sort cand[] by normalized span */
      int best = c, j;
      double bx1, by1, bx2, by2;
      fluid_wire_norm_pts(xctx->wire[cand[c]].x1, xctx->wire[cand[c]].y1,
                          xctx->wire[cand[c]].x2, xctx->wire[cand[c]].y2, &bx1, &by1, &bx2, &by2);
      for(j = c + 1; j < ncand; ++j) {
        double ax, ay, cx, cy;
        fluid_wire_norm_pts(xctx->wire[cand[j]].x1, xctx->wire[cand[j]].y1,
                            xctx->wire[cand[j]].x2, xctx->wire[cand[j]].y2, &ax, &ay, &cx, &cy);
        if(ax < bx1 || (ax == bx1 && (ay < by1 || (ay == by1 && (cx < bx2 || (cx == bx2 && cy < by2)))))) {
          best = j; bx1 = ax; by1 = ay; bx2 = cx; by2 = cy;
        }
      }
      if(best != c) { int t = cand[c]; cand[c] = cand[best]; cand[best] = t; }
    }
    for(c = 0; c < ncand; ++c) {
      int e = cand[c];
      if(doomed[e]) continue;                              /* (stable: eligibility only shrinks) */
      doomed[e] = 1;                                       /* tentative -- geometry UNCHANGED */
      fluid_loop_partition(doomed, now);
      if(fluid_part_equal(now, base, np)) progress = 1;    /* removal is invisible to every pin: keep */
      else doomed[e] = 0;                                  /* it strands/splits an anchor: revert */
    }
  }

  for(i = 0; i < W; ++i) if(doomed[i]) ++removed;
  if(!removed) goto done;                                  /* strict no-op on a normal (acyclic) drag */

  for(i = 0; i < W; ++i) if(doomed[i] && fluid_wire_is_novel(i)) { novel = 1; break; }
  if(!novel) goto done;                                    /* H3: an untouched user ring => decline */

  /* commit; snapshot doomed geometry for the H4 name-aware rollback */
  sav = my_malloc(_ALLOC_ID_, removed * sizeof(*sav));
  for(i = 0; i < W; ++i) if(doomed[i]) {
    sav[nsav].x1 = xctx->wire[i].x1; sav[nsav].y1 = xctx->wire[i].y1;
    sav[nsav].x2 = xctx->wire[i].x2; sav[nsav].y2 = xctx->wire[i].y2;
    sav[nsav].prop = NULL;
    my_strdup(_ALLOC_ID_, &sav[nsav].prop, xctx->wire[i].prop_ptr);
    ++nsav;
  }
  wire_delete_compact(wire_doomed_flag, doomed);
  xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
  prepare_netlist_structs(0);
  /* H4 backstop (defense in depth; unreachable given the per-doom geometric verify): a same-named
   * island split or device merge the geometric model cannot see. Fail CLOSED if the snapshot is not
   * comparable. On a trip, re-create the removed wires and leave the loop (never-worse). */
  if(!(fluid_g.snap_npins > 0 && fluid_count_pins() == fluid_g.snap_npins) ||
     fluid_partition_changed() || fluid_check_device_merge()) {
    for(i = 0; i < nsav; ++i) {
      storeobject(-1, sav[i].x1, sav[i].y1, sav[i].x2, sav[i].y2, WIRE, 0, 0, sav[i].prop);
      order_wire_coords(xctx->wires - 1);        /* touch() (pin attach) fails on an unordered wire */
    }
    xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
    xctx->need_reb_sel_arr = 1;                            /* wire array mutated (compact + re-store) */
    prepare_netlist_structs(0);
    fltrace("FLTRACE loop: H4 backstop tripped -- restored %d wire(s), loop kept\n", nsav);
  } else {
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
    fltrace("FLTRACE loop: collapsed redundant same-net loop, removed %d wire(s)\n", removed);
  }
  for(i = 0; i < nsav; ++i) my_free(_ALLOC_ID_, &sav[i].prop);
  my_free(_ALLOC_ID_, &sav);

done:
  my_free(_ALLOC_ID_, &doomed);
  my_free(_ALLOC_ID_, &cand);
  my_free(_ALLOC_ID_, &base);
  my_free(_ALLOC_ID_, &now);
  my_free(_ALLOC_ID_, &predeg1);
  my_free(_ALLOC_ID_, &predeg2);
  my_free(_ALLOC_ID_, &prot);
}

/* ==== issues 0089 + 0090: straighten a redundant same-net jog a fluid stretch left =================
 * doc/claude/issues/0089-fluid-reroute-redundant-samenet-detour.md (reversal) +
 * 0090-fluid-reroute-redundant-samenet-staircase.md (staircase). Sibling to
 * fluid_remove_redundant_loops. A declined corner-slide (0086/0087 transient-short guard) leaves a
 * same-net PATH (no cycle) with a redundant jog; delete-only (0088) cannot fix a tree, so this SLIDES
 * the jog away. Two shapes, both collapsed by pass 1:
 *   - REVERSAL (0089): the jog's two perpendicular same-net neighbours leave on the SAME side, so the
 *     route bulges out to an intermediate column and RETURNS (before_3.sch, R18 (-80,-60) -> after_9:
 *     #net2 rings out to x=-400 and back). Sliding to the nearer neighbour only SHORTENS copper.
 *   - STAIRCASE (0090): neighbours leave on OPPOSITE sides -- a monotone step the route takes and keeps
 *     going (a MULTI-GESTURE artifact: before_3 -> after_10, R18.M's #net1 riser steps at x=-250).
 *     Collapsing it EXTENDS the far neighbour, so pass 1 additionally body-cross-guards the reshaped
 *     legs and, when the nearer target would drive the riser through the moving device's own body,
 *     tries the farther target (merge into the riser + pass-2 tail retract).
 *
 * SAFETY: every mutation is pin-partition VERIFIED (fluid_loop_partition, pure touch() -- node[]
 * independent) against the pass-entry BASE; a slide/retract/prune that changes ANY pin's partition is
 * reverted, so no pin ever strands and no two nets ever merge (a foreign-pin short shows as a merge).
 * SCOPE: the jog must be NOVEL (absent at move START), so a user's deliberate staircase is never
 * rewritten; a retracted riser tail must have been a real junction at START (fluid_start_deg_at >= 2)
 * that this drag orphaned, so a user's dangling stub is never pruned. Strict no-op unless a removable
 * jog exists. Caller-gated on fluid_editing (default off => never runs => byte-identical). */

/* was (x,y) an ENDPOINT of some wire at move START? The 0103 anchor-tail prune scopes its free end
 * with this (a pristine attach point IS a START endpoint) -- NOT with coord_was_grabbed, whose
 * stretch_grabbed_xy snapshot is re-taken by the mid-gesture follow-set regrabs and so holds the
 * follow wires' MOVED coords, never the pristine anchors. */
static int fluid_start_endpoint_at(double x, double y)
{
  int j;
  if(fluid_g.start_nwire == 0 || !fluid_g.start_wire) return 0;
  for(j = 0; j < fluid_g.start_nwire; ++j)
    if((fluid_g.start_wire[j].x1 == x && fluid_g.start_wire[j].y1 == y) ||
       (fluid_g.start_wire[j].x2 == x && fluid_g.start_wire[j].y2 == y)) return 1;
  return 0;
}

/* touch-degree of (x,y) over the move-START wire snapshot: how many START spans cover it. Used to tell
 * a drag-ORPHANED junction (was >=2, now dangling) from a pre-existing user dangler tip (was <=1). */
static int fluid_start_deg_at(double x, double y)
{
  int j, c = 0;
  if(fluid_g.start_nwire == 0 || !fluid_g.start_wire) return 0;
  for(j = 0; j < fluid_g.start_nwire; ++j) {
    /* skip a zero-length START span: touch() mishandles a degenerate segment -- its collinear test is
     * trivially 0==0 and the axis branch ignores the off-axis coord, so a point wire on row y matches
     * EVERY query on that row, spuriously inflating the degree (a label-tap left one such point at
     * START in test_wireedit_20, reading the run's free end as a junction). */
    if(fluid_g.start_wire[j].x1 == fluid_g.start_wire[j].x2 &&
       fluid_g.start_wire[j].y1 == fluid_g.start_wire[j].y2) continue;
    if(touch(fluid_g.start_wire[j].x1, fluid_g.start_wire[j].y1,
             fluid_g.start_wire[j].x2, fluid_g.start_wire[j].y2, x, y)) ++c;
  }
  return c;
}

/* Retract wire kw's ORPHANED dangling end back to its nearest interior junction, OR delete kw whole if
 * it is a fully-orphaned stub whose far end stays connected. Partition-verified against base; reverts on
 * any change. Returns 1 iff geometry changed. `ex,ey` is the dangling end (deg_now==1, verified by the
 * caller). */
/* issue 0132 §11.9g (P-B, after_37): does the net NAME on wire kw survive on OTHER live copper that
 * touches kw's FAR (kept) end (ox,oy)? Authorizes deleting a stale NAMED old-elbow overhang without
 * orphaning its label. The pin-indexed partition-verify (fluid_loop_partition) is BLIND to a pin-less
 * named net (e.g. a lab=VDD stub), so deleting the SOLE carrier of a name would pass the partition
 * check yet silently drop the label. Requiring a same-lab survivor touching the far end guarantees
 * (a) the name is never orphaned (never delete the last carrier), (b) the survivor is in the SAME
 * touch-component (not a separately-named same-lab island), (c) self-protection across prune rounds.
 * Compares the lab STRING, not merely "is named". */
static int fluid_same_name_survivor(int kw, double ox, double oy)
{
  char *mylab = NULL;
  int m, found = 0;
  my_strdup(_ALLOC_ID_, &mylab, get_tok_value(xctx->wire[kw].prop_ptr, "lab", 0));
  if(!mylab || !mylab[0]) { my_free(_ALLOC_ID_, &mylab); return 0; }
  for(m = 0; m < xctx->wires && !found; ++m) {
    const char *ml;
    if(m == kw) continue;
    if(xctx->wire[m].x1 == xctx->wire[m].x2 && xctx->wire[m].y1 == xctx->wire[m].y2) continue;
    if(!touch(xctx->wire[m].x1, xctx->wire[m].y1, xctx->wire[m].x2, xctx->wire[m].y2, ox, oy)) continue;
    if(!fluid_wire_explicit_lab(m)) continue;      /* (calls get_tok_value; ml read AFTER, so fresh) */
    ml = get_tok_value(xctx->wire[m].prop_ptr, "lab", 0);
    if(ml && ml[0] && !strcmp(ml, mylab)) found = 1;
  }
  my_free(_ALLOC_ID_, &mylab);
  return found;
}

/* allow_named_stale (0132 §11.9g): when 1, the DELETE branch below may remove a NAMED whole-stub
 * overhang IF its label survives on live copper at the far end (fluid_same_name_survivor) -- the
 * relocated-pin-riser old-elbow tail (TRIANG 80,90 / CTRL1 120,100). Set ONLY by the diag_relay
 * stale-feed prune, whose per-end gates already prove the dangling end was a drag-orphaned START
 * junction. 0 elsewhere keeps the §11.1 delete-blackout byte-identical (RETRACT stays name-safe
 * unconditionally). */
static int fluid_retract_orphan_tail(int kw, double ex, double ey, int *base, int np, int *now,
                                     int allow_named_stale)
{
  xWire *w = &xctx->wire[kw];
  double ox = (w->x1 == ex && w->y1 == ey) ? w->x2 : w->x1;  /* the far (kept) end */
  double oy = (w->x1 == ex && w->y1 == ey) ? w->y2 : w->y1;
  double jx = ex, jy = ey, bestd = -1.0;
  int m, inst, r, rects, found = 0;
  double sx1 = w->x1, sy1 = w->y1, sx2 = w->x2, sy2 = w->y2;  /* revert snapshot */
  /* nearest interior junction J on kw between (ex,ey) and the far end: an endpoint of another alive
   * wire, or an instance pin, lying strictly interior to kw's span. */
  for(m = 0; m < xctx->wires; ++m) {
    int e2;
    if(m == kw) continue;
    for(e2 = 0; e2 < 2; ++e2) {
      double px = e2 ? xctx->wire[m].x2 : xctx->wire[m].x1;
      double py = e2 ? xctx->wire[m].y2 : xctx->wire[m].y1;
      double d;
      if(!touch(w->x1, w->y1, w->x2, w->y2, px, py)) continue;
      if((px == ex && py == ey) || (px == ox && py == oy)) continue;  /* not kw's own ends */
      d = (px - ex) * (px - ex) + (py - ey) * (py - ey);
      if(bestd < 0 || d < bestd) { bestd = d; jx = px; jy = py; found = 1; }
    }
  }
  for(inst = 0; inst < xctx->instances; ++inst) {            /* a pin interior to kw is a junction too */
    if(xctx->inst[inst].ptr < 0) continue;
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; ++r) {
      double px, py, d;
      get_inst_pin_coord(inst, r, &px, &py);
      if(!touch(w->x1, w->y1, w->x2, w->y2, px, py)) continue;
      if((px == ex && py == ey) || (px == ox && py == oy)) continue;
      d = (px - ex) * (px - ex) + (py - ey) * (py - ey);
      if(bestd < 0 || d < bestd) { bestd = d; jx = px; jy = py; found = 1; }
    }
  }
  if(found) {                                                /* retract (ex,ey) -> (jx,jy) */
    if(w->x1 == ex && w->y1 == ey) { w->x1 = jx; w->y1 = jy; } else { w->x2 = jx; w->y2 = jy; }
    order_wire_coords(kw);
    fluid_loop_partition(NULL, now);
    if(fluid_part_equal(now, base, np)) {
      fltrace("FLTRACE straighten: retracted orphan tail wire=%d (%g,%g)->(%g,%g)\n", kw, ex, ey, jx, jy);
      check_collapsing_objects(); trim_wires();
      return 1;
    }
    w->x1 = sx1; w->y1 = sy1; w->x2 = sx2; w->y2 = sy2;      /* revert */
    return 0;
  }
  /* no interior junction: kw is a whole orphaned stub. Delete it iff its far end stays connected and the
   * partition is preserved (delete-verify by tentatively degenerating it, then compacting on keep). */
  {
    unsigned short *doomed = my_malloc(_ALLOC_ID_, xctx->wires * sizeof(unsigned short));
    int keep;
    memset(doomed, 0, xctx->wires * sizeof(unsigned short));
    doomed[kw] = 1;
    fluid_loop_partition(doomed, now);
    keep = fluid_part_equal(now, base, np) &&
           (!fluid_wire_explicit_lab(kw) ||                        /* never delete named copper, unless... */
            (allow_named_stale && fluid_same_name_survivor(kw, ox, oy)));  /* §11.9g: a stale named
                                    * old-elbow overhang whose label survives at its far end */
    if(keep) {
      fltrace("FLTRACE straighten: deleted orphan stub wire=%d [%g %g %g %g]\n", kw, sx1, sy1, sx2, sy2);
      wire_delete_compact(wire_doomed_flag, doomed);
    }
    my_free(_ALLOC_ID_, &doomed);
    return keep;
  }
}

/* do wires a and b share a touch point (endpoint of one on the other's span -- the SAME connectivity
 * model fluid_loop_partition / the netlister use: a bare crossing with no shared/on-span endpoint is
 * NOT a connection)? Degenerate (point) wires carry no connectivity. */
static int fluid_wires_touch(int a, int b)
{
  xWire *wa = &xctx->wire[a], *wb = &xctx->wire[b];
  if((wa->x1 == wa->x2 && wa->y1 == wa->y2) || (wb->x1 == wb->x2 && wb->y1 == wb->y2)) return 0;
  return touch(wa->x1, wa->y1, wa->x2, wa->y2, wb->x1, wb->y1) ||
         touch(wa->x1, wa->y1, wa->x2, wa->y2, wb->x2, wb->y2) ||
         touch(wb->x1, wb->y1, wb->x2, wb->y2, wa->x1, wa->y1) ||
         touch(wb->x1, wb->y1, wb->x2, wb->y2, wa->x2, wa->y2);
}

/* mark (in reach[], size xctx->wires) every wire touch-reachable from wire kd -- i.e. kd's whole net
 * copper component in the CURRENT geometry. Used to tell a slide's INTENDED new adjacency (a wire
 * already in d's net) from a foreign SHORT (a wire the slide newly lands d on). */
static void fluid_wire_reach_set(int kd, unsigned char *reach)
{
  int W = xctx->wires, i, changed;
  memset(reach, 0, (W > 0 ? W : 1) * sizeof(unsigned char));
  if(kd < 0 || kd >= W) return;
  reach[kd] = 1;
  do {
    changed = 0;
    for(i = 0; i < W; ++i) {
      int j;
      if(reach[i]) continue;
      for(j = 0; j < W; ++j)
        if(reach[j] && j != i && fluid_wires_touch(i, j)) { reach[i] = 1; changed = 1; break; }
    }
  } while(changed);
}

/* Would sliding the reversal unit (kd,kA,kC) to its new position merge d's net with FOREIGN copper the
 * pin-partition cannot see? `reach` = d's PRE-slide net component (computed before the coord edit). Any
 * wire NOT in reach that now touches the reshaped d/A/C is a different net -> a short. This closes the
 * gap that fluid_loop_partition (instance-pin-indexed) misses for a pin-LESS foreign net (a lab= supply
 * stub with no device pin) -- review wf_bacae8eb. */
static int fluid_slide_merges_foreign(int kd, int kA, int kC, unsigned char *reach)
{
  int m, W = xctx->wires;
  for(m = 0; m < W; ++m) {
    if(m == kd || m == kA || m == kC || reach[m]) continue;   /* the unit, or already d's net */
    if(fluid_wires_touch(m, kd) || fluid_wires_touch(m, kA) || fluid_wires_touch(m, kC)) return 1;
  }
  return 0;
}

/* issue 0091: does wire k carry the session-stable id of a wire the USER selected at drag START?
 * Ids are preserved across an in-place move (place_moved_wire's SELECTED else-branch updates coords
 * on the same struct) and are never reused, so an id match is a reliable "this is the user's wire"
 * even after the follow reroute renumbered every #net. A wire merged away by trim loses its id from
 * the live set (a benign miss -- the merged survivor is legitimately cleaner copper). */
static int fluid_wire_is_user_selected(int k)
{
  int j;
  unsigned int id;
  if(k < 0 || k >= xctx->wires) return 0;
  id = xctx->wire[k].id;
  if(id == 0 || xctx->fluid_startsel_nid <= 0 || !xctx->fluid_startsel_id) return 0;
  for(j = 0; j < xctx->fluid_startsel_nid; ++j) if(xctx->fluid_startsel_id[j] == id) return 1;
  return 0;
}

/* issue 0091: flood-fill prot[] over the touch-component of every user-selected wire. The END
 * redundant-route cleanup (0088-0090) declines any reshape/delete of a wire with prot[]=1, so it
 * cleans tool-grabbed follow copper on OTHER nets (the reported R18.M #net1 body-cross) while leaving
 * the user's own selected net intact -- the per-component refinement of the old wholesale
 * fluid_startsel_wires==0 gate. Distinct nets never share a touch-component (that would be a short),
 * so protecting the user's net never blocks a foreign-net cleanup. prot[] must be xctx->wires long. */
static void fluid_mark_user_protected(unsigned char *prot)
{
  int k, W = xctx->wires;
  unsigned char *reach;
  memset(prot, 0, (W > 0 ? W : 1) * sizeof(unsigned char));
  if(xctx->fluid_startsel_nid <= 0 || !xctx->fluid_startsel_id) return;
  reach = my_malloc(_ALLOC_ID_, (W > 0 ? W : 1) * sizeof(unsigned char));
  for(k = 0; k < W; ++k) {
    int j;
    if(prot[k]) continue;                              /* already covered by an earlier flood */
    if(!fluid_wire_is_user_selected(k)) continue;
    fluid_wire_reach_set(k, reach);
    for(j = 0; j < W; ++j) if(reach[j]) prot[j] = 1;
  }
  my_free(_ALLOC_ID_, &reach);
}

/* issue 0137 (minimum-copper compaction on every move): re-admit ONE shape into
 * fluid_straighten_reversals that its span-novelty gate (:3589) would otherwise skip -- a MOVED pin's
 * escape stub left OVERSHOOTING beyond the minimal 1-grid P3 escape. Mechanism (traced, before_41.sch):
 * the drag pipeline is PUSH-only. Dragging the instance so its pin approaches its own perpendicular jog,
 * the push-through slide (fluid_slide_push_through) SHOVES the jog out along the escape normal (keeps the
 * escape >= 1 grid) -- correct. But dragging the instance back so the pin RECEDES, nothing PULLS the jog
 * in: the escape stub simply stretches. Because each gesture's START snapshot is the PREVIOUS gesture's
 * output, the stretched stub is now pre-existing copper that fluid_wire_is_novel_span() protects, so the
 * excess is never reclaimed and GROWS 2*delta per round trip (before_41: up30/dn30 -> 130 copper vs the
 * minimal 70; up60/dn60 -> 190).
 *
 * fluid_straighten_reversals ALREADY slides exactly this reversal to the 1-grid escape row -- its 0111
 * pin-landing reschedule tries the far target first (blocked by the pin's own body) then pin + grid*normal
 * -- and VERIFIES it (pin-partition + foreign-copper + body, exact revert). It just never SEES the wire.
 * This predicate re-admits precisely that shape. It is deliberately narrow so straighten stays
 * byte-identical everywhere else: kd is a plain (non-bus, non-explicit-lab) axis jog; both cornered
 * neighbours are perpendicular and on the SAME side of kd (a REVERSAL -- the near slide only ever
 * SHORTENS, safe by construction); the NEARER neighbour's far end lands EXACTLY on a MOVED pin whose
 * outward lead normal is collinear with, and points along, that stub; and the stub is longer than one
 * grid (a real overshoot). Anything else => 0 => the gate is unchanged. Gated fluid_editing. */
static int fluid_jog_is_moved_pin_escape_overshoot(int kd)
{
  xWire *d = &xctx->wire[kd];
  int vert, m, kA = -1, kC = -1;
  double dx1 = d->x1, dy1 = d->y1, dx2 = d->x2, dy2 = d->y2;
  double grid = tclgetdoublevar("cadsnap");
  if(!tclgetboolvar("fluid_editing")) return 0;
  /* mirror straighten's 0111 pin-landing gate (:3672): only when rot==flip==0 does straighten reschedule
   * a pin-landing near target to pin + grid*normal (the 1-grid escape). Under a rotated/flipped stretch it
   * takes the plain near-first slide -- onto the pin, collapsing the escape to 0 (partition-preserved, so
   * the verify would NOT decline it). Reclaiming here would then be WORSE, so restrict to the rot-free case
   * (rotation lacks the exit-stub/escape machinery anyway, WIRING §11.9). */
  if(xctx->move_rot != 0 || xctx->move_flip != 0) return 0;
  if(grid <= 0.0) grid = 1.0;
  /* issue 0138 (after_41): named nets (TRIANG/CTRL1) may overshoot too. An escape-stub overshoot slide is
   * a pure INWARD same-net shorten (crossbar pulled toward the pin, both risers shrink) -- it keeps every
   * wire's lab and the straighten slide's partition + foreign-copper verify prevents any rename/merge, so
   * the explicit-lab carve-out (which spares #-auto vs named) is not needed here. Buses stay excluded
   * (index/range reshaping is genuinely risky). */
  if(d->bus != 0.0) return 0;
  vert = (dx1 == dx2 && dy1 != dy2);
  if(!vert && !(dy1 == dy2 && dx1 != dx2)) return 0;          /* diagonal / zero-length */
  for(m = 0; m < xctx->wires; ++m) {                          /* the cornered neighbour at each end */
    if(m == kd) continue;
    if((xctx->wire[m].x1 == dx1 && xctx->wire[m].y1 == dy1) ||
       (xctx->wire[m].x2 == dx1 && xctx->wire[m].y2 == dy1)) kA = m;
    if((xctx->wire[m].x1 == dx2 && xctx->wire[m].y1 == dy2) ||
       (xctx->wire[m].x2 == dx2 && xctx->wire[m].y2 == dy2)) kC = m;
  }
  if(kA < 0 || kC < 0 || kA == kC) return 0;
  {
    xWire *A = &xctx->wire[kA], *C = &xctx->wire[kC];
    double fa, fb, dcoord, near_t, pinx, piny, along, nnx = 0.0, nny = 0.0;
    int sa, sb;
    if(A->bus != 0.0 || C->bus != 0.0) return 0;
    /* issue 0138: explicit-labelled neighbours allowed too (see the kd gate above -- the slide is a
     * same-net inward shorten that the partition/foreign verify keeps rename-safe). */
    if(vert) {
      if(A->y1 != A->y2 || C->y1 != C->y2) return 0;         /* neighbours must be horizontal */
      fa = (A->x1 == dx1 && A->y1 == dy1) ? A->x2 : A->x1;
      fb = (C->x1 == dx2 && C->y1 == dy2) ? C->x2 : C->x1;
      dcoord = dx1;
    } else {
      if(A->x1 != A->x2 || C->x1 != C->x2) return 0;         /* neighbours must be vertical */
      fa = (A->x1 == dx1 && A->y1 == dy1) ? A->y2 : A->y1;
      fb = (C->x1 == dx2 && C->y1 == dy2) ? C->y2 : C->y1;
      dcoord = dy1;
    }
    sa = (fa > dcoord) - (fa < dcoord); sb = (fb > dcoord) - (fb < dcoord);
    if(sa == 0 || sb == 0 || sa != sb) return 0;             /* must be a same-side REVERSAL */
    near_t = (fabs(fa - dcoord) <= fabs(fb - dcoord)) ? fa : fb;
    if(vert) { pinx = near_t; piny = (near_t == fa) ? dy1 : dy2; }
    else     { piny = near_t; pinx = (near_t == fa) ? dx1 : dx2; }
    if(!point_on_any_pin(pinx, piny)) return 0;
    if(!fluid_moving_pin_normal(pinx, piny, &nnx, &nny)) return 0;    /* MOVED pin + outward lead normal */
    along = vert ? nnx : nny;                                /* normal component on kd's slide axis */
    if(along == 0.0) return 0;                               /* normal perpendicular to stub: not an escape */
    if((dcoord - near_t) * along <= 0.0) return 0;           /* the jog must lie OUTWARD of the pin */
    if(fabs(near_t - dcoord) <= grid) return 0;              /* already the minimal 1-grid escape */
    return 1;
  }
}

static void fluid_straighten_reversals(void)
{
  int np, progress, guard = 0, changed_any = 0, npins;
  int *base, *now;
  unsigned char *prot;

  fltrace("FLTRACE straighten: ENTER W=%d snap_npins=%d\n", xctx->wires, fluid_g.snap_npins);
  if(xctx->wires < 3) return;
  if(fluid_failsafe(fluid_g.snap_npins <= 0)) return;          /* no START snapshot => cannot verify */
  npins = fluid_count_pins() > 0 ? fluid_count_pins() : 1;
  base = my_malloc(_ALLOC_ID_, npins * sizeof(int));
  now  = my_malloc(_ALLOC_ID_, npins * sizeof(int));
  /* issue 0091: prot[] guards the user's own selected net(s). REFILLED each iteration (indices
   * renumber after a trim) and RESIZED to the current wire count first -- trim_wires' break phase
   * (check.c wire_store_split) can SPLIT a wire and GROW xctx->wires when a kept slide lands an
   * endpoint mid-span on same-net copper, so the count is NOT monotone (adversarial review
   * wf_bbb1dcb1: a fixed entry-sized buffer overran here). Start NULL; the realloc below sizes it. */
  prot = NULL;
  np = fluid_loop_partition(NULL, base);                     /* invariant target */

  progress = 1;
  while(progress && guard++ < 8 * xctx->wires + 8) {
    int kd, W = xctx->wires;
    progress = 0;
    my_realloc(_ALLOC_ID_, &prot, (xctx->wires > 0 ? xctx->wires : 1) * sizeof(unsigned char));
    fluid_mark_user_protected(prot);                          /* issue 0091: recompute over current geometry */
    /* --- pass 1: collapse a redundant jog by sliding it to the nearer neighbour. Two shapes:
     *   same-side  (sa==sb): a REVERSAL (U-turn) -- the route bulges out and doubles back (issue 0089);
     *   opposite-side (sa!=sb): a monotone STAIRCASE STEP -- the route steps out and keeps going the same
     *     way (issue 0090). Both collapse by the same slide; the difference is that a reversal only ever
     *     SHORTENS copper (safe by construction) while a staircase EXTENDS the far neighbour, so the
     *     opposite-side case additionally guards the reshaped legs against crossing a stationary body. */
    for(kd = 0; kd < W && !progress; ++kd) {
      xWire *d = &xctx->wire[kd];
      int vert, kA = -1, kC = -1, m, sa, sb, oppo = 0, is_overshoot = 0;
      double dx1, dy1, dx2, dy2, fa = 0, fb = 0, target, near_t = 0, far_t = 0;
      double cand[10];
      int ci, ncand, cext[10], call_body[10], near_pin;
      const char *lab;
      if(d->bus != 0.0) continue;
      dx1 = d->x1; dy1 = d->y1; dx2 = d->x2; dy2 = d->y2;
      vert = (dx1 == dx2 && dy1 != dy2);
      if(!vert && !(dy1 == dy2 && dx1 != dx2)) continue;     /* diagonal or zero-length */
      lab = get_tok_value(d->prop_ptr, "lab", 0);
      if(lab && strpbrk(lab, "[:")) continue;                /* bus label: never reshape */
      /* issue 0137: reshape a jog THIS drag created (span-novelty) OR a moved-pin escape stub the drag
       * stretched past the minimal 1-grid escape and never pulled back (min-copper compaction). */
      is_overshoot = fluid_jog_is_moved_pin_escape_overshoot(kd);
      if(!fluid_wire_is_novel_span(kd) && !is_overshoot) continue;
      if(prot[kd]) continue;                                 /* issue 0091: user's own net component -- leave it */
      if(point_on_any_pin(dx1, dy1) || point_on_any_pin(dx2, dy2)) continue;
      if(fluid_deg_at(dx1, dy1, NULL, kd) != 1) continue;    /* each end a clean corner (d + one wire) */
      if(fluid_deg_at(dx2, dy2, NULL, kd) != 1) continue;
      for(m = 0; m < W; ++m) {                               /* the cornered neighbour at each end */
        if(m == kd) continue;
        if((xctx->wire[m].x1 == dx1 && xctx->wire[m].y1 == dy1) ||
           (xctx->wire[m].x2 == dx1 && xctx->wire[m].y2 == dy1)) kA = m;
        if((xctx->wire[m].x1 == dx2 && xctx->wire[m].y1 == dy2) ||
           (xctx->wire[m].x2 == dx2 && xctx->wire[m].y2 == dy2)) kC = m;
      }
      if(kA < 0 || kC < 0 || kA == kC) continue;             /* mid-span pass, or a parallel wire */
      {
        xWire *A = &xctx->wire[kA], *C = &xctx->wire[kC];
        /* d/A/C are touch-connected (d shares an endpoint with each), so they are the SAME net by
         * construction -- no net-token compare is needed (and the partition verify catches any short).
         * Only decline when an EXPLICIT label is present: reshaping named copper could rename its net. */
        if(A->bus != 0.0 || C->bus != 0.0) continue;
        /* issue 0138: explicit-labelled copper is normally left untouched -- reshaping a named net could
         * merge/rename it. EXCEPTION: a verified moved-pin escape-stub OVERSHOOT is a pure same-net inward
         * slide; the partition + foreign-copper verify below rejects any merge/rename, so admit it and let
         * the 0111 pin-landing reschedule compact the crossbar to the minimal 1-grid escape (after_41
         * TRIANG/CTRL1 crossbars stranded below their pins by a multi-motion jiggle drag). */
        if(!is_overshoot &&
           (fluid_wire_explicit_lab(kd) || fluid_wire_explicit_lab(kA) || fluid_wire_explicit_lab(kC))) continue;
        if(vert) {
          if(A->y1 != A->y2 || C->y1 != C->y2) continue;     /* neighbours perpendicular = horizontal */
          fa = (A->x1 == dx1 && A->y1 == dy1) ? A->x2 : A->x1;
          fb = (C->x1 == dx2 && C->y1 == dy2) ? C->x2 : C->x1;
          sa = (fa > dx1) - (fa < dx1); sb = (fb > dx1) - (fb < dx1);
          if(sa == 0 || sb == 0) continue;                   /* a neighbour collinear with d: not a jog */
          oppo = (sa != sb);                                 /* opposite side => monotone staircase step */
          near_t = (fabs(fa - dx1) <= fabs(fb - dx1)) ? fa : fb;
          far_t  = (near_t == fa) ? fb : fa;
        } else {
          if(A->x1 != A->x2 || C->x1 != C->x2) continue;     /* neighbours perpendicular = vertical */
          fa = (A->x1 == dx1 && A->y1 == dy1) ? A->y2 : A->y1;
          fb = (C->x1 == dx2 && C->y1 == dy2) ? C->y2 : C->y1;
          sa = (fa > dy1) - (fa < dy1); sb = (fb > dy1) - (fb < dy1);
          if(sa == 0 || sb == 0) continue;                   /* a neighbour collinear with d: not a jog */
          oppo = (sa != sb);                                 /* opposite side => monotone staircase step */
          near_t = (fabs(fa - dy1) <= fabs(fb - dy1)) ? fa : fb;
          far_t  = (near_t == fa) ? fb : fa;
        }
        /* Try the NEARER neighbour first, then the FARTHER as a fallback (both shapes). A staircase
         * (opposite-side) EXTENDS the far neighbour, so its nearer target may drive the reshaped riser
         * through the moving device's own body (declined below) and the farther target is the way out. A
         * reversal (same-side) near slide only ever SHORTENS -- so where it applies it wins on ci==0 and
         * the path stays byte-identical (ci==1 never runs once progress is set). But the near reversal
         * target is NOT always legal: a rigid group drag can leave the U-turn's near column landing on the
         * MOVED device itself, so the near collapse would run the jog through the device between its two
         * pins -- a short the partition verify declines (issue 0096: before_5.sch C12+R18+#net2 -> R18's
         * #net1 riser reverses out to x=-260 and the near slide back to x=-320 shorts R18's pins). The far
         * target then routes the same net cleanly PAST the device; it EXTENDS the near neighbour, so it is
         * body-guarded exactly like a staircase (guard = oppo || far candidate). See
         * doc/claude/issues/0096-fluid-reroute-reversal-near-shorts-moved-body.md */
        /* issue 0111: when the NEAR target sits ON a MOVING instance pin whose escape normal
         * runs ALONG the slide axis (the near neighbour is the pin's P3 exit stub), do not
         * collapse onto the pin. Pre-0111 that collapse was accepted and insert_exit_stubs
         * then re-jogged the leg one grid back off the pin ALONG THE NORMAL -- an undo/redo
         * pair whose net effect was only to NORMALIZE the jog to one grid on the outward
         * side, EXCEPT when a decomposed drag had already left the jog exactly there: that
         * round trip reproduced the same redundant staircase the collapse had just removed
         * and the SAVE kept 4 segments where 3 suffice (before_8.sch, R18 dragged NW ->
         * after_28.sch #net3). New schedule for such a pin-landing near target:
         *   1. FAR target first -- where legal it removes the jog entirely and the route
         *      arrives straight along the pin's lead (P3-perfect, minimum segments). A
         *      brand-new route choice (pre-0111 it was never reached), so it must clear the
         *      MOVED body too (call_body, test_wireedit_48 case A);
         *   2. else NEAR moved to ONE GRID OUTWARD of the pin (pin + grid x normal) --
         *      exactly the old collapse + re-stub round trip's result (the connected-wire
         *      shove of test_wireedit_37/40 and the 0089/0090/0091 golden routes are this
         *      shape), skipped when the jog already sits there (the no-op that used to
         *      round-trip into the 0111 staircase).
         * A STATIONARY pin landing, or a pin whose normal is perpendicular/ambiguous, keeps
         * the plain near-first schedule: insert_exit_stubs never re-jogged those the same
         * way (stationary pins are not scanned; a perpendicular normal re-jogs along the
         * OTHER axis, which the unchanged insert pass still does), so plain collapse is the
         * baseline there. See
         * doc/claude/issues/0111-exit-stub-restaircases-straightened-pin-arrival.md */
        near_pin = 0;
        {
          double npx, npy, nnx = 0.0, nny = 0.0;   /* collapsed neighbour's pin end + normal */
          if(vert) { npx = near_t; npy = (near_t == fa) ? dy1 : dy2; }
          else     { npy = near_t; npx = (near_t == fa) ? dx1 : dx2; }
          /* rot/flip gate mirrors the insert_exit_stubs call-site gate (review wf_bb7bb60e):
           * under a rotated/flipped stretch the re-stub pass never runs, so there is no round
           * trip to normalize -- the pre-0111 plain collapse IS the (good, minimal) baseline. */
          if(xctx->move_rot == 0 && xctx->move_flip == 0 &&
             point_on_any_pin(npx, npy) && fluid_moving_pin_normal(npx, npy, &nnx, &nny)) {
            double along = vert ? nnx : nny;     /* normal component along the slide axis */
            if(along != 0.0) {
              double grid = tclgetdoublevar("cadsnap");
              double dpos = vert ? dx1 : dy1;
              double outward;
              if(grid <= 0.0) grid = 1.0;
              outward = near_t + grid * along;   /* the old round trip's normalized jog */
              near_pin = 1;
              fltrace("FLTRACE straighten: near %g is a moving-pin landing -> far first, then outward %g\n",
                      near_t, outward);
              cand[0] = far_t; cext[0] = 1; call_body[0] = 1;
              ncand = 1;
              if(is_overshoot) {
                /* issue 0138: an escape-stub OVERSHOOT can be blocked at the minimal 1-grid row by a
                 * sibling net that already compacted onto it (after_41: TRIANG holds y=130 across the
                 * whole width, so CTRL1's 1-grid escape would short it). Search outward grid-by-grid --
                 * pin+1, pin+2, ... -- and take the nearest row that VERIFIES. Every generated row is
                 * strictly inside (pin, current jog), so it is always shorter than leaving the jog
                 * stranded; landing at dpos (the no-op) and beyond (longer) is never generated. Bounded
                 * search (<= 8 rows), same spirit as insert_exit_stubs' D2 outward slide. */
                int st; double cur = near_t;
                for(st = 0; st < 8; ++st) {
                  cur += grid * along;
                  if((along > 0 && cur >= dpos) || (along < 0 && cur <= dpos)) break;
                  cand[ncand] = cur; cext[ncand] = oppo; call_body[ncand] = 1; ncand++;
                }
              } else if(outward != dpos) {       /* novel-span jog: single 1-grid step (unchanged) */
                cand[1] = outward;
                cext[1] = oppo;
                call_body[1] = 0;                /* == the old collapse + re-stub round trip */
                ncand = 2;
              }
            }
          }
        }
        if(!near_pin) {
          cand[0] = near_t; cext[0] = oppo; call_body[0] = 0;
          cand[1] = far_t;  cext[1] = 1;    call_body[1] = 0;
          ncand = 2;
        }
        for(ci = 0; ci < ncand && !progress; ++ci) {
          double sdx1=d->x1, sdy1=d->y1, sdx2=d->x2, sdy2=d->y2;
          double sax1=A->x1, say1=A->y1, sax2=A->x2, say2=A->y2;
          double scx1=C->x1, scy1=C->y1, scx2=C->x2, scy2=C->y2;
          unsigned char *reach = my_malloc(_ALLOC_ID_, (W > 0 ? W : 1) * sizeof(unsigned char));
          target = cand[ci];
          fluid_wire_reach_set(kd, reach);                   /* d's PRE-slide net component */
          if(vert) {
            d->x1 = d->x2 = target;
            if(A->x1 == dx1 && A->y1 == dy1) A->x1 = target; else A->x2 = target;
            if(C->x1 == dx2 && C->y1 == dy2) C->x1 = target; else C->x2 = target;
          } else {
            d->y1 = d->y2 = target;
            if(A->x1 == dx1 && A->y1 == dy1) A->y1 = target; else A->y2 = target;
            if(C->x1 == dx2 && C->y1 == dy2) C->y1 = target; else C->y2 = target;
          }
          order_wire_coords(kd); order_wire_coords(kA); order_wire_coords(kC);
          /* KEEP iff the pin-partition is byte-preserved (no pinned-net short/disconnect) AND the slide
           * did not newly land d/A/C on FOREIGN copper (a pin-LESS labeled net the pin-partition cannot
           * see -- review wf_bacae8eb). A collapse that EXTENDS a neighbour (a STAIRCASE either target, or
           * a REVERSAL's far fallback ci==1) must additionally clear every stationary body -- only a
           * reversal's near slide (ci==0) is a pure shorten that keeps its byte-identical no-body-guard
           * path (issue 0096: the far reversal fallback is body-guarded like a staircase). */
          fluid_loop_partition(NULL, now);
          {
            int part_ok = fluid_part_equal(now, base, np);
            int foreign = fluid_slide_merges_foreign(kd, kA, kC, reach);
            int extends = cext[ci];                          /* slide lengthens a neighbour => guard body */
            /* issue 0138: an escape-overshoot outward row (ci>0) TRANSLATES the crossbar to a new column at
             * fixed length while its neighbours shorten -- so its final column can sweep into a device body
             * that partition/foreign (pin-net only) never see. The multi-step outward search reaches deeper
             * corridor columns than 0137's single step, so those rows must clear BOTH the MOVED body (0136:
             * a named trunk pulled back through the dragged device) AND STATIONARY bodies (review wf_fa599f4d
             * never-worse lens: a crossbar routed across a pin-less stationary symbol). Both use the REAL
             * drawn body (notext = inst.xx1..yy2), NOT the text-inflated world bbox: a wire may legally graze
             * a device's @name text (before_41's minimal y=60 escape sits above R1's real body but inside its
             * text bbox -- the text-inflated check wrongly declined it, regressing 0137). Non-overshoot / far
             * collapse (ci==0) paths keep the historical text-inflated stationary check gated on `extends`
             * (byte-identical). */
            int overshoot_row = is_overshoot && ci > 0;
            int guard_stat = extends || overshoot_row;
            int guard_moved = extends || is_overshoot;
            int body = 0;
            if((guard_stat || guard_moved) && part_ok && !foreign) {
              int q; int idx[3]; idx[0] = kd; idx[1] = kA; idx[2] = kC;
              for(q = 0; q < 3 && !body; ++q) {
                xWire *ww = &xctx->wire[idx[q]];
                if(ww->x1 == ww->x2 && ww->y1 == ww->y2) continue;   /* collapsed neighbour */
                if(guard_stat &&
                   fluid_seg_crosses_body(ww->x1, ww->y1, ww->x2, ww->y2, 0, overshoot_row)) body = 1;
                /* issue 0111/0138: the pin-landing far collapse and the overshoot reclaim must clear MOVED bodies */
                if(!body && guard_moved && call_body[ci] &&
                   fluid_seg_crosses_body(ww->x1, ww->y1, ww->x2, ww->y2, 1, overshoot_row)) body = 1;
              }
            }
            if(part_ok && foreign)
              fltrace("FLTRACE straighten: DECLINE slide wire=%d %s->%g (would short foreign copper)\n",
                      kd, vert ? "x" : "y", target);
            if((extends || is_overshoot) && part_ok && !foreign && body)
              fltrace("FLTRACE straighten: DECLINE slide wire=%d %s->%g (%s leg crosses body)\n",
                      kd, vert ? "x" : "y", target, oppo ? "staircase" : "reversal");
            if(part_ok && !foreign && !body) {
              fltrace("FLTRACE straighten: slid jog wire=%d %s->%g (%s collapse)\n",
                      kd, vert ? "x" : "y", target, oppo ? "staircase" : "reversal");
              changed_any = 1; progress = 1;
              check_collapsing_objects(); trim_wires();      /* drop collapsed neighbour + merge collinear */
            } else {
              d->x1=sdx1; d->y1=sdy1; d->x2=sdx2; d->y2=sdy2;  /* revert */
              A->x1=sax1; A->y1=say1; A->x2=sax2; A->y2=say2;
              C->x1=scx1; C->y1=scy1; C->x2=scx2; C->y2=scy2;
            }
          }
          my_free(_ALLOC_ID_, &reach);
        }
      }
    }
    if(progress) continue;                                   /* geometry changed: rescan from a fresh W */
    /* --- pass 2: retract/prune a riser tail the slide orphaned (was a START junction, now dangling) --- */
    W = xctx->wires;
    for(kd = 0; kd < W && !progress; ++kd) {
      int e;
      for(e = 0; e < 2 && !progress; ++e) {
        double ex = e ? xctx->wire[kd].x2 : xctx->wire[kd].x1;
        double ey = e ? xctx->wire[kd].y2 : xctx->wire[kd].y1;
        if(prot[kd]) continue;                               /* issue 0091: user's own net component -- leave it */
        if(point_on_any_pin(ex, ey)) continue;               /* a pin end is never dangling */
        if(fluid_deg_at(ex, ey, NULL, kd) != 0) continue;    /* still connected: not a dangling end */
        if(fluid_start_deg_at(ex, ey) < 2) continue;         /* a pre-existing user dangler tip: leave */
        if(fluid_retract_orphan_tail(kd, ex, ey, base, np, now, 0)) { changed_any = 1; progress = 1; }
      }
    }
  }

  if(changed_any) {
    /* Normalise once more before publishing: the pass-2 delete branch (fluid_retract_orphan_tail)
     * does not trim, and a fixpoint that ends on a delete can leave collinear fragments unmerged.
     * trim_wires() merges/splits, then check_collapsing_objects() drops any zero-length residue. */
    trim_wires();
    check_collapsing_objects();
    xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
    prepare_netlist_structs(0);
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
  }
  my_free(_ALLOC_ID_, &base);
  my_free(_ALLOC_ID_, &now);
  my_free(_ALLOC_ID_, &prot);
}

/* issue 0092: collapse the DANGLING OVERSHOOT STUB an along-axis wire drag leaves (see
 * doc/claude/issues/0092-fluid-axis-drag-overshoot-stub.md). A fluid stretch that drags a same-net wire
 * ALONG its own axis (a horizontal rung pulled left/right, a vertical riser pulled up/down) overshoots
 * its junction: place_moved_wire relays the along-axis component as a short stub S collinear with the
 * wire, dangling past a drag-created solder-dot junction J, while the perpendicular riser V that meets J
 * stays put. The pin-driven shove (fluid_shove_connected_wire) can NOT reach it -- its stub needs a
 * moving-INSTANCE-PIN endpoint, but the user grabbed a WIRE -- and straighten/loop miss it (the tip is a
 * brand-new deg-0 dangle, not a clean-corner jog; and it is on the user's own grabbed net, which 0091's
 * prot[] shields THEM from). This pass repairs it:
 *   SHOVE: if V's far corner C is not pinned, translate the riser column {V, the arms at C} by (T-J) and
 *          pull H's and S's J-ends to the tip T -> S collapses, H absorbs it, the riser follows the drag
 *          (preferred_12.sch);
 *   TRIM:  else delete the dangling stub S (partition-verified) -- the safe fallback when the riser is
 *          pin-anchored (a rightward drag past the pin) or a shove would short.
 * Every mutation is pin-partition VERIFIED (pure touch(), node[]-independent) against the pass-entry base
 * and reverted on any change; a foreign-wire touch by a shoved segment (the pin-less-net short the
 * partition cannot see) also reverts. NOVELTY-scoped + strict-no-op otherwise. Deliberately does NOT
 * consult prot[] (the target is always drag-created junk on the grabbed net). Caller-gated on
 * fluid_editing (default off => never runs => byte-identical). */
static void fluid_collapse_axis_overshoot_stub(void)
{
  int np, guard = 0, progress = 1, npins, changed_any = 0;
  int *base, *now;

  if(xctx->wires < 3) return;
  if(fluid_g.snap_npins <= 0) return;                         /* no START snapshot => cannot verify */
  npins = fluid_count_pins() > 0 ? fluid_count_pins() : 1;
  base = my_malloc(_ALLOC_ID_, npins * sizeof(int));
  now  = my_malloc(_ALLOC_ID_, npins * sizeof(int));
  np = fluid_loop_partition(NULL, base);                    /* invariant target */

  while(progress && guard++ < 4 * xctx->wires + 8) {
    int W = xctx->wires, ks;
    progress = 0;
    for(ks = 0; ks < W && !progress; ++ks) {
      xWire *S = &xctx->wire[ks];
      double sx1 = S->x1, sy1 = S->y1, sx2 = S->x2, sy2 = S->y2;
      int svert, m, kH = -1, kV = -1, bad = 0;
      double Tx = 0, Ty = 0, Jx = 0, Jy = 0;                /* dangling tip T, junction J */
      const char *lab;

      if(S->bus != 0.0) continue;
      svert = (sx1 == sx2 && sy1 != sy2);
      if(!svert && !(sy1 == sy2 && sx1 != sx2)) continue;   /* diagonal / zero-length */
      lab = get_tok_value(S->prop_ptr, "lab", 0);
      if(lab && strpbrk(lab, "[:")) continue;               /* bus label: never reshape */
      if(fluid_wire_explicit_lab(ks)) continue;             /* only tool-generated auto (#net) copper */
      if(!fluid_wire_is_novel_span(ks)) continue;           /* only a stub THIS drag created */

      /* exactly one end is a BRAND-NEW dangle (deg 0, no pin, absent at START); the other end = J */
      {
        int d1 = fluid_deg_at(sx1, sy1, NULL, ks) == 0 && !point_on_any_pin(sx1, sy1) &&
                 fluid_start_deg_at(sx1, sy1) == 0;
        int d2 = fluid_deg_at(sx2, sy2, NULL, ks) == 0 && !point_on_any_pin(sx2, sy2) &&
                 fluid_start_deg_at(sx2, sy2) == 0;
        if(d1 == d2) continue;                              /* need exactly one dangling brand-new tip */
        if(d1) { Tx = sx1; Ty = sy1; Jx = sx2; Jy = sy2; } else { Tx = sx2; Ty = sy2; Jx = sx1; Jy = sy1; }
      }

      /* J must be a clean solder-dot: exactly one COLLINEAR same-axis continuation H (endpoint at J, its
       * far end on the OPPOSITE side of J from T) + exactly one PERPENDICULAR riser V, nothing else. */
      for(m = 0; m < W && !bad; ++m) {
        double mx1, my1, mx2, my2; int at1, at2, mvert, mhoriz;
        if(m == ks) continue;
        mx1 = xctx->wire[m].x1; my1 = xctx->wire[m].y1;
        mx2 = xctx->wire[m].x2; my2 = xctx->wire[m].y2;
        if(mx1 == mx2 && my1 == my2) continue;              /* degenerate */
        at1 = (mx1 == Jx && my1 == Jy); at2 = (mx2 == Jx && my2 == Jy);
        if(!at1 && !at2) {
          if(touch(mx1, my1, mx2, my2, Jx, Jy)) bad = 1;    /* copper PASSES THROUGH J: not a clean dot */
          continue;
        }
        mvert  = (mx1 == mx2 && my1 != my2);
        mhoriz = (my1 == my2 && mx1 != mx2);
        if(!mvert && !mhoriz) { bad = 1; continue; }        /* DIAGONAL at J: not a clean dot -> decline */
        if(mvert == svert) {                                /* collinear (same-axis) continuation H? */
          double mfar = svert ? (at1 ? my2 : my1) : (at1 ? mx2 : mx1);
          double jca  = svert ? Jy : Jx, tca = svert ? Ty : Tx;
          if(kH < 0 && (mfar - jca) * (tca - jca) < 0.0 && !fluid_wire_explicit_lab(m)) kH = m;
          else bad = 1;                                     /* 2nd collinear / same-side / labeled -> decline */
        } else {                                            /* perpendicular riser V */
          if(kV < 0 && !fluid_wire_explicit_lab(m)) kV = m; else bad = 1;
        }
      }
      if(bad || kH < 0 || kV < 0) continue;

      {
        xWire *V = &xctx->wire[kV];
        double Cx = (V->x1 == Jx && V->y1 == Jy) ? V->x2 : V->x1;
        double Cy = (V->x1 == Jx && V->y1 == Jy) ? V->y2 : V->y1;
        double shx = Tx - Jx, shy = Ty - Jy;                /* shove vector (pure along-axis) */
        /* V is PERPENDICULAR to S, so an S-vertical stub has a HORIZONTAL riser V (and vice-versa).
         * vline = V's constant-axis coord (its line); [vlo,vhi] = V's span along its RUNNING axis. */
        int vhoriz = svert;                                 /* S vertical => perpendicular V horizontal */
        double vline = vhoriz ? Jy : Jx;
        double va = vhoriz ? Jx : Jy, vb = vhoriz ? Cx : Cy;
        double vlo = va < vb ? va : vb, vhi = va < vb ? vb : va;
        int shoveable = !point_on_fixed_pin(Cx, Cy);
        int shoved = 0;

        /* V must be a CLEAN isolated segment J..C for a shove: no endpoint strictly inside its span (a
         * mid-span tap would strand), and no wire COLLINEAR with V ending at C (a continuation the arm
         * drag would bend into a diagonal -- which the touch-based partition verify would NOT catch).
         * Either => not shoveable (fall through to the trim). */
        for(m = 0; m < W && shoveable; ++m) {
          double mx1, my1, mx2, my2; int e_at_c, coll;
          if(m == ks || m == kV) continue;
          mx1 = xctx->wire[m].x1; my1 = xctx->wire[m].y1;
          mx2 = xctx->wire[m].x2; my2 = xctx->wire[m].y2;
          if(mx1 == mx2 && my1 == my2) continue;
          if(vhoriz) {                                      /* V horizontal: on line y==vline, x-span */
            if(my1 == vline && mx1 > vlo && mx1 < vhi) shoveable = 0;
            if(my2 == vline && mx2 > vlo && mx2 < vhi) shoveable = 0;
          } else {                                          /* V vertical: on line x==vline, y-span */
            if(mx1 == vline && my1 > vlo && my1 < vhi) shoveable = 0;
            if(mx2 == vline && my2 > vlo && my2 < vhi) shoveable = 0;
          }
          e_at_c = (mx1 == Cx && my1 == Cy) || (mx2 == Cx && my2 == Cy);
          coll = vhoriz ? (my1 == my2 && my1 == vline) : (mx1 == mx2 && mx1 == vline);
          if(e_at_c && coll) shoveable = 0;
        }

        if(shoveable) {                                     /* --- try the SHOVE --- */
          /* collect the wires to translate: S's J-end, H's J-end, V (both ends), each arm at C. Snapshot
           * their coords so a failed partition/foreign check reverts exactly. */
          int cap = W, cnt = 0, i, ok;
          int *idx = my_malloc(_ALLOC_ID_, cap * sizeof(int));
          double *sav = my_malloc(_ALLOC_ID_, 4 * cap * sizeof(double));
          unsigned char *reach = my_malloc(_ALLOC_ID_, W * sizeof(unsigned char));
          fluid_wire_reach_set(kH, reach);                  /* H's PRE-shove net component */
          for(m = 0; m < W; ++m) {                          /* mutate list: S, H, V, arms at C */
            int take = 0;
            if(m == ks || m == kH || m == kV) take = 1;
            else if((xctx->wire[m].x1 == Cx && xctx->wire[m].y1 == Cy) ||
                    (xctx->wire[m].x2 == Cx && xctx->wire[m].y2 == Cy)) take = 1;
            if(!take) continue;
            idx[cnt] = m;
            sav[4*cnt] = xctx->wire[m].x1; sav[4*cnt+1] = xctx->wire[m].y1;
            sav[4*cnt+2] = xctx->wire[m].x2; sav[4*cnt+3] = xctx->wire[m].y2;
            ++cnt;
          }
          /* apply: V translates whole; S/H move only their J-end; an arm moves only its C-end */
          for(i = 0; i < cnt; ++i) {
            xWire *w = &xctx->wire[idx[i]];
            if(idx[i] == kV) { w->x1 += shx; w->y1 += shy; w->x2 += shx; w->y2 += shy; }
            else if(idx[i] == ks || idx[i] == kH) {
              if(w->x1 == Jx && w->y1 == Jy) { w->x1 += shx; w->y1 += shy; }
              else                           { w->x2 += shx; w->y2 += shy; }
            } else {                                        /* arm: only its endpoint at C */
              if(w->x1 == Cx && w->y1 == Cy) { w->x1 += shx; w->y1 += shy; }
              else                           { w->x2 += shx; w->y2 += shy; }
            }
            order_wire_coords(idx[i]);
          }
          /* verify: pin-partition preserved AND no shoved segment newly touches FOREIGN copper */
          fluid_loop_partition(NULL, now);
          ok = fluid_part_equal(now, base, np);
          for(i = 0; i < cnt && ok; ++i) {
            for(m = 0; m < W; ++m) {
              int j, inmut = 0;
              if(reach[m]) continue;                        /* already H's net: legitimate */
              for(j = 0; j < cnt; ++j) if(idx[j] == m) { inmut = 1; break; }
              if(inmut) continue;
              if(fluid_wires_touch(m, idx[i])) { ok = 0; break; }
            }
          }
          if(ok) {
            check_collapsing_objects(); trim_wires();        /* drop the collapsed stub + merge collinear */
            fltrace("FLTRACE overshoot: SHOVE stub=%d riser=%d cont=%d J=(%g,%g) T=(%g,%g)\n",
                    ks, kV, kH, Jx, Jy, Tx, Ty);
            progress = 1; shoved = 1; changed_any = 1;
          } else {
            for(i = 0; i < cnt; ++i) {                       /* revert */
              xWire *w = &xctx->wire[idx[i]];
              w->x1 = sav[4*i]; w->y1 = sav[4*i+1]; w->x2 = sav[4*i+2]; w->y2 = sav[4*i+3];
            }
          }
          my_free(_ALLOC_ID_, &idx); my_free(_ALLOC_ID_, &sav); my_free(_ALLOC_ID_, &reach);
        }

        if(!shoved) {                                        /* --- TRIM fallback: delete the dangling stub --- */
          unsigned short *doomed = my_malloc(_ALLOC_ID_, W * sizeof(unsigned short));
          int keep;
          memset(doomed, 0, W * sizeof(unsigned short));
          doomed[ks] = 1;
          fluid_loop_partition(doomed, now);
          keep = fluid_part_equal(now, base, np);
          if(keep) {
            fltrace("FLTRACE overshoot: TRIM stub=%d [%g %g %g %g]\n", ks, sx1, sy1, sx2, sy2);
            wire_delete_compact(wire_doomed_flag, doomed);
            check_collapsing_objects(); trim_wires();
            progress = 1; changed_any = 1;
          }
          my_free(_ALLOC_ID_, &doomed);
        }
      }
    }
  }

  if(changed_any) {
    xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
    prepare_netlist_structs(0);
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
  }
  my_free(_ALLOC_ID_, &base);
  my_free(_ALLOC_ID_, &now);
}

/* issue 0103 (doc/claude/issues/0103-rotate-stretch-dangling-anchor-tails.md): a ROTATED/FLIPPED
 * connected stretch leaves the follow-wire elbow's far leg reaching back to the pin's PRISTINE
 * premove attach point: trim_wires() splits the stationary backbone at the elbow corner and dedups
 * the overlap, so a same-net DANGLING TAIL survives from the corner junction to the now-bare anchor
 * spot (before_7.sch + ALT-R, drop (-40,70) -> after_20.sch's N -190 -40 -120 -40 and
 * N -130 -150 -120 -150). Same net => invisible to the partition accept ladder;
 * remove_move_orphan_wires declines it (the kept end is a rail T, not a moving pin -- move.c:1644);
 * and the tail-capable aesthetic passes (0089/0090/0092) are rotfree-gated. Delete-only, tightly
 * scoped prune:
 *   - novelty-span scoped + auto copper only (never an explicit user lab=, never a bus);
 *   - exactly one FREE end (live touch-degree 0, on no pin) that was an ATTACH POINT at START: a
 *     START wire ENDPOINT (fluid_start_endpoint_at -- pristine anchors are; coord_was_grabbed is
 *     unusable here, its snapshot is re-taken by mid-gesture regrabs at MOVED coords) with START
 *     touch-degree >= 2, so a pre-existing user dangler tip (START degree <= 1) is never pruned;
 *   - the kept end must remain a junction WITHOUT this wire (touch-degree >= 2), so removal never
 *     strands the junction and a bend continuation (degree 1) is never eaten;
 *   - never a wire on a USER-selected wire's touch-component (fluid_mark_user_protected, the 0091
 *     "selection wins" policy the sibling passes follow): novelty-SPAN alone would also match a
 *     user-selected pin-free wire that RODE the rotation and happened to land its dangling tip on
 *     a vacated anchor spot -- the partition verify is blind to pin-free copper, so prot[] is the
 *     guard that keeps the user's own wire alive;
 *   - per-doom pin-partition verify (fluid_loop_partition with the candidate doomed vs pass entry):
 *     a pin lying anywhere ON the tail would lose copper and trips the verify, so the doom is
 *     dropped rather than committed.
 * Caller gates on the rotated/flipped fluid END path => byte-identical for pure translations. */
static void fluid_prune_anchor_tails(void)
{
  int i, np, removed = 0;
  unsigned short *doomed = NULL;
  unsigned char *prot = NULL;
  int *base = NULL, *now = NULL;
  if(xctx->wires == 0 || fluid_g.start_nwire <= 0) return;   /* no START snapshot => cannot scope/verify */
  np = fluid_count_pins();
  if(np <= 0) return;
  my_realloc(_ALLOC_ID_, &doomed, xctx->wires * sizeof(unsigned short));
  memset(doomed, 0, xctx->wires * sizeof(unsigned short));
  base = my_malloc(_ALLOC_ID_, np * sizeof(int));
  now  = my_malloc(_ALLOC_ID_, np * sizeof(int));
  prot = my_malloc(_ALLOC_ID_, xctx->wires * sizeof(unsigned char));
  fluid_mark_user_protected(prot);                         /* issue 0091: never doom the user's own net */
  fluid_loop_partition(NULL, base);                        /* pass-entry partition = invariant target */
  for(i = 0; i < xctx->wires; i++) {
    double ax = xctx->wire[i].x1, ay = xctx->wire[i].y1;
    double bx = xctx->wire[i].x2, by = xctx->wire[i].y2;
    double fx, fy, kx, ky;
    int f1, f2;
    if(ax == bx && ay == by) continue;                     /* degenerate: check_collapsing's job */
    if(xctx->wire[i].bus != 0.0) continue;
    if(prot[i]) continue;                                  /* 0091 "selection wins": user's own net */
    if(fluid_wire_explicit_lab(i)) continue;               /* explicit name: deleting could rename */
    if(!fluid_wire_is_novel_span(i)) continue;             /* only copper THIS drag produced */
    f1 = fluid_deg_at(ax, ay, doomed, i) == 0 && !point_on_any_pin(ax, ay);
    f2 = fluid_deg_at(bx, by, doomed, i) == 0 && !point_on_any_pin(bx, by);
    if(f1 == f2) continue;                                 /* need exactly one free (dangling) end */
    if(f1) { fx = ax; fy = ay; kx = bx; ky = by; }
    else   { fx = bx; fy = by; kx = ax; ky = ay; }
    fltrace("FLTRACE anchor-tail: cand w=%d [%g %g %g %g] free=(%g,%g) startep=%d startdeg=%d keptdeg=%d\n",
            i, ax, ay, bx, by, fx, fy, fluid_start_endpoint_at(fx, fy),
            fluid_start_deg_at(fx, fy), fluid_deg_at(kx, ky, doomed, i));
    if(!fluid_start_endpoint_at(fx, fy)) continue;         /* free end must be a pristine attach spot */
    if(fluid_start_deg_at(fx, fy) < 2) continue;           /* drag-orphaned junction, never a user tip */
    if(fluid_deg_at(kx, ky, doomed, i) < 2) continue;      /* kept end must stay a real junction */
    doomed[i] = 1;
    fluid_loop_partition(doomed, now);
    if(memcmp(base, now, np * sizeof(int))) { doomed[i] = 0; fltrace("FLTRACE anchor-tail: w=%d partition veto\n", i); continue; }
    removed++;
  }
  if(removed) {
    wire_delete_compact(wire_doomed_flag, doomed);
    xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
    fltrace("FLTRACE anchor-tail: pruned %d dangling pristine-anchor tail(s)\n", removed);
  }
  my_free(_ALLOC_ID_, &doomed);
  my_free(_ALLOC_ID_, &prot);
  my_free(_ALLOC_ID_, &base);
  my_free(_ALLOC_ID_, &now);
}

/* issue 0104 helper: number of pin PAIRS whose together/apart relation in rep[] (a live
 * fluid_loop_partition result) disagrees with the GEOMETRIC START snapshot fluid_g.geo_snap_id --
 * 0 iff the two partitions are equivalent. Geometry-to-geometry on purpose: the node[]-NAME
 * snapshot (fluid_g.snap_id) merges disjoint same-name islands and skips netlist-ignored wires, so
 * comparing it against geometry either never reaches 0 (pass permanently inert in any multi-island
 * GND/VDD schematic) or blesses a doom the names cannot see (review wf_506236ef). Both arrays are
 * smallest-pin-index canonical, but compare class STRUCTURE anyway -- robust to id-scheme drift.
 * Not comparable (no snapshot / pin-count drift) returns "maximally different": a 0 return is what
 * COMMITS a doom, so the fail-safe direction is "don't commit". */
static int fluid_part_diff_pairs(int *rep, int np)
{
  int i, j, d = 0;
  if(!fluid_g.geo_snap_id || np != fluid_g.geo_snap_npins || np <= 0) return np * (np - 1) / 2 + 1;
  for(i = 1; i < np; ++i)
    for(j = 0; j < i; ++j)
      if((rep[j] == rep[i]) != (fluid_g.geo_snap_id[j] == fluid_g.geo_snap_id[i])) ++d;
  return d;
}

/* issue 0104 (doc/claude/issues/0104-rotate-stretch-sibling-routes-collide-at-stale-anchor.md): a
 * ROTATED connected stretch can leave one moved pin's elbow far leg reaching back to that pin's
 * PRISTINE premove attach point (the 0103 tail shape) while the SIBLING pin's follow wire -- a
 * degenerate straight run with no elbow freedom -- passes exactly THROUGH that stale anchor
 * coordinate (before_7.sch + ALT-R, drop (-30,70): pin0's x lands on the anchor's own column).
 * The endpoint touch merges the two nets across the device; every accept-ladder attempt is equally
 * shorted, so the shorted ortho result is kept and saved (after_21.sch).
 *
 * Why the neighbours don't own it: 0103's prune requires the tail end DANGLING (touch-deg 0) -- here
 * the crossing route gives it degree 2 -- and its verify direction PRESERVES the (already shorted)
 * pass-entry partition, while the fix must CHANGE it back to START. 0094/0098's rip-up keys on a
 * device PIN sitting on foreign copper -- no pin sits at the anchor. The 0085/0086 elbow classifiers
 * only choose BETWEEN two L orientations sharing the same endpoints; the anchor endpoint itself is
 * the hazard, common to both.
 *
 * So: delete-only de-short. Strict no-op unless the GEOMETRIC pin-partition ALREADY differs from the
 * geometric START snapshot (fluid_part_diff_pairs > 0; nothing to fix => byte-identical for every
 * clean drag). Candidate = non-bus, unlabeled, non-user-protected (0091), novel-SPAN (a pristine
 * backbone remnant split at the elbow corner tests novel too -- span-based, not id-based) wire with
 * one end F on a pristine attach spot (a START wire endpoint, START touch-deg >= 2, on no pin) that
 * is still touched by OTHER copper (deg >= 1 -- the crossing route; a deg-0 dangling tail is 0103's,
 * keeping the domains disjoint), whose other end K stays a junction without it (deg >= 2), and with
 * a clean interior (fluid_loop_interior_clean: no wire T-tap or pin mid-span -- deleting under a tap
 * would silently sever a pin-less lab= branch the pin-partition verify cannot see, review
 * wf_506236ef). Dooms accumulate GREEDILY to a fixpoint: a doom is kept only if it strictly reduces
 * the pair-disagreement count vs START (fluid_part_diff_pairs), and the accumulated set is committed
 * ONLY when the count reaches 0 -- the partition over the remaining wires is exactly the START one
 * (the 0094/0098 "must RESTORE START" verify direction, computed geometrically so no netlist rebuild
 * is needed mid-scan). Anything short of a full restore reverts every doom: the pass either de-shorts
 * provably or leaves the scene byte-identical. Multi-short scenes (two devices, two stale-anchor
 * tails) converge because each tail's doom removes its own disagreeing pairs independently. */
static void fluid_prune_shorting_anchor_tails(void)
{
  int i, np, removed = 0, curdiff, progress;
  unsigned short *doomed = NULL;
  unsigned char *prot = NULL;
  int *now = NULL;
  if(xctx->wires == 0 || fluid_g.start_nwire <= 0) return;   /* no START snapshot => cannot scope/verify */
  if(!fluid_g.geo_snap_id || fluid_g.geo_snap_npins <= 0) return;
  np = fluid_count_pins();
  if(np != fluid_g.geo_snap_npins) return;                   /* instance set changed: not comparable */
  now = my_malloc(_ALLOC_ID_, np * sizeof(int));
  if(fluid_loop_partition(NULL, now) != np) { my_free(_ALLOC_ID_, &now); return; }
  curdiff = fluid_part_diff_pairs(now, np);
  if(curdiff == 0) {
    my_free(_ALLOC_ID_, &now);                             /* geometry matches START: clean drag */
    return;
  }
  my_realloc(_ALLOC_ID_, &doomed, xctx->wires * sizeof(unsigned short));
  memset(doomed, 0, xctx->wires * sizeof(unsigned short));
  prot = my_malloc(_ALLOC_ID_, xctx->wires * sizeof(unsigned char));
  fluid_mark_user_protected(prot);                         /* issue 0091: never doom the user's own net */
  do {
    progress = 0;
    for(i = 0; i < xctx->wires && curdiff > 0; i++) {
      double ax = xctx->wire[i].x1, ay = xctx->wire[i].y1;
      double bx = xctx->wire[i].x2, by = xctx->wire[i].y2;
      int e, nd, hit = 0;
      if(doomed[i]) continue;
      if(ax == bx && ay == by) continue;                   /* degenerate: check_collapsing's job */
      if(xctx->wire[i].bus != 0.0) continue;
      if(prot[i]) continue;                                /* 0091 "selection wins": user's own net */
      if(fluid_wire_explicit_lab(i)) continue;             /* explicit name: deleting could rename */
      if(!fluid_wire_is_novel_span(i)) continue;           /* only spans THIS drag produced */
      for(e = 0; e < 2 && !hit; ++e) {                     /* either end may be the stale anchor F */
        double fx = e ? bx : ax, fy = e ? by : ay;
        double kx = e ? ax : bx, ky = e ? ay : by;
        if(!fluid_start_endpoint_at(fx, fy)) continue;     /* F must be a pristine attach spot */
        if(fluid_start_deg_at(fx, fy) < 2) continue;       /* ...that was a junction, not a user tip */
        if(point_on_any_pin(fx, fy)) continue;             /* pin at F = 0098 rip-up territory */
        if(fluid_deg_at(fx, fy, doomed, i) < 1) continue;  /* crossing copper present (deg 0 = 0103) */
        if(fluid_deg_at(kx, ky, doomed, i) < 2) continue;  /* kept end must stay a real junction */
        hit = 1;
      }
      if(!hit) continue;
      if(!fluid_loop_interior_clean(i, doomed)) continue;  /* mid-span tap: severing risk, decline */
      doomed[i] = 1;
      if(fluid_loop_partition(doomed, now) == np &&
         (nd = fluid_part_diff_pairs(now, np)) < curdiff) {
        fltrace("FLTRACE short-tail: doomed w=%d [%g %g %g %g] diff %d -> %d\n",
                i, ax, ay, bx, by, curdiff, nd);
        curdiff = nd; removed++; progress = 1;
        continue;
      }
      doomed[i] = 0;
      fltrace("FLTRACE short-tail: cand w=%d [%g %g %g %g] doom does not approach START -> keep\n",
              i, ax, ay, bx, by);
    }
  } while(progress && curdiff > 0);
  if(removed && curdiff == 0) {                            /* full START restore proven: commit */
    wire_delete_compact(wire_doomed_flag, doomed);
    check_collapsing_objects(); trim_wires();              /* re-merge the route split at the anchor */
    xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
    prepare_netlist_structs(0);
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
    fltrace("FLTRACE short-tail: pruned %d shorting tail(s), START partition restored\n", removed);
  } else if(removed) {
    fltrace("FLTRACE short-tail: partial improvement only (diff=%d), all %d doom(s) reverted\n",
            curdiff, removed);
  }
  my_free(_ALLOC_ID_, &doomed);
  my_free(_ALLOC_ID_, &prot);
  my_free(_ALLOC_ID_, &now);
}

/* issue 0098: route-AROUND fallback for fluid_ripup_foreign_pin_short. When a connected stretch lands a
 * device pin Q mid-line on a foreign net's backbone that the whole-backbone slide CANNOT move -- its far
 * anchor pins it (before_7.sch: C12 pins #net3 at Q's row y=-160 and its OTHER pin one grid family away,
 * so sliding the backbone to Q's sibling row just SWAPS the short onto C12.p) -- JOG the backbone one grid
 * AROUND Q's pin instead: clip the backbone away from a one-grid gap centred on Q and bridge the gap with
 * a 3-segment bump on whichever perpendicular side clears. Reshape/add-only + pin-partition VERIFIED to
 * RESTORE the START partition (fluid_partition_changed()==0), so it can only de-short or decline (revert).
 * vertaxis==1: backbone horizontal on Q's row (bump in y); vertaxis==0: vertical on Q's column (bump in x).
 * Returns 1 iff a clean jog was committed. See doc/claude/issues/0098-fluid-stretch-pin-on-sibling-net-backbone-short.md */
static int fluid_jog_is_doomed(int n, void *arg) { (void)arg; return n >= fluid_g.jog_doomed_from; }

static int fluid_jog_pin_off_backbone(double qx, double qy, int vertaxis)
{
  double grid = tclgetdoublevar("cadsnap");
  double qL, qR;                          /* gap [qL,qR] centred on Q along the backbone axis */
  int W, m, ci, nbb = 0, left_ok = 0, right_ok = 0, covers_q = 0, guard;
  int bb[64];                             /* backbone wire indices overlapping the gap, extending beyond */
  double sc[64][4], nc[64][4];            /* saved (revert) + clipped-primary coords */
  double ex[64][4]; int nex = 0;          /* straddle-split right pieces to re-add */
  char *bbprop = NULL;

  if(grid <= 0.0) grid = 10.0;
  qL = (vertaxis ? qx : qy) - grid;
  qR = (vertaxis ? qx : qy) + grid;
  W = xctx->wires;
  /* issue 0106: EXPAND the gap outward until both bump legs land on clean backbone interior.
   * A plain attached drag can park the pin's whole follow cluster -- its stub, its riser's
   * T-junction -- ON the backbone line right next to the pin (before_8.sch R18 dragged
   * (0,-40): stub [-80,-70] and the capa riser T at -80 sit one grid left of the pin at -70).
   * With the fixed one-grid gap a bump leg lands exactly on that copper and WELDS the two
   * nets this jog must separate (or the old whole-tiny-wire-in-gap test bailed outright).
   * A boundary is dirty when a perpendicular wire occupies that column across the bump band,
   * when a row wire ends there without extending outward past the gap, or when two row wires
   * meet there; push the dirty side out one grid and re-scan. Cluster copper swallowed
   * strictly inside the gap is left untouched by the clip pass below. */
  for(guard = 0; guard < 16; ++guard) {
    int dirtyL = 0, dirtyR = 0, nendL = 0, nendR = 0;
    for(m = 0; m < W; ++m) {
      xWire *w = &xctx->wire[m];
      double lo, hi, col, plo, phi;
      int onrow = vertaxis ? (w->y1 == qy && w->y2 == qy && w->x1 != w->x2)
                           : (w->x1 == qx && w->x2 == qx && w->y1 != w->y2);
      int perp  = vertaxis ? (w->x1 == w->x2 && w->y1 != w->y2)
                           : (w->y1 == w->y2 && w->x1 != w->x2);
      if(onrow) {
        if(vertaxis) { lo = w->x1 < w->x2 ? w->x1 : w->x2; hi = w->x1 < w->x2 ? w->x2 : w->x1; }
        else         { lo = w->y1 < w->y2 ? w->y1 : w->y2; hi = w->y1 < w->y2 ? w->y2 : w->y1; }
        if(lo == qL || hi == qL) { if(++nendL > 1) dirtyL = 1; if(lo == qL && hi <= qR) dirtyL = 1; }
        if(lo == qR || hi == qR) { if(++nendR > 1) dirtyR = 1; if(hi == qR && lo >= qL) dirtyR = 1; }
      } else if(perp) {
        col = vertaxis ? w->x1 : w->y1;
        if(vertaxis) { plo = w->y1 < w->y2 ? w->y1 : w->y2; phi = w->y1 < w->y2 ? w->y2 : w->y1; }
        else         { plo = w->x1 < w->x2 ? w->x1 : w->x2; phi = w->x1 < w->x2 ? w->x2 : w->x1; }
        if(plo <= (vertaxis ? qy : qx) + grid && phi >= (vertaxis ? qy : qx) - grid) {
          if(col == qL) dirtyL = 1;
          if(col == qR) dirtyR = 1;
        }
      }
    }
    if(!dirtyL && !dirtyR) break;
    if(dirtyL) qL -= grid;
    if(dirtyR) qR += grid;
  }
  if(guard >= 16) { my_free(_ALLOC_ID_, &bbprop); return 0; }                 /* no clean bump legs found */
  for(m = 0; m < W; ++m) {
    xWire *w = &xctx->wire[m];
    double lo, hi, kl, kh;
    int online = vertaxis ? (w->y1 == qy && w->y2 == qy && w->x1 != w->x2)   /* horizontal on Q's row */
                          : (w->x1 == qx && w->x2 == qx && w->y1 != w->y2);   /* vertical on Q's column */
    if(!online || w->bus != 0.0) continue;
    if(vertaxis) { lo = w->x1 < w->x2 ? w->x1 : w->x2; hi = w->x1 < w->x2 ? w->x2 : w->x1; }
    else         { lo = w->y1 < w->y2 ? w->y1 : w->y2; hi = w->y1 < w->y2 ? w->y2 : w->y1; }
    if(hi < qL || lo > qR) continue;                                          /* clear of the gap */
    if(lo >= qL && hi <= qR) continue;                                        /* 0106: swallowed cluster copper: keep intact */
    if(fluid_wire_explicit_lab(m)) { my_free(_ALLOC_ID_, &bbprop); return 0; }/* never reshape named copper */
    if(nbb >= 64 || nex >= 63) { my_free(_ALLOC_ID_, &bbprop); return 0; }
    if(lo < qL) left_ok = 1;
    if(hi > qR) right_ok = 1;
    if(touch(w->x1, w->y1, w->x2, w->y2, qx, qy)) covers_q = 1;
    bb[nbb] = m;
    sc[nbb][0]=w->x1; sc[nbb][1]=w->y1; sc[nbb][2]=w->x2; sc[nbb][3]=w->y2;
    /* clip away the OPEN gap (qL,qR): keep the left piece [lo,qL] as the primary (or the right piece
     * [qR,hi] when the wire lies entirely to Q's right); a straddle keeps left primary + right extra. */
    if(lo < qL) { kl = lo; kh = (hi < qL ? hi : qL); }
    else        { kl = (lo > qR ? lo : qR); kh = hi; }
    if(vertaxis) { nc[nbb][0]=kl; nc[nbb][1]=qy; nc[nbb][2]=kh; nc[nbb][3]=qy; }
    else         { nc[nbb][0]=qx; nc[nbb][1]=kl; nc[nbb][2]=qx; nc[nbb][3]=kh; }
    if(lo < qL && hi > qR) {                                                  /* straddle: re-add right */
      if(vertaxis) { ex[nex][0]=qR; ex[nex][1]=qy; ex[nex][2]=hi; ex[nex][3]=qy; }
      else         { ex[nex][0]=qx; ex[nex][1]=qR; ex[nex][2]=qx; ex[nex][3]=hi; }
      ++nex;
    }
    if(!bbprop) my_strdup(_ALLOC_ID_, &bbprop, w->prop_ptr);                  /* bump inherits backbone lab */
    ++nbb;
  }
  /* covers_q: some clipped wire must actually carry Q, else this is not Q's backbone at all */
  if(nbb == 0 || !left_ok || !right_ok || !covers_q) { my_free(_ALLOC_ID_, &bbprop); return 0; }

  for(ci = 0; ci < 2; ++ci) {                                    /* try both perpendicular bump sides */
    double dir = (ci == 0) ? -grid : grid;
    int i;
    fluid_g.jog_doomed_from = xctx->wires;                         /* every wire added below is revertible */
    for(i = 0; i < nbb; ++i) {                                   /* apply clipped primaries in place */
      xctx->wire[bb[i]].x1 = nc[i][0]; xctx->wire[bb[i]].y1 = nc[i][1];
      xctx->wire[bb[i]].x2 = nc[i][2]; xctx->wire[bb[i]].y2 = nc[i][3];
      order_wire_coords(bb[i]);
    }
    for(i = 0; i < nex; ++i) {                                   /* re-add straddle right pieces */
      storeobject(-1, ex[i][0], ex[i][1], ex[i][2], ex[i][3], WIRE, 0, 0, bbprop);
      order_wire_coords(xctx->wires - 1);
    }
    if(vertaxis) {                                               /* 3-seg bump bridging (qL..qR) at +dir */
      storeobject(-1, qL, qy,       qL, qy + dir, WIRE, 0, 0, bbprop);
      order_wire_coords(xctx->wires - 1);
      storeobject(-1, qL, qy + dir, qR, qy + dir, WIRE, 0, 0, bbprop);
      order_wire_coords(xctx->wires - 1);
      storeobject(-1, qR, qy + dir, qR, qy,       WIRE, 0, 0, bbprop);
      order_wire_coords(xctx->wires - 1);
    } else {
      storeobject(-1, qx,       qL, qx + dir, qL, WIRE, 0, 0, bbprop);
      order_wire_coords(xctx->wires - 1);
      storeobject(-1, qx + dir, qL, qx + dir, qR, WIRE, 0, 0, bbprop);
      order_wire_coords(xctx->wires - 1);
      storeobject(-1, qx + dir, qR, qx,       qR, WIRE, 0, 0, bbprop);
      order_wire_coords(xctx->wires - 1);
    }
    xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
    prepare_netlist_structs(0);
    if(fluid_partition_changed() == 0) {                         /* START pin-partition RESTORED: keep */
      fltrace("FLTRACE ripup: jogged backbone around pin (%g,%g) %s side=%g (%d bb,%d extra)\n",
              qx, qy, vertaxis ? "vert" : "horiz", dir, nbb, nex);
      my_free(_ALLOC_ID_, &bbprop);
      return 1;
    }
    for(i = 0; i < nbb; ++i) {                                   /* revert: restore primaries ... */
      xctx->wire[bb[i]].x1 = sc[i][0]; xctx->wire[bb[i]].y1 = sc[i][1];
      xctx->wire[bb[i]].x2 = sc[i][2]; xctx->wire[bb[i]].y2 = sc[i][3];
      order_wire_coords(bb[i]);
    }
    wire_delete_compact(fluid_jog_is_doomed, NULL);              /* ... and drop every added wire */
    xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
    prepare_netlist_structs(0);
  }
  my_free(_ALLOC_ID_, &bbprop);
  return 0;
}

/* issue 0094: rip up a move-created DEVICE SHORT where a rigid group drag landed one of a moved device's
 * pins exactly on a foreign net's backbone wire (before_5.sch C12+R18+#net2 dragged (-40,+70): R18's #net2
 * top pin lands on the #net1 backbone at (-300,-10) -> #net1==#net2). The pin position is fixed by the
 * rigid move, so only the foreign copper can move out of the way -- the deferred nice_drag_rerouting
 * Phase-4 "no-short + rip-up". Detect the merge vs the START snapshot (two pins of one device on DISTINCT
 * nets at START, one net now); the INVADER pin P sits on a backbone B perpendicular to the P->sibling(Q)
 * axis, where Q is the pin whose START net is B's net. Slide B's whole touch-connected collinear span from
 * P's line onto Q's line: P is un-shorted and Q is reached directly. The follow-riser/column tails this
 * orphans are pruned by fluid_straighten_reversals, which runs next. Every slide is pin-partition VERIFIED
 * to RESTORE the START partition (fluid_partition_changed()==0) and reverted otherwise; a fixpoint handles
 * more than one merged device. Strict no-op unless a move-created merge exists (the common path is
 * byte-identical). Caller-gated on fluid_editing (default off => never runs). See
 * doc/claude/issues/0094-fluid-group-drag-offpin-lands-foreign-backbone-short-loop.md. */
static int fluid_ripup_foreign_pin_short(void)
{
  int guard = 0, changed_any = 0;
  if(xctx->wires < 3) return 0;
  if(fluid_failsafe(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0)) return 0;
  if(fluid_failsafe(fluid_count_pins() != fluid_g.snap_npins)) return 0;
  for(;;) {
    int i, p, q, k, fixed = 0;
    if(guard++ > fluid_g.snap_npins + 4) break;              /* progress backstop */
    xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
    prepare_netlist_structs(0);
    if(fluid_count_pins() != fluid_g.snap_npins) break;
    if(fluid_partition_changed() == 0) break;              /* no move-created merge/disconnect (common) */
    k = 0;
    for(i = 0; i < xctx->instances && !fixed; ++i) {
      int base, npins;
      const char *type;
      if(xctx->inst[i].ptr < 0) continue;
      npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
      base = k; k += npins;                                /* advance k for EVERY instance (mirror snapshot) */
      if(k > fluid_g.snap_npins) break;                      /* structure drift guard */
      type = xctx->sym[xctx->inst[i].ptr].type;
      if(type && !strcmp(type, "label")) continue;         /* net-label pins echo lab=; not a device */
      for(p = 0; p < npins && !fixed; ++p) {
        const char *sp = fluid_g.snap_pinnet[base + p];
        double px, py;
        if(!sp || !sp[0]) continue;
        get_inst_pin_coord(i, p, &px, &py);
        for(q = 0; q < npins && !fixed; ++q) {
          const char *sq = fluid_g.snap_pinnet[base + q];
          /* Re-read BOTH live pin net names EACH q: a declined slide below calls
           * prepare_netlist_structs(0), which frees+rebuilds inst[].node[] -- a pointer hoisted to
           * the p-loop would DANGLE on the next q (use-after-free, review wf_fe8ba9a4). sp/sq are the
           * START snapshot (stable until move END), only ap/aq are live node[]. */
          const char *ap = (xctx->inst[i].node && xctx->inst[i].node[p]) ? xctx->inst[i].node[p] : NULL;
          const char *aq = (xctx->inst[i].node && xctx->inst[i].node[q]) ? xctx->inst[i].node[q] : NULL;
          double qx, qy, target;
          int vertaxis, m, W = xctx->wires, nslid = 0, named = 0, ok;
          int *slid;
          double *sv;
          unsigned char *reach;
          if(q == p) continue;
          if(!ap || !ap[0] || !sq || !sq[0] || !aq || !aq[0]) continue;
          if(!strcmp(sp, sq)) continue;                    /* same net at START: not a merge pair */
          if(strcmp(ap, aq)) continue;                     /* not merged now */
          get_inst_pin_coord(i, q, &qx, &qy);
          /* P and Q must be axis-aligned so the perpendicular backbone slides cleanly onto Q's line */
          if(px == qx && py != qy) vertaxis = 1;           /* P->Q vertical => backbone horizontal */
          else if(py == qy && px != qx) vertaxis = 0;      /* P->Q horizontal => backbone vertical */
          else continue;
          target = vertaxis ? qy : qx;
          slid = my_malloc(_ALLOC_ID_, (W > 0 ? W : 1) * sizeof(int));
          sv   = my_malloc(_ALLOC_ID_, (W > 0 ? W : 1) * 4 * sizeof(double));
          /* seed: backbone = perpendicular wires on P's line that carry P on their span */
          for(m = 0; m < W; ++m) {
            xWire *w = &xctx->wire[m];
            int perp = vertaxis ? (w->y1 == w->y2 && w->x1 != w->x2 && w->y1 == py)
                                : (w->x1 == w->x2 && w->y1 != w->y2 && w->x1 == px);
            if(perp && touch(w->x1, w->y1, w->x2, w->y2, px, py)) {
              if(fluid_wire_explicit_lab(m)) named = 1;    /* never reshape explicitly-named copper */
              slid[nslid++] = m;
            }
          }
          /* flood: add touch-connected perpendicular wires on the same line (the full collinear span) */
          if(!named) {
            int added = 1;
            while(added) {
              added = 0;
              for(m = 0; m < W; ++m) {
                xWire *w = &xctx->wire[m];
                int perp = vertaxis ? (w->y1 == w->y2 && w->x1 != w->x2 && w->y1 == py)
                                    : (w->x1 == w->x2 && w->y1 != w->y2 && w->x1 == px);
                int j, dup = 0;
                if(!perp) continue;
                for(j = 0; j < nslid; ++j) if(slid[j] == m) { dup = 1; break; }
                if(dup) continue;
                for(j = 0; j < nslid; ++j) if(fluid_wires_touch(m, slid[j])) {
                  if(fluid_wire_explicit_lab(m)) named = 1;
                  slid[nslid++] = m; added = 1; break;
                }
              }
            }
          }
          if(named) { my_free(_ALLOC_ID_, &slid); my_free(_ALLOC_ID_, &sv); continue; }
          if(nslid == 0) {
            /* issue 0105: no perpendicular backbone carries P at all. The shorting copper can
             * instead lie ALONG the P->Q axis: a connected move drops the device back onto the
             * very backbone that fed Q, so ONE collinear wire now covers BOTH pins (before_8.sch
             * R18 (-90,-40): both pins land on the old #net1 run at y=-40 -> bridged under the
             * body). No slide can help (the backbone cannot slide along its own axis away from
             * pins ON it) -- jog it one grid around P instead. Around-Q would gap Q off its own
             * net and the jog's partition verify rejects it, so P is the only candidate; the
             * mirrored (q,p) pair iteration covers the case where the invader roles are swapped. */
            if(fluid_jog_pin_off_backbone(px, py, !vertaxis)) { fixed = 1; changed_any = 1; }
            my_free(_ALLOC_ID_, &slid); my_free(_ALLOC_ID_, &sv);
            continue;
          }
          /* reach = the backbone's PRE-slide wire component, for the pin-less foreign-short guard below
           * (fluid_partition_changed is pin-indexed and blind to a merge onto a labeled net with no
           * device pin -- same gap fluid_slide_merges_foreign closes for the straighten slide). */
          reach = my_malloc(_ALLOC_ID_, (W > 0 ? W : 1) * sizeof(unsigned char));
          fluid_wire_reach_set(slid[0], reach);
          for(m = 0; m < nslid; ++m) {                     /* save + slide the backbone onto Q's line */
            xWire *w = &xctx->wire[slid[m]];
            sv[4*m+0] = w->x1; sv[4*m+1] = w->y1; sv[4*m+2] = w->x2; sv[4*m+3] = w->y2;
            if(vertaxis) { w->y1 = w->y2 = target; } else { w->x1 = w->x2 = target; }
            order_wire_coords(slid[m]);
          }
          xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
          prepare_netlist_structs(0);
          ok = (fluid_partition_changed() == 0);           /* slide must RESTORE the START partition */
          if(ok) {                                         /* + no slid wire newly touches FOREIGN copper */
            int a, b;
            for(a = 0; a < nslid && ok; ++a)
              for(b = 0; b < W; ++b)
                if(!reach[b] && fluid_wires_touch(b, slid[a])) { ok = 0; break; }
          }
          /* NB: no P5 no-body-cross guard here (unlike the straighten staircase collapse). A slid
           * backbone that grazes a stationary device body WITHOUT hitting its pins is electrically
           * clean (a pin-hitting cross is a merge the partition-verify above already rejects), so
           * declining it would re-introduce the HARD short this pass exists to remove -- and P2
           * (no-short) OUTRANKS P5 (no-body-cross) in the conflict order. Route-around is deferred. */
          if(ok) {
            fltrace("FLTRACE ripup: '%s' pins %d(%s)/%d(%s) unshort; slid %d backbone wire(s) %s->%g\n",
                    xctx->inst[i].instname ? xctx->inst[i].instname : "?", p, sp, q, sq, nslid,
                    vertaxis ? "y" : "x", target);
            fixed = 1; changed_any = 1;
          } else {
            for(m = 0; m < nslid; ++m) {                    /* revert the whole-backbone slide */
              xWire *w = &xctx->wire[slid[m]];
              w->x1 = sv[4*m+0]; w->y1 = sv[4*m+1]; w->x2 = sv[4*m+2]; w->y2 = sv[4*m+3];
              order_wire_coords(slid[m]);
            }
            /* issue 0098: the slide could not move the anchored backbone off Q -- try the local
             * route-around jog (bump the backbone one grid AROUND Q's pin). Q is the pin that landed
             * on the foreign backbone (the merge sits on Q's line, perpendicular to Q's riser). */
            if(fluid_jog_pin_off_backbone(qx, qy, vertaxis)) { fixed = 1; changed_any = 1; }
            /* issue 0105: the perpendicular copper the slide seeded was P's OWN follow riser, not
             * the shorting backbone -- the short is a COLLINEAR backbone along the P->Q axis
             * covering both pins (device dropped back onto the wire that fed Q). Jog it around P;
             * the jog's partition verify makes a wrong-pin attempt a clean no-op. */
            else if(fluid_jog_pin_off_backbone(px, py, !vertaxis)) { fixed = 1; changed_any = 1; }
          }
          my_free(_ALLOC_ID_, &reach);
          my_free(_ALLOC_ID_, &slid); my_free(_ALLOC_ID_, &sv);
        }
      }
    }
    if(!fixed) break;                                      /* a merge we cannot rip up: leave to log-only */
    trim_wires();
    check_collapsing_objects();
  }
  if(changed_any) {
    xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
    prepare_netlist_structs(0);
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
  }
  return changed_any;
}

/* issue 0094 tail: after fluid_ripup_foreign_pin_short slides a backbone onto the sibling pin and
 * fluid_straighten_reversals prunes the START-junction follow-riser, the slid backbone's far span can be
 * left as a FRESH dangling stub past the sibling pin (before_5.sch (-40,+70): #net1 (-300,50)-(-260,50)) --
 * an orphan whose free end touched NO START copper, so straighten's START-scoped retract leaves it. Delete
 * such purely-novel dangling stubs, connectivity-VERIFIED (fluid_loop_partition preserved). Only called
 * when the rip-up fired, so it is a strict no-op (byte-identical) on every non-shorting drag. */
static void fluid_prune_novel_orphan_stub(void)
{
  int np, guard = 0, progress = 1, npins;
  int *base, *now;
  if(xctx->wires < 2 || fluid_g.snap_npins <= 0) return;
  npins = fluid_count_pins() > 0 ? fluid_count_pins() : 1;
  base = my_malloc(_ALLOC_ID_, npins * sizeof(int));
  now  = my_malloc(_ALLOC_ID_, npins * sizeof(int));
  xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
  prepare_netlist_structs(0);
  np = fluid_loop_partition(NULL, base);
  while(progress && guard++ < 4 * xctx->wires + 8) {
    int kd, W = xctx->wires;
    progress = 0;
    for(kd = 0; kd < W && !progress; ++kd) {
      int e;
      for(e = 0; e < 2 && !progress; ++e) {
        double ex = e ? xctx->wire[kd].x2 : xctx->wire[kd].x1;
        double ey = e ? xctx->wire[kd].y2 : xctx->wire[kd].y1;
        if(point_on_any_pin(ex, ey)) continue;             /* a pin end is never dangling */
        if(fluid_wire_explicit_lab(kd)) continue;          /* never delete named copper */
        if(fluid_deg_at(ex, ey, NULL, kd) != 0) continue;  /* still connected: not a dangling end */
        if(fluid_start_deg_at(ex, ey) != 0) continue;      /* touched START copper: not a fresh orphan */
        if(fluid_retract_orphan_tail(kd, ex, ey, base, np, now, 0)) progress = 1;
      }
    }
  }
  my_free(_ALLOC_ID_, &base);
  my_free(_ALLOC_ID_, &now);
}

/* issue 0107: an ACCEPTED rigid diagonal relay (attempt 2, partition clean) is saved raw -- its
 * follow wires run pin->anchor DIAGONALLY, violating orthogonal mode (before_8.sch, R18 dragged
 * (-130,-90): both ortho attempts self-collide -- the two follow routes share the anchors' y=0
 * row and one route's riser T-lands on the other's horizontal -- so the relay wins and after_24.sch
 * keeps two non-Manhattan wires). Convert each relay diagonal that starts on a MOVED (selected)
 * device pin into a Manhattan route, best candidate first:
 *
 *   issue 0108 (re-anchor): the diagonal's far endpoint is the pin's STALE pre-move foot -- a point
 *   whose only purpose was serving the old pin position. Blindly L-ing pin->anchor keeps a detour
 *   through the vacated location plus the stale feed copper behind it (after_25.sch: the [0,-40 0,0]
 *   stub and the #net3 route around the old [-80,0] riser foot), and under rot180 the two anchor-Ls
 *   must CROSS each other's route so BOTH orientations verify dirty and the diagonals survive.
 *   So first try RE-ANCHORING: connect the pin to the closest point Q on each same-net wire
 *   (distance-ordered; straight run when aligned, else the two L orientations), each candidate
 *   partition-verified + guarded against welding foreign pin-less copper. Fallback: the 0107
 *   pin->anchor L (two orientations); last resort: keep the diagonal (electrically correct is
 *   better than pretty). After any change, the abandoned stale feed is pruned: dangling ends that
 *   were junctions at START (live touch-deg 0, on no pin, START deg >= 2 -- never a user's own
 *   pre-existing dangler) are retracted/deleted to fixpoint via fluid_retract_orphan_tail, each
 *   action partition-verified, user-protected (0091) and explicit-lab copper excluded.
 *
 * Reshape/add/prune all per-action verified, so the pass can only improve or decline; pristine user
 * diagonals not touching a moved pin are never candidates. Caller-gated on END + accepted relay +
 * orthogonal_wiring + fluid_editing.
 * See doc/claude/issues/0107-fluid-relay-saves-non-manhattan-wires.md and
 * doc/claude/issues/0108-fluid-relay-reanchors-to-stale-feet.md */
static int fluid_manh_is_doomed(int n, void *arg) { (void)arg; return n >= fluid_g.manh_doomed_from; }

/* 0108: closest point Q on the axis-aligned segment (sx1,sy1)-(sx2,sy2) to P (px,py) */
static void fluid_seg_closest_point(double px, double py, double sx1, double sy1,
                                    double sx2, double sy2, double *qx, double *qy)
{
  if(sy1 == sy2) {                                 /* horizontal */
    double lo = sx1 < sx2 ? sx1 : sx2, hi = sx1 < sx2 ? sx2 : sx1;
    *qx = px < lo ? lo : px > hi ? hi : px; *qy = sy1;
  } else {                                         /* vertical */
    double lo = sy1 < sy2 ? sy1 : sy2, hi = sy1 < sy2 ? sy2 : sy1;
    *qy = py < lo ? lo : py > hi ? hi : py; *qx = sx1;
  }
}

/* 0108: would the axis-aligned segment (x1,y1)-(x2,y2) weld (endpoint-on-span, either direction --
 * the netlister's touch model) to any wire whose node differs from `node`? The pin-indexed partition
 * verify is blind to a pin-LESS foreign net (a lab= supply stub with no device pin); this geometric
 * guard closes that hole for the re-anchor legs. Same-net copper is fine to touch -- welding to it
 * is the point. Requires fresh prepare_netlist_structs (reads wire[].node). */
static int fluid_seg_welds_foreign(double x1, double y1, double x2, double y2,
                                   const char *node, int excl)
{
  int m;
  for(m = 0; m < xctx->wires; ++m) {
    const char *wn;
    if(m == excl) continue;
    if(xctx->wire[m].x1 == xctx->wire[m].x2 && xctx->wire[m].y1 == xctx->wire[m].y2) continue;
    wn = xctx->wire[m].node;
    if(node && wn && !strcmp(wn, node)) continue;  /* our own net */
    if(touch(x1, y1, x2, y2, xctx->wire[m].x1, xctx->wire[m].y1) ||
       touch(x1, y1, x2, y2, xctx->wire[m].x2, xctx->wire[m].y2) ||
       touch(xctx->wire[m].x1, xctx->wire[m].y1, xctx->wire[m].x2, xctx->wire[m].y2, x1, y1) ||
       touch(xctx->wire[m].x1, xctx->wire[m].y1, xctx->wire[m].x2, xctx->wire[m].y2, x2, y2))
      return 1;
  }
  return 0;
}

/* PIN-INCLUSIVE body box (world) of instance i = the symbol's NO-TEXT drawn bbox. sym->minx..maxy
 * (calc_symbol_bbox, save.c:4475) span every pin rect, stub line and body polygon but EXCLUDE text
 * (which is instance-variable via @-expansion). This is the "widest bbox that includes all pins" the
 * user routes around -- NOT the tight central body -- so a backbone threading UNDER the top pins
 * counts as a body crossing. Rotation is 0/90/180/270, so rotating the two opposite bbox corners and
 * re-ordering yields the exact world AABB (same construction as symbol_bbox, select.c:499). The
 * text-inflated inst.x1..y2 is deliberately NOT used (its @name halo varies per instance). */
static int fluid_inst_body_box(int i, double *bx1, double *by1, double *bx2, double *by2)
{
  short rot, flip;
  double x0, y0, rx1, ry1, rx2, ry2, t;
  xSymbol *sym;
  if(xctx->inst[i].ptr < 0) return 0;
  rot = xctx->inst[i].rot; flip = xctx->inst[i].flip;
  x0 = xctx->inst[i].x0; y0 = xctx->inst[i].y0;
  sym = xctx->inst[i].ptr + xctx->sym;
  ROTATION(rot, flip, 0.0, 0.0, sym->minx, sym->miny, rx1, ry1);
  ROTATION(rot, flip, 0.0, 0.0, sym->maxx, sym->maxy, rx2, ry2);
  *bx1 = rx1 + x0; *by1 = ry1 + y0; *bx2 = rx2 + x0; *by2 = ry2 + y0;
  if(*bx1 > *bx2) { t = *bx1; *bx1 = *bx2; *bx2 = t; }
  if(*by1 > *by2) { t = *by1; *by1 = *by2; *by2 = t; }
  return 1;
}

/* Does axis-aligned segment [x1,y1]-[x2,y2] strictly enter the PIN-INCLUSIVE body of ANY selected
 * (moved) instance? Same strict-interior test as fluid_seg_crosses_body, WITH its escape-normal
 * exemption: because a pin sits ON the pin-inclusive box, EVERY feed leg touching a pin clips the
 * box -- a leg leaving one of THIS instance's pins along the pin's OUTWARD normal is its own
 * connection, not a crossing; a backbone threading under/through the pins (or a leg diving INWARD)
 * is. Used to PREFER a body-free relay L/Z; never a hard decline. */
static int fluid_seg_crosses_sel_body(double x1, double y1, double x2, double y2)
{
  int i;
  for(i = 0; i < xctx->instances; ++i) {
    double bx1, by1, bx2, by2, slo, shi;
    int crossed = 0, r, rects, exempt = 0;
    if(xctx->inst[i].sel != SELECTED) continue;
    if(!fluid_inst_body_box(i, &bx1, &by1, &bx2, &by2)) continue;   /* already ordered */
    if(x1 == x2) {                                      /* vertical segment at x1 */
      if(x1 <= bx1 || x1 >= bx2) continue;
      slo = y1 < y2 ? y1 : y2; shi = y1 < y2 ? y2 : y1;
      crossed = (slo < by2 && shi > by1);
    } else if(y1 == y2) {                               /* horizontal segment at y1 */
      if(y1 <= by1 || y1 >= by2) continue;
      slo = x1 < x2 ? x1 : x2; shi = x1 < x2 ? x2 : x1;
      crossed = (slo < bx2 && shi > bx1);
    }
    if(!crossed) continue;
    /* escape exemption: a feed leg leaving one of THIS instance's pins OUTWARD is the pin's own
     * connection, not a crossing (the pin sits ON the pin-inclusive box, so every feed leg clips it).
     * Outward = away from the box centre on the dominant axis. NOTE: get_pin_escape_normal() is NOT
     * used -- its nearest-edge heuristic runs on the TEXT-inflated inst.x1..y2 and mis-picks the axis
     * for a pin near a corner (e.g. an output pin 2.5u from both the left and top edges ties to Left),
     * which would reject the correct over-the-top route. Deriving the axis from the pin-inclusive box
     * centre is exact for the 0/90/180/270 pin positions here. */
    {
      double cx = (bx1 + bx2) / 2.0, cy = (by1 + by2) / 2.0;
      rects = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
      for(r = 0; r < rects && !exempt; ++r) {
        double px, py, fx, fy, dx, dy, nx, ny;
        get_inst_pin_coord(i, r, &px, &py);
        if(x1 == px && y1 == py)      { fx = x2; fy = y2; }
        else if(x2 == px && y2 == py) { fx = x1; fy = y1; }
        else continue;
        dx = px - cx; dy = py - cy;
        if(fabs(dx) >= fabs(dy)) { nx = dx >= 0.0 ? 1.0 : -1.0; ny = 0.0; }
        else                     { nx = 0.0; ny = dy >= 0.0 ? 1.0 : -1.0; }
        if(nx * (fx - px) + ny * (fy - py) > 0.0) exempt = 1;
      }
    }
    if(!exempt) return 1;
  }
  return 0;
}

/* union of all selected instances' tight drawn-body boxes (world). 0 if none has a solid body. */
static int fluid_union_sel_body_box(double *bx1, double *by1, double *bx2, double *by2)
{
  int i, seen = 0;
  for(i = 0; i < xctx->instances; ++i) {
    double x1, y1, x2, y2, t;
    if(xctx->inst[i].sel != SELECTED) continue;
    if(!fluid_inst_body_box(i, &x1, &y1, &x2, &y2)) continue;
    if(x1 > x2) { t = x1; x1 = x2; x2 = t; }
    if(y1 > y2) { t = y1; y1 = y2; y2 = t; }
    if(!seen) { *bx1 = x1; *by1 = y1; *bx2 = x2; *by2 = y2; seen = 1; }
    else { if(x1 < *bx1) *bx1 = x1; if(y1 < *by1) *by1 = y1;
           if(x2 > *bx2) *bx2 = x2; if(y2 > *by2) *by2 = y2; }
  }
  return seen;
}

/* 0108: one re-anchor candidate -- connect pin P to Q, optionally via corner C (nbend 1) */
typedef struct { double qx, qy, cx, cy; int nbend; double cost; } Fluid_reanchor_cand;

/* 0108: tentatively reshape relay wire w from P->(diag anchor) to P->Q (straight) or P->C->Q (L).
 * Commits iff the pin-partition still equals START; else reverts geometry exactly. Returns 1 on
 * commit. prp = w's saved prop string (for the added leg). */
static int fluid_try_reanchor(int w, double px, double py, double ax, double ay,
                              const Fluid_reanchor_cand *c, const char *prp)
{
  fluid_g.manh_doomed_from = xctx->wires;            /* any added leg is revertible */
  xctx->wire[w].x1 = px; xctx->wire[w].y1 = py;
  if(c->nbend) {
    xctx->wire[w].x2 = c->cx; xctx->wire[w].y2 = c->cy;
    order_wire_coords(w);
    storeobject(-1, c->cx, c->cy, c->qx, c->qy, WIRE, 0, 0, prp);
    order_wire_coords(xctx->wires - 1);
  } else {
    xctx->wire[w].x2 = c->qx; xctx->wire[w].y2 = c->qy;
    order_wire_coords(w);
  }
  xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
  prepare_netlist_structs(0);
  if(fluid_partition_changed() == 0) return 1;
  xctx->wire[w].x1 = px; xctx->wire[w].y1 = py;    /* revert: restore the diagonal, drop the leg */
  xctx->wire[w].x2 = ax; xctx->wire[w].y2 = ay;
  order_wire_coords(w);
  wire_delete_compact(fluid_manh_is_doomed, NULL);
  xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
  prepare_netlist_structs(0);
  return 0;
}

/* Commit an n-point axis-aligned polyline as relay wire w (its first segment) plus storeobjects for
 * the rest, partition-verify; return 1 on success, else revert EXACTLY (restore the diagonal
 * ox/oy, drop the added legs via the manh_doomed watermark). Same tentative-apply/verify/revert
 * contract as fluid_try_reanchor. */
static int fluid_manh_commit_path(int w, const double *ptx, const double *pty, int n,
                                  double ox1, double oy1, double ox2, double oy2, const char *prp)
{
  int k;
  fluid_g.manh_doomed_from = xctx->wires;
  xctx->wire[w].x1 = ptx[0]; xctx->wire[w].y1 = pty[0];
  xctx->wire[w].x2 = ptx[1]; xctx->wire[w].y2 = pty[1];
  order_wire_coords(w);
  for(k = 1; k < n - 1; ++k) {
    storeobject(-1, ptx[k], pty[k], ptx[k+1], pty[k+1], WIRE, 0, 0, prp);
    order_wire_coords(xctx->wires - 1);
  }
  xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
  prepare_netlist_structs(0);
  if(fluid_partition_changed() == 0) return 1;
  xctx->wire[w].x1 = ox1; xctx->wire[w].y1 = oy1;
  xctx->wire[w].x2 = ox2; xctx->wire[w].y2 = oy2;
  order_wire_coords(w);
  wire_delete_compact(fluid_manh_is_doomed, NULL);
  xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
  prepare_netlist_structs(0);
  return 0;
}

/* Append a compressed axis-aligned candidate path (raw pts rx/ry[0..nr-1]) to the candidate arrays
 * (row stride 5). Drops coincident points, rejects a non-Manhattan or <2-point path. Records leg
 * count + Manhattan length for the shortest-first sort. */
static void fluid_manh_pushpath(double *ax, double *ay, int *an, int *aleg, double *alen, int *na,
                                int cap, const double *rx, const double *ry, int nr)
{
  int k, m = 0, base;
  double len = 0.0;
  if(*na >= cap) return;
  base = *na * 5;
  for(k = 0; k < nr; ++k) {
    if(m > 0 && rx[k] == ax[base+m-1] && ry[k] == ay[base+m-1]) continue;   /* coincident -> drop */
    if(m > 0 && rx[k] != ax[base+m-1] && ry[k] != ay[base+m-1]) return;     /* non-Manhattan -> reject */
    if(m >= 5) return;
    ax[base+m] = rx[k]; ay[base+m] = ry[k]; ++m;
  }
  if(m < 2) return;
  for(k = 0; k < m - 1; ++k) len += fabs(ax[base+k+1]-ax[base+k]) + fabs(ay[base+k+1]-ay[base+k]);
  an[*na] = m; aleg[*na] = m - 1; alen[*na] = len; ++(*na);
}

/* issue 0130/0133: shape ONE accepted relay diagonal (moved pin P=(px,py) -> stale anchor A=(ax,ay))
 * into a Manhattan route that clears the PIN-INCLUSIVE body of every moved instance. Enumerates, in
 * increasing complexity, axis-aligned candidate routes:
 *   L : P -> corner -> A                               (2 legs)
 *   Z : P -> channel -> A                              (3 legs; channel = 1/2 grids off the pin, one
 *                                                        grid outside a body edge, or the anchor line)
 *   escaped L/Z: a one-grid exit stub along the pin's OUTWARD normal first (P -> E), then L/Z from E
 *                -- the only way out when the pin is INSET from the body edge so no direct L/Z leaves
 *                it without threading the body (e.g. an output pin whose net-label sits past the far
 *                side, after_33.sch CTRL1).
 * Every candidate is partition-verified and reverted exactly; body-free routes (pref 0) are committed
 * before body-crossing ones (pref 1), shortest first. Purely geometric on the baked coords ->
 * rotation-safe; NEVER WORSE (only reached where the wire would else stay diagonal, commits only a
 * verified route). Returns 1 if a route committed. */
static int fluid_manh_route(int w, double px, double py, double ax, double ay, const char *prp)
{
  enum { MANH_CAP = 64 };
  double grid = tclgetdoublevar("cadsnap");
  double bx1 = 0.0, by1 = 0.0, bx2 = 0.0, by2 = 0.0, cx = 0.0, cy = 0.0;
  double sk_lo, sk_hi, sk_l, sk_r, yc[8], xc[8];
  double AX[MANH_CAP * 5], AY[MANH_CAP * 5], ALEN[MANH_CAP];
  int AN[MANH_CAP], ALEG[MANH_CAP], IDX[MANH_CAP], na = 0, have_body;
  int nyc = 0, nxc = 0, s, i, ii, pref;
  if(grid <= 0.0) grid = 1.0;
  have_body = fluid_union_sel_body_box(&bx1, &by1, &bx2, &by2);
  sk_lo = grid * (ceil(by1 / grid) - 1.0); sk_hi = grid * (floor(by2 / grid) + 1.0);
  sk_l  = grid * (ceil(bx1 / grid) - 1.0); sk_r  = grid * (floor(bx2 / grid) + 1.0);
  yc[nyc++] = py - grid; yc[nyc++] = py + grid; yc[nyc++] = py - 2.0 * grid; yc[nyc++] = py + 2.0 * grid;
  yc[nyc++] = ay; if(have_body) { yc[nyc++] = sk_lo; yc[nyc++] = sk_hi; }
  xc[nxc++] = px - grid; xc[nxc++] = px + grid; xc[nxc++] = px - 2.0 * grid; xc[nxc++] = px + 2.0 * grid;
  xc[nxc++] = ax; if(have_body) { xc[nxc++] = sk_l; xc[nxc++] = sk_r; }
  if(have_body) {                                 /* drop channels that lie ON a body edge (a wire */
    int nn = 0, t;                                /* there grazes the outline); sk_* keep a clear one */
    for(t = 0; t < nyc; ++t) if(yc[t] != by1 && yc[t] != by2) yc[nn++] = yc[t];
    nyc = nn;
    for(nn = 0, t = 0; t < nxc; ++t) if(xc[t] != bx1 && xc[t] != bx2) xc[nn++] = xc[t];
    nxc = nn;
  }
  /* direct L (V-first, H-first) */
  { double rx[3] = {px, px, ax}, ry[3] = {py, ay, ay}; fluid_manh_pushpath(AX,AY,AN,ALEG,ALEN,&na,MANH_CAP,rx,ry,3); }
  { double rx[3] = {px, ax, ax}, ry[3] = {py, py, ay}; fluid_manh_pushpath(AX,AY,AN,ALEG,ALEN,&na,MANH_CAP,rx,ry,3); }
  for(s = 0; s < nyc; ++s) { double m = yc[s], rx[4] = {px, px, ax, ax}, ry[4] = {py, m, m, ay};
    fluid_manh_pushpath(AX,AY,AN,ALEG,ALEN,&na,MANH_CAP,rx,ry,4); }
  for(s = 0; s < nxc; ++s) { double m = xc[s], rx[4] = {px, m, m, ax}, ry[4] = {py, py, ay, ay};
    fluid_manh_pushpath(AX,AY,AN,ALEG,ALEN,&na,MANH_CAP,rx,ry,4); }
  /* escaped L/Z: a stub along the pin's OUTWARD normal (box-centre dominant axis) to a point one or
   * two grids outside the body, then L/Z from there. Two step distances so a pin whose 1-grid escape
   * row is already taken by a sibling feed can step one grid further (after_33.sch: CTRL1 vs TRIANG,
   * both output pins escaping +y). */
  if(have_body) {
    int ed, vert;
    cx = (bx1 + bx2) / 2.0; cy = (by1 + by2) / 2.0;
    vert = (fabs(px - cx) < fabs(py - cy));
    for(ed = 0; ed < 2; ++ed) {
      double ex, ey;
      if(!vert) { ex = (px >= cx) ? sk_r + ed * grid : sk_l - ed * grid; ey = py; }
      else      { ex = px; ey = (py >= cy) ? sk_hi + ed * grid : sk_lo - ed * grid; }
      if(ex == px && ey == py) continue;
      { double rx[4] = {px, ex, ex, ax}, ry[4] = {py, ey, ay, ay}; fluid_manh_pushpath(AX,AY,AN,ALEG,ALEN,&na,MANH_CAP,rx,ry,4); }
      { double rx[4] = {px, ex, ax, ax}, ry[4] = {py, ey, ey, ay}; fluid_manh_pushpath(AX,AY,AN,ALEG,ALEN,&na,MANH_CAP,rx,ry,4); }
      for(s = 0; s < nyc; ++s) { double m = yc[s], rx[5] = {px, ex, ex, ax, ax}, ry[5] = {py, ey, m, m, ay};
        fluid_manh_pushpath(AX,AY,AN,ALEG,ALEN,&na,MANH_CAP,rx,ry,5); }
      for(s = 0; s < nxc; ++s) { double m = xc[s], rx[5] = {px, ex, m, m, ax}, ry[5] = {py, ey, ey, ay, ay};
        fluid_manh_pushpath(AX,AY,AN,ALEG,ALEN,&na,MANH_CAP,rx,ry,5); }
    }
  }
  for(i = 0; i < na; ++i) IDX[i] = i;             /* index sort: length, then fewer legs */
  for(i = 1; i < na; ++i) { int t = IDX[i], j = i - 1;
    while(j >= 0 && (ALEN[IDX[j]] > ALEN[t] || (ALEN[IDX[j]] == ALEN[t] && ALEG[IDX[j]] > ALEG[t])))
      { IDX[j+1] = IDX[j]; --j; }
    IDX[j+1] = t;
  }
  for(pref = 0; pref < 2; ++pref) for(ii = 0; ii < na; ++ii) {
    int c = IDX[ii], base = c * 5, k, crosses = 0;
    for(k = 0; k < AN[c] - 1 && !crosses; ++k)
      crosses = fluid_seg_crosses_sel_body(AX[base+k], AY[base+k], AX[base+k+1], AY[base+k+1]);
    if(pref == 0 ? crosses : !crosses) continue;
    if(fluid_manh_commit_path(w, &AX[base], &AY[base], AN[c], px, py, ax, ay, prp)) {
      fltrace("FLTRACE manh: wire=%d [%g %g %g %g] -> %d-leg route via (%g,%g)\n",
              w, px, py, ax, ay, ALEG[c], AX[base+1], AY[base+1]);
      return 1;
    }
  }
  return 0;
}

/* issue 0132: does ANY same-net (== node) axis-aligned wire strictly enter a moved instance's
 * PIN-INCLUSIVE body? (fluid_seg_crosses_sel_body already exempts a leg leaving one of the moved
 * pins outward -- the pin's own feed -- so a bare feed stub does NOT count; only a backbone that
 * threads under/through the pins does.) Used to detect a body dropped onto its OWN copper. */
static int fluid_net_crosses_sel_body(const char *node)
{
  int m;
  if(!node || !node[0]) return 0;
  for(m = 0; m < xctx->wires; ++m) {
    const char *wn = xctx->wire[m].node;
    if(!wn || strcmp(wn, node)) continue;
    if(xctx->wire[m].bus != 0.0) continue;
    if(xctx->wire[m].x1 == xctx->wire[m].x2 && xctx->wire[m].y1 == xctx->wire[m].y2) continue;
    if(fluid_seg_crosses_sel_body(xctx->wire[m].x1, xctx->wire[m].y1,
                                  xctx->wire[m].x2, xctx->wire[m].y2)) return 1;
  }
  return 0;
}

/* issue 0132: nearest same-net wire ENDPOINT strictly OUTSIDE the union pin-inclusive body box to
 * the moved pin (px,py) -- the re-route target when the pin's own copper now threads the body. A
 * vertex (not a closest-point-on-span) so the re-anchor lands on real copper that survives after the
 * in-body backbone is ripped. Returns 0 if the net has no copper outside the body. */
static int fluid_nearest_outside_body_anchor(double px, double py, const char *node,
                                             double *ax, double *ay)
{
  double bx1, by1, bx2, by2, best = 1e30;
  int m, e, found = 0;
  if(!node || !node[0]) return 0;
  if(!fluid_union_sel_body_box(&bx1, &by1, &bx2, &by2)) return 0;
  for(m = 0; m < xctx->wires; ++m) {
    const char *sn = xctx->wire[m].node;
    if(!sn || strcmp(sn, node)) continue;
    if(xctx->wire[m].bus != 0.0) continue;
    for(e = 0; e < 2; ++e) {
      double ex = e ? xctx->wire[m].x2 : xctx->wire[m].x1;
      double ey = e ? xctx->wire[m].y2 : xctx->wire[m].y1;
      double d;
      if(ex == px && ey == py) continue;                 /* the pin itself */
      if(ex > bx1 && ex < bx2 && ey > by1 && ey < by2) continue;  /* strictly inside body: reject */
      d = fabs(ex - px) + fabs(ey - py);
      if(d < best) { best = d; *ax = ex; *ay = ey; found = 1; }
    }
  }
  return found;
}

/* issue 0132 (P-D, after_37): a wire whose endpoint sits exactly on a moved (selected) instance pin
 * is that pin's OWN lead -- never "stale through-body copper", even when the pin lies strictly inside
 * the pin-inclusive body box (under rotation the symbol-left pins map to the box interior, so a lead
 * MUST cross the box to reach its pin -- yet it is still clear of the real device-body polygon).
 * Deleting such a lead orphans the pin: the delete's partition-verify below is fooled by a transient
 * weld (a relay corner momentarily bridging the pin to sibling copper) that a later prune removes,
 * so the "redundant" test passes and the pin's only feed vanishes. Protect every moved-pin lead. */
static int fluid_wire_end_on_moved_pin(double x1, double y1, double x2, double y2)
{
  int i, p;
  for(i = 0; i < xctx->instances; ++i) {
    int npins;
    if(xctx->inst[i].sel != SELECTED || xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    for(p = 0; p < npins; ++p) {
      double px, py;
      get_inst_pin_coord(i, p, &px, &py);
      if((px == x1 && py == y1) || (px == x2 && py == y2)) return 1;
    }
  }
  return 0;
}

/* issue 0132: VERIFIED delete of same-net copper that strictly threads a moved body. After the pin
 * feed has been re-routed clear of the body (fluid_manh_route to an outside anchor), the old
 * through-body backbone is redundant -- but it is NAMED copper (TRIANG/CTRL1...), which the
 * explicit-lab orphan prune refuses to touch (WIRING.md §11.1 named-rail blackout). Delete it here
 * with an explicit pin-partition verify: a wire is removed ONLY if the netlist is unchanged without
 * it (so a load-bearing crossing -- one with no alternate path -- is kept). Greedy to fixpoint;
 * indices shift on each delete so the scan restarts. A moved pin's OWN lead is never deleted here
 * (fluid_wire_end_on_moved_pin, P-D) -- the partition-verify alone is fooled by a transient weld.
 * Returns 1 if anything was removed. */
static int fluid_delete_body_crossing_copper(const char *node)
{
  int changed = 0, progress = 1, guard = 0;
  if(!node || !node[0]) return 0;
  while(progress && ++guard < 256) {
    int s;
    progress = 0;
    for(s = 0; s < xctx->wires; ++s) {
      double ox1, oy1, ox2, oy2;
      char *op = NULL;
      unsigned short *flag;
      const char *sn = xctx->wire[s].node;
      if(!sn || strcmp(sn, node)) continue;
      if(xctx->wire[s].bus != 0.0) continue;
      if(xctx->wire[s].x1 == xctx->wire[s].x2 && xctx->wire[s].y1 == xctx->wire[s].y2) continue;
      if(!fluid_seg_crosses_sel_body(xctx->wire[s].x1, xctx->wire[s].y1,
                                     xctx->wire[s].x2, xctx->wire[s].y2)) continue;
      if(fluid_wire_end_on_moved_pin(xctx->wire[s].x1, xctx->wire[s].y1,      /* P-D: pin's own lead */
                                     xctx->wire[s].x2, xctx->wire[s].y2)) {
        fltrace("FLTRACE bodycross: KEEP moved-pin lead [%g %g %g %g] %s\n",
                xctx->wire[s].x1, xctx->wire[s].y1, xctx->wire[s].x2, xctx->wire[s].y2, node);
        continue;
      }
      ox1 = xctx->wire[s].x1; oy1 = xctx->wire[s].y1;
      ox2 = xctx->wire[s].x2; oy2 = xctx->wire[s].y2;
      my_strdup(_ALLOC_ID_, &op, xctx->wire[s].prop_ptr);
      flag = my_malloc(_ALLOC_ID_, (size_t)(xctx->wires > 0 ? xctx->wires : 1) * sizeof(unsigned short));
      memset(flag, 0, (size_t)(xctx->wires > 0 ? xctx->wires : 1) * sizeof(unsigned short));
      flag[s] = 1;
      wire_delete_compact(wire_doomed_flag, flag);
      my_free(_ALLOC_ID_, &flag);
      xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
      prepare_netlist_structs(0);
      if(fluid_partition_changed() != 0) {               /* load-bearing: put it back exactly */
        storeobject(-1, ox1, oy1, ox2, oy2, WIRE, 0, 0, op);
        order_wire_coords(xctx->wires - 1);
        xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
        prepare_netlist_structs(0);
      } else {
        fltrace("FLTRACE bodycross: deleted stale through-body copper [%g %g %g %g] %s\n",
                ox1, oy1, ox2, oy2, node);
        changed = 1; progress = 1;
      }
      my_free(_ALLOC_ID_, &op);
      if(progress) break;                                /* indices shifted: restart the scan */
    }
  }
  return changed;
}

/* issue 0132: a moved instance dropped onto its OWN previously-routed copper (a second incremental
 * fluid drag) leaves a stationary Manhattan backbone threading the pin-inclusive body -- the
 * diagonal manhattanizer never touches it (it is Manhattan, its ends are not on a moved pin, and
 * the named-net orphan prune skips it, §11.1). For each moved pin whose net now crosses the body,
 * re-route the pin's feed to an OUTSIDE-body anchor (body-aware fluid_manh_route), then verified-
 * delete the now-redundant crossing copper. Purely on the baked coords -> rotation-safe; never worse
 * (fluid_manh_route commits only a verified route, the delete only verified-redundant copper).
 * Returns 1 if anything changed. */
static int fluid_reroute_body_crossing_feeds(void)
{
  int i, changed = 0;
  for(i = 0; i < xctx->instances; ++i) {
    int npins, p;
    if(xctx->inst[i].sel != SELECTED || xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    for(p = 0; p < npins; ++p) {
      double px, py, ax = 0.0, ay = 0.0, fox1, foy1, fox2, foy2;
      int f = -1, w;
      char *fprop = NULL, *fnode = NULL;
      get_inst_pin_coord(i, p, &px, &py);
      /* the feed wire = a wire with an endpoint exactly on this moved pin */
      for(w = 0; w < xctx->wires; ++w) {
        if(xctx->wire[w].bus != 0.0) continue;
        if((xctx->wire[w].x1 == px && xctx->wire[w].y1 == py) ||
           (xctx->wire[w].x2 == px && xctx->wire[w].y2 == py)) { f = w; break; }
      }
      if(f < 0) continue;
      my_strdup(_ALLOC_ID_, &fnode, xctx->wire[f].node);
      if(!fnode || !fnode[0]) { my_free(_ALLOC_ID_, &fnode); continue; }
      if(!fluid_net_crosses_sel_body(fnode)) { my_free(_ALLOC_ID_, &fnode); continue; }
      if(!fluid_nearest_outside_body_anchor(px, py, fnode, &ax, &ay)) {
        my_free(_ALLOC_ID_, &fnode); continue;
      }
      my_strdup(_ALLOC_ID_, &fprop, xctx->wire[f].prop_ptr);
      fox1 = xctx->wire[f].x1; foy1 = xctx->wire[f].y1;
      fox2 = xctx->wire[f].x2; foy2 = xctx->wire[f].y2;
      /* fluid_manh_route routes (px,py)->(ax,ay); it reverts a failed attempt to that straight
       * pair, NOT the feed's original shape, so restore the original explicitly on failure. */
      if(fluid_manh_route(f, px, py, ax, ay, fprop)) {
        changed = 1;
        fluid_delete_body_crossing_copper(fnode);
      } else {
        xctx->wire[f].x1 = fox1; xctx->wire[f].y1 = foy1;
        xctx->wire[f].x2 = fox2; xctx->wire[f].y2 = foy2;
        order_wire_coords(f);
        xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
        prepare_netlist_structs(0);
      }
      my_free(_ALLOC_ID_, &fprop);
      my_free(_ALLOC_ID_, &fnode);
    }
  }
  return changed;
}

static void fluid_manhattanize_relay_diagonals(void)
{
  int w, changed = 0;
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return;
  xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
  prepare_netlist_structs(0);
  if(fluid_partition_changed() != 0) return;      /* relay not accepted clean (alt result restored) */
  for(w = 0; w < xctx->wires; ++w) {
    double x1, y1, x2, y2, px, py;
    int i, p, hit = 0, done = 0;
    char *prp = NULL, *wnode = NULL;
    if(xctx->wire[w].x1 == xctx->wire[w].x2 || xctx->wire[w].y1 == xctx->wire[w].y2) continue;
    if(xctx->wire[w].bus != 0.0) continue;
    x1 = xctx->wire[w].x1; y1 = xctx->wire[w].y1; x2 = xctx->wire[w].x2; y2 = xctx->wire[w].y2;
    /* one endpoint must be a moved (selected) device pin: the relay translated that end */
    for(i = 0; i < xctx->instances && !hit; ++i) {
      int npins;
      if(xctx->inst[i].sel != SELECTED || xctx->inst[i].ptr < 0) continue;
      npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
      for(p = 0; p < npins && !hit; ++p) {
        get_inst_pin_coord(i, p, &px, &py);
        if(px == x1 && py == y1) hit = 1;
        else if(px == x2 && py == y2) hit = 2;
      }
    }
    if(!hit) continue;
    if(hit == 2) { double t; t = x1; x1 = x2; x2 = t; t = y1; y1 = y2; y2 = t; }
    my_strdup(_ALLOC_ID_, &prp, xctx->wire[w].prop_ptr);
    my_strdup(_ALLOC_ID_, &wnode, xctx->wire[w].node);  /* preps below rewrite wire[].node */
    /* --- 0108 phase 1: re-anchor to the closest same-net copper, distance-ordered --- */
    if(wnode && wnode[0]) {
      Fluid_reanchor_cand *cand = NULL;
      int nc = 0, s, k;
      cand = my_malloc(_ALLOC_ID_, (size_t)(2 * xctx->wires + 1) * sizeof(Fluid_reanchor_cand));
      for(s = 0; s < xctx->wires; ++s) {
        double qx, qy, d;
        const char *sn = xctx->wire[s].node;
        if(s == w || xctx->wire[s].bus != 0.0) continue;
        if(xctx->wire[s].x1 != xctx->wire[s].x2 && xctx->wire[s].y1 != xctx->wire[s].y2) continue;
        if(xctx->wire[s].x1 == xctx->wire[s].x2 && xctx->wire[s].y1 == xctx->wire[s].y2) continue;
        if(!sn || strcmp(sn, wnode)) continue;     /* re-anchor only onto our own net */
        fluid_seg_closest_point(x1, y1, xctx->wire[s].x1, xctx->wire[s].y1,
                                xctx->wire[s].x2, xctx->wire[s].y2, &qx, &qy);
        if(qx == x1 && qy == y1) continue;         /* pin already on this copper */
        d = fabs(qx - x1) + fabs(qy - y1);
        if(qx == x1 || qy == y1) {                 /* aligned: one straight wire */
          cand[nc].qx = qx; cand[nc].qy = qy; cand[nc].cx = cand[nc].cy = 0.0;
          cand[nc].nbend = 0; cand[nc].cost = d; ++nc;
        } else {                                   /* two L orientations */
          cand[nc].qx = qx; cand[nc].qy = qy; cand[nc].cx = x1; cand[nc].cy = qy;
          cand[nc].nbend = 1; cand[nc].cost = d; ++nc;
          cand[nc].qx = qx; cand[nc].qy = qy; cand[nc].cx = qx; cand[nc].cy = y1;
          cand[nc].nbend = 1; cand[nc].cost = d; ++nc;
        }
      }
      for(k = 1; k < nc; ++k) {                    /* insertion sort: distance, then fewer bends */
        Fluid_reanchor_cand t = cand[k];
        int j = k - 1;
        while(j >= 0 && (cand[j].cost > t.cost ||
              (cand[j].cost == t.cost && cand[j].nbend > t.nbend))) { cand[j + 1] = cand[j]; --j; }
        cand[j + 1] = t;
      }
      for(k = 0; k < nc && !done; ++k) {
        /* pre-check both legs against pin-less foreign copper (partition verify is blind to it) */
        if(cand[k].nbend) {
          if(fluid_seg_welds_foreign(x1, y1, cand[k].cx, cand[k].cy, wnode, w)) continue;
          if(fluid_seg_welds_foreign(cand[k].cx, cand[k].cy, cand[k].qx, cand[k].qy, wnode, w))
            continue;
        } else {
          if(fluid_seg_welds_foreign(x1, y1, cand[k].qx, cand[k].qy, wnode, w)) continue;
        }
        /* 0132: never re-anchor THROUGH a moved body. A body dropped onto its own copper makes the
         * distance-nearest same-net point the stationary backbone threading the body; taking it
         * solders the pin through the body AND short-circuits the body-aware fluid_manh_route below
         * (it sets done=1). Reject such a candidate so a clean outside route is used instead. */
        if(cand[k].nbend) {
          if(fluid_seg_crosses_sel_body(x1, y1, cand[k].cx, cand[k].cy) ||
             fluid_seg_crosses_sel_body(cand[k].cx, cand[k].cy, cand[k].qx, cand[k].qy)) continue;
        } else {
          if(fluid_seg_crosses_sel_body(x1, y1, cand[k].qx, cand[k].qy)) continue;
        }
        if(fluid_try_reanchor(w, x1, y1, x2, y2, &cand[k], prp)) {
          fltrace("FLTRACE reanchor: wire=%d [%g %g %g %g] -> Q=(%g,%g) nbend=%d cost=%g\n",
                  w, x1, y1, x2, y2, cand[k].qx, cand[k].qy, cand[k].nbend, cand[k].cost);
          changed = 1; done = 1;
        }
      }
      my_free(_ALLOC_ID_, &cand);
    }
    /* --- phases 2-4 (0130/0133): reshape the accepted relay diagonal into a Manhattan route that
     * clears the PIN-INCLUSIVE body of every moved instance. Under rotation the whole obstacle/exit-
     * stub layer is gated OFF (move.c fluid-block, rot==flip==0), so this is the ONLY shaper of the
     * relay diagonals; picking the first partition-clean L regardless of geometry routed the feeds
     * through the body / under the top pins. fluid_manh_route tries body-free L -> body-free Z ->
     * escape-stub Z before any body-crossing route, shortest first, each partition-verified and
     * reverted exactly. Runs whenever phase 1 (re-anchor) did not resolve the diagonal. */
    if(!done && fluid_manh_route(w, x1, y1, x2, y2, prp)) { changed = 1; done = 1; }
    my_free(_ALLOC_ID_, &prp);
    my_free(_ALLOC_ID_, &wnode);
  }
  /* 0132: a body dropped onto its OWN stationary Manhattan copper (second incremental drag) is not a
   * relay diagonal -- re-route each moved pin whose net threads the body to an outside anchor and
   * verified-delete the redundant through-body backbone (§11.9b). */
  if(fluid_reroute_body_crossing_feeds()) changed = 1;
  if(changed) {
    trim_wires();
    check_collapsing_objects();
    xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
    prepare_netlist_structs(0);
    /* 0108: prune the abandoned stale feed. A re-anchored connection leaves its old copper hanging
     * (the [0,-40 0,0] stub, the [-80,-150 -80,0] riser, the backbone overhang past the new T).
     * Retract/delete dangling ends that were JUNCTIONS at START (live touch-deg 0, on no pin,
     * START deg >= 2 -- a user's pre-existing dangler tip has START deg <= 1 and is never touched)
     * to fixpoint. Each action is partition-verified by fluid_retract_orphan_tail; user-protected
     * (0091) and explicit-lab copper excluded. Only follow-net copper can newly dangle (END re-applies
     * the total delta from the pristine snapshot), so no extra net scoping is needed. */
    {
      int np = fluid_count_pins();
      if(np > 0) {
        int *base = my_malloc(_ALLOC_ID_, np * sizeof(int));
        int *now  = my_malloc(_ALLOC_ID_, np * sizeof(int));
        int progress = 1, rounds = 0;
        fluid_loop_partition(NULL, base);
        while(progress && ++rounds < 64) {
          unsigned char *prot = my_malloc(_ALLOC_ID_,
                                  (size_t)(xctx->wires > 0 ? xctx->wires : 1) * sizeof(unsigned char));
          int i;
          progress = 0;
          fluid_mark_user_protected(prot);
          for(i = 0; i < xctx->wires && !progress; ++i) {
            int e;
            if(prot[i]) continue;
            if(xctx->wire[i].bus != 0.0) continue;
            if(xctx->wire[i].x1 == xctx->wire[i].x2 && xctx->wire[i].y1 == xctx->wire[i].y2) continue;
            /* 0132 §11.9g (after_37 P-B): NAMED copper is NOT skipped here any more. The old-elbow
             * overhang a relocated pin-riser leaves dangling (TRIANG's 80,90 tail, CTRL1's 120,100
             * tail) carries the net's explicit lab, so the §11.1 blackout used to refuse to remove it.
             * These overhangs are WHOLE stubs (trim keeps them split at the riser T, so there is no
             * interior junction to retract to) -- fluid_retract_orphan_tail falls to DELETE mode.
             * Pass allow_named_stale=1: DELETE may remove a named stub ONLY when its label survives on
             * live copper at the far end (fluid_same_name_survivor) AND the partition is preserved. The
             * per-end gates below (drag-orphaned NOW, not on a pin, START deg>=2 = was a real junction,
             * never a user's deliberate deg<=1 named-stub tip) scope it to genuinely stale elbows.
             * RETRACT (name-preserving) stays available too. */
            for(e = 0; e < 2 && !progress; ++e) {
              double ex = e ? xctx->wire[i].x2 : xctx->wire[i].x1;
              double ey = e ? xctx->wire[i].y2 : xctx->wire[i].y1;
              if(fluid_deg_at(ex, ey, NULL, i) != 0) continue;
              if(point_on_any_pin(ex, ey)) continue;
              if(fluid_start_deg_at(ex, ey) < 2) continue;
              if(fluid_retract_orphan_tail(i, ex, ey, base, np, now, 1)) {
                fltrace("FLTRACE reanchor: pruned stale feed at (%g,%g)\n", ex, ey);
                progress = 1;             /* indices shifted: restart the scan */
              }
            }
          }
          my_free(_ALLOC_ID_, &prot);
        }
        my_free(_ALLOC_ID_, &base);
        my_free(_ALLOC_ID_, &now);
        xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
        prepare_netlist_structs(0);
      }
    }
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
  }
}

/* ==== Track D (D3): the END cleanup pass table ====================================================
 * One table drives the END cleanup cluster (WIRING.md §3 step 9, §4 pass catalog). ARRAY ORDER IS
 * THE EXECUTION ORDER and encodes the hard ordering edges (WIRING §3), each discovered by a bug:
 *   - ripup FIRST: straighten pass-2 is the designated pruner of ripup's orphaned riser tails;
 *   - de-short (ripup, shorting-anchor-tails) before the aesthetics (loops, straighten, overshoot):
 *     the aesthetic passes verify against PASS ENTRY -- an unfixed short entering them is frozen in
 *     as the invariant they preserve;
 *   - anchor-tails before straighten (0110): a dangling tail holds the stale-anchor jog's endpoint
 *     at touch-degree 2, masking the staircase from the collapse;
 *   - straighten before insert_exit_stubs (0111): a P3 stub is itself a straighten-collapsible jog
 *     unit -- NOTHING that collapses jogs may run after the stub pass (or every stub is undone /
 *     oscillates); the converse antagonism is resolved INSIDE straighten (0111 reschedule);
 *   - orphan-stub after straighten: its target only becomes prunable once straighten deletes the
 *     follow-riser it was joined to;
 *   - manhattanize LAST (per gesture, after the attempt ladder): the accepted-relay path had
 *     leg_ortho==0 and skipped this whole per-leg cluster.
 * Never insert or reorder an entry without re-walking that list. */

/* Gate bits. END_ONLY/ORTHO/FINAL_LEG are guaranteed by the enclosing call-site gate (the cluster
 * runs inside move_objects' attempt x leg scaffold under `!commit_now && fluid_editing &&
 * stretch_select && leg_ortho && leg == nlegs-1`); the driver re-checks them anyway so each entry
 * is self-describing (and so a future one-pass harness can enforce them, D6). */
#define FLUID_PASS_END_ONLY     0x01 /* real END only, never on a live RUBBER commit (commit_now) */
#define FLUID_PASS_ORTHO        0x02 /* requires an orthogonal leg (leg_ortho) */
#define FLUID_PASS_FINAL_LEG    0x04 /* final decomposition leg only (leg == nlegs-1) */
#define FLUID_PASS_ROTFREE_ONLY 0x08 /* only when move_rot==0 && move_flip==0 */
#define FLUID_PASS_ROTATED_ONLY 0x10 /* only when rotated/flipped -- the old `if(!rotfree)` gate */
#define FLUID_PASS_NEEDS_RIPPED 0x20 /* only after ripup committed a change -- the old `if(ripped)` */
#define FLUID_PASS_SETS_RIPPED  0x40 /* pass return value becomes the driver's `ripped` flag --
                                        plain assignment (not OR), mirroring the old single
                                        `int ripped = ripup()`; revisit before adding a 2nd one */
#define FLUID_PASS_MANUAL_SITE  0x80 /* cataloged here for order/contract but CALLED AT ITS OWN
                                        SITE (different gate set); the driver skips it -- see the
                                        entry comment for why it cannot be driver-run yet */

/* Verify direction (WIRING §5 taxonomy) + mutation class: per-pass contract made structural.
 * The D3 driver does not consult them; they are the hooks for the D5 idempotence oracle and the
 * D6 single-pass harness. */
typedef enum {
  FLUID_VERIFY_RESTORE_START_NAME, /* fluid_partition_changed()==0 vs fluid_g.snap_id */
  FLUID_VERIFY_RESTORE_START_GEO,  /* fluid_part_diff_pairs()==0 vs fluid_g.geo_snap_id (0104) */
  FLUID_VERIFY_PRESERVE_ENTRY,     /* geometric fluid_loop_partition base-vs-now */
  FLUID_VERIFY_NONE                /* geometric construction, no partition verify */
} Fluid_verify_dir;
typedef enum {
  FLUID_MUT_DELETE_ONLY,           /* can only remove copper (decline = keep) */
  FLUID_MUT_RESHAPE,               /* slides/retracts/extends legs (may add copper, e.g. ripup's
                                      jog); the partition state it must reach is its verify_dir */
  FLUID_MUT_ADD                    /* constructs new copper (exit stubs) */
} Fluid_mut_class;

typedef struct {
  const char *name;
  int (*fn)(void);                 /* uniform driver signature: int-returning passes feed
                                      SETS_RIPPED; void passes get a wrapper returning 0;
                                      NULL for MANUAL_SITE entries (never driver-called) */
  unsigned int gates;              /* FLUID_PASS_* bits */
  Fluid_verify_dir verify_dir;
  Fluid_mut_class mut_class;
} Fluid_pass;

/* Uniform-signature adapters for the void passes -- the exact old calls, no argument or gate
 * change (D3 is a pure refactor; the table must transcribe, not clean up). */
static int fluid_pass_prune_shorting_anchor_tails(void) { fluid_prune_shorting_anchor_tails(); return 0; }
static int fluid_pass_remove_redundant_loops(void)      { fluid_remove_redundant_loops();      return 0; }
static int fluid_pass_prune_anchor_tails(void)          { fluid_prune_anchor_tails();          return 0; }
static int fluid_pass_straighten_reversals(void)        { fluid_straighten_reversals();        return 0; }
static int fluid_pass_collapse_axis_overshoot_stub(void){ fluid_collapse_axis_overshoot_stub(); return 0; }
static int fluid_pass_prune_novel_orphan_stub(void)     { fluid_prune_novel_orphan_stub();     return 0; }

#define FLUID_PASS_CLUSTER (FLUID_PASS_END_ONLY | FLUID_PASS_ORTHO | FLUID_PASS_FINAL_LEG)

static const Fluid_pass fluid_end_passes[] = {
  /* issue 0094: a rigid group drag can land a moved device's OFF-net pin exactly on a foreign
   * net's backbone (before_5.sch C12+R18+#net2 by (-40,+70): R18's #net2 pin on the #net1
   * backbone) -- a genuine device SHORT the reroute must RIP UP (the pin is fixed by the rigid
   * move; only the foreign copper can move). Runs FIRST so the slide's orphaned column/riser
   * tails are pruned by the straighten/retract pass below. Strict no-op unless a move-created
   * merge exists => byte-identical for every non-shorting drag. Its route-around fallback
   * fluid_jog_pin_off_backbone (0098, 0106 gap expansion) is an INTERNAL per-pin subroutine
   * (args qx,qy,vertaxis), invoked only from inside this pass -- not a standalone table entry.
   * See doc/claude/issues/0094-*.md. */
  { "ripup_foreign_pin_short", fluid_ripup_foreign_pin_short,
    FLUID_PASS_CLUSTER | FLUID_PASS_SETS_RIPPED,
    FLUID_VERIFY_RESTORE_START_NAME, FLUID_MUT_RESHAPE },
  /* issue 0104: a rotated stretch can short two follow-wires at one pin's STALE pristine anchor
   * (no pin on the contact point, so the rip-up above never fires). Delete-only, commits a doom
   * only when it makes the pin-partition equivalent to START again -- strict no-op on clean
   * drags. The one restore-START *geometric* verifier (same-name islands, WIRING §5). */
  { "prune_shorting_anchor_tails", fluid_pass_prune_shorting_anchor_tails,
    FLUID_PASS_CLUSTER,
    FLUID_VERIFY_RESTORE_START_GEO, FLUID_MUT_DELETE_ONLY },
  /* issue 0088: collapse a redundant same-net cycle a fluid stretch closed (before_3.sch R18
   * (-20,-60) -> the {w4,w5,w6,w9} #net2 rectangle) to its minimal connectivity-preserving tree
   * (here just the riser). Delete-only, per-doom pin-partition-verified, scoped to THIS drag's
   * copper. Runs after trim/orphan (site order) so it sees deduped geometry, before
   * insert_exit_stubs so P3 is re-applied to the collapsed riser.
   * See doc/claude/issues/0088-fluid-reroute-redundant-samenet-loop.md. */
  { "remove_redundant_loops", fluid_pass_remove_redundant_loops,
    FLUID_PASS_CLUSTER,
    FLUID_VERIFY_PRESERVE_ENTRY, FLUID_MUT_DELETE_ONLY },
  /* issue 0103: under rotation/flip the elbow's pristine-anchor far leg can survive trim as a
   * same-net dangling tail (remove_move_orphan_wires needs the kept end on a MOVING pin).
   * Delete-only + per-doom partition-verified, so it can only remove drag-produced jetsam or
   * decline. ROTATED_ONLY (the old `if(!rotfree)`): the translation path never strands these.
   * Runs BEFORE the straighteners (issue 0110): the dangling tail holds the stale-anchor jog's
   * endpoint at touch-degree 2, masking the staircase from the collapse below. */
  { "prune_anchor_tails", fluid_pass_prune_anchor_tails,
    FLUID_PASS_CLUSTER | FLUID_PASS_ROTATED_ONLY,
    FLUID_VERIFY_PRESERVE_ENTRY, FLUID_MUT_DELETE_ONLY },
  /* issues 0089 + 0090: the loop-remover only DELETES a redundant same-net CYCLE. A far / multi-
   * gesture move leaves a same-net PATH (no cycle) with a redundant jog -- a same-side U-turn
   * (0089, before_3 R18 (-80,-60) -> after_9 #net2) or an opposite-side monotone STAIRCASE
   * (0090, before_3 -> after_10 #net1). Straighten both to a clean L (slide + verified
   * tail-retract; partition-invariant + novelty-scoped; strict no-op otherwise).
   * issue 0110: no longer rotfree-gated -- one ALT-R mid-drag left the stale-anchor staircase
   * and U-loop of after_27.sch in the save. Every slide/retract is pin-partition-verified,
   * novelty-scoped, user-protected (0091) and body-guarded against STATIONARY instances
   * (plus, for the 0111 pin-landing FAR candidate only, against MOVED bodies too), so the
   * guards are geometric, not rotation-dependent (the 0098 facet B argument); worst case
   * they decline and the pre-0110 route is kept. The 0111 pin-landing reschedule itself is
   * rot/flip-gated off INSIDE the pass (no insert_exit_stubs round trip exists there to
   * normalize). */
  { "straighten_reversals", fluid_pass_straighten_reversals,
    FLUID_PASS_CLUSTER,
    FLUID_VERIFY_PRESERVE_ENTRY, FLUID_MUT_RESHAPE },
  /* issue 0092: an along-axis wire drag (grab a rung, pull it along its own axis) overshoots its
   * junction into a dangling stub + solder dot instead of SHOVING the perpendicular riser.
   * Neither the pin-driven shove (no moving pin -- a WIRE was grabbed) nor straighten
   * (brand-new deg-0 tip, user's own protected net) reaches it. Shove the riser column to the
   * stub tip (preferred_12.sch), or trim the stub when the riser is pin-anchored.
   * Partition-verified + novelty-scoped; NOT prot[]-gated (drag-created junk on the grabbed net
   * is always removable). Un-gated from rotfree with 0110.
   * See doc/claude/issues/0092-fluid-axis-drag-overshoot-stub.md. */
  { "collapse_axis_overshoot_stub", fluid_pass_collapse_axis_overshoot_stub,
    FLUID_PASS_CLUSTER,
    FLUID_VERIFY_PRESERVE_ENTRY, FLUID_MUT_RESHAPE },
  /* issue 0094 tail: the rip-up slide + straighten can leave a fresh dangling backbone stub past
   * the sibling pin (the follow-riser it was joined to is only deleted by straighten just
   * above). Prune it now, connectivity-verified. NEEDS_RIPPED (the old `if(ripped)`) so it
   * never runs on a non-shorting drag. Runs under rotation too (0098 facet B): when ripup fired
   * on a rotated stretch its orphan tail must still go. */
  { "prune_novel_orphan_stub", fluid_pass_prune_novel_orphan_stub,
    FLUID_PASS_CLUSTER | FLUID_PASS_NEEDS_RIPPED,
    FLUID_VERIFY_PRESERVE_ENTRY, FLUID_MUT_DELETE_ONLY },
  /* MANUAL_SITE: insert_exit_stubs (P3 escape-normal stubs, wire-editing Phase 6 / R13) runs at
   * its own call site just after this cluster because its gate set DIFFERS from the cluster's:
   * it is NOT END-only (it also runs on every live RUBBER commit -- each step restores from
   * pristine and re-inserts), it fires for `wire_exit_stub` users even with fluid_editing OFF,
   * and it carries its own trailing check_collapsing_objects sweep (a stub landing exactly on
   * the stationary pin degenerates a slid leg to zero length and nothing trims after it).
   * Position in THIS array records the 0111 ordering invariant: after all straighteners,
   * nothing jog-collapsing after it. */
  { "insert_exit_stubs", NULL,
    FLUID_PASS_ORTHO | FLUID_PASS_FINAL_LEG | FLUID_PASS_ROTFREE_ONLY | FLUID_PASS_MANUAL_SITE,
    FLUID_VERIFY_NONE, FLUID_MUT_ADD },
  /* MANUAL_SITE: fluid_manhattanize_relay_diagonals (0107/0108) runs PER GESTURE after the whole
   * attempt ladder, not per leg -- an ACCEPTED rigid relay is partition-clean but diagonal, and
   * that path had leg_ortho==0 so it skipped this cluster entirely. Its site gate is
   * `!commit_now && diag_relay && orthogonal_wiring && stretch_select && fluid_editing`
   * (diag_relay/orthogonal_wiring are not per-leg cluster state), and it must run after the
   * relay's manhattan_lines=0 override is restored (WIRING §7.1). Self-gates on
   * partition-clean entry; carries its own stale-feed prune (0108). */
  { "manhattanize_relay_diagonals", NULL,
    FLUID_PASS_END_ONLY | FLUID_PASS_MANUAL_SITE,
    FLUID_VERIFY_RESTORE_START_NAME, FLUID_MUT_RESHAPE },
  /* MANUAL_SITE: fluid_shove_body_crossing_backbone (0132 §11.9c, after_35) runs PER GESTURE at
   * the real END right after manhattanize's site, on the COMPLEMENTARY path (!diag_relay -- the
   * accepted pure-ortho gesture): a moved body engulfing the pin's own stationary perpendicular
   * backbone (pin lands mid-run) is pushed one grid past the body edge in the motion direction,
   * pin re-fed via a jog, dead overhang dropped. Site gate adds fluid_startsel_wires==0 +
   * rot-free (not per-leg cluster state). Both-sides-of-pin through-run gate excludes ordinary
   * one-sided escape feeds; mem-snapshot + name AND geometric partition verify, exact revert.
   * Reshapes NAMED copper under verify (a §11.1 crack); props copied from the run, never renamed. */
  { "shove_body_crossing_backbone", NULL,
    FLUID_PASS_END_ONLY | FLUID_PASS_MANUAL_SITE,
    FLUID_VERIFY_RESTORE_START_NAME, FLUID_MUT_RESHAPE },
};

/* ==== Track D (D4): per-pass observability for the pass-table driver =============================
 * EVERYTHING here is trace-only: nothing runs unless fluid_trace_on() (FLUID_TRACE set), so the
 * driver stays byte-identical with tracing off (the D3 guarantee is preserved). D4 turns the D3
 * one-line-per-firing trace into the decline-reason record that would have surfaced 0110's masking
 * instantly: every SKIP names the gate bit that stopped the pass, every run reports changed=N, and
 * FLUID_TRACE_DUMP=1 additionally dumps the wire array between passes. */

/* Which gate bit, if any, makes this pass SKIP at the given driver state? Returns the bit's name
 * for the FIRST failing check in the DRIVER'S short-circuit order (so the reported reason is the
 * one that actually fired), or NULL if the pass runs. Pure function of its args -- the driver calls
 * it unconditionally (tracing on or off) to decide skip vs run, so this is the single source of
 * truth for both the control flow and the trace label (they cannot drift). */
static const char *fluid_pass_skip_gate(const Fluid_pass *p, int commit_now, int leg_ortho,
                                        int leg, int nlegs, int rotfree, int ripped)
{
  if(p->gates & FLUID_PASS_MANUAL_SITE)                       return "MANUAL_SITE";
  if((p->gates & FLUID_PASS_END_ONLY) && commit_now)          return "END_ONLY";
  if((p->gates & FLUID_PASS_ORTHO) && !leg_ortho)             return "ORTHO";
  if((p->gates & FLUID_PASS_FINAL_LEG) && leg != nlegs - 1)   return "FINAL_LEG";
  if((p->gates & FLUID_PASS_ROTFREE_ONLY) && !rotfree)        return "ROTFREE_ONLY";
  if((p->gates & FLUID_PASS_ROTATED_ONLY) && rotfree)         return "ROTATED_ONLY";
  if((p->gates & FLUID_PASS_NEEDS_RIPPED) && !ripped)         return "NEEDS_RIPPED";
  return NULL;
}

/* Per-wire geometry signature keyed by the session-stable wire id (WIRING §1.1: only wire[].id is
 * stable across trim/compact). Endpoints stored ORDERED so a bare order_wire_coords swap does not
 * read as a change. Used only to count what a pass changed for the trace. */
typedef struct { unsigned int id; double x1, y1, x2, y2; } Fluid_wsig;

static Fluid_wsig *fluid_wsig_snapshot(int *np)
{
  int i, n = xctx->wires;
  Fluid_wsig *s = NULL;
  if(n > 0) s = my_malloc(_ALLOC_ID_, (size_t)n * sizeof(Fluid_wsig));
  for(i = 0; i < n; ++i) {
    double x1 = xctx->wire[i].x1, y1 = xctx->wire[i].y1;
    double x2 = xctx->wire[i].x2, y2 = xctx->wire[i].y2;
    if(x1 > x2 || (x1 == x2 && y1 > y2)) { double t;
      t = x1; x1 = x2; x2 = t; t = y1; y1 = y2; y2 = t; }
    s[i].id = xctx->wire[i].id;
    s[i].x1 = x1; s[i].y1 = y1; s[i].x2 = x2; s[i].y2 = y2;
  }
  *np = n;
  return s;
}

/* changed = wires added + wires deleted + wires moved, keyed by id (O(na*nb) -- trace-only, small
 * W). A trim collinear-merge loses the absorbed id (WIRING §1.1) => counts as one delete; a split
 * mints a fresh id => one add. Good enough as a "did this pass touch anything, how much" proxy. */
static int fluid_wsig_diff(const Fluid_wsig *a, int na, const Fluid_wsig *b, int nb)
{
  int i, j, changed = 0;
  for(j = 0; j < nb; ++j) {                 /* new or moved */
    int found = 0;
    for(i = 0; i < na; ++i) if(a[i].id == b[j].id) {
      found = 1;
      if(a[i].x1 != b[j].x1 || a[i].y1 != b[j].y1 || a[i].x2 != b[j].x2 || a[i].y2 != b[j].y2)
        changed++;
      break;
    }
    if(!found) changed++;
  }
  for(i = 0; i < na; ++i) {                 /* deleted */
    int found = 0;
    for(j = 0; j < nb; ++j) if(a[i].id == b[j].id) { found = 1; break; }
    if(!found) changed++;
  }
  return changed;
}

static int fluid_trace_dump_on(void)
{
  static int v = -1;
  if(v < 0) { const char *e = getenv("FLUID_TRACE_DUMP"); v = (e && *e && *e != '0') ? 1 : 0; }
  return v;
}

/* Dump the whole wire array (id + ordered-as-stored coords + sel + lab) with a tag. Gated on BOTH
 * fluid_trace_on() and FLUID_TRACE_DUMP so a plain FLUID_TRACE run stays compact. */
static void fluid_dump_wires(const char *tag)
{
  int i;
  if(!fluid_trace_on() || !fluid_trace_dump_on()) return;
  fltrace("FLTRACE dump [%s]: %d wires\n", tag, xctx->wires);
  for(i = 0; i < xctx->wires; ++i)
    fltrace("FLTRACE   w%d id=%u [%g %g %g %g] sel=%u lab=%s\n", i, xctx->wire[i].id,
            xctx->wire[i].x1, xctx->wire[i].y1, xctx->wire[i].x2, xctx->wire[i].y2,
            xctx->wire[i].sel, get_tok_value(xctx->wire[i].prop_ptr, "lab", 0));
}

/* ==== Track D (D5): idempotence oracle ==========================================================
 * The END cleanup cluster is a FIXPOINT: a second pass over the same geometry must change nothing.
 * The 0111 oscillation class (straighten collapses a jog onto a pin, insert_exit_stubs re-jogs it
 * one grid back, forever) is exactly a broken fixpoint. FLUID_IDEMPOTENT_CHECK=1 (off by default,
 * tests only) makes the driver run the cluster a SECOND time and flag any pass that still changes
 * the wire SET -- naming the offending pass. Off => the 2nd round never runs => byte-identical to
 * D4. On a CORRECT build the 2nd round is a no-op, so the schematic (and every test's assertions)
 * is untouched even with the oracle ON; a violation means the build is already broken, so the
 * 2nd-round mutation is acceptable (the oracle exists to make it LOUD). */
static int fluid_idempotent_check_on(void)
{
  static int v = -1;
  if(v < 0) { const char *e = getenv("FLUID_IDEMPOTENT_CHECK"); v = (e && *e && *e != '0') ? 1 : 0; }
  return v;
}

static int fluid_wsig_cmp(const void *pa, const void *pb)
{
  const Fluid_wsig *a = pa, *b = pb;
  if(a->x1 != b->x1) return a->x1 < b->x1 ? -1 : 1;
  if(a->y1 != b->y1) return a->y1 < b->y1 ? -1 : 1;
  if(a->x2 != b->x2) return a->x2 < b->x2 ? -1 : 1;
  if(a->y2 != b->y2) return a->y2 < b->y2 ? -1 : 1;
  return 0;
}

/* Did the wire GEOMETRY set change (id-independent: a delete + re-add of the same span is still a
 * fixpoint)? Sorts both throwaway snapshots and compares the ordered coordinate multisets. */
static int fluid_wsig_geom_changed(Fluid_wsig *a, int na, Fluid_wsig *b, int nb)
{
  int i;
  if(na != nb) return 1;
  if(na == 0) return 0;
  qsort(a, (size_t)na, sizeof(Fluid_wsig), fluid_wsig_cmp);
  qsort(b, (size_t)nb, sizeof(Fluid_wsig), fluid_wsig_cmp);
  for(i = 0; i < na; ++i)
    if(a[i].x1 != b[i].x1 || a[i].y1 != b[i].y1 || a[i].x2 != b[i].x2 || a[i].y2 != b[i].y2)
      return 1;
  return 0;
}

/* Round 2 of the idempotence oracle: re-run the END cleanup cluster once over the ALREADY-finalized
 * geometry (called AFTER insert_exit_stubs so it also catches CROSS-pass oscillation -- the 0111
 * straighten<->exit-stub antagonism, which a cluster-only re-run positioned before the stub pass
 * would miss). Flags any pass that still changes the wire geometry SET (id-independent), naming the
 * first offender to stderr (live in the --nogui headless path; the wireedit --idempotent runner
 * greps the token), fltrace, and the Tcl var fluid_idempotence_violation. On a correct build this
 * is a strict no-op (the finalization IS a fixpoint), so the schematic stays byte-identical. */
static void fluid_end_cluster_idempotence_probe(int commit_now, int leg_ortho, int leg, int nlegs,
                                                int rotfree)
{
  int npasses = (int)(sizeof(fluid_end_passes) / sizeof(fluid_end_passes[0]));
  int ripped2 = 0, pj;
  tclsetvar("fluid_idempotence_violation", "");
  for(pj = 0; pj < npasses; ++pj) {
    const Fluid_pass *p = &fluid_end_passes[pj];
    int nb2 = 0, na2 = 0;
    Fluid_wsig *b2, *a2;
    const char *skip = fluid_pass_skip_gate(p, commit_now, leg_ortho, leg, nlegs, rotfree, ripped2);
    if(skip) continue;
    b2 = fluid_wsig_snapshot(&nb2);
    if(p->gates & FLUID_PASS_SETS_RIPPED) ripped2 = p->fn();
    else p->fn();
    a2 = fluid_wsig_snapshot(&na2);
    if(fluid_wsig_geom_changed(b2, nb2, a2, na2)) {
      fprintf(stderr, "FLUID_IDEMPOTENCE_VIOLATION: pass %s changed the wire set on the 2nd "
                      "cleanup round (not a fixpoint)\n", p->name);
      fltrace("FLTRACE IDEMPOTENCE VIOLATION: pass %s changed on round 2\n", p->name);
      if(tclgetvar("fluid_idempotence_violation")[0] == '\0')
        tclsetvar("fluid_idempotence_violation", p->name);
    }
    if(b2) my_free(_ALLOC_ID_, &b2);
    if(a2) my_free(_ALLOC_ID_, &a2);
  }
}

/* ==== Track D (D6): single-pass harness ==========================================================
 * Run one END-cleanup pass in isolation -- no gesture, no X, milliseconds -- so a pass can be unit-
 * tested against a synthetic scene instead of a transcribed drag. Exposed to Tcl via the scheduler
 * (`xschem fluid_snapshot arm`, `xschem fluid_pass <name>`). The gesture-state contract is the same
 * as at a real END: the snapshot must be armed (fluid_gesture_arm) on the PRISTINE geometry BEFORE
 * the novel copper exists -- straighten et al. are novelty-scoped against fluid_g.start_wire, so a
 * pass run against geometry that was already present at arm time correctly declines. */

/* Arm the START snapshot on the current geometry. Returns 1 iff a valid snapshot was taken --
 * fluid_snapshot_partition no-ops when fluid_editing is off OR there are no instance pins
 * (fluid_count_pins()<=0), leaving snap_pinnet NULL, which every pass fail-safes on. */
int fluid_harness_snapshot_arm(void)
{
  fluid_gesture_arm();
  return fluid_g.snap_pinnet != NULL;
}

/* Run the named driver-run pass against the current schematic; returns its changed-count (adds +
 * deletes + moves, id-keyed -- the D4 metric), 0 when it fail-safe-declines with no armed snapshot
 * (the gate-enforcement case), or -1 for an unknown name or a MANUAL_SITE entry (not driver-run). */
int fluid_harness_run_pass(const char *name)
{
  int i, npasses = (int)(sizeof(fluid_end_passes) / sizeof(fluid_end_passes[0]));
  int nb = 0, na = 0, changed;
  Fluid_wsig *before, *after;
  const Fluid_pass *p = NULL;
  for(i = 0; i < npasses; ++i)
    if(!strcmp(fluid_end_passes[i].name, name)) { p = &fluid_end_passes[i]; break; }
  if(!p || (p->gates & FLUID_PASS_MANUAL_SITE) || !p->fn) return -1;
  /* Establish the driver's precondition: in move_objects prepare_netlist_structs(0) runs before
   * the cluster, so the pin table / node[] the passes read (point_on_any_pin, etc.) is current for
   * the post-edit geometry. A cold harness call must refresh it or a stale table misleads the gate. */
  xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
  prepare_netlist_structs(0);
  before = fluid_wsig_snapshot(&nb);
  p->fn();                                  /* SETS_RIPPED return is irrelevant for a lone pass */
  after = fluid_wsig_snapshot(&na);
  changed = fluid_wsig_diff(before, nb, after, na);
  if(before) my_free(_ALLOC_ID_, &before);
  if(after)  my_free(_ALLOC_ID_, &after);
  return changed;
}

/* Phase III helper: is foreign pin (px,py) on the axis-aligned segment (x1,y1)-(x2,y2)? cadsnap/2
 * tolerance on the CONSTANT axis (mirrors point_near_pin, move.c:1220); inclusive span on the
 * varying axis. A degenerate (point) or diagonal leg carries no two-pin bridge. */
static int fluid_pin_on_seg(double px, double py, double x1, double y1, double x2, double y2)
{
  double tol = tclgetdoublevar("cadsnap") / 2.0, lo, hi;
  if(tol < 1e-6) tol = 1e-6;
  if(y1 == y2 && x1 != x2) {                       /* horizontal leg */
    if(fabs(py - y1) > tol) return 0;
    lo = x1 < x2 ? x1 : x2; hi = x1 < x2 ? x2 : x1;
    return px >= lo - tol && px <= hi + tol;
  }
  if(x1 == x2 && y1 != y2) {                        /* vertical leg */
    if(fabs(px - x1) > tol) return 0;
    lo = y1 < y2 ? y1 : y2; hi = y1 < y2 ? y2 : y1;
    return py >= lo - tol && py <= hi + tol;
  }
  return 0;
}

/* Do two AXIS-ALIGNED segments A(ax1,ay1)-(ax2,ay2) and B(bx1,by1)-(bx2,by2) share any point?
 * (issue 0087) The future-aware hazard tests (fluid_ml_future_covers / fluid_slide_future_hazard)
 * originally probed only a co-moving pin's FINAL landing POINT, but a co-moving pin is not a point:
 * the remaining decomposition leg drags a RISER along the future axis from the pin's intermediate
 * (post-current-leg) position to its final one, and foreign copper touching ANYWHERE on that riser
 * shorts just as surely as copper on the pin itself. So those tests probe the whole corridor
 * SEGMENT and need segment-vs-segment overlap, not point-on-segment. A degenerate (point) input
 * (which the future=0 later legs always produce) falls back to fluid_pin_on_seg, so the later legs
 * and every pure-axis / plain move stay byte-identical. Diagonal input returns 0 (callers only ever
 * pass H/V copper and single-axis corridors), so it can never false-hit. Same cadsnap/2 tolerance
 * as fluid_pin_on_seg. */
static int fluid_seg_pair_touch(double ax1, double ay1, double ax2, double ay2,
                                double bx1, double by1, double bx2, double by2)
{
  double tol = tclgetdoublevar("cadsnap") / 2.0;
  int ah, av, bh, bv;
  if(tol < 1e-6) tol = 1e-6;
  if(ax1 == ax2 && ay1 == ay2) return fluid_pin_on_seg(ax1, ay1, bx1, by1, bx2, by2);  /* A is a point */
  if(bx1 == bx2 && by1 == by2) return fluid_pin_on_seg(bx1, by1, ax1, ay1, ax2, ay2);  /* B is a point */
  ah = (ay1 == ay2); av = (ax1 == ax2);
  bh = (by1 == by2); bv = (bx1 == bx2);
  if(!(ah || av) || !(bh || bv)) return 0;          /* diagonal: unsupported, never a false hit */
  if(ah && bh) {                                    /* both horizontal: same row + overlapping x */
    double alo, ahi, blo, bhi;
    if(fabs(ay1 - by1) > tol) return 0;
    alo = ax1 < ax2 ? ax1 : ax2; ahi = ax1 < ax2 ? ax2 : ax1;
    blo = bx1 < bx2 ? bx1 : bx2; bhi = bx1 < bx2 ? bx2 : bx1;
    return ahi >= blo - tol && bhi >= alo - tol;
  }
  if(av && bv) {                                    /* both vertical: same column + overlapping y */
    double alo, ahi, blo, bhi;
    if(fabs(ax1 - bx1) > tol) return 0;
    alo = ay1 < ay2 ? ay1 : ay2; ahi = ay1 < ay2 ? ay2 : ay1;
    blo = by1 < by2 ? by1 : by2; bhi = by1 < by2 ? by2 : by1;
    return ahi >= blo - tol && bhi >= alo - tol;
  }
  {                                                 /* perpendicular: cross point inside both */
    double hx1, hx2, hy, vx, vy1, vy2;
    if(ah) { hx1 = ax1 < ax2 ? ax1 : ax2; hx2 = ax1 < ax2 ? ax2 : ax1; hy = ay1;
             vx = bx1; vy1 = by1 < by2 ? by1 : by2; vy2 = by1 < by2 ? by2 : by1; }
    else   { hx1 = bx1 < bx2 ? bx1 : bx2; hx2 = bx1 < bx2 ? bx2 : bx1; hy = by1;
             vx = ax1; vy1 = ay1 < ay2 ? ay1 : ay2; vy2 = ay1 < ay2 ? ay2 : ay1; }
    return vx >= hx1 - tol && vx <= hx2 + tol && hy >= vy1 - tol && hy <= vy2 + tol;
  }
}

/* (issue 0087) Like fluid_seg_pair_touch, but a shared contact EXACTLY at (ex,ey) does not count:
 * returns 1 iff A and B share some point OTHER than (ex,ey). The elbow future tie-break
 * (fluid_ml_future_covers) uses this against a co-moving pin's riser corridor because the candidate
 * L legitimately TERMINATES at its own moving pin (ex,ey) -- and that pin travels on in the next leg,
 * so a contact there is not a future short; only copper crossing the corridor ELSEWHERE is. A/B are
 * axis-aligned; a real (non-degenerate) collinear overlap always contains a non-(ex,ey) point => hit.
 * Same cadsnap/2 span tolerance; the pin-exemption match uses a tight epsilon (on-grid coords). */
static int fluid_seg_pair_touch_except(double ax1, double ay1, double ax2, double ay2,
                                       double bx1, double by1, double bx2, double by2,
                                       double ex, double ey)
{
  double tol = tclgetdoublevar("cadsnap") / 2.0;
  double pe = 1e-6;                                  /* pin-identity epsilon */
  int ah, av, bh, bv;
  if(tol < 1e-6) tol = 1e-6;
  if(!fluid_seg_pair_touch(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)) return 0;
  ah = (ay1 == ay2); av = (ax1 == ax2);
  bh = (by1 == by2); bv = (bx1 == bx2);
  /* perpendicular (or either degenerate): the touch is a single point -- exempt iff it IS (ex,ey) */
  if((ah && bv) || (av && bh) || (ax1 == ax2 && ay1 == ay2) || (bx1 == bx2 && by1 == by2)) {
    double px, py;
    if(ax1 == ax2 && ay1 == ay2)      { px = ax1; py = ay1; }   /* A is the point */
    else if(bx1 == bx2 && by1 == by2) { px = bx1; py = by1; }   /* B is the point */
    else if(ah)                       { px = bx1; py = ay1; }   /* A horiz, B vert -> (Bx, Ay) */
    else                              { px = ax1; py = by1; }   /* A vert, B horiz -> (Ax, By) */
    return !(fabs(px - ex) < pe && fabs(py - ey) < pe);
  }
  /* collinear (both horizontal same row, or both vertical same col): compute the overlap span */
  {
    double alo, ahi, blo, bhi, olo, ohi;
    if(ah) { alo = ax1<ax2?ax1:ax2; ahi = ax1<ax2?ax2:ax1; blo = bx1<bx2?bx1:bx2; bhi = bx1<bx2?bx2:bx1; }
    else   { alo = ay1<ay2?ay1:ay2; ahi = ay1<ay2?ay2:ay1; blo = by1<by2?by1:by2; bhi = by1<by2?by2:by1; }
    olo = alo > blo ? alo : blo;                      /* overlap [olo,ohi] along the shared axis */
    ohi = ahi < bhi ? ahi : bhi;
    if(ohi - olo > pe) return 1;                      /* real sub-segment: has a non-(ex,ey) point */
    /* single-point overlap: exempt iff it is (ex,ey) */
    if(ah) return !(fabs(olo - ex) < pe && fabs(ay1 - ey) < pe);
    return !(fabs(ax1 - ex) < pe && fabs(olo - ey) < pe);
  }
}

/* incremental_wire_reroute.md Phase III (§5/§6): would the manhattan L formed by the horizontal
 * leg (hx1,hy)-(hx2,hy) and the vertical leg (vx,vy1)-(vx,vy2) lay across a STATIONARY (foreign)
 * device between two of its pins that were on DISTINCT nets pre-move? That is the P2 short the naive
 * jog creates (R18's riser leg sweeping through v8). The L is tested AS A WHOLE (union of both
 * legs), NOT leg-by-leg: an L bridges its two legs through the shared corner, so a device with one
 * distinct-net pin on the horizontal leg and another on the vertical leg is shorted through the
 * corner -- a per-leg test misses it (adversarial review, cross-leg hole). A pin counts if it is on
 * EITHER leg. Uses the START name snapshot (fluid_g.snap_pinnet), so it is a pure function of
 * (snapshot, geometry) -- no live node[], deterministic. Same base-walk as fluid_check_device_merge,
 * plus a sel==0 (stationary) filter: a moving/partially-selected device's pins travel WITH the drag,
 * so it is not a fixed obstacle. Cost O(fixed_inst * pins^2), pins 2..4. */
static int fluid_L_bridges_device(double hx1, double hy, double hx2, double vx, double vy1, double vy2)
{
  int i, p, q, k = 0;
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return 0;
  for(i = 0; i < xctx->instances; ++i) {
    int npins, base;
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(k > fluid_g.snap_npins) break;                /* structure drift guard */
    if(xctx->inst[i].sel) continue;                /* only STATIONARY devices are obstacles */
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(type && !strcmp(type, "label")) continue;   /* net labels are not devices */
    for(p = 0; p < npins; ++p) {
      const char *bp = fluid_g.snap_pinnet[base + p];
      double px, py;
      if(!bp || !bp[0]) continue;
      get_inst_pin_coord(i, p, &px, &py);
      /* pin p anywhere on the L (either leg; the corner is shared -> a corner-straddle counts) */
      if(!(fluid_pin_on_seg(px, py, hx1, hy, hx2, hy) ||
           fluid_pin_on_seg(px, py, vx, vy1, vx, vy2))) continue;
      for(q = p + 1; q < npins; ++q) {
        const char *bq = fluid_g.snap_pinnet[base + q];
        double qx, qy;
        if(!bq || !bq[0] || !strcmp(bp, bq)) continue;   /* need distinct pre-move named nets */
        get_inst_pin_coord(i, q, &qx, &qy);
        if(fluid_pin_on_seg(qx, qy, hx1, hy, hx2, hy) ||
           fluid_pin_on_seg(qx, qy, vx, vy1, vx, vy2)) return 1;
      }
    }
  }
  return 0;
}

/* incremental_wire_reroute.md Phase III: is the L-route implied by orientation `ml` blocked -- does
 * it lay across a stationary device between two distinct-net pins (either leg, or straddling the
 * corner)? sel1 = the wire's moving endpoint is endpoint 1 (SELECTED1). The leg geometry mirrors the
 * four place_moved_wire branches EXACTLY (verified): horizontal leg spans rx1..rx2 at hy, vertical
 * leg spans ry1..ry2 at vx, meeting at the corner (vx,hy). */
static int fluid_ml_blocked(int ml, int sel1)
{
  double rx1 = xctx->rx1, ry1 = xctx->ry1, rx2 = xctx->rx2, ry2 = xctx->ry2;
  double hy = sel1 ? ((ml & 1) ? ry2 : ry1) : ((ml & 1) ? ry1 : ry2);   /* horizontal leg y */
  double vx = sel1 ? ((ml & 1) ? rx1 : rx2) : ((ml & 1) ? rx2 : rx1);   /* vertical leg x */
  return fluid_L_bridges_device(rx1, hy, rx2, vx, ry1, ry2);
}

/* incremental_wire_reroute.md Layer 2 helpers (below). Largest on-grid value strictly LESS than v /
 * strictly GREATER than v -- used to pick a detour row one grid OUTSIDE a device body edge. */
static double fluid_grid_below(double v, double grid)
{
  double q = floor(v / grid) * grid;
  if(q >= v) q -= grid;
  return q;
}
static double fluid_grid_above(double v, double grid)
{
  double q = ceil(v / grid) * grid;
  if(q <= v) q += grid;
  return q;
}

/* incremental_wire_reroute.md Layer 3: perp-axis (horiz? y : x) min/max over ALL obstacle geometry
 * -- every instance world bbox and every wire endpoint -- so the outward detour-row search (below)
 * has a finite, geometry-derived cap. One grid beyond this extent on a side, a detour's along-leg
 * (leg2) can meet no obstacle, so a side still blocked out there is a permanently-blocked riser
 * (a foreign/co-moving pin fixed on M's or the landing column) => stop searching that side and
 * decline cleanly, never widening into a never-terminating scan. */
static void fluid_perp_extent(int horiz, double *plo, double *phi)
{
  double lo = 0, hi = 0;
  int seen = 0, i, w;
  for(w = 0; w < xctx->wires; ++w) {
    double a = horiz ? xctx->wire[w].y1 : xctx->wire[w].x1;
    double b = horiz ? xctx->wire[w].y2 : xctx->wire[w].x2;
    if(!seen) { lo = hi = a; seen = 1; }
    if(a < lo) lo = a; if(a > hi) hi = a;
    if(b < lo) lo = b; if(b > hi) hi = b;
  }
  for(i = 0; i < xctx->instances; ++i) {
    double a, b;
    if(xctx->inst[i].ptr < 0) continue;
    a = horiz ? xctx->inst[i].y1 : xctx->inst[i].x1;
    b = horiz ? xctx->inst[i].y2 : xctx->inst[i].x2;
    if(!seen) { lo = hi = a; seen = 1; }
    if(a < lo) lo = a; if(a > hi) hi = a;
    if(b < lo) lo = b; if(b > hi) hi = b;
  }
  *plo = lo; *phi = hi;
}

/* Layer 2: pristine (START-snapshot) net name of the MOVING instance pin at (x,y), or NULL if none.
 * Same instance/pin walk order as fluid_build_partition (skip ptr<0), so the snapshot index lines up
 * with fluid_g.snap_pinnet. */
static const char *fluid_moving_pin_net(double x, double y)
{
  int i, p, k = 0, npins, base;
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return NULL;
  for(i = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_g.snap_npins) break;
    if(!xctx->inst[i].sel) continue;                 /* only MOVING instances */
    for(p = 0; p < npins; ++p) {
      double px, py;
      get_inst_pin_coord(i, p, &px, &py);
      if(point_near_pin(px, py, x, y)) return fluid_g.snap_pinnet[base + p];
    }
  }
  return NULL;
}

/* Layer 2: does segment (x1,y1)-(x2,y2) pass over any STATIONARY device pin that was on a net OTHER
 * than `nf` at START? Such a pin on a detour leg would merge nf with that foreign net -- a NEW short.
 * A same-net (== nf) pin or an unconnected (empty) pin is fine to touch. */
static int fluid_seg_hits_foreign_pin(double x1, double y1, double x2, double y2, const char *nf)
{
  int i, p, k = 0, npins, base;
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return 0;
  for(i = 0; i < xctx->instances; ++i) {
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_g.snap_npins) break;
    if(xctx->inst[i].sel) continue;                  /* only STATIONARY devices are obstacles */
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(type && !strcmp(type, "label")) continue;
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_g.snap_pinnet[base + p];
      double px, py;
      if(!pn || !pn[0]) continue;
      if(nf && !strcmp(pn, nf)) continue;            /* same net: not a short */
      get_inst_pin_coord(i, p, &px, &py);
      if(fluid_pin_on_seg(px, py, x1, y1, x2, y2)) return 1;
    }
  }
  return 0;
}

/* Layer 2: does a detour leg (x1,y1)-(x2,y2) pass over a pin of a MOVING (co-dragged) instance that
 * is NOT the follow pin M (mx,my) and is on a net OTHER than NF? A rigidly-dragged multi-terminal
 * device carries its OTHER pins to fixed post-move offsets near M; a detour leg plowing through one
 * solders it onto NF -- a NEW device short (e.g. a MOS gate/bulk merged onto the source it was routed
 * for). fluid_seg_hits_foreign_pin() deliberately skips sel!=0 instances (stationary obstacles only),
 * so this is its moving-instance counterpart (adversarial re-review wf_582991bf). Uses the pristine
 * (START) net -- a moving pin whose net == NF, or the follow pin M itself, is fine to touch. */
static int fluid_seg_hits_moving_pin(double x1, double y1, double x2, double y2,
                                     const char *nf, double mx, double my)
{
  int i, p, k = 0, npins, base;
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return 0;
  for(i = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_g.snap_npins) break;
    if(!xctx->inst[i].sel) continue;                 /* only MOVING (co-dragged) instances */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_g.snap_pinnet[base + p];
      double px, py;
      get_inst_pin_coord(i, p, &px, &py);            /* live POST-move coord */
      /* exempt the follow pin M itself (its riser legitimately starts at M) by EXACT coincidence,
       * not point_near_pin's cadsnap/2 tolerance -- a DISTINCT co-dragged pin landing 1..cadsnap/2 from
       * M must NOT be treated as M (adversarial re-review wf_eade2790: it was soldered onto NF). M is
       * on NF anyway, so the net check below is the real exemption; this is a belt-and-suspenders. */
      if(px == mx && py == my) continue;             /* the follow pin M itself */
      if(pn && pn[0] && nf && !strcmp(pn, nf)) continue;  /* already on NF (incl. M): no new merge */
      if(fluid_pin_on_seg(px, py, x1, y1, x2, y2)) return 1;
    }
  }
  return 0;
}

/* issue 0085 (blind-elbow diagonal fallback, doc/claude/issues/0085-*.md): FULL hazard
 * classification of the L orientation `ml` for the stretching wire (sel1: the moving endpoint is
 * endpoint 1). fluid_ml_blocked tested only the stationary-device two-pin bridge, so the 0081
 * single-diagonal-pass fallback picked "clean" L elbows that (a) ran the moved device's OWN far pin
 * over (R18.P's riser plowing R18.M) and (b) T'd onto a stationary foreign wire's endpoint (C12's
 * stub) -- both P2 shorts (tests/from_user/after_5.sch). Bitmask:
 *   FLUID_MLH_BRIDGE  stationary device with two distinct-pristine-net pins on the L (Phase III class)
 *   FLUID_MLH_MOVPIN  the L covers a CO-MOVING pin (at its POST-move position) on a different
 *                     pristine net -- typically the moving device's own other pin
 *   FLUID_MLH_FPIN    a lone stationary foreign-net pin under either leg (a merge without a bridge)
 *   FLUID_MLH_STRAY   a wire-contact hazard whose foreignness cannot be pristine-net-verified: a
 *                     stationary wire's endpoint lands on a leg (or the L's corner lands on a
 *                     stationary wire), or a partially-selected SIBLING follow wire's FIXED
 *                     endpoint lands on a leg (review wf_e348633c F1 -- its span is about to be
 *                     relaid but its anchor stays put and is a real contact). Exemptions (one-hop
 *                     same-net evidence, review F2): a wire touching the anchor A, touching M (the
 *                     pin landing merges it in every orientation, test_wireedit_39 C2), touching
 *                     M's PRE-move position, or tapping the stretched wire's own PRE-move span
 *                     A..preM (already connected pre-move -- flipping away from re-covering that
 *                     span would DISCONNECT the tap, worse than any flip could gain).
 *   FLUID_MLH_SPANLOSS the wire's PRE-move span A..preM carries a stationary attachment strictly
 *                     inside it (tap endpoint / mid-span-fed pin) that no leg of this orientation
 *                     re-covers -- relocating the copper strands it, a P1 disconnect (review F2).
 * BRIDGE/FPIN/MOVPIN/SPANLOSS are geometrically/pristine-net-verified; STRAY is heuristic, hence
 * the severity split in fluid_mlh_sev(). When nf is unknown (M is not a moving-instance pin, e.g. a
 * wire-junction grab) the MOVPIN/label classes cannot verify distinctness and degrade to the
 * heuristic STRAY band instead of a false sev-2 (review F4). Stationary net-LABEL pins -- skipped
 * by every shared helper -- are classified here explicitly (review F3): a label pin under a leg
 * names the copper beneath it, so a distinct-pristine-net label is a merge (FPIN). Runs
 * PRE-commit: the ELEMENT commit loop runs after the wire pass, so co-moving pins sit at live
 * (pre-move) coords and are tested at coord+delta, and M's pristine net is looked up at M-delta
 * (rot/flip==0 is gated by the caller). Pure function of (snapshot, geometry, delta) =>
 * deterministic, release==stepwise. Returns 0 with no armed snapshot (same gate as before). */
#define FLUID_MLH_BRIDGE   1
#define FLUID_MLH_MOVPIN   2
#define FLUID_MLH_FPIN     4
#define FLUID_MLH_STRAY    8
#define FLUID_MLH_SPANLOSS 16
static int fluid_ml_hazards(int ml, int sel1)
{
  double rx1 = xctx->rx1, ry1 = xctx->ry1, rx2 = xctx->rx2, ry2 = xctx->ry2;
  double hy = sel1 ? ((ml & 1) ? ry2 : ry1) : ((ml & 1) ? ry1 : ry2);   /* horizontal leg y */
  double vx = sel1 ? ((ml & 1) ? rx1 : rx2) : ((ml & 1) ? rx2 : rx1);   /* vertical leg x */
  double mx = sel1 ? rx1 : rx2, my = sel1 ? ry1 : ry2;                  /* moving endpoint M */
  double ax = sel1 ? rx2 : rx1, ay = sel1 ? ry2 : ry1;                  /* fixed anchor A */
  double cx = vx, cy = hy;                                              /* the L's corner */
  double pmx, pmy;                                                      /* M's PRE-move position */
  const char *nf;
  int i, p, k, npins, base, h = 0, m;

  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return 0;
  /* rotate_keep_connected_stretch.md / issue 0099: under a rotated/flipped stretch the moving pin M
   * did NOT merely translate -- it rotated about a pivot, THEN translated by delta. Recover M's true
   * PRE-move position so the pristine-net lookup (nf) and the pre-move span A..preM tests below
   * reference the REAL pin, not a rotated-back-by-delta phantom off the grid.
   * issue 0100: mid-move ALT-R issues ROTATE|ROTATELOCAL (callback.c:5100), so the pivot is NOT
   * always the global grab point xctx->{x1,y1} -- the commit block hands the pristine endpoint down
   * directly (fluid_stretch_premove_*), exact under ANY pivot and equal to the old inverse-about-
   * {x1,y1} under plain ROTATE. The inverse math stays as the fallback for a caller that did not arm
   * the hand-down. For move_rot==0 && move_flip==0 this is BYTE-IDENTICAL to the old `mx-delta`
   * (the branch is skipped). */
  if(xctx->move_rot || xctx->move_flip) {
    if(fluid_g.stretch_premove_valid) {
      pmx = fluid_g.stretch_premove_x; pmy = fluid_g.stretch_premove_y;
    } else {
      double pvx = xctx->x1, pvy = xctx->y1, qx = mx - xctx->deltax, qy = my - xctx->deltay, fx, fy;
      ROTATION((4 - xctx->move_rot) & 3, 0, pvx, pvy, qx, qy, fx, fy);
      pmx = xctx->move_flip ? 2 * pvx - fx : fx;
      pmy = fy;
    }
  } else {
    pmx = mx - xctx->deltax; pmy = my - xctx->deltay;
  }
  nf = fluid_moving_pin_net(pmx, pmy);

  /* (1) stationary device two-distinct-net-pin bridge (the original Phase III test) */
  if(fluid_L_bridges_device(rx1, hy, rx2, vx, ry1, ry2)) h |= FLUID_MLH_BRIDGE;

  /* (2) co-moving pin plow: a pin of a MOVING instance, at its POST-move position (live + delta),
   * on a different pristine net, covered by either leg. The moving endpoint M itself is exempt. */
  for(i = 0, k = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_g.snap_npins) break;
    if(!xctx->inst[i].sel) continue;                 /* only MOVING (co-dragged) instances */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_g.snap_pinnet[base + p];
      double px, py;
      get_inst_pin_coord(i, p, &px, &py);            /* live == PRE-move here */
      /* issue 0099: a co-moving pin ROTATES about the pivot then translates -- it does not merely
       * translate. Apply the SAME ROTATION(pivot)+delta the commit block applies to the instance, so a
       * rotated sibling pin (e.g. R18's other pin landing where an elbow leg runs) is tested at its TRUE
       * post-move position. move_rot==0 && move_flip==0 skips this => byte-identical translation path.
       * issue 0100: under ALT-R/ALT-F (ROTATELOCAL) the ELEMENT commit rotates each instance about ITS
       * OWN origin -- mirror that pivot here or the sibling pin is predicted at the wrong spot and the
       * elbow can pick a shorting orientation. */
      if(xctx->move_rot || xctx->move_flip) {
        double rpx, rpy;
        double pvx = xctx->rotatelocal ? xctx->inst[i].x0 : xctx->x1;
        double pvy = xctx->rotatelocal ? xctx->inst[i].y0 : xctx->y1;
        ROTATION(xctx->move_rot, xctx->move_flip, pvx, pvy, px, py, rpx, rpy);
        px = rpx; py = rpy;
      }
      px += xctx->deltax; py += xctx->deltay;
      if(px == mx && py == my) continue;             /* the follow pin M itself */
      if(!pn || !pn[0]) continue;                    /* unconnected pin: no merge */
      if(nf && !strcmp(pn, nf)) continue;            /* same pristine net: not a short */
      if(fluid_pin_on_seg(px, py, rx1, hy, rx2, hy) ||
         fluid_pin_on_seg(px, py, vx, ry1, vx, ry2)) {
        /* nf unknown => distinctness unverifiable: heuristic band, not a false sev-2 (review F4) */
        h |= nf ? FLUID_MLH_MOVPIN : FLUID_MLH_STRAY;
        break;
      }
    }
    if(h & (FLUID_MLH_MOVPIN | FLUID_MLH_STRAY)) break;
  }

  /* (3) lone stationary foreign-net pin under either leg (needs nf to tell foreign from own) */
  if(nf && nf[0] &&
     (fluid_seg_hits_foreign_pin(rx1, hy, rx2, hy, nf) ||
      fluid_seg_hits_foreign_pin(vx, ry1, vx, ry2, nf))) h |= FLUID_MLH_FPIN;

  /* (3b) stationary net-LABEL pin under either leg (review F3): every shared helper skips
   * type=="label", but a label names the copper beneath its pin, so a distinct-pristine-net label
   * under a leg is a merge. Labels exactly at A or M are orientation-independent contacts: skip. */
  for(i = 0, k = 0; i < xctx->instances && !(h & (FLUID_MLH_FPIN | FLUID_MLH_STRAY)); ++i) {
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_g.snap_npins) break;
    if(xctx->inst[i].sel) continue;                  /* only STATIONARY labels */
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(!type || strcmp(type, "label")) continue;
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_g.snap_pinnet[base + p];
      double px, py;
      if(!pn || !pn[0]) continue;
      if(nf && !strcmp(pn, nf)) continue;            /* same pristine net: not a merge */
      get_inst_pin_coord(i, p, &px, &py);
      if((px == ax && py == ay) || (px == mx && py == my)) continue;
      if(fluid_pin_on_seg(px, py, rx1, hy, rx2, hy) ||
         fluid_pin_on_seg(px, py, vx, ry1, vx, ry2)) {
        h |= nf ? FLUID_MLH_FPIN : FLUID_MLH_STRAY;  /* no nf: heuristic band (review F4) */
        break;
      }
    }
  }

  /* (4) stray wire contact. Fully STATIONARY wires (sel==0): an endpoint on a leg, or the L's
   * corner on the wire's span, at a point other than A or M. Wire-level exemptions (one-hop
   * same-net evidence): a wire touching the anchor A (pre-connected), touching M (the pin landing
   * merges it in every orientation, test_wireedit_39 C2), touching M's PRE-move position, or
   * tapping the stretched wire's own PRE-move span A..preM (already connected; flipping away from
   * re-covering that span would DISCONNECT the tap -- review wf_e348633c F2). Partially-selected
   * SIBLING follow wires (SELECTED1/2): their span is about to be relaid, but the FIXED endpoint
   * stays put and is a real contact (review F1) -- test just that point, with the same A/M/pre-span
   * exemptions (the stretching wire n itself is exempted here: its fixed endpoint IS A).
   * fluid_pin_on_seg / exact == compares, like fluid_seg_stray_contact. */
  for(m = 0; m < xctx->wires && !(h & FLUID_MLH_STRAY); ++m) {
    unsigned int msel = xctx->wire[m].sel;
    double wx1, wy1, wx2, wy2;
    if((msel & SELECTED) || ((msel & SELECTED1) && (msel & SELECTED2)))
      continue;                                      /* rigid co-moving wire: both endpoints travel */
    wx1 = xctx->wire[m].x1; wy1 = xctx->wire[m].y1;
    wx2 = xctx->wire[m].x2; wy2 = xctx->wire[m].y2;
    if(msel == 0) {
      if(fluid_pin_on_seg(ax, ay, wx1, wy1, wx2, wy2)) continue;  /* touches the anchor: pre-connected */
      if(fluid_pin_on_seg(mx, my, wx1, wy1, wx2, wy2)) continue;  /* touches M: merged by the landing */
      if(fluid_pin_on_seg(pmx, pmy, wx1, wy1, wx2, wy2)) continue;/* sat under pre-move M */
      if(fluid_pin_on_seg(wx1, wy1, ax, ay, pmx, pmy) ||
         fluid_pin_on_seg(wx2, wy2, ax, ay, pmx, pmy)) continue;  /* taps our own pre-move span */
      /* wire m's endpoint lands on a leg, away from A / M */
      if((fluid_pin_on_seg(wx1, wy1, rx1, hy, rx2, hy) || fluid_pin_on_seg(wx1, wy1, vx, ry1, vx, ry2)) &&
         !(wx1 == ax && wy1 == ay) && !(wx1 == mx && wy1 == my)) { h |= FLUID_MLH_STRAY; break; }
      if((fluid_pin_on_seg(wx2, wy2, rx1, hy, rx2, hy) || fluid_pin_on_seg(wx2, wy2, vx, ry1, vx, ry2)) &&
         !(wx2 == ax && wy2 == ay) && !(wx2 == mx && wy2 == my)) { h |= FLUID_MLH_STRAY; break; }
      /* the L's corner lands on wire m's span (a T of the L onto m) */
      if(fluid_pin_on_seg(cx, cy, wx1, wy1, wx2, wy2) &&
         !(cx == ax && cy == ay) && !(cx == mx && cy == my)) { h |= FLUID_MLH_STRAY; break; }
    } else {
      /* partial sibling follow wire: only its FIXED (stationary) endpoint is a real contact.
       * A sibling whose MOVING endpoint shares our junction (== preM, e.g. two follow wires
       * grabbed at the same pin) is on our net by construction: exempt (round-2 wf_876b8a88). */
      double fx = (msel & SELECTED1) ? wx2 : wx1;
      double fy = (msel & SELECTED1) ? wy2 : wy1;
      double sx = (msel & SELECTED1) ? wx1 : wx2;    /* sibling's MOVING endpoint (pre-move) */
      double sy = (msel & SELECTED1) ? wy1 : wy2;
      if(sx == pmx && sy == pmy) continue;           /* shares our junction: same net */
      if((fx == ax && fy == ay) || (fx == mx && fy == my)) continue;
      if(fluid_pin_on_seg(fx, fy, ax, ay, pmx, pmy)) continue;    /* on our own pre-move span */
      if(fluid_pin_on_seg(fx, fy, rx1, hy, rx2, hy) ||
         fluid_pin_on_seg(fx, fy, vx, ry1, vx, ry2)) { h |= FLUID_MLH_STRAY; break; }
    }
  }

  /* (5) span-loss (review F2 / test 43 D4): the wire's PRE-move span A..preM carries an attachment
   * STRICTLY inside it -- a stationary wire's endpoint (a tap), a partial SIBLING follow wire's
   * FIXED anchor (the T onto our span is what joined the two nets; its own relay lands on a
   * DIFFERENT pin -- round-2 wf_876b8a88), or a stationary instance pin fed mid-span -- and this
   * orientation does NOT keep that attachment connected: relocating the copper strands it, a P1
   * DISCONNECT. "Still connected" for a tap WIRE also counts its OTHER endpoint landing on a leg
   * or the L's corner landing on its span (connectivity retained through the tap itself --
   * round-2 false-positive fix); endpoint-on-wire IS connection in xschem, so this is
   * geometrically verified => verified severity band; it ties against e.g. a MOVPIN on the
   * covering orientation instead of losing to it (keep ml0 = the pre-fix outcome). */
  for(m = 0; m < xctx->wires && !(h & FLUID_MLH_SPANLOSS); ++m) {
    unsigned int msel = xctx->wire[m].sel;
    double wx1, wy1, wx2, wy2;
    int e, nend;
    if((msel & SELECTED) || ((msel & SELECTED1) && (msel & SELECTED2)))
      continue;                                      /* rigid co-moving: travels with the drag */
    wx1 = xctx->wire[m].x1; wy1 = xctx->wire[m].y1;
    wx2 = xctx->wire[m].x2; wy2 = xctx->wire[m].y2;
    nend = (msel == 0) ? 2 : 1;                      /* partial sibling: only its FIXED endpoint */
    for(e = 0; e < nend; ++e) {
      double ex, ey, ox, oy;
      if(msel == 0) {
        ex = e ? wx2 : wx1; ey = e ? wy2 : wy1;
        ox = e ? wx1 : wx2; oy = e ? wy1 : wy2;      /* the tap's other endpoint */
      } else {
        ex = (msel & SELECTED1) ? wx2 : wx1; ey = (msel & SELECTED1) ? wy2 : wy1;
        ox = (msel & SELECTED1) ? wx1 : wx2; oy = (msel & SELECTED1) ? wy1 : wy2;
        if(ox == pmx && oy == pmy) continue;         /* shares our junction: relays with us */
      }
      if(!fluid_pin_on_seg(ex, ey, ax, ay, pmx, pmy)) continue;   /* not on the pre-move span */
      if((ex == ax && ey == ay) || (ex == pmx && ey == pmy)) continue;  /* span end, not inside */
      if(fluid_pin_on_seg(ex, ey, rx1, hy, rx2, hy) ||
         fluid_pin_on_seg(ex, ey, vx, ry1, vx, ry2)) continue;    /* a leg still covers it */
      if(msel == 0) {
        /* connectivity retained through the tap itself? (other endpoint on a leg / corner on it) */
        if(fluid_pin_on_seg(ox, oy, rx1, hy, rx2, hy) ||
           fluid_pin_on_seg(ox, oy, vx, ry1, vx, ry2)) continue;
        if(fluid_pin_on_seg(cx, cy, wx1, wy1, wx2, wy2)) continue;
      }
      h |= FLUID_MLH_SPANLOSS; break;
    }
  }
  for(i = 0, k = 0; i < xctx->instances && !(h & FLUID_MLH_SPANLOSS); ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_g.snap_npins) break;
    if(xctx->inst[i].sel) continue;                  /* only STATIONARY instances */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_g.snap_pinnet[base + p];
      double px, py;
      if(!pn || !pn[0]) continue;                    /* was not connected: nothing to strand */
      get_inst_pin_coord(i, p, &px, &py);
      if(!fluid_pin_on_seg(px, py, ax, ay, pmx, pmy)) continue;
      if((px == ax && py == ay) || (px == pmx && py == pmy)) continue;
      if(fluid_pin_on_seg(px, py, rx1, hy, rx2, hy) ||
         fluid_pin_on_seg(px, py, vx, ry1, vx, ry2)) continue;
      h |= FLUID_MLH_SPANLOSS; break;
    }
  }
  return h;
}

/* issue 0085: severity of a hazard mask for the orientation choice. Pristine-net-VERIFIED classes
 * (bridge / co-moving pin / foreign pin) rank above the heuristic stray-wire-contact class, so a
 * proven short still flips to a merely stray-flagged orientation (preserving the old flip behavior
 * where the flip target's stray contact was invisible), while a stray-only orientation never steals
 * the choice from a fully clean one. */
static int fluid_mlh_sev(int h)
{
  return ((h & (FLUID_MLH_BRIDGE | FLUID_MLH_MOVPIN | FLUID_MLH_FPIN | FLUID_MLH_SPANLOSS)) ? 2 : 0)
       + ((h & FLUID_MLH_STRAY) ? 1 : 0);
}

/* issue 0086 (future-blind elbow tie-break): during leg 0 of the 0081 X-then-Y decomposition, does
 * the L implied by `ml` lay copper on the RISER a co-moving foreign-pristine-net instance pin drags
 * as the remaining leg carries it to its final landing? Both orientations can be hazard-free at
 * leg-0 sight while one of them paints the corridor the OTHER moving pin lands in after the Y leg --
 * by then the follow stretch is degenerate (a straight extension through its own anchor, no elbow
 * freedom) and the short is unavoidable, collapsing the whole gesture to the rigid diagonal relay
 * although a clean Manhattan route exists (before_3.sch -> after_6.sch, R18 by (+150,-80)). Used ONLY
 * as a tie-break between two P2-clean orientations, so a hit can never pick a hazardous L. Same walk,
 * index lineup, M/same-net/unconnected exemptions and leg geometry as fluid_ml_hazards class (2).
 * issue 0087: the co-moving pin is NOT just its final POINT -- the remaining leg drags a RISER from
 * its intermediate (post-current-leg) position to the final one, so this tests the whole corridor
 * SEGMENT (fluid_seg_pair_touch_except), exempting a contact AT the L's own moving pin (that pin
 * travels on next leg; the L must legitimately end there). Leg 1's future=0 collapses the corridor
 * to the old point test, so later legs / pure-axis / plain moves are byte-identical (fluid_leg_future_*
 * zero outside decomposed legs => returns 0). Pure function of (snapshot, geometry, deltas) =>
 * deterministic, release==stepwise. */
static int fluid_ml_future_covers(int ml, int sel1)
{
  double rx1 = xctx->rx1, ry1 = xctx->ry1, rx2 = xctx->rx2, ry2 = xctx->ry2;
  double hy = sel1 ? ((ml & 1) ? ry2 : ry1) : ((ml & 1) ? ry1 : ry2);   /* horizontal leg y */
  double vx = sel1 ? ((ml & 1) ? rx1 : rx2) : ((ml & 1) ? rx2 : rx1);   /* vertical leg x */
  double mx = sel1 ? rx1 : rx2, my = sel1 ? ry1 : ry2;                  /* moving endpoint M */
  const char *nf;
  int i, p, k, npins, base;

  if(fluid_g.leg_future_dx == 0.0 && fluid_g.leg_future_dy == 0.0) return 0;
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return 0;
  nf = fluid_moving_pin_net(mx - xctx->deltax, my - xctx->deltay);
  for(i = 0, k = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_g.snap_npins) break;
    if(!xctx->inst[i].sel) continue;                 /* only MOVING (co-dragged) instances */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_g.snap_pinnet[base + p];
      double px, py;
      get_inst_pin_coord(i, p, &px, &py);            /* live == PRE-leg here */
      if(px + xctx->deltax == mx && py + xctx->deltay == my) continue;  /* the follow pin M itself */
      if(!pn || !pn[0]) continue;                    /* unconnected pin: no merge (class-2 parity) */
      if(nf && !strcmp(pn, nf)) continue;            /* same pristine net: own copper is fine */
      /* issue 0087: the co-moving pin's RISER corridor -- from its intermediate (post-current-leg)
       * position to its FINAL one -- not just the final point (leg 1's future=0 collapses this to
       * the old point test, so later legs are byte-identical). */
      {
        double ix = px + xctx->deltax, iy = py + xctx->deltay;                       /* intermediate */
        double fxc = ix + fluid_g.leg_future_dx, fyc = iy + fluid_g.leg_future_dy;        /* final       */
        /* exempt a corridor contact AT this L's own moving pin (mx,my): the L must end there and
         * that pin moves on in the next leg -- only copper crossing the corridor elsewhere shorts. */
        if(fluid_seg_pair_touch_except(ix, iy, fxc, fyc, rx1, hy, rx2, hy, mx, my) ||
           fluid_seg_pair_touch_except(ix, iy, fxc, fyc, vx, ry1, vx, ry2, mx, my)) return 1;
      }
    }
  }
  return 0;
}

/* issue 0086 (future-blind corner slide): would sliding wire n rigidly by the current leg's delta
 * park its copper -- or drag the corner (fx,fy)'s collinear-neighbour endpoints -- into the RISER a
 * co-moving foreign-pristine-net pin drags to its final landing? The corner slide is a P4 aesthetic;
 * when it fires here it REMOVES the elbow freedom the later leg needs: the neighbour's stretched
 * endpoint becomes a fixed anchor in the landing corridor, so the leg-1 follow stretch is a
 * degenerate straight run into a guaranteed short (before_3.sch, R18 by (+150,-80): the C12 stub
 * corner slides from (-400,-90) to (-250,-90) == R18.M's final landing). issue 0087: it is not just
 * the final POINT -- a horizontal slid stub whose far end parks on the shared landing COLUMN but a
 * grid off the final row still lands inside the riser (before_3.sch, R18 by (+250,-90)), so this
 * tests the whole corridor SEGMENT (fluid_seg_pair_touch). (mx,my) = wire n's moving (pin-driven)
 * endpoint at its PRE-leg position, used to resolve the wire's own pristine net. Same walk/exemptions
 * as fluid_ml_future_covers. Inert (returns 0) outside decomposed fluid legs or without a snapshot
 * => plain moves are byte-identical. */
static int fluid_slide_future_hazard(int n, double fx, double fy, double mx, double my)
{
  const char *nf;
  int i, p, k, m, npins, base;
  double dx = xctx->deltax, dy = xctx->deltay;
  if(fluid_g.leg_future_dx == 0.0 && fluid_g.leg_future_dy == 0.0) return 0;
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return 0;
  nf = fluid_moving_pin_net(mx, my);
  for(i = 0, k = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_g.snap_npins) break;
    if(!xctx->inst[i].sel) continue;                 /* only MOVING (co-dragged) instances */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_g.snap_pinnet[base + p];
      double px, py;
      get_inst_pin_coord(i, p, &px, &py);            /* live == PRE-leg here */
      if(px == mx && py == my) continue;             /* the driving pin M itself */
      if(!pn || !pn[0]) continue;                    /* unconnected pin: no merge (class-2 parity) */
      if(nf && !strcmp(pn, nf)) continue;            /* same pristine net: own copper is fine */
      /* issue 0087: the co-moving pin's RISER corridor (intermediate post-slide position ..
       * FINAL landing after the remaining legs), not just the final POINT. A horizontal slid stub
       * that parks its far end on the shared landing COLUMN but a grid off the final row still lands
       * inside the riser the later leg drags down that column -> short. Leg 1 (future=0) collapses
       * the corridor to a point == old behavior, so single-axis / plain moves are byte-identical. */
      {
        double ix = px + dx, iy = py + dy;                                    /* intermediate */
        double fxc = ix + fluid_g.leg_future_dx, fyc = iy + fluid_g.leg_future_dy; /* final        */
        /* on the slid wire's post-slide span? */
        if(fluid_seg_pair_touch(ix, iy, fxc, fyc, xctx->wire[n].x1 + dx, xctx->wire[n].y1 + dy,
                                                   xctx->wire[n].x2 + dx, xctx->wire[n].y2 + dy)) return 1;
        /* on a dragged collinear neighbour's post-stretch span (far end .. corner+delta)?
         * (a non-axis-aligned candidate span returns 0 from fluid_seg_pair_touch: no false hit) */
        for(m = 0; m < xctx->wires; ++m) {
          double ox, oy;
          if(m == n) continue;
          if(xctx->wire[m].x1 == fx && xctx->wire[m].y1 == fy)      { ox = xctx->wire[m].x2; oy = xctx->wire[m].y2; }
          else if(xctx->wire[m].x2 == fx && xctx->wire[m].y2 == fy) { ox = xctx->wire[m].x1; oy = xctx->wire[m].y1; }
          else continue;
          if(fluid_seg_pair_touch(ix, iy, fxc, fyc, ox, oy, fx + dx, fy + dy)) return 1;
        }
      }
    }
  }
  return 0;
}

/* Layer 2: would a detour leg (sx1,sy1)-(sx2,sy2) make a STRAY connection to some existing wire --
 * i.e. a T-junction at a point that is NOT the intended NF landing (cx,cy) nor the moving pin M
 * (mx,my)? A wire whose endpoint lands on the leg's span, or a leg endpoint that lands on another
 * wire, connects the two nets -- and unlike a foreign PIN (fluid_seg_hits_foreign_pin) the wire's net
 * is not cheaply known here, so ANY stray contact is treated as unsafe and makes the reroute pick the
 * OTHER detour side (or decline). Pure geometric crossings where both wires are mid-span do NOT
 * connect in xschem, so they are intentionally not flagged. `selfw` (the straddle wire being reused)
 * is excluded. */
static int fluid_seg_stray_contact(double sx1, double sy1, double sx2, double sy2,
                                   double cx, double cy, double mx, double my, int selfw)
{
  int m;
  for(m = 0; m < xctx->wires; ++m) {
    double ax, ay, bx, by;
    if(m == selfw) continue;
    ax = xctx->wire[m].x1; ay = xctx->wire[m].y1;
    bx = xctx->wire[m].x2; by = xctx->wire[m].y2;
    /* (1) wire m's endpoint lands on this leg (a T onto the detour) -- allowed only at C or M */
    if(fluid_pin_on_seg(ax, ay, sx1, sy1, sx2, sy2) &&
       !(ax == cx && ay == cy) && !(ax == mx && ay == my)) return 1;
    if(fluid_pin_on_seg(bx, by, sx1, sy1, sx2, sy2) &&
       !(bx == cx && by == cy) && !(bx == mx && by == my)) return 1;
    /* (2) a leg endpoint lands on wire m (a T onto m) -- allowed only at C or M */
    if(fluid_pin_on_seg(sx1, sy1, ax, ay, bx, by) &&
       !(sx1 == cx && sy1 == cy) && !(sx1 == mx && sy1 == my)) return 1;
    if(fluid_pin_on_seg(sx2, sy2, ax, ay, bx, by) &&
       !(sx2 == cx && sy2 == cy) && !(sx2 == mx && sy2 == my)) return 1;
  }
  return 0;
}

/* Layer 2: is there a NON-DEGENERATE wire (other than selfw), lying on the straddle line (y==perp if
 * horiz, else x==perp), that fully COVERS the along-span [u1,u2]? Used to confirm the NF bus extends
 * from the same-net pin one grid outward before landing the up-leg there. "Covers a span" (not merely
 * "touches a point") is deliberate: it rejects (a) a foreign wire that merely ends AT the offset
 * point, and (b) a degenerate zero-length wire, both of which a bare touch()/point_on_other_wire test
 * wrongly accepted at the pre-trim seam -- tearing the moving pin off its net (adversarial review
 * wf_838ec39f). Because the span starts at the same-net pin (u1==a_same), any covering wire also
 * carries NF, so no separate (cache-fragile) net lookup is needed. */
static int fluid_wire_covers_on_line(double u1, double u2, double perp, int horiz, int selfw)
{
  double lo = u1 < u2 ? u1 : u2, hi = u1 < u2 ? u2 : u1;
  int m;
  for(m = 0; m < xctx->wires; ++m) {
    double x1, y1, x2, y2, wlo, whi;
    if(m == selfw) continue;
    x1 = xctx->wire[m].x1; y1 = xctx->wire[m].y1;
    x2 = xctx->wire[m].x2; y2 = xctx->wire[m].y2;
    if(horiz) {
      if(y1 != y2 || x1 == x2 || y1 != perp) continue;   /* need a horizontal wire on the perp row */
      wlo = x1 < x2 ? x1 : x2; whi = x1 < x2 ? x2 : x1;
    } else {
      if(x1 != x2 || y1 == y2 || x1 != perp) continue;    /* need a vertical wire on the perp column */
      wlo = y1 < y2 ? y1 : y2; whi = y1 < y2 ? y2 : y1;
    }
    if(wlo <= lo && whi >= hi) return 1;                  /* covers the whole [lo,hi] span */
  }
  return 0;
}

/* incremental_wire_reroute.md Layer 2 (spec sec 5 step 2-3, sec 6): resolve a residual
 * both-orientations-blocked device short by ripping up the straddling follow leg and routing a
 * detour AROUND the device. Runs at the pre-trim seam (after the per-object commit loop, before
 * check_collapsing_objects), so -- like every pass in the shared geometry-commit block -- it is a
 * pure function of (pristine snapshot, total delta, obstacles): release == stepwise for free (Phase
 * II already reapplies the total delta each step). Gated identically to the Layer-1 flip
 * (fluid_editing && stretch_select && orthogonal_wiring && rot==flip==0) => default off byte-identical.
 *
 * Layer 1 (place_moved_wire flip) already avoids the short whenever ONE L orientation is clear; this
 * fires only when the naive route STILL lays a single leg straight across a stationary device between
 * two of its distinct-pre-move-net pins (both orientations blocked, or a degenerate straight-through
 * where the moved pin lands on the device pin row). The presence of that residual single-wire
 * straddle IS the trigger -- no separate both-blocked test needed.
 *
 * Conservative: DECLINES to the baseline (never makes it worse) unless every safety condition holds.
 * The straddling wire W has the moving pin M at one end and an anchor (on the follow net NF) at the
 * other, with device D between them. Of D's two straddled pins, one resolves to NF at START (the
 * same-net pin, legitimately connected) and the other is FOREIGN (the short). W is ripped up and
 * replaced by three legs:  M -> perpendicular to a detour row one grid OUTSIDE D's body -> along,
 * past D -> back up to the row, landing AT the same-net device pin (on NF and connected by
 * construction), shifted one grid outward to a visible offset solder-joint (spec sec 6) only when a
 * real NF wire demonstrably extends there. It never continues across D. The detour side (below/above;
 * left/right for a vertical W) is the FIRST whose three legs hit NO obstacle: a stationary foreign
 * pin (fluid_seg_hits_foreign_pin), a stray wire T-junction off the intended NF landing
 * (fluid_seg_stray_contact), or a co-dragged MOVING pin on a net != NF (fluid_seg_hits_moving_pin) --
 * so the "boxed between two devices" case takes the clear side, else it declines. Two adversarial
 * review rounds (wf_838ec39f landing net-blindness, wf_582991bf/wf_eade2790 moving-pin plow-through)
 * hardened these guards; each is conservative (over-reject => decline => baseline, never a short). */
static void fluid_reroute_around_obstacles(int orthogonal_wiring)
{
  double grid = tclgetdoublevar("cadsnap");
  int iter;
  if(!orthogonal_wiring) return;
  if(fluid_failsafe(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0)) return;
  if(fluid_failsafe(fluid_count_pins() != fluid_g.snap_npins)) return; /* instance set changed: snapshot walk unreliable */
  if(grid <= 0.0) grid = 1.0;

  /* one reroute per straddled device; cap the loop at instance count as a runaway backstop */
  for(iter = 0; iter < xctx->instances + 1; ++iter) {
    int D, p, q, w, k = 0, npins, base;
    int wfound = -1, Dfound = -1, horiz = 0;
    double px_s = 0, py_s = 0, px_f = 0, py_f = 0;   /* the two straddled pins' coords */
    const char *nf = NULL, *net_p = NULL, *net_q = NULL; /* their pristine (START) nets */

    /* --- find one residual single-wire straddle: a stationary device D with two distinct-net pins
     *     that both lie on ONE wire W, where W has exactly one moving-pin endpoint (=M) --- */
    for(D = 0; D < xctx->instances && wfound < 0; ++D) {
      const char *type;
      if(xctx->inst[D].ptr < 0) continue;
      npins = (xctx->inst[D].ptr + xctx->sym)->rects[PINLAYER];
      base = k; k += npins;
      if(base + npins > fluid_g.snap_npins) break;
      if(xctx->inst[D].sel) continue;                /* only STATIONARY devices */
      type = xctx->sym[xctx->inst[D].ptr].type;
      if(type && !strcmp(type, "label")) continue;
      for(p = 0; p < npins && wfound < 0; ++p) {
        const char *np = fluid_g.snap_pinnet[base + p];
        double pax, pay;
        if(!np || !np[0]) continue;
        get_inst_pin_coord(D, p, &pax, &pay);
        for(q = p + 1; q < npins && wfound < 0; ++q) {
          const char *nq = fluid_g.snap_pinnet[base + q];
          double qbx, qby;
          if(!nq || !nq[0] || !strcmp(np, nq)) continue;   /* need distinct pre-move nets */
          get_inst_pin_coord(D, q, &qbx, &qby);
          for(w = 0; w < xctx->wires; ++w) {
            double x1 = xctx->wire[w].x1, y1 = xctx->wire[w].y1;
            double x2 = xctx->wire[w].x2, y2 = xctx->wire[w].y2;
            int h = (y1 == y2 && x1 != x2), v = (x1 == x2 && y1 != y2);
            if(!h && !v) continue;
            if(!(fluid_pin_on_seg(pax, pay, x1, y1, x2, y2) &&
                 fluid_pin_on_seg(qbx, qby, x1, y1, x2, y2))) continue;
            wfound = w; Dfound = D; horiz = h;
            px_s = pax; py_s = pay; net_p = np;    /* pin p and its pristine net */
            px_f = qbx; py_f = qby; net_q = nq;    /* pin q and its pristine net */
            break;
          }
        }
      }
    }
    if(wfound < 0) break;                            /* no straddle left */

    /* --- classify + build the detour; any failed safety condition DECLINES (leave baseline) --- */
    {
      w = wfound; D = Dfound;
      {
      double x1 = xctx->wire[w].x1, y1 = xctx->wire[w].y1;
      double x2 = xctx->wire[w].x2, y2 = xctx->wire[w].y2;
      double perp0 = horiz ? y1 : x1;                /* the straddle row/col */
      double e1a = horiz ? x1 : y1, e2a = horiz ? x2 : y2;    /* endpoint along-coords */
      int e1mov = point_on_moving_pin(x1, y1);
      int e2mov = point_on_moving_pin(x2, y2);
      double a_m, a_p = horiz ? px_s : py_s, a_q = horiz ? px_f : py_f;
      double a_same, a_for, a_C, dir, t;
      double bx1, by1, bx2, by2, body_p_lo, body_p_hi;
      double Vb = 0;
      double plo_ext = 0, phi_ext = 0, below_stop = 0, above_stop = 0, vb_lo = 0, vb_hi = 0;
      int have = 0, ci, lo_done = 0, hi_done = 0, guard_steps = 0;
      char *prop = NULL;

      if(e1mov == e2mov) break;                      /* need exactly one moving-pin endpoint (=M) */
      a_m      = e1mov ? e1a : e2a;
      nf = fluid_moving_pin_net(e1mov ? x1 : x2, e1mov ? y1 : y2);
      if(!nf || !nf[0]) break;
      /* of the two straddled pins (nets net_p/net_q captured in detection), the same-net pin
       * resolves to NF at START and the other is foreign; require EXACTLY one to match NF */
      {
        if(net_p && net_p[0] && !strcmp(net_p, nf) && !(net_q && net_q[0] && !strcmp(net_q, nf))) {
          a_same = a_p; a_for = a_q;
        } else if(net_q && net_q[0] && !strcmp(net_q, nf) && !(net_p && net_p[0] && !strcmp(net_p, nf))) {
          a_same = a_q; a_for = a_p;
        } else break;                                /* cannot classify same/foreign vs NF */
      }
      /* the foreign pin must lie strictly between M and the same-net pin, so a detour landing one
       * grid outside the same-net pin (away from M) never has to pass the foreign pin */
      if(!((a_for - a_m) * (a_same - a_for) > 0.0)) break;
      dir = (a_same > a_m) ? 1.0 : -1.0;             /* M -> same-net pin (= anchor) direction */

      /* device world bbox (valid for stationary D after update_symbol_bboxes) */
      bx1 = xctx->inst[D].x1; by1 = xctx->inst[D].y1; bx2 = xctx->inst[D].x2; by2 = xctx->inst[D].y2;
      if(bx1 > bx2) { t = bx1; bx1 = bx2; bx2 = t; }
      if(by1 > by2) { t = by1; by1 = by2; by2 = t; }
      body_p_lo = horiz ? by1 : bx1; body_p_hi = horiz ? by2 : bx2;

      /* Landing column. Land AT the same-net device pin a_same: it is on NF and connected by
       * construction (a real pin the netlister binds the up-leg endpoint to), so P1/P2 hold with NO
       * fragile "is a wire here" search -- the earlier point_on_other_wire test matched transient jog
       * geometry / degenerate zero-length kiss stubs / a foreign wire ending at C and tore the moving
       * pin off its net (adversarial review wf_838ec39f, 8 confirmed P1 disconnects). As a pure
       * aesthetic upgrade, shift ONE grid outward (away from M) to a visible offset solder-joint only
       * when a real NF wire demonstrably extends there -- a non-degenerate wire COVERING the whole
       * pin->offset span on the straddle line (so it is the NF bus continuing, not a foreign wire
       * merely ending at C, nor a spurious degenerate match). */
      a_C = a_same;
      {
        double aC_off = a_same + dir * grid;
        if(fluid_wire_covers_on_line(a_same, aC_off, perp0, horiz, w)) a_C = aC_off;
      }
      if(a_C == a_m) break;                           /* degenerate landing (M already at the pin col) */

      /* Layer 3 (incremental_wire_reroute.md sec 5/6 -- multi-bend detour): OUTWARD-STEPPING
       * detour-row search. Layer 2 tried exactly one grid outside the body on each side and declined
       * if both were blocked; Layer 3 keeps stepping the detour row one grid further out until a
       * clear side is found, or both sides pass the schematic's perp-axis obstacle extent (then a
       * still-blocked side is a permanently-blocked riser -> decline cleanly). Step 1 tries below
       * then above at the body edge -- BYTE-IDENTICAL to Layer 2's pick, so every case Layer 2
       * already routed at step 1 is unchanged; only both-blocked cases search further. The 3-leg
       * construction + 9 obstacle guards are UNCHANGED (just evaluated at more candidate rows), so
       * P1/P2 hold exactly as in Layer 2 and any over-rejection still degrades to baseline. */
      fluid_perp_extent(horiz, &plo_ext, &phi_ext);
      /* Cap = the outermost obstacle's grid row, plus ONE more grid so the search reaches the first
       * row genuinely OUTSIDE that obstacle's guard tolerance: the along-leg guards match a pin/wire
       * within cadsnap/2 (fluid_pin_on_seg), so an OFF-GRID extent obstacle blocks its own grid row
       * AND the adjacent one -- without the extra grid the loop would stop inside the tolerance band
       * and decline while a provably-clear row sits one grid beyond it (adversarial review wf_afb2b1af,
       * off-grid decline-regression). Still finite + monotonic-safe: a truly boxed device declines. */
      below_stop = fluid_grid_below(plo_ext, grid) - grid;
      above_stop = fluid_grid_above(phi_ext, grid) + grid;
      vb_lo = fluid_grid_below(body_p_lo, grid);       /* nearest below/left detour row (step 1)      */
      vb_hi = fluid_grid_above(body_p_hi, grid);       /* nearest above/right detour row (step 1)     */
      while(!have && !(lo_done && hi_done)) {
        if(++guard_steps > 100000) break;              /* runaway backstop (geometry cap already bounds) */
        for(ci = 0; ci < 2 && !have; ++ci) {
          double vb;
          if(ci == 0) { if(lo_done) continue; vb = vb_lo; }   /* below/left first (Layer-2 order) */
          else        { if(hi_done) continue; vb = vb_hi; }   /* then above/right                 */
          {
          /* leg endpoints in (x,y): along a -> x if horiz else y; perp -> y if horiz else x */
          double l1x1 = horiz ? a_m : perp0, l1y1 = horiz ? perp0 : a_m;
          double l1x2 = horiz ? a_m : vb,    l1y2 = horiz ? vb    : a_m;
          double l2x2 = horiz ? a_C : vb,    l2y2 = horiz ? vb    : a_C;
          double l3x2 = horiz ? a_C : perp0, l3y2 = horiz ? perp0 : a_C;
          double cx = l3x2, cy = l3y2, mx = l1x1, my = l1y1; /* landing C (up-leg top), moving pin M */
          if(fluid_seg_hits_foreign_pin(l1x1, l1y1, l1x2, l1y2, nf)) continue; /* M riser        */
          if(fluid_seg_hits_foreign_pin(l1x2, l1y2, l2x2, l2y2, nf)) continue; /* detour along    */
          if(fluid_seg_hits_foreign_pin(l2x2, l2y2, l3x2, l3y2, nf)) continue; /* up leg to NF row */
          /* also reject a side whose legs would T onto some OTHER wire (foreign-net short) anywhere
           * but the intended NF landing C or the moving pin M -- pick the other side, or decline */
          if(fluid_seg_stray_contact(l1x1, l1y1, l1x2, l1y2, cx, cy, mx, my, w)) continue;
          if(fluid_seg_stray_contact(l1x2, l1y2, l2x2, l2y2, cx, cy, mx, my, w)) continue;
          if(fluid_seg_stray_contact(l2x2, l2y2, l3x2, l3y2, cx, cy, mx, my, w)) continue;
          /* and reject a side whose legs plow through the MOVING device's OTHER (co-dragged) pins,
           * which travel to fixed post-move offsets near M -- soldering one onto NF is a new short */
          if(fluid_seg_hits_moving_pin(l1x1, l1y1, l1x2, l1y2, nf, mx, my)) continue;
          if(fluid_seg_hits_moving_pin(l1x2, l1y2, l2x2, l2y2, nf, mx, my)) continue;
          if(fluid_seg_hits_moving_pin(l2x2, l2y2, l3x2, l3y2, nf, mx, my)) continue;
          Vb = vb; have = 1;
          }
        }
        if(!have) {                                    /* both sides blocked this far out: step further */
          vb_lo -= grid; if(vb_lo < below_stop) lo_done = 1;
          vb_hi += grid; if(vb_hi > above_stop) hi_done = 1;
        }
      }
      if(!have) break;                               /* no clear detour row at any distance: baseline */

      /* --- commit the detour: reuse W as the M riser, store the along + up legs, all on NF's prop.
       *     storeobject() reallocs xctx->wire, so index (never a cached pointer) across it. --- */
      my_strdup(_ALLOC_ID_, &prop, xctx->wire[w].prop_ptr);
      {
        double l1x1 = horiz ? a_m : perp0, l1y1 = horiz ? perp0 : a_m;
        double l1x2 = horiz ? a_m : Vb,    l1y2 = horiz ? Vb    : a_m;
        double l2x2 = horiz ? a_C : Vb,    l2y2 = horiz ? Vb    : a_C;
        double l3x2 = horiz ? a_C : perp0, l3y2 = horiz ? perp0 : a_C;
        xctx->wire[w].x1 = l1x1; xctx->wire[w].y1 = l1y1;
        xctx->wire[w].x2 = l1x2; xctx->wire[w].y2 = l1y2;
        order_wire_coords(w);
        storeobject(-1, l1x2, l1y2, l2x2, l2y2, WIRE, 0, 0, prop);
        order_wire_coords(xctx->wires - 1);
        storeobject(-1, l2x2, l2y2, l3x2, l3y2, WIRE, 0, 0, prop);
        order_wire_coords(xctx->wires - 1);
      }
      my_free(_ALLOC_ID_, &prop);
      xctx->prep_hash_wires = 0;
      xctx->prep_net_structs = 0;
      xctx->prep_hi_structs = 0;
      xctx->need_reb_sel_arr = 1;
      set_modify(1);
      /* rerouted this device; loop to catch any further straddle (a fixed device won't re-match) */
      }
    }
  }
}

/* issue 0083 (far-pin landing): is (x,y) EXACTLY a STATIONARY device pin that was on a net OTHER
 * than nf at START? That is the FAR (distinct-net) pin a long drag lands the riser corner on. A
 * STATIONARY (unselected) wire ending there is pristinely attached to THAT pin -- pristinely on the
 * foreign net, never on nf -- so the V-H-V rebuild, which vacates the corner entirely, restores its
 * pristine contact set exactly (the accidental corner contact was the would-be short). Same
 * instance/pin walk order as fluid_moving_pin_net / fluid_seg_hits_foreign_pin (skip ptr<0, skip
 * labels) so the snapshot index lines up. EXACT coordinate match, NOT point_near_pin: the soundness
 * argument ("a wire ending there is pristinely attached to that pin") is an exact-contact property --
 * xschem connectivity is exact -- while point_near_pin's cadsnap/2 box would also match an OFF-GRID
 * pin the corner did NOT land on and exempt a wire that is NOT the pin's attachment (adversarial
 * review wf_dfd3e463: tolerance-band false match -> P1 disconnect). */
static int fluid_point_on_foreign_fixed_pin(double x, double y, const char *nf)
{
  int i, p, k = 0, npins, base;
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return 0;
  for(i = 0; i < xctx->instances; ++i) {
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_g.snap_npins) break;
    if(xctx->inst[i].sel) continue;                  /* only STATIONARY devices */
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(type && !strcmp(type, "label")) continue;     /* net labels are not device pins */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_g.snap_pinnet[base + p];
      double px, py;
      if(!pn || !pn[0]) continue;
      if(nf && !strcmp(pn, nf)) continue;            /* same net: not foreign */
      get_inst_pin_coord(i, p, &px, &py);
      if(px == x && py == y) return 1;
    }
  }
  return 0;
}

/* issue 0083 far-pin landing, removed-span safety (adversarial review wf_dfd3e463). The V-H-V rebuild
 * leaves row copper [anchor..C'] U [C'..P] -- a strict subset of the naive [anchor..C] U [P..C] -- so
 * the (P..C] span is REMOVED. That removal is exactly the short-repair when only the foreign pin /
 * its attachments sit there, but anything ELSE attached STRICTLY INSIDE (P..C) on the row would be
 * stranded by it: an nf tap-wire endpoint (a pristine in-body arm, reachable with autotrim_wires=0,
 * the stock default) or a pin that was on NF at START (a second device fed mid-span by the bus).
 * Return 1 (unsafe -> decline to baseline) unless every wire endpoint strictly inside coincides
 * EXACTLY with a stationary START-foreign pin (that wire is the pin's own attachment and keeps it
 * when we vacate) and no START-nf pin (stationary or co-moving, non-label) lies strictly inside.
 * START-foreign pins strictly inside are fine: the naive route shorts them, the removal un-shorts. */
static int fluid_removed_span_unsafe(double Px, double Cx, double Py, const char *nf,
                                     int Rw, int wB, int wS)
{
  int rr, i, p, k = 0, npins, base;
  for(rr = 0; rr < xctx->wires; ++rr) {
    double ex[2], ey[2];
    int e;
    if(rr == Rw || rr == wB || rr == wS) continue;   /* the classified riser/bus/overshoot */
    ex[0] = xctx->wire[rr].x1; ey[0] = xctx->wire[rr].y1;
    ex[1] = xctx->wire[rr].x2; ey[1] = xctx->wire[rr].y2;
    for(e = 0; e < 2; ++e) {
      if(ey[e] != Py) continue;
      if((ex[e] - Px) * (Cx - ex[e]) <= 0.0) continue;         /* not strictly inside (P..C) */
      if(!fluid_point_on_foreign_fixed_pin(ex[e], ey[e], nf)) return 1;
    }
  }
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return 1;    /* no snapshot: cannot prove safe */
  for(i = 0; i < xctx->instances; ++i) {
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_g.snap_npins) break;
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(type && !strcmp(type, "label")) continue;
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_g.snap_pinnet[base + p];
      double px, py;
      if(!pn || !pn[0]) continue;
      if(!nf || strcmp(pn, nf) != 0) continue;       /* only START-nf pins block the removal */
      get_inst_pin_coord(i, p, &px, &py);
      if(py != Py) continue;
      if((px - Px) * (Cx - px) > 0.0) return 1;      /* nf pin strictly inside the removed span */
    }
  }
  return 0;
}

/* issue 0083 (incremental_wire_reroute.md §6 stop-short/solder-joint, GENERALIZED off the short
 * trigger): a NO-SHORT foreign-pin LANDING. On a small pure-axis nudge the base stretch-follow
 * (compute_wire_slide) promotes a tool-owned riser to a full selection and TRANSLATES it, so its far
 * corner comes to rest flush on a stationary device pin, and trim_wires merges away the offset
 * solder-joint -- the visible T-junction buries on the pin and the riser runs flush along the device
 * body. Connectivity stays correct (no short, no disconnect, partition unchanged), so NO obstacle layer
 * fires: fluid_reroute_around_obstacles needs a two-distinct-net STRADDLE (both pins on one wire), which
 * does not exist when only one same-net pin is contacted; fluid_seg_crosses_stationary_body is a P6
 * decline-veto, never a driver. This is a pure P5/beautify feel bug (lowest-but-one in the conflict
 * order P1=P2 > P3 > P5 > P4 > P7 > P6), so it must NEVER trade a higher predicate: every guard DECLINES
 * to the naive baseline route (never worse).
 *
 * This sibling pass detects that committed shape and rebuilds the riser into the user's V-H-V: the pin
 * escapes one grid, jogs one grid AWAY from the body, and drops a long clear leg that lands one grid
 * OUTSIDE the body onto the bus at a restored VISIBLE degree-3 solder-dot, with a short stub reaching
 * the pin. The bus is shrunk to the solder-dot and the pin-reaching stub is re-added, so the horizontal
 * copper at the bus row is UNION-IDENTICAL to the baseline bus (only re-segmented) -- copper-neutral,
 * no new crossing -- and only the three new riser legs are genuinely new copper and are guarded. Runs
 * on the SAME shared commit block as a real END and a live fluid RUBBER step (pre-trim seam) so it is a
 * pure function of (pristine snapshot + total delta + geometry): release == stepwise for FREE. Gated
 * fluid_editing && stretch_select && rot==flip==0 (caller) plus a valid START name snapshot => default
 * off byte-identical. TRIGGER (broadened twice): the riser corner landed strictly PAST the pin-side
 * body edge, inward -- unbounded on the far side. Catches the exact-on-pin +1-grid case, a continuous
 * drag deeper into the body (+2/+3 grid, overshoot stub between pin and corner), AND a drag ON or PAST
 * the FAR (distinct-net) pin / past the whole body. That far-pin landing is a GENUINE would-be SHORT
 * (the stretched bus covers both device pins), and fluid_reroute_around_obstacles can NOT see it: its
 * straddle needs a wire with exactly one moving-pin endpoint, but the straddling wire here is the
 * stretched BUS/overshoot whose endpoints are the anchor and the dragged corner (e1mov==e2mov -> its
 * detection breaks out). So for the far-pin landing this pass is the ONLY layer that fires, and firing
 * REPAIRS the short (the rebuild vacates the corner); the classification tolerates STATIONARY wires
 * ending at a corner that sits exactly on a foreign stationary pin (fluid_point_on_foreign_fixed_pin)
 * -- they are pristinely on the foreign net and keep their own pin contact when the corner is vacated.
 * fluid_removed_span_unsafe declines the firing when any OTHER attachment (an nf tap endpoint, a
 * START-nf pin fed mid-span) sits strictly inside the removed (P..C] row span -- adversarial review
 * wf_dfd3e463 (P1 never-worse holes, reachable with autotrim_wires=0, the stock default).
 * All deltas rebuild to the SAME canonical result (offset column one grid outside the body, pin side).
 * SCOPE (first increment): vertical-riser / horizontal-bus only, and pure-axis (the caller gates on
 * nlegs==1 so it never stacks on the issue-0081 diagonal decomposition); a horizontal riser, a rotated
 * bus, or a diagonal drag DECLINE to baseline (documented limitations, all P1/P2-safe). */
static void fluid_offset_foreign_pin_landing(int orthogonal_wiring)
{
  double grid = tclgetdoublevar("cadsnap");
  int D, p, k = 0, npins, base;
  if(!orthogonal_wiring) { fltrace("FLTRACE offset: skip (not orthogonal)\n"); return; }
  if(fluid_failsafe(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0)) { fltrace("FLTRACE offset: skip (no snapshot)\n"); return; }
  if(fluid_failsafe(fluid_count_pins() != fluid_g.snap_npins)) { fltrace("FLTRACE offset: skip (pin count changed)\n"); return; }
  if(grid <= 0.0) grid = 1.0;
  fltrace("FLTRACE offset: ENTER wires=%d grid=%g\n", xctx->wires, grid);

  for(D = 0; D < xctx->instances; ++D) {
    const char *type;
    double bx1, by1, bx2, by2, t, xc;
    if(xctx->inst[D].ptr < 0) continue;
    npins = (xctx->inst[D].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_g.snap_npins) break;
    if(xctx->inst[D].sel) continue;                     /* only STATIONARY devices */
    type = xctx->sym[xctx->inst[D].ptr].type;
    if(type && !strcmp(type, "label")) continue;        /* labels have no body (§2) */
    /* device world bbox (the text/pin-inflated symbol_bbox the P5 body test also uses) */
    bx1 = xctx->inst[D].x1; by1 = xctx->inst[D].y1; bx2 = xctx->inst[D].x2; by2 = xctx->inst[D].y2;
    if(bx1 > bx2) { t = bx1; bx1 = bx2; bx2 = t; }
    if(by1 > by2) { t = by1; by1 = by2; by2 = t; }
    xc = (bx1 + bx2) / 2.0;
    for(p = 0; p < npins; ++p) {
      const char *np = fluid_g.snap_pinnet[base + p];
      const char *nf;
      double Px, Py;                                     /* the stationary device pin (the anchor) */
      double Mx = 0, My = 0, Cx = 0, Cy = 0;             /* riser: M = moving-pin end, C = corner in body */
      int Rw = -1, wB = -1, wS = -1, rr, ambiguous = 0, stranded = 0, c_on_foreign = 0;
      double dir_off, dir_mc, Cpx, JOGY;
      double l1x1, l1y1, l1x2, l1y2, l2x2, l2y2, l3x2, l3y2;
      char *prop = NULL;

      if(!np || !np[0]) continue;
      get_inst_pin_coord(D, p, &Px, &Py);               /* stationary D never moved: post == pre */
      if(Px == xc) continue;                            /* pin on body centre: no offset direction */
      dir_off = (Px > xc) ? 1.0 : -1.0;                 /* away from the body, along the bus (X) axis */
      Cpx = Px + dir_off * grid;                        /* the restored solder-dot column (PIN-relative) */

      /* --- guard 1: EXACTLY ONE tool-owned VERTICAL riser R whose corner (its endpoint on the pin's
       *     row Py) landed strictly PAST this device's pin-side body edge, inward (issue 0083,
       *     broadened from "corner exactly on the pin", then from "inside the body x-span": the far
       *     side is UNBOUNDED so a drag onto / past the FAR distinct-net pin -- a would-be short no
       *     other layer can repair -- is caught too). The OTHER end M is on a MOVING pin (so R is a
       *     riser the drag pulled). The degenerate collapsed stub is skipped. --- */
      for(rr = 0; rr < xctx->wires && !ambiguous; ++rr) {
        double x1 = xctx->wire[rr].x1, y1 = xctx->wire[rr].y1;
        double x2 = xctx->wire[rr].x2, y2 = xctx->wire[rr].y2;
        double cxx, cyy, ox, oy;
        if(!xctx->wire[rr].sel) continue;               /* tool-owned follow wires only */
        if(x1 == x2 && y1 == y2) continue;              /* degenerate (collapsing stub): skip */
        if(x1 != x2) continue;                          /* VERTICAL riser only (first increment) */
        if(y1 == Py)      { cxx = x1; cyy = y1; ox = x2; oy = y2; }   /* corner on the bus row */
        else if(y2 == Py) { cxx = x2; cyy = y2; ox = x1; oy = y1; }
        else continue;
        if(dir_off < 0.0 ? (cxx <= bx1) : (cxx >= bx2)) continue; /* strictly past the pin-side edge, inward */
        if(!point_on_moving_pin(ox, oy)) continue;      /* other end must be a moving pin */
        if(Rw >= 0) { ambiguous = 1; break; }
        Rw = rr; Mx = ox; My = oy; Cx = cxx; Cy = cyy;
      }
      if(ambiguous) { fltrace("FLTRACE offset: D=%d pin=%d ambiguous riser -> decline\n", D, p); continue; }
      if(Rw < 0) continue;                              /* no intruding riser at this pin (silent: common) */
      fltrace("FLTRACE offset: D=%d pin=%d riser Rw=%d M=(%g,%g) C=(%g,%g) P=(%g,%g) body_x=[%g,%g]\n",
                                D, p, Rw, Mx, My, Cx, Cy, Px, Py, bx1, bx2);

      /* --- guard 2: SAME-NET (no short). A distinct net at the pin is a straddle/short that
       *     fluid_reroute_around_obstacles already owns -- decline here. --- */
      nf = fluid_moving_pin_net(Mx, My);
      if(!nf || !nf[0] || strcmp(nf, np) != 0) { fltrace("FLTRACE offset:   decline (net nf=%s np=%s)\n", nf?nf:"(null)", np); continue; }

      /* --- jog row + non-degenerate legs; offset column clear of pins --- */
      dir_mc = (Cy > My) ? 1.0 : -1.0;
      JOGY = My + dir_mc * grid;
      if((JOGY - My) * (Cy - JOGY) <= 0.0) continue;    /* need |Cy-My| > grid (both legs non-degenerate) */
      if(point_on_any_pin(Cpx, Py)) continue;           /* offset column already occupied by a pin */

      /* --- classify the horizontal copper meeting the riser corner C on row Py. wB = the BUS (far end
       *     on the AWAY-from-body side, i.e. the anchor). wS = the OPTIONAL overshoot stub (far end AT
       *     the pin P) that a >1-grid drag leaves between the pin and the corner. Anything else touching
       *     C, or a second bus / second overshoot, is unexpected -> decline (never worse) -- EXCEPT a
       *     STATIONARY (unselected) wire ending at a C that sits exactly ON a foreign stationary pin
       *     (the far-pin landing): that wire is the foreign pin's own attachment, pristinely on the
       *     foreign net, and the rebuild vacates C so its pristine contact set is restored -- ignore it.
       *     A SELECTED wire ending at C still declines (vacating C would tear a moving wire off). --- */
      c_on_foreign = fluid_point_on_foreign_fixed_pin(Cx, Cy, nf);
      for(rr = 0; rr < xctx->wires; ++rr) {
        double x1 = xctx->wire[rr].x1, y1 = xctx->wire[rr].y1;
        double x2 = xctx->wire[rr].x2, y2 = xctx->wire[rr].y2;
        int atC1, atC2;
        double far;
        if(rr == Rw) continue;
        if(x1 == x2 && y1 == y2) continue;              /* degenerate collapsing stub: ignore */
        if(y1 != Cy || y2 != Cy) {                      /* off the bus row: only a problem if it ends at C */
          if((x1 == Cx && y1 == Cy) || (x2 == Cx && y2 == Cy)) {
            if(c_on_foreign && !xctx->wire[rr].sel) continue; /* the foreign pin's own attachment */
            stranded = 1; break;
          }
          continue;
        }
        atC1 = (x1 == Cx); atC2 = (x2 == Cx);
        if(atC1 == atC2) continue;                      /* horizontal on the row but not ending at C: ignore */
        fltrace("FLTRACE offset:   rowwire rr=%d sel=%d [%g %g %g %g]\n", rr, xctx->wire[rr].sel, x1, y1, x2, y2);
        far = atC1 ? x2 : x1;
        /* NOTE sel cannot distinguish the tool's bus/overshoot from user copper here: place_moved_wire
         * RE-LAYS the follow wires (the relaid bus/overshoot carry sel==0 at this seam), so the
         * classification is purely geometric; ambiguity (two bus / two overshoot candidates, e.g. a
         * stationary duplicate of the relaid overshoot) declines, and interior attachments of a
         * candidate are protected by the removed-span scan below (wf_dfd3e463). */
        if((far - Px) * dir_off > 0.0) {                /* far end AWAY from body -> the bus */
          if(wB >= 0) { stranded = 1; break; } wB = rr;
        } else if(far == Px) {                          /* far end AT the pin -> the overshoot stub */
          if(wS >= 0) { stranded = 1; break; } wS = rr;
        } else {                                        /* toward body but not at the pin -> unexpected */
          if(c_on_foreign && !xctx->wire[rr].sel) continue; /* the foreign pin's own attachment */
          stranded = 1; break;
        }
      }
      if(stranded || wB < 0) { fltrace("FLTRACE offset:   decline (wB=%d wS=%d stranded=%d conF=%d)\n", wB, wS, stranded, c_on_foreign); continue; }
      fltrace("FLTRACE offset:   classified wB=%d wS=%d Cpx=%g JOGY=%g conF=%d\n", wB, wS, Cpx, JOGY, c_on_foreign);

      /* --- removed-span safety: the rebuild deletes the naive (P..C] row copper; decline when any
       *     OTHER attachment (an nf tap endpoint, a START-nf pin fed mid-span) sits strictly inside
       *     -- vacating would strand it, a P1 disconnect naive does not have (wf_dfd3e463). --- */
      if(fluid_removed_span_unsafe(Px, Cx, Py, nf, Rw, wB, wS)) {
        fltrace("FLTRACE offset:   decline (removed-span attachment P=%g C=%g)\n", Px, Cx);
        continue;
      }

      /* --- the three new riser legs (candidate coords). Build the near-M column from R's OWN endpoint
       *     Mx (on-grid Mx==the riser column; off-grid this keeps leg1 anchored to the moving pin, no P1
       *     tear). leg1 = M escape; leg2 = jog to the offset column; leg3 = long clear drop to C'. --- */
      l1x1 = Mx;  l1y1 = My;   l1x2 = Mx;  l1y2 = JOGY;
      l2x2 = Cpx; l2y2 = JOGY;
      l3x2 = Cpx; l3y2 = Cy;

      /* --- guards on the NEW legs. The bus+stub horizontal copper after the rebuild (anchor..C' + C'..P)
       *     is a SUBSET of the baseline row copper (only re-segmented and the overshoot removed), so it
       *     adds no crossing and needs no guard. Any leg hit => decline to baseline (never worse). C'
       *     (=Cpx,Cy) and M are the exempt contacts for stray_contact. --- */
      if(fluid_seg_crosses_stationary_body(l1x1, l1y1, l1x2, l1y2)) continue;
      if(fluid_seg_crosses_stationary_body(l1x2, l1y2, l2x2, l2y2)) continue;
      if(fluid_seg_crosses_stationary_body(l2x2, l2y2, l3x2, l3y2)) continue;
      if(fluid_seg_hits_foreign_pin(l1x1, l1y1, l1x2, l1y2, nf)) continue;
      if(fluid_seg_hits_foreign_pin(l1x2, l1y2, l2x2, l2y2, nf)) continue;
      if(fluid_seg_hits_foreign_pin(l2x2, l2y2, l3x2, l3y2, nf)) continue;
      if(fluid_seg_hits_moving_pin(l1x1, l1y1, l1x2, l1y2, nf, Mx, My)) continue;
      if(fluid_seg_hits_moving_pin(l1x2, l1y2, l2x2, l2y2, nf, Mx, My)) continue;
      if(fluid_seg_hits_moving_pin(l2x2, l2y2, l3x2, l3y2, nf, Mx, My)) continue;
      if(fluid_seg_stray_contact(l1x1, l1y1, l1x2, l1y2, l3x2, l3y2, Mx, My, Rw)) continue;
      if(fluid_seg_stray_contact(l1x2, l1y2, l2x2, l2y2, l3x2, l3y2, Mx, My, Rw)) continue;
      if(fluid_seg_stray_contact(l2x2, l2y2, l3x2, l3y2, l3x2, l3y2, Mx, My, Rw)) continue;

      fltrace("FLTRACE offset:   FIRE! rebuild V-H-V: leg col Mx=%g, dot=(%g,%g), stub->pin=%g wS=%d\n",
                                Mx, Cpx, Cy, Px, wS);
      /* --- commit: reshape R into leg1; pull the bus's C-endpoint back to the solder-dot column C';
       *     turn the overshoot stub into the pin-reaching stub C'->P (or store a fresh one if there was
       *     no overshoot, e.g. an exact-on-pin +1-grid landing); storeobject the jog + drop. storeobject
       *     reallocs xctx->wire, so all reshapes (index-only) happen first, appends last. --- */
      my_strdup(_ALLOC_ID_, &prop, xctx->wire[Rw].prop_ptr);       /* carries lab= (net) */
      xctx->wire[Rw].x1 = l1x1; xctx->wire[Rw].y1 = l1y1;
      xctx->wire[Rw].x2 = l1x2; xctx->wire[Rw].y2 = l1y2;
      order_wire_coords(Rw);
      if(xctx->wire[wB].x1 == Cx && xctx->wire[wB].y1 == Cy) xctx->wire[wB].x1 = Cpx;
      else                                                   xctx->wire[wB].x2 = Cpx;
      order_wire_coords(wB);
      if(wS >= 0) {                                                /* reshape overshoot C..P -> C'..P */
        if(xctx->wire[wS].x1 == Cx && xctx->wire[wS].y1 == Cy) xctx->wire[wS].x1 = Cpx;
        else                                                   xctx->wire[wS].x2 = Cpx;
        order_wire_coords(wS);
      }
      storeobject(-1, l1x2, l1y2, l2x2, l2y2, WIRE, 0, 0, prop);    /* leg2 (jog)  */
      order_wire_coords(xctx->wires - 1);
      storeobject(-1, l2x2, l2y2, l3x2, l3y2, WIRE, 0, 0, prop);    /* leg3 (drop) */
      order_wire_coords(xctx->wires - 1);
      if(wS < 0) {                                                 /* exact-on-pin: no overshoot to reuse */
        storeobject(-1, Cpx, Py, Px, Py, WIRE, 0, 0, prop);        /* fresh stub C' -> pin */
        order_wire_coords(xctx->wires - 1);
      }
      my_free(_ALLOC_ID_, &prop);
      xctx->prep_hash_wires = 0;
      xctx->prep_net_structs = 0;
      xctx->prep_hi_structs = 0;
      xctx->need_reb_sel_arr = 1;
      set_modify(1);
      return;                                            /* one landing per pass (rare to have two) */
    }
  }
}

/* incremental_wire_reroute.md / issue 0015 §7 -- CONNECTED-WIRE SHOVE (drag-toward, the occupancy
 * model). A moving instance that drives its pin ALONG its own stub PAST a CONNECTED perpendicular
 * wire V must PUSH V ahead (a solid body cannot occupy the wire's location) instead of letting the
 * naive place_moved_wire relay the stub as a REVERSED leg back through the instance's own body
 * (the P5 own-body intrusion of after_1.sch). Away = pure stretch (untouched). This is the structural
 * inverse of compute_wire_slide (which slides a PERPENDICULAR cornered wire; here the stub is PARALLEL
 * to the move, so compute_wire_slide skips it and never sees V).
 *
 * Post-detection sibling of Layers 2/3: runs at the shared pre-trim commit seam for BOTH a real END
 * and a live fluid RUBBER step => release==stepwise for free; a pure function of (pristine snapshot +
 * total delta). Gated identically to the obstacle layers (caller: fluid_editing && stretch_select &&
 * rot==flip==0) plus a valid START name snapshot => default off byte-identical. Every relocated piece
 * (S, V, arm) stays on the moving pin's net NF (V is electrically one net with the stub at J), so P1
 * is preserved BY CONSTRUCTION for anything attached at J or C; a wire tapping V's INTERIOR, or a
 * COLLINEAR continuation at C (e.g. an autotrim split of V), would be stranded/bent, so those are
 * DECLINED (leave baseline) via the clean-span/clean-corner guards below. P2: the new S, new V and
 * each dragged arm are checked against stationary foreign device pins (fluid_seg_hits_foreign_pin),
 * co-moving distinct-net pins (fluid_seg_hits_moving_pin) and stationary foreign-net wires
 * (fluid_seg_hits_foreign_wire); any hit DECLINES => baseline, never worse. No transitive chain: only
 * V and the one level of arm endpoints coincident with V's far corner follow. NOTE it post-detects the
 * reversed stub place_moved_wire just laid (a parallel single-endpoint stub is always relaid as one
 * straight degenerate wire), so it is coupled to that relay shape.
 * See doc/claude/issues/0015-component-shove-push-connected-wire-when-moving-into-it.md §7. */
static int fluid_seg_hits_foreign_wire(double x1, double y1, double x2, double y2,
                                       const char *nf, int selfa, int selfb, int selfc)
{
  /* Does axis-aligned seg (x1,y1)-(x2,y2) touch a STATIONARY (unselected) wire that is NOT part of the
   * shove's own group {selfa=S, selfb=V, selfc=arm} and resolves to a net OTHER than nf? Uses the
   * pre-move net cache in xctx->wire[].node (prepare_netlist_structs(0) ran at the commit seam before
   * the shove); a NULL/empty node or an == nf node is same-net and fine to touch. Manhattan-only, so a
   * closed-bbox overlap is the exact seg-seg touch test. Conservative: an unresolved (NULL) node is
   * treated as same-net (skip) so we never DECLINE on a legitimate same-net landing (arm on its rail). */
  int m;
  double alo = x1 < x2 ? x1 : x2, ahi = x1 < x2 ? x2 : x1;
  double blo = y1 < y2 ? y1 : y2, bhi = y1 < y2 ? y2 : y1;
  for(m = 0; m < xctx->wires; ++m) {
    double wx1, wy1, wx2, wy2, clo, chi, dlo, dhi;
    const char *wn;
    if(m == selfa || m == selfb || m == selfc) continue;
    if(xctx->wire[m].sel) continue;                       /* moving wires ride rigidly, not obstacles */
    wn = xctx->wire[m].node;
    if(!wn || !wn[0]) continue;                           /* unresolved -> treat as same-net (skip) */
    if(nf && nf[0] && !strcmp(wn, nf)) continue;          /* same net -> a legitimate touch */
    wx1 = xctx->wire[m].x1; wy1 = xctx->wire[m].y1; wx2 = xctx->wire[m].x2; wy2 = xctx->wire[m].y2;
    clo = wx1 < wx2 ? wx1 : wx2; chi = wx1 < wx2 ? wx2 : wx1;
    dlo = wy1 < wy2 ? wy1 : wy2; dhi = wy1 < wy2 ? wy2 : wy1;
    if(alo <= chi && clo <= ahi && blo <= dhi && dlo <= bhi) return 1;   /* closed-bbox overlap = touch */
  }
  return 0;
}

/* ==== issue 0132 §11.9c (after_35): BODY-driven backbone shove ===================================
 * A pure-ortho connected drag can advance a moved instance's PIN-INCLUSIVE body over the pin's own
 * stationary PERPENDICULAR backbone: the moved pin lands mid-run on same-net copper that is left
 * threading the body (before_10.sch, x1 +20x -> after_35.sch: CTRL1 `N 140 -20 140 100` inside body
 * x[97.5,150], pin (140,80) mid-span). No existing layer reaches it: the PIN-driven shove
 * (fluid_shove_connected_wire) needs a PARALLEL stub driven past its junction (CTRL1 exits +y then
 * jogs -> never matches); the 0132 diag-relay reroute is gated diag_relay (this path accepts at
 * attempt 0); the named-rail orphan prune declines explicit labs (WIRING §11.1). This is the
 * BODY-driven counterpart: push the overrun backbone one grid PAST the body edge in the direction
 * of motion, reconnecting the pin with a short jog (the user's expected result).
 *
 * TIMING (the hard-won part -- see doc/claude/issues/0132-*.md §11.9c/§11.9d): runs LIVE on every
 * RUBBER live-commit step AND at the real END (issue 0132 §11.9d / after_36: the body shoves its own
 * copper on the slightest drag, like the pin-driven fluid_shove_connected_wire, instead of only at
 * release). Called from the ONE clean site AFTER the attempt ladder accepted (partition clean vs
 * START) and AFTER trim/cleanup/ownership-normalize -- i.e. on CLEAN, committed geometry (all wire
 * sel==0, instances at moved coords, no degenerates, no mixed-selection split runs). An earlier
 * attempt at this shove inside the mid-gesture SHARED COMMIT BLOCK (step 4/5) fought the dirty
 * transient state (phantom cross-net merges that survived its internal verify) and was reverted; do
 * NOT move this call back there. Live firing is release==stepwise-safe: each RUBBER step and the real
 * END both fluid_reroute_restore() to pristine and re-derive from the TOTAL delta, so the shove is
 * re-applied fresh each step, never accumulated, and the saved END result is step-count-independent.
 *
 * Per moved pin (px,py), ALL gates must hold (each negation declines to baseline -- never worse):
 *   - the owning instance has >=2 pins (a 1-pin label/power/sheet-pin symbol STRADDLES its pin --
 *     strictly interior to the no-text bbox on both axes -- so the engulf gate is meaningless for
 *     it, and its pin-less backbone would be deleted verify-blind; review wf_cff67bed CRITICAL);
 *   - pure-axis gesture delta; the pin's cross-axis column pc lies STRICTLY inside the moved
 *     instance's own pin-inclusive body cross-range (the body actually engulfed the column);
 *   - THROUGH-RUN: the contiguous same-net perpendicular run at pc through the pin has copper
 *     strictly BOTH sides of the pin (excludes a one-sided escape feed like TRIANG's +y exit --
 *     the key over-fire guard for ordinary 2-pin device moves) and overlaps the body span;
 *   - no OTHER instance pin (device, label or co-moved sibling) sits on the run -- an attachment
 *     the rebuild cannot re-solder; EVERY wire endpoint on the run is either a plain same-net
 *     axis-aligned attachment (collected as a translated corner) or a HARD DECLINE (bus-flagged,
 *     diagonal, foreign node -- severing any of them is invisible to the pin-indexed verifies);
 *     a same-net T-tap with no endpoint on the column is NOT collected -- if load-bearing the
 *     partition verify below reverts the shove;
 *   - none of the rebuilt segments welds pin-less foreign copper (fluid_seg_welds_foreign;
 *     pin-indexed partitions are blind to it, WIRING §5); the new backbone crosses no OTHER moved
 *     body and no stationary body.
 * REBUILD (not translate): collapse the run wires to the pin point (check_collapsing_objects reaps
 * them), lay ONE new backbone at ct = one grid outside the OWNING instance's body edge (NOT the
 * union of all selected bodies -- an unrelated co-selected instance ahead of the motion must not
 * fling the copper past itself), spanning ONLY [pin..attachment corners] -- the dead overhang past
 * the last attachment (after_35: the named CTRL1 stub (140,80)-(140,100)) is deliberately DROPPED,
 * not shoved: it feeds nothing (partition-verified) and shoving it up would cross the foreign
 * TRIANG rail at y=90. Attachment endpoints on the column translate to ct; the pin re-feeds via
 * the jog (px,py)-(ct,py), skipped when a translated pin-row attachment already covers that span
 * (no duplicate overlapping copper).
 * Every firing is mem-snapshotted and DOUBLE partition-verified -- restore-START name partition
 * (entry is accepted-clean, so this equals preserve-entry) AND preserve-pass-entry GEOMETRIC
 * partition (same-name-island + rename blindness cover) -- with EXACT revert on any mismatch.
 * Prop for every new wire is copied from a RUN wire, so a named rail keeps its name: this pass may
 * reshape NAMED copper (a verified §11.1 crack, like fluid_delete_body_crossing_copper) but can
 * never rename it. Returns 1 if a shove committed. */
static int fluid_shove_body_crossing_backbone(void)
{
  double grid = tclgetdoublevar("cadsnap");
  int xmove, dirpos, i, changed = 0;
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return 0;
  if(fluid_count_pins() != fluid_g.snap_npins) return 0;  /* instance set changed: not comparable */
  if(grid <= 0.0) grid = 10.0;
  xmove = (xctx->deltay == 0.0 && xctx->deltax != 0.0);
  if(!xmove && !(xctx->deltax == 0.0 && xctx->deltay != 0.0)) return 0;   /* pure-axis only */
  dirpos = xmove ? (xctx->deltax > 0.0) : (xctx->deltay > 0.0);
  xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
  prepare_netlist_structs(0);
  if(fluid_partition_changed() != 0) return 0;            /* entry not accepted-clean: stand down */
  for(i = 0; i < xctx->instances; ++i) {
    int npins, p;
    if(xctx->inst[i].sel != SELECTED || xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    /* 1-pin instances (net labels, power symbols, ipin/opin sheets) NEVER shove (adversarial
     * review wf_cff67bed, CRITICAL): their graphic STRADDLES the pin, so the pin sits strictly
     * interior to the no-text bbox on BOTH axes and the engulf gate's device assumption (pins on
     * the box edge, column engulfed only when the body really overran it) breaks -- an ordinary
     * "drop the label onto its own wire" drag then fired the shove and the pin-less backbone
     * deletion was invisible to BOTH pin-indexed verifies. The 1-pin family is the §11.5
     * ownerless class; the body-shove is a multi-pin DEVICE-body concept. */
    if(npins < 2) continue;
    for(p = 0; p < npins; ++p) {
      enum { BSHOVE_MAXCORN = 64 };
      double px, py, pc, palong, bx1, by1, bx2, by2, ct;
      double run_lo, run_hi, span_lo, span_hi;
      char *node = NULL, *prp = NULL;
      unsigned short *run = NULL;
      int w, m, e, j, grew, nrun = 0, ncorn = 0, bad = 0, nw0 = xctx->wires;
      int cw[BSHOVE_MAXCORN], ce[BSHOVE_MAXCORN];
      double ca[BSHOVE_MAXCORN];
      get_inst_pin_coord(i, p, &px, &py);
      if(!fluid_moving_pin_net(px, py)) continue;         /* not a snapshot-aligned moving pin */
      pc     = xmove ? px : py;                           /* run column = pin's cross-axis coord */
      palong = xmove ? py : px;                           /* pin position along the run */
      if(!fluid_inst_body_box(i, &bx1, &by1, &bx2, &by2)) continue;
      if(xmove ? (pc <= bx1 || pc >= bx2)                 /* column not strictly engulfed: no shove */
               : (pc <= by1 || pc >= by2)) continue;
      if(!xctx->inst[i].node || !xctx->inst[i].node[p] || !xctx->inst[i].node[p][0]) continue;
      my_strdup(_ALLOC_ID_, &node, xctx->inst[i].node[p]);  /* live net (renumber-safe vs snapshot) */
      /* --- the contiguous same-net perpendicular run at column pc through the pin (the saved
       * backbone is typically SPLIT at the pin by trim, so chain touching intervals to fixpoint) */
      run = my_malloc(_ALLOC_ID_, (size_t)(nw0 > 0 ? nw0 : 1) * sizeof(unsigned short));
      memset(run, 0, (size_t)(nw0 > 0 ? nw0 : 1) * sizeof(unsigned short));
      run_lo = run_hi = palong;
      do {
        grew = 0;
        for(w = 0; w < nw0; ++w) {
          double a, b, lo, hi;
          const char *wn = xctx->wire[w].node;
          if(run[w]) continue;
          if(xctx->wire[w].bus != 0.0) continue;
          if(!wn || strcmp(wn, node)) continue;
          if(xmove) {
            if(xctx->wire[w].x1 != pc || xctx->wire[w].x2 != pc) continue;
            a = xctx->wire[w].y1; b = xctx->wire[w].y2;
          } else {
            if(xctx->wire[w].y1 != pc || xctx->wire[w].y2 != pc) continue;
            a = xctx->wire[w].x1; b = xctx->wire[w].x2;
          }
          if(a == b) continue;                            /* degenerate carries no connectivity */
          lo = a < b ? a : b; hi = a < b ? b : a;
          if(lo > run_hi || hi < run_lo) continue;        /* not touching the run interval */
          run[w] = 1; ++nrun; grew = 1;
          if(lo < run_lo) run_lo = lo;
          if(hi > run_hi) run_hi = hi;
        }
      } while(grew);
      /* THROUGH-RUN / one-sided body-threading gate (issue 0132 §11.9d, after_36): the run must
       * carry same-net copper strictly INSIDE the body along-span by MORE than one grid. A pin
       * mid-run (copper both sides -- the after_35 case) OR a ONE-SIDED feed diving deep into the
       * body both qualify; what is excluded is a CLEAN escape feed that leaves the body within a
       * grid of the pin (TRIANG's +y exit: pin 2.5 below the top edge, wire immediately out).
       * The old strictly-both-sides test over-declined the one-sided INWARD feed that a SECOND
       * incremental drag creates: the advancing body re-engulfs the previously-shoved backbone and
       * the moved pin lands on the run's END (copper only on the body-interior side), so the wire
       * threads the whole body to reach its rail yet reads as a "one-sided escape" and was kept.
       * "> one grid inside" is exactly the user's spec: own copper stays >=1 grid outside the body. */
      if(nrun == 0) bad = 1;
      else {
        int both_sided = (run_lo < palong && run_hi > palong);
        double alo = xmove ? by1 : bx1, ahi = xmove ? by2 : bx2;
        double ilo = run_lo > alo ? run_lo : alo;    /* run interval clipped to the body along-span */
        double ihi = run_hi < ahi ? run_hi : ahi;
        if(both_sided) {
          /* pin MID-run (the after_35 case): preserved BYTE-IDENTICAL -- shove whenever the run
           * reaches the body at all (open-interval overlap == ilo < ihi), regardless of depth. */
          if(ihi <= ilo) bad = 1;
        } else {
          /* pin at a run END (the after_36 one-sided feed): require the copper to dive strictly
           * INSIDE the body by MORE than one grid, so a clean escape feed leaving within a grid
           * (TRIANG's +y exit) still declines and ordinary 2-pin device feeds are untouched. */
          if(ihi - ilo <= grid) bad = 1;
        }
      }
      /* issue 0135 (after_39, defect D1): the per-axis spoof at the call site (move.c ~8779, 0134
       * hunk-2) feeds this shove a SINGLE-axis delta so it can run on a DIAGONAL drag; `dirpos`
       * (motion "ahead") then decides which body edge to shove PAST. On a diagonal SW drag of
       * solar_ctl that mis-models REF: the y-run (deltay spoofed +y/south) read REF's HORIZONTAL
       * escape feed as a shoveable backbone and set ct one grid past the SOUTH edge, dragging the feed
       * from REF's north pin straight DOWN through the whole body (a through-body U). REF's real lead
       * escape normal points NORTH. GUARD: if the pin's outward escape normal has a component ALONG the
       * shove axis that OPPOSES the relocation direction (dirpos), the rebuilt backbone would land on
       * the FAR side of the body -- across it from where the feed should escape. DECLINE (keep the
       * accepted route; never worse). The legitimate perpendicular-backbone shoves (after_35/36 CTRL1,
       * the 0134 x=140 column) have their escape normal PERPENDICULAR to the shove axis (component 0),
       * so this never declines them. Gated fluid_editing via get_pin_escape_normal (the shove call site
       * is fluid-only); the normal is the lead-geometry one (issue 0134), so it is exact on this pin. */
      if(!bad) {
        double enx, eny, en, rel;
        get_pin_escape_normal(i, p, &enx, &eny);
        en  = xmove ? enx : eny;                          /* escape component on the shove axis */
        rel = dirpos ? 1.0 : -1.0;                        /* backbone relocation direction (toward ct) */
        if(en != 0.0 && en * rel < 0.0) {
          fltrace("FLTRACE bodyshove: pin=(%g,%g) escape=(%g,%g) rel=%g -- shove OPPOSES escape, DECLINE\n",
                  px, py, enx, eny, rel);
          bad = 1;
        }
      }
      /* any OTHER pin on the run (tolerant test; includes labels + co-moved siblings): decline */
      for(m = 0; m < xctx->instances && !bad; ++m) {
        int rq, nr2;
        if(xctx->inst[m].ptr < 0) continue;
        nr2 = (xctx->inst[m].ptr + xctx->sym)->rects[PINLAYER];
        for(rq = 0; rq < nr2 && !bad; ++rq) {
          double qx, qy;
          get_inst_pin_coord(m, rq, &qx, &qy);
          if(qx == px && qy == py) continue;              /* the moved pin itself */
          if(xmove ? fluid_pin_on_seg(qx, qy, pc, run_lo, pc, run_hi)
                   : fluid_pin_on_seg(qx, qy, run_lo, pc, run_hi, pc)) bad = 1;
        }
      }
      /* attachment corners: EVERY non-run wire endpoint exactly on the column inside the run
       * interval is an attachment the collapse would sever. A plain same-net axis-aligned thin
       * wire becomes a translated corner; ANYTHING else -- a bus-flagged wire (review
       * wf_cff67bed MAJOR: silently skipping it stranded the pin-less spur as a floating island,
       * invisible to both pin-indexed verifies), a diagonal, or a foreign/unresolved node --
       * DECLINES the whole shove (cannot be re-soldered safely). */
      for(w = 0; w < nw0 && !bad; ++w) {
        const char *wn = xctx->wire[w].node;
        if(run[w]) continue;
        if(xctx->wire[w].x1 == xctx->wire[w].x2 && xctx->wire[w].y1 == xctx->wire[w].y2) continue;
        for(e = 0; e < 2 && !bad; ++e) {
          double ex = e ? xctx->wire[w].x2 : xctx->wire[w].x1;
          double ey = e ? xctx->wire[w].y2 : xctx->wire[w].y1;
          double cross = xmove ? ex : ey, along = xmove ? ey : ex;
          if(cross != pc) continue;
          if(along < run_lo || along > run_hi) continue;
          if(xctx->wire[w].bus != 0.0 ||                  /* bus attachment: decline, not skip */
             !wn || strcmp(wn, node) ||                   /* foreign/unresolved node on the run */
             (xctx->wire[w].x1 != xctx->wire[w].x2 &&
              xctx->wire[w].y1 != xctx->wire[w].y2)) { bad = 1; break; }  /* diagonal */
          if(ncorn >= BSHOVE_MAXCORN) { bad = 1; break; } /* cap: decline, never truncate silently */
          cw[ncorn] = w; ce[ncorn] = e; ca[ncorn] = along; ++ncorn;
        }
      }
      if(!bad && ncorn == 0) bad = 1;                     /* nothing load-bearing: not our shape */
      ct = 0.0;
      if(!bad) {
        /* shove target: one grid outside the OWNING instance's body edge, ahead of the motion.
         * NOT the union of all selected bodies (review wf_cff67bed MAJOR: an unrelated co-selected
         * instance far ahead dragged ct arbitrarily far, flinging the rebuilt copper past it).
         * A backbone landing inside ANOTHER moved body is declined below instead. */
        ct = xmove ? (dirpos ? fluid_grid_above(bx2, grid) : fluid_grid_below(bx1, grid))
                   : (dirpos ? fluid_grid_above(by2, grid) : fluid_grid_below(by1, grid));
        span_lo = span_hi = palong;
        for(j = 0; j < ncorn; ++j) {
          if(ca[j] < span_lo) span_lo = ca[j];
          if(ca[j] > span_hi) span_hi = ca[j];
        }
        /* the NEW backbone must not thread a body itself: own body impossible by construction
         * (ct strictly outside the own cross-range), so the sel-body test catches a co-moved
         * sibling's body, the stationary test any bystander device (review findings: minor
         * body-threading class; text-inflated stationary box over-declines only -- never worse).
         * The JOG is exempt (it is the pin's bridge and legitimately clips the own body corner);
         * the attachment EXTENSIONS are exempt (they extend a row/column that already existed
         * there -- pre-existing crossings are grandfathered, the extension adds none). */
        if(span_lo != span_hi) {
          double nbx1 = xmove ? ct : span_lo, nby1 = xmove ? span_lo : ct;
          double nbx2 = xmove ? ct : span_hi, nby2 = xmove ? span_hi : ct;
          if(fluid_seg_crosses_sel_body(nbx1, nby1, nbx2, nby2) ||
             fluid_seg_crosses_stationary_body(nbx1, nby1, nbx2, nby2)) bad = 1;
        }
        /* foreign-copper early decline on every rebuilt segment (partition verify is blind to a
         * pin-less labeled net): the jog, the new backbone, each attachment's pc->ct extension */
        if(xmove) {
          if(fluid_seg_welds_foreign(px, py, ct, py, node, -1)) bad = 1;
          if(!bad && span_lo != span_hi &&
             fluid_seg_welds_foreign(ct, span_lo, ct, span_hi, node, -1)) bad = 1;
          for(j = 0; j < ncorn && !bad; ++j)
            if(fluid_seg_welds_foreign(pc, ca[j], ct, ca[j], node, cw[j])) bad = 1;
        } else {
          if(fluid_seg_welds_foreign(px, py, px, ct, node, -1)) bad = 1;
          if(!bad && span_lo != span_hi &&
             fluid_seg_welds_foreign(span_lo, ct, span_hi, ct, node, -1)) bad = 1;
          for(j = 0; j < ncorn && !bad; ++j)
            if(fluid_seg_welds_foreign(ca[j], pc, ca[j], ct, node, cw[j])) bad = 1;
        }
      }
      if(bad) {
        fltrace("FLTRACE bodyshove: pin=(%g,%g) pc=%g run=[%g %g]x%d corners=%d DECLINE\n",
                px, py, pc, run_lo, run_hi, nrun, ncorn);
        my_free(_ALLOC_ID_, &run);
        my_free(_ALLOC_ID_, &node);
        continue;
      }
      /* prop template from a RUN wire: the rebuilt rail keeps its own lab, never a foreign one */
      for(w = 0; w < nw0; ++w) if(run[w]) { my_strdup(_ALLOC_ID_, &prp, xctx->wire[w].prop_ptr); break; }
      {
        Undo_slot snap;
        unsigned int s_wid = xctx->wire_id_counter, s_iid = xctx->inst_id_counter;
        unsigned int s_gid = xctx->gfx_id_counter,  s_tid = xctx->text_id_counter;
        int npA, npB, ok, *repA, *repB;
        memset(&snap, 0, sizeof(snap));
        mem_snapshot_alloc(&snap); mem_serialize_slot(&snap);
        npA = fluid_count_pins();
        repA = my_malloc(_ALLOC_ID_, (size_t)(npA > 0 ? npA : 1) * sizeof(int));
        repB = my_malloc(_ALLOC_ID_, (size_t)(npA > 0 ? npA : 1) * sizeof(int));
        fluid_loop_partition(NULL, repA);                 /* pass-entry geometric partition */
        /* 1. jog + new backbone (appends: run/corner indices stay valid). SKIP the jog when a
         * pin-row attachment corner arriving from BEHIND the pin will, once translated, already
         * span [pin..ct] on the pin row -- also storing the jog would leave fully-overlapping
         * duplicate copper that nothing after this site coalesces until the next save/trim
         * (review wf_cff67bed duplicate-overlap findings). The partition verify below still
         * guards the skip: if coverage reasoning ever fails, the shove reverts. */
        {
          int jog_covered = 0;
          for(j = 0; j < ncorn && !jog_covered; ++j) {
            double fo;
            if(ca[j] != palong) continue;
            fo = ce[j] ? (xmove ? xctx->wire[cw[j]].x1 : xctx->wire[cw[j]].y1)
                       : (xmove ? xctx->wire[cw[j]].x2 : xctx->wire[cw[j]].y2);
            if(dirpos ? (fo <= pc) : (fo >= pc)) jog_covered = 1;
          }
          if(!jog_covered) {
            if(xmove) storeobject(-1, px, py, ct, py, WIRE, 0, 0, prp);
            else      storeobject(-1, px, py, px, ct, WIRE, 0, 0, prp);
            order_wire_coords(xctx->wires - 1);
          }
        }
        if(span_lo != span_hi) {
          if(xmove) storeobject(-1, ct, span_lo, ct, span_hi, WIRE, 0, 0, prp);
          else      storeobject(-1, span_lo, ct, span_hi, ct, WIRE, 0, 0, prp);
          order_wire_coords(xctx->wires - 1);
        }
        /* 2. translate the attachment endpoints on the column to ct. EXCEPTION: a pin-row
         * attachment pointing INTO the shove and ending short of ct would, once translated, lie
         * fully inside the jog's pin-row span -- collapse it to the pin instead (reaped below)
         * so no duplicate overlapped copper survives; anything tapping its old far end lands on
         * the covering jog span, and the partition verify guards that reasoning. */
        for(j = 0; j < ncorn; ++j) {
          double fo = ce[j] ? (xmove ? xctx->wire[cw[j]].x1 : xctx->wire[cw[j]].y1)
                            : (xmove ? xctx->wire[cw[j]].x2 : xctx->wire[cw[j]].y2);
          if(ca[j] == palong && (dirpos ? (fo > pc && fo < ct) : (fo < pc && fo > ct))) {
            xctx->wire[cw[j]].x1 = xctx->wire[cw[j]].x2 = px;
            xctx->wire[cw[j]].y1 = xctx->wire[cw[j]].y2 = py;
            continue;
          }
          if(ce[j]) { if(xmove) xctx->wire[cw[j]].x2 = ct; else xctx->wire[cw[j]].y2 = ct; }
          else      { if(xmove) xctx->wire[cw[j]].x1 = ct; else xctx->wire[cw[j]].y1 = ct; }
          order_wire_coords(cw[j]);
        }
        /* 3. collapse the run wires to the pin point; reap the degenerates BEFORE any partition
         * math (a zero-length wire poisons touch(), WIRING §1.2) */
        for(w = 0; w < nw0; ++w) if(run[w]) {
          xctx->wire[w].x1 = xctx->wire[w].x2 = px;
          xctx->wire[w].y1 = xctx->wire[w].y2 = py;
        }
        check_collapsing_objects();
        xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
        prepare_netlist_structs(0);
        npB = fluid_count_pins();
        fluid_loop_partition(NULL, repB);
        ok = (fluid_partition_changed() == 0) && npB == npA && fluid_part_equal(repA, repB, npA);
        if(!ok) {                                         /* EXACT revert (house restore ritual) */
          unsigned int saved_ui = xctx->ui_state;
          mem_restore_slot(&snap, 0);
          xctx->ui_state = saved_ui;
          xctx->wire_id_counter = s_wid; xctx->inst_id_counter = s_iid;
          xctx->gfx_id_counter  = s_gid; xctx->text_id_counter = s_tid;
          xctx->need_reb_sel_arr = 1; rebuild_selected_array();
          xctx->movelastsel = xctx->lastsel;
          xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
          prepare_netlist_structs(0);
          fltrace("FLTRACE bodyshove: pin=(%g,%g) pc=%g -> ct=%g REVERTED (verify failed)\n",
                  px, py, pc, ct);
        } else {
          changed = 1;
          fltrace("FLTRACE bodyshove: pin=(%g,%g) pc=%g run=[%g %g] -> ct=%g span=[%g %g] "
                  "corners=%d SHOVED\n", px, py, pc, run_lo, run_hi, ct, span_lo, span_hi, ncorn);
        }
        mem_snapshot_free(&snap);
        my_free(_ALLOC_ID_, &repA);
        my_free(_ALLOC_ID_, &repB);
      }
      my_free(_ALLOC_ID_, &prp);
      my_free(_ALLOC_ID_, &run);
      my_free(_ALLOC_ID_, &node);
    }
  }
  return changed;
}

/* issue 0136 (before_39 -> after_40, delta +60,+30): a moved DEVICE body advances over a stationary
 * same-net backbone that is NOT incident to any moved pin -- the moved pin reaches it through a JOG
 * (an elbow one grid off the pin's column). fluid_shove_body_crossing_backbone is PIN-INCIDENT: it
 * seeds the perpendicular run at the moved pin's OWN column (move.c:7056/7067/7077), so a trunk one
 * grid off-column is invisible to it (every moved pin declines with corners=0), and the diag_relay
 * reroute/delete family cannot pull it (fluid_nearest_outside_body_anchor returns the pin's own riser
 * END (this fixture: (150,130)) so the feed never leaves the body, and the through-body trunk stays
 * LOAD-BEARING to the naming label). Shove such a jog-separated trunk sideways one grid past the
 * crossed body edge and TRANSLATE its perpendicular attachments' near ends (translate, not
 * collapse -- the pin is elsewhere and stays fed through the jog). Try both sides, prefer the side the
 * attachments lean toward; commit only a body-free, DOUBLE partition-verified route with exact revert.
 * Per-axis (xmove => the trunk is VERTICAL at column tc, shoved in x), fed one axis at a time by the
 * same per-axis spoof as the shove. Scoped to a FOLLOW net (a moved pin carries the trunk's node) so
 * only the gesture's OWN copper is reshaped, never a foreign rail (WIRING §11.1). No new wires are
 * created (each translated wire keeps its own lab), so a named rail is reshaped but never renamed.
 * Never worse: a decline / failed verify keeps the accepted route byte-identical. Returns 1 if a trunk
 * was shoved. */
static int fluid_shove_jog_separated_trunk(void)
{
  enum { TRUNK_MAXCORN = 64 };
  double grid = tclgetdoublevar("cadsnap");
  int xmove, changed = 0, restart = 1, guard = 0;
  if(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0) return 0;
  if(fluid_count_pins() != fluid_g.snap_npins) return 0;   /* instance set changed: not comparable */
  if(grid <= 0.0) grid = 10.0;
  xmove = (xctx->deltay == 0.0 && xctx->deltax != 0.0);
  if(!xmove && !(xctx->deltax == 0.0 && xctx->deltay != 0.0)) return 0;   /* pure-axis only */
  xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
  prepare_netlist_structs(0);
  if(fluid_partition_changed() != 0) return 0;             /* entry not accepted-clean: stand down */

  while(restart && ++guard < 64) {
    int t;
    restart = 0;
    for(t = 0; t < xctx->wires && !restart; ++t) {
      double tc, run_lo, run_hi, bx1 = 0, by1 = 0, bx2 = 0, by2 = 0;
      char *node = NULL;
      unsigned short *run = NULL;
      int w, m, e, j, side, grew, nrun, ncorn = 0, bad = 0, bi = -1, nw0 = xctx->wires;
      int has_moved_pin = 0, pin_on_run = 0, lean = 0;
      int cw[TRUNK_MAXCORN], ce[TRUNK_MAXCORN];
      double ca[TRUNK_MAXCORN], fa[TRUNK_MAXCORN];
      const char *wn = xctx->wire[t].node;
      /* candidate trunk = a same-net thin PERPENDICULAR-orientation wire strictly threading a moved
       * body (fluid_seg_crosses_sel_body already exempts a pin's own OUTWARD feed leg -- so a bare
       * escape stub is never a candidate; only a backbone threading under/through the pins is). */
      if(!wn || !wn[0]) continue;
      if(xctx->wire[t].bus != 0.0) continue;
      if(xctx->wire[t].x1 == xctx->wire[t].x2 && xctx->wire[t].y1 == xctx->wire[t].y2) continue;
      if(xmove) { if(xctx->wire[t].x1 != xctx->wire[t].x2) continue; tc = xctx->wire[t].x1; }
      else      { if(xctx->wire[t].y1 != xctx->wire[t].y2) continue; tc = xctx->wire[t].y1; }
      if(!fluid_seg_crosses_sel_body(xctx->wire[t].x1, xctx->wire[t].y1,
                                     xctx->wire[t].x2, xctx->wire[t].y2)) continue;
      /* only a PRE-EXISTING backbone the moved body advanced OVER -- never a detour leg THIS gesture's
       * reroute just laid (test_wireedit_36 case j: a fresh Layer-3 step-out leg through the moving
       * device's own pin-inclusive body must be left exactly where the router placed it, P7). A
       * pre-existing trunk's span is byte-identical at START (the CTRL1 x=140 column); a this-drag leg
       * is novel. Span-scoped (lab-independent) so a #net renumber across the move does not read novel.
       * issue 0139 (after_42): a SECOND gesture can shrink a pre-existing trunk's span (the LED #net1
       * trunk's right end tracked the LED column inward, x2 90->80) so it reads novel though it is the
       * same user backbone. fluid_wire_pretracked_shrink re-admits exactly that case (collinear inside a
       * START footprint AND an endpoint on a moved pin's column); a genuine detour leg is neither. */
      if(fluid_wire_is_novel_span(t) && !fluid_wire_pretracked_shrink(t, xmove)) continue;
      my_strdup(_ALLOC_ID_, &node, wn);

      /* the contiguous same-net run at column tc (a saved backbone is typically trim-SPLIT, so chain
       * touching intervals to fixpoint) */
      run = my_malloc(_ALLOC_ID_, (size_t)(nw0 > 0 ? nw0 : 1) * sizeof(unsigned short));
      memset(run, 0, (size_t)(nw0 > 0 ? nw0 : 1) * sizeof(unsigned short));
      run_lo = xmove ? (xctx->wire[t].y1 < xctx->wire[t].y2 ? xctx->wire[t].y1 : xctx->wire[t].y2)
                     : (xctx->wire[t].x1 < xctx->wire[t].x2 ? xctx->wire[t].x1 : xctx->wire[t].x2);
      run_hi = xmove ? (xctx->wire[t].y1 < xctx->wire[t].y2 ? xctx->wire[t].y2 : xctx->wire[t].y1)
                     : (xctx->wire[t].x1 < xctx->wire[t].x2 ? xctx->wire[t].x2 : xctx->wire[t].x1);
      run[t] = 1; nrun = 1;
      do {
        grew = 0;
        for(w = 0; w < nw0; ++w) {
          double a, b, lo, hi; const char *wn2 = xctx->wire[w].node;
          if(run[w]) continue;
          if(xctx->wire[w].bus != 0.0) continue;
          if(!wn2 || strcmp(wn2, node)) continue;
          if(xmove) { if(xctx->wire[w].x1 != tc || xctx->wire[w].x2 != tc) continue;
                      a = xctx->wire[w].y1; b = xctx->wire[w].y2; }
          else      { if(xctx->wire[w].y1 != tc || xctx->wire[w].y2 != tc) continue;
                      a = xctx->wire[w].x1; b = xctx->wire[w].x2; }
          if(a == b) continue;
          lo = a < b ? a : b; hi = a < b ? b : a;
          if(lo > run_hi || hi < run_lo) continue;
          run[w] = 1; ++nrun; grew = 1;
          if(lo < run_lo) run_lo = lo;
          if(hi > run_hi) run_hi = hi;
        }
      } while(grew);

      /* the crossed moved body (its edges set the shove target): column strictly interior, run overlaps
       * the body along-span. NOT the union of all selected bodies -- a co-selected instance elsewhere
       * must not fling the copper past itself (the shove's wf_cff67bed fling guard, verbatim). */
      for(m = 0; m < xctx->instances; ++m) {
        double lx1, ly1, lx2, ly2, blo, bhi;
        if(xctx->inst[m].sel != SELECTED) continue;
        if(!fluid_inst_body_box(m, &lx1, &ly1, &lx2, &ly2)) continue;
        if(xmove) { if(tc <= lx1 || tc >= lx2) continue; blo = ly1; bhi = ly2; }
        else      { if(tc <= ly1 || tc >= ly2) continue; blo = lx1; bhi = lx2; }
        if(run_hi <= blo || run_lo >= bhi) continue;
        bi = m; bx1 = lx1; by1 = ly1; bx2 = lx2; by2 = ly2; break;
      }
      if(bi < 0) bad = 1;

      /* net must be a FOLLOW net (a moved pin carries this node); NO moved pin may lie on the run (that
       * is the pin-incident shove's job -- do not duplicate/fight it); NO fixed pin on the run either
       * (translating the run would sever its attachment, invisible to the pin-indexed verify). */
      for(m = 0; m < xctx->instances && !bad; ++m) {
        int np, p2;
        if(xctx->inst[m].ptr < 0) continue;
        np = (xctx->inst[m].ptr + xctx->sym)->rects[PINLAYER];
        for(p2 = 0; p2 < np; ++p2) {
          double qx, qy, qc, qa;
          get_inst_pin_coord(m, p2, &qx, &qy);
          qc = xmove ? qx : qy; qa = xmove ? qy : qx;
          if(xctx->inst[m].sel == SELECTED && xctx->inst[m].node && xctx->inst[m].node[p2] &&
             !strcmp(xctx->inst[m].node[p2], node)) has_moved_pin = 1;
          if(qc == tc && qa >= run_lo && qa <= run_hi) {
            if(xctx->inst[m].sel == SELECTED) pin_on_run = 1;
            else bad = 1;
          }
        }
      }
      if(!has_moved_pin || pin_on_run) bad = 1;

      /* attachments: every non-run wire endpoint exactly on column tc within the run interval. Each
       * must be a plain same-net axis-aligned thin wire whose FAR end is off the column (a real
       * perpendicular attachment); a bus / foreign node / diagonal / collinear-on-column endpoint
       * DECLINES the whole shove (cannot be re-soldered safely). fa[] = far-end cross coord; the lean
       * (which side the attachments extend to) orders the two shove-target candidates. */
      for(w = 0; w < nw0 && !bad; ++w) {
        const char *wn2 = xctx->wire[w].node;
        if(run[w]) continue;
        if(xctx->wire[w].x1 == xctx->wire[w].x2 && xctx->wire[w].y1 == xctx->wire[w].y2) continue;
        for(e = 0; e < 2 && !bad; ++e) {
          double ex = e ? xctx->wire[w].x2 : xctx->wire[w].x1;
          double ey = e ? xctx->wire[w].y2 : xctx->wire[w].y1;
          double cross = xmove ? ex : ey, along = xmove ? ey : ex;
          double fcross = xmove ? (e ? xctx->wire[w].x1 : xctx->wire[w].x2)
                                : (e ? xctx->wire[w].y1 : xctx->wire[w].y2);
          if(cross != tc) continue;
          if(along < run_lo || along > run_hi) continue;
          if(xctx->wire[w].bus != 0.0 || !wn2 || strcmp(wn2, node) ||
             (xctx->wire[w].x1 != xctx->wire[w].x2 && xctx->wire[w].y1 != xctx->wire[w].y2) ||
             fcross == tc) { bad = 1; break; }
          if(ncorn >= TRUNK_MAXCORN) { bad = 1; break; }
          cw[ncorn] = w; ce[ncorn] = e; ca[ncorn] = along; fa[ncorn] = fcross;
          lean += (fcross > tc) ? 1 : -1;
          ++ncorn;
        }
      }
      if(!bad && ncorn == 0) bad = 1;                       /* nothing to re-anchor: not our shape */

      /* the trunk must be LOAD-BEARING (a BRIDGE): dooming the run must change the pin partition. A
       * REDUNDANT run -- a user-drawn ring/loop the moved body merely overlaps (test_wireedit_45 cases
       * U/T) -- keeps the partition intact via its other edges, so reshaping it would silently mangle
       * deliberate user copper (P7). Only a true trunk whose removal disconnects the moved pin from its
       * anchor is ours to shove. Pure computation via fluid_loop_partition's doomed mask (no mutation). */
      if(!bad) {
        int npX = fluid_count_pins(), *rA, *rR;
        rA = my_malloc(_ALLOC_ID_, (size_t)(npX > 0 ? npX : 1) * sizeof(int));
        rR = my_malloc(_ALLOC_ID_, (size_t)(npX > 0 ? npX : 1) * sizeof(int));
        fluid_loop_partition(NULL, rA);
        fluid_loop_partition(run, rR);
        if(fluid_part_equal(rA, rR, npX)) {                 /* pin-partition sees no change -- but... */
          /* issue 0139 (after_42): the pin-partition is BLIND to a SINGLE-PIN feed. Here #net1 carries
           * only the LED pin (its rail dead-ends with no second device pin), so dooming the sole path
           * from the pin's stub to the rail moves no pin between components, yet the trunk IS load-
           * bearing. Fall back to a WIRE-level cut-edge test: with the run doomed, flood touch-
           * connectivity from the first attachment; if any other attachment is unreachable, the run is
           * a genuine BRIDGE (ours to shove). A redundant user ring (test_wireedit_45 U/T) keeps every
           * attachment mutually reachable through its OTHER arc, so it still reads redundant here and is
           * declined. Only widens what is accepted for a run pin-partition already called redundant, and
           * the body-free precheck + DOUBLE partition-verify with exact revert still guard the reshape. */
          int a, brdg = 0;
          unsigned char *rch = my_malloc(_ALLOC_ID_, (size_t)(nw0 > 0 ? nw0 : 1) * sizeof(unsigned char));
          memset(rch, 0, (size_t)(nw0 > 0 ? nw0 : 1) * sizeof(unsigned char));
          if(ncorn > 0) {
            int gr; rch[cw[0]] = 1;
            do {
              gr = 0;
              for(w = 0; w < nw0; ++w) {
                int k;
                if(rch[w] || run[w]) continue;
                for(k = 0; k < nw0; ++k)
                  if(rch[k] && !run[k] && k != w && fluid_wires_touch(w, k)) { rch[w] = 1; gr = 1; break; }
              }
            } while(gr);
            for(a = 1; a < ncorn; ++a) if(!rch[cw[a]]) { brdg = 1; break; }
          }
          if(!brdg) bad = 1;                                /* truly redundant: a ring the body overlaps */
          my_free(_ALLOC_ID_, &rch);
        }
        my_free(_ALLOC_ID_, &rA);
        my_free(_ALLOC_ID_, &rR);
      }

      /* pick a shove target: one grid past the crossed body edge, on the side the attachments lean
       * toward first, then the other side. Accept the first that is BODY-FREE (trunk + every rebuilt
       * attachment clears every moved & stationary body) and welds no foreign copper. */
      for(side = 0; side < 2 && !bad; ++side) {
        double ct = 0, base;
        int prefer_hi = (lean >= 0);
        int hi = prefer_hi ? (side == 0) : (side == 1);    /* which body edge this iteration shoves past */
        int free_ok = 0, s;
        if(xmove) base = hi ? fluid_grid_above(bx2, grid) : fluid_grid_below(bx1, grid);
        else      base = hi ? fluid_grid_above(by2, grid) : fluid_grid_below(by1, grid);
        /* base target = one grid past the crossed body edge. issue 0139: when a NEIGHBOUR net's copper
         * already occupies that grid line -- straighten parks the REF #net2 crossbar exactly one grid out,
         * the very line the LED #net1 trunk would land on -- a lone one-grid shove welds it foreign and
         * declines, leaving the body-cross. STEP the target further out grid-by-grid until the rail clears
         * the neighbour (a mid-span-only crossing that shares no endpoint is left as a benign near-miss,
         * per 0136 defect 2). A BODY block (the far attachment would thread a device body) means this is
         * the WRONG side -- stop stepping and try the other edge. Bounded so a pathological layout cannot
         * run the target away. The DOUBLE partition-verify below still guards every accepted step. */
        for(s = 0; s < 12 && !free_ok; ++s) {
          int bodyblk = 0, foreignblk = 0;
          ct = base + (double)s * (hi ? grid : -grid);
          {
            double t1x = xmove ? ct : run_lo, t1y = xmove ? run_lo : ct;
            double t2x = xmove ? ct : run_hi, t2y = xmove ? run_hi : ct;
            if(fluid_seg_crosses_sel_body(t1x, t1y, t2x, t2y) ||
               fluid_seg_crosses_stationary_body(t1x, t1y, t2x, t2y)) bodyblk = 1;
            if(fluid_seg_welds_foreign(t1x, t1y, t2x, t2y, node, -1)) foreignblk = 1;
          }
          for(j = 0; j < ncorn && !bodyblk; ++j) {
            double nx = xmove ? ct : ca[j], ny = xmove ? ca[j] : ct;
            double fx = xmove ? fa[j] : ca[j], fy = xmove ? ca[j] : fa[j];
            if(fluid_seg_crosses_sel_body(nx, ny, fx, fy) ||
               fluid_seg_crosses_stationary_body(nx, ny, fx, fy)) bodyblk = 1;
            if(fluid_seg_welds_foreign(nx, ny, fx, fy, node, cw[j])) foreignblk = 1;
          }
          if(bodyblk) break;                               /* wrong side: a far leg would thread a body */
          if(!foreignblk) free_ok = 1;                     /* clear at this grid line: take it */
        }
        if(!free_ok) continue;                             /* this side never cleared: try the other */

        /* apply the translate under a mem-snapshot; DOUBLE partition-verify; exact revert on mismatch */
        {
          Undo_slot snap;
          unsigned int s_wid = xctx->wire_id_counter, s_iid = xctx->inst_id_counter;
          unsigned int s_gid = xctx->gfx_id_counter,  s_tid = xctx->text_id_counter;
          int npA, npB, ok, *repA, *repB;
          memset(&snap, 0, sizeof(snap));
          mem_snapshot_alloc(&snap); mem_serialize_slot(&snap);
          npA = fluid_count_pins();
          repA = my_malloc(_ALLOC_ID_, (size_t)(npA > 0 ? npA : 1) * sizeof(int));
          repB = my_malloc(_ALLOC_ID_, (size_t)(npA > 0 ? npA : 1) * sizeof(int));
          fluid_loop_partition(NULL, repA);
          for(w = 0; w < nw0; ++w) if(run[w]) {            /* translate the run to column ct */
            if(xmove) { xctx->wire[w].x1 = ct; xctx->wire[w].x2 = ct; }
            else      { xctx->wire[w].y1 = ct; xctx->wire[w].y2 = ct; }
            order_wire_coords(w);
          }
          for(j = 0; j < ncorn; ++j) {                     /* move each attachment's near end to ct */
            if(ce[j]) { if(xmove) xctx->wire[cw[j]].x2 = ct; else xctx->wire[cw[j]].y2 = ct; }
            else      { if(xmove) xctx->wire[cw[j]].x1 = ct; else xctx->wire[cw[j]].y1 = ct; }
            order_wire_coords(cw[j]);
          }
          check_collapsing_objects();
          xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
          prepare_netlist_structs(0);
          npB = fluid_count_pins();
          fluid_loop_partition(NULL, repB);
          ok = (fluid_partition_changed() == 0) && npB == npA && fluid_part_equal(repA, repB, npA);
          if(!ok) {
            unsigned int saved_ui = xctx->ui_state;
            mem_restore_slot(&snap, 0);
            xctx->ui_state = saved_ui;
            xctx->wire_id_counter = s_wid; xctx->inst_id_counter = s_iid;
            xctx->gfx_id_counter  = s_gid; xctx->text_id_counter = s_tid;
            xctx->need_reb_sel_arr = 1; rebuild_selected_array();
            xctx->movelastsel = xctx->lastsel;
            xctx->prep_hash_wires = xctx->prep_net_structs = xctx->prep_hi_structs = 0;
            prepare_netlist_structs(0);
            fltrace("FLTRACE trunkshove: tc=%g -> ct=%g REVERTED (verify failed)\n", tc, ct);
          } else {
            changed = 1; restart = 1;
            fltrace("FLTRACE trunkshove: tc=%g run=[%g %g] -> ct=%g corners=%d SHOVED\n",
                    tc, run_lo, run_hi, ct, ncorn);
          }
          mem_snapshot_free(&snap);
          my_free(_ALLOC_ID_, &repA);
          my_free(_ALLOC_ID_, &repB);
        }
        break;                                             /* body-free side chosen: done with sides */
      }
      if(bad) fltrace("FLTRACE trunkshove: tc=%g run=[%g %g] corners=%d DECLINE\n",
                      tc, run_lo, run_hi, ncorn);
      my_free(_ALLOC_ID_, &run);
      my_free(_ALLOC_ID_, &node);
    }
  }
  return changed;
}

static void fluid_shove_connected_wire(int orthogonal_wiring)
{
  double grid = tclgetdoublevar("cadsnap");
  int dxnz, dynz, s, iter;

  if(!orthogonal_wiring) return;
  if(fluid_failsafe(!fluid_g.snap_pinnet || fluid_g.snap_npins <= 0)) return;
  if(fluid_failsafe(fluid_count_pins() != fluid_g.snap_npins)) return;   /* instance set changed: snapshot unreliable */
  if(grid <= 0.0) grid = 1.0;
  dxnz = (xctx->deltax != 0.0);
  dynz = (xctx->deltay != 0.0);
  if(dxnz == dynz) return;                              /* pure axis-aligned moves only */
  s = dynz ? (xctx->deltay > 0.0 ? 1 : -1) : (xctx->deltax > 0.0 ? 1 : -1);

  /* refresh the pre-move net cache (xctx->wire[].node) so fluid_seg_hits_foreign_wire can tell a
   * distinct-net wire from a same-net one; the shove has not mutated geometry yet. */
  prepare_netlist_structs(0);

  /* one shove per crossed stub; cap at wire count as a runaway backstop (a shoved stub stops matching
   * the reached/passed test, so the loop terminates well before the cap). */
  for(iter = 0; iter < xctx->wires + 1; ++iter) {
    int n, found = -1, endpin = 0, m, V = -1, perpcount = 0, others = 0;
    double ex = 0, ey = 0, ox = 0, oy = 0;             /* stub S: pin end / junction (far) end */
    double cx = 0, cy = 0;                             /* V's far corner */
    double pm0, jc, pmc, jpx, jpy, dsx, dsy, ncx, ncy;
    double vlo, vhi, vperp;                            /* V span + line, for the clean-span guard */
    int unclean = 0;
    const char *nf;

    /* --- find the crossed stub S: a wire PARALLEL to the move with EXACTLY ONE moving-pin endpoint,
     *     driven TOWARD its fixed far end J and REACHED/PASSED it, whose J is a CLEAN corner carrying
     *     exactly one connected perpendicular wire V --- */
    for(n = 0; n < xctx->wires && found < 0; ++n) {
      double x1 = xctx->wire[n].x1, y1 = xctx->wire[n].y1;
      double x2 = xctx->wire[n].x2, y2 = xctx->wire[n].y2;
      int e1, e2;
      if(dynz && x1 != x2) continue;                   /* vertical move -> parallel stub is vertical */
      if(dxnz && y1 != y2) continue;
      if(x1 == x2 && y1 == y2) continue;               /* degenerate */
      e1 = point_on_moving_pin(x1, y1);
      e2 = point_on_moving_pin(x2, y2);
      if(e1 == e2) continue;                           /* need exactly one moving-pin endpoint */
      endpin = e1;
      ex = e1 ? x1 : x2;  ey = e1 ? y1 : y2;           /* moving pin end (post-move) */
      ox = e1 ? x2 : x1;  oy = e1 ? y2 : y1;           /* junction / far end (unchanged by the move) */
      if(point_on_fixed_pin(ox, oy)) continue;         /* never shove a wire off a fixed pin */
      pm0 = dynz ? (ey - xctx->deltay) : (ex - xctx->deltax);   /* pre-move pin along-coord */
      jc  = dynz ? oy : ox;                            /* junction along-coord */
      pmc = dynz ? ey : ex;                            /* post-move pin along-coord */
      if((jc - pm0) * s <= 0.0) continue;              /* must have been moving TOWARD J */
      if((pmc - jc) * s <  0.0) continue;              /* must have REACHED/PASSED J (overrun >= 0) */

      /* J must be a CLEAN corner: exactly one perpendicular UNSELECTED wire (=V), nothing else */
      perpcount = 0; others = 0; V = -1;
      for(m = 0; m < xctx->wires; ++m) {
        double mx1, my1, mx2, my2;
        int perp;
        if(m == n) continue;
        mx1 = xctx->wire[m].x1; my1 = xctx->wire[m].y1;
        mx2 = xctx->wire[m].x2; my2 = xctx->wire[m].y2;
        if(!((mx1 == ox && my1 == oy) || (mx2 == ox && my2 == oy))) continue;   /* not at J */
        perp = dynz ? (my1 == my2 && mx1 != mx2) : (mx1 == mx2 && my1 != my2);
        if(perp && xctx->wire[m].sel == 0) { V = m; ++perpcount; }
        else ++others;
      }
      if(perpcount != 1 || others != 0) continue;      /* T-tap / ambiguous -> leave to baseline */
      found = n;
    }
    if(found < 0) break;
    n = found;

    /* V's far corner C (the endpoint that is not J) */
    if(xctx->wire[V].x1 == ox && xctx->wire[V].y1 == oy) { cx = xctx->wire[V].x2; cy = xctx->wire[V].y2; }
    else                                                { cx = xctx->wire[V].x1; cy = xctx->wire[V].y1; }
    if(point_on_fixed_pin(cx, cy)) break;              /* can't tear V's far end off a fixed pin */

    /* V must be a CLEAN isolated segment J..C: (1) no wire endpoint STRICTLY inside its span (a
     * mid-span tap would be stranded when V translates -> P1 disconnect), and (2) no COLLINEAR wire
     * at C (a continuation / autotrim split of V; the one-level arm drag would bend it into a diagonal
     * -> P4). Perpendicular arms at C are fine (they are what legitimately follow). Else DECLINE. */
    vperp = dynz ? oy : ox;                             /* V's constant coord (its line) */
    vlo = (dynz ? ox : oy) < (dynz ? cx : cy) ? (dynz ? ox : oy) : (dynz ? cx : cy);
    vhi = (dynz ? ox : oy) < (dynz ? cx : cy) ? (dynz ? cx : cy) : (dynz ? ox : oy);
    for(m = 0; m < xctx->wires && !unclean; ++m) {
      double mx1, my1, mx2, my2;
      int e_at_c, coll;
      if(m == n || m == V) continue;
      mx1 = xctx->wire[m].x1; my1 = xctx->wire[m].y1;
      mx2 = xctx->wire[m].x2; my2 = xctx->wire[m].y2;
      /* (1) endpoint strictly inside V's open span, on V's line */
      if(dynz) {
        if(my1 == vperp && mx1 > vlo && mx1 < vhi) unclean = 1;
        if(my2 == vperp && mx2 > vlo && mx2 < vhi) unclean = 1;
      } else {
        if(mx1 == vperp && my1 > vlo && my1 < vhi) unclean = 1;
        if(mx2 == vperp && my2 > vlo && my2 < vhi) unclean = 1;
      }
      /* (2) a wire COLLINEAR with V that has an endpoint at C = a continuation, not an arm */
      e_at_c = (mx1 == cx && my1 == cy) || (mx2 == cx && my2 == cy);
      coll = dynz ? (my1 == my2 && my1 == vperp) : (mx1 == mx2 && mx1 == vperp);
      if(e_at_c && coll) unclean = 1;
    }
    if(unclean) break;                                 /* messy V -> decline, leave baseline */

    /* J' = pin one grid OUTWARD along the drive axis; ds = J' - J; C' = C + ds */
    jpx = dxnz ? ex + grid * s : ex;
    jpy = dynz ? ey + grid * s : ey;
    dsx = jpx - ox;  dsy = jpy - oy;
    ncx = cx + dsx;  ncy = cy + dsy;

    /* P2: decline (=> baseline) if the new stub, the shoved V, or a dragged arm would land on a
     * stationary distinct-net pin, a co-moving distinct-net pin, or a stationary foreign-net wire.
     * nf = the moving pin's pristine (START) net (S and V are on nf by construction). */
    nf = fluid_moving_pin_net(ex, ey);
    if(nf && nf[0]) {
      if(fluid_seg_hits_foreign_pin(ex, ey, jpx, jpy, nf)) break;           /* new S vs foreign pin */
      if(fluid_seg_hits_foreign_pin(jpx, jpy, ncx, ncy, nf)) break;         /* new V vs foreign pin */
      if(fluid_seg_hits_moving_pin(ex, ey, jpx, jpy, nf, ex, ey)) break;    /* new S vs co-moving pin */
      if(fluid_seg_hits_moving_pin(jpx, jpy, ncx, ncy, nf, ex, ey)) break;  /* new V vs co-moving pin */
      if(fluid_seg_hits_foreign_wire(ex, ey, jpx, jpy, nf, n, V, -1)) break;    /* new S vs foreign wire */
      if(fluid_seg_hits_foreign_wire(jpx, jpy, ncx, ncy, nf, n, V, -1)) break;  /* new V vs foreign wire */
      /* each arm (a wire with an endpoint at C, other than V/S) checked over its NEW span (far end->C') */
      for(m = 0; m < xctx->wires; ++m) {
        double af, ag;   /* arm's fixed far end */
        int at1, at2;
        if(m == n || m == V) continue;
        at1 = (xctx->wire[m].x1 == cx && xctx->wire[m].y1 == cy);
        at2 = (xctx->wire[m].x2 == cx && xctx->wire[m].y2 == cy);
        if(!at1 && !at2) continue;
        af = at1 ? xctx->wire[m].x2 : xctx->wire[m].x1;
        ag = at1 ? xctx->wire[m].y2 : xctx->wire[m].y1;
        if(fluid_seg_hits_foreign_pin(af, ag, ncx, ncy, nf)) { unclean = 1; break; }
        if(fluid_seg_hits_moving_pin(af, ag, ncx, ncy, nf, ex, ey)) { unclean = 1; break; }
        if(fluid_seg_hits_foreign_wire(af, ag, ncx, ncy, nf, n, V, m)) { unclean = 1; break; }
      }
      if(unclean) break;
    }

    /* commit: (1) one-level arm drag at C -> C' (skip V and S), (2) translate V wholesale,
     * (3) collapse S to the one-grid OUTWARD stub pin -> J'. (cx,cy captured before any mutation.) */
    for(m = 0; m < xctx->wires; ++m) {
      int touched = 0;
      if(m == n || m == V) continue;
      if(xctx->wire[m].x1 == cx && xctx->wire[m].y1 == cy) { xctx->wire[m].x1 = ncx; xctx->wire[m].y1 = ncy; touched = 1; }
      if(xctx->wire[m].x2 == cx && xctx->wire[m].y2 == cy) { xctx->wire[m].x2 = ncx; xctx->wire[m].y2 = ncy; touched = 1; }
      if(touched) order_wire_coords(m);
    }
    xctx->wire[V].x1 += dsx; xctx->wire[V].y1 += dsy;
    xctx->wire[V].x2 += dsx; xctx->wire[V].y2 += dsy;
    order_wire_coords(V);
    if(endpin) { xctx->wire[n].x2 = jpx; xctx->wire[n].y2 = jpy; }
    else       { xctx->wire[n].x1 = jpx; xctx->wire[n].y1 = jpy; }
    order_wire_coords(n);

    xctx->prep_hash_wires = 0; xctx->prep_net_structs = 0; xctx->prep_hi_structs = 0;
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
  }
}

/* Runtime P1/P2 no-short/disconnect/device-merge check at move END. Publishes per-class counts to
 * the fluid_last_move_* Tcl vars AND returns the P2 ELECTRICAL-MERGE count (shorts + dev_merges,
 * 0 == none) -- the signal the END enforcement gate (B3) refuses on. Disconnects are published but
 * NOT part of the return: a P1 disconnect is VISIBLE (a dangling pin), its partition-diff count is
 * cascade-sensitive (WIRING.md §5 -- trust zero/nonzero, not magnitude), and the "never-worse"
 * healers legitimately accept a baseline disconnect (test_wireedit_42); the sprint's target is the
 * SILENT saved short/merge, so enforcement refuses on P2 only and disconnects stay log-only. */
/* Count net-label instances whose forced name disagrees with the physical net of the wire they
 * touch -- the P2 label-short signal. This is an ABSOLUTE (whole-schematic) count. The END enforce
 * gate turns it into a DELTA by subtracting the gesture-START baseline (see fluid_check_move_invariants
 * + the enf_short_base capture at the pristine snapshot): a PRE-EXISTING naming short on a net the
 * gesture never touched must NOT veto an otherwise-valid move (issue 0123 -- moving an isolated
 * segment of a clean net was refused because a foreign net elsewhere carried conflicting labels).
 * Requires inst[].node[]/wire[].node fresh (caller runs prepare_netlist_structs). */
static int fluid_count_label_shorts(void)
{
  int i, w, shorts = 0;
  for(i = 0; i < xctx->instances; ++i) {
    const char *type = xctx->sym[xctx->inst[i].ptr].type;
    const char *intended;
    double px, py;
    if(!type || strcmp(type, "label")) continue;         /* only net labels */
    if(!xctx->inst[i].node || !xctx->inst[i].node[0]) continue;
    intended = xctx->inst[i].node[0];                    /* the net this label names */
    get_inst_pin_coord(i, 0, &px, &py);                  /* a net label has a single pin (0) */
    for(w = 0; w < xctx->wires; ++w) {
      if(touch(xctx->wire[w].x1, xctx->wire[w].y1, xctx->wire[w].x2, xctx->wire[w].y2, px, py)) {
        const char *phys = xctx->wire[w].node;
        if(phys && strcmp(intended, phys)) {
          ++shorts;
          dbg(0, "fluid_editing INVARIANT (P2): net label '%s' (%s) on net '%s' -- "
                 "possible short/merge\n", intended, xctx->inst[i].instname, phys);
        }
        break;                                           /* first wire at the pin is enough */
      }
    }
  }
  return shorts;
}

static int fluid_check_move_invariants(int short_baseline)
{
  int shorts = 0, disconnects = 0, dev_merges = 0, short_delta;
  if(!tclgetboolvar("fluid_editing")) { fluid_gesture_free(); return 0; }
  prepare_netlist_structs(0);
  /* --- P2: no-short/merge (wire-level, see comment above). DELTA vs the gesture-START baseline:
   * only shorts THIS gesture INTRODUCED count toward the refuse signal. --- */
  shorts = fluid_count_label_shorts();
  short_delta = shorts - short_baseline;
  if(short_delta < 0) short_delta = 0;                   /* a gesture that HEALS a pre-existing short */
  /* --- P1: connectivity partition unchanged (pin-level, vs START snapshot) --- */
  if(fluid_g.snap_id && fluid_g.snap_npins > 0) {
    int tot = fluid_count_pins();
    if(tot == fluid_g.snap_npins) {                        /* structure comparable (no inst added/removed) */
      int *now = my_malloc(_ALLOC_ID_, tot * sizeof(int));
      int m = fluid_build_partition(now, tot), k;
      if(m == fluid_g.snap_npins)
        for(k = 0; k < m; ++k) if(now[k] != fluid_g.snap_id[k]) ++disconnects;
      my_free(_ALLOC_ID_, &now);
    }
    if(disconnects)
      dbg(0, "fluid_editing INVARIANT (P1): %d instance pin(s) changed net partition after "
             "move -- possible disconnect\n", disconnects);
  }
  /* --- P2 (general): device-pin-merge -- catches a DEVICE short (no net label), the R18/v8 class
   * the label pass above misses. Runs BEFORE the snapshot is freed. --- */
  dev_merges = fluid_check_device_merge();
  fluid_gesture_free();
  tclsetvar("fluid_last_move_violations", my_itoa(short_delta));  /* violations THIS move introduced */
  tclsetvar("fluid_last_move_disconnects", my_itoa(disconnects));
  tclsetvar("fluid_last_move_dev_merges", my_itoa(dev_merges));
  tclsetvar("fluid_last_move_failsafes", my_itoa(fluid_move_failsafes));  /* B4: silent-degradation count */
  fltrace("FLTRACE move: fluid_last_move_failsafes=%d (fluid helpers that fail-safe no-op'd)\n",
          fluid_move_failsafes);
  return short_delta + dev_merges;   /* P2 electrical-merge count (gesture-introduced) = refuse signal */
}

/* incremental_wire_reroute.md Phase II: restore the live schematic to the pristine (post-kiss,
 * pre-delta) snapshot taken at move START, then re-establish the move-scoped state that
 * mem_restore_slot() resets. Called before each per-step reroute (RUBBER) and before the final
 * commit at a dirty END.
 *
 * mem_restore_slot() clears the drawing, frees+reallocs every object array, and (via
 * unselect_all(1)) ZEROES xctx->ui_state and lastsel. Everything else the reroute pipeline needs
 * (x1/y1 anchor, deltax/deltay, stretch_select, stretch_grabbed_xy/n, connect_by_kissing/kissing,
 * fluid_startsel_wires, the Phase-1 partition snapshot) lives in xctx scalars/side-arrays that
 * restore does NOT touch, so it survives. What we must put back here:
 *   - ui_state: preserve the whole word (STARTMOVE + any gesture bits) across the restore;
 *   - the four session-stable id counters: reset to their START values so tool-created wires
 *     (exit stubs, split fragments, kiss stubs) re-stamp IDENTICAL ids every step (determinism);
 *   - sel_array/lastsel: rebuilt from the restored per-object .sel bits;
 *   - movelastsel = lastsel: so update_symbol_bboxes()'s [0,movelastsel) bound tracks the
 *     restored selection (a stale movelastsel > lastsel re-fires the dce0bea6 symbol_bbox
 *     heap-overflow). */
static void fluid_reroute_restore(void)
{
  unsigned int saved_ui = xctx->ui_state;
  mem_restore_slot(&xctx->fluid_reroute_snap, 0);
  xctx->ui_state = saved_ui;
  xctx->wire_id_counter = xctx->fluid_reroute_wid;
  xctx->inst_id_counter = xctx->fluid_reroute_iid;
  xctx->gfx_id_counter  = xctx->fluid_reroute_gid;
  xctx->text_id_counter = xctx->fluid_reroute_tid;
  xctx->need_reb_sel_arr = 1;
  rebuild_selected_array();
  xctx->movelastsel = xctx->lastsel;
}

/* incremental_wire_reroute.md Phase II: drop the active gesture's snapshot (free the deep copy +
 * the per-layer arrays) and clear the ownership flags. Runs on EVERY move END and ABORT exit so a
 * leaked fluid_reroute_active can never make an unrelated later gesture restore a stale/freed
 * snapshot. Also called from clear_schematic() (actions.c) so tearing down / reloading the buffer
 * while a fluid stretch is armed cannot resurrect the pre-clear geometry or leak the deep copy.
 * NOT static (clear_schematic calls it). Idempotent (mem_snapshot_free no-ops on a zeroed slot). */
void fluid_reroute_discard(void)
{
  mem_snapshot_free(&xctx->fluid_reroute_snap);
  xctx->fluid_reroute_active = 0;
  xctx->fluid_reroute_dirty = 0;
}

/* incremental_wire_reroute.md §10.10 / issue 0081: between the X and Y legs of a diagonal fluid
 * stretch, re-derive the tool-owned follow set from the (X-moved, cleaned) leg-A geometry so the
 * Y leg is a fresh pure-axis stretch. Leg A's deselect tail (the Phase-I follow-wire deselect,
 * gated on fluid_startsel_wires==0) has zeroed every wire.sel, so select_attached_nets re-grabs a
 * FRESH single-endpoint (SELECTED1/2) follow set at the X-moved pins -- place_moved_wire then
 * relays each pin-incident segment exactly ONCE per leg (never an L-of-an-L; the M2 failure mode).
 *   - fluid_startsel_wires: select_attached_nets recounts it (select.c) by scanning wire.sel; the
 *     recount is 0 here (leg A deselected all follow wires), which is also its START value on this
 *     path (the two-leg gate required ==0), so save/restore is a no-op belt-and-suspenders that
 *     keeps the deselect-tail gate correct for leg B regardless.
 *   - movelastsel: select_attached_nets -> rebuild_selected_array updates lastsel but NOT
 *     movelastsel; leg B's update_symbol_bboxes(0,0) iterates sel_array[0,movelastsel), and a stale
 *     movelastsel > lastsel re-fires the dce0bea6 symbol_bbox heap-buffer-overflow read. */
static void move_regrab_follow_set(void)
{
  int saved = xctx->fluid_startsel_wires;
  int saved_nid = xctx->fluid_startsel_nid;           /* issue 0091: preserve the user-selected id set */
  /* issue 0117: this regrab runs BETWEEN the X and Y legs, when the geometry is the intermediate
   * X-moved state. select_attached_nets() strokes the highlight of every grabbed wire; that
   * intermediate stroke bakes a ghost segment into save_pixmap (at the leg-A pin row) that the
   * final END redraw never erases. Re-derive the SET only -- the END draw repaints the real
   * highlight at the committed geometry. */
  xctx->select_attached_nodraw = 1;
  select_attached_nets();
  xctx->select_attached_nodraw = 0;
  xctx->fluid_startsel_wires = saved;
  xctx->fluid_startsel_nid = saved_nid;               /* regrab (all sel==0) rebuilt an empty set */
  xctx->movelastsel = xctx->lastsel;
}

/* merge param unused, RFU */
void move_objects(int what, int merge, double dx, double dy)
{
  int c, i, n, k, tmpint;
  double angle, dtmp;
  double tx1,ty1; /* temporaries for swapping coordinates 20070302 */
  char *estr = NULL;
  int orthogonal_wiring = tclgetboolvar("orthogonal_wiring");
  #if HAS_CAIRO==1
  int customfont;
  #endif
  /* incremental_wire_reroute.md Phase II: when a fluid stretch RUBBER step wants to commit the
   * reroute live, it restores the pristine snapshot, sets commit_now, and FALLS THROUGH to the END
   * geometry-commit block below (which is guarded by `(what & END) || commit_now`). commit_now then
   * gates OUT every END-only finalizer (undo push, ui_state teardown, hilight, the final draw) so
   * the SAME commit code runs, but the gesture stays live. */
  int commit_now = 0;
  /* NOT const: a mem_restore_slot() inside a RUBBER step or a dirty END frees+reallocs xctx->wire /
   * xctx->line, so these are re-fetched just before the commit block (using the stale capture would
   * be a heap use-after-free). */
  xLine **line = xctx->line;
  xWire *wire = xctx->wire;

  dbg(1, "move_objects: what=%d, dx=%g, dy=%g\n", what, dx, dy);
  if(what & START)
  {
   xctx->rotatelocal=0;
   xctx->deltax = xctx->deltay = 0.0;
   rebuild_selected_array();
   /* read-only backstop (issue 0041): refuse to begin a move below the entry guards.
    * Placed alongside the lastsel==0 early return so a refused START leaves the same
    * clean state an empty-selection START does (deltas zeroed, selection rebuilt), which
    * keeps a follow-on END (the scheduler calls START then END) a no-op. ABORT/RUBBER/END
    * of an already-started gesture are left alone (none can start on a read-only buffer). */
   if(begin_edit("move")) return;
   if(xctx->lastsel==0) return;
   /* movelastsel must be refreshed to the CURRENT selection BEFORE update_symbol_bboxes(), which
    * iterates sel_array[0..movelastsel-1]. Otherwise it uses the STALE count from the previous move:
    * if that count exceeds the current selection (e.g. the last gesture selected more, then objects
    * were cleared/deleted), the loop reads stale sel_array entries that may index an instance with
    * ptr<0 (unlinked), and symbol_bbox() then dereferences (ptr + xctx->sym) BEFORE the sym array --
    * a heap-buffer-overflow read (found via AddressSanitizer). It is re-snapshotted below after
    * connect_by_kissing() so kissed stubs are still included in the move. */
   xctx->movelastsel = xctx->lastsel;
   update_symbol_bboxes(0, 0);
   /* if connect_by_kissing==2 it was set in callback.c ('M' command) */
   if(xctx->connect_by_kissing == 2) xctx->kissing = connect_by_kissing();
   else xctx->kissing = 0;
   xctx->movelastsel = xctx->lastsel;
   if(xctx->lastsel==1 && xctx->sel_array[0].type==ARC &&
           xctx->arc[c=xctx->sel_array[0].col][n=xctx->sel_array[0].n].sel!=SELECTED) {
     xctx->x1 = xctx->arc[c][n].x;
     xctx->y1 = xctx->arc[c][n].y;
   } else {xctx->x1=xctx->mousex_snap;xctx->y1=xctx->mousey_snap;}
   xctx->move_flip = 0;xctx->move_rot = 0;
   xctx->ui_state|=STARTMOVE;
   fluid_gesture_arm(); /* Phase 1 P1 guard: capture pre-move connectivity partition (D1: arm the Fluid_gesture) */
   fluid_move_failsafes = 0;   /* B4: reset the per-gesture fail-safe degradation counter at START */
   /* incremental_wire_reroute Phase I (ownership decoupling): xctx->fluid_startsel_wires (the count
    * of the user's own selected wires) is captured in select_attached_nets(), which runs BEFORE this
    * START -- it must be taken before follow-wires are grabbed/folded, so it cannot be recomputed
    * here. The END deselect is gated on stretch_select, set only by select_attached_nets alongside
    * that count, so the two are always consistent (a non-stretch move never consumes it). */
   /* incremental_wire_reroute.md Phase II: snapshot the pristine (post-kiss, pre-delta) schematic so
    * each RUBBER step can restore-and-reapply the total delta. Taken HERE -- after connect_by_kissing
    * and after movelastsel was refreshed to lastsel above -- so the snapshot's selection count equals
    * movelastsel. Only for a fluid stretch (the sole path that reroutes follow-wires). fluid_reroute_
    * discard() first clears any snapshot a prior gesture failed to release (defensive; END/ABORT
    * always discard, so normally a no-op). */
   fluid_reroute_discard();
   if(tclgetboolvar("fluid_editing") && xctx->stretch_select) {
     mem_snapshot_alloc(&xctx->fluid_reroute_snap);
     mem_serialize_slot(&xctx->fluid_reroute_snap);
     xctx->fluid_reroute_wid = xctx->wire_id_counter;
     xctx->fluid_reroute_iid = xctx->inst_id_counter;
     xctx->fluid_reroute_gid = xctx->gfx_id_counter;
     xctx->fluid_reroute_tid = xctx->text_id_counter;
     xctx->fluid_reroute_active = 1;
     xctx->fluid_reroute_dirty = 0;
   }
  }
  if(what & ABORT)  /* abort operation */
  {
   /* incremental_wire_reroute.md Phase II: a fluid stretch that committed >=1 live RUBBER step has
    * mutated the live geometry. Roll it back to the pristine snapshot FIRST, so the rest of this
    * ABORT block (and the kissing pop_undo below) sees exactly the post-kiss/pre-move state a
    * preview-only drag would present; then drop the snapshot. Repaint at the block end because the
    * committed intermediate route was baked into the canvas. */
   int fluid_was_dirty = xctx->fluid_reroute_active && xctx->fluid_reroute_dirty;
   if(xctx->fluid_reroute_active) {
     if(xctx->fluid_reroute_dirty) fluid_reroute_restore();
     fluid_reroute_discard();
   }
   xctx->paste_from = 0;
   draw_selection(xctx->gctiled,0);
   if(xctx->kissing) {
     pop_undo(0, 0);
     /* connect_by_kissing() created zero-length stub wires at the kissed pins
      * (meant to be stretched by the move). On an aborted/no-motion gesture they
      * stay degenerate; the pop_undo above can miss them when the cadence
      * deselect-on-release path perturbed the undo pointers, so sweep them with
      * the same degenerate-wire cleanup the normal move END uses. */
     check_collapsing_objects();
   }
   /* Always clear the kissing request on abort, even when nothing was kissed
    * (xctx->kissing == 0). Otherwise connect_by_kissing stays at 2 and leaks
    * into the NEXT move/copy gesture -- e.g. a plain press that kisses nothing
    * would make a subsequent Shift+drag copy spuriously draw connecting wires.
    * move END already resets it unconditionally; mirror that here. */
   if(xctx->connect_by_kissing == 2) xctx->connect_by_kissing = 0;
   /* clear the stretch-move flag too, so an aborted stretch gesture does not leak
    * the Phase-5 cleanup trigger into the next move (mirror of move END). */
   xctx->stretch_select = 0;
   xctx->stretch_grabbed_n = 0;
   my_free(_ALLOC_ID_, &xctx->stretch_grabbed_xy);
   xctx->fluid_startsel_nid = 0;                       /* issue 0091: drop the user-selected id set */
   my_free(_ALLOC_ID_, &xctx->fluid_startsel_id);

   xctx->move_rot=xctx->move_flip=0;
   xctx->deltax=xctx->deltay=0.;
   xctx->ui_state &= ~STARTMOVE;
   fluid_gesture_free(); /* Phase 1: aborted gesture -> drop the START snapshot (D1: free the Fluid_gesture) */
   update_symbol_bboxes(0, 0);
   /* the rolled-back pristine geometry replaces the committed intermediate route on screen. No
    * set_modify(): the RUBBER steps never set it (see the live-step branch), so an aborted fluid
    * drag leaves the buffer's modified flag exactly as it was pre-drag. */
   if(fluid_was_dirty) draw();
  }
  if(what & RUBBER)  /* draw objects while moving */
  {
   if(xctx->mousex_snap == xctx->x2 && xctx->mousey_snap == xctx->y2) return;
   /* incremental_wire_reroute.md Phase II: when a fluid stretch owns a snapshot, reroute LIVE on
    * every snap-grid step -- restore the pristine geometry and re-apply the CURRENT TOTAL delta
    * through the reroute pipeline (the shared geometry-commit block below, reached via commit_now).
    * mousex/y_snap is already cadsnap-quantized, so passing the no-motion guard above == a move of
    * >= one cadsnap.
    * rotate_keep_connected_stretch.md Case 4b: the old `move_rot==0 && move_flip==0` guard is
    * LIFTED so a rotated/flipped stretch reroutes live too. The shared commit block is
    * rotation-aware (ROTATION(pivot,.)+delta per object; the anchored follow-wire endpoint held
    * pristine, crux (a)), so the live route on a MOTION after a rotate matches the drop result.
    * The rot/flip-specific quality layers keep their own internal gates (diagonal decomposition,
    * corner-slide, shove stay translation-only); only the elbow-orientation choice is enabled
    * under rotation. */
   if(tclgetboolvar("fluid_editing") && (xctx->ui_state & STARTMOVE) && xctx->stretch_select &&
      xctx->fluid_reroute_active) {
     xctx->x2 = xctx->mousex_snap; xctx->y2 = xctx->mousey_snap;
     xctx->deltax = xctx->x2 - xctx->x1; xctx->deltay = xctx->y2 - xctx->y1;
     fluid_reroute_restore();   /* live geometry+selection -> pristine (frees+reallocs the arrays) */
     commit_now = 1;            /* fall through to the shared END geometry-commit block */
   } else {
     /* default / non-fluid: rubber-band preview only (bottom draw_selection paints it) */
     xctx->x2=xctx->mousex_snap;xctx->y2=xctx->mousey_snap;
     draw_selection(xctx->gctiled,0);
     xctx->deltax = xctx->x2-xctx->x1; xctx->deltay = xctx->y2 - xctx->y1;
   }
  }
  if(what & ROTATELOCAL) {
   xctx->rotatelocal=1;
  }
  {
   /* issue 0116 bug 1: during a LIVE fluid stretch the moved geometry is committed each RUBBER
    * step, so a bare move_rot/move_flip bump repaints nothing until the NEXT motion re-commits --
    * the user had to jiggle the mouse to see a mid-drag ALT-R/ALT-F. Detect the live-stretch case
    * so ROTATE/FLIP can force an immediate re-commit + repaint below. (A non-fluid move keeps its
    * overlay-XOR erase + bottom draw_selection redraw, which already shows the transform at once.) */
   int fluid_live = tclgetboolvar("fluid_editing") && (xctx->ui_state & STARTMOVE) &&
                    xctx->stretch_select && xctx->fluid_reroute_active;
   if(what & ROTATE) {
    if(!fluid_live) draw_selection(xctx->gctiled,0);
    xctx->move_rot= (xctx->move_rot+1) & 0x3;
    update_symbol_bboxes(xctx->move_rot, xctx->move_flip);
   }
   if(what & FLIP)
   {
    if(!fluid_live) draw_selection(xctx->gctiled,0);
    xctx->move_flip = !xctx->move_flip;
    update_symbol_bboxes(xctx->move_rot, xctx->move_flip);
   }
   if((what & (ROTATE | FLIP)) && fluid_live) {
    /* Re-commit NOW: roll back to pristine and fall into the shared commit block via commit_now,
     * which re-applies ROTATION(move_rot,move_flip)+delta and repaints. The END rolls back to
     * pristine and re-applies (total delta + final move_rot/flip), so this extra intermediate
     * commit does NOT change the dropped result (release==stepwise). Mirrors the RUBBER live step. */
    xctx->x2 = xctx->mousex_snap; xctx->y2 = xctx->mousey_snap;
    xctx->deltax = xctx->x2 - xctx->x1; xctx->deltay = xctx->y2 - xctx->y1;
    if(xctx->fluid_reroute_dirty) fluid_reroute_restore();
    commit_now = 1;
   }
  }
  if((what & END) || commit_now)     /* commit the move: real END, or a live fluid RUBBER step */
  {
   int firsti, firstw;
   /* issue 0081: diagonal X-then-Y decomposition (nlegs==2) + P2 safety net (attempt loop).
    * issue 0085: attempt 2 = rigid diagonal relay (leg_ortho / diag_relay), alt_snap holds the
    * ortho attempt-1 result for the never-worse compare. */
   int nlegs = 1, leg, attempt, leg_snapped = 0;
   int leg_ortho, diag_relay = 0, alt_snapped = 0, alt_pchg = 0, saved_ml_lines = 0;
   unsigned int alt_wid = 0, alt_iid = 0, alt_gid = 0, alt_tid = 0;
   double totdx = 0.0, totdy = 0.0;
   Undo_slot leg_snap, alt_snap;
   /* B3 (hardening sprint Track B): gesture-pristine snapshot for the END enforcement backstop.
    * Armed after push_undo (geometry is pristine there) on a fluid stretch with enforcement on;
    * a refused move restores it and drops the undo push. Freed exactly once below. */
   Undo_slot enf_snap;
   int enf_snapped = 0, enf_mod_before = 0;
   int enf_cur = 0, enf_head = 0, enf_tail = 0;   /* pre-push undo counters, to exactly invert the push on refuse */
   int enf_short_base = 0;   /* issue 0123: absolute label-short count at gesture START (pristine) */
   unsigned int enf_wid = 0, enf_iid = 0, enf_gid = 0, enf_tid = 0;

   /* --- END-only pre-commit finalizers; a live fluid RUBBER step (commit_now) skips them and
    * jumps straight to the shared geometry commit below. --- */
   if(!commit_now) {
   int end_was_dirty = xctx->fluid_reroute_active && xctx->fluid_reroute_dirty;
   /* incremental_wire_reroute.md Phase II: on a fluid stretch, RUBBER steps committed intermediate
    * routes into the live geometry. Roll back to the pristine snapshot BEFORE push_undo, so the undo
    * baseline (and capture_undo_ids' object-shape guard) is the true pre-move state, not the last
    * intermediate route; then drop the snapshot. Unconditional on active (a release-only fluid
    * gesture frees its unused snapshot here too), and ABOVE the no-motion early return so a
    * zero-delta release still frees + rolls back. */
   if(xctx->fluid_reroute_active) {
     if(xctx->fluid_reroute_dirty) fluid_reroute_restore();
     fluid_reroute_discard();
   }

   dbg(1, "end move: unlink sel_file\n");
   xunlink(sel_file);
   xctx->paste_from = 0; /* end of a paste from clipboard command */
   if(xctx->connect_by_kissing == 2) xctx->connect_by_kissing = 0;

   /* button released after clicking elements, without moving... do nothing */
   if(xctx->drag_elements && xctx->deltax==0 && xctx->deltay == 0) {
      xctx->ui_state &= ~STARTMOVE;
      /* Clear the stretch scope, like the normal END tail (2321-2323) and ABORT do: this early
       * return skips those, so otherwise stretch_select / stretch_grabbed_xy bleed into the NEXT
       * gesture -- a plain move would then run the stretch cleanup with stale grabbed coords, and
       * (Phase II) the START/RUBBER reroute gates key on stretch_select so a plain move would
       * spuriously reroute. Pre-existing leak on HEAD; closed here as Phase II makes this a
       * first-class path (a fluid drag out and back to the origin snap). */
      xctx->stretch_select = 0;
      xctx->stretch_grabbed_n = 0;
      my_free(_ALLOC_ID_, &xctx->stretch_grabbed_xy);
      xctx->fluid_startsel_nid = 0;                    /* issue 0091: drop the user-selected id set */
      my_free(_ALLOC_ID_, &xctx->fluid_startsel_id);
      /* a dirty fluid drag committed live steps that the roll-back above reverted to pristine --
       * repaint so the stale committed route is cleared from the canvas. */
      if(end_was_dirty) draw();
      return;
   }

   /* no undo push for MERGE ad PLACE, already done before */
   if(!xctx->kissing &&
      !(xctx->ui_state & (START_SYMPIN | STARTMERGE | PLACE_SYMBOL | PLACE_TEXT)) ) {
     /* B3: capture the pre-push undo counters so a refuse can EXACTLY invert this push
      * (restoring all three is correct even when push_undo no-ops under no_undo, or when the
      * ring is saturated and tail advanced -- a plain cur--/head=cur would mis-handle both). */
     int pre_cur = xctx->cur_undo_ptr, pre_head = xctx->head_undo_ptr, pre_tail = xctx->tail_undo_ptr;
     dbg(1, "move_objects(END): push undo state\n");
     xctx->push_undo();
     /* B3: with the undo just pushed and the geometry still PRISTINE (a fluid RUBBER rolled it
      * back at :6294; a scripted release has not applied its delta yet), snapshot for the END
      * enforcement backstop. Gated to a fluid stretch with enforcement on -- a plain/non-fluid
      * move pays nothing. enf_snapped implies this undo push happened, so a refused move may
      * drop it. */
     if(tclgetboolvar("fluid_editing") && tclgetboolvar("fluid_enforce_invariants") &&
        xctx->stretch_select) {
       enf_mod_before = xctx->modified;
       enf_cur = pre_cur; enf_head = pre_head; enf_tail = pre_tail;
       memset(&enf_snap, 0, sizeof(enf_snap));
       mem_snapshot_alloc(&enf_snap); mem_serialize_slot(&enf_snap); enf_snapped = 1;
       enf_wid = xctx->wire_id_counter; enf_iid = xctx->inst_id_counter;
       enf_gid = xctx->gfx_id_counter;  enf_tid = xctx->text_id_counter;
       /* issue 0123: baseline the ABSOLUTE label-short count on the gesture-START (pristine, pre-delta)
        * geometry, so the END gate refuses only on shorts THIS gesture INTRODUCES. A pre-existing
        * naming short on a foreign net (that the move never touches) had been vetoing valid moves. */
       prepare_netlist_structs(0);
       enf_short_base = fluid_count_label_shorts();
     }
   }
   if((xctx->ui_state & PLACE_SYMBOL)) {
     int n = xctx->sel_array[0].n;
     const char *f =  abs_sym_path((xctx->inst[n].ptr+ xctx->sym)->name, "");
     tclvareval("c_toolbar::add {",f, "}; c_toolbar::display", NULL);
   }
   xctx->ui_state &= ~PLACE_SYMBOL;
   xctx->ui_state &= ~PLACE_TEXT;
   if(dx!=0.0 || dy!=0.0) {
     xctx->deltax = dx;
     xctx->deltay = dy;
   }
   } /* end if(!commit_now): END-only pre-commit finalizers */

   /* incremental_wire_reroute.md §10.10 / issue 0081: DIAGONAL fluid stretch decomposition.
    * A diagonal drag (both Dx,Dy != 0) gets NO aesthetic slide/shove -- compute_wire_slide() and
    * fluid_shove_connected_wire() both bail on `dxnz == dynz`, so place_moved_wire relays the pin's
    * follow-wire as a reversed leg through the moving instance's own body (P5) and the escape
    * staircase reappears. Decompose the TOTAL delta into a fixed X-leg then a Y-leg -- each a pure
    * axis move the existing machinery handles -- by running the shared geometry-commit region below
    * TWICE, re-deriving the follow set between legs (move_regrab_follow_set). Fixed X-then-Y (NOT
    * magnitude-derived): the split depends only on the total delta, never on the drag path or a
    * |Dx|==|Dy| crossing, so it is deterministic => release==stepwise (the Phase-II invariant).
    * Gated so nlegs stays 1 (single pass, byte-identical to HEAD) unless a fluid, orthogonal,
    * non-rotating stretch with a TOOL-OWNED-ONLY follow set (fluid_startsel_wires==0 -- the
    * deselect-tail's own gate, so leg A always clears its follow wires for the re-grab) moves
    * diagonally. P1 (connectivity) holds by construction -- the obstacle ml-flip + fluid_reroute_
    * around_obstacles run inside EACH leg. P2 (no-short) is NOT automatic: the obstacle detour only
    * fires on the diagonal SWEEP, so a per-axis leg can lay a stationary-device straddle as a
    * non-pin-incident wire the detour misses (R18 into ammeter v8). It is enforced by the P2 safety
    * net below (the attempt loop) -- decomposition is lowest in the conflict order and must yield to
    * P2. The index-keyed START snapshot is REUSED (never re-taken, which would bake a possibly-
    * shorted intermediate's nets). The region below is left BYTE-FOR-BYTE
    * in place (only wrapped + per-leg delta set) -- the strongest byte-identical guarantee, matching
    * the Phase-II commit_now fall-through discipline; the body indentation is intentionally not
    * re-flowed to keep this a minimal, auditable diff (`git diff -w` shows only the scaffolding). */
   totdx = xctx->deltax; totdy = xctx->deltay;
   if(tclgetboolvar("fluid_editing") && xctx->stretch_select && orthogonal_wiring &&
      xctx->move_rot == 0 && xctx->move_flip == 0 && xctx->fluid_startsel_wires == 0 &&
      totdx != 0.0 && totdy != 0.0) {
     nlegs = 2;
     /* snapshot pristine (current geometry+selection, pre-delta) for the P2 fallback below.
      * mem_snapshot_alloc only sets up the per-layer arrays and ASSUMES a zeroed slot (xctx's own
      * snapshot is calloc'd; this stack slot is not) -- zero it first or serialize free()s garbage. */
     memset(&leg_snap, 0, sizeof(leg_snap));
     mem_snapshot_alloc(&leg_snap); mem_serialize_slot(&leg_snap); leg_snapped = 1;
   }
   /* issue 0102: arm the SAME P2 safety net for a ROTATED/FLIPPED fluid stretch (nlegs stays 1).
    * rot180/270 swap a device's pins so the two follow routes must CROSS -- the elbow hazard picker
    * correctly flags BOTH orientations (one leg plows the rotated sibling pin, the other T-touches
    * that pin's net backbone end) but has no clean L to pick, so attempt 0 can genuinely short
    * (before_7.sch -> after_19.sch: R18.P + C12 merged onto #net1). With the snapshot armed, the
    * existing attempt loop rolls the shorted route back and falls to the rigid diagonal relay:
    * each follow endpoint lands exactly on its rotated pin (0100 pivots) and a true diagonal lays
    * no new elbow copper, so it cannot merge; an AXIS-DEGENERATE relay (dx==0/dy==0 drop keeps
    * anchor+pin collinear) that spans a swapped sibling pin is bent into two diagonals in the
    * commit WIRE case below -- P1/P2 outrank route aesthetics (attempt 1 re-runs the
    * same single ortho pass and fails identically; the flow then arms the relay exactly as the
    * translation path does). A clean rotated route (the 0099/0100 rot90/flip cases) breaks after
    * attempt 0 with zero behavior change. Translation path untouched (requires move_rot||move_flip;
    * the branch above requires their absence). */
   else if(tclgetboolvar("fluid_editing") && xctx->stretch_select && orthogonal_wiring &&
      (xctx->move_rot || xctx->move_flip)) {
     memset(&leg_snap, 0, sizeof(leg_snap));
     mem_snapshot_alloc(&leg_snap); mem_serialize_slot(&leg_snap); leg_snapped = 1;
   }
   /* issue 0109: arm the SAME P2 safety net for a PURE-AXIS fluid stretch (nlegs stays 1).
    * The pure-axis path used to commit sight-unseen (`if(!leg_snapped) break;`): dragging a
    * device ALONG the row holding both follow anchors slides each stub straight through the
    * other net's riser foot and the sibling pin -- a two-contact-point merge no END pass can
    * de-short (short-tail sees only partial improvement and reverts). The push-through slide
    * (fluid_slide_push_through) removes the collision; this snapshot makes it VERIFIED --
    * attempt 1 re-runs the ortho pass with the push-through OFF (exact pre-0109 route),
    * attempt 2 is the rigid relay, and an intentional landing keeps the attempt-1 result as the
    * diagonal path always did. Same gate as the decomposition arm (tool-owned-only follow set);
    * a clean attempt 0 breaks out immediately, so non-shorting drags only pay the snapshot. */
   else if(tclgetboolvar("fluid_editing") && xctx->stretch_select && orthogonal_wiring &&
      xctx->move_rot == 0 && xctx->move_flip == 0 && xctx->fluid_startsel_wires == 0 &&
      (totdx != 0.0 || totdy != 0.0)) {
     memset(&leg_snap, 0, sizeof(leg_snap));
     mem_snapshot_alloc(&leg_snap); mem_serialize_slot(&leg_snap); leg_snapped = 1;
   }
   /* B2 (hardening sprint Track B / WIRING.md risk #2 = issue 0093-D2): arm the SAME P2 safety
    * net for a MIXED-selection rot-free fluid stretch (fluid_startsel_wires > 0 -- the user also
    * selected wire(s) of her own). All three arms above require startsel==0, so a mixed selection
    * used to run the whole attempt-free path and commit sight-unseen (`if(!leg_snapped) break;`):
    * a drag whose follow stubs still stretch (tool-grabbed) but whose push-through slide is
    * disabled (its own gate is startsel==0, compute_wire_slide :1530) re-exposes the pre-0109
    * collinear plow with NO verification. Arming leg_snap makes the attempt ladder VERIFY the
    * composite route (rollback-to-pristine is selection-agnostic) and fall to the diagonal /
    * rigid-relay fallbacks when a mixed drag genuinely shorts; a clean attempt 0 breaks out at
    * once. nlegs stays 1 -- the X-then-Y decomposition and the push-through slide remain
    * tool-owned-only (their gates are unchanged); this adds ONLY the verify+fallback. Whether the
    * fallback can REPAIR a given short is topology-dependent (a pure-axis collinear plow has a
    * degenerate relay and is only REFUSED, by B3); this arm guarantees no mixed short commits
    * unverified. */
   else if(tclgetboolvar("fluid_editing") && xctx->stretch_select && orthogonal_wiring &&
      xctx->move_rot == 0 && xctx->move_flip == 0 && xctx->fluid_startsel_wires > 0 &&
      (totdx != 0.0 || totdy != 0.0)) {
     memset(&leg_snap, 0, sizeof(leg_snap));
     mem_snapshot_alloc(&leg_snap); mem_serialize_slot(&leg_snap); leg_snapped = 1;
   }
   if(what & (RUBBER | END))
     fltrace("FLTRACE move: what=%s%s commit_now=%d totdx=%g totdy=%g fluid=%d stretch=%d ortho=%d rot=%d startsel_w=%d -> nlegs=%d\n",
         (what & END) ? "END" : "", (what & RUBBER) ? "RUBBER" : "", commit_now, totdx, totdy,
         tclgetboolvar("fluid_editing"), xctx->stretch_select, orthogonal_wiring, xctx->move_rot,
         xctx->fluid_startsel_wires, nlegs);
   /* P2 safety net (P1=P2 outrank the decomposition, which is quality-only). attempt 0 runs the
    * nlegs==2 decomposed legs; if they CHANGE CONNECTIVITY the one-shot diagonal pass would not --
    * the obstacle detour (fluid_reroute_around_obstacles) only fires on the diagonal SWEEP, so a
    * per-axis leg can route a wire across a stationary-device straddle (R18 into ammeter v8, a device
    * merge) or through a stationary net LABEL (a foreign-net merge) the detour misses -- attempt 1
    * rolls back to pristine and re-runs as a SINGLE diagonal pass (the proven no-short Layers-1-3
    * path). The trigger is fluid_partition_changed() (the full P1/P2 signal: device merge, net-label
    * merge, AND disconnect), not the two-pin device check alone. A clean two-leg result (partition
    * preserved), or nlegs==1 from the start, breaks after attempt 0. */
   for(attempt = 0; attempt < 3; ++attempt) {
   /* issue 0109: retry attempts run with the push-through slide OFF so a rolled-back promoted
    * route falls back to the exact pre-0109 geometry (then the rigid relay). */
   fluid_g.slide_pushthrough_on = (attempt == 0);
   for(leg = 0; leg < nlegs; ++leg) {
   /* issue 0085: attempt 2 runs the shared region with orthogonal relaying OFF (rigid diagonal
    * relay): place_moved_wire's else-branch just translates the moved endpoint, laying NO new
    * copper and NO elbow that could land on anything -- the true P2 last resort. */
   leg_ortho = diag_relay ? 0 : orthogonal_wiring;
   if(nlegs == 2) {                    /* leg 0 = (Dx,0) X move; leg 1 = (0,Dy) Y move */
     xctx->deltax = (leg == 0) ? totdx : 0.0;
     xctx->deltay = (leg == 0) ? 0.0 : totdy;
     /* issue 0086: expose the REMAINING legs' delta so the leg-0 elbow tie-break can avoid painting
      * a co-moving pin's final landing point (fluid_ml_future_covers). Leg 1 has no remaining leg. */
     fluid_g.leg_future_dx = 0.0;
     fluid_g.leg_future_dy = (leg == 0) ? totdy : 0.0;
   } else {
     fluid_g.leg_future_dx = fluid_g.leg_future_dy = 0.0; /* single-pass attempts: tie-break inert */
   }
   if(what & (RUBBER | END))
     fltrace("FLTRACE move: attempt=%d leg=%d/%d deltax=%g deltay=%g\n", attempt, leg, nlegs,
         xctx->deltax, xctx->deltay);

   /* --- shared geometry commit: byte-for-byte identical for a real END and a fluid RUBBER step.
    * Re-fetch wire/line -- a fluid_reroute_restore() (in the RUBBER branch, or the dirty-END block
    * above) reallocated xctx->wire / xctx->line, so the function-entry captures are stale. --- */
   wire = xctx->wire;
   line = xctx->line;
   /* calculate moving symbols bboxes before actually doing the move */
   firsti = firstw = 1;
   if(!commit_now && leg == 0) draw_selection(xctx->gctiled,0);  /* END: erase last rubber-band (once) */
   update_symbol_bboxes(0, 0);
   /* corner-slide rubber-band (wire-editing Phase 4): on an orthogonal, axis-aligned,
    * non-rotating move, let perpendicular attached wires forming a corner SLIDE with
    * the pin instead of jogging at the moved end. Modifies/propagates the wire
    * selection and rebuilds sel_array, so it must run before the commit loop. */
   if(leg_ortho && xctx->move_rot == 0 && xctx->move_flip == 0 &&
      ((xctx->deltax != 0.0) != (xctx->deltay != 0.0))) {
     compute_wire_slide();
   }
   for(k=0;k<cadlayers; ++k)
   {
    for(i=0;i<xctx->lastsel; ++i)
    {
     c = xctx->sel_array[i].col;n = xctx->sel_array[i].n;
     switch(xctx->sel_array[i].type)
     {
      case WIRE:
       xctx->prep_hash_wires=0;
       firstw = 0;
       if(k == 0) {
         /* Rotate ONLY the endpoint(s) that follow the move. A partial-select follow-wire
          * (SELECTED1 xor SELECTED2) has one endpoint on a moving pin and the other anchored
          * to a stationary object: rotating the anchored endpoint about the pivot would tear
          * it off that object, so a rotating stretch must leave it at its pristine coordinate
          * and let place_moved_wire() bend an L to the moved pin. The moving endpoint sits on
          * the pin, and rigid rotation-about-pivot moves body+pins together, so
          * ROTATION(pivot,endpoint)+delta lands it exactly on the pin's new position (crux (a),
          * doc/claude/specs/rotate_keep_connected_stretch.md).
          * For move_rot==0 && move_flip==0 ROTATION() is the identity, so a non-selected
          * endpoint keeps its literal coords either way -- this is BYTE-IDENTICAL to the old
          * "rotate both, translate the selected one" form on the pure-translation path, and a
          * fully SELECTED wire (both bits) still rotates+translates both endpoints rigidly. */
         double wpx, wpy; /* rotation pivot for this wire */
         if(xctx->rotatelocal) { wpx = wire[n].x1; wpy = wire[n].y1; }
         else                  { wpx = xctx->x1;   wpy = xctx->y1;   }
         /* issue 0100: ALT-R/ALT-F mid-stretch are ROTATE|ROTATELOCAL (callback.c:5100/:4592): the
          * ELEMENT commit below rotates each instance about ITS OWN origin, so a partial-selected
          * follow wire rotated about the WIRE's own (x1,y1) lands its moving endpoint off the pin --
          * a P1 tear-off (before_7.sch -> after_18.sch: both R18 pins on fresh nets). Use the pivot
          * of the selected instance whose PRISTINE pin the moving endpoint sits on: the pin moves by
          * ROTATION(inst origin)+delta, so the endpoint lands ON it by construction. Instances are
          * still pristine here (the ELEMENT loop runs after this one). No owning pin found (the
          * endpoint follows a selected wire, not a pin) => old per-wire pivot, unchanged. Gated to
          * the fluid stretch => byte-identical everywhere else. */
         if(xctx->rotatelocal && (xctx->move_rot || xctx->move_flip) &&
            xctx->stretch_select && tclgetboolvar("fluid_editing") &&
            (wire[n].sel == SELECTED1 || wire[n].sel == SELECTED2)) {
           double mvx = (wire[n].sel == SELECTED1) ? wire[n].x1 : wire[n].x2;
           double mvy = (wire[n].sel == SELECTED1) ? wire[n].y1 : wire[n].y2;
           int j, p, np, ii, found = 0;
           for(j = 0; j < xctx->lastsel && !found; ++j) {
             if(xctx->sel_array[j].type != ELEMENT) continue;
             ii = xctx->sel_array[j].n;
             if(xctx->inst[ii].ptr < 0) continue;
             np = (xctx->inst[ii].ptr + xctx->sym)->rects[PINLAYER];
             for(p = 0; p < np; ++p) {
               double px, py;
               get_inst_pin_coord(ii, p, &px, &py);
               if(px == mvx && py == mvy) {
                 wpx = xctx->inst[ii].x0; wpy = xctx->inst[ii].y0;
                 found = 1;
                 break;
               }
             }
           }
         }
         if( wire[n].sel & (SELECTED|SELECTED1) ) {
           ROTATION(xctx->move_rot, xctx->move_flip, wpx, wpy,
              wire[n].x1, wire[n].y1, xctx->rx1,xctx->ry1);
           xctx->rx1+=xctx->deltax;
           xctx->ry1+=xctx->deltay;
         } else {
           xctx->rx1 = wire[n].x1; xctx->ry1 = wire[n].y1; /* anchored: pristine, not rotated */
         }
         if( wire[n].sel & (SELECTED|SELECTED2) ) {
           ROTATION(xctx->move_rot, xctx->move_flip, wpx, wpy,
              wire[n].x2, wire[n].y2, xctx->rx2,xctx->ry2);
           xctx->rx2+=xctx->deltax;
           xctx->ry2+=xctx->deltay;
         } else {
           xctx->rx2 = wire[n].x2; xctx->ry2 = wire[n].y2; /* anchored: pristine, not rotated */
         }

         /* issue 0100: hand the PRISTINE moving-endpoint coords to fluid_ml_hazards -- exact under
          * ANY pivot (see the statics' comment). wire[n] is still pristine here (place_moved_wire
          * writes it). Cleared right after so no other caller sees stale data. */
         {
         int fluid_partial = (wire[n].sel == SELECTED1 || wire[n].sel == SELECTED2);
         if((xctx->move_rot || xctx->move_flip) && fluid_partial) {
           fluid_g.stretch_premove_x = (wire[n].sel == SELECTED1) ? wire[n].x1 : wire[n].x2;
           fluid_g.stretch_premove_y = (wire[n].sel == SELECTED1) ? wire[n].y1 : wire[n].y2;
           fluid_g.stretch_premove_valid = 1;
         }
         place_moved_wire(n, leg_ortho);
         fluid_g.stretch_premove_valid = 0;
         /* place_moved_wire() -> storeobject() may my_realloc(xctx->wire), leaving the loop-local
          * `wire` alias dangling. Refresh it so a LATER sel_array WIRE entry (e.g. the second of a
          * two-follow-wire fluid drag -- R18's M and P risers) does not read freed memory. This
          * pre-existing k-loop staleness was previously latent (only single-follow-wire stretches
          * were exercised); test_wireedit_34 exposes it. (line[] is untouched by place_moved_wire.) */
         wire = xctx->wire;
         /* issue 0102 (review wf_49325abb F2): an AXIS-DEGENERATE rigid-relay wire -- a dx==0 (or
          * dy==0) drop keeps the anchor and the rotated pin collinear (rot180 in-place: everything
          * stays on the fixture's single column) -- can SPAN the swapped sibling pin; pin-on-span
          * merges, every attempt stays dirty, and the never-worse fallback kept the shorted ortho
          * route. When a pin actually lies strictly INSIDE the relayed span (moving pins tested at
          * their rotatelocal-aware post-move position), bend the wire at an off-axis midpoint into
          * two true diagonals, which cannot pin-on-span. The attempt-loop partition check remains
          * the arbiter: a dirty bend is rolled back exactly like any dirty attempt => never worse. */
         if(fluid_partial && diag_relay && (xctx->move_rot || xctx->move_flip) &&
            xctx->stretch_select && tclgetboolvar("fluid_editing")) {
           double wx1 = wire[n].x1, wy1 = wire[n].y1, wx2 = wire[n].x2, wy2 = wire[n].y2;
           if((wx1 == wx2) != (wy1 == wy2)) {           /* axis-aligned, non-degenerate-point */
             int ii, p, np, covered = 0;
             for(ii = 0; ii < xctx->instances && !covered; ++ii) {
               if(xctx->inst[ii].ptr < 0) continue;
               np = (xctx->inst[ii].ptr + xctx->sym)->rects[PINLAYER];
               for(p = 0; p < np; ++p) {
                 double px, py;
                 get_inst_pin_coord(ii, p, &px, &py);
                 if(xctx->inst[ii].sel) {               /* co-moving: rotatelocal-aware post-move */
                   double rpx, rpy;
                   double pvx = xctx->rotatelocal ? xctx->inst[ii].x0 : xctx->x1;
                   double pvy = xctx->rotatelocal ? xctx->inst[ii].y0 : xctx->y1;
                   ROTATION(xctx->move_rot, xctx->move_flip, pvx, pvy, px, py, rpx, rpy);
                   px = rpx + xctx->deltax; py = rpy + xctx->deltay;
                 }
                 if(wx1 == wx2) {
                   if(px == wx1 && py > (wy1 < wy2 ? wy1 : wy2) && py < (wy1 < wy2 ? wy2 : wy1))
                     covered = 1;
                 } else {
                   if(py == wy1 && px > (wx1 < wx2 ? wx1 : wx2) && px < (wx1 < wx2 ? wx2 : wx1))
                     covered = 1;
                 }
                 if(covered) break;
               }
             }
             if(covered) {
               double gr = tclgetdoublevar("cadsnap");
               double mxp, myp;
               if(gr <= 0.0) gr = 10.0;
               if(wx1 == wx2) {
                 myp = floor((wy1 + wy2) / (2.0 * gr) + 0.5) * gr;
                 mxp = wx1 + gr;
               } else {
                 mxp = floor((wx1 + wx2) / (2.0 * gr) + 0.5) * gr;
                 myp = wy1 + gr;
               }
               wire[n].x2 = mxp; wire[n].y2 = myp;      /* first half: (x1,y1)-(mid) */
               order_wire_points(n);
               storeobject(-1, mxp, myp, wx2, wy2, WIRE, 0, 0, wire[n].prop_ptr);
               wire = xctx->wire;                       /* storeobject may realloc */
               /* order the new half too -- hash/pin-attach assume ordered endpoints (an unordered
                * diagonal resolves in the wire graph but misses the instance-pin attach: pin ends
                * on a fresh #net while the wire chain stays intact). */
               order_wire_points(xctx->wires - 1);
             }
           }
         }
         }

       }
       break;

      case LINE:
       if(c!=k) break;
       if(xctx->rotatelocal) {
         ROTATION(xctx->move_rot, xctx->move_flip, line[c][n].x1, line[c][n].y1,
            line[c][n].x1, line[c][n].y1, xctx->rx1,xctx->ry1);
         ROTATION(xctx->move_rot, xctx->move_flip, line[c][n].x1, line[c][n].y1,
            line[c][n].x2, line[c][n].y2, xctx->rx2,xctx->ry2);
       } else {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            line[c][n].x1, line[c][n].y1, xctx->rx1,xctx->ry1);
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            line[c][n].x2, line[c][n].y2, xctx->rx2,xctx->ry2);
       }

       if( line[c][n].sel & (SELECTED|SELECTED1) )
       {
        xctx->rx1+=xctx->deltax;
        xctx->ry1+=xctx->deltay;
       }
       if( line[c][n].sel & (SELECTED|SELECTED2) )
       {
        xctx->rx2+=xctx->deltax;
        xctx->ry2+=xctx->deltay;
       }
       line[c][n].x1=xctx->rx1;
       line[c][n].y1=xctx->ry1;
       ORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
       if( line[c][n].x1 == xctx->rx2 &&  line[c][n].y1 == xctx->ry2)
       {
        if(line[c][n].sel == SELECTED1) line[c][n].sel = SELECTED2;
        else if(line[c][n].sel == SELECTED2) line[c][n].sel = SELECTED1;
       }
       line[c][n].x1=xctx->rx1;
       line[c][n].y1=xctx->ry1;
       line[c][n].x2=xctx->rx2;
       line[c][n].y2=xctx->ry2;
       break;

      case POLYGON:
       if(c!=k) break;
       {
         xPoly *p = &xctx->poly[c][n];
         double bx1=0., by1=0., bx2=0., by2=0.;
         int j;
         double savex0, savey0;
         savex0 = p->x[0];
         savey0 = p->y[0];
         for(j=0; j<p->points; ++j) {
           if(j==0 || p->x[j] < bx1) bx1 = p->x[j];
           if(j==0 || p->y[j] < by1) by1 = p->y[j];
           if(j==0 || p->x[j] > bx2) bx2 = p->x[j];
           if(j==0 || p->y[j] > by2) by2 = p->y[j];

           if( p->sel==SELECTED || p->selected_point[j]) {
             if(xctx->rotatelocal) {
               ROTATION(xctx->move_rot, xctx->move_flip, savex0, savey0, p->x[j], p->y[j],
                        xctx->rx1,xctx->ry1);
             } else {
               ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1, p->x[j], p->y[j],
                        xctx->rx1,xctx->ry1);
             }

             p->x[j] =  xctx->rx1+xctx->deltax;
             p->y[j] =  xctx->ry1+xctx->deltay;
           }
         }
         for(j=0; j<p->points; ++j) {
           if(j==0 || p->x[j] < bx1) bx1 = p->x[j];
           if(j==0 || p->y[j] < by1) by1 = p->y[j];
           if(j==0 || p->x[j] > bx2) bx2 = p->x[j];
           if(j==0 || p->y[j] > by2) by2 = p->y[j];
         }
       }
       break;

      case ARC:
       if(c!=k) break;
       if(xctx->rotatelocal) {
         /* rotate center wrt itself: do nothing */
         xctx->rx1 = xctx->arc[c][n].x;
         xctx->ry1 = xctx->arc[c][n].y;
       } else {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            xctx->arc[c][n].x, xctx->arc[c][n].y, xctx->rx1,xctx->ry1);
       }
       angle = xctx->arc[c][n].a;
       if(xctx->move_flip) {
         angle = 270.*xctx->move_rot+180.-xctx->arc[c][n].b-xctx->arc[c][n].a;
       } else {
         angle = xctx->arc[c][n].a+xctx->move_rot*270.;
       }
       angle = fmod(angle, 360.);
       if(angle<0.) angle+=360.;
       if(xctx->arc[c][n].sel == SELECTED) {
         xctx->arc[c][n].x = xctx->rx1+xctx->deltax;
         xctx->arc[c][n].y = xctx->ry1+xctx->deltay;
         xctx->arc[c][n].a = angle;
       } else if(xctx->arc[c][n].sel == SELECTED1) {
         xctx->arc[c][n].x = xctx->rx1;
         xctx->arc[c][n].y = xctx->ry1;
         if(xctx->arc[c][n].r+xctx->deltax) xctx->arc[c][n].r = fabs(xctx->arc[c][n].r+xctx->deltax);
         xctx->arc[c][n].a = angle;
       } else if(xctx->arc[c][n].sel == SELECTED2) {
         angle = my_round(fmod(atan2(-xctx->deltay, xctx->deltax)*180./XSCH_PI+angle, 360.));
         if(angle<0.) angle +=360.;
         xctx->arc[c][n].x = xctx->rx1;
         xctx->arc[c][n].y = xctx->ry1;
         xctx->arc[c][n].a = angle;
       } else if(xctx->arc[c][n].sel==SELECTED3) {
         angle = my_round(fmod(atan2(-xctx->deltay, xctx->deltax)*180./XSCH_PI+xctx->arc[c][n].b, 360.));
         if(angle<0.) angle +=360.;
         if(angle==0) angle=360.;
         xctx->arc[c][n].x = xctx->rx1;
         xctx->arc[c][n].y = xctx->ry1;
         xctx->arc[c][n].b = angle;
       }

       break;

      case xRECT:
       if(c!=k) break;
       /* bbox before move */
       if(xctx->rotatelocal) {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
           xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
           xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
       } else {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
       }

       flip_rotate_ellipse(&xctx->rect[c][n], xctx->move_rot, xctx->move_flip);

       if( xctx->rect[c][n].sel == SELECTED) {
         xctx->rx1+=xctx->deltax;
         xctx->ry1+=xctx->deltay;
         xctx->rx2+=xctx->deltax;
         xctx->ry2+=xctx->deltay;
       }
       else if( xctx->rect[c][n].sel == SELECTED1) {   /* 20070302 stretching on rectangles */
         xctx->rx1+=xctx->deltax;
         xctx->ry1+=xctx->deltay;
       }
       else if( xctx->rect[c][n].sel == SELECTED2) {
         xctx->rx2+=xctx->deltax;
         xctx->ry1+=xctx->deltay;
       }
       else if( xctx->rect[c][n].sel == SELECTED3) {
         xctx->rx1+=xctx->deltax;
         xctx->ry2+=xctx->deltay;
       }
       else if( xctx->rect[c][n].sel == SELECTED4) {
         xctx->rx2+=xctx->deltax;
         xctx->ry2+=xctx->deltay;
       }
       else if(xctx->rect[c][n].sel==(SELECTED1|SELECTED2))
       {
         xctx->ry1+=xctx->deltay;
       }
       else if(xctx->rect[c][n].sel==(SELECTED3|SELECTED4))
       {
         xctx->ry2+=xctx->deltay;
       }
       else if(xctx->rect[c][n].sel==(SELECTED1|SELECTED3))
       {
         xctx->rx1+=xctx->deltax;
       }
       else if(xctx->rect[c][n].sel==(SELECTED2|SELECTED4))
       {
         xctx->rx2+=xctx->deltax;
       }

       tx1 = xctx->rx1;
       ty1 = xctx->ry1;
       RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);

       if( xctx->rx2 == tx1) {
         if(xctx->rect[c][n].sel==SELECTED1) xctx->rect[c][n].sel = SELECTED2;
         else if(xctx->rect[c][n].sel==SELECTED2) xctx->rect[c][n].sel = SELECTED1;
         else if(xctx->rect[c][n].sel==SELECTED3) xctx->rect[c][n].sel = SELECTED4;
         else if(xctx->rect[c][n].sel==SELECTED4) xctx->rect[c][n].sel = SELECTED3;
       }
       if( xctx->ry2 == ty1) {
         if(xctx->rect[c][n].sel==SELECTED1) xctx->rect[c][n].sel = SELECTED3;
         else if(xctx->rect[c][n].sel==SELECTED3) xctx->rect[c][n].sel = SELECTED1;
         else if(xctx->rect[c][n].sel==SELECTED2) xctx->rect[c][n].sel = SELECTED4;
         else if(xctx->rect[c][n].sel==SELECTED4) xctx->rect[c][n].sel = SELECTED2;
       }

       xctx->rect[c][n].x1 = xctx->rx1;
       xctx->rect[c][n].y1 = xctx->ry1;
       xctx->rect[c][n].x2 = xctx->rx2;
       xctx->rect[c][n].y2 = xctx->ry2;

       /* bbox after move */
       break;

      case xTEXT:
       if(k!=TEXTLAYER) break;
       #if HAS_CAIRO==1  /* bbox before move */
       customfont = set_text_custom_font(&xctx->text[n]);
       #endif
       estr = my_expand(get_text_floater(n), tclgetintvar("tabstop"));
       text_bbox(estr, xctx->text[n].xscale,
          xctx->text[n].yscale, xctx->text[n].rot,xctx->text[n].flip, xctx->text[n].hcenter,
          xctx->text[n].vcenter, xctx->text[n].x0, xctx->text[n].y0,
          &xctx->rx1,&xctx->ry1, &xctx->rx2,&xctx->ry2, &tmpint, &dtmp);
       my_free(_ALLOC_ID_, &estr);
       #if HAS_CAIRO==1
       if(customfont) {
         cairo_restore(xctx->cairo_ctx);
       }
       #endif
       if(xctx->rotatelocal) {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->text[n].x0, xctx->text[n].y0,
           xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
       } else {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
       }
       xctx->text[n].x0=xctx->rx1+xctx->deltax;
       xctx->text[n].y0=xctx->ry1+xctx->deltay;
       xctx->text[n].rot=(xctx->text[n].rot +
        ( (xctx->move_flip && (xctx->text[n].rot & 1) ) ? xctx->move_rot+2 : xctx->move_rot) ) & 0x3;
       xctx->text[n].flip=xctx->move_flip^xctx->text[n].flip;

       #if HAS_CAIRO==1  /* bbox after move */
       customfont = set_text_custom_font(&xctx->text[n]);
       #endif
       estr = my_expand(get_text_floater(n), tclgetintvar("tabstop"));
       text_bbox(estr, xctx->text[n].xscale,
          xctx->text[n].yscale, xctx->text[n].rot,xctx->text[n].flip, xctx->text[n].hcenter,
          xctx->text[n].vcenter, xctx->text[n].x0, xctx->text[n].y0,
          &xctx->rx1,&xctx->ry1, &xctx->rx2,&xctx->ry2, &tmpint, &dtmp);
       my_free(_ALLOC_ID_, &estr);
       #if HAS_CAIRO==1
       if(customfont) {
         cairo_restore(xctx->cairo_ctx);
       }
       #endif

       break;

      default:
       break;
     } /* end switch(xctx->sel_array[i].type) */
    } /* end for(i=0;i<xctx->lastsel; ++i) */
   } /*end for(k=0;k<cadlayers; ++k) */

   for(i = 0; i < xctx->lastsel; ++i) {
     n = xctx->sel_array[i].n;
     if(xctx->sel_array[i].type == ELEMENT) {
       xctx->prep_hash_inst=0;
       firsti = 0;
       if(xctx->rotatelocal) {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->inst[n].x0, xctx->inst[n].y0,
            xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
       } else {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
       }
       xctx->inst[n].x0 = xctx->rx1+xctx->deltax;
       xctx->inst[n].y0 = xctx->ry1+xctx->deltay;
       xctx->inst[n].rot = (xctx->inst[n].rot +
        ( (xctx->move_flip && (xctx->inst[n].rot & 1) ) ? xctx->move_rot+2 : xctx->move_rot) ) & 0x3;
       xctx->inst[n].flip = xctx->move_flip ^ xctx->inst[n].flip;
       symbol_bbox(n,
          &xctx->inst[n].x1, &xctx->inst[n].y1,
          &xctx->inst[n].x2, &xctx->inst[n].y2);
     }
   }
   if(!firsti || !firstw) {
     xctx->prep_net_structs=0;
     xctx->prep_hi_structs=0;
   }
   /* incremental_wire_reroute.md Layer 2 (spec sec 5/6): pre-trim rip-up-and-reroute detour. When
    * both L orientations were blocked (place_moved_wire could not flip away the short) the naive
    * route still lays a leg straight across a stationary device between two of its distinct-net pins.
    * Re-detect that residual straddle and route the moving pin AROUND the device with a stop-short
    * junction. Runs on the SAME shared commit block as a real END and a live fluid RUBBER step, so
    * release == stepwise for free. Gated identically to the Layer-1 flip; default off => byte-
    * identical (the whole function early-returns without a fluid START name snapshot). Placed before
    * check_collapsing_objects/trim so the existing cleanup normalises the new geometry once. */
   if(tclgetboolvar("fluid_editing") && xctx->stretch_select &&
      xctx->move_rot == 0 && xctx->move_flip == 0) {
     /* issue 0015 §7: shove a connected wire the moving pin drove past (serves P5), THEN the obstacle
      * layer gets the last word on P2 for anything with a moving-pin endpoint. */
     fluid_shove_connected_wire(leg_ortho);
     fluid_reroute_around_obstacles(leg_ortho);
     /* issue 0083: a NO-SHORT foreign-pin landing buries the offset solder-joint + grazes the body.
      * Restore the V-H-V + visible offset dot. Gated to a PURE-AXIS delta (one of deltax/deltay zero).
      * That fires it for a genuine pure-axis nlegs==1 move AND for EACH leg of the 0081 diagonal
      * decomposition (leg 0 = the pure-X move, leg 1 = the pure-Y move) -- so a diagonal drag that lands
      * the riser in the body is offset on its X leg, then the Y leg re-grabs the now-offset (outside-body)
      * riser and declines. A genuine diagonal delta (the 0081 P2 single-pass fallback, or a pre-selected
      * follow wire keeping nlegs==1) leaves BOTH nonzero -> does NOT fire (that single diagonal pass is
      * fluid_reroute's job, not this one). The internal guards + the same-net-only rule keep every firing
      * decline-to-baseline safe regardless (adversarial reviews wf_3029984d / wf_e96154bf). */
     fltrace("FLTRACE offset-call: deltax=%g deltay=%g pure_axis_gate=%d\n",
             xctx->deltax, xctx->deltay, (xctx->deltax == 0.0 || xctx->deltay == 0.0));
     if(xctx->deltax == 0.0 || xctx->deltay == 0.0)
       fluid_offset_foreign_pin_landing(leg_ortho);
   } else if(what & (RUBBER | END)) {
     fltrace("FLTRACE fluid-block: SKIPPED (fluid=%d stretch=%d rot=%d flip=%d)\n",
             tclgetboolvar("fluid_editing"), xctx->stretch_select, xctx->move_rot, xctx->move_flip);
   }
   /* build after copying and after recalculating prepare_netlist_structs() */
   check_collapsing_objects();
   /* Release-time cleanup (wire-editing Phase 5, Issue D3). On a STRETCH move the
    * rubber-band can leave redundant routing. Run it for stretch moves even when
    * autotrim_wires is off (the cadence rubber-band feel shouldn't depend on that
    * preference). Order matters:
    *   1. trim_wires() first: merge colinear degree-2 fragments (TC7) and drop
    *      included/overlapping duplicates (TC8);
    *   2. remove_move_orphan_wires() on the cleaned geometry: drop redundant dangling
    *      stubs this move produced (TC9). It must see post-trim geometry, else an
    *      overlapping colinear pair would look like a stub-on-a-wire. */
   /* W3: when autotrim is on a stretch/move can create or remove an attachment, so run the
    * full re-split/rejoin (maintain). When autotrim is OFF, a stretch still needs the plain
    * trim cleanup (merge colinear degree-2 fragments, drop dups) but must NOT split at pins
    * (D2 -- default users get no auto-split). See doc/claude/specs/wire_segment_splitting.md. */
   if(tclgetboolvar("autotrim_wires")) maintain_wire_segments();
   else if(xctx->stretch_select) trim_wires();
   if(xctx->stretch_select) remove_move_orphan_wires();
   /* ---- END cleanup cluster (WIRING §3 step 9), driven by the Track-D (D3) pass table
    * fluid_end_passes[] above: array order = execution order; each entry carries its issue
    * history, gates, verify direction and mutation class. END-only (!commit_now): deleting or
    * reshaping follow copper mid-drag could destabilise the next RUBBER step's follow set; the
    * user's complaint is the SAVED result, which END owns (issue 0088). NOT wholesale-gated on
    * fluid_startsel_wires==0 (issue 0091,
    * doc/claude/issues/0091-fluid-reroute-samenet-crosses-moved-body.md): the cluster runs
    * whenever a fluid stretch could have made redundant copper; the prot[]-consulting passes
    * (loops, straighten) decline PER-COMPONENT (fluid_mark_user_protected floods every
    * user-selected wire's touch-component -- "selection wins" per net, not wholesale) and the
    * rest carry their own scope gates (overshoot is deliberately NOT prot[]-gated -- see the
    * entries). Default fluid_editing off => never runs => byte-identical. */
   if(!commit_now && tclgetboolvar("fluid_editing") && xctx->stretch_select &&
      leg_ortho && leg == nlegs - 1) {
     /* issue 0098 facet B (ALT-R during 'm'): the DE-SHORT passes (ripup foreign-pin short + its
      * 0098 route-around jog, the 0104 shorting-anchor-tail prune) only commit a change that
      * RESTORES the START pin-partition, and the delete-only loop remover verifies each doom
      * against its pass-entry partition -- so all of them run under a rotated / flipped stretch
      * too; their guards are geometric, not rotation-dependent. rotfree drives only the entries
      * carrying a ROTFREE_ONLY / ROTATED_ONLY gate bit. */
     int rotfree = (xctx->move_rot == 0 && xctx->move_flip == 0);
     int ripped = 0;
     int pi;
     int npasses = (int)(sizeof(fluid_end_passes) / sizeof(fluid_end_passes[0]));
     int traced = fluid_trace_on();     /* D4: all observability is trace-only (byte-identical off) */
     fluid_dump_wires("cluster entry");
     for(pi = 0; pi < npasses; ++pi) {
       const Fluid_pass *p = &fluid_end_passes[pi];
       /* Single source of truth for skip vs run AND the trace label -- MANUAL_SITE (exit stubs /
        * manhattanize, called at their own sites) + END_ONLY/ORTHO/FINAL_LEG (guaranteed by the
        * enclosing gate, re-checked so the table bits are executable contract) + the per-pass bits
        * (ROTFREE_ONLY/ROTATED_ONLY == old if(!rotfree); NEEDS_RIPPED == old if(ripped)). */
       const char *skip = fluid_pass_skip_gate(p, commit_now, leg_ortho, leg, nlegs, rotfree, ripped);
       if(skip) {
         if(traced) fltrace("FLTRACE pass %s: SKIP(%s)\n", p->name, skip);
         continue;
       }
       if(!traced) {                    /* fast path -- no snapshot/count when tracing is off */
         if(p->gates & FLUID_PASS_SETS_RIPPED) ripped = p->fn();
         else p->fn();
       } else {                         /* D4: measure changed=N across the pass, keyed by wire id */
         int nb = 0, na = 0, changed;
         Fluid_wsig *before = fluid_wsig_snapshot(&nb), *after;
         if(p->gates & FLUID_PASS_SETS_RIPPED) ripped = p->fn();
         else p->fn();
         after = fluid_wsig_snapshot(&na);
         changed = fluid_wsig_diff(before, nb, after, na);
         fltrace("FLTRACE pass %s: ran, changed=%d (rotfree=%d ripped=%d wires %d->%d)\n",
                 p->name, changed, rotfree, ripped, nb, na);
         if(before) my_free(_ALLOC_ID_, &before);
         if(after)  my_free(_ALLOC_ID_, &after);
         fluid_dump_wires(p->name);
       }
     }
   }
   /* Exit-stub preservation (wire-editing Phase 6, Issue E -> R13). After the cleanup above,
    * ensure each moved DEVICE pin's route leaves the pin along the pin's outward escape normal
    * (get_pin_escape_normal, geometry nearest-edge -- nice_drag_rerouting Phase 3 §6/§8) with a
    * short stub before the first bend. Runs AFTER trim_wires() so the stub is never merged
    * back. Gated on wire_exit_stub || fluid_editing (both default OFF) => byte-identical when
    * off. The fluid gate was previously DEFERRED because insert_exit_stubs disconnected a net
    * on a plain fluid drag (a -x/-y escape stub stored unordered -> touch() failed to bind the
    * pin, caught by the Phase-1 P1 guard). order_wire_coords() now normalizes every wire the
    * function writes, closing that (endpoint-ordering) disconnect class, so the fluid gate is
    * enabled. P1/connectivity is preserved for the tap cases too: a pin tap on the slid leg is
    * skipped by the point_on_fixed_pin guard, and a wire tap is a split junction the has_corner
    * neighbour-drag carries along (tests test_wireedit_29..31). NOT yet handled: the SLIDE can
    * still shift the leg/stub one grid onto a DIFFERENT net's wire -> a no-short (P2) hazard,
    * which is nice_drag_rerouting Phase 4 (no-short guard + rip-up) and is caught log-only by
    * fluid_check_move_invariants until then. See doc/claude/specs/nice_drag_rerouting.md. */
   /* issue 0086: FINAL leg only (leg == nlegs-1; unchanged for single-pass moves, nlegs==1). The
    * P3 exit stub is a final-state aesthetic: inserted at a leg-0 (intermediate) pin position it
    * plants a stub anchored INSIDE the later leg's stretch corridor (before_3.sch, R18 (+150,-80):
    * the (-250,-80)..(-250,-70) stub), and leg 1's follow stretch from that anchor is a degenerate
    * straight run across the other pin's landing -- a guaranteed short no elbow can avoid. The
    * final leg re-inserts stubs at the true (post-move) pin positions, so the P3 look is intact. */
   /* issue 0111 ORDERING INVARIANT: insert_exit_stubs must run AFTER the straighteners above
    * and nothing that collapses jogs may run after it -- a P3 stub is itself a straighten-
    * collapsible jog unit, so a later collapse pass would undo every stub (or oscillate).
    * The converse antagonism (straighten collapsing a jog onto a pin, this pass re-jogging
    * it one grid back off -- a round trip that used to re-create the saved staircase of
    * after_28.sch) is resolved INSIDE straighten: a pin-landing near target defers to the
    * far target, else collapses to one grid short of the pin, so no leg ever lands ON a
    * moved pin for this pass to re-jog. */
   if(xctx->stretch_select &&
      (tclgetboolvar("wire_exit_stub") || tclgetboolvar("fluid_editing")) && leg_ortho &&
      xctx->move_rot == 0 && xctx->move_flip == 0 && leg == nlegs - 1) {
     insert_exit_stubs();
     /* insert_exit_stubs stores a stub pin->tip and drags corner neighbours but does NOT trim; when a
      * follow-wire already lands exactly on the stationary partner pin along its normal (the tidy route
      * a staircase collapse produces) the slid/dragged leg can degenerate to a zero-length wire at that
      * pin. Nothing runs trim after this point, so sweep the residue here. No-op (byte-identical) when the
      * stub pass created none, e.g. the wire_exit_stub regression path. */
     check_collapsing_objects();
   }
   /* D5 idempotence oracle round 2 (off by default; tests set FLUID_IDEMPOTENT_CHECK=1). Placed
    * HERE -- after both the cluster and insert_exit_stubs -- so re-running the cluster sees the
    * finalized route and catches CROSS-pass oscillation (0111 straighten<->exit-stub). Same gate
    * as the cluster block above, so round 2 runs exactly when round 1 did. Correct build => strict
    * no-op (finalization is a fixpoint) => byte-identical; a broken build gets a loud named
    * violation. Runs before unselect_partial_sel_wires so the passes see the cluster's own
    * selection state. */
   if(fluid_idempotent_check_on() && !commit_now && tclgetboolvar("fluid_editing") &&
      xctx->stretch_select && leg_ortho && leg == nlegs - 1) {
     int rotfree = (xctx->move_rot == 0 && xctx->move_flip == 0);
     fluid_end_cluster_idempotence_probe(commit_now, leg_ortho, leg, nlegs, rotfree);
   }
   unselect_partial_sel_wires();
   /* incremental_wire_reroute Phase I (ownership decoupling, spec §4). A fluid stretch grabs the
    * wires attached to the moving selection into the SELECTION (select_attached_nets marks them
    * SELECTED1/2; compute_wire_slide promotes corner wires to full SELECTED), so with the cadence
    * default unselect_partial_sel_wires=0 they PERSIST as user selection after the drag -- the
    * user's complaint ("wires get selected when I only move an instance"). When the user selected
    * NO wires of her own (fluid_startsel_wires==0), every wire selected at END is a tool-owned
    * follow-wire: deselect them all so they are transient, not persistent user selection. This runs
    * AFTER all reroute/cleanup, touching only sel-flags => wire GEOMETRY is byte-identical (the
    * route is unchanged; Phase I is bookkeeping only). Gated on fluid_editing => default off is
    * byte-identical. */
   if(tclgetboolvar("fluid_editing") && xctx->stretch_select && xctx->fluid_startsel_wires == 0) {
     int wi, any = 0;
     /* direct clear (not select_wire(...,0,...)): a wire grabbed at BOTH ends is sel==
      * (SELECTED1|SELECTED2), which select_wire would fold to SELECTED instead of deselecting
      * (select.c:965). The following draw() repaints, so the un-highlight is handled there. */
     for(wi = 0; wi < xctx->wires; ++wi) if(xctx->wire[wi].sel) { xctx->wire[wi].sel = 0; any = 1; }
     if(any) { xctx->need_reb_sel_arr = 1; rebuild_selected_array(); }
   }
   /* issue 0093: the mixed case (user also selected wires, fluid_startsel_wires>0). Previously we
    * "stood down" and left the selection AS THE STRETCH LEFT IT -- but a fluid stretch relays the
    * user's own grabbed wire to a PARTIAL state (SELECTED1/2), and with the cadence default
    * unselect_partial_sel_wires=0 that partial selection PERSISTS. On the NEXT gesture, an
    * already-selected press skips the fresh select_object(), so select_attached_nets() sees the
    * wire as SELECTED2 (not full SELECTED) and its `!= SELECTED` guard (select.c) SKIPS grabbing the
    * connected follow-risers -- the wire then translates ALONE, orphaning a load-bearing riser, and
    * fluid_straighten_reversals deletes the orphan => the net silently DISCONNECTS
    * (tests/from_user/before_6.sch -> after_13.sch, R18.M dropped off #net1). Fix: normalize the
    * post-stretch selection -- restore the USER's OWN wires (identified by the 0091 session-stable id
    * snapshot, preserved across the in-place relay) to FULL SELECTED, and deselect every tool-owned
    * follow-wire -- so a re-grab is a clean whole-object move that follows its risers. Direct sel
    * writes (draw() repaints); id-less / merged-away follow copper simply drops from the selection. */
   else if(tclgetboolvar("fluid_editing") && xctx->stretch_select && xctx->fluid_startsel_wires > 0) {
     int wi, any = 0;
     for(wi = 0; wi < xctx->wires; ++wi) {
       if(fluid_wire_is_user_selected(wi)) {
         if(xctx->wire[wi].sel != SELECTED) { xctx->wire[wi].sel = SELECTED; any = 1; }
       } else if(xctx->wire[wi].sel) { xctx->wire[wi].sel = 0; any = 1; }
     }
     if(any) { xctx->need_reb_sel_arr = 1; rebuild_selected_array(); }
   }
   /* issue 0081: end of one X-then-Y decomposition leg. After leg 0 (the X move + its cleanup + the
    * follow-wire deselect above) re-derive a fresh SELECTED1/2 follow set at the X-moved pins, so
    * leg 1 (the Y move) is a clean pure-axis stretch that relays each stub exactly once. */
   if(nlegs == 2 && leg == 0) move_regrab_follow_set();
   } /* end for(leg): issue 0081 diagonal X-then-Y decomposition */
   if(!leg_snapped) break;            /* plain single-pass move (no decomposition snapshot): commit as-is */
   /* attempt done: restore the accumulated total delta, then P2-check the composite route.
    * issue 0085: this check now also covers the attempt-1 single diagonal pass -- its blind-elbow
    * relays proved they CAN short (own-pin plow / stray wire-endpoint T, after_5.sch), so it is no
    * longer accepted sight-unseen; attempt 2 is the rigid diagonal relay above. */
   xctx->deltax = totdx; xctx->deltay = totdy;
   prepare_netlist_structs(0);        /* refresh inst[].node[] for the partition test */
   {
   int pchg;
   if(fluid_trace_on()) {
     int wi;
     for(wi = 0; wi < xctx->wires; ++wi)
       fltrace("FLTRACE wires:   attempt=%d w=%d [%g %g %g %g] sel=%u lab=%s\n", attempt, wi,
               xctx->wire[wi].x1, xctx->wire[wi].y1, xctx->wire[wi].x2, xctx->wire[wi].y2,
               xctx->wire[wi].sel, get_tok_value(xctx->wire[wi].prop_ptr, "lab", 0));
   }
   pchg = fluid_partition_changed();
   fltrace("FLTRACE move: attempt=%d done (nlegs=%d diag_relay=%d), partition_changed=%d %s\n",
           attempt, nlegs, diag_relay, pchg,
           pchg == 0 ? "-> ACCEPT" : attempt == 0 ? "-> ROLLBACK to single diagonal pass" :
           attempt == 1 ? "-> ROLLBACK to rigid diagonal relay" : "(last resort)");
   if(pchg == 0) break;               /* connectivity preserved (no merge/disconnect): accept */
   if(attempt == 2) {
     /* the rigid relay STILL changed the partition: either an intentional landing (a pin dropped
      * onto live copper -- every attempt shows it) or an unroutable scene. Keep the relay ONLY
      * when fully clean (pchg==0, handled by the break above); otherwise put the ortho attempt-1
      * result back. NOT `pchg < alt_pchg`: fluid_partition_changed()'s per-pin diff count is
      * cascade-sensitive (first-seen relabeling inflates one early merge past two late ones --
      * review wf_e348633c F5), so ordering two nonzero counts can prefer MORE real damage; the
      * only trustworthy verdict is zero/nonzero. Restore alt's OWN id counters (not the START
      * ones): they match the geometry being restored. */
     if(alt_snapped) {
       unsigned int saved_ui = xctx->ui_state;
       mem_restore_slot(&alt_snap, 0);
       xctx->ui_state = saved_ui;
       xctx->wire_id_counter = alt_wid;
       xctx->inst_id_counter = alt_iid;
       xctx->gfx_id_counter  = alt_gid;
       xctx->text_id_counter = alt_tid;
       xctx->need_reb_sel_arr = 1; rebuild_selected_array();
       xctx->movelastsel = xctx->lastsel;
       fltrace("FLTRACE move: rigid relay not clean (%d, attempt-1 had %d): kept ortho attempt-1 result\n",
               pchg, alt_pchg);
     }
     break;
   }
   if(attempt == 1) {
     /* issue 0085: snapshot the shorted-but-orthogonal attempt-1 result for the never-worse compare,
      * then arm the rigid relay: manhattan jogs off (place_moved_wire's else-branch translates the
      * moved endpoint; the wire goes diagonal) and the fluid passes decline via leg_ortho==0. */
     memset(&alt_snap, 0, sizeof(alt_snap));
     mem_snapshot_alloc(&alt_snap); mem_serialize_slot(&alt_snap); alt_snapped = 1;
     alt_pchg = pchg;
     alt_wid = xctx->wire_id_counter;
     alt_iid = xctx->inst_id_counter;
     alt_gid = xctx->gfx_id_counter;
     alt_tid = xctx->text_id_counter;
     saved_ml_lines = xctx->manhattan_lines;
     xctx->manhattan_lines = 0;
     diag_relay = 1;
   }
   /* the attempt changed connectivity: roll back to pristine + retry the next fallback.
    * Mirror fluid_reroute_restore(): mem_restore_slot zeroes ui_state/lastsel and reallocs the
    * arrays, so put back ui_state, the START id counters (determinism), sel_array, and movelastsel. */
   { unsigned int saved_ui = xctx->ui_state;
     mem_restore_slot(&leg_snap, 0);
     xctx->ui_state = saved_ui;
     xctx->wire_id_counter = xctx->fluid_reroute_wid;
     xctx->inst_id_counter = xctx->fluid_reroute_iid;
     xctx->gfx_id_counter  = xctx->fluid_reroute_gid;
     xctx->text_id_counter = xctx->fluid_reroute_tid;
     xctx->need_reb_sel_arr = 1; rebuild_selected_array();
     xctx->movelastsel = xctx->lastsel;
   }
   nlegs = 1;                          /* attempts 1/2: single pass from the restored pristine */
   xctx->deltax = totdx; xctx->deltay = totdy;
   } /* end pchg block */
   } /* end for(attempt): P2 safety net */
   fluid_g.leg_future_dx = fluid_g.leg_future_dy = 0.0;  /* issue 0086: never leak past the gesture */
   fluid_g.slide_pushthrough_on = 1;                   /* issue 0109: never leak past the gesture */
   if(diag_relay) xctx->manhattan_lines = saved_ml_lines;
   if(alt_snapped) mem_snapshot_free(&alt_snap);
   if(leg_snapped) mem_snapshot_free(&leg_snap);
   /* issue 0107: an ACCEPTED rigid relay is partition-clean but its follow wires are DIAGONAL --
    * geometry-illegal for orthogonal mode; the relay path skips the whole END cleanup block
    * (leg_ortho==0), so nothing downstream re-Manhattanizes it. Convert each relay diagonal into a
    * partition-verified L (keep the diagonal when neither orientation verifies). END only -- the
    * saved result is what the user keeps; the live RUBBER relay preview stays as-is. When the relay
    * was NOT accepted (attempt-1 alt restored) the function's partition-clean entry check declines. */
   if(!commit_now && diag_relay && orthogonal_wiring && xctx->stretch_select &&
      tclgetboolvar("fluid_editing")) {
     fluid_manhattanize_relay_diagonals();
     /* issue 0132 §11.9f (after_37, defects P-A/P-C): the relay cleanup above can only RE-ROUTE a
      * moved pin's feed to an existing same-net vertex -- it cannot shove a LOAD-BEARING backbone
      * sideways out of the body. So a stationary through-body vertical the moved pin lands on
      * MID-SEGMENT (the CTRL1 x=140 column) is left threading the body: reroute_body_crossing_feeds'
      * nearest-outside anchor is IN-COLUMN (140,100) so the feed never pulls past the body edge, and
      * the verified delete reverts it as load-bearing (it is the only path to the naming label). The
      * pure-ortho path gets exactly this fix from fluid_shove_body_crossing_backbone -- run it here
      * too, now that the diagonals are Manhattan. That function derives its motion axis from
      * xctx->delta[xy] and PURE-AXIS-gates itself off for a diagonal delta, so feed it ONE axis at a
      * time (x-run shove with deltay spoofed to 0, then y-run shove with deltax spoofed to 0). delta
      * is read ONLY at that gate (verified); every downstream gate (engulf + through-run + corner)
      * self-guards and the pass double-verifies with exact revert, so a pin whose run is on the other
      * axis, escapes the body within a grid, or would short is left byte-identical (never worse). END
      * only -- it rides under the diag manhattanize, which is itself END-only. */
     if(xctx->fluid_startsel_wires == 0 && xctx->move_rot == 0 && xctx->move_flip == 0) {
       double sdx = xctx->deltax, sdy = xctx->deltay;
       xctx->deltay = 0.0;                        fluid_shove_body_crossing_backbone(); /* x-run */
       fluid_shove_jog_separated_trunk();                                               /* 0136 x-run */
       xctx->deltax = 0.0; xctx->deltay = sdy;    fluid_shove_body_crossing_backbone(); /* y-run */
       fluid_shove_jog_separated_trunk();                                               /* 0136 y-run */
       xctx->deltax = sdx; xctx->deltay = sdy;
     }
   }
   /* issue 0132 §11.9c/§11.9d (after_35/after_36): BODY-driven backbone shove on the accepted
    * PURE-ORTHO path (diag_relay==0 -- the relay path's body-crossing repair lives inside
    * manhattanize above). Runs LIVE on every RUBBER live-commit step AND at the real END -- the
    * body of the selection shoves its own copper the same way the PIN-driven shove
    * (fluid_shove_connected_wire, step 5) already does, so the re-route kicks in on the slightest
    * drag instead of snapping into place only at the LMB release (the user's request). This is the
    * CLEAN post-attempt-ladder site (post trim/orphan-removal/ownership-normalize: all wire sel==0,
    * instances committed to moved coords), NOT the mid-gesture SHARED COMMIT BLOCK (step 4/5) whose
    * dirty transient state bred phantom cross-net merges and was reverted -- do NOT move this call
    * back there. Firing live is release==stepwise-safe by construction: every RUBBER step and the
    * real END each fluid_reroute_restore() to pristine and re-derive from the TOTAL delta, so a
    * per-step shove never accumulates and the saved END result is independent of how many steps
    * fired. Tool-owned follow set only (fluid_startsel_wires==0): a user-grabbed wire is her own
    * routing, not the tool's to reshape (P7). Rot-free: the rotated twin goes through the diag-relay
    * machinery. Internally pure-axis-gated, per-pin gated, mem-snapshotted and DOUBLE partition-
    * verified with exact revert -- a decline (or a live step on not-yet-engulfed geometry) keeps the
    * accepted route byte-identical (never worse). */
   if(!diag_relay && orthogonal_wiring && xctx->stretch_select &&
      tclgetboolvar("fluid_editing") && xctx->fluid_startsel_wires == 0 &&
      xctx->move_rot == 0 && xctx->move_flip == 0) {
     /* issue 0134: a DIAGONAL drag accepted on the PURE-ORTHO path (attempt=0 leg-split, NOT
      * diag_relay) still threads a load-bearing backbone through the body (the +20,-10 CTRL1 x=140
      * column). This path became reachable once the 0134 exit-stub foreign-net guard keeps the
      * leg-split electrically clean, so the drag no longer falls through to the diag_relay site above
      * (which already spoofs per-axis, §11.9f). fluid_shove_body_crossing_backbone pure-axis-gates
      * itself off a diagonal delta, so -- exactly as the diag_relay site -- feed it ONE axis at a
      * time. A pure-axis drag (one of sdx/sdy is 0) is unaffected: the zero-axis run self-declines,
      * so the live RUBBER behaviour for ordinary single-axis drags is byte-identical. */
     double sdx = xctx->deltax, sdy = xctx->deltay;
     xctx->deltay = 0.0;                     fluid_shove_body_crossing_backbone(); /* x-run */
     fluid_shove_jog_separated_trunk();                                            /* 0136 x-run */
     xctx->deltax = 0.0; xctx->deltay = sdy; fluid_shove_body_crossing_backbone(); /* y-run */
     fluid_shove_jog_separated_trunk();                                            /* 0136 y-run */
     xctx->deltax = sdx; xctx->deltay = sdy;
   }
   /* the END delta-zeroing (below) and the commit_now redraw save/restore consume xctx->deltax/deltay
    * as the true accumulated total (not the last leg's split); it is set to (totdx,totdy) above. */
   /* --- END-only post-commit finalizers. A live fluid RUBBER step (commit_now) keeps the gesture
    * state and only repaints. stretch_select / stretch_grabbed_xy MUST be cleared/freed HERE, not
    * inside the shared commit above -- they scope the reroute (remove_move_orphan_wires reads
    * stretch_grabbed_xy) and must survive every per-step commit, to be freed exactly once at the
    * real END/ABORT (folding them into the shared commit would UAF on step 2 and double-free). --- */
   if(!commit_now) {
     xctx->stretch_select = 0;
     xctx->stretch_grabbed_n = 0;
     my_free(_ALLOC_ID_, &xctx->stretch_grabbed_xy);
     xctx->fluid_startsel_nid = 0;                     /* issue 0091: drop the user-selected id set */
     my_free(_ALLOC_ID_, &xctx->fluid_startsel_id);

     if(xctx->hilight_nets) {
       propagate_hilights(1, 1, XINSERT_NOREPLACE);
     }

     xctx->ui_state &= ~STARTMOVE;
     if(xctx->ui_state & STARTMERGE) xctx->ui_state |= SELECTION; /* leave selection state so objects can be deleted */
     xctx->ui_state &= ~STARTMERGE;
     xctx->move_rot=xctx->move_flip=0;
     xctx->x1=xctx->y1=xctx->x2=xctx->y2=xctx->deltax=xctx->deltay=0.;
     /* P3 write-through: a moved pin-name view records its new offset on the owning pin;
      * a pin moved without its view makes the view follow (Option B). */
     pin_views_reconcile_after_move();
     /* hardening sprint Track B / step B3 (doc/claude/suggestions/hardening_sprint_plan.md):
      * promote the runtime P1/P2 checker from log-only to ROLLBACK-OR-REFUSE. The healer ladder
      * (attempt loop, de-shorters, straighteners) has run every repair it has; if a short / merge /
      * disconnect STILL survives and enforcement is on, refuse the whole gesture: restore the
      * gesture-pristine snapshot, drop the undo push, tell the user, leave the schematic
      * byte-identical to pre-gesture. Kills the "silent saved corruption" failure mode (the
      * 0094/0098/0099 class the checker merely PRINTED while it shipped). */
     {
       int enforce = tclgetboolvar("fluid_enforce_invariants");
       int p2bad = fluid_check_move_invariants(enf_short_base);  /* sets fluid_last_move_* AND returns delta-shorts+dev_merges */
       fltrace("FLTRACE move: fluid_enforce_invariants=%d p2_merges=%d short_base=%d enf_snapped=%d\n",
               enforce, p2bad, enf_short_base, enf_snapped);
       if(enforce && enf_snapped && p2bad) {
         /* REFUSE. Restore ritual mirrors the leg_snap rollback (:7171): preserve ui_state across
          * mem_restore_slot (which zeroes it via unselect_all), put the START id counters back
          * (deterministic tool-wire ids), rebuild sel_array + movelastsel (dce0bea6 overflow guard). */
         unsigned int saved_ui = xctx->ui_state;
         mem_restore_slot(&enf_snap, 0);
         xctx->ui_state = saved_ui;
         xctx->wire_id_counter = enf_wid;
         xctx->inst_id_counter = enf_iid;
         xctx->gfx_id_counter  = enf_gid;
         xctx->text_id_counter = enf_tid;
         xctx->need_reb_sel_arr = 1; rebuild_selected_array();
         xctx->movelastsel = xctx->lastsel;
         /* drop the gesture's undo push: restore the pre-push counter triple (both undo backends
          * key off these shared xctx counters), so the spurious pristine entry (and any redo) is
          * discarded and a saturated-ring tail / a no_undo no-op push are both handled exactly --
          * the refused move never happened as far as undo is concerned. */
         xctx->cur_undo_ptr = enf_cur; xctx->head_undo_ptr = enf_head; xctx->tail_undo_ptr = enf_tail;
         set_modify(enf_mod_before ? 1 : 0);  /* restore pre-gesture modified flag: refuse changed nothing */
         if(has_x)
           tclvareval("if {[info procs ciw_echo] ne {}} {ciw_echo {"
                      "move refused: would short/merge nets -- schematic left unchanged "
                      "(set fluid_enforce_invariants 0 to override; see FLUID_TRACE)}}", NULL);
         fltrace("FLTRACE move: ENFORCE REFUSED (P2 shorts+dev_merges=%d) -- "
                 "restored pristine, dropped undo push\n", p2bad);
       } else {
         set_modify(1); /* must be before draw() if floaters present, to force cached-value update */
       }
     }
     draw();
     if(enf_snapped) mem_snapshot_free(&enf_snap);
     xctx->rotatelocal=0;
   } else {
     /* incremental_wire_reroute.md Phase II live step: the reroute is committed into the live
      * geometry but the gesture stays open. Mark dirty (END must roll back to pristine before its
      * push_undo), then repaint. The committed geometry ALREADY includes the delta, so zero delta
      * around the redraw (draw_selection paints at coord+delta -> would double-offset) and RESTORE
      * it after: the interactive END is move_objects(END,0,0,0) and consumes xctx->deltax/deltay as
      * the accumulated total, so leaving it zeroed would snap the whole move back to the origin. */
     double sdx = xctx->deltax, sdy = xctx->deltay;
     xctx->fluid_reroute_dirty = 1;
     /* Deliberately NO set_modify() here: like a non-fluid drag preview, the buffer's modified flag
      * is set only at the REAL END, so a fluid drag that is aborted or returns to the origin stays
      * clean (no spurious modified/save-prompt). Floater caches still refresh live -- each step's
      * fluid_reroute_restore() -> mem_restore_slot() invalidates floater_inst_table, so the draw()
      * below recomputes them from the current geometry. */
     xctx->deltax = xctx->deltay = 0.0;
     draw();
     draw_selection(xctx->gc[SELLAYER], 0);
     if(tclgetboolvar("draw_crosshair")) draw_crosshair(3, 0);
     xctx->deltax = sdx; xctx->deltay = sdy;
   }
  } /* what & end (or a live fluid commit_now step) */
  if(!commit_now) {
    draw_selection(xctx->gc[SELLAYER], 0);
    if(tclgetboolvar("draw_crosshair")) draw_crosshair(3, 0); /* what = 1(clear) + 2(draw) */
  }
}
