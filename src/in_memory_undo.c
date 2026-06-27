/* File: in_memory_undo.c
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

static void free_undo_lines(Undo_slot *s)
{
  int i, c;

  for(c = 0;c<cadlayers; ++c) {
    for(i = 0;i<s->lines[c]; ++i) {
      my_free(_ALLOC_ID_, &s->lptr[c][i].prop_ptr);
    }
    my_free(_ALLOC_ID_, &s->lptr[c]);
    s->lines[c] = 0;
  }
}

static void free_undo_rects(Undo_slot *s)
{
  int i, c;

  for(c = 0;c<cadlayers; ++c) {
    for(i = 0;i<s->rects[c]; ++i) {
      my_free(_ALLOC_ID_, &s->bptr[c][i].prop_ptr);
    }
    my_free(_ALLOC_ID_, &s->bptr[c]);
    s->rects[c] = 0;
  }
}

static void free_undo_polygons(Undo_slot *s)
{
  int i, c;

  for(c = 0;c<cadlayers; ++c) {
    for(i = 0;i<s->polygons[c]; ++i) {
      my_free(_ALLOC_ID_, &s->pptr[c][i].prop_ptr);
      my_free(_ALLOC_ID_, &s->pptr[c][i].x);
      my_free(_ALLOC_ID_, &s->pptr[c][i].y);
      my_free(_ALLOC_ID_, &s->pptr[c][i].selected_point);
    }
    my_free(_ALLOC_ID_, &s->pptr[c]);
    s->polygons[c] = 0;
  }
}

static void free_undo_arcs(Undo_slot *s)
{
  int i, c;

  for(c = 0;c<cadlayers; ++c) {
    for(i = 0;i<s->arcs[c]; ++i) {
      my_free(_ALLOC_ID_, &s->aptr[c][i].prop_ptr);
    }
    my_free(_ALLOC_ID_, &s->aptr[c]);
    s->arcs[c] = 0;
  }
}

static void free_undo_wires(Undo_slot *s)
{
  int i;

  for(i = 0;i<s->wires; ++i) {
    my_free(_ALLOC_ID_, &s->wptr[i].prop_ptr);
  }
  my_free(_ALLOC_ID_, &s->wptr);
  s->wires = 0;
}

static void free_undo_texts(Undo_slot *s)
{
  int i;

  for(i = 0;i<s->texts; ++i) {
    my_free(_ALLOC_ID_, &s->tptr[i].prop_ptr);
    my_free(_ALLOC_ID_, &s->tptr[i].txt_ptr);
    my_free(_ALLOC_ID_, &s->tptr[i].font);
    my_free(_ALLOC_ID_, &s->tptr[i].floater_instname);
    my_free(_ALLOC_ID_, &s->tptr[i].floater_ptr);
  }
  my_free(_ALLOC_ID_, &s->tptr);
  s->texts = 0;
}

static void free_undo_instances(Undo_slot *s)
{
  int i;

  for(i = 0;i<s->instances; ++i) {
    my_free(_ALLOC_ID_, &s->iptr[i].name);
    my_free(_ALLOC_ID_, &s->iptr[i].prop_ptr);
    my_free(_ALLOC_ID_, &s->iptr[i].instname);
    my_free(_ALLOC_ID_, &s->iptr[i].lab);
  }
  my_free(_ALLOC_ID_, &s->iptr);
  s->instances = 0;
}

static void free_undo_symbols(Undo_slot *s)
{
  int i, j, c, symbols;
  xSymbol *sym;

  symbols = s->symbols;
  for(i = 0;i < symbols; ++i) {
    sym = &s->symptr[i];
    my_free(_ALLOC_ID_, &sym->name);
    my_free(_ALLOC_ID_, &sym->prop_ptr);
    my_free(_ALLOC_ID_, &sym->type);
    my_free(_ALLOC_ID_, &sym->templ);
    my_free(_ALLOC_ID_, &sym->parent_prop_ptr);

    for(c = 0;c<cadlayers; ++c) {
      for(j = 0;j<sym->polygons[c]; ++j) {
        if(sym->poly[c][j].prop_ptr != NULL) {
          my_free(_ALLOC_ID_, &sym->poly[c][j].prop_ptr);
        }
        my_free(_ALLOC_ID_, &sym->poly[c][j].x);
        my_free(_ALLOC_ID_, &sym->poly[c][j].y);
        my_free(_ALLOC_ID_, &sym->poly[c][j].selected_point);
      }
      my_free(_ALLOC_ID_, &sym->poly[c]);
      sym->polygons[c] = 0;

      for(j = 0;j<sym->lines[c]; ++j) {
        if(sym->line[c][j].prop_ptr != NULL) {
          my_free(_ALLOC_ID_, &sym->line[c][j].prop_ptr);
        }
      }
      my_free(_ALLOC_ID_, &sym->line[c]);
      sym->lines[c] = 0;

      for(j = 0;j<sym->arcs[c]; ++j) {
        if(sym->arc[c][j].prop_ptr != NULL) {
          my_free(_ALLOC_ID_, &sym->arc[c][j].prop_ptr);
        }
      }
      my_free(_ALLOC_ID_, &sym->arc[c]);
      sym->arcs[c] = 0;

      for(j = 0;j<sym->rects[c]; ++j) {
        if(sym->rect[c][j].prop_ptr != NULL) {
          my_free(_ALLOC_ID_, &sym->rect[c][j].prop_ptr);
        }
      }
      my_free(_ALLOC_ID_, &sym->rect[c]);
      sym->rects[c] = 0;
    }
    for(j = 0;j<sym->texts; ++j) {
      if(sym->text[j].prop_ptr != NULL) {
        my_free(_ALLOC_ID_, &sym->text[j].prop_ptr);
      }
      if(sym->text[j].txt_ptr != NULL) {
        my_free(_ALLOC_ID_, &sym->text[j].txt_ptr);
      }
      if(sym->text[j].font != NULL) {
        my_free(_ALLOC_ID_, &sym->text[j].font);
      }
      if(sym->text[j].floater_instname != NULL) {
        my_free(_ALLOC_ID_, &sym->text[j].floater_instname);
      }
      if(sym->text[j].floater_ptr != NULL) {
        my_free(_ALLOC_ID_, &sym->text[j].floater_ptr);
      }
    }
    my_free(_ALLOC_ID_, &sym->text);
    sym->texts = 0;
    my_free(_ALLOC_ID_, &sym->line);
    my_free(_ALLOC_ID_, &sym->rect);
    my_free(_ALLOC_ID_, &sym->poly);
    my_free(_ALLOC_ID_, &sym->arc);
    my_free(_ALLOC_ID_, &sym->lines);
    my_free(_ALLOC_ID_, &sym->rects);
    my_free(_ALLOC_ID_, &sym->polygons);
    my_free(_ALLOC_ID_, &sym->arcs);
  }
  my_free(_ALLOC_ID_, &s->symptr);
  s->symbols = 0;
}

static void mem_init_undo(void)
{
  int slot;

  dbg(1, "mem_init_undo(): undo_initialized = %d\n", xctx->mem_undo_initialized);
  if(!xctx->mem_undo_initialized) {
    for(slot = 0;slot<MAX_UNDO; slot++) {
      xctx->uslot[slot].lines = my_calloc(_ALLOC_ID_, cadlayers, sizeof(int));
      xctx->uslot[slot].rects = my_calloc(_ALLOC_ID_, cadlayers, sizeof(int));
      xctx->uslot[slot].arcs = my_calloc(_ALLOC_ID_, cadlayers, sizeof(int));
      xctx->uslot[slot].polygons = my_calloc(_ALLOC_ID_, cadlayers, sizeof(int));
      xctx->uslot[slot].lptr = my_calloc(_ALLOC_ID_, cadlayers, sizeof(xLine *));
      xctx->uslot[slot].bptr = my_calloc(_ALLOC_ID_, cadlayers, sizeof(xRect *));
      xctx->uslot[slot].aptr = my_calloc(_ALLOC_ID_, cadlayers, sizeof(xArc *));
      xctx->uslot[slot].pptr = my_calloc(_ALLOC_ID_, cadlayers, sizeof(xPoly *));
    }
    xctx->mem_undo_initialized = 1;
  }
}

/* called when program resets undo stack (for example when loading a new file */
void mem_clear_undo(void)
{
  int slot;
  dbg(1, "mem_clear_undo(): undo_initialized = %d\n", xctx->mem_undo_initialized);
  xctx->cur_undo_ptr = 0;
  xctx->tail_undo_ptr = 0;
  xctx->head_undo_ptr = 0;
  if(!xctx->mem_undo_initialized) return;
  for(slot = 0; slot<MAX_UNDO; slot++) {
    free_undo_lines(&xctx->uslot[slot]);
    free_undo_rects(&xctx->uslot[slot]);
    free_undo_polygons(&xctx->uslot[slot]);
    free_undo_arcs(&xctx->uslot[slot]);
    free_undo_wires(&xctx->uslot[slot]);
    free_undo_texts(&xctx->uslot[slot]);
    free_undo_instances(&xctx->uslot[slot]);
    free_undo_symbols(&xctx->uslot[slot]);
  }
}

/* used to delete everything when program exits */
void mem_delete_undo(void)
{
  int slot;
  dbg(1, "mem_delete_undo(): undo_initialized = %d\n", xctx->mem_undo_initialized);
  if(!xctx->mem_undo_initialized) return;
  mem_clear_undo();
  for(slot = 0;slot<MAX_UNDO; slot++) {
    my_free(_ALLOC_ID_, &xctx->uslot[slot].lines);
    my_free(_ALLOC_ID_, &xctx->uslot[slot].rects);
    my_free(_ALLOC_ID_, &xctx->uslot[slot].arcs);
    my_free(_ALLOC_ID_, &xctx->uslot[slot].polygons);
    my_free(_ALLOC_ID_, &xctx->uslot[slot].lptr);
    my_free(_ALLOC_ID_, &xctx->uslot[slot].bptr);
    my_free(_ALLOC_ID_, &xctx->uslot[slot].aptr);
    my_free(_ALLOC_ID_, &xctx->uslot[slot].pptr);
  }
  xctx->mem_undo_initialized = 0;
}

/* Deep-copy the current schematic drawing state (wires, instances, symbols,
 * texts, rects/lines/polys/arcs and all prop strings) into undo slot *s. The
 * slot's per-layer count/pointer arrays must already be allocated by
 * mem_init_undo(). Shared by the undo stack (mem_push_undo) and the hierarchy
 * snapshot store (doc/claude/specs/descend_hierarchy_in_memory.md). */
void mem_serialize_slot(Undo_slot *s)
{
  int i, c;

  my_strdup(_ALLOC_ID_, &s->gptr, xctx->schvhdlprop);
  my_strdup(_ALLOC_ID_, &s->vptr, xctx->schverilogprop);
  my_strdup(_ALLOC_ID_, &s->sptr, xctx->schprop);
  my_strdup(_ALLOC_ID_, &s->fptr, xctx->schspectreprop);
  my_strdup(_ALLOC_ID_, &s->kptr, xctx->schsymbolprop);
  my_strdup(_ALLOC_ID_, &s->eptr, xctx->schtedaxprop);

  free_undo_lines(s);
  free_undo_rects(s);
  free_undo_polygons(s);
  free_undo_arcs(s);
  free_undo_wires(s);
  free_undo_texts(s);
  free_undo_instances(s);
  free_undo_symbols(s);

  memcpy(s->lines, xctx->lines, sizeof(xctx->lines[0]) * cadlayers);
  memcpy(s->rects, xctx->rects, sizeof(xctx->rects[0]) * cadlayers);
  memcpy(s->arcs, xctx->arcs, sizeof(xctx->arcs[0]) * cadlayers);
  memcpy(s->polygons, xctx->polygons, sizeof(xctx->polygons[0]) * cadlayers);
  for(c = 0;c<cadlayers; ++c) {
    s->lptr[c] = my_calloc(_ALLOC_ID_, xctx->lines[c], sizeof(xLine));
    s->bptr[c] = my_calloc(_ALLOC_ID_, xctx->rects[c], sizeof(xRect));
    s->pptr[c] = my_calloc(_ALLOC_ID_, xctx->polygons[c], sizeof(xPoly));
    s->aptr[c] = my_calloc(_ALLOC_ID_, xctx->arcs[c], sizeof(xArc));
  }
  s->wptr = my_calloc(_ALLOC_ID_, xctx->wires, sizeof(xWire));
  s->tptr = my_calloc(_ALLOC_ID_, xctx->texts, sizeof(xText));
  s->iptr = my_calloc(_ALLOC_ID_, xctx->instances, sizeof(xInstance));
  s->symptr = my_calloc(_ALLOC_ID_, xctx->symbols, sizeof(xSymbol));
  s->texts = xctx->texts;
  s->instances = xctx->instances;
  s->symbols = xctx->symbols;
  s->wires = xctx->wires;

  for(c = 0;c<cadlayers; ++c) {
    /* lines */
    for(i = 0;i<xctx->lines[c]; ++i) {
      s->lptr[c][i] = xctx->line[c][i];
      s->lptr[c][i].prop_ptr = NULL;
      my_strdup(_ALLOC_ID_, &s->lptr[c][i].prop_ptr, xctx->line[c][i].prop_ptr);
    }
    /* rects */
    for(i = 0;i<xctx->rects[c]; ++i) {
      s->bptr[c][i] = xctx->rect[c][i];
      s->bptr[c][i].prop_ptr = NULL;
      s->bptr[c][i].extraptr = NULL;
      my_strdup(_ALLOC_ID_, &s->bptr[c][i].prop_ptr, xctx->rect[c][i].prop_ptr);
    }
    /* arcs */
    for(i = 0;i<xctx->arcs[c]; ++i) {
      s->aptr[c][i] = xctx->arc[c][i];
      s->aptr[c][i].prop_ptr = NULL;
      my_strdup(_ALLOC_ID_, &s->aptr[c][i].prop_ptr, xctx->arc[c][i].prop_ptr);
    }
    /*polygons */
    for(i = 0;i<xctx->polygons[c]; ++i) {
      int points = xctx->poly[c][i].points;
      s->pptr[c][i] = xctx->poly[c][i];
      s->pptr[c][i].prop_ptr = NULL;
      s->pptr[c][i].x = my_malloc(_ALLOC_ID_, points * sizeof(double));
      s->pptr[c][i].y = my_malloc(_ALLOC_ID_, points * sizeof(double));
      s->pptr[c][i].selected_point = my_malloc(_ALLOC_ID_, points * sizeof(unsigned short));
      memcpy(s->pptr[c][i].x, xctx->poly[c][i].x, points * sizeof(double));
      memcpy(s->pptr[c][i].y, xctx->poly[c][i].y, points * sizeof(double));
      memcpy(s->pptr[c][i].selected_point, xctx->poly[c][i].selected_point,
        points * sizeof(unsigned short));
      my_strdup(_ALLOC_ID_, &s->pptr[c][i].prop_ptr, xctx->poly[c][i].prop_ptr);
    }
  }
  /* instances */
  for(i = 0;i<xctx->instances; ++i) {
    s->iptr[i] = xctx->inst[i];
    s->iptr[i].prop_ptr = NULL;
    s->iptr[i].name = NULL;
    s->iptr[i].instname = NULL;
    s->iptr[i].lab = NULL;
    s->iptr[i].node = NULL;
    my_strdup2(_ALLOC_ID_, &s->iptr[i].lab, xctx->inst[i].lab);
    my_strdup2(_ALLOC_ID_, &s->iptr[i].instname, xctx->inst[i].instname);
    my_strdup2(_ALLOC_ID_, &s->iptr[i].prop_ptr, xctx->inst[i].prop_ptr);
    my_strdup2(_ALLOC_ID_, &s->iptr[i].name, xctx->inst[i].name);
  }

  /* symbols */
  for(i = 0;i<xctx->symbols; ++i) {
    copy_symbol(&s->symptr[i], &xctx->sym[i]);
  }
  /* texts */
  for(i = 0;i<xctx->texts; ++i) {
    s->tptr[i] = xctx->text[i];
    s->tptr[i].prop_ptr = NULL;
    s->tptr[i].txt_ptr = NULL;
    s->tptr[i].font = NULL;
    s->tptr[i].floater_instname = NULL;
    s->tptr[i].floater_ptr = NULL;
    my_strdup2(_ALLOC_ID_, &s->tptr[i].prop_ptr, xctx->text[i].prop_ptr);
    my_strdup2(_ALLOC_ID_, &s->tptr[i].txt_ptr, xctx->text[i].txt_ptr);
    my_strdup2(_ALLOC_ID_, &s->tptr[i].font, xctx->text[i].font);
    my_strdup2(_ALLOC_ID_, &s->tptr[i].floater_instname, xctx->text[i].floater_instname);
    my_strdup2(_ALLOC_ID_, &s->tptr[i].floater_ptr, xctx->text[i].floater_ptr);
  }

  /* wires */
  for(i = 0;i<xctx->wires; ++i) {
    s->wptr[i] = xctx->wire[i];
    s->wptr[i].prop_ptr = NULL;
    s->wptr[i].node = NULL;
    my_strdup(_ALLOC_ID_, &s->wptr[i].prop_ptr, xctx->wire[i].prop_ptr);
  }
}

void mem_push_undo(void)
{
  int slot;

  if(xctx->no_undo)return;
  mem_init_undo();
  slot = xctx->cur_undo_ptr%MAX_UNDO;
  mem_serialize_slot(&xctx->uslot[slot]);
  xctx->cur_undo_ptr++;
  xctx->head_undo_ptr = xctx->cur_undo_ptr;
  xctx->tail_undo_ptr = xctx->head_undo_ptr <= MAX_UNDO? 0: xctx->head_undo_ptr-MAX_UNDO;
}

/* redo:
 * 0: undo (with push current state for allowing following redo)
 * 4: undo, do not push state for redo
 * 1: redo
 * 2: read top data from undo stack without changing undo stack
 */
/* Rebuild the current schematic drawing state from snapshot slot *s, replacing
 * whatever is loaded. Clears the existing drawing first. If set_modify_status is
 * nonzero the schematic is flagged modified afterwards. Shared by the undo stack
 * (mem_pop_undo) and the hierarchy restore (doc/claude/specs/descend_hierarchy_in_memory.md).
 * Caller owns undo-stack pointer bookkeeping. */
void mem_restore_slot(Undo_slot *s, int set_modify_status)
{
  int i, c;

  clear_drawing();
  unselect_all(1);
  my_free(_ALLOC_ID_, &xctx->wire);
  my_free(_ALLOC_ID_, &xctx->text);
  my_free(_ALLOC_ID_, &xctx->inst);

  for(i = 0;i<cadlayers; ++i) {
    my_free(_ALLOC_ID_, &xctx->rect[i]);
    my_free(_ALLOC_ID_, &xctx->line[i]);
    my_free(_ALLOC_ID_, &xctx->poly[i]);
    my_free(_ALLOC_ID_, &xctx->arc[i]);
  }

  remove_symbols();
  my_free(_ALLOC_ID_, &xctx->sym);

  my_strdup(_ALLOC_ID_, &xctx->schvhdlprop, s->gptr);
  my_strdup(_ALLOC_ID_, &xctx->schverilogprop, s->vptr);
  my_strdup(_ALLOC_ID_, &xctx->schspectreprop, s->fptr);
  my_strdup(_ALLOC_ID_, &xctx->schprop, s->sptr);
  my_strdup(_ALLOC_ID_, &xctx->schsymbolprop, s->kptr);
  my_strdup(_ALLOC_ID_, &xctx->schtedaxprop, s->eptr);

  for(c = 0;c<cadlayers; ++c) {
    /* lines */
    xctx->maxl[c] = xctx->lines[c] = s->lines[c];
    xctx->line[c] = my_calloc(_ALLOC_ID_, xctx->lines[c], sizeof(xLine));
    for(i = 0;i<xctx->lines[c]; ++i) {
      xctx->line[c][i] = s->lptr[c][i];
      xctx->line[c][i].prop_ptr = NULL;
      my_strdup(_ALLOC_ID_, &xctx->line[c][i].prop_ptr, s->lptr[c][i].prop_ptr);
    }
    /* rects */
    xctx->maxr[c] = xctx->rects[c] = s->rects[c];
    xctx->rect[c] = my_calloc(_ALLOC_ID_, xctx->rects[c], sizeof(xRect));
    for(i = 0;i<xctx->rects[c]; ++i) {
      xctx->rect[c][i] = s->bptr[c][i];
      xctx->rect[c][i].prop_ptr = NULL;
      xctx->rect[c][i].extraptr = NULL;
      my_strdup(_ALLOC_ID_, &xctx->rect[c][i].prop_ptr, s->bptr[c][i].prop_ptr);
    }
    /* arcs */
    xctx->maxa[c] = xctx->arcs[c] = s->arcs[c];
    xctx->arc[c] = my_calloc(_ALLOC_ID_, xctx->arcs[c], sizeof(xArc));
    for(i = 0;i<xctx->arcs[c]; ++i) {
      xctx->arc[c][i] = s->aptr[c][i];
      xctx->arc[c][i].prop_ptr = NULL;
      my_strdup(_ALLOC_ID_, &xctx->arc[c][i].prop_ptr, s->aptr[c][i].prop_ptr);
    }
    /* polygons */
    xctx->maxp[c] = xctx->polygons[c] = s->polygons[c];
    xctx->poly[c] = my_calloc(_ALLOC_ID_, xctx->polygons[c], sizeof(xPoly));
    for(i = 0;i<xctx->polygons[c]; ++i) {
      int points = s->pptr[c][i].points;
      xctx->poly[c][i] = s->pptr[c][i];
      xctx->poly[c][i].prop_ptr = NULL;
      my_strdup(_ALLOC_ID_, &xctx->poly[c][i].prop_ptr, s->pptr[c][i].prop_ptr);
      xctx->poly[c][i].x = my_malloc(_ALLOC_ID_, points * sizeof(double));
      xctx->poly[c][i].y = my_malloc(_ALLOC_ID_, points * sizeof(double));
      xctx->poly[c][i].selected_point = my_malloc(_ALLOC_ID_, points * sizeof(unsigned short));
      memcpy(xctx->poly[c][i].x, s->pptr[c][i].x, points * sizeof(double));
      memcpy(xctx->poly[c][i].y, s->pptr[c][i].y, points * sizeof(double));
      memcpy(xctx->poly[c][i].selected_point, s->pptr[c][i].selected_point,
        points * sizeof(unsigned short));
    }
  }

  /* instances */
  xctx->maxi = xctx->instances = s->instances;
  xctx->inst = my_calloc(_ALLOC_ID_, xctx->instances, sizeof(xInstance));
  for(i = 0;i<xctx->instances; ++i) {
    xctx->inst[i] = s->iptr[i];
    xctx->inst[i].prop_ptr = NULL;
    xctx->inst[i].name = NULL;
    xctx->inst[i].instname = NULL;
    xctx->inst[i].lab = NULL;
    my_strdup2(_ALLOC_ID_, &xctx->inst[i].prop_ptr, s->iptr[i].prop_ptr);
    my_strdup2(_ALLOC_ID_, &xctx->inst[i].name, s->iptr[i].name);
    my_strdup2(_ALLOC_ID_, &xctx->inst[i].instname, s->iptr[i].instname);
    my_strdup2(_ALLOC_ID_, &xctx->inst[i].lab, s->iptr[i].lab);
  }

  /* symbols */
  xctx->maxs = xctx->symbols = s->symbols;
  xctx->sym = my_calloc(_ALLOC_ID_, xctx->symbols, sizeof(xSymbol));

  for(i = 0;i<xctx->symbols; ++i) {
    copy_symbol(&xctx->sym[i], &s->symptr[i]);
  }

  /* texts */
  xctx->maxt = xctx->texts = s->texts;
  xctx->text = my_calloc(_ALLOC_ID_, xctx->texts, sizeof(xText));
  for(i = 0;i<xctx->texts; ++i) {
    xctx->text[i] = s->tptr[i];
    xctx->text[i].txt_ptr = NULL;
    xctx->text[i].font = NULL;
    xctx->text[i].floater_instname = NULL;
    xctx->text[i].floater_ptr = NULL;
    xctx->text[i].prop_ptr = NULL;
    my_strdup2(_ALLOC_ID_, &xctx->text[i].prop_ptr, s->tptr[i].prop_ptr);
    my_strdup2(_ALLOC_ID_, &xctx->text[i].txt_ptr, s->tptr[i].txt_ptr);
    my_strdup2(_ALLOC_ID_, &xctx->text[i].font, s->tptr[i].font);
    my_strdup2(_ALLOC_ID_, &xctx->text[i].floater_instname, s->tptr[i].floater_instname);
    my_strdup2(_ALLOC_ID_, &xctx->text[i].floater_ptr, s->tptr[i].floater_ptr);
  }

  /* wires — bulk-replace channel of the wire lifecycle funnel (census B7):
   * whole-struct copies from the slot; preceded by clear_drawing()
   * which empties storage through wire_storage_reset(). Any per-wire
   * payload added to xWire (e.g. ids) rides the struct copy. */
  xctx->maxw = xctx->wires = s->wires;
  xctx->wire = my_calloc(_ALLOC_ID_, xctx->wires, sizeof(xWire));
  for(i = 0;i<xctx->wires; ++i) {
    xctx->wire[i] = s->wptr[i];
    xctx->wire[i].prop_ptr = NULL;
    xctx->wire[i].node = NULL;
    my_strdup(_ALLOC_ID_, &xctx->wire[i].prop_ptr, s->wptr[i].prop_ptr);
  }
  /* unnecessary since the slot saves all symbols */
  /* link_symbols_to_instances(-1); */
  if(set_modify_status) set_modify(1);
  xctx->prep_hash_inst = 0;
  xctx->prep_hash_wires = 0;
  xctx->prep_net_structs = 0;
  xctx->prep_hi_structs = 0;
  update_conn_cues(WIRELAYER, 0, 0);
  int_hash_free(&xctx->floater_inst_table);
}

void mem_pop_undo(int redo, int set_modify_status)
{
  int slot;

  if(xctx->no_undo)return;
  if(redo == 1) {
    if(xctx->cur_undo_ptr < xctx->head_undo_ptr) {
      xctx->cur_undo_ptr++;
    } else {
      return;
    }
  } else if(redo == 0 || redo == 4) {  /* undo */
    if(xctx->cur_undo_ptr == xctx->tail_undo_ptr) return;
    if(xctx->head_undo_ptr == xctx->cur_undo_ptr) {
      xctx->push_undo();
      xctx->head_undo_ptr--;
      xctx->cur_undo_ptr--;
    }
    /* was incremented by a previous push_undo() in netlisting code, so restore */
    if(redo == 4 && xctx->head_undo_ptr == xctx->cur_undo_ptr) xctx->head_undo_ptr--;
    if(xctx->cur_undo_ptr<= 0) return; /* check undo tail */
    xctx->cur_undo_ptr--;
  } else { /* redo == 2, get data without changing undo stack */
    if(xctx->cur_undo_ptr<= 0) return; /* check undo tail */
    xctx->cur_undo_ptr--; /* will be restored at end */
  }
  slot = xctx->cur_undo_ptr%MAX_UNDO;
  mem_restore_slot(&xctx->uslot[slot], set_modify_status);
  if(redo == 2) xctx->cur_undo_ptr++; /* restore undo stack pointer */
}
