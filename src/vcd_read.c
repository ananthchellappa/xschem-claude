/* File: vcd_read.c
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

/* VCD (Value Change Dump) reader -- section C of
 * doc/claude/specs/mixed_signal_signal_browser.md.
 *
 * WHAT THIS IS: a SECOND PRODUCER for the existing `Raw` data model. It is the exact
 * analogue of table_read() in save.c -- another file format that becomes an ordinary
 * entry in xctx->extra_raw_arr[]. Nothing downstream learns what a VCD is: the Signal
 * Browser's all-DBs reader (wave_viewer.tcl), the graph renderer (draw.c) and every
 * `xschem raw ...` sub-verb see a Raw like any other. That is the whole design.
 *
 * CONTRACT (identical to table_read(), and relied on by extra_rawfile()):
 *   - xctx->raw MUST be NULL on entry; the caller saves and NULLs it.
 *   - on success allocates xctx->raw, fills it, returns 1.
 *   - on failure returns 0 with xctx->raw already freed and NULLed: every `goto done`
 *     lands on the single cleanup, which calls free_rawfile() when res == 0.
 *   - UNLIKE table_read(), this sets raw->sim_type ("vcd") itself, so a fully built Raw
 *     never carries a NULL sim_type. extra_rawfile() re-stamps it harmlessly. Rationale
 *     at the assignment.
 *
 * ---------------------------------------------------------------------------
 * THE FOUR DECISIONS (spec open decisions 1-4), settled here with the measurement
 * that settled them. Measured 2026-08-08 on ~/.xschem/simulations/counter.vcd,
 * 390 KB, produced by the patched Verilator shim (tools/cosim/).
 * ---------------------------------------------------------------------------
 *
 * DECISION 1 -- SIGNAL NAMES COME FROM THE VCD $scope/$var HEADER, not from parsing
 * the .v source. Confirmed, and the measurement makes it more than a convenience: the
 * reference file declares TEN $var lines using only EIGHT distinct id codes, because
 * `clk` and `count` are declared in BOTH scope `TOP` and scope `TOP.counter` with the
 * SAME id (`&` and `'`). No amount of Verilog parsing predicts that -- it is a fact
 * about what the simulator elaborated. See DECISION 1b.
 *
 * DECISION 1b -- ONE ID CODE MAY NAME MANY VECTORS (aliasing). An id is NOT a signal;
 * it is a shared value cell. `vcd_id` therefore holds a LIST of variable indices and a
 * single value change is written to EVERY column bound to that id. nvars is driven by
 * the $var COUNT (10), never by the id count (8). A reader that assumes id->name is 1:1
 * silently drops or duplicates a vector -- with `#`.."*" here it would have lost one of
 * the two `count` vectors, i.e. exactly the payload this feature exists to show.
 *
 * DECISION 2 -- MATERIALIZATION: columns are built from times where a value ACTUALLY
 * CHANGES, not from `#t` headers, and every change is written as a STEP (two columns).
 *
 *   Measured on the reference file:
 *       50,088   `#t` timestamp lines
 *           36   value-change lines
 *           10   distinct timestamps that carry any change at all
 *       span 0..500,000 ps
 *
 *   M17 in the spec (one `#t` per ngspice timestep, not per event) is real and worse
 *   than recorded: 5,009 timestamp headers per timestamp that means anything. Building
 *   one column per `#t` would cost 29 vectors x 50,088 points x 8 bytes = 11.6 MB for a
 *   500 ns run whose entire information content is 36 lines. Building from real changes
 *   costs 20 columns -- 4.6 KB. That is ~2,500x, and it is the difference between a
 *   reader that survives an unthrottled VCD and one that does not. A9 (throttling the
 *   dump in tools/cosim/src/verilator_shim.cpp) would shrink the INPUT, but eprvcd
 *   output and any externally produced VCD are not ours to throttle, so the reader must
 *   be the thing that is cheap.
 *
 *   WHY TWO COLUMNS PER CHANGE (the step): draw_graph_points() renders with XDrawLines()
 *   in BOTH the analog and the `digital=1` path (draw.c, `if(digital || gr->mode == 0)`).
 *   It draws straight lines between consecutive samples -- it interpolates, it does not
 *   sample-and-hold. Emitting only the change times would therefore draw a 50 ns RAMP
 *   where a clock edge belongs. So each change at tick t emits:
 *       (t-1, previous values)   the hold sample, at the file's own time resolution
 *       (t,   new values)        the edge
 *   which the interpolating renderer draws as a flat run and a one-tick vertical edge.
 *   t-1 can never collide with the previous emitted column: distinct VCD timestamps are
 *   >= 1 tick apart, and when t-1 IS the previous column the hold sample is simply
 *   skipped (the value there is already correct).
 *
 *   Column set = { first `#t` in the file }
 *              U { t-1, t : for every t carrying a value change }
 *              U { last `#t` in the file }
 *   The first and last are what make the trace span the whole run rather than stopping
 *   at the first and last edge. Changes landing ON the first timestamp (the $dumpvars
 *   block, always) overwrite that seeded column instead of appending, so #0 stays a
 *   single point.
 *
 * DECISION 3 -- X AND Z ARE NEVER SILENTLY 0. SPICE_DATA is a bare double with no
 * companion state array, so the four VCD states are encoded as four distinct doubles:
 *
 *       0 -> 0.0     1 -> 1.0     X -> 0.5     Z -> 0.3
 *
 *   These are not arbitrary. get_bus_value() (draw.c) already renders a bus digit as
 *   'X' when a bit sample falls in the undefined band vthl..vthh, and those thresholds
 *   are gr->gy1*0.8+gr->gy2*0.2 and gr->gy1*0.2+gr->gy2*0.8 -- i.e. 0.2..0.8 on the
 *   natural 0..1 digital strip. Both sentinels sit inside that band, so the EXISTING
 *   bus renderer prints 'X' for an unknown or floating bit with no renderer change at
 *   all (spec C7: extend the renderer only if C3/C4 demand it -- they do not, given
 *   this encoding). They are distinct from each other so `xschem raw value` can tell an
 *   X sample from a Z sample, which is what the headless tests assert. A scalar trace
 *   draws them mid-rail, visibly neither 0 nor 1.
 *
 *   A vector with ANY x bit is X as a whole; with any z bit and no x bit it is Z. The
 *   individual bit columns keep their own per-bit state.
 *
 *   Upgrade path, deliberately not taken now: a parallel state array in `Raw`. It would
 *   change a struct every consumer touches and free_rawfile() must free, and it buys
 *   nothing until a renderer reads it (C7/D). The sentinels are the minimal encoding
 *   that is honest at the `xschem raw value` surface today.
 *
 * DECISION 4 -- BUSES ARE EXPLODED TO BITS *AND* KEPT AS A COMPOSITE. A `$var wire 4 '
 * count [3:0]` becomes FIVE columns: `count` holding 0..15, and `count[3]`..`count[0]`
 * holding one bit each. Reason: the viewer's only working bus display composes SCALARS
 * (`node="bus; b3,b2,b1,b0"` -> get_bus_idx_array() -> get_bus_value()), so without the
 * bits a bus is not drawable as a bus today; while the composite is the honest name,
 * the value `xschem raw value` returns, and what the browser tree should show. Both are
 * cheap -- the reference file's 10 $var lines cost 29 columns total. When a native bus
 * vector lands (D/C7) the bit columns become optional, not wrong.
 *
 * DECISION (C6) -- sim_type IS THE STRING "vcd", set by the caller. This is not merely
 * "honest": in extra_rawfile() the type string IS the dispatch key that chooses this
 * reader over raw_read(), exactly as "table" chooses table_read(). Claiming "tran"
 * would route a .vcd into the spice-raw parser. The audit the spec feared costs
 * nothing: every literal sim_type comparison in the tree tests for "op", "dc", "ac" or
 * "table", so "vcd" behaves identically to "tran" at all of them.
 *
 * NAMES ARE STORED VERBATIM -- a deliberate divergence from read_dataset(), which
 * strtolower()s every variable name (save.c) because spice node names are case-
 * insensitive. Verilog identifiers are NOT: `Count` and `count` are two different
 * signals, and folding them would merge two columns into one silently. The cost is that
 * get_raw_index() (save.c) probes verbatim, then uppercased, then lowercased, so a
 * lower-case query does not find a mixed-case VCD name -- the caller must use the name
 * the browser shows. Mapping a schematic path onto a VCD scope path is F2's job and is
 * explicitly NOT a case-folding problem.
 *
 * TIME: VCD time is an integer tick count; $timescale gives the tick. Raw stores
 * SECONDS in names[0] == "time", converted once, here, so that D3's off-by-1e3 class of
 * bug cannot exist downstream and so the X axis matches the analog .raw with no
 * per-consumer knowledge.
 *
 * ROBUSTNESS: the body and the header are parsed from ONE whitespace-delimited token
 * stream, which is what the VCD grammar actually is (`#123`, `0!`, `b0101 !` and
 * `$var wire 1 ! clk $end` are all just tokens). Consequences that matter:
 *   - a TRUNCATED file (a killed simulator always leaves one) ends mid-token or mid-
 *     record; the incomplete record is dropped and everything before it is kept.
 *   - a MISSING $enddefinitions is not fatal: header mode also ends at the first token
 *     that begins a value change or a timestamp.
 *   - $comment blocks are skipped to their $end so their contents can never be read as
 *     data.
 */

#include "xschem.h"

/* Four-state encoding -- see DECISION 3 above. Both VCD_X and VCD_Z lie inside the
 * 0.2..0.8 undefined band get_bus_value() uses on a 0..1 digital strip. */
#define VCD_V0   0.0
#define VCD_V1   1.0
#define VCD_VX   0.5
#define VCD_VZ   0.3

/* growth of the column (time point) arrays; see DECISION 2 -- the count is bounded by
 * real activity, not by the file's timestamp count, so this starts small */
#define VCD_COL_CHUNK 256

/* Largest $var bit width accepted. This is an AMPLIFICATION guard, not a style limit: a
 * declared width becomes width+1 Raw columns, each of which is a growable array of doubles,
 * so one ~30-byte `$var wire 100000000 ! x $end` line in a corrupt file would ask for tens
 * of GB (and a width near INT_MAX would overflow the column count outright). No real Verilog
 * vector approaches 4096 bits -- Verilator emits one $var per signal, and even a wide memory
 * word is declared per word. An over-wide $var is skipped with a message, and the rest of the
 * file still reads. */
#define VCD_MAX_WIDTH 4096

/* one declared VCD variable ($var line) */
typedef struct {
  char *name;     /* full hierarchical name, scopes joined with '.' */
  int width;      /* declared bit width */
  int msb, lsb;   /* from a [msb:lsb] suffix; both -1 when absent */
  int is_real;    /* $var real / realtime */
  int col;        /* column index of the composite value */
  int bitcol;     /* column index of bit 0 of the exploded bits, -1 if not exploded */
} Vcd_var;

/* one id code -- NOT one signal: an id may be bound to several variables (DECISION 1b) */
typedef struct {
  int n;          /* number of variables bound to this id */
  int size;       /* allocated slots in var[] */
  int *var;       /* indices into ctx->var[] */
} Vcd_id;

typedef struct {
  Vcd_var *var;
  int nvar, var_size;
  Vcd_id *id;
  int nid, id_size;
  Int_hashtable idtable;   /* id code string -> index into id[] */
  int ncols;               /* declared data columns, == raw->nvars */
} Vcd_ctx;

/* ---------------------------------------------------------------- token stream ---- */

/* Read one whitespace-delimited token into *buf (grown as needed). Returns the token
 * length, or -1 at end of file. A final token not terminated by whitespace (a truncated
 * file) is returned normally -- the caller decides whether the RECORD it belongs to is
 * complete. */
static int vcd_token(FILE *fd, char **buf, int *bufsize)
{
  int c;
  int n = 0;

  do {
    c = getc(fd);
  } while(c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == '\v');
  if(c == EOF) return -1;
  while(c != EOF && c != ' ' && c != '\t' && c != '\n' && c != '\r' && c != '\f' && c != '\v') {
    if(n + 2 > *bufsize) {
      *bufsize = (*bufsize) ? (*bufsize) * 2 : 64;
      my_realloc(_ALLOC_ID_, buf, (size_t)(*bufsize));
    }
    (*buf)[n++] = (char)c;
    c = getc(fd);
  }
  (*buf)[n] = '\0';
  return n;
}

/* ------------------------------------------------------------------- $timescale ---- */

/* "1ps", "10 ns", "100us" -> seconds per tick. Returns 0.0 if unparsable. The two-token
 * form is handled by the caller concatenating the tokens before calling this. */
static double vcd_timescale_seconds(const char *s)
{
  double mult = 0.0;
  double exp10 = 0.0;
  const char *u;
  char *end = NULL;

  mult = strtod(s, &end);
  if(!end || end == s) return 0.0;
  u = end;
  while(*u == ' ' || *u == '\t') u++;
  if(!strcmp(u, "s"))       exp10 = 1.0;
  else if(!strcmp(u, "ms")) exp10 = 1e-3;
  else if(!strcmp(u, "us")) exp10 = 1e-6;
  else if(!strcmp(u, "ns")) exp10 = 1e-9;
  else if(!strcmp(u, "ps")) exp10 = 1e-12;
  else if(!strcmp(u, "fs")) exp10 = 1e-15;
  else return 0.0;
  return mult * exp10;
}

/* --------------------------------------------------------------- var/id tables ---- */

/* Usable bit width of a `$var <type> <width> ...` declaration, or 0 to reject the whole
 * declaration. A `real`/`realtime` var carries one double whatever width it advertises
 * (VCD writers conventionally say 64). See VCD_MAX_WIDTH for why an upper bound exists. */
static int vcd_var_width(const char *type, const char *width)
{
  int w;

  if(!strcmp(type, "real") || !strcmp(type, "realtime")) return 1;
  w = atoi(width);
  if(w < 1) w = 1;              /* missing or unparsable width: treat as a scalar */
  if(w > VCD_MAX_WIDTH) {
    dbg(0, "vcd_read(): $var width %d exceeds the %d limit, declaration skipped\n",
        w, VCD_MAX_WIDTH);
    return 0;
  }
  return w;
}

static int vcd_add_var(Vcd_ctx *c)
{
  if(c->nvar >= c->var_size) {
    c->var_size = c->var_size ? c->var_size * 2 : 32;
    my_realloc(_ALLOC_ID_, &c->var, (size_t)c->var_size * sizeof(Vcd_var));
  }
  memset(&c->var[c->nvar], 0, sizeof(Vcd_var));
  c->var[c->nvar].msb = c->var[c->nvar].lsb = -1;
  c->var[c->nvar].bitcol = -1;
  return c->nvar++;
}

/* Bind id code `code` to variable index `v`. An id already seen gains another
 * variable -- this is the aliasing case of DECISION 1b, and it is the normal case, not
 * an error: the reference file binds `&` to both TOP.clk and TOP.counter.clk. */
static void vcd_bind_id(Vcd_ctx *c, const char *code, int v)
{
  Int_hashentry *e;
  Vcd_id *id;
  int i;

  /* XINSERT_NOREPLACE returns NULL when it INSERTED (id not seen before) and the
   * EXISTING entry when the id is already bound -- which is the alias case. */
  e = int_hash_lookup(&c->idtable, code, c->nid, XINSERT_NOREPLACE);
  if(e) {
    i = e->value;                       /* id already known: alias */
  } else {
    if(c->nid >= c->id_size) {
      c->id_size = c->id_size ? c->id_size * 2 : 32;
      my_realloc(_ALLOC_ID_, &c->id, (size_t)c->id_size * sizeof(Vcd_id));
    }
    i = c->nid++;
    c->id[i].n = 0;
    c->id[i].size = 0;
    c->id[i].var = NULL;
  }
  id = &c->id[i];
  if(id->n >= id->size) {
    id->size = id->size ? id->size * 2 : 2;
    my_realloc(_ALLOC_ID_, &id->var, (size_t)id->size * sizeof(int));
  }
  id->var[id->n++] = v;
}

static int vcd_find_id(Vcd_ctx *c, const char *code)
{
  Int_hashentry *e = int_hash_lookup(&c->idtable, code, 0, XLOOKUP);
  return e ? e->value : -1;
}

static void vcd_ctx_free(Vcd_ctx *c)
{
  int i;

  for(i = 0; i < c->nvar; i++) {
    if(c->var[i].name) my_free(_ALLOC_ID_, &c->var[i].name);
  }
  for(i = 0; i < c->nid; i++) {
    if(c->id[i].var) my_free(_ALLOC_ID_, &c->id[i].var);
  }
  if(c->var) my_free(_ALLOC_ID_, &c->var);
  if(c->id) my_free(_ALLOC_ID_, &c->id);
  if(c->idtable.table) int_hash_free(&c->idtable);
}

/* ------------------------------------------------------------------- value math ---- */

static double vcd_bit_value(int ch)
{
  switch(ch) {
    case '0': return VCD_V0;
    case '1': return VCD_V1;
    case 'z': case 'Z': return VCD_VZ;
    default:  return VCD_VX;    /* 'x', 'X', 'u', '-' and anything else: unknown */
  }
}

/* Decode a VCD binary vector string (MSB first, leading digits may be omitted) for a
 * variable of declared width `width`.
 *   *composite  <- the integer value, or the X/Z sentinel if any bit is unknown/floating
 *   bits[i]     <- the value of bit i, i counted from the LSB END of the declared vector
 * Per the VCD rule, a string shorter than `width` is left-extended with '0' when its
 * leftmost character is '0' or '1', and with that character itself when it is x or z. */
static void vcd_decode_binary(const char *s, int width, double *composite, double *bits)
{
  int len = (int)strlen(s);
  int i, ch;
  int seen_x = 0, seen_z = 0;
  double val = 0.0;
  int ext;

  if(len <= 0) {
    *composite = VCD_VX;
    for(i = 0; i < width; i++) bits[i] = VCD_VX;
    return;
  }
  ext = (s[0] == 'x' || s[0] == 'X' || s[0] == 'z' || s[0] == 'Z') ? s[0] : '0';
  for(i = 0; i < width; i++) {
    /* bit i counted from the LSB: the character at len-1-i, or the extension */
    int pos = len - 1 - i;
    double bv;
    ch = (pos >= 0) ? s[pos] : ext;
    bv = vcd_bit_value(ch);
    bits[i] = bv;
    /* Classify from the MAPPED VALUE, never by re-testing the character. Re-testing let
     * the composite and its own bit columns disagree: vcd_bit_value() maps every
     * unrecognised character to X (so 'h', 'l', 'w', '-' and any corrupt byte do), but a
     * character list here that named only x/X/u/U left seen_x clear, and the bit then also
     * failed the '1' test, so it was counted as a ZERO in the integer. `bH011` reported
     * composite 3 (fully defined) while its bit 3 column reported 0.5 (unknown) -- the
     * exact silent X->0 that DECISION 3 exists to prevent. Comparing against the VCD_V*
     * constants is exact: bv is one of them by construction, never computed. */
    if(bv == VCD_VX)      seen_x = 1;
    else if(bv == VCD_VZ) seen_z = 1;
    else if(bv == VCD_V1) {
      /* a double holds an exact integer only up to 2^53; wider vectors keep the low
       * bits exactly and lose precision above, which is a property of SPICE_DATA, not
       * of this decode. The per-bit columns stay exact at any width. */
      if(i < 63) val += ldexp(1.0, i);
    }
  }
  if(seen_x)      *composite = VCD_VX;
  else if(seen_z) *composite = VCD_VZ;
  else            *composite = val;
}

/* ----------------------------------------------------------------- column store ---- */

/* Append (or, when `tick` equals the last emitted tick, overwrite) one column.
 * `vals` holds ncols doubles, index 0 unused (the time column is written from `tick`).
 *
 * There is deliberately NO allocation-failure path. my_realloc() returns void and, on
 * failure, prints a message and leaves the OLD pointer in place -- so a caller cannot tell
 * a failed growth from a successful one (a NULL test only ever catches the very first
 * growth, and would wave through exactly the case that matters). Every allocation site in
 * this tree treats my_realloc as fatal-on-OOM for the same reason; a guard here would
 * advertise a safety the allocator does not offer. */
static void vcd_emit(Raw *raw, int *ncol, int *cap, double tick_seconds, double tick,
                     const double *vals, int ncols, int overwrite)
{
  int i;
  int p;

  if(overwrite && *ncol > 0) {
    p = *ncol - 1;
  } else {
    if(*ncol >= *cap) {
      int newcap = (*cap) ? (*cap) * 2 : VCD_COL_CHUNK;
      /* one extra column beyond nvars is mandatory: free_rawfile() frees values[0..nvars]
       * and draw.c uses values[nvars] as scratch for wave expressions */
      for(i = 0; i <= ncols; i++) {
        my_realloc(_ALLOC_ID_, &raw->values[i], (size_t)newcap * sizeof(SPICE_DATA));
      }
      *cap = newcap;
    }
    p = (*ncol)++;
  }
  raw->values[0][p] = (SPICE_DATA)(tick * tick_seconds);
  for(i = 1; i < ncols; i++) raw->values[i][p] = (SPICE_DATA)vals[i];
}

/* Emit the STEP for a timestamp that carried at least one value change: a hold sample one
 * tick before it, then the new values at it. A change landing ON the last emitted column
 * OVERWRITES it rather than appending -- that is what keeps the $dumpvars block from
 * doubling the seeded first column.
 *
 * MONOTONICITY: a timestamp that goes BACKWARDS is clamped to the last emitted one. A
 * corrupt or hand-made VCD can contain one (the patched shim in tools/cosim/ clamps on the
 * writing side for exactly this reason), and values[0] MUST come out non-decreasing:
 * raw_get_pos() brackets on it, and draw.c's sweep-wrap detection compares samples against
 * values[0][0]. An out-of-order X column is a silently wrong plot, not a crash, which is the
 * worst kind. Clamping keeps the change -- latest value wins at that instant -- where
 * dropping it would lose data. */
static void vcd_flush(Raw *raw, int *ncol, int *cap, double tick_seconds, double tick,
                      const double *cur, double *emitted, int ncols, double *last_emitted)
{
  int overwrite;

  if(*ncol > 0 && tick < *last_emitted) {
    dbg(0, "vcd_read(): non-monotonic timestamp #%g after #%g, clamped\n",
        tick, *last_emitted);
    tick = *last_emitted;
  }
  overwrite = (*ncol > 0 && tick == *last_emitted);
  if(!overwrite && *ncol > 0 && tick - 1.0 > *last_emitted) {
    vcd_emit(raw, ncol, cap, tick_seconds, tick - 1.0, emitted, ncols, 0);
    *last_emitted = tick - 1.0;
  }
  vcd_emit(raw, ncol, cap, tick_seconds, tick, cur, ncols, overwrite);
  *last_emitted = tick;
  memcpy(emitted, cur, (size_t)ncols * sizeof(double));
}

/* --------------------------------------------------------------------- the read ---- */

/* Read VCD file `f` into a freshly allocated xctx->raw. See the file header for the
 * contract and every decision. Returns 1 on success, 0 on failure. */
int vcd_read(const char *f)
{
  FILE *fd;
  Raw *raw;
  Vcd_ctx c;
  char *tok = NULL;
  int toksize = 0;
  int toklen;
  double tick_seconds = 1e-12;   /* $timescale default if the file omits it: 1 ps */
  int have_timescale = 0;
  char **scope = NULL;
  int nscope = 0, scope_size = 0;
  char *fullname = NULL;
  char *bitname = NULL;        /* scratch for one bit-column name (heap: names are unbounded) */
  double *cur = NULL;            /* live value per column */
  double *emitted = NULL;        /* values of the last emitted column */
  double *bits = NULL;           /* scratch for one decoded vector */
  int bits_size = 0;
  int ncol = 0, cap = 0;
  int header = 1;
  int pending = 0;               /* a change has been applied since the last flush */
  double pending_tick = 0.0;
  double last_tick = 0.0;        /* last `#t` seen anywhere in the file */
  double last_emitted = 0.0;
  int seen_tick = 0;
  int i, j;
  int res = 0;

  if(xctx->raw) {
    dbg(0, "vcd_read(): must clear current data file before loading new\n");
    return 0;
  }
  memset(&c, 0, sizeof(c));
  int_hash_init(&c.idtable, HASHSIZE);

  fd = my_fopen(f, fopen_read_mode);
  if(!fd) {
    dbg(0, "vcd_read(): failed to open file %s for reading\n", f);
    int_hash_free(&c.idtable);
    return 0;
  }

  /* ---------------------------------------------------------------- header pass --- */
  while(header && (toklen = vcd_token(fd, &tok, &toksize)) >= 0) {
    if(toklen == 0) continue;
    if(tok[0] == '$') {
      if(!strcmp(tok, "$enddefinitions")) {
        while((toklen = vcd_token(fd, &tok, &toksize)) >= 0 && strcmp(tok, "$end")) ;
        header = 0;
      } else if(!strcmp(tok, "$timescale")) {
        char *ts = NULL;
        while((toklen = vcd_token(fd, &tok, &toksize)) >= 0 && strcmp(tok, "$end")) {
          my_strcat(_ALLOC_ID_, &ts, tok);
        }
        if(ts) {
          double t = vcd_timescale_seconds(ts);
          if(t > 0.0) { tick_seconds = t; have_timescale = 1; }
          else dbg(0, "vcd_read(): unrecognized $timescale \"%s\", assuming 1ps\n", ts);
          my_free(_ALLOC_ID_, &ts);
        }
      } else if(!strcmp(tok, "$scope")) {
        char *nm = NULL;
        int field = 0;
        while((toklen = vcd_token(fd, &tok, &toksize)) >= 0 && strcmp(tok, "$end")) {
          if(field == 1) my_strdup2(_ALLOC_ID_, &nm, tok);   /* 0 = scope type */
          field++;
        }
        if(nscope >= scope_size) {
          scope_size = scope_size ? scope_size * 2 : 16;
          my_realloc(_ALLOC_ID_, &scope, (size_t)scope_size * sizeof(char *));
        }
        scope[nscope++] = nm;    /* may be NULL for a malformed $scope; joined as "" */
      } else if(!strcmp(tok, "$upscope")) {
        while((toklen = vcd_token(fd, &tok, &toksize)) >= 0 && strcmp(tok, "$end")) ;
        if(nscope > 0) {
          nscope--;
          if(scope[nscope]) my_free(_ALLOC_ID_, &scope[nscope]);
        }
      } else if(!strcmp(tok, "$var")) {
        char *field[5];
        int nfield = 0;
        for(i = 0; i < 5; i++) field[i] = NULL;
        /* $var <type> <width> <id> <name> [<range>] $end -- read positionally and stop
         * at $end. An id code is any printable ASCII, so the literal `$` IS a legal id
         * (the reference file uses it); only the exact token "$end" terminates. */
        while((toklen = vcd_token(fd, &tok, &toksize)) >= 0 && strcmp(tok, "$end")) {
          if(nfield < 5) my_strdup2(_ALLOC_ID_, &field[nfield], tok);
          nfield++;
        }
        if(nfield >= 4 && field[0] && field[1] && field[2] && field[3] &&
           vcd_var_width(field[0], field[1]) > 0) {
          int v = vcd_add_var(&c);
          Vcd_var *vp = &c.var[v];
          vp->is_real = (!strcmp(field[0], "real") || !strcmp(field[0], "realtime"));
          vp->width = vcd_var_width(field[0], field[1]);
          /* build the full hierarchical name */
          if(fullname) my_free(_ALLOC_ID_, &fullname);
  if(bitname) my_free(_ALLOC_ID_, &bitname);
          for(j = 0; j < nscope; j++) {
            my_strcat(_ALLOC_ID_, &fullname, scope[j] ? scope[j] : "");
            my_strcat(_ALLOC_ID_, &fullname, ".");
          }
          my_strcat(_ALLOC_ID_, &fullname, field[3]);
          /* a [msb:lsb] range names the bits; a single [n] belongs to the NAME (an
           * element of an unpacked array, e.g. `mem[3]`) */
          if(nfield >= 5 && field[4] && field[4][0] == '[') {
            if(strchr(field[4], ':')) {
              sscanf(field[4], "[%d:%d]", &vp->msb, &vp->lsb);
            } else {
              my_strcat(_ALLOC_ID_, &fullname, field[4]);
            }
          }
          my_strdup2(_ALLOC_ID_, &vp->name, fullname);
          vcd_bind_id(&c, field[2], v);
        } else {
          dbg(0, "vcd_read(): malformed $var (%d fields), skipped\n", nfield);
        }
        for(i = 0; i < 5; i++) if(field[i]) my_free(_ALLOC_ID_, &field[i]);
      } else if(!strcmp(tok, "$dumpvars") || !strcmp(tok, "$dumpall") ||
                !strcmp(tok, "$dumpon") || !strcmp(tok, "$dumpoff")) {
        /* the body has started without an $enddefinitions -- a truncated or non-
         * conforming writer. Leave header mode with the marker still in `tok`; the body
         * pass discards it as the no-op it is. Falling through to the generic skip below
         * would have swallowed the whole $dumpvars block, i.e. every initial value. */
        header = 0;
        break;
      } else {
        /* $version $date $comment and anything else: skip the whole block. Skipping
         * $comment to its $end is what stops comment text being read as data. */
        while((toklen = vcd_token(fd, &tok, &toksize)) >= 0 && strcmp(tok, "$end")) ;
      }
    } else {
      /* No $enddefinitions (truncated or non-conforming writer): the header ends at the
       * first token that can only be body. Push it back by handling it below. */
      header = 0;
      break;
    }
  }

  if(c.nvar == 0) {
    dbg(0, "vcd_read(): %s declares no $var, nothing to read\n", f);
    goto done;
  }

  /* --------------------------------------------------------- allocate the Raw ----- */
  /* column 0 is the sweep variable: named "time" and holding SECONDS, so every existing
   * X-axis consumer (cursors, `raw pos_at`, the viewer) works unchanged */
  c.ncols = 1;
  for(i = 0; i < c.nvar; i++) {
    c.var[i].col = c.ncols++;
    if(c.var[i].width > 1 && !c.var[i].is_real) {
      c.var[i].bitcol = c.ncols;
      c.ncols += c.var[i].width;
    }
  }

  xctx->raw = my_calloc(_ALLOC_ID_, 1, sizeof(Raw));
  raw = xctx->raw;
  raw->level = -1;
  raw->annot_p = -1;
  raw->annot_sweep_idx = -1;
  raw->sweep1 = -1.0;
  raw->sweep2 = -1.0;
  int_hash_init(&raw->table, HASHSIZE);
  raw->nvars = c.ncols;
  raw->names = my_calloc(_ALLOC_ID_, (size_t)raw->nvars, sizeof(char *));
  /* one extra column: free_rawfile() frees values[0..nvars] and draw.c writes custom
   * wave-expression results into values[nvars] */
  raw->values = my_calloc(_ALLOC_ID_, (size_t)raw->nvars + 1, sizeof(SPICE_DATA *));
  raw->cursor_b_val = my_calloc(_ALLOC_ID_, (size_t)raw->nvars, sizeof(double));

  my_strdup2(_ALLOC_ID_, &raw->names[0], "time");
  int_hash_lookup(&raw->table, raw->names[0], 0, XINSERT_NOREPLACE);
  for(i = 0; i < c.nvar; i++) {
    Vcd_var *vp = &c.var[i];
    my_strdup2(_ALLOC_ID_, &raw->names[vp->col], vp->name);
    int_hash_lookup(&raw->table, raw->names[vp->col], vp->col, XINSERT_NOREPLACE);
    if(vp->bitcol >= 0) {
      int msb = (vp->msb >= 0) ? vp->msb : vp->width - 1;
      int lsb = (vp->lsb >= 0) ? vp->lsb : 0;
      int step = (lsb > msb) ? -1 : 1;   /* bit index counted up from the LSB end */
      for(j = 0; j < vp->width; j++) {
        /* Built on the HEAP, not in a fixed buffer. A VCD hierarchical name is unbounded
         * (every $scope level joined with '.'), and a truncating my_snprintf would give
         * every bit of the bus the SAME string -- XINSERT_NOREPLACE then keeps one, and
         * get_raw_index() resolves all of them to bit 0, so a bus reads back as N copies
         * of its LSB. That is the aliasing failure DECISION 1b exists to prevent, arriving
         * through the name instead of the id.
         * bit j counted from the LSB; its declared index walks from lsb toward msb */
        my_strdup2(_ALLOC_ID_, &bitname, vp->name);
        my_strcat(_ALLOC_ID_, &bitname, "[");
        my_strcat(_ALLOC_ID_, &bitname, my_itoa(lsb + j * step));
        my_strcat(_ALLOC_ID_, &bitname, "]");
        my_strdup2(_ALLOC_ID_, &raw->names[vp->bitcol + j], bitname);
        int_hash_lookup(&raw->table, raw->names[vp->bitcol + j], vp->bitcol + j,
                        XINSERT_NOREPLACE);
      }
    }
  }

  cur     = my_calloc(_ALLOC_ID_, (size_t)c.ncols, sizeof(double));
  emitted = my_calloc(_ALLOC_ID_, (size_t)c.ncols, sizeof(double));
  /* everything is X until the $dumpvars block (or the first change) says otherwise --
   * this is the VCD rule, and DECISION 3 says an unknown must not read back as 0 */
  for(i = 1; i < c.ncols; i++) cur[i] = VCD_VX;

  /* --------------------------------------------------------------- body pass ------ */
  /* `tok` currently holds the first body token when the header ended without
   * $enddefinitions; otherwise fetch one. */
  if(toklen < 0 || (tok && tok[0] == '$') || !tok || !tok[0]) {
    toklen = vcd_token(fd, &tok, &toksize);
  }
  for( ; toklen >= 0; toklen = vcd_token(fd, &tok, &toksize)) {
    char ch;
    if(toklen == 0) continue;
    ch = tok[0];

    if(ch == '#') {
      double t;
      /* A timestamp closes the previous one: flush whatever it accumulated. `pending_tick`
       * starts at 0.0, which is exactly right -- a value change written before ANY `#t`
       * (a $dumpvars block ahead of the first timestamp, which is legal and common)
       * belongs at time 0 by the VCD rule, not at whatever the first timestamp turns out
       * to be. */
      if(pending) {
        vcd_flush(raw, &ncol, &cap, tick_seconds, pending_tick, cur, emitted,
                  c.ncols, &last_emitted);
        pending = 0;
      }
      t = strtod(tok + 1, NULL);
      if(!seen_tick) {
        seen_tick = 1;
        last_tick = t;   /* not max() yet: the first timestamp may be negative */
        /* Seed a column at the first timestamp so the trace starts where the run does
         * rather than at the first edge -- but ONLY if the flush above has not already
         * emitted one. Seeding unconditionally appended a SECOND column at the same tick
         * whenever changes preceded the first `#t`, and a duplicate time sample is one
         * raw_get_pos()'s bracketing walks straight over. */
        if(ncol == 0) {
          vcd_emit(raw, &ncol, &cap, tick_seconds, t, cur, c.ncols, 0);
          last_emitted = t;
          memcpy(emitted, cur, (size_t)c.ncols * sizeof(double));
        }
      }
      pending_tick = t;
      /* the MAX, not the last seen: the tail column has to be the end of the run even if
       * the file's timestamps are out of order */
      if(t > last_tick) last_tick = t;
      continue;
    }

    if(ch == '$') {
      /* $dumpvars $dumpall $dumpon $dumpoff hold ordinary value changes; only their
       * $end is noise. $comment must be skipped whole. */
      if(!strcmp(tok, "$comment")) {
        while((toklen = vcd_token(fd, &tok, &toksize)) >= 0 && strcmp(tok, "$end")) ;
        if(toklen < 0) break;
      }
      continue;
    }

    if(ch == 'b' || ch == 'B' || ch == 'r' || ch == 'R') {
      char *val = NULL;
      int idx;
      /* value and id are two tokens; at EOF between them the record is incomplete and
       * is dropped -- this is the truncated-file case */
      my_strdup2(_ALLOC_ID_, &val, tok + 1);
      toklen = vcd_token(fd, &tok, &toksize);
      if(toklen < 0) { my_free(_ALLOC_ID_, &val); break; }
      idx = vcd_find_id(&c, tok);
      if(idx >= 0) {
        Vcd_id *id = &c.id[idx];
        for(j = 0; j < id->n; j++) {              /* DECISION 1b: every alias */
          Vcd_var *vp = &c.var[id->var[j]];
          if(ch == 'r' || ch == 'R') {
            cur[vp->col] = strtod(val, NULL);
          } else {
            if(vp->width > bits_size) {
              bits_size = vp->width;
              my_realloc(_ALLOC_ID_, &bits, (size_t)bits_size * sizeof(double));
            }
            vcd_decode_binary(val, vp->width, &cur[vp->col], bits);
            if(vp->bitcol >= 0) {
              int k;
              for(k = 0; k < vp->width; k++) cur[vp->bitcol + k] = bits[k];
            }
          }
        }
        pending = 1;
      }
      my_free(_ALLOC_ID_, &val);
      continue;
    }

    if(ch == '0' || ch == '1' || ch == 'x' || ch == 'X' || ch == 'z' || ch == 'Z' ||
       ch == 'u' || ch == 'U' || ch == 'h' || ch == 'H' || ch == 'l' || ch == 'L' ||
       ch == 'w' || ch == 'W' || ch == '-') {
      const char *code = tok + 1;
      int idx;
      if(!code[0]) {                 /* liberal: some writers put a space, "0 !" */
        toklen = vcd_token(fd, &tok, &toksize);
        if(toklen < 0) break;
        code = tok;
      }
      idx = vcd_find_id(&c, code);
      if(idx >= 0) {
        double v = vcd_bit_value(ch);
        Vcd_id *id = &c.id[idx];
        for(j = 0; j < id->n; j++) {
          Vcd_var *vp = &c.var[id->var[j]];
          cur[vp->col] = v;
          if(vp->bitcol >= 0) cur[vp->bitcol] = v;
        }
        pending = 1;
      }
      continue;
    }
    /* anything else: an unknown record. Ignore it rather than abandoning the file. */
  }

  /* flush whatever the last timestamp accumulated */
  if(pending) {
    vcd_flush(raw, &ncol, &cap, tick_seconds, pending_tick, cur, emitted,
              c.ncols, &last_emitted);
  }
  /* extend the traces to the end of the run: the last `#t` normally carries no change,
   * and without this the waveform would stop at the last edge (DECISION 2) */
  if(ncol > 0 && last_tick > last_emitted) {
    vcd_emit(raw, &ncol, &cap, tick_seconds, last_tick, cur, c.ncols, 0);
    last_emitted = last_tick;
  }

  if(ncol == 0) {
    dbg(0, "vcd_read(): %s has no value change data\n", f);
    goto done;
  }

  raw->datasets = 1;
  my_realloc(_ALLOC_ID_, &raw->npoints, sizeof(int));
  raw->npoints[0] = ncol;
  raw->allpoints = ncol;
  my_strdup2(_ALLOC_ID_, &raw->rawfile, f);
  my_strdup2(_ALLOC_ID_, &raw->schname, xctx->sch[xctx->currsch]);
  raw->level = xctx->currsch;
  /* Set sim_type HERE rather than leaving it to the caller as table_read() does. Seven
   * sites strcmp xctx->raw->sim_type with NO null guard (scheduler.c:2183, 9751, 9764;
   * callback.c:785; draw.c:3543, 4860, 8318) and scheduler.c hands the bare pointer to
   * Tcl_SetResult, so any window in which a fully built Raw carries a NULL sim_type is a
   * crash waiting for a caller that forgets. extra_rawfile() still stamps the type after
   * this returns -- my_strdup() reallocs, so the overwrite is clean. */
  my_strdup(_ALLOC_ID_, &raw->sim_type, "vcd");
  res = 1;

  dbg(0, "VCD data read: %s\n", f);
  dbg(0, "points=%d, vars=%d, datasets=%d, timescale=%g s%s\n",
      raw->allpoints, raw->nvars, raw->datasets, tick_seconds,
      have_timescale ? "" : " (defaulted, no $timescale)");

  /* single cleanup, reached on BOTH the success and the failure path */
  done:
  if(fd) fclose(fd);
  if(tok) my_free(_ALLOC_ID_, &tok);
  if(cur) my_free(_ALLOC_ID_, &cur);
  if(emitted) my_free(_ALLOC_ID_, &emitted);
  if(bits) my_free(_ALLOC_ID_, &bits);
  if(fullname) my_free(_ALLOC_ID_, &fullname);
  for(i = 0; i < nscope; i++) if(scope[i]) my_free(_ALLOC_ID_, &scope[i]);
  if(scope) my_free(_ALLOC_ID_, &scope);
  vcd_ctx_free(&c);
  if(!res && xctx->raw) free_rawfile(&xctx->raw, 0, 1);
  return res;
}
