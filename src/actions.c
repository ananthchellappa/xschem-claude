/* File: actions.c
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
#include <sys/wait.h>  /* waitpid */
#endif

void here(double i)
{
  dbg(0, "here %g\n", i);
}

/* super simple 32 bit hashing function for files
 * It is suppoded to be used on text files.
 * Calculates the same hash on windows (crlf) and unix (lf) text files.
 * If you want high collision resistance and
 * avoid 'birthday problem' collisions use a better hash function, like md5sum
 * or sha256sum
 */
unsigned int hash_file(const char *f, int skip_path_lines)
{
  FILE *fd;
  int i;
  size_t n;
  int cr = 0;
  unsigned int h=5381;
  char *line = NULL;
  fd = my_fopen(f, "r"); /* windows won't return \r in the lines and we chop them out anyway in the code */
  if(fd) {
    while((line = my_fgets(fd, &n))) {
      /* skip lines of type: '** sch_path: ...' or '-- sch_path: ...' or '// sym_path: ...'
       * skip also .include /path/to/some/file */
      if(skip_path_lines && n > 14) {
        if(!strncmp(line+2, " sch_path: ", 11) || !strncmp(line+2, " sym_path: ", 11) ) {
          my_free(_ALLOC_ID_, &line);
          continue;
        }
        if(!strncmp(line, ".include ", 9) || !strncmp(line, ".INCLUDE ", 9) ) {
          my_free(_ALLOC_ID_, &line);
          continue;
        }
      }
      for(i = 0; i < n; ++i) {
        /* skip CRs so hashes will match on unix / windows */
        if(line[i] == '\r') {
          cr = 1;
          continue;
        } else if(line[i] == '\n' && cr) {
          cr = 0;
        } else if(cr) { /* no skip \r if not followed by \n */
          cr = 0;
          h += (h << 5) + '\r';
        }
        h += (h << 5) + (unsigned char)line[i];
      }
      my_free(_ALLOC_ID_, &line);
    } /* while(line ....) */
    if(cr) h += (h << 5) + '\r'; /* file ends with \r not followed by \n: keep it */
    fclose(fd);
    return h;
  } else {
    dbg(0, "Can not open file %s\n", f);
  }
  return 0;
}

int there_are_floaters(void)
{
  int floaters = 0, k;
  for(k = 0; k < xctx->texts; k++) {
    if(xctx->text[k].flags & TEXT_FLOATER) {
      floaters = 1;
      dbg(1, "text %d is a floater\n", k);
      break;
    }
  }
  return floaters;
}

const char *get_text_floater(int i)
{
  const char *txt_ptr =  xctx->text[i].txt_ptr;
  if(xctx->text[i].flags & TEXT_FLOATER) {
    int inst = -1;
    const char *instname;

    if(!xctx->floater_inst_table.table) {
      floater_hash_all_names();
    }

    if(xctx->text[i].floater_instname)
      instname = xctx->text[i].floater_instname;
    else {
      instname = get_tok_value(xctx->text[i].prop_ptr, "name", 0);
      if(!xctx->tok_size) {
        instname = get_tok_value(xctx->text[i].prop_ptr, "floater", 0);
        if(xctx->tok_size && !strboolcmp(instname, "true")) instname = "true";
      }
    }
    inst = get_instance(instname);
    if(inst >= 0) {
      if(xctx->text[i].floater_ptr) {
        txt_ptr = xctx->text[i].floater_ptr;
      } else {
        /* cache floater translated text to avoid re-evaluating every time schematic is drawn */
        my_strdup2(_ALLOC_ID_, &xctx->text[i].floater_ptr, translate(inst, xctx->text[i].txt_ptr));
        txt_ptr = xctx->text[i].floater_ptr;
      }
      dbg(1, "floater: %s\n",txt_ptr);
    } else {
      /* do just a tcl substitution if floater does not reference an existing instance
       * (but name=something or floater=something attribute must be present) and text
       * matches tcleval(...) or contains '@' */
      if(strstr(txt_ptr, "tcleval(") == txt_ptr || strchr(txt_ptr, '@')) {
        /* my_strdup2(_ALLOC_ID_, &xctx->text[i].floater_ptr, tcl_hook2(xctx->text[i].txt_ptr)); */
        my_strdup2(_ALLOC_ID_, &xctx->text[i].floater_ptr, translate(-1, xctx->text[i].txt_ptr));
        txt_ptr = xctx->text[i].floater_ptr;
      }
    }
  }
  return txt_ptr;
}

/* Canonical read-only edit gate (issue 0041). Returns 1 -- refusing the edit, with a
 * single dbg/CIW notice -- when the current buffer is read-only, else 0. Woven into the
 * genuine-edit CORES (delete(), move_objects()/copy_objects() START) as a backstop BELOW
 * the scattered entry-point guards (readonly_block() for keyboard/menu, the 29
 * scheduler_readonly_reject() subcommand guards, the action-registry `mutates` flag), so
 * a mutation reaching a guarded core is refused by construction on ANY path -- the entry
 * guards become the fast-path UX, not the sole defense. Deliberately NOT applied at the
 * store/push_undo funnels: those also run during load / undo-restore / netlist-flatten,
 * which must not be blocked (there is no reliable "internal vs user edit" flag at that
 * level -- see doc/claude/issues/0041). `op` names the operation for the notice. */
int begin_edit(const char *op)
{
  if(!xctx || !xctx->readonly) return 0;
  dbg(1, "begin_edit(): read-only buffer, refused: %s\n", op ? op : "edit");
  if(has_x) tclvareval("if {[info procs ciw_echo] ne {}} {ciw_echo {read-only: ",
                       op ? op : "edit", " ignored}}", NULL);
  return 1;
}

/* mod:
 *   0 : clear modified flag, update title and tab names, upd. simulation button colors.
 *   1 : set modified flag, update title and tab names, upd. simulation button colors, rst floater caches.
 *   2 : clear modified flag, do nothing else.
 *   3 : set modified flag, do nothing else.
 *  -1 : set title, rst floater caches.
 *  -2 : rst floater caches, update simulation button colors (Simulate, Waves, Netlist).
 * If floaters are present set_modify(1) (after a modify operation) must be done before draw()
 * to invalidate cached floater string values  before redrawing
 * return 1 if floaters are found (mod==-2 or mod == 1 or mod == -1) */
int set_modify(int mod)
{
  int i, floaters = 0;
  int ro_suppress;

  dbg(1, "set_modify(): %d, prev_set_modify=%d\n", mod, xctx->prev_set_modify);

  /* A read-only buffer cannot hold unsaved edits, so never flag it modified: the '*'
   * title marker and the save-on-close prompt would be bogus (issue 0035 -- e.g. a
   * read-only browse window whose child auto-normalizes on load, or an on-disk mtime
   * change). Suppress only the modified flag (and the autosave backup), while keeping the
   * rest of a mod==1 call's side effects (Netlist/Simulate/Waves button refresh, floater
   * cache flush, title refresh) so a read-only window's UI does not go stale. External
   * on-disk changes are surfaced by the reload mechanism, not by faking modified. Genuine
   * edits can't reach here while read-only (blocked upstream); a pre-existing modified
   * flag from before the buffer was made read-only is left as-is. */
  ro_suppress = ((mod == 1 || mod == 3) && xctx->readonly);

  /* set modify state */
  if(mod == 0 || mod == 1 || mod == 2 || mod == 3) {
    xctx->modified = ro_suppress ? 0 : (mod & 1);
  }
  /* ISSUE 0267 -- see xctx->modify_seq (xschem.h). Bumped on every DECLARATION of dirtiness, not
   * on the 0 -> 1 transition: the point is to let a latched "the flag before X" notice a later,
   * unrelated edit, and after a paste the flag is already 1, so a transition counter would see
   * nothing. Suppressed reads follow xctx->modified: a read-only buffer never becomes dirty, so
   * nothing claimed a modification here either. */
  if((mod == 1 || mod == 3) && !ro_suppress) ++xctx->modify_seq;
  /* Autosave: a genuine edit (mod 1/3 -> modified) immediately persists the buffer
   * to its cellName~.sch backup, so descend never has to save and edits survive a
   * crash. write_backup() is itself a no-op during load (xctx->no_autosave), when
   * autosave_backup is off, or for an untitled buffer. Highlight/select/pan/zoom and
   * net-resolution never call set_modify(1), so they correctly do not write.
   * Removal of the ~ is handled by save_schematic on a real save, not here (clearing
   * modified on load must not delete a recovery backup). */
  if((mod == 1 || mod == 3) && !ro_suppress) write_backup();
  if(mod == 1 || (mod == 0  && xctx->prev_set_modify) || mod == -2) {
    /*                Do not configure buttons if displaying in preview window */
    if(has_x && (xctx->top_path[0] == '\0' || strstr(xctx->top_path, ".x") == xctx->top_path)) {
      char s[256];
      tclvareval("catch {", xctx->top_path, ".menubar entryconfigure Netlist -background $simulate_bg}", NULL);
      tclvareval("set tctx::", xctx->current_win_path, "_netlist $simulate_bg", NULL);
      my_snprintf(s, S(s), "tctx::%s_simulate_id", xctx->current_win_path);
      if(tclgetvar(s)) {
        tclvareval("catch {", xctx->top_path, ".menubar entryconfigure Simulate -background ", tclresult(), "}", NULL);
        tclvareval("set tctx::", xctx->current_win_path, "_simulate ", tclresult(), NULL);
      } else {
        tclvareval("catch {", xctx->top_path, ".menubar entryconfigure Simulate -background $simulate_bg}", NULL);
        tclvareval("set tctx::", xctx->current_win_path, "_simulate $simulate_bg", NULL);
      }
    }
    if(sch_waves_loaded() >= 0) {
      if(has_x && (xctx->top_path[0] == '\0' || strstr(xctx->top_path, ".x") == xctx->top_path)) {
        tclvareval("set tctx::", xctx->current_win_path, "_waves Green", NULL);
        tclvareval("catch {", xctx->top_path, ".menubar entryconfigure Waves -background Green}", NULL);
      }
    } else {
      if(has_x && (xctx->top_path[0] == '\0' || strstr(xctx->top_path, ".x") == xctx->top_path)) {
        tclvareval("set tctx::", xctx->current_win_path, "_waves $simulate_bg", NULL);
        tclvareval("catch {", xctx->top_path, ".menubar entryconfigure Waves -background $simulate_bg}", NULL);
      }
    }
  }

  /* clear floater caches */
  if(mod == 1 || mod == -2 || mod == -1) {
    for(i = 0; i < xctx->texts; i++)
    if(xctx->text[i].flags & TEXT_FLOATER) {
      floaters++;
      my_free(_ALLOC_ID_, &xctx->text[i].floater_ptr); /* clear floater cached value */
    }
    int_hash_free(&xctx->floater_inst_table);
    /* S9 HOOK B (decision D3, issue 0466). THIS BLOCK is the codebase's own
     * "my per-object rendered caches are stale" channel, and the OP-annotation
     * overlay cache is exactly that object class -- one lazily-built rendered
     * string per object, same as xText.floater_ptr above. The epoch's modify_seq
     * term is NOT enough: it moves only for mod 1|3 and never when ro_suppress
     * is set, so it misses editprop.c apply_symbol_prop()'s `set_modify(-2);
     * draw();` -- which paints a FULL FRAME before its caller's set_modify(1) --
     * and every read-only-buffer path. Inside the `if`, deliberately: outside it
     * this would fire on mod 0/2/3 too, and it must not perturb the function's
     * `return floaters` contract (callback.c and scheduler.c read that value). */
    annot_data_changed();
  }

  /* force title   no mod      mod */
  if(mod == -1 || mod == 0 || mod == 1) {
    if(has_x &&
       strcmp(get_cell(xctx->sch[xctx->currsch],1), "systemlib/font") &&
       (xctx->prev_set_modify != xctx->modified || mod == -1)
      ) {
      char *top_path =  xctx->top_path[0] ? xctx->top_path : ".";
      const char *ro = xctx->readonly ? " (read-only)" : "";
      /* Cadence-style window number in the title bar (doc/claude/specs/window_numbering.md):
       * "xschem [3] - cell". Omitted for unnumbered scratch/preview ctxs (window_number 0). */
      /* Backslash-escape the brackets: this string is spliced into a double-quoted Tcl
       * "wm title" argument, where a bare [N] would be command substitution (Tcl would
       * run the command "N"). \[ \] make them literal. */
      char wn[20] = "";
      if(xctx->window_number > 0) my_snprintf(wn, S(wn), " \\[%d\\]", xctx->window_number);
      /* ⚠ issue 0851: A WAVEFORM VIEWER OWNS ITS OWN TITLE. Its buffer is `untitled.sch`
       * by construction, so deriving a title from the schematic name here renames the
       * window from "Waveforms <cell> (<state>)" to "xschem [N] - untitled.sch
       * (read-only)" -- and the user then reasonably reports that there is no waveform
       * window, because the one on screen no longer says it is one. wviewer::retitle
       * (src/wave_viewer.tcl) is the owner; this is the same surface-vs-document
       * distinction the wave_viewer brand was added for in issue 0172.
       *
       * It surfaced with issue 0848. Before that fix the redraw-only restore hit
       * switch_window's "already there" early return and never reached set_modify(-1);
       * once the forward switch really happened, the restore had somewhere to come back
       * FROM, called set_modify(-1) on the viewer context, and clobbered the title. The
       * bug was always here -- 0848 only stopped hiding it. */
      if(xctx->wave_viewer) {
        /* leave the viewer's title to its owner */
      } else if(xctx->modified == 1) {
        tclvareval("wm title ", top_path, " \"xschem", wn, " - [file tail [xschem get schname]]*", ro, "\"", NULL);
        tclvareval("wm iconname ", top_path, " \"xschem", wn, " - [file tail [xschem get schname]]*", ro, "\"", NULL);
      } else {
        tclvareval("wm title ", top_path, " \"xschem", wn, " - [file tail [xschem get schname]]", ro, "\"", NULL);
        tclvareval("wm iconname ", top_path, " \"xschem", wn, " - [file tail [xschem get schname]]", ro, "\"", NULL);
      }
      dbg(1, "modified=%d, schname=%s\n", xctx->modified, xctx->current_name);
      if(xctx->modified) tcleval("set_tab_names *");
      else tcleval("set_tab_names");
    }
  }
  xctx->prev_set_modify = xctx->modified;
  return floaters;
}

void print_version()
{
  printf("XSCHEM V%s\n", XSCHEM_VERSION);
  printf("Copyright (C) 1998-2024 Stefan Schippers\n");
  printf("\n");
  printf("This is free software; see the source for copying conditions.  There is NO\n");
  printf("warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n");
}

char *escape_chars(const char *source, const char *charset)
{
  int s=0;
  int d=0;
  static char *dest = NULL;
  size_t slen, size;

  if(!source) {
    if(dest)  my_free(_ALLOC_ID_, &dest);
    return NULL;
  }
  slen = strlen(source);
  size = slen + 1;
  my_realloc(_ALLOC_ID_, &dest, size);
  while(source && source[s]) {
    if(d >= size - 2) {
      size += 2;
      my_realloc(_ALLOC_ID_, &dest, size);
    }
    if(!strcmp(charset, "")) {
      switch(source[s]) {
        case '\n':
          dest[d++] = '\\';
          dest[d++] = 'n';
          break;
        case '\t':
          dest[d++] = '\\';
          dest[d++] = 't';
          break;
        case '\\':
        case '\'':
        case ' ':
        case ';':
        case '$':
        case '!':
        case '#':
        case '{':
        case '}':
        case '[':
        case ']':
        case '"':
          dest[d++] = '\\';
          dest[d++] = source[s];
          break;
        default:
          dest[d++] = source[s];
      }
    } else {
      if(strchr(charset, source[s])) {
        dest[d++] = '\\';
        dest[d++] = source[s];
      } else {
        dest[d++] = source[s];
      }
    }
    s++;
  }
  dest[d] = '\0';
  return dest;
}

/* the snap in force when the program started (xschemrc `snap`, else CADSNAP).
 * Hoisted out of set_snap() so linewidth_ref_snap() below can read it; still a
 * single program-wide value, safe with multiple schematics/windows. */
static double default_snap = -1.0;

/* The REFERENCE length the automatic line width and the wire-junction / pin dot
 * radius scale with.
 *
 * Stock XSCHEM uses the LIVE cadsnap for both: change_linewidth computes
 * `lw = mooz * 0.09 * cadsnap * k`, which makes every drawn line a fixed fraction
 * (~9%) of the snap pitch as it appears on screen, and cadhalfdotsize scales the
 * same way. That couples a pure CURSOR setting to how the drawing RENDERS -- so
 * doubling the snap (the Alt+Up / Alt+Down bindkeys, the View menu items, the snap
 * dialog, the statusbar entry, `xschem set cadsnap`) also doubles the thickness of
 * every wire, symbol line and pin-rectangle outline and grows the junction dots.
 * That is not what "change the snap spacing" means to the user, and it is the
 * defect this indirection removes.
 *
 * `linewidth_follows_snap` (MIRRORED IN TCL, xschem.tcl) picks the length:
 *   0 = DEFAULT: the startup snap, fixed. Line weight and dot size then track ZOOM
 *       only -- which is what change_linewidth's own comment ("choose line width
 *       automatically based on zoom") describes -- and snap becomes orthogonal to
 *       rendering. At the default snap the result is bit-identical to stock, so a
 *       session that never changes the snap draws exactly as before.
 *   1 = the old stock coupling, for anyone who wants line weight to follow the grid.
 * See doc/claude/specs/snap_spacing_bindkeys.md section 5. */
double linewidth_ref_snap(void)
{
  double cs = tclgetdoublevar("cadsnap");
  if(tclgetboolvar("linewidth_follows_snap")) return cs;
  /* before the first set_snap() (very early startup) there is no recorded default
   * yet -- fall back to the live value, which IS the startup value at that point. */
  if(default_snap <= 0.0) return cs ? cs : CADSNAP;
  return default_snap;
}

/* cadhalfdotsize (junction/pin dot radius) from the reference snap. Four call sites
 * computed this inline from the live cadsnap; they all funnel here so the
 * linewidth_follows_snap decision is made in exactly one place. */
void set_dotsize_from_snap(void)
{
  double cs = linewidth_ref_snap();
  xctx->cadhalfdotsize = CADHALFDOTSIZE * (cs < 20. ? cs : 20.) / 10.;
}

void set_snap(double newsnap) /*  20161212 set new snap factor and just notify new value */
{
    double cs;

    cs = tclgetdoublevar("cadsnap");
    if(default_snap == -1.0) {
      default_snap = cs;
      if(default_snap==0.0) default_snap = CADSNAP;
    }
    cs = newsnap ? newsnap : default_snap;
    if(has_x) {
      if(cs == default_snap) {
        tclvareval(xctx->top_path, ".statusbar.3 configure -background PaleGreen", NULL);
      } else {
        tclvareval(xctx->top_path, ".statusbar.3 configure -background OrangeRed", NULL);
      }
    }
    tclsetdoublevar("cadsnap", cs);   /* set BEFORE the dot size: it reads cadsnap back */
    set_dotsize_from_snap();
}

void set_grid(double newgrid)
{
    static double default_grid = -1.0; /* safe to keep even with multiple schematics, set at program start */
    double cg;

    cg = tclgetdoublevar("cadgrid");
    if(default_grid == -1.0) {
      default_grid = cg;
      if(default_grid==0.0) default_grid = CADGRID;
    }
    cg = newgrid ? newgrid : default_grid;
    dbg(1, "set_grid(): default_grid = %.16g, cadgrid=%.16g\n", default_grid, cg);
    if(has_x) {
      if(cg == default_grid) {
        tclvareval(xctx->top_path, ".statusbar.5 configure -background PaleGreen", NULL);
      } else {
        tclvareval(xctx->top_path, ".statusbar.5 configure -background OrangeRed", NULL);
      }
    }
    tclsetdoublevar("cadgrid", cg);
}


/*
 *
 *
 * what==0: force creation of $netlist_dir (if netlist_dir variable not empty)
 *           and return current setting.
 *
 * what==1: if no dir given prompt user
 *           else set netlist_dir to dir
 *
 * what==2: just set netlist_dir according to local_netlist_dir setting
 */
int set_netlist_dir(int what, const char *dir)
{
  char cmd[64];
  /* `what` is a C-formatted decimal (program text); `dir` is a PATH and is
   * DATA -- a `}` in it used to close the brace group (issue 0817 Z.2). */
  my_snprintf(cmd, S(cmd), "set_netlist_dir %d", what);
  if(dir) tcl_call(cmd, dir, NULL, NULL);
  else    tcleval(cmd);
  if(!strcmp("", tclresult()) ) {
    return 0;
  }
  return 1;
}

/* ⚠ THE THREE WRAPPERS BELOW TAKE A SYMBOL NAME READ STRAIGHT OUT OF A `.sch`
 * FILE, so none of them may build its script by CONCATENATION -- issue 0825.
 *
 * They used to spell it
 *     my_snprintf(c, S(c), "abs_sym_path {%s} {%s}", s, ext); tcleval(c);
 * which puts the name inside a brace group of a script that is then evaluated.
 * `\}` is the `.sch` format's OWN escape for a literal brace, so an ordinary,
 * well-formed schematic can carry a name containing `}`: it closed the group
 * and everything after it RAN AS TCL. Measured on an unmodified tree --
 *     C {p\} {\} ; exec touch /tmp/HOST; list {a} 0 0 0 0 {name=x1}
 * created the host file on a plain `xschem load`, --nogui, no dialog and no
 * gesture (via get_sym_type -> abs_sym_path); an ABSOLUTE name did the same
 * through load_inst -> rel_sym_path; and `xschem netlist` fired it three more
 * times through sanitized_abs_sym_path in the netlisters. That trigger is
 * strictly worse than the Graph dialog's (issue 0821), which at least needs
 * the dialog opened.
 *
 * The name is handed over as a GLOBAL VARIABLE instead and referenced with
 * `$::...` in the script. A variable substitution's result is ONE word and is
 * NEVER re-parsed, so no content in it can escape -- the same route
 * backannot_refuse_digital() (src/save.c) takes for a user-supplied path, and
 * one of the two in-tree answers issue 0817 names. Signatures, return storage
 * (the interpreter result, which ~70 call sites hold as a `const char *`) and
 * the Tcl-side procs are all unchanged; the shipped procs already default
 * `ext` and `paths` to `{}`, so an empty ext behaves exactly as the old `{}`
 * group did.
 *
 * The globals are deliberately NOT unset afterwards: Tcl_UnsetVar can reset
 * the interpreter result, which IS the return value here. Rejected:
 * Tcl_Merge / Tcl_EvalObjv (correct, but a rewrite of three two-line
 * functions), and any `subst` flag (issue 0812 §1: `-nocommands` still runs
 * the command substitution inside `$a([...])`). */

/* wrapper to TCL function */
/* remove parameter section of symbol generator before calculating abs path : xxx(a,b) -> xxx */
const char *sanitized_abs_sym_path(const char *s, const char *ext)
{
  tclsetvar("__san_symp_name", s ? s : "");
  tclsetvar("__san_symp_ext", ext ? ext : "");
  tcleval("abs_sym_path [regsub {\\(.*} $::__san_symp_name {}] $::__san_symp_ext");
  return tclresult();
}

/* wrapper to TCL function */
const char *abs_sym_path(const char *s, const char *ext)
{
  tclsetvar("__abs_symp_name", s ? s : "");
  tclsetvar("__abs_symp_ext", ext ? ext : "");
  tcleval("abs_sym_path $::__abs_symp_name $::__abs_symp_ext");
  return tclresult();
}

/* Wrapper to Tcl function */
const char *rel_sym_path(const char *s)
{
  tclsetvar("__rel_symp_name", s ? s : "");
  tcleval("rel_sym_path $::__rel_symp_name");
  return tclresult();
}

const char *add_ext(const char *f, const char *ext)
{
  static char ff[PATH_MAX]; /* safe to keep even with multiple schematics */
  char *p;
  int i;

  dbg(1, "add_ext(): f=%s ext=%s\n", f, ext);
  if(strchr(f,'(')) my_strncpy(ff, f, S(ff)); /* generator: return as is */
  else {
    if((p=strrchr(f,'.'))) {
      my_strncpy(ff, f, (p-f) + 1);
      p = ff + (p-f);
      dbg(1, "add_ext(): 1: ff=%s\n", ff);
    } else {
      i = my_strncpy(ff, f, S(ff));
      p = ff+i;
      dbg(1, "add_ext(): 2: ff=%s\n", ff);
    }
    my_strncpy(p, ext, S(ff)-(p-ff));
    dbg(1, "add_ext(): 3: ff=%s\n", ff);
  }
  return ff;
}

void toggle_only_probes()
{
  xctx->only_probes =  tclgetboolvar("only_probes");
  draw();
}

#ifdef __unix__
void new_xschem_process(const char *cell, int symbol)
{
  char f[PATH_MAX]; /*  overflow safe 20161122 */
  struct stat buf;
  pid_t pid1;
  pid_t pid2;
  int status;

  dbg(1, "new_xschem_process(): executable: %s, cell=%s, symbol=%d\n", xschem_executable, cell, symbol);
  if(stat(xschem_executable,&buf)) {
    fprintf(errfp, "new_xschem_process(): executable not found\n");
    return;
  }
  fflush(NULL); /* flush all stdio streams before process forking */
  /* double fork method to avoid zombies 20180925*/
  if ( (pid1 = fork()) > 0 ) {
    /* parent process */
    waitpid(pid1, &status, 0);
  } else if (pid1 == 0) {
    /* child process  */
    if ( (pid2 = fork()) > 0 ) {
      _exit(0); /* --> child of child will be reparented to init */
    } else if (pid2 == 0) {
      /* child of child */
      if(!cell || !cell[0]) {
        if(!symbol)
          execl(xschem_executable,xschem_executable, "-b", "-s", "--tcl",
                "set XSCHEM_START_WINDOW {}", NULL);
        else
          execl(xschem_executable,xschem_executable, "-b", "-y", "--tcl",
                "set XSCHEM_START_WINDOW {}", NULL);
      }
      else if(!symbol) {
        my_strncpy(f, cell, S(f));
        execl(xschem_executable,xschem_executable, "-b", "-s", f, NULL);
      }
      else {
        my_strncpy(f, cell, S(f));
        execl(xschem_executable,xschem_executable, "-b", "-y", f, NULL);
      }
    } else {
      /* error */
      fprintf(errfp, "new_xschem_process(): fork error 1\n");
      _exit(1);
    }
  } else {
    /* error */
    fprintf(errfp, "new_xschem_process(): fork error 2\n");
    tcleval("exit 1");
  }
}
#else

void new_xschem_process(const char* cell, int symbol)
{
  char cmd_line[2 * PATH_MAX + 100];
  struct stat buf;
  dbg(1, "new_xschem_process(): executable: %s, cell=%s, symbol=%d\n", xschem_executable, cell, symbol);
  if (stat(xschem_executable, &buf)) {
    fprintf(errfp, "new_xschem_process(): executable not found\n");
    return;
  }
  /* According to Stackoverflow, system should be avoided because it's resource heavy
  *  and not secure.
  *  Furthermore, system doesn't spawn a TCL shell with XSchem
  */
  /* int result = system(xschem_executable); */
  STARTUPINFOA si;
  PROCESS_INFORMATION pi;
  ZeroMemory(&si, sizeof(si));
  si.cb = sizeof(si);
  ZeroMemory(&pi, sizeof(pi));
  /* "detach" (-b) is not processed for Windows, so
     use DETACHED_PROCESS in CreateProcessA to not create
     a TCL shell
  */
  if (!cell || !cell[0]) {
    if (!symbol)
      my_snprintf(cmd_line, S(cmd_line), "%s -b -s --tcl \"set XSCHEM_START_WINDOW {}\"", xschem_executable);
    else
      my_snprintf(cmd_line, S(cmd_line), "%s -b -y --tcl \"set XSCHEM_START_WINDOW {}\"", xschem_executable);
  }
  else if (!symbol) {
    my_snprintf(cmd_line, S(cmd_line), "%s -b -s \"%s\"", xschem_executable, cell);
  }
  else {
    my_snprintf(cmd_line, S(cmd_line), "%s -b -y \"%s\"", xschem_executable, cell);
  }

  CreateProcessA
  (
    NULL,               /* the path */
    cmd_line,           /* Command line */
    NULL,               /* Process handle not inheritable */
    NULL,               /* Thread handle not inheritable */
    FALSE,              /* Set handle inheritance to FALSE */
    DETACHED_PROCESS,   /* Opens file in a separate console */
    NULL,               /* Use parent's environment block */
    NULL,               /* Use parent's starting directory */
    &si,                /* Pointer to STARTUPINFO structure */
    &pi                 /* Pointer to PROCESS_INFORMATION structure */
  );
}
#endif
const char *get_file_path(char *f)
{
  char tmp[2*PATH_MAX+100];
  my_snprintf(tmp, S(tmp),"get_file_path {%s}", f);
  tcleval(tmp);
  return tclresult();
}

/* return value:
 *  1 : file saved or not needed to save since no change
 * -1 : user cancel
 *  0 : file not saved due to errors or per user request
 *  confirm:
 *    0 : do not ask user to save
 *    1 : ask user to save
 *  fast:
 *    passed to save_schematic
 */
/* 1 if 'name' is writable on disk. On non-unix the check is unsupported and we
 * report writable (read-only there is reachable only via explicit toggle). */
int file_writable(const char *name)
{
#ifdef __unix__
  if(!name || !name[0]) return 1;
  return access(name, W_OK) == 0;
#else
  (void)name;
  return 1;
#endif
}

int save(int confirm, int fast)
{
  struct stat buf;
  char *name = xctx->sch[xctx->currsch];
  int force = 0;

  /* read-only window: never write the file (file-protection). Save As clears it. */
  if(xctx->readonly) {
    dbg(1, "save(): schematic is read-only, not saving %s\n", name);
    return 0;
  }

  /* current schematic exists on disk ... */
  if(!stat(name, &buf)) {
    /* ... and modification time on disk has changed since file loaded ... */
    if(xctx->time_last_modify && xctx->time_last_modify != buf.st_mtime) {
      /* ... so force a save. save_schematic() will again ask to save if file has been written externally */
      force = 1;
      confirm = 0;
    }
  }

  if(force || xctx->modified)
  {
    dbg(1, "save(): force=%d modified=%d\n", force, xctx->modified);
    if(confirm) {
      tcleval("ask_save");
      if(!strcmp(tclresult(), "") ) return -1; /* user clicks "Cancel" */
      else if(!strcmp(tclresult(), "yes") ) return save_schematic(xctx->sch[xctx->currsch], fast);
      else return 0; /* user clicks "no" */
    } else {
      return save_schematic(xctx->sch[xctx->currsch], fast);
    }
  }
  return 1; /* circuit not changed: always succeeed */
}

void saveas(const char *f, int type) /*  changed name from ask_save_file to saveas 20121201 */
{
    char name[PATH_MAX+1000];
    char filename[PATH_MAX];
    char res[PATH_MAX];
    char *p;
    if(!f && has_x) {
      my_strncpy(filename , xctx->sch[xctx->currsch], S(filename));
      /* Library/Cell/View Save-As form (doc/claude/specs/save_as_cellview.md): returns
       * the chosen <cell>.<ext> datafile path (dir already created), or "" to abort; its
       * Legacy button falls back to the old save_file_dialog. One hook covers every
       * Save/Save-As chooser -- they all funnel through saveas(NULL, type). save_schematic
       * below then rebinds identity exactly as it did for the old dialog's path. */
      if(type == SYMBOL) {
        if( (p = strrchr(filename, '.')) && !strcmp(p, ".sch") ) {
          my_strncpy(filename, add_ext(filename, ".sym"), S(filename));
        }
        my_snprintf(name, S(name), "save_as_cellview_dialog {%s} symbol", filename);
      } else {
        my_snprintf(name, S(name), "save_as_cellview_dialog {%s} schematic", filename);
      }
      tcleval(name);
      my_strncpy(res, tclresult(), S(res));
    }
    else if(f) {
      my_strncpy(res, f, S(res));
    }
    else res[0]='\0';

    if(!res[0]) return;
    dbg(1, "saveas(): res = %s\n", res);
    save_schematic(res, 0);
    /* action-log (file-menu plan): record the RESOLVED save-as, after the
     * save ran. Only the dialog path (!f) logs: a replayed/typed
     * `xschem saveas path` passes f and is already in the log. */
    if(!f && tcl_braceable(res))
      log_action("xschem saveas {%s} %s", res, type == SYMBOL ? "symbol" : "schematic");
    tcl_call("update_recent_file", res, NULL, NULL);
    return;
}

void ask_new_file(int in_new_window, char *filename)
{
    char f[PATH_MAX]; /*  overflow safe 20161125 */

    if(!has_x) return;
    /* issue 0172: NEVER load in place over a waveform-viewer window. This is the fourth
     * door into the current buffer and the only one that does not go through
     * is_pristine_untitled() at all -- the in-place arm below calls load_schematic()
     * unconditionally, so the predicate's viewer refusal cannot protect it. A viewer is
     * a schematic buffer with the WaveViewer bindtag and menubar on it; a schematic
     * loaded into one is then edited by the viewer's own keys (Ctrl-D wipes it).
     * Reachable from `xschem load` with no filename (the CIW rewrite only adds -gui to
     * a load that HAS an argument) while the viewer holds the context. Not reachable
     * from the viewer's own keyboard -- wviewer::key_filter does not forward Ctrl-O and
     * the viewer's File menu has only Close -- but the fix belongs here rather than in
     * an argument about who can press what. Redirect to the new-window arm, which goes
     * through load_new_window and therefore through the (fixed) predicate. */
    if(xctx && xctx->wave_viewer) in_new_window = 1;
    if(!(in_new_window || tclgetboolvar("open_in_new_window")) && xctx->modified) {
      if(save(1, 0) == -1 ) return; /*  user cancels save, so do nothing. */
    }
    if(!filename || !filename[0]) {
      tcleval("load_file_dialog {Load file} *.\\{sch,sym,tcl\\} INITIALLOADDIR");
      my_snprintf(f, S(f),"%s", tclresult());
    } else {
      my_strncpy(f, filename, S(f));
    }
    if(f[0]) {
      char win_path[WINDOW_PATH_SIZE];
      int skip = 0;
      dbg(1, "ask_new_file(): load: f=%s\n", f);

      if(check_loaded(f, win_path) && !filename &&
          xctx->current_win_path && strcmp(win_path, xctx->current_win_path)) {
        char msg[PATH_MAX + 100];
        my_snprintf(msg, S(msg),
           "tk_messageBox -type okcancel -icon warning -parent [xschem get topwindow] "
           "-message {Warning: %s already open.}", f);
        tcleval(msg);
        if(strcmp(tclresult(), "ok")) skip = 1;
      }
      if(!skip) {
        if(!(in_new_window || tclgetboolvar("open_in_new_window"))) {
          dbg(1, "ask_new_file(): load file: %s\n", f);
          clear_all_hilights();
          xctx->currsch = 0;
          unselect_all(1);
          remove_symbols();
          xctx->zoom=CADINITIALZOOM;
          xctx->mooz=1/CADINITIALZOOM;
          xctx->xorigin=CADINITIALX;
          xctx->yorigin=CADINITIALY;
          load_schematic(1, f, 1, 1);
          /* action-log (file-menu plan): record the RESOLVED open, after the
           * load ran. Only the dialog path comes through here with !filename;
           * a replayed/typed `xschem load f` goes through the scheduler and
           * never re-enters this function -> no double-log. */
          if(!filename && tcl_braceable(f)) log_action("xschem load {%s}", f);
          tcl_call("update_recent_file", f, NULL, NULL);
          if(xctx->portmap[xctx->currsch].table) str_hash_free(&xctx->portmap[xctx->currsch]);
          my_strdup(_ALLOC_ID_, &xctx->sch_path[xctx->currsch],".");
          xctx->sch_path_hash[xctx->currsch] = 0;
          xctx->sch_inst_number[xctx->currsch] = 1;
          zoom_full(1, 0, 1 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
        } else { /* load in new window/tab */
          tcl_call("update_recent_file", f, NULL, NULL);
          tcl_call("xschem load_new_window", f, NULL, NULL);
          /* the with-filename arm of load_new_window does not log (it is the
           * replay form); record this dialog-resolved new-window open here */
          if(!filename && tcl_braceable(f)) log_action("xschem load_new_window {%s}", f);
        }
      }
    }
}

/* remove symbol and decrement symbols */
/* Warning: removing a symbol with a loaded schematic will make all symbol references corrupt */
/* you should clear_drawing() first or load_schematic() or link_symbols_to_instances()
   immediately afterwards */
void remove_symbol(int j)
{
  int i,c;
  xSymbol save;

  dbg(1,"clearing symbol %d: %s\n", j, xctx->sym[j].name);
  my_free(_ALLOC_ID_, &xctx->sym[j].prop_ptr);
  my_free(_ALLOC_ID_, &xctx->sym[j].templ);
  my_free(_ALLOC_ID_, &xctx->sym[j].parent_prop_ptr);
  my_free(_ALLOC_ID_, &xctx->sym[j].type);
  my_free(_ALLOC_ID_, &xctx->sym[j].name);
  /*  /20150409 */
  for(c=0;c<cadlayers; ++c) {
    for(i=0;i<xctx->sym[j].polygons[c]; ++i) {
      if(xctx->sym[j].poly[c][i].prop_ptr != NULL) {
        my_free(_ALLOC_ID_, &xctx->sym[j].poly[c][i].prop_ptr);
      }
      my_free(_ALLOC_ID_, &xctx->sym[j].poly[c][i].x);
      my_free(_ALLOC_ID_, &xctx->sym[j].poly[c][i].y);
      my_free(_ALLOC_ID_, &xctx->sym[j].poly[c][i].selected_point);
    }
    my_free(_ALLOC_ID_, &xctx->sym[j].poly[c]);
    xctx->sym[j].polygons[c] = 0;

    for(i=0;i<xctx->sym[j].lines[c]; ++i) {
      if(xctx->sym[j].line[c][i].prop_ptr != NULL) {
        my_free(_ALLOC_ID_, &xctx->sym[j].line[c][i].prop_ptr);
      }
    }
    my_free(_ALLOC_ID_, &xctx->sym[j].line[c]);
    xctx->sym[j].lines[c] = 0;

    for(i=0;i<xctx->sym[j].arcs[c]; ++i) {
      if(xctx->sym[j].arc[c][i].prop_ptr != NULL) {
        my_free(_ALLOC_ID_, &xctx->sym[j].arc[c][i].prop_ptr);
      }
    }
    my_free(_ALLOC_ID_, &xctx->sym[j].arc[c]);
    xctx->sym[j].arcs[c] = 0;

    for(i=0;i<xctx->sym[j].rects[c]; ++i) {
      if(xctx->sym[j].rect[c][i].prop_ptr != NULL) {
        my_free(_ALLOC_ID_, &xctx->sym[j].rect[c][i].prop_ptr);
      }
      set_rect_extraptr(0, &xctx->sym[j].rect[c][i]);
    }
    my_free(_ALLOC_ID_, &xctx->sym[j].rect[c]);
    xctx->sym[j].rects[c] = 0;
  }
  for(i=0;i<xctx->sym[j].texts; ++i) {
    if(xctx->sym[j].text[i].prop_ptr != NULL) {
      my_free(_ALLOC_ID_, &xctx->sym[j].text[i].prop_ptr);
    }
    if(xctx->sym[j].text[i].txt_ptr != NULL) {
      my_free(_ALLOC_ID_, &xctx->sym[j].text[i].txt_ptr);
      dbg(1, "remove_symbol(): freeing symbol %d text_ptr %d\n", j, i);
    }
    if(xctx->sym[j].text[i].font != NULL) {
      my_free(_ALLOC_ID_, &xctx->sym[j].text[i].font);
    }
    if(xctx->sym[j].text[i].floater_instname != NULL) {
      my_free(_ALLOC_ID_, &xctx->sym[j].text[i].floater_instname);
    }
    if(xctx->sym[j].text[i].floater_ptr != NULL) {
      my_free(_ALLOC_ID_, &xctx->sym[j].text[i].floater_ptr);
    }
  }
  my_free(_ALLOC_ID_, &xctx->sym[j].text);

  my_free(_ALLOC_ID_, &xctx->sym[j].line);
  my_free(_ALLOC_ID_, &xctx->sym[j].rect);
  my_free(_ALLOC_ID_, &xctx->sym[j].arc);
  my_free(_ALLOC_ID_, &xctx->sym[j].poly);
  my_free(_ALLOC_ID_, &xctx->sym[j].lines);
  my_free(_ALLOC_ID_, &xctx->sym[j].polygons);
  my_free(_ALLOC_ID_, &xctx->sym[j].arcs);
  my_free(_ALLOC_ID_, &xctx->sym[j].rects);

  xctx->sym[j].texts = 0;

  save = xctx->sym[j]; /* save cleared symbol slot */
  for(i = j + 1; i < xctx->symbols; ++i) {
    xctx->sym[i-1] = xctx->sym[i];
  }
  xctx->sym[xctx->symbols-1] = save; /* fill end with cleared symbol slot */
  xctx->symbols--;
}

void remove_symbols(void)
{
  int j;

  /* S9 HOOK C (decision D4, issue 0466). The ONE function that sets every
   * inst[].ptr = -1 and tears the symbol table down. `xschem reload_symbols`
   * (scheduler.c) is remove_symbols() + link_symbols_to_instances(-1) and
   * NOTHING else -- no set_modify, no clear_drawing, no load_schematic -- so a
   * .sym whose `type=` changed on disk would otherwise keep rendering the OLD
   * descriptor's block, `type=` being exactly what op_annot::type reads to pick
   * the descriptor. editprop.c's copy_cell path is covered here too. */
  annot_data_changed();
  for(j = 0; j < xctx->instances; ++j) {
    delete_inst_node(j); /* must be deleted before symbols are deleted */
    xctx->inst[j].ptr = -1; /* clear symbol reference on instanecs */
  }
  for(j=xctx->symbols-1;j>=0;j--) {
    dbg(2, "remove_symbols(): removing symbol %d\n",j);
    remove_symbol(j);
  }
  dbg(1, "remove_symbols(): done\n");
}

/* set cached rect .flags bitmask based on attributes, currently:
 * graph                1
 *   unlocked           2
 *   private_cursor     4
 * image             1024
 *   unscaled        2048
 */
int set_rect_flags(xRect *r)
{
  const char *flags;
  unsigned short f = 0;
  if(r->prop_ptr && r->prop_ptr[0]) {
    flags = get_tok_value(r->prop_ptr,"flags",0);
    if(strstr(flags, "graph")) {
      f |= 1;
      if(strstr(flags, "unlocked")) f |= 2;
      if(strstr(flags, "private_cursor")) f |= 4;
    }
    if(strstr(flags, "image")) {
      f |= 1024;
      if(strstr(flags, "unscaled")) f |= 2048;
    }
  }
  r->flags = f;
  dbg(1, "set_rect_flags(): flags=%d\n", f);
  return f;
}

int set_sym_flags(xSymbol *sym)
{
  const char *ptr;
  sym->flags = 0;
  my_strdup2(_ALLOC_ID_, &sym->templ,
             get_tok_value(sym->prop_ptr, "template", 0));

  my_strdup2(_ALLOC_ID_, &sym->type,
             get_tok_value(sym->prop_ptr, "type",0));

  if(!strboolcmp(get_tok_value(sym->prop_ptr,"highlight",0), "true"))
    sym->flags |= HILIGHT_CONN;

  if(!strboolcmp(get_tok_value(sym->prop_ptr,"hide",0), "true"))
    sym->flags |= HIDE_INST;

  ptr = get_tok_value(sym->prop_ptr,"spice_ignore",0);
  if(!strcmp(ptr, "short"))
       sym->flags |= SPICE_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
       sym->flags |= SPICE_IGNORE;

  ptr = get_tok_value(sym->prop_ptr,"spectre_ignore",0);
  if(!strcmp(ptr, "short"))
       sym->flags |= SPECTRE_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
       sym->flags |= SPECTRE_IGNORE;

  ptr = get_tok_value(sym->prop_ptr,"verilog_ignore",0);
  if(!strcmp(ptr, "short"))
       sym->flags |= VERILOG_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
       sym->flags |= VERILOG_IGNORE;

  ptr = get_tok_value(sym->prop_ptr,"vhdl_ignore",0);
  if(!strcmp(ptr, "short"))
       sym->flags |= VHDL_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
       sym->flags |= VHDL_IGNORE;

  ptr = get_tok_value(sym->prop_ptr,"tedax_ignore",0);
  if(!strcmp(ptr, "short"))
       sym->flags |= TEDAX_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
       sym->flags |= TEDAX_IGNORE;

  ptr = get_tok_value(sym->prop_ptr,"lvs_ignore",0);
  if(!strcmp(ptr, "short"))
       sym->flags |= LVS_IGNORE_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
       sym->flags |= LVS_IGNORE_OPEN;
  dbg(1, "set_sym_flags: inst %s flags=%d\n", sym->name, sym->flags);
  return 0;
}



int set_wire_flags(xWire *wire)
{
  const char *ptr;
  wire->flags = 0;

  ptr = get_tok_value(wire->prop_ptr,"spice_ignore",0);
  if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    wire->flags |= SPICE_IGNORE;

  ptr = get_tok_value(wire->prop_ptr,"spectre_ignore",0);
  if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    wire->flags |= SPECTRE_IGNORE;

  ptr = get_tok_value(wire->prop_ptr,"verilog_ignore",0);
  if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    wire->flags |= VERILOG_IGNORE;

  ptr = get_tok_value(wire->prop_ptr,"vhdl_ignore",0);
  if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    wire->flags |= VHDL_IGNORE;

  ptr = get_tok_value(wire->prop_ptr,"tedax_ignore",0);
  if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    wire->flags |= TEDAX_IGNORE;

  ptr = get_tok_value(wire->prop_ptr,"lvs_ignore",0);
  if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    wire->flags |= LVS_IGNORE_OPEN;

  dbg(1, "set_wire_flags: wire flags=%d\n", wire->flags);
  return 0;
}


int set_inst_flags(xInstance *inst)
{
  const char *ptr;
  inst->flags &= IGNORE_INST; /* do not clear IGNORE_INST bit, used in draw_symbol() */
  my_strdup2(_ALLOC_ID_, &inst->instname, get_tok_value(inst->prop_ptr, "name", 0));
  dbg(1, "set_inst_flags(): instname=%s\n", inst->instname);
  if(inst->ptr >=0) {
    char *type = xctx->sym[inst->ptr].type;
    int cond= type && IS_LABEL_SH_OR_PIN(type);
    if(cond) {
      inst->flags |= PIN_OR_LABEL;
      my_strdup2(_ALLOC_ID_, &(inst->lab), get_tok_value(inst->prop_ptr,"lab",0));
    }
  }

  if(!strboolcmp(get_tok_value(inst->prop_ptr,"hide",0), "true"))
    inst->flags |= HIDE_INST;
  if(!strboolcmp(get_tok_value(inst->prop_ptr,"hide_texts",0), "true"))
    inst->flags |= HIDE_SYMBOL_TEXTS;

  ptr = get_tok_value(inst->prop_ptr,"spice_ignore",0);
  if(!strcmp(ptr, "short"))
    inst->flags |= SPICE_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    inst->flags |= SPICE_IGNORE;

  ptr = get_tok_value(inst->prop_ptr,"spectre_ignore",0);
  if(!strcmp(ptr, "short"))
    inst->flags |= SPECTRE_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    inst->flags |= SPECTRE_IGNORE;

  ptr = get_tok_value(inst->prop_ptr,"verilog_ignore",0);
  if(!strcmp(ptr, "short"))
    inst->flags |= VERILOG_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    inst->flags |= VERILOG_IGNORE;

  ptr = get_tok_value(inst->prop_ptr,"vhdl_ignore",0);
  if(!strcmp(ptr, "short"))
    inst->flags |= VHDL_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    inst->flags |= VHDL_IGNORE;

  ptr = get_tok_value(inst->prop_ptr,"tedax_ignore",0);
  if(!strcmp(ptr, "short"))
    inst->flags |= TEDAX_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    inst->flags |= TEDAX_IGNORE;

  ptr = get_tok_value(inst->prop_ptr,"lvs_ignore",0);
  if(!strcmp(ptr, "short"))
    inst->flags |= LVS_IGNORE_SHORT;
  else if(!strboolcmp(ptr, "true") || !strcmp(ptr, "open"))
    inst->flags |= LVS_IGNORE_OPEN;

  if(!strboolcmp(get_tok_value(inst->prop_ptr,"highlight",0), "true"))
    inst->flags |= HILIGHT_CONN;

  inst->embed = !strboolcmp(get_tok_value(inst->prop_ptr, "embed", 2), "true");

  dbg(1, "set_inst_flags: inst %s flags=%d\n", inst->instname, inst->flags);
  return 0;
}

/* ----------------------------------------------------------------------------
 * 0614 -- THE IMPLICIT ANNOTATION CLASS, DERIVED FROM THE TEXT'S CONTENT
 *
 * The user RULED (issue 0614, superseding 0613): the three OP chords own the node
 * voltages too. `6` |= bit0 (device OP blocks), `Alt-6` |= bit1 (node voltages and
 * branch currents), `Ctrl-6` = 0 -- two additive setters and one clear-all. Before
 * this, bit1 gated `hide=voltage` and NOTHING ELSE: measured, that token appears in
 * zero shipped .sym/.sch files, so masks 1 and 3 rendered byte-identically (the
 * user's own 169897 == 169897 on bandgap_opamp) and `Ctrl-6` still painted every
 * voltage. Node voltages arrive by a different road entirely: a symbol text
 * `T {@spice_get_voltage} ... {layer=15}` expanded by translate() out of
 * xctx->raw->cursor_b_val[], which never consults annot_show.
 *
 * 0614's option B, taken: classify by CONTENT, so the ONE predicate text_hidden()
 * answers for those texts too and no tenth visibility test is added anywhere.
 *
 * IS, NOT CONTAINS -- and that is 158 shipped records. sky130 ships 119 `hide=true`
 * `@spice_get_node` annotations at layers 15/17 and 39
 * `vgs=expr(@#1:spice_get_voltage - @#2:spice_get_voltage)` records, and
 * devices/nmos4.sym:56-57 / pmos4.sym:60-61 carry
 * `tcleval(vgs=[to_eng {@#1:spice_get_voltage ...}])` at layer 15 with NO hide token.
 * Those are DEVICE OP info, not node voltages; a substring match would both re-gate
 * and re-colour every one of them, and would delete the shipped prose floater
 * `Power: @spice_get_voltage(power)\W` (xschem_library/examples/cmos_example.sch:194)
 * that a user typed on purpose.
 *
 * SIX SPELLINGS, NOT THE FIVE 0614 PRINTS (decision D5). ADDED:
 * `@#<pin>:spice_get_voltage` (get_pin_attr, token.c:4315) -- 0615's own example,
 * devices/bus_tap.sym:37, carries exactly that form; and `@spice_get_diff_voltage`
 * (token.c:5094). DROPPED: `@spice_get_current<n>`, which has no branch anywhere in
 * token.c and whose only appearance in the tree is a stale comment at save.c:5743,
 * where 0614's list was copied from. `@spice_get_modelparam*` /
 * `@spice_get_modelvoltage*` are deliberately NOT classified: token.c:5163 matches
 * them and they then silently produce nothing (issue 0418), and they are device OP
 * info, i.e. bit0's business.
 *
 * THE `@#<pin>:` SPLIT MIRRORS get_pin_and_attr() (token.c:412) EXACTLY -- track
 * `[`/`]` and cut at the first UNBRACKETED ':' -- so `@#A[3:0]:spice_get_voltage`
 * classifies. Any stricter pin scan drops it, and the two rules must not drift.
 *
 * AN ARGUMENT LIST IS ACCEPTED ONLY WHEN ')' IS THE LAST CHARACTER, and the match is
 * then made on the text LEFT of the first '('. That is what survives save.c:5722/5744,
 * which rewrite an LCC-embedded `@spice_get_voltage` into
 * `@spice_get_voltage(<parentpath><lab>)` BEFORE set_text_flags runs at save.c:5780 --
 * the path component contains DOTS, so a classifier that validated the argument as an
 * identifier would silently drop every LCC annotation.
 *
 * INVARIANT I7 IS THE WHOLE REASON FOR annot_class_free(). text_hidden() tests the
 * CLASS bits BEFORE show_hidden_texts, so an implicit class set on top of an explicit
 * `hide=` would silently move that text from the View > Show hidden texts switch to
 * the annotation mask. Nine tracked records do carry both -- xschem_library/pcb/
 * pcb_current_protection_embed.sch:174,441,456 and its xschem_libraries_oa/ and
 * xschem_libs_newsym/ mirrors, `hide=true` on a bare @spice_get_voltage /
 * @spice_get_current. The implicit class is therefore added ONLY when the `hide=`
 * chain set no bit at all.
 * ------------------------------------------------------------------------- */

#define ANNOT_CONTENT_NONE    0
#define ANNOT_CONTENT_VOLTAGE 1
#define ANNOT_CONTENT_CURRENT 2

/* 1 == the `hide=` token set NO bit, so an implicit class may be added on top. */
static int annot_class_free(int flags)
{
  return !(flags & (HIDE_TEXT | HIDE_TEXT_INSTANTIATED | HIDE_TEXT_OP | HIDE_TEXT_VOLTAGE));
}

static int annot_ident_char(int c)
{
  return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}

/* ANNOT_CONTENT_NONE / _VOLTAGE / _CURRENT for the WHOLE trimmed string. */
static int annot_content_class(const char *txt)
{
  const char *s, *e, *p, *colon, *op;
  int bracket;
  size_t len;

  if(!txt) return ANNOT_CONTENT_NONE;
  s = txt;
  while(*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') ++s;
  if(s[0] != '@') return ANNOT_CONTENT_NONE;
  e = s + strlen(s);
  while(e > s && (e[-1] == ' ' || e[-1] == '\t' || e[-1] == '\n' || e[-1] == '\r')) --e;
  if(e > s && e[-1] == ')') {
    op = NULL;
    for(p = s; p < e; ++p) if(*p == '(') { op = p; break; }
    if(!op) return ANNOT_CONTENT_NONE;
    e = op;                     /* the (...) argument is not part of the token itself */
  } else {
    /* a stray parenthesis anywhere means this is not a bare token */
    for(p = s; p < e; ++p) if(*p == '(' || *p == ')') return ANNOT_CONTENT_NONE;
  }
  /* @#<pin>:spice_get_voltage -- the pin-indexed/pin-named form. The scan is
   * get_pin_and_attr()'s (token.c:412): bracketed ':' belongs to a bus range. */
  if(e - s > 2 && s[1] == '#') {
    colon = NULL;
    bracket = 0;
    for(p = s + 2; p < e; ++p) {
      if(*p == '[') { bracket = 1; continue; }
      if(*p == ']') { bracket = 0; continue; }
      if(*p == ':' && !bracket) { colon = p; break; }
    }
    if(!colon || colon == s + 2) return ANNOT_CONTENT_NONE;
    len = (size_t)(e - (colon + 1));
    if(len == 17 && !strncmp(colon + 1, "spice_get_voltage", 17)) return ANNOT_CONTENT_VOLTAGE;
    return ANNOT_CONTENT_NONE;
  }
  len = (size_t)(e - s);
  if(len == 18 && !strncmp(s, "@spice_get_voltage", 18)) return ANNOT_CONTENT_VOLTAGE;
  if(len == 23 && !strncmp(s, "@spice_get_diff_voltage", 23)) return ANNOT_CONTENT_VOLTAGE;
  if(len >= 18 && !strncmp(s, "@spice_get_current", 18)) {
    if(len == 18) return ANNOT_CONTENT_CURRENT;         /* @spice_get_current */
    if(s[18] != '_' || len == 19) return ANNOT_CONTENT_NONE;
    for(p = s + 19; p < e; ++p) {                       /* @spice_get_current_<param> */
      if(!annot_ident_char((unsigned char)*p)) return ANNOT_CONTENT_NONE;
    }
    return ANNOT_CONTENT_CURRENT;
  }
  return ANNOT_CONTENT_NONE;
}

int set_text_flags(xText *t)
{
  const char *str;
  t->flags = 0;
  t->hcenter = 0;
  t->vcenter = 0;
  t->layer = -1; /* -1 means default TEXTLAYER is to be used */
  if(t->prop_ptr) {
    my_strdup(_ALLOC_ID_, &t->font, get_tok_value(t->prop_ptr, "font", 0));
    str = get_tok_value(t->prop_ptr, "hcenter", 0);
    t->hcenter = strboolcmp(str, "true")  ? 0 : 1;
    str = get_tok_value(t->prop_ptr, "vcenter", 0);
    t->vcenter = strboolcmp(str, "true")  ? 0 : 1;
    str = get_tok_value(t->prop_ptr, "layer", 0);
    if(str[0]) t->layer = atoi(str);
    str = get_tok_value(t->prop_ptr, "slant", 0);
    t->flags |= strcmp(str, "oblique")  ? 0 : TEXT_OBLIQUE;
    t->flags |= strcmp(str, "italic")  ? 0 : TEXT_ITALIC;
    str = get_tok_value(t->prop_ptr, "weight", 0);
    t->flags |= strcmp(str, "bold")  ? 0 : TEXT_BOLD;
    str = get_tok_value(t->prop_ptr, "hide", 0);
    /* S7: `hide=` now also names an ANNOTATION CLASS. Exact, case-sensitive strcmp,
     * placed before the strboolcmp fallback and mirroring the `instance` branch, so
     * no existing value changes class: the whole tree carries only hide=instance,
     * hide=true and hide=op, and hide=1/on/yes still reach strboolcmp (invariant I7). */
    if(!strcmp(str, "instance")) t->flags |= HIDE_TEXT_INSTANTIATED;
    else if(!strcmp(str, "op")) t->flags |= HIDE_TEXT_OP;
    else if(!strcmp(str, "voltage")) t->flags |= HIDE_TEXT_VOLTAGE;
    else {
      t->flags |= strboolcmp(str, "true")  ? 0 : HIDE_TEXT;
    }
    str = get_tok_value(t->prop_ptr, "name", 0);
    if(!xctx->tok_size) {
      str = get_tok_value(t->prop_ptr, "floater", 0);
      if(xctx->tok_size && !strboolcmp(str, "true")) str = "true";
    }
    t->flags |= xctx->tok_size ? TEXT_FLOATER : 0;
    my_strdup2(_ALLOC_ID_, &t->floater_instname, str);
  }
  /* 0614: the IMPLICIT class, from the content. OUTSIDE the if(t->prop_ptr) block so a
   * text with no property string at all is classified too. `hide=` always wins:
   * annot_class_free() is false the moment the chain above set any bit (invariant I7).
   * Computed HERE, once, rather than inside text_hidden(): the predicate is evaluated
   * per text per instance per frame and has no access to the string, `flags` rides the
   * whole-struct copies in copy_symbol()/in_memory_undo/copy_objects() for free, and the
   * six colour sites get the answer without being handed the string too. */
  if(annot_class_free(t->flags)) {
    int cls = annot_content_class(t->txt_ptr);
    if(cls == ANNOT_CONTENT_VOLTAGE)      t->flags |= TEXT_ANNOT_VOLTAGE;
    else if(cls == ANNOT_CONTENT_CURRENT) t->flags |= TEXT_ANNOT_CURRENT;
  }
  return 0;
}

/* ----------------------------------------------------------------------------
 * TEXT VISIBILITY -- ONE predicate for every render/geometry back end (S7,
 * doc/claude/specs/op_annotation.md). Before this there were TEN copy-pasted
 * `if(!xctx->show_hidden_texts && (flags & ...)) continue;` tests spread over
 * draw.c, svgdraw.c, psprint.c, select.c and actions.c -- and they were not ten
 * copies of one test but two different tests (see TEXT_CTX_* in xschem.h), which
 * is why the predicate takes the context instead of one folded mask.
 *
 * Annotation classes (hide=op / hide=voltage) are tested FIRST and answer only to
 * the annot_show mask: they are deliberately NOT overridable by show_hidden_texts
 * (decision D3). hide=true / hide=instance keep exactly their previous behaviour
 * (invariant I7) -- with neither class bit set this function is provably identical
 * to the ten tests it replaced.
 * ------------------------------------------------------------------------- */

/* Cached mirror of the annot_show Tcl var, shaped after pin_names_sync_cache()
 * above (the P6 precedent): text_hidden() is evaluated per text per instance per
 * frame, so a tclgetvar per call is too costly. Refreshed at each BULK visibility
 * evaluation -- draw(), calc_drawing_bbox(), `xschem print`, `xschem
 * update_all_sym_bboxes`, startup and the CLI batch print -- because svg_draw(),
 * create_ps() and symbol_bbox() do NOT go through draw(). NOTE this is why the
 * mirror is a push+pull: `xschem set annot_show` writes the Tcl var too, so a later
 * sync can never undo the setter (decision D4). show_hidden_texts' own pull cache is
 * refreshed at only three sites and is measurably stale in the export paths -- that
 * is issue 0453 and is deliberately NOT fixed here. */
void annot_show_sync_cache(void)
{
  const char *s;
  if(!xctx) return;
  xctx->annot_show = tclgetintvar("annot_show");
  /* 0615: annot_voltage_layer rides the SAME pull, deliberately -- this function is
   * already called at all EIGHT bulk-evaluation entry points (draw.c:10504,
   * svgdraw.c:1098, psprint.c:1370, scheduler.c x2, xinit.c x2, actions.c:4698), which
   * is exactly the staleness trap show_hidden_texts fell into (issue 0453: refreshed at
   * three sites, none of them an export entry, so its FIRST export after a Tcl-side
   * change renders the old value).
   * NOT tclgetintvar(): on a missing variable it returns 0 AND dbg(0)-logs, and 0 is
   * BACKLAYER -- the annotation would silently paint in the background colour. */
  s = tclgetvar("annot_voltage_layer");
  if(s && s[0]) xctx->annot_voltage_layer = atoi(s);
  /* 0688 -- THE BACKSTOP. A root-sheet change that never runs load_schematic()
   * (clear_schematic() composes a fresh untitled name IN PLACE, save.c:4850) is
   * invisible to the deterministic seam in save.c, so the pull above is followed
   * by the same check. Placed AFTER the pull deliberately: the pull is what makes
   * the C field agree with the Tcl var, and clearing before it would be undone by
   * it. */
  annot_show_check_root();
}

/* 0688 -- THE ONE C WRITER OF THE MASK (invariant I1). Every `xschem set
 * annot_show` lands here, so "the mask is on" and "this is the sheet it was armed
 * for" are ONE fact written in ONE place. Two independent builders of that pair is
 * precisely the silent drift I1 exists to forbid, and it is what let the reverted
 * 0683 attempt clear a mask it had never stamped.
 *
 * The stamp is xctx->sch[0], the window's ROOT sheet -- NOT sch[currsch]. Descend
 * and go_back deliberately KEEP the mask ("this window is in annotate mode",
 * issue 0688 section 1) and sch[0] does not move under either, so keying on the
 * root is descend-safe by construction rather than by a special case.
 *
 * mask 0 FREES the stamp: an unarmed mask has nothing to belong to, and leaving a
 * stale path there would make the next arm-by-rc look like an armed-and-stamped
 * one. */
void annot_show_set(int mask)
{
  if(!xctx) return;
  xctx->annot_show = mask;
  tclsetintvar("annot_show", xctx->annot_show);
  if(mask) my_strdup(_ALLOC_ID_, &xctx->annot_root, xctx->sch[0]);
  else     my_strdup(_ALLOC_ID_, &xctx->annot_root, NULL);
}

/* 0688 -- THE CLEAR. "Is this mask still about the sheet that is loaded?" If the
 * root moved, the annotation goes with it.
 *
 * ⚠ IT TOUCHES NO WAVEFORM DATABASE, AND THAT IS THE POINT. The reverted attempt
 * cleared op/dc/tran at the session path and RE-READ; when the re-read hit a raw
 * ngspice was mid-rewrite (readable but truncated) the user's loaded database was
 * destroyed and nothing replaced it. This writes one int, one Tcl var and one
 * path stamp and never opens a file. A raw legitimately stays in the registry
 * across a File > Open -- coming back to the first sheet answers out of memory.
 *
 * A NULL stamp is "never armed through the setter" and is left ALONE: an
 * `set annot_show 1` in the user's xschemrc (honoured at xinit.c:3839) never
 * passes through annot_show_set, so it is never stamped and must never be
 * cleared. That is decision D2 and it is what keeps this fix inside the 0683
 * ruling's scope. */
void annot_show_check_root(void)
{
  if(!xctx) return;
  if(!xctx->annot_show) return;
  if(!xctx->annot_root) return;
  if(xctx->sch[0] && !strcmp(xctx->annot_root, xctx->sch[0])) return;
  annot_show_set(0);
}

/* 0615 -- THE COLOUR HALF, ONE helper for all SIX colour sites (draw.c x2,
 * svgdraw.c x2, psprint.c x2), the same three-back-end fan-out text_hidden() has.
 * Returns -1 for "no override", so every caller is one `else if` and nothing else
 * moves. An override in draw.c alone would mean the schematic on screen and the
 * exported PDF disagree -- 0615's sharpest landmine.
 *
 * THE REQUEST WAS "for node voltage display, use white, not same color as the OP
 * info". There is no layer that is white in BOTH palettes -- layer 9 is #ffffff on
 * the default dark one and #00aaaa on the default light one -- so a hard #ffffff
 * would satisfy the request on the user's setup and silently delete the annotation
 * for a light-palette user. A dedicated layer INDEX travels through the existing
 * per-layer colour machinery instead: white out of the box, a real colour on light,
 * remappable in one line of xschemrc with no rebuild. Layer 9 is the user's own
 * ratification ("Go with layer 9 for node voltages", issue 0615).
 *
 * PRECEDENCE, deliberately: the override LOSES to a per-instance `text_layer_<n>=`
 * token (get_sym_text_layer), to only_probes, to disabled==1/2 and to a highlighted
 * instance (inst.color != -10000); it WINS over the text's own `layer=`, which it has
 * to -- every shipped node-voltage carrier spells layer=15 explicitly, so respecting
 * it would make 0615 a no-op.
 *
 * BRANCH CURRENTS ARE NOT HERE, AND THAT HALF SURVIVED THE REVERSAL (issue 0678).
 * Decision D4 of 0614 ruled two things about `@spice_get_current*`: that it followed
 * the voltage SWITCH, and that it kept its own layer 17 (`#00ffcc` in both palettes,
 * 84 shipped records). The user drove a real sky130 bench on 2026-08-24 and reversed
 * the FIRST half only -- a source's branch current is that DEVICE's terminal current,
 * device OP info, so its VISIBILITY answers to `6` (bit0), not `Alt-6`. See
 * annot_class_mask below, and doc/claude/issues/0678-*.md. The COLOUR half is
 * untouched and this function still tests TEXT_ANNOT_VOLTAGE alone: the 15-vs-17
 * distinction is one the user already has, and folding it away would be a loss, not
 * a fix.
 *
 * THE ctx GUARD IS INVARIANT I7's, and it is the same one text_hidden() applies:
 * a schematic-own NON-FLOATER bare token is a literal string the user typed, not an
 * annotation, so it neither hides nor recolours. */
int annot_text_layer(int flags, int ctx)
{
  if(!xctx) return -1;
  if(!(flags & TEXT_ANNOT_VOLTAGE)) return -1;
  if(ctx != TEXT_CTX_INSTANCE && !(flags & TEXT_FLOATER)) return -1;
  /* Any index outside [1, cadlayers) means NO OVERRIDE (decision D7). The documented
   * off switch (-1) therefore also covers 0 == BACKLAYER and any atoi garbage, so a
   * typo in xschemrc cannot make annotations invisible in a way indistinguishable
   * from the feature being broken. */
  if(xctx->annot_voltage_layer <= 0 || xctx->annot_voltage_layer >= cadlayers) return -1;
  return xctx->annot_voltage_layer;
}

/* 0678 -- WHICH annot_show BIT OWNS AN IMPLICIT CONTENT CLASS. Returns the mask bit
 * to test, or 0 for "no implicit class here". Shaped exactly like its colour twin
 * annot_text_layer(flags, ctx) above so the two answers cannot drift (invariant I1),
 * and it is the ONE place the grouping is written down: the two flag bits (xschem.h
 * 422-423) are separate PRECISELY so re-pointing a class is this one line, and
 * 0678 forbids folding them back into a single test.
 *
 * THE GROUPING, AND WHY IT CHANGED. Decision D4 of issue 0614 put both classes on
 * the voltage switch, grouping them by WHERE THE NUMBER COMES FROM in the raw. The
 * user drove a real sky130 bench on 2026-08-24 and grouped them by WHAT THE NUMBER
 * IS ABOUT -- "ALT-6 is doing its job for node voltages - but it's also displaying
 * OP info of voltage sources - namely their current. That should be controlled by 6
 * key, not Alt-6." A source's branch current is that DEVICE's terminal current,
 * exactly like a FET's id; a node voltage is a property of the NET. So:
 *   TEXT_ANNOT_VOLTAGE -> ANNOT_SHOW_VOLTAGE  (bit1, `Alt-6`)  net quantity
 *   TEXT_ANNOT_CURRENT -> ANNOT_SHOW_OP       (bit0, `6`)      device OP info
 * `Ctrl-6 -> nothing` (issue 0613) is unaffected: mask 0 clears both bits.
 * Only the VISIBILITY half moved -- annot_text_layer() still tests the voltage flag
 * alone, so currents keep layer 17. See doc/claude/issues/0678-*.md.
 *
 * ⚠ THE ctx TERM IS INVARIANT I7's AND IT LIVES IN HERE ON PURPOSE. Splitting the
 * old single test into two answers would otherwise mean writing the same guard
 * twice, and a dropped copy silently deletes a literal string a user typed. Measured
 * on this tree with no raw loaded: a SYMBOL text `@spice_get_voltage` emits no
 * element at all, so classifying it costs literally nothing -- but a SCHEMATIC-OWN
 * NON-FLOATER `T {@spice_get_voltage} ... {layer=15}` renders the LITERAL STRING,
 * because get_text_floater() translates only floaters. Blanking that at mask 0 would
 * be a text that has sat on their sheet for years vanishing because of a mask they
 * never touched. The same is true of the `@spice_get_current` spelling (measured;
 * tests/headless/test_op_annot.tcl rows U27 and U33). The exemption is for the
 * IMPLICIT class ONLY -- an author who typed `hide=voltage` on a top-level text
 * declared a class explicitly and still follows bit1, which is why the two classes
 * need two different bits. */
static int annot_class_mask(int flags, int ctx)
{
  if(ctx != TEXT_CTX_INSTANCE && !(flags & TEXT_FLOATER)) return 0;
  /* 0868 -- TWO BITS, ONE CONTENT CLASS. bit1 is the operating-point node
   * voltage (`Alt-6`), bit2 the TRANSIENT node voltage at a requested time
   * point (`Alt-Shift-6` / ASE-L Results > Annotate). They render the same
   * texts, so this returns BOTH and text_hidden()'s `annot_show & m` shows the
   * class when EITHER switch is on. Measured before the change: `xschem set
   * annot_show 4` read back 4 and painted nothing at all -- a mode the user can
   * select and not see (row V7 of tests/headless/test_op_annot.tcl). What the
   * two bits do NOT share is where the number came from, and that provenance
   * travels in the minted sentence, not in a second render path. Row V9 forbids
   * the shortcut of making bit2 an alias that sets bit1. */
  if(flags & TEXT_ANNOT_VOLTAGE) return ANNOT_SHOW_VOLTAGE | ANNOT_SHOW_TRAN;
  if(flags & TEXT_ANNOT_CURRENT) return ANNOT_SHOW_OP;
  return 0;
}

/* 1 == this text must not be drawn. ctx is TEXT_CTX_INSTANCE when iterating a
 * symbol's text[] while drawing an instance, TEXT_CTX_SCHEMATIC when iterating the
 * schematic's own xctx->text[]. */
int text_hidden(int flags, int ctx)
{
  /* 0614/0678: the IMPLICIT content class, tested FIRST and never both with an
   * explicit one (set_text_flags only adds it when the `hide=` chain set no bit, so
   * a text carrying a class bit carries no HIDE_TEXT* bit and m == 0 falls through to
   * exactly the tests the old single `if` fell through to). */
  int m = annot_class_mask(flags, ctx);
  if(m) return (xctx->annot_show & m) ? 0 : 1;
  if(flags & HIDE_TEXT_OP)      return (xctx->annot_show & ANNOT_SHOW_OP)      ? 0 : 1;
  /* 0868: an author's EXPLICIT `hide=voltage` follows both node-voltage
   * switches too -- the implicit class above and this one must not disagree
   * about which masks show a node voltage, or the same number would appear on
   * one sheet and vanish on another for the same mask. */
  if(flags & HIDE_TEXT_VOLTAGE)
    return (xctx->annot_show & (ANNOT_SHOW_VOLTAGE | ANNOT_SHOW_TRAN)) ? 0 : 1;
  if(xctx->show_hidden_texts) return 0;
  if(flags & HIDE_TEXT) return 1;
  if(ctx == TEXT_CTX_INSTANCE && (flags & HIDE_TEXT_INSTANTIATED)) return 1;
  return 0;
}

/* ----------------------------------------------------------------------------
 * S9 -- THE DRAW-TIME OP-ANNOTATION OVERLAY (doc/claude/specs/op_annotation.md).
 *
 * S6 shipped a CARRIER: the user places one devices/annotate_params per device
 * and types the device's name into its `ref=`. This is the second carrier: the
 * block is drawn ON THE DEVICE, with no placed symbol and no text record at all.
 *
 * ONE shared reader, THREE thin call sites (draw.c, svgdraw.c, psprint.c), and
 * every policy decision here so the screen and the two exports cannot disagree:
 *
 *   D1  THE GATE IS A NON-BLANK op_annot::text BLOCK, not "the symbol type has a
 *       registered descriptor". Spec 4.2 (issue 0425) and 4.3 both rule: skip on
 *       a blank DEVPATH, never on a blank descriptor -- the `type=` key is shared
 *       by every PDK and by the generic xschem_library/devices/*.sym, so with
 *       only sky130 registered devices/nmos.sym answers descriptor?=1, devpath {}.
 *       The descriptor gate would paint a block on 13 generic symbols.
 *   D2  THE MASK GATE IS text_hidden(HIDE_TEXT_OP, TEXT_CTX_INSTANCE), i.e. the
 *       overlay is exactly as visible as a `hide=op` text on an instance would
 *       be. HIDE_TEXT_OP is tested first in text_hidden and answers only to
 *       annot_show, so this is the mask alone -- through S7's single predicate,
 *       and NOT a fourth inline `xctx->annot_show & ANNOT_SHOW_OP` test.
 *   D9  It also obeys xctx->sym_txt, hide_texts=true (HIDE_SYMBOL_TEXTS) and
 *       hide=true (HIDE_INST): a user who switched symbol text off must not
 *       still get a block of numbers pinned to the instance.
 *   I4  NOTHING HERE MODIFIES THE SCHEMATIC. No instance placed, no set_modify,
 *       no byte written. Every path is a read.
 *
 * PERFORMANCE (the step's named risk). Measured on this tree before the cache:
 * one uncached op_annot::text sweep costs +0.67 ms on bandgap_opamp (73 inst /
 * 13 devices), +1.22 ms on test_comparator and +2.49 ms on top -- 20..35% of a
 * frame with the annotation gate closed, and +66..100% with a raw loaded (the
 * sky130 descriptor's two pinexpr rows add two more `xschem translate` calls per
 * FET). So the block is cached PER INSTANCE, lazily, and flushed wholesale by
 * annot_overlay_sync() whenever the observed-state epoch moves.
 * ------------------------------------------------------------------------- */

/* forward: the numeric-token reader defined with the pin-name layout below.
 * annot_dx / annot_dy are read with exactly the same helper, and the same
 * "absent token -> default" rule, as P6's name_dx / name_dy -- deliberately. */
static double pin_dtok(const char *prop, const char *tok, double dflt);

/* The render constants are lifted VERBATIM from the shipped carrier symbol
 * xschem_library/devices/annotate_params.sym, whose one text record is
 *   T {tcleval([op_annot::text @ref ])} 5 5 0 0 0.2 0.2 {layer=15
 *   font=Monospace hide=op}
 * so a placed carrier (S6) and the overlay (S9) render the same block in the
 * same fill, family and size when both are on screen. The carrier's SECOND text
 * record (`T {@ref} ... layer=4`) is deliberately NOT ported: it exists only so
 * a FLOATING annotator can say which device it belongs to, and the overlay is
 * drawn on the device itself. */
#define ANNOT_OVERLAY_SIZE  0.2
#define ANNOT_OVERLAY_LAYER 15
#define ANNOT_OVERLAY_DX    5.0
#define ANNOT_OVERLAY_DY    0.0

/* monotonic count of blocks this reader approved. draw()'s entire body is inside
 * if(has_x), so `xschem get annot_overlay_count` is the only seam any automated
 * check can use to prove the screen call site exists. Mirrors draw_count. */
unsigned int annot_overlay_count = 0;

/* monotonic count of WHOLESALE cache flushes (S9b). Read with
 * `xschem get annot_overlay_flushes`. Without this seam every staleness check in
 * the suite is satisfiable by flushing on EVERY frame -- i.e. by deleting the
 * cache -- which is precisely the +1.77 / +3.05 / +3.33 ms regression the cache
 * exists to avoid, and which no other check can see. Bumped INSIDE
 * annot_overlay_sync() at the moment of the flush and NEVER inside
 * annot_data_changed() (decision D1): several hooks legitimately fire for ONE
 * user action -- a `reload` bumps via remove_symbols() AND clear_drawing() --
 * so a counter of invalidation REQUESTS would report 2 where 1 flush happened. */
unsigned int annot_overlay_flushes = 0;

/* The observed-state epoch. Any field moving flushes the whole cache.
 * data_seq is the half the epoch CANNOT observe: re-running the same deck and
 * re-annotating republishes into the SAME Raw allocation with identical
 * nvars/level and annot_p 0 -> 0, so without the explicit bump the overlay would
 * keep showing the previous run's numbers (invariant I3's literal wording).
 * desc_gen is invariant I5: a user's op_annot::register in their own rc takes
 * effect ON REDRAW, and nothing in C can otherwise see a Tcl re-registration. */
typedef struct {
  void *ctx;
  void *raw;
  int valid;
  int instances;
  int currsch;
  int annot_show;
  int raw_level;
  int raw_nvars;
  int raw_annot_p;
  unsigned int schhash;
  unsigned int modify_seq;
  unsigned int data_seq;
  int desc_gen;
} Annot_epoch;

static Annot_epoch annot_epoch;      /* zero-initialised: .valid == 0 == "no epoch yet" */
static char **annot_cache = NULL;    /* per-instance rendered block, lazily filled */
static int annot_cache_n = 0;
static int annot_overlay_ok = 0;     /* ::op_annot::text is defined in this interpreter */
static int annot_overlay_busy = 0;   /* re-entrancy guard: a devproc that redraws */
static unsigned int annot_data_seq = 0;
static int annot_invalidate_held = 0;

/* S9b -- HOLD/RELEASE, depth-counted. ONE caller: prepare_netlist_structs()
 * (netlist.c), whose `set_modify(-2)` is a MAINTENANCE reset of derived data and
 * not a document change. Without the hold that call lands inside the export
 * itself (svg_draw() and create_ps() both run prepare_netlist_structs(0) after
 * their instance loop), so a single `load` + export flushed the cache TWICE:
 * once correctly for the load, and once more at the trailing draw() -- throwing
 * away the very blocks the export had just built and forcing the next frame to
 * rebuild all of them. MEASURED, not theorised: `xschem load -keep_symbols` plus
 * one SVG export moved annot_overlay_flushes by 2 (test rows O32/O34 pin 1).
 *
 * It is SAFE because the hold is strictly downstream: prepare_netlist_structs()
 * does work only when the netlist structs were invalidated, and every path that
 * invalidates them (a document edit, a paste, a property change, a load) has
 * ALREADY bumped through HOOK A or HOOK B before reaching here. The hold drops
 * a redundant bump, never the first one. */
void annot_invalidate_hold(int on)
{
  if(on) ++annot_invalidate_held;
  else if(annot_invalidate_held > 0) --annot_invalidate_held;
}

/* The two OP publishers call this: update_op() (save.c, the point-0 publisher
 * every `annotate_op` / `raw switch` / `update_op` request funnels through) and
 * backannotate_at_cursor_b_pos() (callback.c, the cursor-B live path), plus the
 * S9b invalidation hooks A (clear_drawing), B (set_modify's floater block),
 * C (remove_symbols) and D (the four raw-content mutators). */
void annot_data_changed(void)
{
  if(annot_invalidate_held) return;
  ++annot_data_seq;
}

static void annot_overlay_flush(void)
{
  int i;
  if(annot_cache) {
    for(i = 0; i < annot_cache_n; ++i) {
      if(annot_cache[i]) my_free(_ALLOC_ID_, &annot_cache[i]);
    }
    my_free(_ALLOC_ID_, &annot_cache);
  }
  annot_cache = NULL;
  annot_cache_n = 0;
}

/* Once per frame / per export, beside annot_show_sync_cache(). Compares the epoch
 * and flushes wholesale -- the xText.floater_ptr model (get_text_floater above),
 * not a per-instance field: a field on xInstance would have to be copied,
 * cleared and freed at the nine store/select/paste/undo sites `pin_sel` touches. */
void annot_overlay_sync(void)
{
  Annot_epoch e;
  const char *g;
  /* S9b hardening (decision D8). annot_overlay_busy guarded get_annot_overlay()
   * but NOT this function, which is the one that FREES the cache -- so a devproc
   * that re-enters xschem from inside annot_overlay_cached_text()'s tcleval
   * could free the block the outer frame is still holding (the documented
   * signal-11, issue 0464 residual #2). This NARROWS that window; it does not
   * close it, and 0464 stays open. It cannot move any golden: busy is set only
   * inside the cached-text fill, and no legitimate sync is nested in one. */
  if(annot_overlay_busy) return;
  if(!xctx) {
    annot_overlay_flush();
    annot_epoch.valid = 0;
    annot_overlay_ok = 0;
    return;
  }
  e.valid = 1;
  e.ctx = (void *)xctx;
  e.instances = xctx->instances;
  e.currsch = xctx->currsch;
  e.annot_show = xctx->annot_show;
  e.modify_seq = xctx->modify_seq;
  e.data_seq = annot_data_seq;
  e.schhash = 0;
  if(xctx->currsch >= 0 && xctx->currsch < CADMAXHIER && xctx->sch[xctx->currsch]) {
    e.schhash = str_hash(xctx->sch[xctx->currsch]);
  }
  e.raw = (void *)xctx->raw;
  e.raw_level   = xctx->raw ? xctx->raw->level   : -1;
  e.raw_nvars   = xctx->raw ? xctx->raw->nvars   : -1;
  e.raw_annot_p = xctx->raw ? xctx->raw->annot_p : -1;
  g = tclgetvar("::op_annot::gen");
  e.desc_gen = g ? atoi(g) : -1;
  /* ISSUE 0864 -- THERE WAS A 14th TERM HERE AND IT IS GONE; a reader who
   * remembers it will assume the epoch still has to watch a Tcl variable. It
   * read the shipped "Live annotate probes with 'b' cursor" checkbutton, because
   * that switch used to be op_annot::_annotated's first gate and so flipped
   * every row of every block between its value and blank while moving nothing
   * else -- not modify_seq, not the raw, not ::op_annot::gen, not any field of
   * xctx. After 0864 nothing that RENDERS reads that switch (it means "follow
   * cursor B and re-annotate as it moves"), so the term can no longer tell two
   * frames apart: it is a flush trigger keyed to a variable the block's content
   * does not depend on. Removed rather than left with a corrected comment --
   * the alternative was considered and rejected in 0864. Row O29b slices this
   * function and is the ONLY thing that can see the term come back; O29 stays
   * green either way, which is exactly why O29b exists. */
  if(annot_epoch.valid &&
     e.ctx == annot_epoch.ctx && e.raw == annot_epoch.raw &&
     e.instances == annot_epoch.instances && e.currsch == annot_epoch.currsch &&
     e.annot_show == annot_epoch.annot_show &&
     e.raw_level == annot_epoch.raw_level && e.raw_nvars == annot_epoch.raw_nvars &&
     e.raw_annot_p == annot_epoch.raw_annot_p && e.schhash == annot_epoch.schhash &&
     e.modify_seq == annot_epoch.modify_seq && e.data_seq == annot_epoch.data_seq &&
     e.desc_gen == annot_epoch.desc_gen) return;
  annot_overlay_flush();
  ++annot_overlay_flushes;
  annot_epoch = e;
  /* op_annot.tcl is sourced from xschem.tcl; an installed tree with a stale
   * Makefile (issues 0424/0458) can lack it. Probing ONCE per epoch beats a
   * per-instance tcleval that can only fail -- tcleval() swallows a Tcl error
   * into the empty string but prints two lines to stderr first, which for a
   * per-FET per-frame call is a flood, not a diagnostic. */
  annot_overlay_ok = 0;
  if(interp) {
    const char *r = tcleval("info commands ::op_annot::text");
    if(r && r[0]) annot_overlay_ok = 1;
  }
}

/* The cached block for instance n. NULL == "no cache available"; "" == computed
 * and this device carries no block. The fixed script + a carrier variable avoids
 * every quoting hazard an instance name could raise, and the `catch` keeps a
 * malformed user descriptor (issue 0447: op_annot::register validates only
 * `dict size`) from printing two stderr lines per device per frame. */
static const char *annot_overlay_cached_text(int n)
{
  const char *r;
  if(!annot_cache) {
    if(xctx->instances <= 0) return NULL;
    annot_cache = my_calloc(_ALLOC_ID_, xctx->instances, sizeof(char *));
    if(!annot_cache) return NULL;
    annot_cache_n = xctx->instances;
  }
  if(n < 0 || n >= annot_cache_n) return NULL;
  if(!annot_cache[n]) {
    annot_overlay_busy = 1;
    tclsetvar("::op_annot::_ovi", xctx->inst[n].instname ? xctx->inst[n].instname : "");
    r = tcleval("if {[catch {::op_annot::text $::op_annot::_ovi} ::op_annot::_ovr]}"
                " {set ::op_annot::_ovr {}}\nset ::op_annot::_ovr");
    annot_overlay_busy = 0;
    my_strdup2(_ALLOC_ID_, &annot_cache[n], r ? r : "");
  }
  return annot_cache[n];
}

/* 1 == draw instance n's operating-point block, at *x/*y, size *size, layer
 * *layer, text *txt (owned here -- the caller must NOT free it).
 * 0 == this instance carries no block. */
int get_annot_overlay(int n, const char **txt, double *x, double *y,
                      double *size, int *layer)
{
  const char *t;
  int lay;
  if(txt) *txt = NULL;
  if(!xctx) return 0;
  if(annot_overlay_busy) return 0;
  if(!annot_overlay_ok) return 0;
  if(n < 0 || n >= xctx->instances) return 0;
  if(xctx->inst[n].ptr == -1) return 0;
  if(!xctx->sym_txt) return 0;                                    /* D9 */
  if(xctx->inst[n].flags & HIDE_SYMBOL_TEXTS) return 0;           /* D9 */
  /* the same `hide` expression draw_symbol/svg_draw_symbol/ps_draw_symbol compute */
  if((xctx->inst[n].flags & HIDE_INST) ||
     ((xctx->inst[n].ptr + xctx->sym)->flags & HIDE_INST) ||
     (xctx->hide_symbols == 1 && (xctx->inst[n].ptr + xctx->sym)->type &&
      !strcmp((xctx->inst[n].ptr + xctx->sym)->type, "subcircuit")) ||
     (xctx->hide_symbols == 2)) return 0;                         /* D9 */
  if(text_hidden(HIDE_TEXT_OP, TEXT_CTX_INSTANCE)) return 0;      /* D2: the mask, alone */
  t = annot_overlay_cached_text(n);
  if(!t || !t[0]) return 0;                                       /* D1: a blank block */
  lay = ANNOT_OVERLAY_LAYER;
  if(lay < 0 || lay >= cadlayers) lay = TEXTLAYER;
  /* D7: anchored at the instance's TEXT-FREE bbox corner (xx2, yy1 -- absolute,
   * rot/flip already applied by symbol_bbox), with annot_dx / annot_dy as
   * RELATIVE offsets. Relative, not absolute, for the P6 name_dx/name_dy reason:
   * an absolute override breaks the moment the instance is moved. The block is
   * always upright (rot 0 / flip 0): a 90-degree FET would otherwise print a
   * vertical wall of monospace rows. */
  if(x) *x = xctx->inst[n].xx2 + pin_dtok(xctx->inst[n].prop_ptr, "annot_dx", ANNOT_OVERLAY_DX);
  if(y) *y = xctx->inst[n].yy1 + pin_dtok(xctx->inst[n].prop_ptr, "annot_dy", ANNOT_OVERLAY_DY);
  if(size) *size = ANNOT_OVERLAY_SIZE;
  if(layer) *layer = lay;
  if(txt) *txt = t;
  ++annot_overlay_count;
  return 1;
}

/* ----------------------------------------------------------------------------
 * Cadence-style pin-owned name text (Option B). A symbol PINLAYER pin carries its
 * displayed name as tokens on its B-record prop_ptr (name=, show_pinname=, and
 * name_dx/name_dy/name_size/name_rot/name_flip layout). There is NO standalone name
 * T record on disk. While EDITING a symbol, the name shown next to each pin is a
 * SYNTHESIZED, transient xText "view" (owner_pin_id = owning pin's xRect.id) so the
 * normal select/move/resize/edit machinery applies. Views are never saved
 * (save_text() skips them) and are regenerated here on load.
 * See doc/claude/specs/cadence_pin_name_text.md (P0/P1).
 * ------------------------------------------------------------------------- */

/* read a double-valued token from a prop string, returning dflt if absent/empty */
static double pin_dtok(const char *prop, const char *tok, double dflt)
{
  const char *s = get_tok_value(prop, tok, 0);
  return s[0] ? atof(s) : dflt;
}

/* P5 global pin-name visibility (tri-state, mirrored in the show_pin_names Tcl var):
 * "on" force-shows every owned pin, "off" force-hides all, "auto" (default / unset)
 * defers to each pin's show_pinname token. The global setting WINS over per-pin when
 * on/off (spec doc/claude/specs/cadence_pin_name_text.md §4.8). */
enum { PIN_NAMES_AUTO = 0, PIN_NAMES_ON, PIN_NAMES_OFF };

/* Cached mirror of the show_pin_names Tcl var. pin_name_visible() is evaluated per pin per
 * frame in the draw_symbol instance pass (P6), so a tclgetvar per call is too costly. The
 * cache is refreshed by pin_names_sync_cache() at each BULK visibility evaluation -- draw()
 * (once per frame), synth_pin_views() and pin_views_reconcile_all() (once per pass) -- which
 * covers every path that changes the mode (the `xschem pin_names` command routes through
 * reconcile). A direct `set ::show_pin_names` is picked up on the next such pass. */
static int pin_names_mode = PIN_NAMES_AUTO;
void pin_names_sync_cache(void)
{
  const char *m = tclgetvar("show_pin_names");
  pin_names_mode = (m && !strcmp(m, "on"))  ? PIN_NAMES_ON  :
                   (m && !strcmp(m, "off")) ? PIN_NAMES_OFF : PIN_NAMES_AUTO;
}

/* Effective pin-name visibility from a pin's prop tokens + the global tri-state (§4.8).
 * "owned" == it has a show_pinname token at all (legacy pins have none and are never shown,
 * so their appearance is preserved). Effective show = global==on ? shown : global==off ?
 * hidden : per-pin show_pinname. Reads the cached global (pin_names_sync_cache). Shared by
 * the symbol-edit views (pin_name_shown) and the draw_symbol instance pass (P6). */
int pin_name_visible(const char *prop)
{
  const char *s = get_tok_value(prop, "show_pinname", 0);
  if(!s[0]) return 0;                           /* legacy / un-owned pin: not in the model */
  if(pin_names_mode == PIN_NAMES_ON)  return 1; /* global ON wins: show every owned pin */
  if(pin_names_mode == PIN_NAMES_OFF) return 0; /* global OFF wins: hide every owned pin */
  return strboolcmp(s, "true") ? 0 : 1;         /* AUTO: defer to the per-pin token */
}

static int pin_name_shown(xRect *p) { return pin_name_visible(p->prop_ptr); }

/* [5] Shared reader for a pin's name-label layout + name/font, used by every render backend
 * (draw_symbol / svg_draw_symbol / ps_draw_symbol) so the token set, the defaults
 * (20/-5/0.2/0/0) and the "read name LAST because get_tok_value shares one static buffer"
 * ordering live in ONE place and cannot drift between the screen/SVG/PS outputs. Fills *lay
 * from the numeric tokens and copies the name into *name and, when present, the font into
 * *font (caller frees both). Returns 0 -- and frees *font -- when the pin has no name (nothing
 * to draw). pin_dtok's calls clobber get_tok_value's static buffer, so name/font are read (and
 * copied) after all the numeric reads. */
int get_pin_name_layout(const char *prop, Pin_name_layout *lay, char **name, char **font)
{
  const char *s;
  lay->dx   = pin_dtok(prop, "name_dx",   20.0);
  lay->dy   = pin_dtok(prop, "name_dy",   -5.0);
  lay->size = pin_dtok(prop, "name_size", 0.2);
  lay->rot  = pin_dtok(prop, "name_rot",  0.0);
  lay->flip = pin_dtok(prop, "name_flip", 0.0);
  if(font) { s = get_tok_value(prop, "name_font", 0); if(s[0]) my_strdup(_ALLOC_ID_, font, s); }
  s = get_tok_value(prop, "name", 0);
  if(!s[0]) { if(font) my_free(_ALLOC_ID_, font); return 0; }
  my_strdup2(_ALLOC_ID_, name, s);
  return 1;
}

/* Thread-A deliverable (P9): the single source of truth for "a pin's own name-text size",
 * consumed by the wire-stub / net-label feature (doc/claude/specs/wire_stub_netlabel.md
 * §3.4, §4.2). Returns the yscale of pin 'pin' of symbol 'sym': the pin rect's name_size token
 * when present, else 0.2 -- the SAME fallback get_pin_name_layout() uses when it renders the pin
 * name, so the size reported here always matches what draw_symbol actually draws (a divergent
 * fallback -- e.g. the create-time sym_pin_name_size var -- would size the stub/label differently
 * from the on-screen pin text). Legacy / un-owned pins carry no name_size and get that 0.2. A
 * NULL symbol or an out-of-range/negative pin also yields 0.2 rather than erroring, so a caller
 * can median a mixed pin set without special-casing missing pins. KEEP THE DEFAULT IN SYNC WITH
 * get_pin_name_layout(). */
double get_pin_name_size(xSymbol *sym, int pin)
{
  if(!sym || pin < 0 || pin >= sym->rects[PINLAYER]) return 0.2;
  return pin_dtok(sym->rect[PINLAYER][pin].prop_ptr, "name_size", 0.2);
}

/* -------------------------------------------------------------------------
 * Thread B (wire-stubs + auto net-labels on instance pins). B1 = the median
 * sizing primitive. See doc/claude/specs/wire_stub_netlabel.md.
 * ------------------------------------------------------------------------- */

/* qsort comparator for doubles, ascending. NaN is ordered after every non-NaN (and equal to
 * itself) so the comparator is a strict weak ordering even for a corrupt name_size=nan token: a
 * plain `x<y?-1:x>y?1:0` returns 0 for EVERY comparison involving NaN, which violates qsort's
 * contract and leaves the sort (hence the median) undefined. `x != x` is true iff x is NaN. */
static int cmp_double(const void *a, const void *b)
{
  double x = *(const double *)a, y = *(const double *)b;
  if(x < y) return -1;
  if(x > y) return 1;
  if(x == y) return 0;
  return (x != x) ? ((y != y) ? 0 : 1) : -1;   /* NaN present: sort it last, consistently */
}

/* B1: median of n doubles. Copies the input (so the caller's array is NOT reordered), sorts the
 * copy, and returns the middle element for odd n or the mean of the two middle elements for even
 * n (the textbook median; for n==2 that mean is the only sensible "middle"). n==1 returns a[0];
 * n<=0 returns 0.0. The wire-stub op (§4.2) uses this to reduce the processed pins' name sizes to
 * the ONE size that drives every label + stub in an invocation -- the median resists a minority
 * of outlier pins in a way a plain mean does not. */
double median_double(const double *a, int n)
{
  double *tmp, med;
  int i;
  if(n <= 0) return 0.0;
  if(n == 1) return a[0];
  tmp = my_malloc(_ALLOC_ID_, (size_t)n * sizeof(double));
  for(i = 0; i < n; ++i) tmp[i] = a[i];
  qsort(tmp, (size_t)n, sizeof(double), cmp_double);
  med = (n & 1) ? tmp[n / 2] : (tmp[n / 2 - 1] + tmp[n / 2]) / 2.0;
  my_free(_ALLOC_ID_, &tmp);
  return med;
}

/* B2: is instance i's pin j already connected? Two ways count as connected (both skipped in
 * whole-instance mode):
 *   1. a WIRE -- a wire endpoint AT the pin OR a wire passing THROUGH it, via touch() (the exact
 *      on-segment test the netlister uses in name_attached_inst_to_net), so this agrees with real
 *      netlist connectivity;
 *   2. a COINCIDENT pin of ANOTHER instance (abutment / pin-to-pin placement) -- exact coord
 *      match, since get_inst_pin_coord is exact for on-grid instances (user: treat a coincident
 *      instance pin the same as a wired one).
 * Caller must have built BOTH spatial hashes (hash_wires + hash_instances). See
 * doc/claude/specs/wire_stub_netlabel.md §4.1/§4.5. */
static int pin_is_connected(int i, int j)
{
  double x0, y0, xx, yy;
  Iterator_ctx ctx;
  Wireentry *wp;
  Instentry *ep;
  xWire * const wire = xctx->wire;
  xInstance * const inst = xctx->inst;
  get_inst_pin_coord(i, j, &x0, &y0);
  init_wire_iterator(&ctx, x0 - CADWIREMINDIST, y0 - CADWIREMINDIST,
                           x0 + CADWIREMINDIST, y0 + CADWIREMINDIST);
  while((wp = wire_iterator_next(&ctx)))
    if(touch(wire[wp->n].x1, wire[wp->n].y1, wire[wp->n].x2, wire[wp->n].y2, x0, y0)) return 1;
  init_inst_iterator(&ctx, x0 - CADWIREMINDIST, y0 - CADWIREMINDIST,
                           x0 + CADWIREMINDIST, y0 + CADWIREMINDIST);
  while((ep = inst_iterator_next(&ctx))) {
    int m = ep->n, p, rects;
    if(m == i || inst[m].ptr < 0) continue;    /* skip this instance and symbol-less instances */
    rects = (inst[m].ptr + xctx->sym)->rects[PINLAYER];
    for(p = 0; p < rects; p++) {
      get_inst_pin_coord(m, p, &xx, &yy);
      if(xx == x0 && yy == y0) return 1;        /* another instance's pin lands on this one */
    }
  }
  return 0;
}

/* append (inst,pin) to a growable Pin_stub_target array (doubling; caller frees *list). */
static void stub_target_append(Pin_stub_target **list, int *cnt, int *cap, int inst, int pin)
{
  if(*cnt >= *cap) {
    *cap = *cap ? *cap * 2 : 8;
    my_realloc(_ALLOC_ID_, list, (size_t)*cap * sizeof(Pin_stub_target));
  }
  (*list)[*cnt].inst = inst;
  (*list)[*cnt].pin  = pin;
  ++*cnt;
}

/* B2: build the list of (instance, pin) targets a wire-stub invocation should process
 * (doc/claude/specs/wire_stub_netlabel.md §4.1). Two modes, individually-selected pins WIN; an
 * already-connected pin is skipped in BOTH modes (never double a connection):
 *   - any INST_PIN in the selection -> those (instance, pin) pairs, minus any already connected;
 *   - else every whole instance selected (ELEMENT) -> each of ITS pins not already connected.
 * "connected" == pin_is_connected() (a wire, or a coincident pin of another instance).
 * Returns the count; *out is a my_malloc'd Pin_stub_target[] the caller frees (NULL/0 when there
 * is nothing to do). Schematic-mode only -- a symbol being edited has no placed instances; a
 * symbol-less instance (ptr<0) and stale/generic pin indices are skipped. */
int collect_pin_stub_targets(Pin_stub_target **out)
{
  int i, j, n, rects, cnt = 0, cap = 0, have_pins = 0;
  Pin_stub_target *list = NULL;
  *out = NULL;
  if(!xctx || xctx->netlist_type == CAD_SYMBOL_ATTRS) return 0;
  rebuild_selected_array();
  for(i = 0; i < xctx->lastsel; ++i)
    if(xctx->sel_array[i].type == INST_PIN) { have_pins = 1; break; }
  hash_wires();       /* pin_is_connected() queries the wire ... */
  hash_instances();   /* ... and the instance spatial hash */
  for(i = 0; i < xctx->lastsel; ++i) {
    Selected sel = xctx->sel_array[i];
    if(have_pins) {
      if(sel.type != INST_PIN) continue;                       /* pins win: ignore whole-inst sels */
      n = sel.n;
      if(n < 0 || n >= xctx->instances || xctx->inst[n].ptr < 0) continue;
      rects = (xctx->inst[n].ptr + xctx->sym)->rects[PINLAYER];
      /* an already-connected pin is skipped even when explicitly selected -- never double a
       * connection (user decision 2026-07-01) */
      if((int)sel.col < rects && !pin_is_connected(n, (int)sel.col))
        stub_target_append(&list, &cnt, &cap, n, (int)sel.col);
    } else {
      if(sel.type != ELEMENT) continue;
      n = sel.n;
      if(n < 0 || n >= xctx->instances || xctx->inst[n].ptr < 0) continue;
      rects = (xctx->inst[n].ptr + xctx->sym)->rects[PINLAYER];
      for(j = 0; j < rects; ++j)
        if(!pin_is_connected(n, j)) stub_target_append(&list, &cnt, &cap, n, j);
    }
  }
  *out = list;
  return cnt;
}

/* B3: reduce the targets to the ONE size + derived geometry an invocation uses
 * (doc/claude/specs/wire_stub_netlabel.md §4.2). size = median of the targets' pin-name sizes
 * (get_pin_name_size, robust to an outlier pin -- §4.2 step 2); text_h = a label line's height
 * at that size via text_bbox() (per-line height is ~content-independent, so a representative
 * "Mg" stands in for the not-yet-known net name -- §4.4); stub_len = the smallest cadgrid
 * multiple STRICTLY greater than 2*text_h, so every stub clears 2x its label height AND lands on
 * grid (Req 1 / §4.2 step 4). Returns 0 (leaving *out untouched) when n<=0. Each target's symbol
 * is resolved defensively (ptr<0 -> the 0.2 default) though B2 already filters symbol-less ones. */
int compute_pin_stub_sizing(const Pin_stub_target *t, int n, Pin_stub_sizing *out)
{
  double *sizes, S, H, grid, twoH;
  double rx1, ry1, rx2, ry2, longest;
  int k, cairo_lines;
  if(n <= 0) return 0;
  sizes = my_malloc(_ALLOC_ID_, (size_t)n * sizeof(double));
  for(k = 0; k < n; ++k) {
    int inst = t[k].inst;
    xSymbol *sym = (inst >= 0 && inst < xctx->instances && xctx->inst[inst].ptr >= 0)
                   ? xctx->sym + xctx->inst[inst].ptr : NULL;
    sizes[k] = get_pin_name_size(sym, t[k].pin);
  }
  S = median_double(sizes, n);
  my_free(_ALLOC_ID_, &sizes);
  text_bbox("Mg", S, S, 0, 0, 0, 0, 0.0, 0.0, &rx1, &ry1, &rx2, &ry2, &cairo_lines, &longest);
  H = ry2 - ry1;
  grid = tclgetdoublevar("cadgrid");
  twoH = 2.0 * H;
  out->size = S;
  out->text_h = H;
  out->stub_len = (grid > 0.0) ? (floor(twoH / grid) + 1.0) * grid : twoH + 1.0;
  return 1;
}

/* B4: the stub segment for instance 'inst' pin 'pin', extended outward by 'stub_len'
 * (doc/claude/specs/wire_stub_netlabel.md §4.3). The OUTWARD direction is, in symbol-local
 * coords, (pin center - body center) snapped to the dominant axis (Manhattan, so the stub is
 * orthogonal) then transformed through the instance's rot/flip (ROTATION). Body center uses the
 * symbol's minx/maxx/miny/maxy, which EXCLUDE symbol text (save.c leaves text out of the symbol
 * bbox), i.e. the no-text body box §4.3 asks for. Start = the pin's absolute coord
 * (get_inst_pin_coord); end = start + outward*stub_len. Real pins sit on-grid so end lands on
 * grid without a separate snap (which could otherwise erode the L>2H guarantee for an off-grid
 * pin). Returns 0 for a bad instance/pin. */
int compute_pin_stub_geom(int inst, int pin, double stub_len, Pin_stub_geom *out)
{
  xSymbol *sym;
  double px, py, bcx, bcy, ldx, ldy, lox, loy, adx, ady, sx, sy;
  int rot, flip;
  if(!xctx || inst < 0 || inst >= xctx->instances || xctx->inst[inst].ptr < 0) return 0;
  sym = xctx->sym + xctx->inst[inst].ptr;
  if(pin < 0 || pin >= sym->rects[PINLAYER]) return 0;
  px = (sym->rect[PINLAYER][pin].x1 + sym->rect[PINLAYER][pin].x2) / 2.0;
  py = (sym->rect[PINLAYER][pin].y1 + sym->rect[PINLAYER][pin].y2) / 2.0;
  bcx = (sym->minx + sym->maxx) / 2.0;
  bcy = (sym->miny + sym->maxy) / 2.0;
  ldx = px - bcx;
  ldy = py - bcy;
  /* dominant axis; a pin exactly at the body centre (ldx==ldy==0) defaults to +x */
  if(fabs(ldx) >= fabs(ldy)) { lox = (ldx < 0.0) ? -1.0 : 1.0; loy = 0.0; }
  else                       { lox = 0.0; loy = (ldy < 0.0) ? -1.0 : 1.0; }
  rot = xctx->inst[inst].rot;
  flip = xctx->inst[inst].flip;
  ROTATION(rot, flip, 0.0, 0.0, lox, loy, adx, ady);   /* local outward -> absolute outward */
  get_inst_pin_coord(inst, pin, &sx, &sy);
  out->x1 = sx;
  out->y1 = sy;
  out->x2 = sx + adx * stub_len;
  out->y2 = sy + ady * stub_len;
  out->dx = adx;
  out->dy = ady;
  return 1;
}

/* B5: lab_pin (rot,flip) so its @lab text reads OUTWARD along (dx,dy) -- away from the instance,
 * "flag in the wind" (§4.3). Determined empirically against lab_pin.sym's `T {@lab} -7.5 -8.125
 * 0 1 ...` anchor (text-bbox-centre offset from the connection point): rot=0 draws the text
 * horizontally (flip picks -x vs +x), rot=1 vertically (flip picks -y vs +y). (dx,dy) is one of
 * the four cardinals from compute_pin_stub_geom. */
static void lab_orient(double dx, double dy, short *rot, short *flip)
{
  if(dy == 0.0) { *rot = 0; *flip = (dx > 0.0) ? 1 : 0; }   /* horizontal: text along -x / +x */
  else          { *rot = 1; *flip = (dy > 0.0) ? 1 : 0; }   /* vertical:   text along -y / +y */
}

/* B5: draw a wire stub out of every stub target (collect_pin_stub_targets) and drop a lab_pin
 * net-label "flag" at the far end, oriented so its text reads outward (§4). All targets share one
 * size S + stub length L (compute_pin_stub_sizing). The label net name is
 * [instname_ if inst_prefix][prefix]<pinname>[suffix] (prefix/suffix may be "" ). ONE undo covers
 * the whole operation. Returns the number of stubs added. See doc/claude/specs/wire_stub_netlabel.md. */
int add_pin_stubs(const char *prefix, const char *suffix, int inst_prefix)
{
  Pin_stub_target *t = NULL;
  Pin_stub_sizing sz;
  char *lab_sym = NULL;
  const char *lp;
  char szbuf[64];
  int nt, k, added = 0, first = 1;
  if(!xctx || xctx->netlist_type == CAD_SYMBOL_ATTRS) return 0;
  if(xctx->readonly) return 0;  /* read-only view: refuse via EVERY entry point (SPACE key, Sym menu, command) */
  if(!prefix) prefix = "";
  if(!suffix) suffix = "";
  nt = collect_pin_stub_targets(&t);
  if(nt <= 0) { my_free(_ALLOC_ID_, &t); return 0; }
  if(!compute_pin_stub_sizing(t, nt, &sz)) { my_free(_ALLOC_ID_, &t); return 0; }
  lp = tcleval("find_file_first lab_pin.sym");           /* copy before place_symbol's tcleval */
  if(!lp || !lp[0]) { my_free(_ALLOC_ID_, &t); return 0; }
  my_strdup(_ALLOC_ID_, &lab_sym, lp);
  my_snprintf(szbuf, S(szbuf), "%g", sz.size);
  xctx->push_undo();
  for(k = 0; k < nt; ++k) {
    Pin_stub_geom g;
    xSymbol *sym;
    const char *pinname, *instname;
    char *netname = NULL, *prop = NULL;
    short lrot, lflip;
    int inst = t[k].inst, pin = t[k].pin;
    if(!compute_pin_stub_geom(inst, pin, sz.stub_len, &g)) continue;
    sym = xctx->sym + xctx->inst[inst].ptr;
    /* net name pieces read BEFORE place_symbol (which may realloc xctx->sym via match_symbol) */
    pinname = get_tok_value(sym->rect[PINLAYER][pin].prop_ptr, "name", 0);
    instname = xctx->inst[inst].instname ? xctx->inst[inst].instname : "";
    if(inst_prefix && instname[0]) my_mstrcat(_ALLOC_ID_, &netname, instname, "_", NULL);
    my_mstrcat(_ALLOC_ID_, &netname, prefix, pinname, suffix, NULL); /* empty parts are skipped */
    /* a nameless pin with no prefix/suffix yields an empty net name: skip it rather than drop
     * a blank lab= net-label (which would name the empty net / error at netlist time).
     * str_is_blank(), not netname[0]: a prefix of " " over a nameless pin passed the old
     * test and emitted `name=l0 lab=  text_size_0=0.2`, whose lab reads back as
     * "text_size_0=0.2" with text_size_0 destroyed. Measured via
     * `xschem add_pin_stubs -prefix { }`. Issue 0183. */
    if(str_is_blank(netname)) { my_free(_ALLOC_ID_, &netname); continue; }
    /* stub wire: pin (start) -> stub end */
    storeobject(-1, g.x1, g.y1, g.x2, g.y2, WIRE, 0, 0, NULL);
    /* lab_pin at the stub end, oriented so the text reads outward; unique name via uniquify */
    lab_orient(g.dx, g.dy, &lrot, &lflip);
    my_mstrcat(_ALLOC_ID_, &prop, "name=l0 lab=", netname ? netname : "", " text_size_0=", szbuf, NULL);
    place_symbol(-1, lab_sym, g.x2, g.y2, lrot, lflip, prop, 0 /*draw*/, first /*first_call*/, 0 /*push_undo*/);
    first = 0;
    my_free(_ALLOC_ID_, &netname);
    my_free(_ALLOC_ID_, &prop);
    ++added;
  }
  my_free(_ALLOC_ID_, &t);
  my_free(_ALLOC_ID_, &lab_sym);
  /* one batch rebuild + redraw */
  xctx->prep_hi_structs = 0;
  xctx->prep_net_structs = 0;
  xctx->prep_hash_wires = 0;
  xctx->prep_hash_inst = 0;
  if(added) { set_modify(1); draw(); }
  return added;
}

/* [6] Fast global short-circuit for the per-frame draw_symbol pin-name pass: when the
 * show_pin_names tri-state is OFF no owned pin can show, so the whole per-instance pin loop
 * is skippable without a get_tok_value per pin. Reads the cached mode (pin_names_sync_cache
 * runs once per draw()/export, before this is consulted). */
int pin_names_all_off(void) { return pin_names_mode == PIN_NAMES_OFF; }

/* index of the synthesized name view owned by pin id 'pin_id', or -1 if none */
int pin_name_view_of(unsigned int pin_id)
{
  int i;
  if(!pin_id) return -1;
  for(i = 0; i < xctx->texts; ++i)
    if(xctx->text[i].owner_pin_id == pin_id) return i;
  return -1;
}

/* (Re)materialize editable pin-name views for the symbol being edited. Way A: only the
 * live edited document gets views; placed instances draw their names directly from pin
 * tokens in draw_symbol (P6). Idempotent: pins that already have a view are skipped. */
void synth_pin_views(void)
{
  int j, rects;
  if(!xctx) return;
  if(xctx->netlist_type != CAD_SYMBOL_ATTRS) return;  /* only while editing a symbol */
  pin_names_sync_cache();                             /* freshen the global tri-state gate */
  rects = xctx->rects[PINLAYER];
  for(j = 0; j < rects; ++j) {
    xRect *p = &xctx->rect[PINLAYER][j];
    const char *name;
    double cx, cy, dx, dy, size, rot, flip;
    if(!pin_name_shown(p)) continue;                  /* legacy/un-owned or hidden */
    if(pin_name_view_of(p->id) >= 0) continue;        /* already materialized */
    cx = (p->x1 + p->x2) / 2.0;
    cy = (p->y1 + p->y2) / 2.0;
    dx   = pin_dtok(p->prop_ptr, "name_dx",   20.0);
    dy   = pin_dtok(p->prop_ptr, "name_dy",   -5.0);
    size = pin_dtok(p->prop_ptr, "name_size", 0.2);
    rot  = pin_dtok(p->prop_ptr, "name_rot",  0.0);
    flip = pin_dtok(p->prop_ptr, "name_flip", 0.0);
    /* fetch name_font then name LAST: get_tok_value() uses one volatile static buffer the
     * pin_dtok() calls above clobber, so build the view's font-only prop (which copies the
     * value) before reading name; create_text() then copies 'name' immediately. */
    {
      const char *nf = get_tok_value(p->prop_ptr, "name_font", 0);
      char *vp = NULL;
      if(nf[0]) my_mstrcat(_ALLOC_ID_, &vp, "font=", nf, NULL);
      name = get_tok_value(p->prop_ptr, "name", 0);
      if(!name[0]) { my_free(_ALLOC_ID_, &vp); continue; } /* nameless pin: nothing to show */
      create_text(0 /* no draw */, cx + dx, cy + dy, (int)rot, (int)flip, name, vp, size, size);
      my_free(_ALLOC_ID_, &vp);
      xctx->text[xctx->texts - 1].owner_pin_id = p->id;
    }
  }
}

/* Create a symbol pin that OWNS its name text (Option B, P2). Stores a PINLAYER rect at
 * (x,y) carrying name=/dir=/show_pinname=true + default name_* layout tokens, then
 * materializes the editable name view (owner_pin_id = the rect's id). 'sel' selects both
 * rect and view (used for interactive placement so they move together; a pure
 * translation preserves the name_dx/name_dy offsets). Returns the new pin index in
 * rect[PINLAYER], or -1. Default name size = sym_pin_name_size Tcl var (fallback 0.2). */
int create_pin(double x, double y, const char *name, const char *dir, unsigned short sel)
{
  char *prop = NULL;
  char nums[160];
  const char *sz;
  int ri, flip;
  double cx, cy, dx, dy, size;
  if(!xctx) return -1;
  if(!name) name = "";
  if(!dir || !dir[0]) dir = "inout";
  flip = (!strcmp(dir, "out") || !strcmp(dir, "inout")) ? 1 : 0;   /* name on the left */
  sz = tclgetvar("sym_pin_name_size");
  size = (sz && sz[0]) ? atof(sz) : 0.2;
  if(size <= 0.0) size = 0.2;
  dx = flip ? -25.0 : 25.0;
  dy = -5.0;
  /* numeric/bounded tokens into a small fixed buffer; the (unbounded) name and dir are
   * concatenated separately so a long pin name is never truncated (cf. old my_mstrcat) */
  my_snprintf(nums, S(nums),
    " show_pinname=true name_dx=%g name_dy=%g name_size=%g%s",
    dx, dy, size, flip ? " name_flip=1" : "");
  /* `name` may legitimately be "" -- the guard above turns a NULL into one, and the
   * argc>5 form of `xschem add_symbol_pin` (scheduler.c:1677) passes argv[4] through
   * unguarded, unlike the other two callers. An unquoted empty value would make
   * get_tok_value() read " dir=in" as the NAME and leave the rect with no `dir` at
   * all -- and dir drives netlist port direction, ERC and set_pin_type. Issue 0183.
   * `dir` needs no such care: it is forced non-empty a few lines above. */
  my_mstrcat_tok(_ALLOC_ID_, &prop, "name", name, NULL);
  my_mstrcat(_ALLOC_ID_, &prop, " dir=", dir, nums, NULL);
  storeobject(-1, x - 2.5, y - 2.5, x + 2.5, y + 2.5, xRECT, PINLAYER, sel, prop);
  my_free(_ALLOC_ID_, &prop);
  ri = xctx->rects[PINLAYER] - 1;
  if(ri < 0) return -1;
  cx = (xctx->rect[PINLAYER][ri].x1 + xctx->rect[PINLAYER][ri].x2) / 2.0;
  cy = (xctx->rect[PINLAYER][ri].y1 + xctx->rect[PINLAYER][ri].y2) / 2.0;
  /* Materialize the name view only if effectively shown -- respect the global tri-state so
   * a pin added while show_pin_names=off does not display its name against the setting
   * (P5). When later toggled to auto/on, synth_pin_views/reconcile creates the view. */
  if(pin_name_shown(&xctx->rect[PINLAYER][ri])) {
    create_text(0 /* no draw */, cx + dx, cy + dy, 0, flip, name, NULL, size, size);
    xctx->text[xctx->texts - 1].owner_pin_id = xctx->rect[PINLAYER][ri].id;
    if(sel) xctx->text[xctx->texts - 1].sel = SELECTED;
  }
  return ri;
}

/* ---- P3 write-through (Option B): keep pin tokens <-> name view in sync. ---------- */

/* index of the PINLAYER rect whose id == 'id', or -1 */
int pin_idx_by_id(unsigned int id)
{
  int j, rects;
  if(!id) return -1;
  rects = xctx->rects[PINLAYER];
  for(j = 0; j < rects; ++j) if(xctx->rect[PINLAYER][j].id == id) return j;
  return -1;
}

/* write view text[ti]'s current geometry/size back into its owning pin's name_* tokens
 * (offset is relative to the pin center, so it is invariant under joint translation) */
void pin_view_writeback(int ti)
{
  xText *v = &xctx->text[ti];
  int pi = pin_idx_by_id(v->owner_pin_id);
  xRect *p;
  double cx, cy;
  char b[80];
  char *pr = NULL;
  if(pi < 0) return;
  p = &xctx->rect[PINLAYER][pi];
  cx = (p->x1 + p->x2) / 2.0;
  cy = (p->y1 + p->y2) / 2.0;
  my_strdup(_ALLOC_ID_, &pr, p->prop_ptr);
  my_snprintf(b, S(b), "%g", v->x0 - cx);   my_strdup(_ALLOC_ID_, &pr, subst_token(pr, "name_dx", b));
  my_snprintf(b, S(b), "%g", v->y0 - cy);   my_strdup(_ALLOC_ID_, &pr, subst_token(pr, "name_dy", b));
  my_snprintf(b, S(b), "%d", (int)v->rot);  my_strdup(_ALLOC_ID_, &pr, subst_token(pr, "name_rot", b));
  my_snprintf(b, S(b), "%d", (int)v->flip); my_strdup(_ALLOC_ID_, &pr, subst_token(pr, "name_flip", b));
  my_snprintf(b, S(b), "%g", v->yscale);    my_strdup(_ALLOC_ID_, &pr, subst_token(pr, "name_size", b));
  my_strdup(_ALLOC_ID_, &p->prop_ptr, pr);
  my_free(_ALLOC_ID_, &pr);
}

/* view text[ti]'s content -> owning pin's name= (editing the label renames the pin) */
void pin_rename_from_view(int ti)
{
  xText *v = &xctx->text[ti];
  int pi = pin_idx_by_id(v->owner_pin_id);
  if(pi < 0 || !v->txt_ptr) return;
  my_strdup(_ALLOC_ID_, &xctx->rect[PINLAYER][pi].prop_ptr,
            subst_token(xctx->rect[PINLAYER][pi].prop_ptr, "name", v->txt_ptr));
}

/* Sync a pin's name view (content + position + size + rot + flip) from its tokens, so
 * the displayed label tracks the name and name_dx/dy/size after a pin property edit.
 * No-op if the pin has no view (e.g. show_pinname false). */
void pin_view_refresh(int pi)
{
  xRect *p = &xctx->rect[PINLAYER][pi];
  int ti = pin_name_view_of(p->id);
  double cx, cy, s;
  if(ti < 0) return;
  cx = (p->x1 + p->x2) / 2.0;
  cy = (p->y1 + p->y2) / 2.0;
  /* copy the name first: get_tok_value's static buffer is clobbered by pin_dtok below */
  my_strdup2(_ALLOC_ID_, &xctx->text[ti].txt_ptr, get_tok_value(p->prop_ptr, "name", 0));
  xctx->text[ti].x0 = cx + pin_dtok(p->prop_ptr, "name_dx", 20.0);
  xctx->text[ti].y0 = cy + pin_dtok(p->prop_ptr, "name_dy", -5.0);
  s = pin_dtok(p->prop_ptr, "name_size", 0.2);
  xctx->text[ti].xscale = s;
  xctx->text[ti].yscale = s;
  xctx->text[ti].rot  = (short)pin_dtok(p->prop_ptr, "name_rot", 0.0);
  xctx->text[ti].flip = (short)pin_dtok(p->prop_ptr, "name_flip", 0.0);
  /* font (name_font): set the view's font + keep its font-only prop in sync. Read LAST --
   * the pin_dtok() calls above clobber get_tok_value()'s shared static buffer. */
  {
    const char *nf = get_tok_value(p->prop_ptr, "name_font", 0);
    char *vp = NULL;
    if(nf[0]) my_mstrcat(_ALLOC_ID_, &vp, "font=", nf, NULL);
    my_strdup(_ALLOC_ID_, &xctx->text[ti].prop_ptr, vp);  /* view prop carries only the font */
    my_strdup(_ALLOC_ID_, &xctx->text[ti].font, nf);      /* "" when absent: no custom font */
    my_free(_ALLOC_ID_, &vp);
  }
}

/* Recompute a pin's name-label side from its current dir= (in -> right/no-flip,
 * out|inout -> left/flip), writing name_dx/name_flip. Called when the direction
 * changes so the label re-orients to the conventional side. */
void pin_reorient(int pi)
{
  xRect *p = &xctx->rect[PINLAYER][pi];
  const char *dir = get_tok_value(p->prop_ptr, "dir", 0);
  int flip = (!strcmp(dir, "out") || !strcmp(dir, "inout")) ? 1 : 0;
  char b[32];
  char *pr = NULL;
  my_strdup(_ALLOC_ID_, &pr, p->prop_ptr);
  my_snprintf(b, S(b), "%g", flip ? -25.0 : 25.0); my_strdup(_ALLOC_ID_, &pr, subst_token(pr, "name_dx", b));
  my_snprintf(b, S(b), "%d", flip);                my_strdup(_ALLOC_ID_, &pr, subst_token(pr, "name_flip", b));
  my_strdup(_ALLOC_ID_, &p->prop_ptr, pr);
  my_free(_ALLOC_ID_, &pr);
}

/* remove a synthesized name-view text at index ti and compact the text array */
static void pin_view_delete(int ti)
{
  int k;
  my_free(_ALLOC_ID_, &xctx->text[ti].txt_ptr);
  my_free(_ALLOC_ID_, &xctx->text[ti].prop_ptr);
  my_free(_ALLOC_ID_, &xctx->text[ti].font);
  my_free(_ALLOC_ID_, &xctx->text[ti].floater_ptr);
  my_free(_ALLOC_ID_, &xctx->text[ti].floater_instname);
  for(k = ti; k < xctx->texts - 1; ++k) xctx->text[k] = xctx->text[k + 1];
  xctx->texts--;
}

/* Reconcile a pin's name view with show_pinname after a property edit: create the view
 * if now shown and missing, delete it if now hidden, then sync its content/geometry.
 * (show_pinname uncheck must actually hide the label.) */
void pin_view_apply(int pi)
{
  xRect *p = &xctx->rect[PINLAYER][pi];
  int ti = pin_name_view_of(p->id);
  if(!pin_name_shown(p)) {
    if(ti >= 0) pin_view_delete(ti);   /* hidden -> remove the view */
    return;
  }
  if(ti < 0) synth_pin_views();        /* shown but no view -> create it (idempotent) */
  pin_view_refresh(pi);                /* sync content/pos/size/rot/flip from tokens */
}

/* P5 show/hide: bring EVERY owned pin's name view into line with the effective
 * visibility (global show_pin_names tri-state, then per-pin show_pinname). Deletes
 * views that are now hidden, then (re)creates views that are now shown. Called when the
 * global toggle changes. Symbol-edit only; views are derived so this alters no
 * persistent state and needs no undo -- caller redraws. Deleting a view shifts text
 * indices, but we iterate PINLAYER rects and re-look-up each view by pin id, so it is
 * safe. */
void pin_views_reconcile_all(void)
{
  int j, rects, deleted = 0;
  if(!xctx || xctx->netlist_type != CAD_SYMBOL_ATTRS) return;
  pin_names_sync_cache();                             /* freshen the global tri-state gate */
  rects = xctx->rects[PINLAYER];
  for(j = 0; j < rects; ++j) {
    xRect *p = &xctx->rect[PINLAYER][j];
    if(!pin_name_shown(p)) {
      int ti = pin_name_view_of(p->id);
      if(ti >= 0) { pin_view_delete(ti); deleted = 1; }
    }
  }
  /* pin_view_delete() compacts xctx->text, so a still-selected (now deleted or shifted)
   * view would leave sel_array/sel_index dangling -- rebuild it, as the P4 view-drop path
   * does (move.c). */
  if(deleted) { xctx->need_reb_sel_arr = 1; rebuild_selected_array(); }
  synth_pin_views();                   /* create views for pins now shown but missing */
}

/* After a move/rotate/flip commit, reconcile every name view with its pin:
 *  - VIEW was in the move -> record its new offset/rot/flip/size on the pin;
 *  - else only the PIN moved -> reposition the view from the pin tokens (label follows).
 * Keyed on .sel (still set right after the move commit). Symbol-edit only. */
void pin_views_reconcile_after_move(void)
{
  int i;
  if(xctx->netlist_type != CAD_SYMBOL_ATTRS) return;
  for(i = 0; i < xctx->texts; ++i) {
    xText *v = &xctx->text[i];
    int pi;
    if(!v->owner_pin_id) continue;
    pi = pin_idx_by_id(v->owner_pin_id);
    if(pi < 0) continue;
    if(v->sel == SELECTED) {
      pin_view_writeback(i);
    } else if(xctx->rect[PINLAYER][pi].sel == SELECTED) {
      xRect *p = &xctx->rect[PINLAYER][pi];
      double cx = (p->x1 + p->x2) / 2.0, cy = (p->y1 + p->y2) / 2.0;
      v->x0 = cx + pin_dtok(p->prop_ptr, "name_dx", 20.0);
      v->y0 = cy + pin_dtok(p->prop_ptr, "name_dy", -5.0);
    }
  }
}

/* Append one machine-readable issue element "{type idx {name}}" to the Tcl list *res
 * (unbounded, so a long/bus pin name is never truncated). */
static void add_pin_issue(char **res, const char *type, int idx, const char *name)
{
  char idxbuf[32];
  my_snprintf(idxbuf, S(idxbuf), "%d", idx);
  if(*res) my_strcat(_ALLOC_ID_, res, " ");
  my_mstrcat(_ALLOC_ID_, res, "{", type, " ", idxbuf, " {", name ? name : "", "}}", NULL);
}

/* P7 ERC: pin-name integrity check (doc/claude/specs/cadence_pin_name_text.md §4.9).
 * Non-blocking, display/report only -- never changes objects or netlists. Scans the
 * PINLAYER pins of the CURRENT drawing (populated in symbol-edit mode) and flags:
 *   dup       two pins carry the same non-empty name= -- the pin<->view binding and the
 *             netlist pin order are ambiguous (highest value check).
 *   nameless  an OWNED pin (has a show_pinname token) whose name= is empty: it is meant
 *             to display a name but has none.
 *   legacy    an UN-owned pin (no show_pinname token) that still has a real, literal T
 *             name label next to it (owner_pin_id==0, content == pin name): a pre-model
 *             label the P8 migration must adopt/resolve (adoption gap).
 * Appends one "{type idx {name}}" element per issue to the Tcl list *result and emits a
 * human-readable warning per issue via statusmsg(...,2) (the ERC info window). Returns
 * the number of issues found. *result is left NULL when there are none. */
int check_pin_names(char **result)
{
  int i, t, np, n = 0;
  Int_hashtable name_table = {NULL, 0};
  double cg, tol;
  char msg[1024];
  if(!xctx) return 0;
  np = xctx->rects[PINLAYER];

  /* 1. Duplicate pin names. XINSERT_NOREPLACE keeps the FIRST index as the entry value, so
   *    a non-NULL return means this name is already present -> report the later pin. */
  int_hash_init(&name_table, HASHSIZE);
  for(i = 0; i < np; ++i) {
    char *nm = NULL;
    Int_hashentry *e;
    my_strdup(_ALLOC_ID_, &nm, get_tok_value(xctx->rect[PINLAYER][i].prop_ptr, "name", 0));
    if(!nm || !nm[0]) { my_free(_ALLOC_ID_, &nm); continue; } /* empty -> handled by check 2 */
    e = int_hash_lookup(&name_table, nm, i, XINSERT_NOREPLACE);
    if(e) {
      add_pin_issue(result, "dup", i, nm);
      my_snprintf(msg, S(msg),
        "Warning: duplicate pin name '%s' (pin %d duplicates pin %d)", nm, i, e->value);
      statusmsg(msg, 2);
      ++n;
    }
    my_free(_ALLOC_ID_, &nm);
  }
  int_hash_free(&name_table);

  /* 2. Owned but nameless: a show_pinname token present but an empty name=. */
  for(i = 0; i < np; ++i) {
    const char *prop = xctx->rect[PINLAYER][i].prop_ptr;
    if(!get_tok_value(prop, "show_pinname", 0)[0]) continue;     /* un-owned: outside model */
    if(get_tok_value(prop, "name", 0)[0]) continue;             /* has a name: ok */
    add_pin_issue(result, "nameless", i, "");
    my_snprintf(msg, S(msg),
      "Warning: pin %d has show_pinname set but an empty name", i);
    statusmsg(msg, 2);
    ++n;
  }

  /* 3. Legacy adoption gap: an un-owned pin (no show_pinname token) that still has a real,
   *    literal T label (owner_pin_id==0, i.e. NOT a synth view) near it whose content equals
   *    the pin name. Migration (P8) must adopt/resolve it. Proximity mirrors the editprop.c
   *    legacy bind (cadgrid-scaled), floored so a small cadgrid does not miss the default
   *    ~25-unit label offset. */
  cg = tclgetdoublevar("cadgrid");
  tol = cg * 3.0;
  if(tol < 60.0) tol = 60.0;
  for(i = 0; i < np; ++i) {
    xRect *p = &xctx->rect[PINLAYER][i];
    char *nm = NULL;
    double cx, cy;
    if(get_tok_value(p->prop_ptr, "show_pinname", 0)[0]) continue; /* owned: no legacy T */
    my_strdup(_ALLOC_ID_, &nm, get_tok_value(p->prop_ptr, "name", 0));
    if(!nm || !nm[0]) { my_free(_ALLOC_ID_, &nm); continue; }
    cx = (p->x1 + p->x2) / 2.0;
    cy = (p->y1 + p->y2) / 2.0;
    for(t = 0; t < xctx->texts; ++t) {
      xText *tx = &xctx->text[t];
      if(tx->owner_pin_id) continue;                    /* skip synthesized name views */
      if(!tx->txt_ptr || strcmp(tx->txt_ptr, nm)) continue;
      if(fabs(tx->x0 - cx) < tol && fabs(tx->y0 - cy) < tol) {
        add_pin_issue(result, "legacy", i, nm);
        my_snprintf(msg, S(msg),
          "Warning: pin %d ('%s') has an un-adopted legacy name label "
          "(run pin-name migration)", i, nm);
        statusmsg(msg, 2);
        ++n;
        break;
      }
    }
    my_free(_ALLOC_ID_, &nm);
  }
  return n;
}


void reset_caches(void)
{
  int i;
  dbg(1, "reset_caches()\n");
  for(i = 0; i < xctx->wires; i++) {
    set_wire_flags(&xctx->wire[i]);
  }
  for(i = 0; i < xctx->instances; i++) {
    set_inst_flags(&xctx->inst[i]);
  }
  for(i = 0; i < xctx->symbols; i++) {
    set_sym_flags(&xctx->sym[i]);
  }
}

/* what:
 * 1: create
 * 0: clear
 */
int set_rect_extraptr(int what, xRect *drptr)
{
  #if HAS_CAIRO==1
  if(what==1) { /* create */
    if(drptr->flags & 1024) { /* embedded image */
      if(!drptr->extraptr) {
        xEmb_image *d;
        d = my_malloc(_ALLOC_ID_, sizeof(xEmb_image));
        d->image = NULL;
        drptr->extraptr = d;
      }
    }
  } else {   /* clear */
    if(drptr->flags & 1024) { /* embedded image */
      if(drptr->extraptr) {
        xEmb_image *d = drptr->extraptr;
        if(d->image) {
           cairo_surface_destroy(d->image);
        }
        my_free(_ALLOC_ID_, &drptr->extraptr);
      }
    }
  }
  #endif
  return 0;
}

void clear_drawing(void)
{
  /* viewer plan item 9: the snap diamond belongs to the drawing that is going
   * away. Nothing to erase (the window is about to be repainted wholesale) --
   * just disarm, or the next hover would try to gctiled-erase a glyph at a
   * stale screen position. */
  xctx->graph_snap_on = 0;
  xctx->graph_snap_have_prev = 0;
 int i,j;
 /* S9 HOOK A (decision D2, issue 0466). THE file-re-read choke point, and the
  * reason this is here rather than in load_schematic() as issue 0466 originally
  * named: load_schematic() (save.c) has an early `return 0` reached AFTER
  * xctx->sch[currsch] is already rewritten, and it covers strictly less. One
  * line here covers `xschem reload` (the FileReload button -- the literal 0466
  * repro), `xschem load` of a different file, `load -keep_symbols` of the SAME
  * path (where remove_symbols never runs, so HOOK C cannot help), descend,
  * ascend, descend_symbol, disk undo via pop_undo(), in-memory undo/redo via
  * mem_restore_slot(), `xschem clear`, font reload and window/tab teardown --
  * the last of which also retires the epoch's dangling-ctx-compared-by-value
  * residual, since the data seq has moved by the time a recycled malloc address
  * could alias. The netlisters reach here per sub-sheet too; that is free (this
  * is a counter bump) but it is why every seam test wraps a SINGLE action. */
 annot_data_changed();
 /* the document is being torn down (load / clear / new / undo reload): any in-flight
  * Add-Pin cursor preview is now invalid, so drop the flag (cadence_pin_name_text.md
  * item #3) -- otherwise it would survive into the next document and mislead the next
  * -place re-arm / abort_operation. wirelabel_preview is cleared alongside it (must hold
  * the "cleared everywhere sympin_preview is" invariant, add_wire_label.md) so a torn-down
  * net-label preview cannot leak its drop-on-copper gate onto the next document's placements. */
 xctx->sympin_preview = 0;
 xctx->wirelabel_preview = 0;
 /* issue 0241: the stamped preview identity belongs to the document going away. The ids in it
  * name objects that no longer exist, and the next document restarts the id counters -- so a
  * survivor could resolve onto an UNRELATED new object and get deleted by the next abort. */
 clear_placement_preview();
 xctx->graph_lastsel = -1;
 /* Waveform markers: the selection is a NUMBER, and the same xctx is reused by
  * `xschem clear`, File>Open in the same tab, `xschem load` and the disk-undo
  * reload. A surviving selection would silently latch onto whatever marker in
  * the NEW document happens to carry that number -- the M1 case, i.e. the
  * common one -- drawing a selection ring the user never asked for and letting
  * Delete destroy that marker. Any in-flight drag dies with the document too.
  * doc/claude/specs/graph_markers.md */
 xctx->graph_marker_sel = -1;
 xctx->graph_marker_n_sel = 0;   /* issue 0189: a surviving SET latches exactly as a
                                  * surviving head does -- same reset class */
 xctx->graph_marker_selgraph = -1;
 xctx->graph_marker_drag = 0;
 xctx->graph_marker_dragmode = GRAPH_MARKER_MODE_NONE;
 xctx->graph_marker_dragnum = -1;
 xctx->graph_marker_draggraph = -1;
 xctx->graph_marker_moved = 0;
 /* issue 0190: an armed axis-region drag zoom is bound to a rect INDEX, and this
  * clear is about to invalidate every one of them. The same xctx is reused by
  * `xschem clear`, File>Open in the tab, `xschem load`, the disk-undo reload and
  * wviewer::regenerate's own clear_drawing, so a surviving arm would commit the
  * drag onto whatever rect lands at that index next. */
 xctx->graph_axis_drag = GRAPH_AXIS_NONE;
 xctx->graph_axis_draggraph = -1;
 xctx->graph_axis_press = 0.0;
 /* viewer plan item 6: the mid-drag shrink preview is transient chrome bound to
  * a graph index that this clear is about to invalidate. Left armed it would
  * shrink whatever trace happened to land at that index next. */
 xctx->graph_preview_scale = 0.0;
 xctx->graph_preview_gi = 0;
 xctx->graph_preview_wave = 0;
 /* issue 0192: the SET joins the same reset class for the same reason -- a
  * surviving arm would shrink whatever traces land at those indices next. */
 xctx->graph_preview_n = 0;
 /* Trace highlights (doc/claude/specs/wave_trace_hilight.md §4.2): the same
  * reset class again, and the entry that makes it load-bearing rather than
  * tidy. wviewer::regenerate calls `xschem clear_drawing` and re-places every
  * strip -- and a plain window RESIZE calls regenerate (landmine 50) -- so a
  * surviving (gi, ni) would highlight whatever trace lands at that index in
  * the rebuilt stack. The set is re-applied from its Tcl authority right after,
  * which is exactly why D4 puts the authority there and not here.
  * The envelope cache goes with it: it is keyed on the raw and the geometry,
  * both of which this clear invalidates, and losing it is a rebuild. */
 xctx->wave_hilight_n = 0;
 wave_hilight_cache_free();
 del_inst_table();
 del_wire_table();
 my_free(_ALLOC_ID_, &xctx->schtedaxprop);
 my_free(_ALLOC_ID_, &xctx->schsymbolprop);
 my_free(_ALLOC_ID_, &xctx->schprop);
 my_free(_ALLOC_ID_, &xctx->schvhdlprop);
 my_free(_ALLOC_ID_, &xctx->schverilogprop);
 my_free(_ALLOC_ID_, &xctx->schspectreprop);
 my_free(_ALLOC_ID_, &xctx->version_string);
 if(xctx->header_text) my_free(_ALLOC_ID_, &xctx->header_text);
 wire_storage_reset();
 inst_storage_reset();
 for(i=0;i<xctx->texts; ++i)
 {
  my_free(_ALLOC_ID_, &xctx->text[i].font);
  my_free(_ALLOC_ID_, &xctx->text[i].floater_instname);
  my_free(_ALLOC_ID_, &xctx->text[i].floater_ptr);
  my_free(_ALLOC_ID_, &xctx->text[i].prop_ptr);
  my_free(_ALLOC_ID_, &xctx->text[i].txt_ptr);
 }
 xctx->texts = 0;
 for(i=0;i<cadlayers; ++i)
 {
  for(j=0;j<xctx->lines[i]; ++j)
  {
   my_free(_ALLOC_ID_, &xctx->line[i][j].prop_ptr);
  }
  for(j=0;j<xctx->rects[i]; ++j)
  {
   my_free(_ALLOC_ID_, &xctx->rect[i][j].prop_ptr);
   set_rect_extraptr(0, &xctx->rect[i][j]);
  }
  for(j=0;j<xctx->arcs[i]; ++j)
  {
   my_free(_ALLOC_ID_, &xctx->arc[i][j].prop_ptr);
  }
  for(j=0;j<xctx->polygons[i]; ++j) {
    my_free(_ALLOC_ID_, &xctx->poly[i][j].x);
    my_free(_ALLOC_ID_, &xctx->poly[i][j].y);
    my_free(_ALLOC_ID_, &xctx->poly[i][j].prop_ptr);
    my_free(_ALLOC_ID_, &xctx->poly[i][j].selected_point);
  }
  xctx->lines[i] = 0;
  xctx->arcs[i] = 0;
  xctx->rects[i] = 0;
  xctx->polygons[i] = 0;
 }
 dbg(1, "clear drawing(): deleted data structures, now deleting hash\n");
 int_hash_free(&xctx->inst_name_table);
 int_hash_free(&xctx->floater_inst_table);
}

/*  xctx->n_active_layers is the total number of layers for hilights. */
void enable_layers(void)
{
  int i;
  char tmp[50];
  int en;
  xctx->n_active_layers = 0;
  for(i = 0; i< cadlayers; ++i) {
    my_snprintf(tmp, S(tmp), "enable_layer(%d)",i);
    en = tclgetboolvar(tmp);
    if(!en) xctx->enable_layer[i] = 0;
    else {
      xctx->enable_layer[i] = 1;
      if(i>=7) {
        xctx->active_layer[xctx->n_active_layers] = i;
        xctx->n_active_layers++;
      }
    }
  }
  build_net_hilight_styles(); /* keep net hilight style table in sync with active layers */
}


/* not used... */
void clear_partial_selected_wires(void)
{
  int j;
  rebuild_selected_array();
  for(j=0; j < xctx->lastsel; ++j) if(xctx->sel_array[j].type == WIRE) {
    int wire = xctx->sel_array[j].n;
    select_wire(wire, 0, 1, 1);
  }
  xctx->need_reb_sel_arr = 1;
  rebuild_selected_array();
}


/* Add wires when moving instances or wires */
int connect_by_kissing(void)
{
  xSymbol *symbol;
  int npin, i, j;
  double x0,y0, pinx0, piny0;
  int kissing, changed = 0;
  int k, ii, done_undo = 0;
  /* doc/claude/specs/wire_label_ride.md R3 (S3, change #8): read the ride preference ONCE per
   * sweep -- the wire-endpoint arm below consults it per candidate pin. */
  int label_ride_on = tclgetboolvar("label_ride");
  Wireentry *wptr;
  Instpinentry *iptr;
  int sqx, sqy;
  Str_hashtable coord_table = {NULL, 0}; /* hash table to add new wires at a given position only once */
  char coord[200]; /* string representation of 'x0 y0' or 'pinx0 piny0' */

  str_hash_init(&coord_table, HASHSIZE);
  rebuild_selected_array();
  k = xctx->lastsel;
  prepare_netlist_structs(0); /* rebuild spatial hashes */

  /* add wires to moving instance pins */
  for(j=0;j<k; ++j) if(xctx->sel_array[j].type==ELEMENT) {
    int inst = xctx->sel_array[j].n;
    symbol = xctx->sym + xctx->inst[inst].ptr;
    /* doc/claude/specs/wire_label_ride.md R1 (S1, change #4): a NET LABEL's pin is a naming
     * anchor, not copper. The stub minted below is a gesture artifact -- it is rubber-banded
     * into real copper by the drag, which is what leaks a duplicate collinear N record when the
     * label slides ALONG its wire and leaves a permanent perpendicular stub when it is dragged
     * OFF it (spec §4.1). Nothing reads that stub as the label-to-net connection: the label is
     * bound to the wire by touch() at netlist time (netlist.c:1034), interior included.
     * What replaces it is the LEASH (label_ride_capture/apply, move.c): the label is projected
     * back onto its owner's span at move END, so it can slide along the wire but never leave it.
     * NEVER ship this skip without that leash -- alone it turns an ugly-but-connected stub into
     * a silent orphan. ipin/opin/iopin and every device pin are untouched (inst_is_netlabel is
     * strcmp "label", not IS_LABEL_OR_PIN), and so is the wire-endpoint arm below (change #8,
     * which must ship with RIDE in S3). */
    if(inst_is_netlabel(inst)) continue;
    npin = symbol->rects[PINLAYER];
    for(i=0;i<npin; ++i) {
      get_inst_pin_coord(inst, i, &pinx0, &piny0);
      get_square(pinx0, piny0, &sqx, &sqy);
      iptr=xctx->instpin_spatial_table[sqx][sqy];
      wptr=xctx->wire_spatial_table[sqx][sqy];
      kissing=0;
      while(iptr) {
        ii = iptr->n;
        if(ii == inst) {
          iptr = iptr->next;
          continue;
        }
        if( iptr->x0 == pinx0 && iptr->y0 == piny0  && xctx->inst[ii].sel == 0) {
          kissing = 1;
          break;
        }
        iptr = iptr->next;
      }
      while(wptr) {
        xWire *w = &xctx->wire[wptr->n];
        if( touch(w->x1, w->y1, w->x2, w->y2, pinx0, piny0) && w->sel == 0) {
          kissing = 1;
          break;
        }
        wptr = wptr->next;
      }
      if(kissing) {

        if(!done_undo) {
          xctx->push_undo();
          done_undo = 1;
        }
        my_snprintf(coord, S(coord), "%.16g %.16g", pinx0, piny0);
        if (str_hash_lookup(&coord_table, coord, "", XLOOKUP)==NULL) {
          dbg(1, "connect_by_kissing(): adding wire in %g %g, wires before = %d\n", pinx0, piny0, xctx->wires);
          str_hash_lookup(&coord_table, coord, "", XINSERT);
          storeobject(-1, pinx0, piny0,  pinx0, piny0, WIRE, 0, SELECTED1, NULL);
          changed = 1;
          xctx->prep_hash_wires=0;
          xctx->need_reb_sel_arr = 1;
        }
      }
    }
  }

  /* add wires to moving wire endpoints */
  for(j=0; j < k; ++j) if(xctx->sel_array[j].type == WIRE) {
    int wire = xctx->sel_array[j].n;
    if(xctx->wire[wire].sel != SELECTED) continue; /* skip partially selected wires */
    for(i=0;i<2; ++i) {
      if(i == 0) {
        x0 = xctx->wire[wire].x1;
        y0 = xctx->wire[wire].y1;
      } else {
        x0 = xctx->wire[wire].x2;
        y0 = xctx->wire[wire].y2;
      }

      get_square(x0, y0, &sqx, &sqy);
      iptr=xctx->instpin_spatial_table[sqx][sqy];
      wptr=xctx->wire_spatial_table[sqx][sqy];
      kissing=0;
      while(iptr) {
        ii = iptr->n;
        dbg(1, "connect_by_kissing(): ii=%d, x0=%g, y0=%g,  iptr->x0=%g, iptr->y0=%g\n",
               ii, x0, y0, iptr->x0, iptr->y0);
        /* doc/claude/specs/wire_label_ride.md R3 (S3, change #8): the TETHER. This arm is
         * wire-endpoint driven, so the instance tested through iptr is the STATIONARY one -- a net
         * label sitting on the endpoint of a wire this gesture is about to move. The stub minted
         * below is what has kept such a label attached; RIDE replaces it by carrying the label
         * itself, orientation included, which is the Cadence behaviour and what R1/§5.1 mean by
         * "no invented copper".
         * MUST NOT SHIP WITHOUT RIDE. Post-S2 a mid-span label is interior to one wire and this arm
         * never sees it, but an END-OF-STUB label -- the dominant topology the wire-stub+netlabel
         * idiom produces -- is exactly on the endpoint, and this stub is the only thing holding it.
         * Removing it without the rider widens S2's unmask from mid-span labels to ALL of them.
         * Hence the shared `label_ride` gate: the preference switches the stub and the ride
         * together, so 0 restores pre-S3 behaviour rather than leaving the label with neither.
         * ipin/opin/iopin and every device pin are untouched (inst_is_netlabel is strcmp "label",
         * not IS_LABEL_OR_PIN), and so is the ELEMENT arm above, which handles the mirrored case
         * (a moving DEVICE carrying a stationary label on its pin). */
        if( iptr->x0 == x0 && iptr->y0 == y0  &&  xctx->inst[ii].sel == 0 &&
            !(label_ride_on && inst_is_netlabel(ii)) ) {
          kissing = 1;
          break;
        }
        iptr = iptr->next;
      }
      while(wptr) {
        xWire *w = &xctx->wire[wptr->n];
        if(wire == wptr->n) {
          wptr = wptr->next;
          continue;
        }
        if( touch(w->x1, w->y1, w->x2, w->y2, x0, y0) && w->sel == 0) {
          kissing = 1;
          break;
        }
        wptr = wptr->next;
      }
      if(kissing) {
        if(!done_undo) {
          xctx->push_undo();
          done_undo = 1;
        }
        my_snprintf(coord, S(coord), "%.16g %.16g", x0, y0);
        if (str_hash_lookup(&coord_table, coord, "", XLOOKUP)==NULL) {
          dbg(1, "connect_by_kissing(): adding wire in %g %g, wires before = %d\n", x0, y0, xctx->wires);
          str_hash_lookup(&coord_table, coord, "", XINSERT);
          storeobject(-1, x0, y0,  x0, y0, WIRE, 0, SELECTED1, NULL);
          changed = 1;
          xctx->prep_hash_wires=0;
          xctx->need_reb_sel_arr = 1;
        }
      }
    }
  }
  str_hash_free(&coord_table);
  rebuild_selected_array();
  return changed;
}

int unselect_partial_sel_wires(void)
{
  xSymbol *symbol;
  int npin, i, j;
  double x0,y0, pinx0, piny0;
  int changed = 0;
  int k;
  Wireentry *wptr;
  int sqx, sqy;

  if(!tclgetboolvar("unselect_partial_sel_wires")) return 0;
  rebuild_selected_array();
  k = xctx->lastsel;
  prepare_netlist_structs(0); /* rebuild spatial hashes */
  /* unselect wires attached to moved instance pins */
  for(j=0;j<k; ++j) if(xctx->sel_array[j].type==ELEMENT) {
    int inst = xctx->sel_array[j].n;
    symbol = xctx->sym + xctx->inst[inst].ptr;
    npin = symbol->rects[PINLAYER];
    for(i=0;i<npin; ++i) {
      get_inst_pin_coord(inst, i, &pinx0, &piny0);
      get_square(pinx0, piny0, &sqx, &sqy);
      wptr=xctx->wire_spatial_table[sqx][sqy];
      while(wptr) {
        xWire *w = &xctx->wire[wptr->n];
        if(touch(w->x1, w->y1, w->x2, w->y2, pinx0, piny0) && w->sel && w->sel != SELECTED) {
          select_wire(wptr->n, 0, 1, 1);
          changed = 1;
        }
        wptr = wptr->next;
      }
    }
  }
  /* unselect wires attached to moved wire endpoints */
  for(j=0; j < k; ++j) if(xctx->sel_array[j].type == WIRE) {
    int wire = xctx->sel_array[j].n;
    if(xctx->wire[wire].sel != SELECTED) continue; /* skip partially selected wires */
    for(i=0;i<2; ++i) {
      if(i == 0) {
        x0 = xctx->wire[wire].x1;
        y0 = xctx->wire[wire].y1;
      } else {
        x0 = xctx->wire[wire].x2;
        y0 = xctx->wire[wire].y2;
      }
      get_square(x0, y0, &sqx, &sqy);
      wptr=xctx->wire_spatial_table[sqx][sqy];
      while(wptr) {
        xWire *w = &xctx->wire[wptr->n];
        if(wire == wptr->n) {
          wptr = wptr->next;
          continue;
        }
        if(touch(w->x1, w->y1, w->x2, w->y2, x0, y0) && w->sel && w->sel != SELECTED) {
          xctx->wire[wptr->n].sel = 0;
          select_wire(wptr->n, 0, 1, 1);
          changed = 1;
        }
        wptr = wptr->next;
      }
    }
  }
  return changed;
}


/* interactive = 0: do not present dialog box
 * interactive = 1: present dialog box
 * interactive = 2: attach lab_show to unconnected pins, no dialog box
 */
void attach_labels_to_inst(int interactive) /*  offloaded from callback.c 20171005 */
{
  xSymbol *symbol;
  int npin, i, j;
  double x0,y0, pinx0, piny0;
  short flip, rot, rot1 ;
  xRect *rct;
  char *labname=NULL;
  char *prop=NULL; /*  20161122 overflow safe */
  char *symname_pin = NULL;
  char *symname_wire = NULL;
  char *symname_show = NULL;
  char *type=NULL;
  short dir;
  int k,ii, skip;
  int do_all_inst=0;
  const char *rot_txt;
  int rotated_text=-1;

  Wireentry *wptr;
  Instpinentry *iptr;
  int sqx, sqy;
  int first_call;
  int use_label_prefix;
  int found=0;

  my_strdup(_ALLOC_ID_, &symname_pin, tcleval("find_file_first lab_pin.sym"));
  my_strdup(_ALLOC_ID_, &symname_wire, tcleval("find_file_first lab_wire.sym"));
  my_strdup(_ALLOC_ID_, &symname_show, tcleval("find_file_first lab_show.sym"));
  if(symname_pin && symname_wire && symname_show) {
    rebuild_selected_array();
    k = xctx->lastsel;
    first_call=1;
    prepare_netlist_structs(0);
    for(j=0;j<k; ++j) if(xctx->sel_array[j].type==ELEMENT) {
      found=1;
      my_strdup(_ALLOC_ID_, &prop, xctx->inst[xctx->sel_array[j].n].instname);
      my_strcat(_ALLOC_ID_, &prop, "_");
      tclsetvar("custom_label_prefix",prop);

      if(interactive == 1 && !do_all_inst) {
        dbg(1,"attach_labels_to_inst(): invoking tcl attach_labels_to_inst\n");
        tcleval("attach_labels_to_inst");
        if(!strcmp(tclgetvar("tctx::rcode"),"") ) {
          bbox(END, 0., 0., 0., 0.);
          my_free(_ALLOC_ID_, &prop);
          return;
        }
      }
      if(interactive != 1 ) {
        tclsetvar("tctx::rcode", "yes");
        tclsetvar("use_lab_wire", "0");
        tclsetvar("use_label_prefix", "0");
        tclsetvar("do_all_inst", "1");
        tclsetvar("rotated_text", "0");
      }
      use_label_prefix = tclgetboolvar("use_label_prefix");
      rot_txt = tclgetvar("rotated_text");
      if(strcmp(rot_txt,"")) rotated_text=atoi(rot_txt);
      my_strdup(_ALLOC_ID_, &type,(xctx->inst[xctx->sel_array[j].n].ptr+ xctx->sym)->type);
      if( type && IS_LABEL_OR_PIN(type) ) {
        continue;
      }
      if(!do_all_inst && tclgetboolvar("do_all_inst")) do_all_inst=1;
      dbg(1, "attach_labels_to_inst(): 1--> %s %.16g %.16g   %s\n",
          xctx->inst[xctx->sel_array[j].n].name,
          xctx->inst[xctx->sel_array[j].n].x0,
          xctx->inst[xctx->sel_array[j].n].y0,
          xctx->sym[xctx->inst[xctx->sel_array[j].n].ptr].name);

      x0 = xctx->inst[xctx->sel_array[j].n].x0;
      y0 = xctx->inst[xctx->sel_array[j].n].y0;
      rot = xctx->inst[xctx->sel_array[j].n].rot;
      flip = xctx->inst[xctx->sel_array[j].n].flip;
      symbol = xctx->sym + xctx->inst[xctx->sel_array[j].n].ptr;
      npin = symbol->rects[PINLAYER];
      rct=symbol->rect[PINLAYER];

      for(i=0;i<npin; ++i) {
         my_strdup(_ALLOC_ID_, &labname,get_tok_value(rct[i].prop_ptr,"name",1));
         dbg(1,"attach_labels_to_inst(): 2 --> labname=%s\n", labname);

         pinx0 = (rct[i].x1+rct[i].x2)/2;
         piny0 = (rct[i].y1+rct[i].y2)/2;

         if(strcmp(get_tok_value(rct[i].prop_ptr,"dir",0),"in")) dir=1; /*  out or inout pin */
         else dir=0; /*  input pin */

         /*  opin or iopin on left of symbol--> reverse orientation 20171205 */
         if(rotated_text ==-1 && dir==1 && pinx0<0) dir=0;

         ROTATION(rot, flip, 0.0, 0.0, pinx0, piny0, pinx0, piny0);

         pinx0 += x0;
         piny0 += y0;

         get_square(pinx0, piny0, &sqx, &sqy);
         iptr=xctx->instpin_spatial_table[sqx][sqy];
         wptr=xctx->wire_spatial_table[sqx][sqy];

         skip=0;
         while(iptr) {
           ii = iptr->n;
           if(ii == xctx->sel_array[j].n) {
             iptr = iptr->next;
             continue;
           }

           if( iptr->x0 == pinx0 && iptr->y0 == piny0 ) {
             skip=1;
             break;
           }
           iptr = iptr->next;
         }
         while(wptr) {
           if( touch(xctx->wire[wptr->n].x1, xctx->wire[wptr->n].y1,
               xctx->wire[wptr->n].x2, xctx->wire[wptr->n].y2, pinx0, piny0) ) {
             skip=1;
             break;
           }
           wptr = wptr->next;
         }
         if(!skip) {
           my_strdup(_ALLOC_ID_, &prop, "name=p1 lab=");
           if(use_label_prefix) {
             my_strcat(_ALLOC_ID_, &prop, (char *)tclgetvar("custom_label_prefix"));
           }
           /*  /20171005 */

           my_strcat(_ALLOC_ID_, &prop, labname);
           dir ^= flip; /*  20101129  20111030 */
           if(rotated_text ==-1) {
             rot1=rot;
             if(rot1==1 || rot1==2) { dir=!dir;rot1 = (short)((rot1+2) %4);}
           } else {
             rot1=(short)((rot+rotated_text)%4); /*  20111103 20171208 text_rotation */
           }
           if(interactive == 2) {
             place_symbol(-1,symname_show, pinx0, piny0, rot1, dir, prop, 2, first_call, 1/*to_push_undo*/);
           } else if(!tclgetboolvar("use_lab_wire")) {
             place_symbol(-1,symname_pin, pinx0, piny0, rot1, dir, prop, 2, first_call, 1/*to_push_undo*/);
           } else {
             place_symbol(-1,symname_wire, pinx0, piny0, rot1, dir, prop, 2, first_call, 1/*to_push_undo*/);
           }
           first_call=0;
         }
         dbg(1, "attach_labels_to_inst(): %d   %.16g %.16g %s\n", i, pinx0, piny0,labname);
      }
    }
    if(first_call == 0) set_modify(1);
    my_free(_ALLOC_ID_, &prop);
    my_free(_ALLOC_ID_, &labname);
    my_free(_ALLOC_ID_, &type);
    if(!found) return;
    /*  draw things  */
    if(!first_call) {
      bbox(SET , 0.0 , 0.0 , 0.0 , 0.0);
      draw();
      bbox(END , 0.0 , 0.0 , 0.0 , 0.0);
    }
  } else {
    fprintf(errfp, "attach_labels_to_inst(): location of schematic labels not found\n");
    tcleval("alert_ {attach_labels_to_inst(): location of schematic labels not found} {}");
  }
  /* if hilights are present in schematic propagate to new added labels */
  if(xctx->hilight_nets) {
    propagate_hilights(1, 0, XINSERT_NOREPLACE);
    redraw_hilights(0);
  }
  my_free(_ALLOC_ID_, &symname_pin);
  my_free(_ALLOC_ID_, &symname_wire);
  my_free(_ALLOC_ID_, &symname_show);
}

void delete_files(void)
{
  char str[PATH_MAX + 100];
  rebuild_selected_array();
  if(xctx->lastsel && xctx->sel_array[0].type==ELEMENT) {
    my_snprintf(str, S(str), "delete_files {%s}",
         abs_sym_path(tcl_hook2(xctx->inst[xctx->sel_array[0].n].name), ""));
  } else {
    my_snprintf(str, S(str), "delete_files {%s}",
         abs_sym_path(xctx->sch[xctx->currsch], ""));
  }
  tcleval(str);
}

void place_net_label(int type)
{
  /* phase 2 of doc/claude/suggestions/plan_modal_gesture_exclusion.md (issue 0247) -- see
   * leave_wire_draw_for() in scheduler.c for the rule and why it is not optional. ONE call here
   * covers every route to a net-label placement: Alt+Shift+L (type 0), Ctrl+P (2),
   * Ctrl+Shift+P (3) and the scripted `xschem net_label 0|1|2|3`. All of them arm a cursor
   * placement (START_SYMPIN + a real lab_wire / lab_pin / ipin / opin preview instance riding the
   * pointer); none is a commit form, so there is no coordinate sub-form to exclude here. */
  leave_wire_draw_for("Net label");
  leave_shape_draw_for("Net label");   /* issue 0269 -- phase 3, the SHAPE twin: see leave_shape_draw_for() (callback.c) */
  /* issue 0242 -- see leave_placement_for() (callback.c). The other modal gesture this arm can
   * land on: it ORs START_SYMPIN over a live Add-Wire-Label / Add-Pin preview and shares its
   * STARTMOVE, so the earlier preview instance is left committed in the drawing -- a connected,
   * netlist-visible lab_pin that renames the net under it. Measured as a door on all four types
   * via the scripted `xschem net_label 0|1|2|3` (orphan=1 on each). This arm was NOT in the
   * issue's 17-verb census; the tripwire found it, which is what the tripwire is for. */
  leave_placement_for("Net label");
  /* issue 0265 -- and the third modal gesture this arm can land on: a pending PASTE. The
   * unselect_all(1) inside place_symbol()/place_wire_label() below zeroes ui_state wholesale, so
   * STARTMERGE went away with no delete() and the paste stayed COMMITTED in the drawing. Always
   * after leave_placement_for(): the two share xctx->preview_sel (abort_pending_merge(),
   * callback.c). */
  leave_merge_for("Net label");
  if(type == 1) {
      const char *lab = tcleval("find_file_first lab_pin.sym");
      place_symbol(-1, lab, xctx->mousex_snap, xctx->mousey_snap, 0, 0, NULL, 4, 1, 1/*to_push_undo*/);
  } else if(type == 0) {
      const char *lab = tcleval("find_file_first lab_wire.sym");
      place_symbol(-1, lab, xctx->mousex_snap, xctx->mousey_snap, 0, 0, NULL, 4, 1, 1/*to_push_undo*/);
  } else if(type == 2) {
      const char *lab = tcleval("find_file_first ipin.sym");
      place_symbol(-1, lab, xctx->mousex_snap, xctx->mousey_snap, 0, 0, NULL, 4, 1, 1/*to_push_undo*/);
  } else if(type == 3) {
      const char *lab = tcleval("find_file_first opin.sym");
      place_symbol(-1, lab, xctx->mousex_snap, xctx->mousey_snap, 0, 0, NULL, 4, 1, 1/*to_push_undo*/);
  }
  move_objects(START,0,0,0);
  stamp_placement_preview();   /* issue 0241 -- see stamp_placement_preview() in select.c */
  xctx->ui_state |= START_SYMPIN;
}

/* Place one schematic port-pin INSTANCE named <name> at the cursor, SELECTED so it can be
 * dragged as a placement preview -- the schematic analog of create_pin (which places a symbol
 * PINLAYER rect). See doc/claude/specs/schematic_add_pin.md. Direction picks the device symbol:
 *   in -> ipin.sym   out -> opin.sym   inout|other -> iopin.sym
 * The port's net name is its lab= property; "name=p1" lets new_prop_string uniquify the refdes.
 * to_push_undo is 0: the modeless `add_sch_pin -place` driver manages one undo baseline across
 * the per-keystroke re-arms itself. Returns place_symbol()'s result (1 placed, 0 not). */
int place_sch_pin(const char *name, const char *dir)
{
  char symbuf[PATH_MAX];
  char *prop = NULL;
  const char *symcmd;
  int r;
  if(!xctx) return 0;
  if(!name) name = "";
  if(!dir || !dir[0]) dir = "inout";
  if(!strcmp(dir, "in"))       symcmd = "find_file_first ipin.sym";
  else if(!strcmp(dir, "out")) symcmd = "find_file_first opin.sym";
  else                         symcmd = "find_file_first iopin.sym";
  /* copy the resolved path out of the volatile Tcl result BEFORE place_symbol runs its own
   * tclevals (abs_sym_path/is_xschem_file), which would clobber it. */
  my_strncpy(symbuf, tcleval(symcmd), S(symbuf));
  my_mstrcat(_ALLOC_ID_, &prop, "name=p1 lab=", name, NULL);
  r = place_symbol(-1, symbuf, xctx->mousex_snap, xctx->mousey_snap, 0, 0, prop,
                   4 /* select the new instance */, 1 /* first_call */,
                   0 /* to_push_undo: the -place driver owns the undo baseline */);
  my_free(_ALLOC_ID_, &prop);
  return r;
}

/* Place one Cadence net-label INSTANCE (lab_pin.sym, lab=<name>) at the cursor, SELECTED as a
 * placement preview -- the label twin of place_sch_pin (place_net_label(1) with a pre-filled
 * name). See doc/claude/specs/add_wire_label.md. The net name is the lab= property; "name=l1"
 * lets new_prop_string uniquify the (netlist-irrelevant) refdes. to_push_undo is 0: the modeless
 * `add_wire_label -place` driver owns the single undo baseline across the per-keystroke re-arms.
 * Returns place_symbol()'s result (1 placed, 0 not). */
int place_wire_label(const char *name)
{
  char symbuf[PATH_MAX];
  char *prop = NULL;
  int r;
  if(!xctx) return 0;
  if(!name) name = "";
  /* copy the resolved path out of the volatile Tcl result BEFORE place_symbol runs its own
   * tclevals (abs_sym_path/is_xschem_file), which would clobber it. */
  my_strncpy(symbuf, tcleval("find_file_first lab_pin.sym"), S(symbuf));
  my_mstrcat(_ALLOC_ID_, &prop, "name=l1 lab=", name, NULL);
  r = place_symbol(-1, symbuf, xctx->mousex_snap, xctx->mousey_snap, 0, 0, prop,
                   4 /* select the new instance */, 1 /* first_call */,
                   0 /* to_push_undo: the -place driver owns the undo baseline */);
  my_free(_ALLOC_ID_, &prop);
  return r;
}

/* True when the top-level view currently being edited is a symbol (.sym). Symbol
 * views hold only pins + artwork -- never instances of other symbols -- so instance
 * creation is refused there (see place_symbol). This is deliberately a filename test,
 * NOT netlist_type==CAD_SYMBOL_ATTRS: a freshly loaded EMPTY schematic also carries
 * that netlist_type (load_schematic sets it when instances==0), yet placing the first
 * instance into a blank schematic must be allowed. The ".sym" extension is exactly the
 * signal load_schematic() itself uses to decide symbol-ness. */
int editing_symbol_view(void)
{
  const char *s;
  size_t len;
  if(!xctx) return 0;
  s = xctx->sch[xctx->currsch];
  if(!s) return 0;
  len = strlen(s);
  return (len >= 4 && !strcmp(s + len - 4, ".sym"));
}

/*  draw_sym==4 select element after placing */
/*  draw_sym==2 begin bbox if(first_call), add bbox */
/*  draw_sym==1 begin bbox if(first_call), add bbox, end bbox, draw placed symbols  */
/*  */
/*  first_call: set to 1 on first invocation for a given set of symbols (same prefix) */
/*  set to 0 on next calls, this speeds up searching for unique names in prop string */
/*  returns 1 if symbol successfully placed, 0 otherwise */
int place_symbol(int pos, const char *symbol_name, double x, double y, short rot, short flip,
                   const char *inst_props, int draw_sym, int first_call, int to_push_undo)
/*  if symbol_name is a valid string load specified cell and */
/*  use the given params, otherwise query user */
{
 int i,j,n;
 char name[PATH_MAX];
 char name1[PATH_MAX];
 char tclev = 0;

 /* Render instance creation impotent in a symbol view, from EVERY route: the Cadence
  * `i` form, native `I`, the Insert-symbol dialog, menus, the Library Manager, and the
  * `xschem instance` / `xschem place_symbol` commands all funnel through here, so this
  * single guard covers them all regardless of what they are bound to. Refuse before the
  * file dialog / undo push so nothing is created and no undo slot is spent. The friendly
  * modal lives at the ciform chokepoint; here we just do nothing. */
 if(editing_symbol_view()) return 0;

 if(symbol_name==NULL) {
   tcleval("load_file_dialog {Choose symbol} *.\\{sym,tcl\\} INITIALINSTDIR");
   my_strncpy(name1, tclresult(), S(name1));
 } else {
   my_strncpy(name1, abs_sym_path(trim_chars(symbol_name, " \t\n"), ""), S(name1));
 }
 if(!name1[0]) return 0;
 dbg(1, "place_symbol(): 1: name1=%s first_call=%d\n",name1, first_call);
 /* remove tcleval( given in file selector, if any ... */
 if(strstr(name1, "tcleval(")) {
   tclev = 1;
   my_snprintf(name1, S(name1), "%s", str_replace(name1, "tcleval(", "", 0, -1));
 }
 dbg(1, "place_symbol(): 2: name1=%s\n",name1);

 tcl_call("is_xschem_file", name1, NULL, NULL);
 if(!strcmp(tclresult(), "GENERATOR")) {
   size_t len = strlen(name1);
   if( name1[len - 1] != ')') my_snprintf(name, S(name), "%s()", name1);
   else my_strncpy(name, name1, S(name));
 } else {
   my_strncpy(name, name1, S(name));
 }
 my_strncpy(name1, rel_sym_path(name), S(name1));
 /* ... and re-add tcleval( around relative path symbol name */
 if(tclev) {
   my_snprintf(name, S(name), "tcleval(%s", name1);
 } else {
   my_strncpy(name, name1, S(name));
 }
 if(!name[0]) return 0;
 /* issue 0125 residual: resolve the symbol BEFORE push_undo (match_symbol is
  * idempotent and never returns -1, token.c) so the scope-ammeter refusal below
  * can bail without burning an undo slot. Snapshot-ordering delta is harmless:
  * the undo slot may now contain one extra unreferenced symbol def. */
 i = match_symbol(name);
 /* Pre-flight twin of the in-body scope-ammeter bail (below, at the
  * rects[PINLAYER]==0 arm): a type=scope symbol with no pins needs exactly one
  * selected ELEMENT to link to; refuse BEFORE push_undo and before any mutation.
  * lastsel/sel_array are read raw, in deliberate parity with the in-body check.
  * The in-body bail stays as a backstop for the exotic translate()-swapped-symbol
  * path (that path still burns a slot - documented residual in issue 0125). */
 if(xctx->sym[i].type && !strcmp(xctx->sym[i].type, "scope")
    && xctx->sym[i].rects[PINLAYER] == 0
    && !(xctx->lastsel == 1 && xctx->sel_array[0].type == ELEMENT)) {
   const char msg[]="scope_ammeter is being inserted but no selected ammeter device/vsource to link to\n";
   dbg(0, "%s", msg);
   if(has_x) tclvareval("alert_ {", msg, "} {} 1", NULL);
   return 0;
 }
 if(first_call && to_push_undo) xctx->push_undo();

 if(i!=-1)
 {
  if(first_call) hash_names(-1, XINSERT);
  check_inst_storage();
  if(pos==-1 || pos > xctx->instances) n=xctx->instances;
  else
  {
   xctx->prep_hash_inst = 0; /* instances moved so need to rebuild hash */
   for(j=xctx->instances;j>pos;j--)
   {
    xctx->inst[j]=xctx->inst[j-1];
   }
   n=pos;
  }
  /*  03-02-2000 */
  dbg(1, "place_symbol(): checked inst_ptr storage, sym number i=%d\n", i);
  xctx->inst[n].ptr = i;
  xctx->inst[n].name=NULL;
  xctx->inst[n].lab=NULL;
  dbg(1, "place_symbol(): entering my_strdup: name=%s\n",name);  /*  03-02-2000 */
  my_strdup2(_ALLOC_ID_, &xctx->inst[n].name ,name);
  dbg(1, "place_symbol(): done my_strdup: name=%s\n",name);  /*  03-02-2000 */
  /*  xctx->inst[n].x0=symbol_name ? x : xctx->mousex_snap; */
  /*  xctx->inst[n].y0=symbol_name ? y : xctx->mousey_snap; */
  xctx->inst[n].x0= x ; /*  20070228 x and y given in callback */
  xctx->inst[n].y0= y ;
  xctx->inst[n].rot=symbol_name ? rot : 0;
  xctx->inst[n].flip=symbol_name ? flip : 0;

  xctx->inst[n].flags=0;
  xctx->inst[n].color=-10000; /* small negative values used for simulation */
  xctx->inst[n].sel=0;
  xctx->inst[n].node=NULL;
  xctx->inst[n].prop_ptr=NULL;
  xctx->inst[n].instname=NULL;
  xctx->inst[n].pin_sel=NULL;       /* transient pin selection: a reused slot (after
                                     * inst_delete_compact) may carry a stale/aliased
                                     * pin_sel pointer; clear it (pin_selection.md) */
  xctx->inst[n].pin_sel_size=0;
  dbg(1, "place_symbol() :all inst_ptr members set\n");  /*  03-02-2000 */
  if(inst_props) {
    new_prop_string(n, inst_props, tclgetboolvar("disable_unique_names")); /*  20171214 first_call */
  }
  else {
    set_inst_prop(n); /* no props, get from sym template, also calls new_prop_string() */
  }
  dbg(1, "place_symbol(): done set_inst_prop()\n");  /*  03-02-2000 */


  inst_register(n);/* translate expects the correct balue of xctx->instances */
  /* After having assigned prop_ptr to new instance translate symbol reference
   * to resolve @params  --> res.tcl(@value\) --> res.tcl(100) */
  my_strncpy(name, translate(n, name), S(name));
  /* parameters like res.tcl(@value\) have been resolved, so reload symbol removing previous */
  if(strcmp(name, name1)) {
    remove_symbol(i);
    i = match_symbol(name);
  }
  xctx->inst[n].ptr = i;
  set_inst_flags(&xctx->inst[n]);
  hash_names(n, XINSERT);
  if(first_call && (draw_sym & 3) ) bbox(START, 0.0 , 0.0 , 0.0 , 0.0);
  /* force these vars to 0 to trigger a prepare_netlist_structs(0) needed by symbol_bbox->translate
   * to translate @#n:net_name texts */
  xctx->prep_net_structs=0;
  xctx->prep_hi_structs=0;
  symbol_bbox(n, &xctx->inst[n].x1, &xctx->inst[n].y1,
                    &xctx->inst[n].x2, &xctx->inst[n].y2);
  if(xctx->prep_hash_inst) hash_inst(XINSERT, n); /* no need to rehash, add item */
  /* xctx->prep_hash_inst=0; */

  /* embed a (locked) graph object floater inside the symbol */
  if(xctx->sym[i].type && !strcmp(xctx->sym[i].type, "scope")) {
    char *prop = NULL;

    my_strdup(_ALLOC_ID_, &xctx->inst[n].prop_ptr,
          subst_token(xctx->inst[n].prop_ptr, "attach", xctx->inst[n].instname));
    /* instname is "" (never NULL -- set_inst_flags() fills it via my_strdup2 +
     * get_tok_value) when the scope symbol's template carries no name= token. An
     * unquoted empty value here would make the floater's `name` swallow the whole
     * "flags=graph,unlocked" line below, so the rect would not be a graph at all.
     * Issue 0183. */
    my_mstrcat_tok(_ALLOC_ID_, &prop, "name", xctx->inst[n].instname, "\n");
    my_mstrcat(_ALLOC_ID_, &prop, "flags=graph,unlocked\n", NULL);
    my_mstrcat(_ALLOC_ID_, &prop, "lock=1\n", NULL);
    my_mstrcat(_ALLOC_ID_, &prop, "color=8\n", NULL);
    if(xctx->sym[i].rects[PINLAYER] == 0) {
      if(xctx->lastsel == 1 && xctx->sel_array[0].type==ELEMENT) {
        my_mstrcat(_ALLOC_ID_, &prop, "node=\"tcleval([xschem get_fqdevice [xschem translate ",
                                       xctx->inst[n].instname, " @device]])\"\n", NULL);
        my_strdup(_ALLOC_ID_, &xctx->inst[n].prop_ptr,
            subst_token(xctx->inst[n].prop_ptr, "device", xctx->inst[xctx->sel_array[0].n].instname));
      } else {
        const char msg[]="scope_ammeter is being inserted but no selected ammeter device/vsource to link to\n";
        dbg(0, "%s", msg);
        if(has_x) tclvareval("alert_ {", msg, "} {} 1", NULL);
        #if 1
        if(xctx->inst[n].instname) my_free(_ALLOC_ID_, &xctx->inst[n].instname);
        if(xctx->inst[n].name) my_free(_ALLOC_ID_, &xctx->inst[n].name);
        if(xctx->inst[n].prop_ptr) my_free(_ALLOC_ID_, &xctx->inst[n].prop_ptr);
        if(xctx->inst[n].lab) my_free(_ALLOC_ID_, &xctx->inst[n].lab);
        if(prop) my_free(_ALLOC_ID_, &prop);
        xctx->instances--;
        /* issue 0125 residual: balance the bbox(START) opened at 2567 for this
         * first_call; bailing with bbox_set==1 poisons the NEXT placement
         * (reentrant-bbox error + real alert_ modal from select.c bbox()).
         * Gate mirrors the START gate exactly so a batch-owned bbox (first_call==0)
         * is never closed from here. */
        if(first_call && (draw_sym & 3)) bbox(END, 0.0, 0.0, 0.0, 0.0);
        return 0;
        #endif
      }
    } else if(xctx->sym[i].rects[PINLAYER] == 1) {
      my_mstrcat(_ALLOC_ID_, &prop,
        "node=\"tcleval(",
        "[xschem translate ", xctx->inst[n].instname, " @#0:net_name]",
        ")\"\n", NULL);
    } else {
      my_mstrcat(_ALLOC_ID_, &prop,
        "node=\"tcleval(",
        "[xschem translate ", xctx->inst[n].instname, " @#0:net_name] ",
        "[xschem translate ", xctx->inst[n].instname, " @#1:net_name] -",
        ")\"\n", NULL);
    }
    storeobject(-1, x + 20, y-125, x + 130 , y - 25, xRECT, 2, SELECTED, prop);
    my_free(_ALLOC_ID_, &prop);
  }

  if(draw_sym & 3) {
    bbox(ADD, xctx->inst[n].x1, xctx->inst[n].y1, xctx->inst[n].x2, xctx->inst[n].y2);
  }
  if(draw_sym&1) {
    bbox(SET , 0.0 , 0.0 , 0.0 , 0.0);
    draw();
    bbox(END , 0.0 , 0.0 , 0.0 , 0.0);
  }
  /*   hilight new element 24122002 */

  if(draw_sym & 4 ) {
    unselect_all(1);
    select_element(n, SELECTED,0, 1);
    drawtemparc(xctx->gc[SELLAYER], END, 0.0, 0.0, 0.0, 0.0, 0.0);
    drawtemprect(xctx->gc[SELLAYER], END, 0.0, 0.0, 0.0, 0.0);
    drawtempline(xctx->gc[SELLAYER], END, 0.0, 0.0, 0.0, 0.0);
    xctx->need_reb_sel_arr = 1;
    rebuild_selected_array(); /* sets  xctx->ui_state |= SELECTION; */
  }

 }
 return 1;
}

/* ISSUE 0258 -- the already-open arm of symbol_in_new_window() below.
 *
 * check_loaded() answers TWO things: "is it open" and "WHERE". symbol_in_new_window() asked for
 * both (it passes win_path) and consumed only the boolean, so the request died there: no window
 * opened, no window switched, nothing said. Measured 2026-08-10 with the .sym already open in
 * .x1.drw and its instance selected -- `xschem check_loaded <sym>` returned ".x1.drw", the exact
 * value this function had in hand, while `xschem symbol_in_new_window` returned empty, left
 * current_win_path on the parent and wrote nothing to the status bar. One level down,
 * `xschem new_schematic create {} <sym> 1` both SAYS "already open: .x1.drw" and SWITCHES there.
 * So the pre-check was deleting the message AND the navigation the user asked for.
 *
 * Ratified rule R1, "whatever you just pressed is what you meant": the user asked to see that
 * symbol, and the window already holding it is the honest fulfilment. new_schematic("switch") is
 * used rather than switch_tab/switch_window directly because it is the one entry that routes a
 * real detached window and a pure tab correctly (xinit.c). The switch is VERIFIED by re-reading
 * current_win_path: switch_tab()/switch_window() both bail on a nonzero semaphore and on a
 * destroyed widget, and a refusal that reported 2 would be a fresh false success of the 0366 class.
 *
 * new_process (Alt+Shift+I) keeps its guard but now refuses OUT LOUD (ruling D5, ledger question):
 * letting it through would give one .sym two editable views in two processes with no shared modify
 * flag -- a real save-over-each-other path -- so the smallest, least surprising answer is to say
 * why rather than to do nothing.
 *
 * Return: 0 nothing done, 2 switched, 3 refused (new_process). Never 1 -- the caller owns "opened".
 */
static int symbol_already_open(const char *filename, const char *win_path, int new_process)
{
  char msg[PATH_MAX + 160];
  if(new_process) {
    my_snprintf(msg, S(msg),
      "Edit symbol in new process: %s is already open in this process (%s) -- not opening a second copy",
      filename, win_path);
    statusmsg_hold(msg, 1);
    return 3;
  }
  if(!strcmp(win_path, xctx->current_win_path)) {
    my_snprintf(msg, S(msg), "Edit symbol: %s is already open in this window", filename);
    statusmsg_hold(msg, 1);
    return 0;
  }
  new_schematic("switch", win_path, "", 1);
  if(strcmp(xctx->current_win_path, win_path)) {
    /* the switch was refused (semaphore held, or the widget is gone). Say so instead of
     * reporting a navigation that did not happen. */
    my_snprintf(msg, S(msg), "Edit symbol: %s is open in %s but that window cannot be raised now",
                filename, win_path);
    statusmsg_hold(msg, 1);
    return 0;
  }
  /* windowed mode's switch_window() retitles and re-points xctx but never raises the toplevel, so
   * the window the user was just sent to can stay buried behind the one they are looking at.
   * catch-guarded: a tab's toplevel is the main window (a harmless raise) and headless has no Tk. */
  if(has_x) {
    tclvareval("catch {raise [winfo toplevel ", win_path, "]}", NULL);
    tclvareval("catch {focus -force ", win_path, "}", NULL);
  }
  my_snprintf(msg, S(msg), "Edit symbol: %s is already open -- switched to %s", filename, win_path);
  statusmsg_hold(msg, 1);
  return 2;
}

/* Returns what happened, for the `xschem symbol_in_new_window` result (issue 0258; the return
 * shape is 0251's): 0 nothing done, 1 opened, 2 switched to the window that already holds it,
 * 3 refused and said why. The two key entries (callback.c Alt+i / Alt+Shift+I) discard it. */
int symbol_in_new_window(int new_process)
{
  char filename[PATH_MAX];
  char win_path[WINDOW_PATH_SIZE];
  rebuild_selected_array();

  if(xctx->lastsel !=1 || xctx->sel_array[0].type!=ELEMENT) {
    if(tclgetboolvar("search_schematic")) {
      my_strncpy(filename, abs_sym_path(xctx->current_name, ".sym"), S(filename));
    } else {
      my_strncpy(filename, add_ext(xctx->sch[xctx->currsch], ".sym"), S(filename));
    }
    if(new_process) new_xschem_process(filename, 1);
    else new_schematic("create", NULL, filename, 1);
    return 1;
  }
  else {
    my_strncpy(filename, abs_sym_path(tcl_hook2(xctx->inst[xctx->sel_array[0].n].name), ""), S(filename));
    if(!check_loaded(filename, win_path)) {
      if(new_process) new_xschem_process(filename, 1);
      else new_schematic("create", NULL, filename, 1);
      return 1;
    }
    return symbol_already_open(filename, win_path, new_process);
  }
}

int copy_hierarchy_data(const char *from_win_path, const char *to_win_path)
{
  int n;
  Xschem_ctx **save_xctx;
  Xschem_ctx *from, *to;
  char **sch;
  char **sch_path;
  int *sch_path_hash;
  int *sch_inst_number;
  int *previous_instance;
  Zoom *zoom_array;
  Lcc *hier_attr;
  int i, j;
  Str_hashentry **fromnext;
  Str_hashentry **tonext;


  if(!get_window_count()) { return 0; }
  save_xctx = get_save_xctx();
  n = get_tab_or_window_number(from_win_path);
  if(n >= 0) {
    from = save_xctx[n];
  } else return 0;
  n = get_tab_or_window_number(to_win_path);
  if(n >= 0) {
    to = save_xctx[n];
  } else return 0;
  sch = from->sch;
  sch_path = from->sch_path;
  sch_path_hash = from->sch_path_hash;
  sch_inst_number = from->sch_inst_number;
  previous_instance = from->previous_instance;
  zoom_array = from->zoom_array;
  hier_attr = from->hier_attr;
  to->currsch = from->currsch;
  for(i = 0; i <= from->currsch; i++) {
    my_strdup2(_ALLOC_ID_, &to->sch[i], sch[i]);
    my_strdup2(_ALLOC_ID_, &to->sch_path[i], sch_path[i]);
    to->sch_path_hash[i] = sch_path_hash[i];
    to->sch_inst_number[i] = sch_inst_number[i];
    to->previous_instance[i] = previous_instance[i];
    to->zoom_array[i].x = zoom_array[i].x;
    to->zoom_array[i].y = zoom_array[i].y;
    to->zoom_array[i].zoom = zoom_array[i].zoom;
    to->hier_attr[i].x0 = hier_attr[i].x0;
    to->hier_attr[i].y0 = hier_attr[i].y0;
    to->hier_attr[i].rot = hier_attr[i].rot;
    to->hier_attr[i].flip = hier_attr[i].flip;
    to->hier_attr[i].fd = NULL; /* Never used outside load_sym_def() */
    my_strdup2(_ALLOC_ID_, &to->hier_attr[i].prop_ptr, hier_attr[i].prop_ptr);
    my_strdup2(_ALLOC_ID_, &to->hier_attr[i].templ, hier_attr[i].templ);
    my_strdup2(_ALLOC_ID_, &to->hier_attr[i].symname, hier_attr[i].symname);
    my_strdup2(_ALLOC_ID_, &to->hier_attr[i].sym_extra, hier_attr[i].sym_extra);
    to->hier_attr[i].auto_spec = hier_attr[i].auto_spec;   /* issue 1201 */
    if(to->portmap[i].table) str_hash_free(&to->portmap[i]);
    str_hash_init(&to->portmap[i], HASHSIZE);
    for(j = 0; j < HASHSIZE; j++) {
      if(!from->portmap[i].table || !from->portmap[i].table[j]) continue;
      fromnext = &(from->portmap[i].table[j]);
      tonext =  &(to->portmap[i].table[j]);
      while(*fromnext) {
        Str_hashentry *e;
        e = my_calloc(_ALLOC_ID_, 1, sizeof(Str_hashentry));
        e->hash = (*fromnext)->hash;
        my_strdup2(_ALLOC_ID_, &e->token, (*fromnext)->token);
        my_strdup2(_ALLOC_ID_, &e->value, (*fromnext)->value);
        *tonext = e;
        fromnext = &( (*fromnext)->next );
        tonext = &( (*tonext)->next );
      }
    }
  }
  return 1;
}

/*  20111007 duplicate current schematic if no inst selected */
/* if force set to 1 force opening another new schematic even if already open */
/* win: when set, force a real top-level window (create_window) instead of letting
 * the global tabbed_interface decide tab-vs-window (doc/claude/specs/multi_window_detach.md).
 * Used by the cadence "open instance schematic read-only in a new window" flow. */
int schematic_in_new_window(int new_process, int dr, int force, int win)
{
  const char *create_verb = win ? "create_window" : "create";
  char filename[PATH_MAX];
  char win_path[WINDOW_PATH_SIZE];
  rebuild_selected_array();
  if(xctx->lastsel == 0) {
    if(new_process) new_xschem_process(xctx->sch[xctx->currsch], 0);
    else {
      int gf = xctx->graph_flags;
      double c1 = xctx->graph_cursor1_x;
      double c2 = xctx->graph_cursor2_x;
      new_schematic(create_verb, force ? "noalert" : "", xctx->sch[xctx->currsch], dr);

      /* propagte raw cursor info to new window */
      xctx->graph_flags = gf;
      xctx->graph_cursor1_x = c1;
      xctx->graph_cursor2_x = c2;
      dbg(1, "path=%s\n", xctx->current_win_path);
    }
    return 1;
  }
  else if(xctx->lastsel > 1) {
    return 0;
  }
  else { /* xctx->lastsel == 1 */
    if(xctx->inst[xctx->sel_array[0].n].ptr < 0 ) return 0;
    if(!(xctx->inst[xctx->sel_array[0].n].ptr+ xctx->sym)->type) return 0;
    if(xctx->sel_array[0].type != ELEMENT) return 0;
    if(                   /*  do not descend if not subcircuit */
       strcmp(
          (xctx->inst[xctx->sel_array[0].n].ptr+ xctx->sym)->type,
           "subcircuit"
       ) &&
       strcmp(
          (xctx->inst[xctx->sel_array[0].n].ptr+ xctx->sym)->type,
           "primitive"
       )
    ) return 0;
    get_sch_from_sym(filename, xctx->inst[xctx->sel_array[0].n].ptr+ xctx->sym, xctx->sel_array[0].n, 0);
    if(force || !check_loaded(filename, win_path)) {
      if(new_process) new_xschem_process(filename, 0);
      else new_schematic(create_verb, "noalert", filename, dr);
    }
  }
  return 1;
}

void launcher(void)
{
  const char *url;
  char program[PATH_MAX];
  char *command = NULL;
  int n, c;
  char *prop_ptr=NULL;
  rebuild_selected_array();
  tcleval("update");
  if(xctx->lastsel ==1)
  {
    size_t tclcommand_found;
    double mx=xctx->mousex, my=xctx->mousey;
    n=xctx->sel_array[0].n;
    c=xctx->sel_array[0].col;
    if     (xctx->sel_array[0].type==ELEMENT) prop_ptr = xctx->inst[n].prop_ptr;
    else if(xctx->sel_array[0].type==xRECT)   prop_ptr = xctx->rect[c][n].prop_ptr;
    else if(xctx->sel_array[0].type==POLYGON) prop_ptr = xctx->poly[c][n].prop_ptr;
    else if(xctx->sel_array[0].type==ARC)     prop_ptr = xctx->arc[c][n].prop_ptr;
    else if(xctx->sel_array[0].type==LINE)    prop_ptr = xctx->line[c][n].prop_ptr;
    else if(xctx->sel_array[0].type==WIRE)    prop_ptr = xctx->wire[n].prop_ptr;
    else if(xctx->sel_array[0].type==xTEXT)   prop_ptr = xctx->text[n].prop_ptr;
    my_strdup2(_ALLOC_ID_, &command, get_tok_value(prop_ptr, "tclcommand", 0));
    tclcommand_found = xctx->tok_size;
    if(!tclcommand_found && xctx->sel_array[0].type==ELEMENT) {
      xSymbol *sym = xctx->inst[n].ptr + xctx->sym;
      my_strdup2(_ALLOC_ID_, &command, get_tok_value(sym->prop_ptr, "tclcommand", 0));
    }
    if(strchr(command, '@')) {
      my_strdup2(_ALLOC_ID_, &command, translate3(command, 1, prop_ptr, NULL, NULL, NULL));
      if(xctx->sel_array[0].type==ELEMENT) {
        xSymbol *sym = xctx->inst[n].ptr + xctx->sym;
        if(strchr(command, '@')) {
          my_strdup2(_ALLOC_ID_, &command, translate3(command, 1, sym->prop_ptr, NULL, NULL, NULL));
        }
      }
    }
    my_strncpy(program, get_tok_value(prop_ptr,"program",0), S(program)); /* handle backslashes */
    url = get_tok_value(prop_ptr,"url",0); /* handle backslashes */
    dbg(1, "launcher(): url=%s\n", url);
    if(url[0] || (program[0])) { /* open url with appropriate program */
      tcl_call("launcher", url, program, NULL);
    } else if(command && command[0]){
      dbg(1, "launcher(): command=%s\n", command);
      if(Tcl_GlobalEval(interp, command) != TCL_OK) {
        char errmsg[PATH_MAX + 100];
        my_strncpy(errmsg, tclresult(), S(errmsg)); /* tclsetvar() would invalidate it */
        dbg(0, "%s\n", errmsg);
        if(has_x) tcl_call("alert_", errmsg, NULL, "{}");
        Tcl_ResetResult(interp);
      }
    } else { /* no action defined --> warning */
      const char *msg = "No action on launcher is defined (url or tclcommand)";
      dbg(0, "%s\n", msg);
      /* if(has_x) tclvareval("alert_ {", msg, "} {}", NULL); */ /* commented, annoying */
    }
    my_free(_ALLOC_ID_, &command);
    tcleval("after 300");
    select_object(mx,my,0, 0, NULL);
  }
}


/* get symbol reference of instance 'inst', looking into
 * instance 'schematic' attribute (and appending '.sym') if set
 * or get it from inst[inst].name.
 * perform tcl substitution of the result and
 * return the last 'ndir' directory components of symbol reference. */
const char *get_sym_name(int inst, int ndir, int ext, int abs_path)
{
  const char *sym;
  char *sch = NULL;
  size_t schematic_token_found = 0;

  /* instance based symbol selection */
  /* resolve schematic=generator.tcl( @n ) where n=11 is defined in instance attrs */
  my_strdup2(_ALLOC_ID_, &sch, get_tok_value(xctx->inst[inst].prop_ptr,"schematic", 6));
  schematic_token_found = xctx->tok_size;
  /* ISSUE 1201. The SECOND of the two places that decide which cell body a copy
   * belongs to -- this one writes the name onto the call line, the one in
   * get_additional_symbols() writes the body. Both ask auto_spec_name(), so the
   * call line and the .subckt line can never drift apart about what the copy is
   * called. Outside a SPICE netlist run this is always NULL and nothing here
   * changes. */
  if(!schematic_token_found) {
    const char *auto_sch = auto_spec_name(inst);
    if(auto_sch && auto_sch[0]) {
      my_strdup2(_ALLOC_ID_, &sch, auto_sch);
      schematic_token_found = strlen(auto_sch);
    }
  }
  if(sch && sch[0])
    my_strdup2(_ALLOC_ID_, &sch, translate3(sch, 1, xctx->inst[inst].prop_ptr, NULL, NULL, NULL));
  if(sch && sch[0])
    my_strdup2(_ALLOC_ID_, &sch, tcl_hook2(
       str_replace(sch, "@symname", get_cell(xctx->inst[inst].name, 0), '\\', -1)));

  /*
   * sch = tcl_hook2(str_replace(get_tok_value(xctx->inst[inst].prop_ptr,"schematic", 6), "@symname",
   *      get_cell(xctx->inst[inst].name, 0), '\\', -1));
   */

  dbg(1, "get_sym_name(): sch=%s\n", sch);
  if(schematic_token_found) { /* token exists */
    if(abs_path)
      sym = abs_sym_path(sch, ".sym");
    else
      sym = add_ext(rel_sym_path(sch), ".sym");
  }
  else {
    if(abs_path)
      sym = abs_sym_path(tcl_hook2(xctx->inst[inst].name), "");
    else
      sym = tcl_hook2(xctx->inst[inst].name);
  }

  my_free(_ALLOC_ID_, &sch);
  if(ext) return get_cell_w_ext(sym, ndir);
  else return get_cell(sym, ndir);
}

void copy_symbol(xSymbol *dest_sym, xSymbol *src_sym)
{
  int c, j;

  dest_sym->minx = src_sym->minx;
  dest_sym->maxx = src_sym->maxx;
  dest_sym->miny = src_sym->miny;
  dest_sym->maxy = src_sym->maxy;
  dest_sym->flags = src_sym->flags;
  dest_sym->texts = src_sym->texts;

  dest_sym->name = NULL;
  dest_sym->base_name = NULL; /* this is not allocated and points to the base symbol */
  dest_sym->prop_ptr = NULL;
  dest_sym->type = NULL;
  dest_sym->templ = NULL;
  dest_sym->parent_prop_ptr = NULL;
  my_strdup2(_ALLOC_ID_, &dest_sym->name, src_sym->name);
  my_strdup2(_ALLOC_ID_, &dest_sym->type, src_sym->type);
  my_strdup2(_ALLOC_ID_, &dest_sym->templ, src_sym->templ);
  my_strdup(_ALLOC_ID_, &dest_sym->parent_prop_ptr, src_sym->parent_prop_ptr);
  my_strdup2(_ALLOC_ID_, &dest_sym->prop_ptr, src_sym->prop_ptr);

  dest_sym->line = my_calloc(_ALLOC_ID_, cadlayers, sizeof(xLine *));
  dest_sym->poly = my_calloc(_ALLOC_ID_, cadlayers, sizeof(xPoly *));
  dest_sym->arc = my_calloc(_ALLOC_ID_, cadlayers, sizeof(xArc *));
  dest_sym->rect = my_calloc(_ALLOC_ID_, cadlayers, sizeof(xRect *));
  dest_sym->lines = my_calloc(_ALLOC_ID_, cadlayers, sizeof(int));
  dest_sym->rects = my_calloc(_ALLOC_ID_, cadlayers, sizeof(int));
  dest_sym->arcs = my_calloc(_ALLOC_ID_, cadlayers, sizeof(int));
  dest_sym->polygons = my_calloc(_ALLOC_ID_, cadlayers, sizeof(int));

  dest_sym->text = my_calloc(_ALLOC_ID_, src_sym->texts, sizeof(xText));
  memcpy(dest_sym->lines, src_sym->lines, sizeof(dest_sym->lines[0]) * cadlayers);
  memcpy(dest_sym->rects, src_sym->rects, sizeof(dest_sym->rects[0]) * cadlayers);
  memcpy(dest_sym->arcs, src_sym->arcs, sizeof(dest_sym->arcs[0]) * cadlayers);
  memcpy(dest_sym->polygons, src_sym->polygons, sizeof(dest_sym->polygons[0]) * cadlayers);
  for(c = 0;c<cadlayers; ++c) {
    /* symbol lines */
    dest_sym->line[c] = my_calloc(_ALLOC_ID_, src_sym->lines[c], sizeof(xLine));
    for(j = 0; j < src_sym->lines[c]; ++j) {
      dest_sym->line[c][j] = src_sym->line[c][j];
      dest_sym->line[c][j].prop_ptr = NULL;
      my_strdup(_ALLOC_ID_, &dest_sym->line[c][j].prop_ptr, src_sym->line[c][j].prop_ptr);
    }
    /* symbol rects */
    dest_sym->rect[c] = my_calloc(_ALLOC_ID_, src_sym->rects[c], sizeof(xRect));
    for(j = 0; j < src_sym->rects[c]; ++j) {
      dest_sym->rect[c][j] = src_sym->rect[c][j];
      dest_sym->rect[c][j].prop_ptr = NULL;
      dest_sym->rect[c][j].extraptr = NULL;
      my_strdup(_ALLOC_ID_, &dest_sym->rect[c][j].prop_ptr, src_sym->rect[c][j].prop_ptr);
    }
    /* symbol arcs */
    dest_sym->arc[c] = my_calloc(_ALLOC_ID_, src_sym->arcs[c], sizeof(xArc));
    for(j = 0; j < src_sym->arcs[c]; ++j) {
      dest_sym->arc[c][j] = src_sym->arc[c][j];
      dest_sym->arc[c][j].prop_ptr = NULL;
      my_strdup(_ALLOC_ID_, &dest_sym->arc[c][j].prop_ptr, src_sym->arc[c][j].prop_ptr);
    }
    /* symbol polygons */
    dest_sym->poly[c] = my_calloc(_ALLOC_ID_, src_sym->polygons[c], sizeof(xPoly));
    for(j = 0; j < src_sym->polygons[c]; ++j) {
      int points = src_sym->poly[c][j].points;
      dest_sym->poly[c][j] = src_sym->poly[c][j];
      dest_sym->poly[c][j].prop_ptr = NULL;
      dest_sym->poly[c][j].x = my_malloc(_ALLOC_ID_, points * sizeof(double));
      dest_sym->poly[c][j].y = my_malloc(_ALLOC_ID_, points * sizeof(double));
      dest_sym->poly[c][j].selected_point = my_malloc(_ALLOC_ID_, points * sizeof(unsigned short));
      my_strdup(_ALLOC_ID_, &dest_sym->poly[c][j].prop_ptr, src_sym->poly[c][j].prop_ptr);
      memcpy(dest_sym->poly[c][j].x, src_sym->poly[c][j].x, points * sizeof(double));
      memcpy(dest_sym->poly[c][j].y, src_sym->poly[c][j].y, points * sizeof(double));
      memcpy(dest_sym->poly[c][j].selected_point, src_sym->poly[c][j].selected_point,
           points * sizeof(unsigned short));
    }
  }
  /* symbol texts */
  for(j = 0; j < src_sym->texts; ++j) {
    dest_sym->text[j] = src_sym->text[j];
    dest_sym->text[j].prop_ptr = NULL;
    dest_sym->text[j].txt_ptr = NULL;
    dest_sym->text[j].font = NULL;
    dest_sym->text[j].floater_instname = NULL;
    dest_sym->text[j].floater_ptr = NULL;
    my_strdup2(_ALLOC_ID_, &dest_sym->text[j].prop_ptr, src_sym->text[j].prop_ptr);
    my_strdup2(_ALLOC_ID_, &dest_sym->text[j].floater_ptr, src_sym->text[j].floater_ptr);
    dbg(1, "copy_symbol1(): allocating sym %d text %d\n", dest_sym - xctx->sym, j);
    my_strdup2(_ALLOC_ID_, &dest_sym->text[j].txt_ptr, src_sym->text[j].txt_ptr);
    my_strdup2(_ALLOC_ID_, &dest_sym->text[j].font, src_sym->text[j].font);
    my_strdup2(_ALLOC_ID_, &dest_sym->text[j].floater_instname, src_sym->text[j].floater_instname);
  }
}

void toggle_ignore(void)
{
  int i, n, first = 1;
  char *attr;
  int flag = 0; /* 1: spice_ignore=true, 2: spice_ignore=short */
  const char *ignore_str;
  if(xctx->netlist_type == CAD_VERILOG_NETLIST) attr="verilog_ignore";
  else if(xctx->netlist_type == CAD_VHDL_NETLIST) attr="vhdl_ignore";
  else if(xctx->netlist_type == CAD_TEDAX_NETLIST) attr="tedax_ignore";
  else if(xctx->netlist_type == CAD_SPECTRE_NETLIST) attr="spectre_ignore";
  else if(xctx->netlist_type == CAD_SPICE_NETLIST) attr="spice_ignore";
  else attr = NULL;
  if(attr) {
    rebuild_selected_array();
    for(n=0; n < xctx->lastsel; ++n) {
      if(xctx->sel_array[n].type == ELEMENT) {
        i = xctx->sel_array[n].n;
        if(first) {
          xctx->push_undo();
          first = 0;
        }
        flag = 0;
        ignore_str = get_tok_value(xctx->inst[i].prop_ptr, attr, 0);
        if(!strcmp(ignore_str, "short")) flag = 2;
        else if(!strboolcmp(ignore_str, "true")) flag = 1;

        if(flag == 0) flag = 1;
        else if(flag == 1) flag = 2;
        else flag = 0;

        if(flag == 1) {
          my_strdup(_ALLOC_ID_, &xctx->inst[i].prop_ptr, subst_token(xctx->inst[i].prop_ptr, attr, "true"));
        } else if(flag == 2) {
          my_strdup(_ALLOC_ID_, &xctx->inst[i].prop_ptr, subst_token(xctx->inst[i].prop_ptr, attr, "short"));
        } else {
          my_strdup(_ALLOC_ID_, &xctx->inst[i].prop_ptr, subst_token(xctx->inst[i].prop_ptr, attr, NULL));
        }
        set_inst_flags(&xctx->inst[i]);
        set_modify(1);
        xctx->prep_hash_inst=0;
        xctx->prep_net_structs=0;
        xctx->prep_hi_structs=0;
      }

      if(xctx->sel_array[n].type == WIRE) {
        i = xctx->sel_array[n].n;
        if(first) {
          xctx->push_undo();
          first = 0;
        }
        flag = 0;
        ignore_str = get_tok_value(xctx->wire[i].prop_ptr, attr, 0);
        if(!strcmp(ignore_str, "short")) flag = 2;
        else if(!strboolcmp(ignore_str, "true")) flag = 1;

        if(flag == 0) flag = 1;
        else if(flag == 1) flag = 2;
        else flag = 0;

        if(flag == 1) {
          my_strdup(_ALLOC_ID_, &xctx->wire[i].prop_ptr, subst_token(xctx->wire[i].prop_ptr, attr, "true"));
        } else if(flag == 2) {
          my_strdup(_ALLOC_ID_, &xctx->wire[i].prop_ptr, subst_token(xctx->wire[i].prop_ptr, attr, "short"));
        } else {
          my_strdup(_ALLOC_ID_, &xctx->wire[i].prop_ptr, subst_token(xctx->wire[i].prop_ptr, attr, NULL));
        }

        set_wire_flags(&xctx->wire[i]);
        set_modify(1);
        xctx->prep_hash_wires=0;
        xctx->prep_net_structs=0;
        xctx->prep_hi_structs=0;
      }

    }
    draw();
  }
}

/* ============================================================================
 * ISSUE 1201: THE NETLISTER WRITES THE SPECIALISED COPY OF A CELL BY ITSELF
 * ============================================================================
 *
 * WHAT WENT WRONG FOR THE USER. A designer opens the shipped sky130 bandgap
 * sheet, clicks two of the five passgates and types modelp=pfet_01v8_lvt on
 * them, because those two have to be built from the low-threshold p-device.
 * They press netlist. The deck builds all five out of the ordinary device and
 * the tool says the setting changed nothing. Measured: one cell body, zero
 * occurrences of the device they asked for.
 *
 * The tool COULD always do it. Type a second attribute -- `schematic=` naming a
 * cell name no other copy asks for -- and get_additional_symbols() below writes
 * a second cell body out of the very same sheet, feeds that copy's own property
 * string into it as parent_prop_ptr, and the deck is right. The name in that
 * attribute is not a path; it is just a cell name nobody else uses. So the
 * designer was being asked to invent a unique name for something the netlister
 * could name itself. In Cadence there is no such token: the netlister
 * unique-ifies a specialised body on its own. This is that.
 *
 * WHEN IT FIRES, and both halves are required:
 *   1. the copy sets something the SPICE line it is written through never reads
 *      (the shared classification in token.c, the same one the "your setting
 *      went nowhere" warning uses -- see ua_instance_eligible() and
 *      ua_token_lost() there), AND
 *   2. the cell's OWN drawing uses that setting, as sky130_tests/passgate.sch
 *      uses `model=@modelp` (GUARD AS-BODY, token.c).
 * Half 2 is what keeps this small. "The SPICE line never reads it" alone is
 * true of misspellings and leftovers, and writing a cell body for those would
 * put cells nobody asked for into decks that are correct today.
 *
 * MEASURED ON THE SHIPPED TREES: of the 653 schematics under sky130A,
 * gf180mcuD, ihp-sg13g2, xschem_library and xschem_libs_newsym, not one copy
 * enters this path, because every copy that would qualify already carries a
 * hand-typed `schematic=`. The BEFORE/AFTER byte-diff of all 653 decks is on
 * issue 1201.
 *
 * SCOPE IS THE SPICE DECK ONLY (GUARD AS-MODE). auto_spec_begin() is called
 * from global_spice_netlist() and nowhere else, so the GUI, descend, and the
 * Spectre, VHDL, Verilog and tEDAx netlisters keep exactly today's behaviour.
 * The classification this rests on has only ever run for SPICE anyway --
 * warn_unused_instance_attr() has one call site, inside print_spice_element().
 */

/* auto_spec_on is GUARD AS-MODE itself: outside a SPICE netlist run every
 * question below is answered NULL and nothing in the editor changes. */
static int auto_spec_on = 0;
/* "<symbol reference>\n<the copy's whole property string>" -> the cell name
 * chosen for it, or "" for "this copy gets nothing". Purely a speed memo: the
 * answer is a function of those two things, and get_sym_name() asks it once per
 * token expansion, which on a large sheet is thousands of times. */
static Str_hashtable auto_spec_memo = {NULL, 0};
/* "<symbol reference>\n<canonical setting list>" -> the cell name. THIS is what
 * makes sharing correct: two copies that asked for the same settings land on
 * the same key and therefore on ONE cell body, whatever order they typed them
 * in and whatever else differs between them. */
static Str_hashtable auto_spec_by_set = {NULL, 0};
/* every cell name this run has already handed out, so GUARD AS-COLLIDE can see
 * a name it minted itself as taken. */
static Str_hashtable auto_spec_taken = {NULL, 0};

/* ISSUE 1201. End the window: forget every answer, and stop answering.
 *
 * A reader would assume the tables are harmless to leave lying about, since
 * they only cache. They are not: the sheet a cell is built from is read off
 * DISK, and the file may be edited between two netlist runs of the same
 * session, so an answer kept past the end of a run is an answer about a file
 * that no longer says that. No behavioural row inside one run can see this --
 * within a run the stale answer is the right one -- which is exactly the class
 * of defect this branch has shipped past a green suite before. Row AS30 pins it
 * structurally. */
void auto_spec_end(void)
{
  auto_spec_on = 0;
  str_hash_free(&auto_spec_memo);
  str_hash_free(&auto_spec_by_set);
  str_hash_free(&auto_spec_taken);
  lost_attrs_cache_clear();
}

/* ISSUE 1201. Open the window. Called from global_spice_netlist() immediately
 * before it writes the TOP sheet's own call lines, and from nowhere else. That
 * point matters and is measured -- see the comment at the call site. */
void auto_spec_begin(void)
{
  auto_spec_end();
  str_hash_init(&auto_spec_memo, 1021);
  str_hash_init(&auto_spec_by_set, 1021);
  str_hash_init(&auto_spec_taken, 1021);
  auto_spec_on = 1;
}

/* GUARD AS-COLLIDE, issue 1201. Is <nm> a name this deck, this design or this
 * disk already means something else by?
 *
 * A NAME THE TOOL INVENTS MUST NEVER LAND ON A CELL THE DESIGN ALREADY HAS.
 * The consequence if it does is not cosmetic: get_additional_symbols() below
 * only falls back to the cell's own drawing when the named file does NOT
 * exist, so a candidate that happens to name a real symbol next door builds
 * this copy out of THAT cell's drawing instead -- a different circuit, quietly,
 * under a name the designer never typed. Three questions, because there are
 * three ways a name can already be spoken for:
 *
 *   * a symbol already loaded in this design, including one this same run has
 *     just minted;
 *   * a name this run has already handed out (two different setting lists whose
 *     names collapse to the same spelling once punctuation is folded to '_');
 *   * a file on disk, asked BOTH as a bare reference and as a reference in the
 *     base symbol's own library, because that is where a neighbouring cell of
 *     the same family actually lives and a bare name does not resolve there.
 */
static int auto_spec_collides(int inst, const char *nm)
{
  struct stat buf;
  const char *symname;
  char dirref[PATH_MAX];
  const char *slash;
  size_t dlen;
  int i;

  if(!nm || !nm[0]) return 1;
  for(i = 0; i < xctx->symbols; ++i) {
    if(!xctx->sym[i].name) continue;
    if(!strcmp(get_cell(xctx->sym[i].name, 0), nm)) return 1;
  }
  if(str_hash_lookup(&auto_spec_taken, nm, "", XLOOKUP)) return 1;
  if(!stat(abs_sym_path(nm, ".sym"), &buf)) return 1;
  if(!stat(abs_sym_path(nm, ".sch"), &buf)) return 1;
  symname = xctx->sym[xctx->inst[inst].ptr].name;
  slash = symname ? strrchr(symname, '/') : NULL;
  if(slash) {
    dlen = (size_t)(slash - symname) + 1;
    if(dlen < S(dirref) - 1) {
      my_strncpy(dirref, symname, dlen + 1);
      my_strncpy(dirref + dlen, nm, S(dirref) - dlen);
      if(!stat(abs_sym_path(dirref, ".sym"), &buf)) return 1;
      if(!stat(abs_sym_path(dirref, ".sch"), &buf)) return 1;
    }
  }
  return 0;
}

/* ISSUE 1201. DOES THIS COPY QUALIFY FOR A CELL BODY OF ITS OWN? Everything
 * except GUARD AS-MODE and the naming, so that auto_spec_name() (inside a SPICE
 * netlist run) and auto_spec_would_specialize() (the annotation surface, at any
 * time) can never answer differently about the same copy.
 *
 * Returns the number of settings that qualify and hands back the canonical and
 * the human spelling of them. */
static int auto_spec_qualifies(int inst, char **canon, char **settings)
{
  xSymbol *symptr;
  size_t saved_tok_size;
  int ok;

  if(canon) my_strdup(_ALLOC_ID_, canon, NULL);
  if(settings) my_strdup(_ALLOC_ID_, settings, NULL);
  if(inst < 0 || inst >= xctx->instances) return 0;
  if(xctx->inst[inst].ptr < 0) return 0;
  symptr = xctx->inst[inst].ptr + xctx->sym;

  saved_tok_size = xctx->tok_size;
  /* GUARD AS-SYMBODY, issue 1201. A SYMBOL that names its own drawing, or says
   * its insides are never to be written out, has already decided which body it
   * uses -- and get_additional_symbols()'s missing-file fallback would silently
   * replace that decision with "<cell>.sch beside the symbol", which is a
   * different drawing. Ten shipped symbols are of this shape. Rejected
   * alternative, recorded on issue 1201: resolve the symbol's own drawing and
   * use THAT as the fallback. More code, it changes an existing fallback, and
   * no shipped cell needs it. */
  get_tok_value(symptr->prop_ptr, "schematic", 0);
  ok = xctx->tok_size ? 0 : 1;
  if(ok) {
    get_tok_value(symptr->prop_ptr, "default_schematic", 0);
    ok = xctx->tok_size ? 0 : 1;
  }
  /* GUARD AS-TMPLMODEL, issue 1201. spice_block_netlist() takes the .subckt
   * name from the symbol template's `model` when it has one, NOT from the
   * symbol's name -- so two specialised copies of such a cell would put two
   * different cell bodies into the deck under ONE name, which is a deck no
   * simulator can read. Zero of the 533 shipped subcircuit symbols do this; the
   * fixture on row AS20 is what proves the guard. */
  if(ok) {
    get_tok_value(symptr->templ, "model", 0);
    ok = xctx->tok_size ? 0 : 1;
  }
  xctx->tok_size = saved_tok_size;
  /* GUARD AS-IGNORE, issue 1201. A copy the SPICE deck does not contain at all,
   * or one written out as a plain wire joining its pins, carries no settings
   * anywhere. Without this it would still grow a cell body nothing calls. */
  if(ok && ((xctx->inst[inst].flags & (SPICE_IGNORE | SPICE_SHORT)) ||
            (symptr->flags & (SPICE_IGNORE | SPICE_SHORT)))) ok = 0;
  if(!ok) return 0;
  /* GUARD AS-EXPLICIT, AS-TYPE, AS-LOST and AS-BODY, all four, and they are the
   * same tests the "your setting went nowhere" warning applies -- one
   * classification, in token.c, asked twice. GUARD AS-ORDER is inside it: the
   * canonical string is sorted by setting name, so two copies that typed the
   * same settings in opposite order are one request and share one body. */
  return lost_attrs_the_cell_body_reads(inst, canon, settings);
}

/* ISSUE 1201. WOULD THE NETLISTER GIVE THIS COPY A CELL BODY OF ITS OWN?
 * The same question auto_spec_name() answers, asked OUTSIDE a netlist run and
 * without minting a name or saying anything.
 *
 * WHY IT EXISTS, and it is not a convenience. The annotation surface has to
 * know which model name the DECK will build a device with, so it can ask the
 * results file for that device by the name the simulator gave it
 * (op_annot::model_netlist, src/op_annot.tcl, GUARD GB). Before issue 1201 the
 * only way a copy's own setting could reach the deck was a hand-typed
 * `schematic=`, and GUARD GB tested for exactly that string. Now the netlister
 * does it by itself, so a copy with no attribute on it at all can have its
 * setting in the deck -- and an annotation surface still testing for the
 * attribute would ask the results for a device under a name the simulator never
 * used, and put no numbers, or the wrong ones, on the user's schematic. RULING
 * D5-1. descend_schematic() records this answer per hierarchy level; `xschem
 * globals` publishes it as lcc[N].auto_spec.
 *
 * The body-read cache is dropped on the way out when no netlist run owns it,
 * because outside that window nothing else would ever clear it and the drawing
 * it read may be edited a moment later. */
int auto_spec_would_specialize(int inst)
{
  char *canon = NULL;
  char *settings = NULL;
  int n;

  n = auto_spec_qualifies(inst, &canon, &settings);
  my_free(_ALLOC_ID_, &canon);
  my_free(_ALLOC_ID_, &settings);
  if(!auto_spec_on) lost_attrs_cache_clear();
  return n > 0 ? 1 : 0;
}

/* ISSUE 1201. The cell name this copy should be built under, or NULL for "leave
 * this copy exactly as it is today".
 *
 * Consulted from the two places that resolve which cell body a copy calls --
 * get_additional_symbols(), which writes the body, and get_sym_name(), which
 * writes the name onto the call line. Both ask THIS function, so the two can
 * never disagree about what a copy is called.
 *
 * The guards, in order, each of which has its own test row:
 *   AS-MODE       we are not inside a SPICE netlist run
 *   AS-SYMBODY    the SYMBOL already has an opinion about which drawing it is
 *                 built from, or says not to write its insides out at all
 *   AS-TMPLMODEL  the symbol's template names the cell body itself
 *   AS-IGNORE     this copy is not written into the SPICE deck at all
 *   AS-EXPLICIT / AS-TYPE / AS-LOST / AS-BODY, all four in token.c
 *   AS-ORDER      the answer is the SET of settings, not the order typed
 *   AS-CANON      a readable, deterministic name built from that set
 *   AS-COLLIDE    and never a name something else already answers to
 */
const char *auto_spec_name(int inst)
{
  static char name[256];
  char cand[256];
  char note[1600];
  char e_sheet[160];
  char e_inst[80];
  char e_cell[80];
  char e_set[160];
  char e_new[120];
  char *memokey = NULL;
  char *setkey = NULL;
  char *canon = NULL;
  char *settings = NULL;
  const char *symname;
  /* ⚠ A COPY, NOT THE POINTER get_cell() HANDS BACK. get_cell() returns a
   * static buffer that the NEXT call overwrites, and auto_spec_collides() below
   * calls it once per loaded symbol. Measured before this copy existed: the
   * note told the user their passgate was "a 130_fd_pr/pfet_01v8" -- the tail
   * of some other symbol's name, left in that buffer. */
  char base[PATH_MAX];
  const char *sheet;
  const char *instname;
  const char *s;
  Str_hashentry *e;
  xSymbol *symptr;
  size_t w;
  int nlost;
  int suffix;
  int c;

  name[0] = '\0';
  if(!auto_spec_on) return NULL;                              /* GUARD AS-MODE */
  if(inst < 0 || inst >= xctx->instances) return NULL;
  if(xctx->inst[inst].ptr < 0) return NULL;
  symptr = xctx->inst[inst].ptr + xctx->sym;
  symname = symptr->name ? symptr->name : "";

  my_strdup2(_ALLOC_ID_, &memokey, symname);
  my_strcat(_ALLOC_ID_, &memokey, "\n");
  my_strcat(_ALLOC_ID_, &memokey,
            xctx->inst[inst].prop_ptr ? xctx->inst[inst].prop_ptr : "");
  e = str_hash_lookup(&auto_spec_memo, memokey, "", XLOOKUP);
  if(e) {
    if(e->value && e->value[0]) my_strncpy(name, e->value, S(name));
    my_free(_ALLOC_ID_, &memokey);
    return name[0] ? name : NULL;
  }

  nlost = auto_spec_qualifies(inst, &canon, &settings);
  if(nlost <= 0 || !canon || !canon[0]) {
    str_hash_lookup(&auto_spec_memo, memokey, "", XINSERT);
    my_free(_ALLOC_ID_, &memokey);
    my_free(_ALLOC_ID_, &canon);
    my_free(_ALLOC_ID_, &settings);
    return NULL;
  }

  my_strdup2(_ALLOC_ID_, &setkey, symname);
  my_strcat(_ALLOC_ID_, &setkey, "\n");
  my_strcat(_ALLOC_ID_, &setkey, canon);
  e = str_hash_lookup(&auto_spec_by_set, setkey, "", XLOOKUP);
  if(e && e->value && e->value[0]) {
    my_strncpy(name, e->value, S(name));
    str_hash_lookup(&auto_spec_memo, memokey, name, XINSERT);
    my_free(_ALLOC_ID_, &memokey);
    my_free(_ALLOC_ID_, &setkey);
    my_free(_ALLOC_ID_, &canon);
    my_free(_ALLOC_ID_, &settings);
    return name;
  }

  /* GUARD AS-CANON, issue 1201. The name is READABLE and it is a pure function
   * of the setting SET: `passgate__modelp_pfet_01v8_lvt`. A designer reading a
   * simulator log, or a .subckt line, can see at a glance which copy it is and
   * why it exists. Rejected alternative, recorded on issue 1201: an opaque
   * `passgate__auto_7f3a1c9e`, which is shorter and says nothing.
   *
   * Anything a simulator would not accept in a name becomes '_', and a cell
   * whose own name does not begin with a letter gets one, because the result
   * has to be a name a netlist reader accepts (row AS12). The length is capped
   * so a long setting value cannot produce an unreadable line. */
  w = 0;
  my_strncpy(base, get_cell(symname, 0), S(base));
  if(!base[0]) my_strncpy(base, "cell", S(base));
  if(!((base[0] >= 'a' && base[0] <= 'z') || (base[0] >= 'A' && base[0] <= 'Z')))
    cand[w++] = 'x';
  for(s = base; *s && w < 60; ++s) {
    c = (unsigned char)*s;
    cand[w++] = (char)(((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                        (c >= '0' && c <= '9')) ? c : '_');
  }
  cand[w++] = '_';
  cand[w++] = '_';
  for(s = canon; *s && w < 200; ++s) {
    c = (unsigned char)*s;
    cand[w++] = (char)(((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                        (c >= '0' && c <= '9')) ? c : '_');
  }
  cand[w] = '\0';

  suffix = 0;
  while(1) {
    if(suffix == 0) my_strncpy(name, cand, S(name));
    else my_snprintf(name, S(name), "%s_%d", cand, suffix);
    if(!auto_spec_collides(inst, name)) break;
    ++suffix;
    /* Nothing a user can type reaches this: it needs a thousand different
     * cells already answering to one family of names. If it ever does, the
     * honest answer is today's behaviour, not a name that means something
     * else. */
    if(suffix > 999) {
      str_hash_lookup(&auto_spec_memo, memokey, "", XINSERT);
      my_free(_ALLOC_ID_, &memokey);
      my_free(_ALLOC_ID_, &setkey);
      my_free(_ALLOC_ID_, &canon);
      my_free(_ALLOC_ID_, &settings);
      return NULL;
    }
  }

  str_hash_lookup(&auto_spec_by_set, setkey, name, XINSERT);
  str_hash_lookup(&auto_spec_taken, name, "1", XINSERT);
  str_hash_lookup(&auto_spec_memo, memokey, name, XINSERT);

  /* ISSUE 1201 AND THE PLAIN-ENGLISH RULING. The user gets a cell name in their
   * deck that nobody typed, so the tool says so ONCE per new cell, in the words
   * a first-time user has: sheet, copy, setting, cell, new name -- and it ends
   * by telling them there is nothing for them to do. It does NOT tell them to
   * type an attribute; that instruction is what this whole issue removes, and
   * rows AS23, AS24 and AS25 assert its absence here and on the two older
   * surfaces that used to give it.
   *
   * Net noise goes DOWN: this line replaces a warning that used to fire on the
   * same copy, and like that warning it is statusmsg(..., 2), which appends to
   * the info window without forcing it open. RULING D5-4: the sentence is
   * assembled by ONE my_snprintf and handed over exactly once.
   *
   * GUARD UA-ELIDE on every variable-length field, so no value a user types can
   * push the last sentence off the end or split the note across two entries. */
  sheet = (xctx->current_name[0]) ? xctx->current_name :
          (xctx->sch[xctx->currsch] ? xctx->sch[xctx->currsch] : "?");
  instname = xctx->inst[inst].instname ? xctx->inst[inst].instname : "?";
  unused_attr_elide(e_sheet, S(e_sheet), sheet, 120, 1);
  unused_attr_elide(e_inst,  S(e_inst),  instname, 60, 0);
  unused_attr_elide(e_cell,  S(e_cell),  base, 60, 0);
  unused_attr_elide(e_set,   S(e_set),   settings ? settings : "", 120, 0);
  unused_attr_elide(e_new,   S(e_new),   name, 100, 0);
  my_snprintf(note, S(note),
    "Note: on sheet %s, %s (a %s) sets %s, and the %s drawing uses that setting "
    "inside it, so XSCHEM wrote a separate copy of %s called %s and pointed %s "
    "at it. Any other copy of %s on this design that asks for the same settings "
    "shares that one. You do not have to add anything to the sheet.",
    e_sheet, e_inst, e_cell, e_set, e_cell, e_cell, e_new, e_inst, e_cell);
  statusmsg(note, 2);

  my_free(_ALLOC_ID_, &memokey);
  my_free(_ALLOC_ID_, &setkey);
  my_free(_ALLOC_ID_, &canon);
  my_free(_ALLOC_ID_, &settings);
  return name;
}

/* what = 1: start
 * what = 0 : end : should NOT be called if match_symbol() has been executed between start & end
 */
void get_additional_symbols(int what)
{
  int i;
  static int num_syms; /* no context switch between start and end so it is safe */
  Int_hashentry *found;
  Int_hashtable sym_table = {NULL, 0};
  struct stat buf;
  int is_gen = 0;

  if(what == 1) { /* start */
    int_hash_init(&sym_table, HASHSIZE);
    num_syms = xctx->symbols;
    for(i = 0; i < xctx->symbols; ++i) {
      int_hash_lookup(&sym_table, xctx->sym[i].name, i, XINSERT);
    }
    /* handle instances with "schematic=..." attribute (polymorphic symbols) */
    for(i=0;i<xctx->instances; ++i) {
      char *spice_sym_def = NULL;
      char *vhdl_sym_def = NULL;
      char *verilog_sym_def = NULL;
      char *spectre_sym_def = NULL;
      char *default_schematic = NULL;
      char *sch = NULL;
      const char *auto_sch = NULL;
      char symbol_base_sch[PATH_MAX] = "";
      size_t schematic_token_found = 0;

      if(xctx->inst[i].ptr < 0) continue;
      dbg(1, "get_additional_symbols(): inst=%d (%s) sch=%s\n",i, xctx->inst[i].name,  sch);
      /* copy instance based *_sym_def attributes to symbol */
      my_strdup(_ALLOC_ID_, &spice_sym_def, get_tok_value(xctx->inst[i].prop_ptr,"spice_sym_def",6));
      my_strdup(_ALLOC_ID_, &spectre_sym_def, get_tok_value(xctx->inst[i].prop_ptr,"spectre_sym_def",6));
      my_strdup(_ALLOC_ID_, &verilog_sym_def, get_tok_value(xctx->inst[i].prop_ptr,"verilog_sym_def",4));
      my_strdup(_ALLOC_ID_, &vhdl_sym_def, get_tok_value(xctx->inst[i].prop_ptr,"vhdl_sym_def",4));

      /* resolve schematic=generator.tcl( @n ) where n=11 is defined in instance attrs */
      my_strdup2(_ALLOC_ID_, &sch, get_tok_value(xctx->inst[i].prop_ptr,"schematic", 6));
      dbg(1, "get_additional_symbols(): schematic=%s\n", sch);
      schematic_token_found = xctx->tok_size;

      /* ISSUE 1201. The copy did not name a cell body of its own -- so ask
       * whether the netlister should name one for it. auto_spec_name() answers
       * NULL for everything except the one shape this issue is about, and
       * always NULL outside a SPICE netlist run. When it does answer, the name
       * takes exactly the route a hand-typed one takes from here on: the file
       * of that name does not exist, so the fallback three lines below points
       * the new symbol block at the cell's own drawing, and parent_prop_ptr
       * further down feeds THIS copy's settings into it. That is the whole
       * mechanism; nothing new was needed for it. */
      if(!schematic_token_found) {
        auto_sch = auto_spec_name(i);
        if(auto_sch && auto_sch[0]) {
          my_strdup2(_ALLOC_ID_, &sch, auto_sch);
          schematic_token_found = strlen(auto_sch);
        }
      }

      my_strdup2(_ALLOC_ID_, &sch, translate3(sch, 1, xctx->inst[i].prop_ptr, NULL, NULL, NULL));
      dbg(1, "  get_additional_symbols(): sch=%s tok_size= %ld\n", sch, xctx->tok_size);

      my_strdup2(_ALLOC_ID_, &sch, tcl_hook2(
         str_replace(sch, "@symname", get_cell(xctx->inst[i].name, 0), '\\', -1)));
      dbg(1, "  get_additional_symbols(): sch=%s\n", sch);

      /* schematic does not exist */
      if(sch[0] && stat(abs_sym_path(sch, ""), &buf)) {
        my_snprintf(symbol_base_sch, PATH_MAX, "%s.sch", get_cell(xctx->sym[xctx->inst[i].ptr].name, 9999));
        dbg(1, "get_additional_symbols(): schematic not existing\n");
        dbg(1, "using: %s\n", symbol_base_sch);
      }
      if(schematic_token_found && sch[0]) { /* `schematic` token exists  and a schematic is specified */
        int j;
        char *sym = NULL;
        char *symname_attr = NULL;
        int ignore_schematic = 0;
        xSymbol *symptr = xctx->inst[i].ptr + xctx->sym;

        my_strdup2(_ALLOC_ID_, &default_schematic, get_tok_value(symptr->prop_ptr,"default_schematic",0));
        ignore_schematic = !strcmp(default_schematic, "ignore");

        dbg(1, "get_additional_symbols(): inst=%d, sch=%s instname=%s\n", i, sch, xctx->inst[i].instname);
        dbg(1, "get_additional_symbols(): current_name=%s\n", xctx->current_name);

        is_gen = is_generator(sch);

        if(is_gen) {
          my_strdup2(_ALLOC_ID_, &sym, sch);
          dbg(1, "get_additional_symbols(): generator\n");
        } else {
          my_strdup2(_ALLOC_ID_, &sym, add_ext(rel_sym_path(sch), ".sym"));
        }

        /* get_cell() returns "" whenever the basename is nothing but an extension --
         * `schematic=foo/` yields sym == "foo/.sym", and get_trailing_path()
         * (token.c:1434-1440) NUL-terminates at the '.' and then returns the text after
         * the '/'. Measured reachable: that instance logs `has_included_subcircuit: :`
         * with an empty cell name. Unquoted, the empty symname would swallow the whole
         * " symref=..." that follows and translate3() would resolve @symname to the
         * symref and @symref to nothing. Issue 0183. */
        my_mstrcat_tok(_ALLOC_ID_, &symname_attr, "symname", get_cell(sym, 0), NULL);
        my_mstrcat(_ALLOC_ID_, &symname_attr, " symref=", get_sym_name(i, 9999, 1, 1), NULL);
        my_strdup(_ALLOC_ID_, &spice_sym_def,
            translate3(spice_sym_def, 1, xctx->inst[i].prop_ptr,
                                         symptr->templ,
                                         symname_attr, NULL));
        my_strdup(_ALLOC_ID_, &spectre_sym_def,
            translate3(spectre_sym_def, 1, xctx->inst[i].prop_ptr,
                                         symptr->templ,
                                         symname_attr, NULL));
        my_free(_ALLOC_ID_, &symname_attr);
        /* if instance symbol has default_schematic set to ignore copy the symbol anyway, since
         * the base symbol will not be netlisted by *_block_netlist() */
        found = ignore_schematic ? NULL : int_hash_lookup(&sym_table, sym, 0, XLOOKUP);
        if(!found) {
          j = xctx->symbols;
          int_hash_lookup(&sym_table, sym, j, XINSERT);
          dbg(1, "get_additional_symbols(): adding symbol %s\n", sym);
          check_symbol_storage();
          copy_symbol(&xctx->sym[j], symptr);
          xctx->sym[j].base_name = symptr->name;
          my_strdup(_ALLOC_ID_, &xctx->sym[j].name, sym);

          my_strdup(_ALLOC_ID_, &xctx->sym[j].parent_prop_ptr, xctx->inst[i].prop_ptr);
          /* the copied symbol will not inherit the default_schematic attribute otherwise it will also
           * be skipped */
          if(default_schematic) {
            my_strdup(_ALLOC_ID_, &xctx->sym[j].prop_ptr,
              subst_token(xctx->sym[j].prop_ptr, "default_schematic", NULL)); /* delete attribute */
          }
          /* if symbol has no corresponding schematic file use symbol base schematic */
          if(!is_gen && symbol_base_sch[0]) {
            my_strdup(_ALLOC_ID_, &xctx->sym[j].prop_ptr,
              subst_token(xctx->sym[j].prop_ptr, "schematic", symbol_base_sch));
          }
          if(spice_sym_def) {
             my_strdup(_ALLOC_ID_, &xctx->sym[j].prop_ptr,
               subst_token(xctx->sym[j].prop_ptr, "spice_sym_def", spice_sym_def));
          }
          if(spectre_sym_def) {
             my_strdup(_ALLOC_ID_, &xctx->sym[j].prop_ptr,
               subst_token(xctx->sym[j].prop_ptr, "spectre_sym_def", spectre_sym_def));
          }
          if(verilog_sym_def) {
             my_strdup(_ALLOC_ID_, &xctx->sym[j].prop_ptr,
               subst_token(xctx->sym[j].prop_ptr, "verilog_sym_def", verilog_sym_def));
          }
          if(vhdl_sym_def) {
             my_strdup(_ALLOC_ID_, &xctx->sym[j].prop_ptr,
               subst_token(xctx->sym[j].prop_ptr, "vhdl_sym_def", vhdl_sym_def));
          }
          xctx->symbols++;
        } else {
         j = found->value;
        }
        my_free(_ALLOC_ID_, &sym);
        my_free(_ALLOC_ID_, &default_schematic);
      } /* if(xctx->tok_size && sch[0]) */
      my_free(_ALLOC_ID_, &sch);
      my_free(_ALLOC_ID_, &spice_sym_def);
      my_free(_ALLOC_ID_, &spectre_sym_def);
      my_free(_ALLOC_ID_, &vhdl_sym_def);
      my_free(_ALLOC_ID_, &verilog_sym_def);
    } /* for(i=0;i<xctx->instances; ++i) */
    int_hash_free(&sym_table);
  } else { /* end */
    for(i = xctx->symbols - 1; i >= num_syms; --i) {
      remove_symbol(i);
    }
    xctx->symbols = num_syms;
  }
}
/* fallback = 1: if schematic attribute is set but file not existing fallback
 * to defaut symbol schematic (symname.sym -> symname.sch)
 * if inst == -1 use only symbol reference */
/* If 'ref' is a lib-qualified reference "lib/cell" whose schematic view exists
 * (<libpath>/<cell>/schematic/<cell>.sch), return its absolute path, else "".
 * Thin wrapper over the Tcl resolver (library-manager Phase 4). Lets descend and
 * the schematic= override target the cell's schematic VIEW rather than ext-swap
 * the symbol-view path. See doc/claude/code_analysis/library_manager_design.md.
 *
 * ⚠ `ref` IS `.sch` TEXT AND MUST NOT BE CONCATENATED INTO THE SCRIPT -- issue
 * 0827. It used to be spelled
 *     my_snprintf(c, S(c), "cellview_path {%s} schematic", ref); tcleval(c);
 * and both call sites below hand it attacker-controlled bytes: the instance's
 * `schematic=` property value, and the symbol's own name. `\}` is the `.sch`
 * format's OWN escape for a literal brace, so a WELL-FORMED sheet closed the
 * group and the rest of the attribute RAN AS TCL. Driven: ONE mailed `.sch`
 * referencing examples/rlc.sym (which ships with xschem) executed `exec touch`
 * on a plain `xschem descend -inst x1`, --nogui, no dialog. The second door
 * (sym->name) needs an EMBEDDED subcircuit symbol -- a disk symbol whose name
 * carries `}` cannot reach it, because the load falls back to missing.sym and
 * descend_schematic()'s type guard refuses a non-subcircuit -- and was driven
 * too. tcl_call() (util.c) hands `ref` over as a variable; one wrapper, both
 * doors. The PATH_MAX+100 buffer and its silent mid-escape truncation go with
 * it. Rows CVP01-CVP07 in tests/headless/test_raw_read_dispatch.tcl. */
static const char *cellview_sch_path(const char *ref)
{
  return tcl_call("cellview_path", ref ? ref : "", NULL, "schematic");
}

void get_sch_from_sym(char *filename, xSymbol *sym, int inst, int fallback)
{
  char *sch = NULL;
  char *str_tmp = NULL;
  int web_url = 0;
  struct stat buf;
  int file_exists=0;
  int cancel = 0;
  int is_gen = 0;
  char msg[PATH_MAX + 100];

  my_strncpy(filename, "", PATH_MAX);

  if(inst >= xctx->instances) {
    dbg(0, "get_sch_from_sym() error: called with invalid inst=%d\n", inst);
    return;
  }

  if(!sym) {
    dbg(0, "get_sch_from_sym() error: called with NULL sym", inst);
    return;
  }

  /* get sch/sym name from parent schematic downloaded from web */
  if(is_from_web(xctx->current_dirname)) {
    web_url = 1;
  }

  dbg(1, "get_sch_from_sym(): current_dirname= %s\n", xctx->current_dirname);
  dbg(1, "get_sch_from_sym(): symbol %s inst=%d web_url=%d\n", sym->name, inst, web_url);
  /* resolve schematic=generator.tcl( @n ) where n=11 is defined in instance attrs */
  if(inst >=0 ) {
    /* hi_descend: one-shot transient view override (doc/claude/specs/hi_descend.md). When the Tcl
     * global hi_descend_view_path is non-empty, resolve THIS one descend into that exact
     * view file instead of the instance/symbol 'schematic' attribute -- so choosing a
     * non-default named view does not rewrite (and dirty) the instance. Single-use: it is
     * cleared immediately, and descend_schematic resolves the target instance before any
     * other get_sch_from_sym call, so netlisting / cellview / go_back callers are
     * unaffected. */
    const char *hi_ov = tclgetvar("hi_descend_view_path");
    if(hi_ov && hi_ov[0]) {
      my_strdup2(_ALLOC_ID_, &str_tmp, hi_ov);
      Tcl_SetVar(interp, "hi_descend_view_path", "", TCL_GLOBAL_ONLY);
    } else {
      /* instance based symbol selection */
      /* resolve schematic=generator.tcl( @n ) where n=11 is defined in instance attrs */
      my_strdup2(_ALLOC_ID_, &str_tmp, get_tok_value(xctx->inst[inst].prop_ptr,"schematic", 6));
    }
    if(str_tmp[0])
      my_strdup2(_ALLOC_ID_, &str_tmp, translate3(str_tmp, 1, xctx->inst[inst].prop_ptr, NULL, NULL, NULL));
    /*
     * my_strdup(_ALLOC_ID_, &str_tmp, translate3(get_tok_value(xctx->inst[inst].prop_ptr,"schematic", 6),
     *          1, xctx->inst[inst].prop_ptr, NULL, NULL, NULL));
     */
  }
  if(!str_tmp || !str_tmp[0]) my_strdup2(_ALLOC_ID_, &str_tmp,  get_tok_value(sym->prop_ptr, "schematic", 6));
  if(str_tmp && str_tmp[0]) { /* schematic attribute in symbol or instance was given */
    /* @symname in schematic attribute will be replaced with symbol name */
    my_strdup2(_ALLOC_ID_, &sch, tcl_hook2(str_replace(str_tmp, "@symname",
       get_cell(sym->name, 0), '\\', -1)));
    if(is_generator(sch)) { /* generator: return as is */
      my_strncpy(filename, sch, PATH_MAX);
      is_gen = 1;
      dbg(1, "get_sch_from_sym(): filename=%s\n", filename);
    } else { /* not generator */
      const char *cv;
      dbg(1, "get_sch_from_sym(): after tcl_hook2 sch=%s\n", sch);
      /* for schematics referenced from web symbols do not build absolute path */
      if(web_url) my_strncpy(filename, sch, PATH_MAX);
      /* a lib-qualified override (lib/cell) points at the cell's schematic view */
      else if((cv = cellview_sch_path(sch))[0]) my_strncpy(filename, cv, PATH_MAX);
      else my_strncpy(filename, abs_sym_path(sch, ""), PATH_MAX);
    }
  }

  if(has_x && fallback && !is_gen && filename[0]) {
    file_exists = !stat(filename, &buf);
    if(!file_exists) {
      my_snprintf(msg, S(msg), "Schematic %s\ndoes not exist.\nDescend into base schematic?", filename);
      tcl_call("ask_save", msg, NULL, NULL);
      if(strcmp(tclresult(), "yes") ) fallback = 0; /* 'no' or 'cancel' */
       if(!strcmp(tclresult(), "") ) { /* 'cancel' */
         cancel = 1;
         my_strncpy(filename,"", PATH_MAX);
       }
    }
  }

  /* no schematic attr from instance or symbol */
  if(!cancel && (!str_tmp[0] || (fallback && !is_gen && filename[0] && !file_exists ))) {
    const char *symname_tcl = tcl_hook2(sym->name);
    const char *cv;
    if(is_generator(symname_tcl))  my_strncpy(filename, symname_tcl, PATH_MAX);
    /* lib-qualified symbol: its schematic lives in the cell's schematic view */
    else if(!web_url && (cv = cellview_sch_path(sym->name))[0]) my_strncpy(filename, cv, PATH_MAX);
    else if(tclgetboolvar("search_schematic")) {
      /* for schematics referenced from web symbols do not build absolute path */
      if(web_url) my_strncpy(filename, add_ext(sym->name, ".sch"), PATH_MAX);
      else my_strncpy(filename, abs_sym_path(sym->name, ".sch"), PATH_MAX);
    } else {
      /* for schematics referenced from web symbols do not build absolute path */
      if(web_url) my_strncpy(filename, add_ext(sym->name, ".sch"), PATH_MAX);
      else {
        if(!stat(abs_sym_path(sym->name, ""), &buf)) /* symbol exists. pretend schematic exists too ... */
          my_strncpy(filename, add_ext(abs_sym_path(sym->name, ""), ".sch"), PATH_MAX);
        else /* ... symbol does not exist (instances with schematic=... attr) so can not pretend that */
          my_strncpy(filename, abs_sym_path(sym->name, ".sch"), PATH_MAX);
      }
    }
  }
  if(sch) my_free(_ALLOC_ID_, &sch);

  if(web_url && filename[0] && xschem_web_dirname[0]) {
    char sympath[PATH_MAX];

    /* build local cached filename of web_url */
    my_snprintf(sympath, S(sympath), "%s/%s",  xschem_web_dirname, get_cell_w_ext(filename, 0));
    if(stat(sympath, &buf)) { /* not found, download */
      /* download item into ${XSCHEM_TMP_DIR}/xschem_web_xxxxx */
      tcl_call("try_download_url", xctx->current_dirname, filename, NULL);
    }
    if(stat(sympath, &buf)) { /* not found !!! build abs_sym_path to look into local fs and hope fror the best */
      my_strncpy(filename, abs_sym_path(sym->name, ".sch"), PATH_MAX);
    } else {
      my_strncpy(filename, sympath, PATH_MAX);
    }
  }
  my_free(_ALLOC_ID_, &str_tmp);
  dbg(1, "get_sch_from_sym(): sym->name=%s, filename=%s\n", sym->name, filename);
}

/* When descended into an i-th instance of a vector instance this function allows
 * to change the path to the j-th instance. the instnumber parameters follows the same rules
 * as descend_schematic() */
int change_sch_path(int instnumber, int dr)
{
  int level = xctx->currsch - 1;
  char *instname = NULL;
  char *expanded_instname = NULL;
  int inst_mult;
  char *path = NULL;
  char *ptr;
  size_t pathlen;
  int res = 0;
  if(level < 0 ) return 0;
  my_strdup2(_ALLOC_ID_, &instname, get_tok_value(xctx->hier_attr[level].prop_ptr, "name", 0));
  my_strdup2(_ALLOC_ID_, &expanded_instname, expandlabel(instname, &inst_mult));
  my_strdup2(_ALLOC_ID_, &path, xctx->sch_path[xctx->currsch]);
  if(instnumber < 0 ) instnumber += inst_mult+1;
  /* any invalid number->descend to leftmost inst */
  if(instnumber <1 || instnumber > inst_mult) instnumber = 1;
  pathlen = strlen(path);
  if(pathlen == 0) goto end;
  path[pathlen - 1] = '\0';
  ptr = strrchr(path, '.');
  if(!ptr) goto end;
  *(ptr+1) = '\0';
  my_free(_ALLOC_ID_, &xctx->sch_path[xctx->currsch]);
  my_strcat(_ALLOC_ID_, &xctx->sch_path[xctx->currsch], path);
  my_strcat(_ALLOC_ID_, &xctx->sch_path[xctx->currsch], find_nth(expanded_instname, ",", "", 0, instnumber));
  my_strcat(_ALLOC_ID_, &xctx->sch_path[xctx->currsch], ".");
  xctx->sch_path_hash[xctx->currsch] = 0;
  xctx->sch_inst_number[level] = instnumber;
  dbg(1, "instname=%s, path=%s\n", instname, path);
  path[pathlen - 1] = '.';
  res = 1;
  if(dr && has_x) {
    draw();
  }
  end:
  my_free(_ALLOC_ID_, &instname);
  my_free(_ALLOC_ID_, &path);
  my_free(_ALLOC_ID_, &expanded_instname);
  return res;
}

/* ===========================================================================
 * The descend refusal channel. Issues 0249 / 0251 / 0254 / 0256 / 0366.
 * doc/claude/code_analysis/descend_silent_refusal_census.md
 *
 * descend has thirteen refusal sites and, before this, no status protocol: a
 * refused descend was indistinguishable from a successful one at every caller.
 * ONE mechanism closes the batch -- a short reason token recorded on the CURRENT
 * context (xctx->descend_err, read as `xschem get descend_error`) at every
 * `return 0`, plus a status line at the subset of them the user actually asked
 * for.
 *
 * RECORD ALWAYS, SPEAK SELECTIVELY, and the split is the point:
 *   loud  -- the user pressed `i`/`e` on something they picked and nothing
 *            happened (empty/ambiguous selection, a ---MISSING SYMBOL---
 *            placeholder, a symbol with no schematic view, a failed load).
 *   quiet -- the annotation class: 262 shipped lab_pin/gnd/vdd/ipin/title/
 *            launcher/probe symbols have no child schematic and pressing `e`
 *            with one selected never promised a descend. Making those speak adds
 *            one status line per label press and breaks the committed lock
 *            tests/headless/test_descend_inert_class.tcl.
 * A quiet refusal still RECORDS, so a script or a dialog can ask why.
 *
 * Two rules this must not break:
 *  - the reason is a SECOND channel. The "0"/"1" string of `xschem descend` is
 *    load-bearing in src/xschem.tcl, sky130/ihp/cadence glue and
 *    tests/buried_hilight.tcl; it is never widened into a reason string.
 *  - speaking uses statusmsg_hold(), never a plain statusmsg() and never dbg(0).
 *    A plain statusmsg is clobbered one call later by select.c's
 *    "n= x= y= w= h=" info line (issue 0248), and stderr noise is what the
 *    inert-class lock greps for.
 * =========================================================================== */

/* Both verbs call this on entry, so a stale reason can never be read as a fresh
 * one and the SUCCESS path needs no bookkeeping of its own. */
void descend_clear_error(void)
{
  if(xctx) xctx->descend_err[0] = '\0';
}

/* The loud/silent predicate. Trivial by design: it exists as a named callee so
 * the split can be neutralized in one place by a sabotage build (`#define
 * descend_speak_p(s) (1)` must turn the inert-class silence rows red). */
int descend_speak_p(int speak)
{
  return speak;
}

/* Say it where a user will actually read it. statusmsg_hold() (issue 0248) owns
 * .statusbar.1 for a few seconds so the selection info line cannot eat it, and
 * it records xctx->statusmsg_text even headless -- which is the test seam
 * (`xschem get statusmsg` / `get statusmsg_hold`). */
void descend_speak(const char *msg)
{
  if(msg && msg[0]) statusmsg_hold((char *)msg, 1);
}

/* code: the stable token a script tests ("no-selection", "not-descendable", ...)
 * detail: appended as "code:detail" when non-empty (the symbol name, the type)
 * msg:  the human sentence, used only when speak
 * speak: 1 = the user asked for this descend, 0 = record only */
void descend_set_error(const char *code, const char *detail, const char *msg, int speak)
{
  if(!xctx) return;
  if(detail && detail[0]) {
    my_snprintf(xctx->descend_err, S(xctx->descend_err), "%s:%s", code, detail);
  } else {
    my_snprintf(xctx->descend_err, S(xctx->descend_err), "%s", code);
  }
  if(descend_speak_p(speak)) descend_speak(msg);
}

/* Which instance does the user mean? Counted over the ELEMENT entries of the
 * selection -- what `xschem selected_set` reports and what is highlighted on
 * screen -- NOT xctx->lastsel, which also counts INST_PIN pseudo-selections
 * (an instance plus its own pin reads as lastsel 2 while exactly one symbol is
 * selected; the legacy `lastsel > 1` guard refused a selection that does not
 * exist -- issue 0249).
 * multi_ok = 1 keeps descend_schematic's shipped "first ELEMENT, any count"
 * capability; descend_symbol passes 0 and refuses a genuinely ambiguous pick,
 * but now says so.
 * The loop is also the fix for issue 0366: with nothing selected,
 * rebuild_selected_array() leaves the PREVIOUS rebuild's entry in sel_array[0],
 * so a guard phrased as `sel_array[0].type != ELEMENT` re-descended into the
 * last child and returned 1. Nothing here reads sel_array[i] past lastsel. */
int descend_pick_target(int *n, int multi_ok, const char *verb)
{
  int i, nelem = 0, first = -1;
  char msg[256];
  rebuild_selected_array();
  for(i = 0; i < xctx->lastsel; ++i) {
    if(xctx->sel_array[i].type == ELEMENT) {
      if(first < 0) first = xctx->sel_array[i].n;
      ++nelem;
    }
  }
  if(nelem == 0) {
    my_snprintf(msg, S(msg), "%s: select an instance to descend into", verb);
    /* two different mistakes: "you selected nothing" and "you selected something
     * that is not an instance". Same sentence, different token. */
    descend_set_error(xctx->lastsel == 0 ? "no-selection" : "no-instance-selected",
                      NULL, msg, 1);
    return 0;
  }
  if(nelem > 1 && !multi_ok) {
    my_snprintf(msg, S(msg), "%s: select exactly one instance", verb);
    descend_set_error("multi-selection", NULL, msg, 1);
    return 0;
  }
  *n = first;
  return 1;
}

/* The ---MISSING SYMBOL--- placeholder (issue 0254). Its own named guard, tested
 * BEFORE the generic type whitelist on both verbs, because it is the one member
 * of the "type is not subcircuit" family that a user deliberately clicks to find
 * out what broke -- so it must SPEAK the unresolved name, which is live in the
 * caller two lines up. None of the 262 annotation symbols carries type
 * "missing", so the inert-class lock is untouched.
 * A user-authored symbol that really exists on disk and declares type=missing is
 * a different sentence (it is not a lookup failure) but the same token. */
int descend_missing_sym(int n, const char *symname)
{
  struct stat sbuf;
  char msg[PATH_MAX + 128];
  const char *type = (xctx->inst[n].ptr + xctx->sym)->type;
  const char *path;
  if(!type || strcmp(type, "missing")) return 0;
  path = (symname && symname[0] && !is_generator(symname)) ? abs_sym_path(symname, "") : "";
  if(path && path[0] && !stat(path, &sbuf)) {
    my_snprintf(msg, S(msg), "Descend: %s declares type=missing -- nothing to descend into",
                symname);
  } else {
    my_snprintf(msg, S(msg), "Descend: symbol not found: %s -- nothing to descend into",
                symname ? symname : "");
  }
  descend_set_error("missing-symbol", symname, msg, 1);
  return 1;
}

/* fallback = 1: if schematic=.. attr is set but file not existing descend into symbol base schematic
 * instnumber: instance to descend into in case of vector instances (1 = leftmost, -1=rightmost)
 * if set_title == 0 do not set window title (faster)
 *              == 1 do set_title
 *              == 2 do not process instance pins/nets
 *              == 4 do not descend into i-th instance of vecrtor instance. just
 *                 concatenate instance name as is to path and descend.
 *              above flags can be ORed together */
int descend_schematic(int instnumber, int fallback, int alert, int set_title)
{
 char *str = NULL;
 char filename[PATH_MAX];
 char descend_logname[256] = ""; /* raw instname captured for the outcome-level action log */
 int inst_mult, inst_number;
 int save_ok = 0;
 int i, n = 0;
 int descend_ok = 1;

 descend_clear_error();
 if(xctx->currsch + 1 >= CADMAXHIER) {
   char msg[128];
   my_snprintf(msg, S(msg), "Descend: maximum hierarchy depth (%d) reached", CADMAXHIER);
   dbg(0, "descend_schematic(): max hierarchy depth reached: %d", CADMAXHIER);
   descend_set_error("maxdepth", NULL, msg, 1);
   return 0;
 }
 /* was: a bare test of sel_array[0].type != ELEMENT (with the lastsel != 1 half
  * commented out). That read entry 0
  * of an array that, with nothing selected, still holds the PREVIOUS rebuild's
  * entry -- so `e`, go_back, `e` descended a second time and reported success
  * (issue 0366). The picker counts live ELEMENT entries instead, and keeps the
  * "first ELEMENT, any count" capability (multi_ok = 1): no descend that
  * succeeds today stops succeeding, 0366's false one excepted. */
 if(!descend_pick_target(&n, 1, "Descend")) {
   dbg(1, "descend_schematic(): wrong selection\n");
   return 0;
 }
 else {
   char symname[PATH_MAX];
   /* no name set for current schematic: save it before descending*/
   if(!strcmp(xctx->sch[xctx->currsch],""))
   {
     char cmd[PATH_MAX+1000];
     char res[PATH_MAX];

     my_strncpy(filename, xctx->sch[xctx->currsch], S(filename));
     my_snprintf(cmd, S(cmd), "save_file_dialog {Save file} * INITIALLOADDIR {%s}", filename);
     tcleval(cmd);
     my_strncpy(res, tclresult(), S(res));
     /* the user's own Cancel is its own feedback: record it, do not narrate it
      * (message built anyway -- speak = 0 is the only thing keeping it quiet) */
     if(!res[0]) {
       descend_set_error("save-cancelled", NULL, "Descend: save cancelled -- not descending", 0);
       return 0;
     }
     dbg(1, "descend_schematic(): saving: %s\n",res);
     save_ok = save_schematic(res, 0);
     if(save_ok==0) {
       descend_set_error("save-failed", NULL,
         "Descend: could not save the current schematic -- not descending", 1);
       return 0;
     }
   }
   /* capture the raw instname NOW: after load_schematic() below, xctx->inst[]
    * is the CHILD's array and n no longer names this instance. Used for the
    * `xschem descend -inst <name>` action-log line. action_log_absorb.md */
   my_strncpy(descend_logname, xctx->inst[n].instname ? xctx->inst[n].instname : "", S(descend_logname));
   my_snprintf(symname, S(symname), "%s", translate(n, xctx->inst[n].name));
   /* issue 0254: the placeholder is checked BEFORE the generic type guard, so the
    * one refusal in this family that a user provoked on purpose can name the
    * symbol that failed to resolve instead of joining the silent class. */
   if(descend_missing_sym(n, symname)) return 0;
   dbg(1, "descend_schematic(): selected:%s\n", xctx->inst[n].name);
   dbg(1, "descend_schematic(): inst type: %s\n", (xctx->inst[n].ptr+ xctx->sym)->type);
   /* THE SILENT ONE (speak = 0), and it must stay silent: this is the annotation
    * class -- labels, ports, title blocks, launchers, probes. Nothing the user saw,
    * typed or clicked promised a descend, so there is nothing to explain; the
    * reason is recorded for whoever asks. Locked by
    * tests/headless/test_descend_inert_class.tcl (262 symbols).
    * Moved AHEAD of get_sch_from_sym(): the type is knowable without resolving a
    * filename, and this keeps the annotation class landing on its own token
    * rather than on the (loud) no-schematic one. */
   if(                   /*  do not descend if not subcircuit */
      (xctx->inst[n].ptr+ xctx->sym)->type &&
      strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "subcircuit") &&
      strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "primitive")
   ) {
     /* The sentence is BUILT and then deliberately not said: what keeps this guard
      * quiet is the speak = 0 argument alone, not a missing string. That is what makes
      * the policy testable -- neutralize descend_speak_p() and the inert-class silence
      * rows must go red. */
     char msg[PATH_MAX + 128];
     my_snprintf(msg, S(msg), "Descend: %s is a '%s' symbol -- nothing to descend into",
                 symname, (xctx->inst[n].ptr+ xctx->sym)->type);
     descend_set_error("not-descendable", (xctx->inst[n].ptr+ xctx->sym)->type, msg, 0);
     return 0;
   }
   get_sch_from_sym(filename, xctx->inst[n].ptr+ xctx->sym, n, fallback);

   if(!filename[0]) { /* no filename returned from get_sch_from_sym() --> abort */
     char msg[PATH_MAX + 128];
     my_snprintf(msg, S(msg), "Descend: %s has no schematic view", symname);
     descend_set_error("no-schematic", NULL, msg, 1);
     return 0;
   }
   /* No save prompt on descend: a genuine edit to the parent was already
    * persisted to cellName~.sch by the autosave hook (set_modify -> write_backup),
    * and go_back() reloads that backup, restoring the unsaved edits and the
    * modified flag. Descending is not a save point and never loses data, so it
    * must not prompt. Prompts remain at go_back and window-close, where edits
    * are actually at risk. doc/claude/specs/descend_hierarchy_in_memory.md (B5) */
   /*  build up current hierarchy path */
   dbg(1, "descend_schematic(): selected instname=%s\n", xctx->inst[n].instname);

   if(xctx->inst[n].instname && xctx->inst[n].instname[0]) {
     if(set_title & 4)  {
       my_strdup2(_ALLOC_ID_, &str, xctx->inst[n].instname);
       inst_mult = 1;
       instnumber = 1;
     } else {
       my_strdup2(_ALLOC_ID_, &str, expandlabel(xctx->inst[n].instname, &inst_mult));
     }
   } else {
     my_strdup2(_ALLOC_ID_, &str, "");
     inst_mult = 1;
   }
   prepare_netlist_structs(0); /* for portmap feature (mapping subcircuit nodes connected to
                                * ports to upper level) */

   inst_number = 1;
   if(inst_mult > 1) { /* on multiple instances ask where to descend, to correctly evaluate
                          the hierarchy path you descend to */
     if(instnumber == 0 ) {
       const char *inum;
       tclvareval("input_line ", "{input instance number (leftmost = 1) to descend into:\n"
         "negative numbers select instance starting\nfrom the right (rightmost = -1)}"
         " {} 1 6", NULL);
       inum = tclresult();
       dbg(1, "descend_schematic(): inum=%s\n", inum);
       if(!inum[0]) {
         my_free(_ALLOC_ID_, &str);
         /* the user cancelled the iteration prompt: their own Cancel is the feedback */
         descend_set_error("iter-cancelled", NULL,
           "Descend: no instance number given -- not descending", 0);
         return 0;
       }
       inst_number=atoi(inum);
     } else {
       inst_number = instnumber;
     }
     if(inst_number < 0 ) inst_number += inst_mult+1;
     /* any invalid number->descend to leftmost inst */
     if(inst_number <1 || inst_number > inst_mult) inst_number = 1;
   }

   my_strdup(_ALLOC_ID_, &xctx->sch_path[xctx->currsch+1], xctx->sch_path[xctx->currsch]);
   xctx->sch_path_hash[xctx->currsch+1] =0;
   if(xctx->portmap[xctx->currsch + 1].table) str_hash_free(&xctx->portmap[xctx->currsch + 1]);
   str_hash_init(&xctx->portmap[xctx->currsch + 1], HASHSIZE);

   if(!(set_title & 2)) for(i = 0; i < xctx->sym[xctx->inst[n].ptr].rects[PINLAYER]; i++) {
     const char *pin_name = get_tok_value(xctx->sym[xctx->inst[n].ptr].rect[PINLAYER][i].prop_ptr,"name",0);
     char *pin_node = NULL, *net_node = NULL;
     int k, mult, net_mult;
     char *single_p, *single_n = NULL, *single_n_ptr = NULL;
     char *p_n_s1 = NULL;
     char *p_n_s2 = NULL;

     if(!pin_name[0]) continue;
     if(!xctx->inst[n].node[i]) continue;

     my_strdup2(_ALLOC_ID_, &pin_node, expandlabel(pin_name, &mult));
     my_strdup2(_ALLOC_ID_, &net_node, expandlabel(xctx->inst[n].node[i], &net_mult));

     p_n_s1 = pin_node;
     for(k = 1; k<=mult; ++k) {
         single_p = my_strtok_r(p_n_s1, ",", "", 0, &p_n_s2);
         p_n_s1 = NULL;
         my_strdup2(_ALLOC_ID_, &single_n,
             find_nth(net_node, ",", "", 0, ((inst_number - 1) * mult + k - 1) % net_mult + 1));
         single_n_ptr = single_n;
         if(single_n_ptr[0] == '#') {
           if(mult > 1) {
             my_mstrcat(_ALLOC_ID_, &single_n, "[", my_itoa((inst_mult - inst_number + 1) * mult - k), "]", NULL);
           }
           single_n_ptr = single_n + 1;
         }
         str_hash_lookup(&xctx->portmap[xctx->currsch + 1], single_p, single_n_ptr, XINSERT);
         dbg(1, "descend_schematic(): %s: %s ->%s\n", xctx->inst[n].instname, single_p, single_n_ptr);
     }
     if(single_n) my_free(_ALLOC_ID_, &single_n);
     my_free(_ALLOC_ID_, &net_node);
     my_free(_ALLOC_ID_, &pin_node);
   }

   my_strdup(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch].prop_ptr,
             xctx->inst[n].prop_ptr);
   my_strdup(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch].templ, xctx->sym[xctx->inst[n].ptr].templ);
   my_strdup(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch].sym_extra,
     get_tok_value(xctx->sym[xctx->inst[n].ptr].prop_ptr, "extra", 0));
   /* ISSUE 1201. ⚠ ASKED HERE AND NOWHERE ELSE, AND IT HAS TO BE. The question
    * "would the netlister give this copy a cell body of its own?" needs the
    * PARENT sheet's instance and its symbol, and one line below this the walk
    * is inside the child and neither of them exists any more. The three
    * attribute strings above are recorded for exactly the same reason. Read
    * back from Tcl as lcc[N].auto_spec by op_annot::model_netlist, so the
    * annotation surface asks the results file for the device under the name the
    * simulator really used. */
   xctx->hier_attr[xctx->currsch].auto_spec = auto_spec_would_specialize(n);

   dbg(1,"descend_schematic(): inst_number=%d\n", inst_number);
   my_strcat(_ALLOC_ID_, &xctx->sch_path[xctx->currsch+1], find_nth(str, ",", "", 0, inst_number));
   my_free(_ALLOC_ID_, &str);
   dbg(1,"descend_schematic(): inst_number=%d\n", inst_number);
   my_strcat(_ALLOC_ID_, &xctx->sch_path[xctx->currsch+1], ".");
   xctx->sch_inst_number[xctx->currsch] = inst_number;
   dbg(1, "descend_schematic(): current path: %s\n", xctx->sch_path[xctx->currsch+1]);
   dbg(1, "descend_schematic(): inst_number=%d\n", inst_number);

   xctx->previous_instance[xctx->currsch]=n;
   xctx->zoom_array[xctx->currsch].x=xctx->xorigin;
   xctx->zoom_array[xctx->currsch].y=xctx->yorigin;
   xctx->zoom_array[xctx->currsch].zoom=xctx->zoom;
   xctx->currsch++;
   hilight_child_pins();
   unselect_all(1);
   dbg(1, "descend_schematic(): filename=%s\n", filename);
   /* we are descending from a parent schematic downloaded from the web */
   if(!tclgetboolvar("keep_symbols")) remove_symbols();
   descend_ok = load_schematic(1, filename, (set_title & 1), alert);
   if(!descend_ok) {
     /* xctx->currsch was ALREADY incremented above, so this 0 does not mean
      * "nothing happened" -- the window is one level down on a page that failed
      * to load and the caller must go_back. Its own token, deliberately not
      * lumped in with the refusals (issue 0250). */
     char msg[PATH_MAX + 128];
     my_snprintf(msg, S(msg), "Descend: could not load %s", filename);
     descend_set_error("load-failed", NULL, msg, 1);
   }
   if(descend_ok) {
     /* Outcome-level action log: record the coordinate-free, replay-stable form
      * `xschem descend -inst <name>`, absorbing the provisional select_at the
      * selecting click stashed (n = the parent instance it selected). Empty name
      * (rare, unnamed instance) falls back to the plain form + a flushed
      * select_at. doc/claude/specs/action_log_absorb.md */
     if(descend_logname[0]) log_action_descend("descend", n, descend_logname);
     else log_action("xschem descend");
     if(xctx->hilight_nets) {
       prepare_netlist_structs(0);
       propagate_hilights(1, 0, XINSERT_NOREPLACE);
     }
     dbg(1, "descend_schematic(): before zoom(): prep_hash_inst=%d\n", xctx->prep_hash_inst);

     if(xctx->rects[GRIDLAYER] > 0 && tcleval("info exists ngspice::ngspice_data")[0] == '0') {
       Graph_ctx *gr = &xctx->graph_struct;
       xRect *r = &xctx->rect[GRIDLAYER][0];
       if(r->flags & 1) {
         /* ISSUES 0865 / 0868 -- GUARD G2: DESCENDING IS NOT A REQUEST.
          *
          * This was the second of two UNGATED publishers. Walk into a child that
          * happens to carry a graph rect with cursor B on and the child's sheet
          * ACQUIRED a node-voltage annotation -- with `Simulation > Graphs >
          * Live annotate probes with 'b' cursor` in its shipped UNTICKED state,
          * i.e. with the user having asked for nothing. Move the cursor
          * afterwards and the number stays where it was: RULING D5-1, a number
          * that was not measured for the state it is shown in. The user's rule
          * on this whole family is verbatim "MUST ONLY HAPPEN WHEN USER
          * REQUESTS IT!!".
          *
          * The six re-annotate sites the user reaches BY MOVING A CURSOR
          * (callback.c x5, scheduler.c swap_cursors) have always tested this
          * switch; this site and raw_read()'s tail (save.c, guard G1) did not.
          * The spelling is deliberately identical to those six so one grep finds
          * one gate shape.
          *
          * ⚠ WHAT IS DELIBERATELY *NOT* GATED: both arms of `xschem set
          * cursor2_x <t>`. That verb is a sentence somebody TYPED, naming a
          * time, which is what "the user requested it" means; it is also the
          * scripting verb and step S11's only road. See doc/claude/issues/
          * 0868-*.md and row V25 of tests/headless/test_op_annot.tcl, which pins
          * that decision so a later crew meets an explained row rather than what
          * looks like a missed gate.
          *
          * ⚠ THE USER'S ON-REQUEST DOOR IS THE NEW MODE, not this site. Gating
          * here without `xschem annotate_at` / cadence::annot_tran would leave a
          * user who cannot annotate a transient at all -- measured, with the box
          * off no gesture in the program re-measured the stale number.
          *
          * ⚠ ROW V23b GREPS THIS FUNCTION'S BODY for the switch name with C
          * comments STRIPPED, so this paragraph may name it freely and the code
          * line below is what the row actually counts. */
         if(tclgetboolvar("live_cursor2_backannotate") && (xctx->graph_flags & 4)) {
           backannotate_at_cursor_b_pos(r, gr);
         }
       }
     }
   }
   /* Cadence-style browse mode: a descended schematic opens READ-ONLY by default.
    * Off by default (descend_readonly=0 -> normal editable descend, unchanged);
    * cadence_style_rc turns it on. Only the descended level is forced: ascending
    * (go_back) reloads the parent via load_schematic, which restores the parent's
    * own writability. Edit it with Ctrl-2 / View > Toggle Read Only / the
    * "Descend schematic (edit)" context-menu item. */
   if(descend_ok && tclgetboolvar("descend_readonly")) {
     xctx->readonly = 1;
     set_modify(-1); /* refresh window title to show the read-only marker */
   }
   /* Re-arm the animated-highlight tick (issue 0034): the child reloaded into a fresh
    * context whose per-window animation tick is unarmed, and descend is not a highlight
    * MUTATION (the only thing that otherwise calls net_hilight_anim_update), so without
    * this a blink/marching-ants highlight freezes after descend. Cheap: the function
    * short-circuits to one boolean read when nothing animates. Arms every open window,
    * so the new-window descend path (open_sub_schematic) is covered too. */
   if(descend_ok) net_hilight_anim_update();
   /* Descending changes this window's current level, so a LINKED window one level away must be
    * re-synced from the new state (mirror of the go_back sync). Idempotent + cheap when no
    * linked window exists. issue 0073 child->parent. */
   if(descend_ok) net_hilight_sync_descend_windows();
   zoom_full(1, 0, 1 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
 }
 return descend_ok;
}

/*
 * what:
 * 1: ask gui user confirm if schematic modified
 * 2: do *NOT* reset window title
 */
void go_back(int what)
{
 int save_ok;
 int from_embedded_sym;
 int save_modified;
 char filename[PATH_MAX];
 char msg[PATH_MAX + 100];
 int prev_sch_type;
 int confirm = what & 1;
 int set_title = !(what & 2);

 save_ok=1;
 dbg(1,"go_back(): sch[xctx->currsch]=%s\n", xctx->sch[xctx->currsch]);
 prev_sch_type = xctx->netlist_type; /* if CAD_SYMBOL_ATTRS do not hilight_parent_pins */
 if(xctx->currsch>0)
 {
  /* if current sym/schematic is changed ask save before going up */
  if(xctx->modified)
  {
    if(confirm) {
      char as[PATH_MAX+100];
      /* name the cell being left, so the user knows which level this is about */
      my_snprintf(as, S(as), "ask_save {Schematic \"%s\" has unsaved changes.\n\nSave changes to this cell before returning to the upper level?}",
                  get_cell(xctx->sch[xctx->currsch], 0));
      tcleval(as);
      if(!strcmp(tclresult(), "yes") ) save_ok = save_schematic(xctx->sch[xctx->currsch], 0);
      else if(!strcmp(tclresult(), "") ) return;
      else remove_backup(); /* "No": discard this level's edits -> drop its cellName~ backup */
    }
    /* do not automatically save if confirm==0. Script developers should take care of this */
    /*
     * else {
     *   save_ok = save_schematic(xctx->sch[xctx->currsch], 0);
     * }
     */
  }
  if(save_ok==0) {
    fprintf(errfp, "go_back(): file opening for write failed! %s \n", xctx->current_name);
    my_snprintf(msg, S(msg), "file opening for write failed! %s", xctx->current_name);
    tcl_call("alert_", msg, NULL, "{}");
  }
  unselect_all(1);
  if(!tclgetboolvar("keep_symbols")) remove_symbols();
  from_embedded_sym=0;
  if(strstr(xctx->sch[xctx->currsch], ".xschem_embedded_")) {
    /* when returning after editing an embedded symbol
     * load immediately symbol definition before going back (.xschem_embedded... file will be lost)
     */
    load_sym_def(xctx->sch[xctx->currsch], NULL);
    from_embedded_sym=1;
  }
  my_free(_ALLOC_ID_, &xctx->sch[xctx->currsch]);
  if(xctx->portmap[xctx->currsch].table) str_hash_free(&xctx->portmap[xctx->currsch]);

  xctx->sch_path_hash[xctx->currsch] = 0;
  xctx->currsch--;
  my_free(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch].prop_ptr);
  my_free(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch].templ);
  my_free(_ALLOC_ID_, &xctx->hier_attr[xctx->currsch].sym_extra);
  xctx->hier_attr[xctx->currsch].auto_spec = 0;            /* issue 1201 */
  save_modified = xctx->modified; /* we propagate modified flag (cleared by load_schematic */
                            /* by default) to parent schematic if going back from embedded symbol */

  my_strncpy(filename, xctx->sch[xctx->currsch], S(filename)); /* logical cell name */
  /* If the parent has unsaved edits persisted in its cellName~.sch backup, load
   * those instead of the on-disk cellName.sch -- the buffer's logical identity
   * stays cellName and it returns flagged modified, so descending neither lost
   * edits nor required a save (load_backup_as does the content/identity split). A
   * clean parent (no ~) loads normally. Embedded-symbol returns keep the plain disk
   * path (deferred). doc/claude/specs/descend_hierarchy_in_memory.md */
  if(from_embedded_sym || !load_backup_as(filename, set_title)) {
    load_schematic(1, filename, set_title, 1);
  }
  /* if we are returning from a symbol created from a generator don't set modified flag on parent
   * as these symbols can not be edited / saved as embedded
   * xctx->sch_inst_number[xctx->currsch + 1] == -1 --> we came from an inst with no embed flag set */
  if(from_embedded_sym && xctx->sch_inst_number[xctx->currsch] != -1)
    xctx->modified=save_modified; /* to force ask save embedded sym in parent schematic */

  if(xctx->hilight_nets) {
    if(prev_sch_type != CAD_SYMBOL_ATTRS) hilight_parent_pins();
    propagate_hilights(1, 1, XINSERT_NOREPLACE);
  }
  xctx->xorigin=xctx->zoom_array[xctx->currsch].x;
  xctx->yorigin=xctx->zoom_array[xctx->currsch].y;
  xctx->zoom=xctx->zoom_array[xctx->currsch].zoom;
  xctx->mooz=1/xctx->zoom;

  change_linewidth(-1.);
  draw();
  /* Re-arm the animated-highlight tick after ascending (issue 0034): the parent reloaded
   * into a fresh context whose tick is unarmed; like descend, go_back is not a highlight
   * mutation, so a blink/marching-ants highlight would otherwise freeze on pop. */
  net_hilight_anim_update();
  /* Ascending re-maps this window's highlights to a new current level (hilight_parent_pins
   * above), so a LINKED window one level away must be re-synced from the new state -- e.g. a
   * secondary window that ascends back to depth-1 of the primary must now light the primary's
   * buried-net cue. go_back is not a highlight-mutation hook, so sync explicitly here. Cheap
   * (a no-op when no linked window exists). issue 0073 child->parent. */
  net_hilight_sync_descend_windows();

  /* Self-log at the core (issue 0071 atom 3): go_back() is 1:1 with the user verb
   * "return up one level" -- Ctrl-E, BackSpace and the context menu call it directly
   * (bypassing the scheduler branch), and the Tcl walk-ups (hierarchy_close,
   * descend_hierarchy, traversal) reach it as `xschem go_back`. Those walk-ups must
   * log too: their descends already log via descend_schematic's core self-log, so a
   * silent ascend would leave the replayed hierarchy level drifted. The currsch==0
   * no-op and the Save/No/Cancel "Cancel" path return before this -> no phantom.
   * Wrapper copies (context-menu table, Layer A csv) dedup via actionlog_cmd_logged.
   * doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md */
  if(what == 1) log_action("xschem go_back");
  else log_action("xschem go_back %d", what);

  dbg(1, "go_back(): current path: %s\n", xctx->sch_path[xctx->currsch]);
 }
}

void clear_schematic(int cancel, int symbol)
{
      if(cancel == 1) cancel=save(1, 0);
      if(cancel != -1) { /* -1 means user cancel save request */
        char name[PATH_MAX];
        /* The current buffer is being discarded (saved above, or the user declined
         * to save). Drop its cellName~.sch autosave backup so a leftover ~ on the
         * next open unambiguously means a crash, not an intentional discard. (A real
         * save already removed it; this no-ops then.) doc/claude/specs/...in_memory.md (B8) */
        remove_backup();
        xctx->currsch = 0;
        unselect_all(1);
        /* incremental_wire_reroute Phase II: if a fluid stretch gesture is still armed, tearing down
         * the buffer here must drop its move-scoped state -- else a later move_objects(RUBBER) could
         * restore the pre-clear geometry onto the cleared buffer (resurrecting deleted content), and
         * the deep copy / grabbed-coord array would leak. Frees the reroute snapshot (fluid_reroute_
         * discard) and the stretch scope (stretch_grabbed_xy, allocated by select_attached_nets). */
        fluid_reroute_discard();
        fluid_gesture_free();  /* D1 (Track D): close the Fluid_gesture START snapshot too (clear
                                * is a legitimate 3rd gesture-close point beside move END/ABORT) */
        xctx->stretch_select = 0;
        xctx->stretch_grabbed_n = 0;
        my_free(_ALLOC_ID_, &xctx->stretch_grabbed_xy);
        xctx->fluid_startsel_nid = 0;                   /* issue 0091: drop the user-selected id set */
        my_free(_ALLOC_ID_, &xctx->fluid_startsel_id);
        label_ride_free();  /* wire_label_ride.md S1: a teardown mid-gesture must drop the label
                             * rider set too, else a later move END would leash instance ids that
                             * belong to a different buffer. */
        remove_symbols();
        clear_drawing();
        /* next free untitled[-n] name, avoiding both files already in pwd_dir -- the very
         * directory the buffer path is composed from just below, which is what issue 0323
         * is about -- and names already open in other windows (issue 0056) */
        if(symbol == 1) {
          xctx->netlist_type = CAD_SYMBOL_ATTRS;
          set_tcl_netlist_type();
          get_unused_untitled_name(pwd_dir, 1, name, S(name));
        } else {
          xctx->netlist_type = CAD_SPICE_NETLIST;
          set_tcl_netlist_type();
          get_unused_untitled_name(pwd_dir, 0, name, S(name));
        }
        my_free(_ALLOC_ID_, &xctx->sch[xctx->currsch]);
        my_mstrcat(_ALLOC_ID_, &xctx->sch[xctx->currsch], pwd_dir, "/", name, NULL);
        my_strncpy(xctx->current_name, name, S(xctx->current_name));
        draw();
        set_modify(0);
        /* a fresh blank untitled buffer is always editable -- there is no file to
         * protect, so clear the read-only flag that may linger from a closed file
         * (e.g. returning to untitled after closing a read-only schematic) */
        xctx->readonly = 0;
        xctx->prep_hash_inst=0;
        xctx->prep_hash_wires=0;
        xctx->prep_net_structs=0;
        xctx->prep_hi_structs=0;
        if(has_x) {
          set_modify(-1);
        }
      }
}

#ifndef __unix__
/* Source: https://www.tcl.tk/man/tcl8.7/TclCmd/glob.htm */
/* backslash character has a special meaning to glob command,
so glob patterns containing Windows style path separators need special care.*/
void change_to_unix_fn(char* fn)
{
  size_t len, i, ii;
  len = strlen(fn);
  ii = 0;
  for (i = 0; i < len; ++i) {
    if (fn[i]!='\\') fn[ii++] = fn[i];
    else { fn[ii++] = '/'; if (fn[i + 1] == '\\') ++i; }
  }
}
#endif

/* selected: 0 -> all, 1 -> selected, 2 -> hilighted */
void calc_drawing_bbox(xRect *boundbox, int selected)
{
 xRect rect;
 int c, i;
 int count=0;
 #if HAS_CAIRO==1
 int customfont;
 #endif
 char *estr = NULL;

 xctx->show_hidden_texts = tclgetboolvar("show_hidden_texts");
 annot_show_sync_cache();
 boundbox->x1=-100;
 boundbox->x2=100;
 boundbox->y1=-100;
 boundbox->y2=100;
 if(selected != 2) for(c=0;c<cadlayers; ++c)
 {
  int hide_graphs = tclgetboolvar("hide_empty_graphs");
  int waves = (sch_waves_loaded() >= 0);

  for(i=0;i<xctx->lines[c]; ++i)
  {
   if(selected == 1 && !xctx->line[c][i].sel) continue;
   rect.x1=xctx->line[c][i].x1;
   rect.x2=xctx->line[c][i].x2;
   rect.y1=xctx->line[c][i].y1;
   rect.y2=xctx->line[c][i].y2;
   ++count;
   updatebbox(count,boundbox,&rect);
  }

  for(i=0;i<xctx->polygons[c]; ++i)
  {
    double x1=0., y1=0., x2=0., y2=0.;
    int k;
    if(selected == 1 && !xctx->poly[c][i].sel) continue;
    ++count;
    for(k=0; k<xctx->poly[c][i].points; ++k) {
      /* fprintf(errfp, "  poly: point %d: %.16g %.16g\n", k, pp[c][i].x[k], pp[c][i].y[k]); */
      if(k==0 || xctx->poly[c][i].x[k] < x1) x1 = xctx->poly[c][i].x[k];
      if(k==0 || xctx->poly[c][i].y[k] < y1) y1 = xctx->poly[c][i].y[k];
      if(k==0 || xctx->poly[c][i].x[k] > x2) x2 = xctx->poly[c][i].x[k];
      if(k==0 || xctx->poly[c][i].y[k] > y2) y2 = xctx->poly[c][i].y[k];
    }
    rect.x1=x1;rect.y1=y1;rect.x2=x2;rect.y2=y2;
    updatebbox(count,boundbox,&rect);
  }

  for(i=0;i<xctx->arcs[c]; ++i)
  {
    if(selected == 1 && !xctx->arc[c][i].sel) continue;
    arc_bbox(xctx->arc[c][i].x, xctx->arc[c][i].y, xctx->arc[c][i].r, xctx->arc[c][i].a, xctx->arc[c][i].b,
             &rect.x1, &rect.y1, &rect.x2, &rect.y2);
    ++count;
    updatebbox(count,boundbox,&rect);
  }

  for(i=0;i<xctx->rects[c]; ++i)
  {
   if(selected == 1 && !xctx->rect[c][i].sel) continue;
   /* skip graph objects if no datafile loaded */
   if(c == GRIDLAYER && xctx->rect[c][i].flags) {
     if(hide_graphs && !waves) continue;
   }
   rect.x1=xctx->rect[c][i].x1;
   rect.x2=xctx->rect[c][i].x2;
   rect.y1=xctx->rect[c][i].y1;
   rect.y2=xctx->rect[c][i].y2;
   ++count;
   updatebbox(count,boundbox,&rect);
  }
 }
 if(selected == 2 && xctx->hilight_nets) prepare_netlist_structs(0);
 for(i=0;i<xctx->wires; ++i)
 {
   double ov, y1, y2;
   if(selected == 1 && !xctx->wire[i].sel) continue;
   if(selected == 2) {
   /* const char *str;
    * str = get_tok_value(xctx->wire[i].prop_ptr, "lab",0);
    * if(!str[0] || !bus_hilight_hash_lookup(str, 0,XLOOKUP)) continue;
    */
     if(!xctx->hilight_nets || !xctx->wire[i].node ||
       !xctx->wire[i].node[0] || !bus_hilight_hash_lookup(xctx->wire[i].node, 0,XLOOKUP)) continue;
   }
   if(xctx->wire[i].bus == -1.0){
     ov = INT_BUS_WIDTH(xctx->lw)> xctx->cadhalfdotsize ? INT_BUS_WIDTH(xctx->lw) : CADHALFDOTSIZE;
     if(xctx->wire[i].y1 < xctx->wire[i].y2) { y1 = xctx->wire[i].y1-ov; y2 = xctx->wire[i].y2+ov; }
     else                        { y1 = xctx->wire[i].y1+ov; y2 = xctx->wire[i].y2-ov; }
   } else {
     ov = xctx->cadhalfdotsize;
     if(xctx->wire[i].y1 < xctx->wire[i].y2) { y1 = xctx->wire[i].y1-ov; y2 = xctx->wire[i].y2+ov; }
     else                        { y1 = xctx->wire[i].y1+ov; y2 = xctx->wire[i].y2-ov; }
   }
   rect.x1 = xctx->wire[i].x1-ov;
   rect.x2 = xctx->wire[i].x2+ov;
   rect.y1 = y1;
   rect.y2 = y2;
   ++count;
   updatebbox(count,boundbox,&rect);
 }
 if(has_x && selected != 2) {
   for(i=0;i<xctx->texts; ++i)
   {
     int no_of_lines;
     double longest_line;
     if(selected == 1 && !xctx->text[i].sel) continue;

     if(text_hidden(xctx->text[i].flags, TEXT_CTX_SCHEMATIC)) continue;
     #if HAS_CAIRO==1
     customfont = set_text_custom_font(&xctx->text[i]);
     #endif
     estr = my_expand(get_text_floater(i), tclgetintvar("tabstop"));
     if(text_bbox(estr, xctx->text[i].xscale,
           xctx->text[i].yscale,xctx->text[i].rot, xctx->text[i].flip,
           xctx->text[i].hcenter, xctx->text[i].vcenter,
           xctx->text[i].x0, xctx->text[i].y0,
           &rect.x1,&rect.y1, &rect.x2,&rect.y2, &no_of_lines, &longest_line) ) {
       ++count;
       updatebbox(count,boundbox,&rect);
     }
     my_free(_ALLOC_ID_, &estr);
     #if HAS_CAIRO==1
     if(customfont) {
       cairo_restore(xctx->cairo_ctx);
     }
     #endif
   }
 }
 for(i=0;i<xctx->instances; ++i)
 {
  char *type;
  Hilight_hashentry *entry;

  if(selected == 1 && !xctx->inst[i].sel) continue;

  if(selected == 2) {
    int found;
    type = (xctx->inst[i].ptr+ xctx->sym)->type;
    found = 0;
    if( type && IS_LABEL_OR_PIN(type)) {
      entry=bus_hilight_hash_lookup(xctx->inst[i].lab, 0, XLOOKUP );
      if(entry) found = 1;
    }
    if(!found &&  xctx->inst[i].color != -10000 ) {
      found = 1;
    }
    if(!found) continue;
  }

  /* cpu hog 20171206 */
  /*  symbol_bbox(i, &xctx->inst[i].x1, &xctx->inst[i].y1, &xctx->inst[i].x2, &xctx->inst[i].y2); */
  rect.x1=xctx->inst[i].x1;
  rect.y1=xctx->inst[i].y1;
  rect.x2=xctx->inst[i].x2;
  rect.y2=xctx->inst[i].y2;
  ++count;
  updatebbox(count,boundbox,&rect);
 }
}

/* flags: bit0: invoke change_linewidth()/xsetLineattributes, bit1: centered zoom */
void zoom_full(int dr, int sel, int flags, double shrink)
{
  xRect boundbox;
  double yzoom;
  double bboxw, bboxh, schw, schh;
  if(flags & 1) {
    if(xctx->change_lw) {
      xctx->lw = 1.;
    }
    xctx->areax1 = -2*INT_LINE_W(xctx->lw);
    xctx->areay1 = -2*INT_LINE_W(xctx->lw);
    xctx->areax2 = xctx->xrect[0].width+2*INT_LINE_W(xctx->lw);
    xctx->areay2 = xctx->xrect[0].height+2*INT_LINE_W(xctx->lw);
    xctx->areaw = xctx->areax2-xctx->areax1;
    xctx->areah = xctx->areay2 - xctx->areay1;
  }
  calc_drawing_bbox(&boundbox, sel);
  dbg(1, "zoom_full: %s, %g %g  %g %g\n",
      xctx->current_win_path, boundbox.x1, boundbox.y1, boundbox.x2, boundbox.y2);
  schw = xctx->areaw-4*INT_LINE_W(xctx->lw);
  schh = xctx->areah-4*INT_LINE_W(xctx->lw);
  bboxw = boundbox.x2-boundbox.x1;
  bboxh = boundbox.y2-boundbox.y1;
  xctx->zoom = bboxw / schw;
  yzoom = bboxh / schh;
  if(yzoom > xctx->zoom) xctx->zoom = yzoom;
  xctx->zoom /= shrink;

  xctx->mooz = 1 / xctx->zoom;
  if(flags & 2) {
    xctx->xorigin = -boundbox.x1 + (xctx->zoom * schw - bboxw) / 2; /* centered */
    xctx->yorigin = -boundbox.y1 + (xctx->zoom * schh - bboxh) / 2; /* centered */
  } else {
    xctx->xorigin = -boundbox.x1 + (1 - shrink) / 2 * xctx->zoom * schw;
    xctx->yorigin = -boundbox.y1 + xctx->zoom * schh - bboxh - (1 - shrink) / 2 * xctx->zoom * schh;
  }
  dbg(1, "zoom_full(): dr=%d sel=%d flags=%d areaw=%d, areah=%d\n", sel, dr, flags, xctx->areaw, xctx->areah);
  dbg(1, "zoom_full(): zoom=%g, xor=%g, yor=%g\n", xctx->zoom, xctx->xorigin, xctx->yorigin);
  dbg(1, "zoom_full(): current_name=%s\n", xctx->current_name);
  if(flags & 1) change_linewidth(-1.);
  /* we do this here since change_linewidth may not be called  if flags & 1 == 0*/
  set_dotsize_from_snap();
  if(dr && has_x) {
    draw();
    redraw_w_a_l_r_p_z_rubbers(1);
  }
}

void view_zoom(double z)
{
  double factor;
  factor = z!=0.0 ? z : CADZOOMSTEP;
  if(xctx->zoom<CADMINZOOM) return;
  xctx->zoom/= factor;
  xctx->mooz=1/xctx->zoom;
  xctx->xorigin=-xctx->mousex_snap+(xctx->mousex_snap+xctx->xorigin)/factor;
  xctx->yorigin=-xctx->mousey_snap+(xctx->mousey_snap+xctx->yorigin)/factor;
  change_linewidth(-1.);

  draw();
  redraw_w_a_l_r_p_z_rubbers(1);
}

void view_unzoom(double z)
{
  double factor;
  factor = z!=0.0 ? z : CADZOOMSTEP;
  if(xctx->zoom>CADMAXZOOM) return;
  xctx->zoom*= factor;
  xctx->mooz=1/xctx->zoom;
  /* 20181022 make unzoom and zoom symmetric  */
  /* keeping the mouse pointer as the origin */
  if(tclgetboolvar("unzoom_nodrift")) {
    xctx->xorigin=-xctx->mousex_snap+(xctx->mousex_snap+xctx->xorigin)*factor;
    xctx->yorigin=-xctx->mousey_snap+(xctx->mousey_snap+xctx->yorigin)*factor;
  } else {
    xctx->xorigin=xctx->xorigin+xctx->areaw*xctx->zoom*(1-1/factor)/2;
    xctx->yorigin=xctx->yorigin+xctx->areah*xctx->zoom*(1-1/factor)/2;
  }
  change_linewidth(-1.);
  draw();
  redraw_w_a_l_r_p_z_rubbers(1);
}

void set_viewport_size(int w, int h, double lw)
{
    xctx->xrect[0].x = 0;
    xctx->xrect[0].y = 0;
    xctx->xrect[0].width = (unsigned short)w;
    xctx->xrect[0].height = (unsigned short)h;
    xctx->areax2 = w+2*INT_LINE_W(lw);
    xctx->areay2 = h+2*INT_LINE_W(lw);
    xctx->areax1 = -2*INT_LINE_W(lw);
    xctx->areay1 = -2*INT_LINE_W(lw);
    xctx->lw = lw;
    xctx->areaw = xctx->areax2-xctx->areax1;
    xctx->areah = xctx->areay2-xctx->areay1;
}

void save_restore_zoom(int save, Zoom_info *zi)
{
  if(save) {
    dbg(1, "save_restore_zoom: save width= %d, height=%d\n", xctx->xrect[0].width, xctx->xrect[0].height);
    dbg(1, "                   zoom=%g\n", xctx->zoom);
    zi->savew = xctx->xrect[0].width;
    zi->saveh = xctx->xrect[0].height;
    zi->savelw = xctx->lw;
    zi->savexor = xctx->xorigin;
    zi->saveyor = xctx->yorigin;
    zi->savezoom = xctx->zoom;
  } else {
    xctx->xrect[0].x = 0;
    xctx->xrect[0].y = 0;
    xctx->xrect[0].width = (unsigned short)zi->savew;
    xctx->xrect[0].height = (unsigned short)zi->saveh;
    dbg(1, "save_restore_zoom: restore width= %d, height=%d\n", xctx->xrect[0].width, xctx->xrect[0].height);
    xctx->areax2 = zi->savew+2*INT_LINE_W(zi->savelw);
    xctx->areay2 = zi->saveh+2*INT_LINE_W(zi->savelw);
    xctx->areax1 = -2*INT_LINE_W(zi->savelw);
    xctx->areay1 = -2*INT_LINE_W(zi->savelw);
    xctx->lw = zi->savelw;
    xctx->areaw = xctx->areax2-xctx->areax1;
    xctx->areah = xctx->areay2-xctx->areay1;
    xctx->xorigin = zi->savexor;
    xctx->yorigin = zi->saveyor;
    xctx->zoom = zi->savezoom;
    xctx->mooz = 1 / zi->savezoom;
    dbg(1, "                   zoom=%g\n", xctx->zoom);
  }
}

void zoom_box(double x1, double y1, double x2, double y2, double factor)
{
  double yy1;
  if(factor == 0.) factor = 1.;
  RECTORDER(x1,y1,x2,y2);
  xctx->xorigin=-x1;xctx->yorigin=-y1;
  xctx->zoom=(x2-x1)/(xctx->areaw-4*INT_LINE_W(xctx->lw));
  yy1=(y2-y1)/(xctx->areah-4*INT_LINE_W(xctx->lw));
  if(yy1>xctx->zoom) xctx->zoom=yy1;
  xctx->zoom*= factor;
  xctx->mooz=1/xctx->zoom;
  xctx->xorigin=xctx->xorigin+xctx->areaw*xctx->zoom*(1-1/factor)/2;
  xctx->yorigin=xctx->yorigin+xctx->areah*xctx->zoom*(1-1/factor)/2;
  dbg(1, "zoom_box(): zoom=%g\n", xctx->zoom);
}

void zoom_rectangle(int what)
{
  if( (what & START) )
  {
    xctx->nl_x1=xctx->nl_x2=xctx->mousex_snap;xctx->nl_y1=xctx->nl_y2=xctx->mousey_snap;
    xctx->ui_state |= STARTZOOM;
  }
  if( what & END)
  {
    xctx->ui_state &= ~STARTZOOM;
    RECTORDER(xctx->nl_x1,xctx->nl_y1,xctx->nl_x2,xctx->nl_y2);
    drawtemprect(xctx->gctiled, NOW, xctx->nl_xx1, xctx->nl_yy1, xctx->nl_xx2, xctx->nl_yy2);
    if( xctx->nl_x1 != xctx->nl_x2 || xctx->nl_y1 != xctx->nl_y2) {
      xctx->xorigin = -xctx->nl_x1; xctx->yorigin = -xctx->nl_y1;
      xctx->zoom = (xctx->nl_x2 - xctx->nl_x1) / (xctx->areaw - 4 * INT_LINE_W(xctx->lw));
      xctx->nl_yy1=(xctx->nl_y2 - xctx->nl_y1) / (xctx->areah - 4 * INT_LINE_W(xctx->lw));
      if(xctx->nl_yy1 > xctx->zoom) xctx->zoom = xctx->nl_yy1;
      xctx->mooz = 1 / xctx->zoom;
      change_linewidth(-1.);
      draw();
      redraw_w_a_l_r_p_z_rubbers(1);
      dbg(1, "zoom_rectangle(): coord: %.16g %.16g %.16g %.16g zoom=%.16g\n",
        xctx->nl_x1, xctx->nl_y1, xctx->mousex_snap, xctx->mousey_snap, xctx->zoom);
    }
  }
  if(what & RUBBER)
  {
    xctx->nl_xx1=xctx->nl_x1;xctx->nl_yy1=xctx->nl_y1;xctx->nl_xx2=xctx->nl_x2;xctx->nl_yy2=xctx->nl_y2;
    RECTORDER(xctx->nl_xx1,xctx->nl_yy1,xctx->nl_xx2,xctx->nl_yy2);
    drawtemprect(xctx->gctiled,NOW, xctx->nl_xx1,xctx->nl_yy1,xctx->nl_xx2,xctx->nl_yy2);
    xctx->nl_x2=xctx->mousex_snap;xctx->nl_y2=xctx->mousey_snap;


    /*  20171211 update selected objects while dragging */
    rebuild_selected_array();
    bbox(START,0.0, 0.0, 0.0, 0.0);
    bbox(ADD, xctx->nl_xx1, xctx->nl_yy1, xctx->nl_xx2, xctx->nl_yy2);
    bbox(SET,0.0, 0.0, 0.0, 0.0);
    draw_selection(xctx->gc[SELLAYER], 0);
    bbox(END,0.0, 0.0, 0.0, 0.0);

    xctx->nl_xx1=xctx->nl_x1;xctx->nl_yy1=xctx->nl_y1;xctx->nl_xx2=xctx->nl_x2;xctx->nl_yy2=xctx->nl_y2;
    RECTORDER(xctx->nl_xx1,xctx->nl_yy1,xctx->nl_xx2,xctx->nl_yy2);
    /* RUBBER|CLEAR: erase only -- see new_polygon() (abort_shape_draw(), callback.c). The
     * draw_selection() overlay above is NOT skipped: the tiled erase wipes the SELLAYER highlight
     * of everything inside the band bbox, and restoring it is not part of the band. */
    if(!(what & CLEAR)) {
      drawtemprect(xctx->gc[SELLAYER], NOW, xctx->nl_xx1,xctx->nl_yy1,xctx->nl_xx2,xctx->nl_yy2);
    }
  }
}

#define STORE
void draw_stuff(void)
{
   double x1,y1,w,h, x2, y2;
   int i;
   int n = 200000;
   clear_drawing();
   view_unzoom(40);
   #ifndef STORE
   n /= (cadlayers - 4);
   for(xctx->rectcolor = 4; xctx->rectcolor < cadlayers; xctx->rectcolor++) {
   #else
   #endif
     for(i = 0; i < n; ++i)
      {
       w=(xctx->areaw*xctx->zoom/800) * rand() / (RAND_MAX+1.0);
       h=(xctx->areah*xctx->zoom/80) * rand() / (RAND_MAX+1.0);
       x1=(xctx->areaw*xctx->zoom) * rand() / (RAND_MAX+1.0)-xctx->xorigin;
       y1=(xctx->areah*xctx->zoom) * rand() / (RAND_MAX+1.0)-xctx->yorigin;
       x2=x1+w;
       y2=y1+h;
       ORDER(x1,y1,x2,y2);
       #ifdef STORE
       xctx->rectcolor = (int) (16.0*rand()/(RAND_MAX+1.0))+4;
       storeobject(-1, x1, y1, x2, y2, xRECT,xctx->rectcolor, 0, NULL);
       #else
       drawtemprect(xctx->gc[xctx->rectcolor], ADD, x1, y1, x2, y2);
       #endif
     }

     for(i = 0; i < n; ++i)
      {
       w=(xctx->areaw*xctx->zoom/80) * rand() / (RAND_MAX+1.0);
       h=(xctx->areah*xctx->zoom/800) * rand() / (RAND_MAX+1.0);
       x1=(xctx->areaw*xctx->zoom) * rand() / (RAND_MAX+1.0)-xctx->xorigin;
       y1=(xctx->areah*xctx->zoom) * rand() / (RAND_MAX+1.0)-xctx->yorigin;
       x2=x1+w;
       y2=y1+h;
       ORDER(x1,y1,x2,y2);
       #ifdef STORE
       xctx->rectcolor = (int) (16.0*rand()/(RAND_MAX+1.0))+4;
       storeobject(-1, x1, y1, x2, y2,xRECT,xctx->rectcolor, 0, NULL);
       #else
       drawtemprect(xctx->gc[xctx->rectcolor], ADD, x1, y1, x2, y2);
       #endif
     }

     for(i = 0; i < n; ++i)
     {
       w=xctx->zoom * rand() / (RAND_MAX+1.0);
       h=w;
       x1=(xctx->areaw*xctx->zoom) * rand() / (RAND_MAX+1.0)-xctx->xorigin;
       y1=(xctx->areah*xctx->zoom) * rand() / (RAND_MAX+1.0)-xctx->yorigin;
       x2=x1+w;
       y2=y1+h;
       RECTORDER(x1,y1,x2,y2);
       #ifdef STORE
       xctx->rectcolor = (int) (16.0*rand()/(RAND_MAX+1.0))+4;
       storeobject(-1, x1, y1, x2, y2,xRECT,xctx->rectcolor, 0, NULL);
       #else
       drawtemprect(xctx->gc[xctx->rectcolor], ADD, x1, y1, x2, y2);
       #endif
     }
   #ifndef STORE
     drawtemprect(xctx->gc[xctx->rectcolor], END, 0.0, 0.0, 0.0, 0.0);
   }
   #else
   draw();
   #endif
}

static void restore_selection(double x1, double y1, double x2, double y2)
{
  double xx1,yy1,xx2,yy2;
  int intlw = 2 * INT_LINE_W(xctx->lw) + (int)xctx->cadhalfdotsize;
  xx1 = x1; yy1 = y1; xx2 = x2; yy2 = y2;
  RECTORDER(xx1,yy1,xx2,yy2);
  rebuild_selected_array();
  if(!xctx->lastsel) return;
  bbox(START,0.0, 0.0, 0.0, 0.0);
  bbox(ADD, xx1 - intlw, yy1 - intlw, xx2 + intlw, yy2 + intlw);
  bbox(SET,0.0, 0.0, 0.0, 0.0);
  draw_selection(xctx->gc[SELLAYER], 0);
  bbox(END,0.0, 0.0, 0.0, 0.0);
}

void new_wire(int what, double mx_snap, double my_snap)
{
  int modified = 0;
  double nl_xx1, nl_yy1, nl_xx2, nl_yy2;
  if( (what & PLACE) ) {
    if( (xctx->ui_state & STARTWIRE) && (xctx->nl_x1!=xctx->nl_x2 || xctx->nl_y1!=xctx->nl_y2) ) {
      xctx->push_undo();
      if(xctx->manhattan_lines & 1) {
        if(xctx->nl_x2!=xctx->nl_x1) {
          nl_xx1 = xctx->nl_x1; nl_yy1 = xctx->nl_y1;
          nl_xx2 = xctx->nl_x2; nl_yy2 = xctx->nl_y2;
          ORDER(nl_xx1,nl_yy1,nl_xx2,nl_yy1);
          storeobject(-1, nl_xx1,nl_yy1,nl_xx2,nl_yy1,WIRE,0,0,NULL);
          /* action-log Layer C (spec section 2): every gesture path (release,
           * intermediate click, persistent mode, infix gui, context menu)
           * places its segment through these storeobject calls, so this is the
           * single recording point; one line per stored segment (manhattan
           * modes place up to two). Replaying `xschem wire ...` stores
           * directly in the scheduler, NOT through new_wire -> no double-log. */
          log_action("xschem wire %.16g %.16g %.16g %.16g", nl_xx1, nl_yy1, nl_xx2, nl_yy1);
          modified = 1;
          hash_wire(XINSERT, xctx->wires-1, 1);
          drawline(WIRELAYER,NOW, nl_xx1,nl_yy1,nl_xx2,nl_yy1, 0.0, 0, NULL);
        }
        if(xctx->nl_y2!=xctx->nl_y1) {
          nl_xx1 = xctx->nl_x1; nl_yy1 = xctx->nl_y1;
          nl_xx2 = xctx->nl_x2; nl_yy2 = xctx->nl_y2;
          ORDER(nl_xx2,nl_yy1,nl_xx2,nl_yy2);
          storeobject(-1, nl_xx2,nl_yy1,nl_xx2,nl_yy2,WIRE,0,0,NULL);
          log_action("xschem wire %.16g %.16g %.16g %.16g", nl_xx2, nl_yy1, nl_xx2, nl_yy2);
          modified = 1;
          hash_wire(XINSERT, xctx->wires-1, 1);
          drawline(WIRELAYER,NOW, nl_xx2,nl_yy1,nl_xx2,nl_yy2, 0.0, 0, NULL);
        }
      } else if(xctx->manhattan_lines & 2) {
        if(xctx->nl_y2!=xctx->nl_y1) {
          nl_xx1 = xctx->nl_x1; nl_yy1 = xctx->nl_y1;
          nl_xx2 = xctx->nl_x2; nl_yy2 = xctx->nl_y2;
          ORDER(nl_xx1,nl_yy1,nl_xx1,nl_yy2);
          storeobject(-1, nl_xx1,nl_yy1,nl_xx1,nl_yy2,WIRE,0,0,NULL);
          log_action("xschem wire %.16g %.16g %.16g %.16g", nl_xx1, nl_yy1, nl_xx1, nl_yy2);
          modified = 1;
          hash_wire(XINSERT, xctx->wires-1, 1);
          drawline(WIRELAYER,NOW, nl_xx1,nl_yy1,nl_xx1,nl_yy2, 0.0, 0, NULL);
        }
        if(xctx->nl_x2!=xctx->nl_x1) {
          nl_xx1=xctx->nl_x1;nl_yy1=xctx->nl_y1;
          nl_xx2=xctx->nl_x2;nl_yy2=xctx->nl_y2;
          ORDER(nl_xx1,nl_yy2,nl_xx2,nl_yy2);
          storeobject(-1, nl_xx1,nl_yy2,nl_xx2,nl_yy2,WIRE,0,0,NULL);
          log_action("xschem wire %.16g %.16g %.16g %.16g", nl_xx1, nl_yy2, nl_xx2, nl_yy2);
          modified = 1;
          hash_wire(XINSERT, xctx->wires-1, 1);
          drawline(WIRELAYER,NOW, nl_xx1,nl_yy2,nl_xx2,nl_yy2, 0.0, 0, NULL);
        }
      } else {
        nl_xx1 = xctx->nl_x1; nl_yy1 = xctx->nl_y1;
        nl_xx2 = xctx->nl_x2; nl_yy2 = xctx->nl_y2;
        ORDER(nl_xx1,nl_yy1,nl_xx2,nl_yy2);
        storeobject(-1, nl_xx1,nl_yy1,nl_xx2,nl_yy2,WIRE,0,0,NULL);
        log_action("xschem wire %.16g %.16g %.16g %.16g", nl_xx1, nl_yy1, nl_xx2, nl_yy2);
        modified = 1;
        hash_wire(XINSERT, xctx->wires-1, 1);
        drawline(WIRELAYER,NOW, nl_xx1,nl_yy1,nl_xx2,nl_yy2, 0.0, 0, NULL);
      }
      xctx->prep_hi_structs = 0;
      /* W3: a freshly drawn wire may pass under existing pins/net-labels -> split it into
       * inter-attachment segments (maintain = split + pin-aware merge). Gated on autotrim_wires.
       * See doc/claude/specs/wire_segment_splitting.md (W3). */
      if(tclgetboolvar("autotrim_wires")) maintain_wire_segments();
      prepare_netlist_structs(0); /* since xctx->prep_hi_structs==0, do a delete_netlist_structs() first,
                                   * this clears both xctx->prep_hi_structs and xctx->prep_net_structs. */
      if(xctx->hilight_nets) {
        propagate_hilights(1, 1, XINSERT_NOREPLACE);
      }
      draw();
      /* draw_hilight_net(1);*/  /* for updating connection bubbles on hilight nets */
    }
    xctx->nl_x1 = xctx->nl_x2=mx_snap; xctx->nl_y1 = xctx->nl_y2=my_snap;
    xctx->ui_state |= STARTWIRE;
    if(modified) set_modify(1);
  }
  if( what & END) {
    xctx->ui_state &= ~STARTWIRE;
  }
  if( (what & RUBBER)  ) {
    drawtemp_manhattanline(xctx->gctiled, NOW, xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2, 0);
    restore_selection(xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2);
    xctx->nl_x2 = mx_snap; xctx->nl_y2 = my_snap;
    if(!(what & CLEAR)) {
      drawtemp_manhattanline(xctx->gc[WIRELAYER], NOW, xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2, 0);
    }
  }
}

void change_layer()
{
  int k, n, type, c;
  double x1,y1,x2,y2, a, b, r;
  int modified = 0;

   if(xctx->lastsel) xctx->push_undo();
   for(k=0;k<xctx->lastsel; ++k)
   {
     n=xctx->sel_array[k].n;
     type=xctx->sel_array[k].type;
     c=xctx->sel_array[k].col;
     if(type==LINE && xctx->line[c][n].sel==SELECTED) {
       x1 = xctx->line[c][n].x1;
       y1 = xctx->line[c][n].y1;
       x2 = xctx->line[c][n].x2;
       y2 = xctx->line[c][n].y2;
       storeobject(-1, x1,y1,x2,y2,LINE,xctx->rectcolor, 0, xctx->line[c][n].prop_ptr);
       modified = 1;
     }
     if(type==ARC && xctx->arc[c][n].sel==SELECTED) {
       x1 = xctx->arc[c][n].x;
       y1 = xctx->arc[c][n].y;
       r = xctx->arc[c][n].r;
       a = xctx->arc[c][n].a;
       b = xctx->arc[c][n].b;
       store_arc(-1, x1, y1, r, a, b, xctx->rectcolor, 0, xctx->arc[c][n].prop_ptr);
     }
     if(type==POLYGON && xctx->poly[c][n].sel==SELECTED) {
        store_poly(-1, xctx->poly[c][n].x, xctx->poly[c][n].y,
                       xctx->poly[c][n].points, xctx->rectcolor, 0, xctx->poly[c][n].prop_ptr);
     }
     else if(type==xRECT && xctx->rect[c][n].sel==SELECTED) {
       x1 = xctx->rect[c][n].x1;
       y1 = xctx->rect[c][n].y1;
       x2 = xctx->rect[c][n].x2;
       y2 = xctx->rect[c][n].y2;
       storeobject(-1, x1,y1,x2,y2,xRECT,xctx->rectcolor, 0, xctx->rect[c][n].prop_ptr);
       modified = 1;
     }
     else if(type==xTEXT && xctx->text[n].sel==SELECTED) {
       if(xctx->rectcolor != xctx->text[n].layer) {
         char *p;
         my_strdup2(_ALLOC_ID_, &xctx->text[n].prop_ptr,
           subst_token(xctx->text[n].prop_ptr, "layer", dtoa(xctx->rectcolor) ));
         xctx->text[n].layer = xctx->rectcolor;
         p = xctx->text[n].prop_ptr;
         while(*p) {
           if(*p == '\n') *p = ' ';
           ++p;
         }
         modified = 1;
       }
     }
   }
   if(xctx->lastsel) delete_only_rect_line_arc_poly();
   unselect_all(1);
   if(modified) set_modify(1);
}

void new_arc(int what, double sweep, double mousex_snap, double mousey_snap)
{
  if(what & PLACE) {
    xctx->nl_state=0;
    xctx->nl_r = -1.;
    xctx->nl_sweep_angle=sweep;
    xctx->nl_xx1 = xctx->nl_xx2 = xctx->nl_x1 = xctx->nl_x2 = xctx->nl_x3 = mousex_snap;
    xctx->nl_yy1 = xctx->nl_yy2 = xctx->nl_y1 = xctx->nl_y2 = xctx->nl_y3 = mousey_snap;
    xctx->ui_state |= STARTARC;
  }
  if(what & SET) {
    if(xctx->nl_state==0) {
      xctx->nl_x2 = xctx->mousex_snap;
      xctx->nl_y2 = xctx->mousey_snap;
      drawtempline(xctx->gctiled, NOW, xctx->nl_xx1,xctx->nl_yy1,xctx->nl_xx2,xctx->nl_yy2);
      restore_selection(xctx->nl_xx1, xctx->nl_yy1, xctx->nl_xx2, xctx->nl_yy2);
      xctx->nl_state=1;
    } else if(xctx->nl_state==1) {
      xctx->nl_x3 = xctx->mousex_snap;
      xctx->nl_y3 = xctx->mousey_snap;
      arc_3_points(xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2,
          xctx->nl_x3, xctx->nl_y3, &xctx->nl_x, &xctx->nl_y, &xctx->nl_r, &xctx->nl_a, &xctx->nl_b);
      if(xctx->nl_sweep_angle==360.) xctx->nl_b=360.;
      if(xctx->nl_r>0.) {
        xctx->push_undo();
        drawarc(xctx->rectcolor, NOW, xctx->nl_x, xctx->nl_y, xctx->nl_r, xctx->nl_a, xctx->nl_b, 0, 0.0, 0);
        store_arc(-1, xctx->nl_x, xctx->nl_y, xctx->nl_r, xctx->nl_a, xctx->nl_b, xctx->rectcolor, 0, NULL);
        log_action("xschem arc %.16g %.16g %.16g %.16g %.16g %d",
          xctx->nl_x, xctx->nl_y, xctx->nl_r, xctx->nl_a, xctx->nl_b, xctx->rectcolor);
        set_modify(1);
      }
      xctx->ui_state &= ~STARTARC;
      xctx->nl_state=0;
    }
  }
  if(what & RUBBER) {
    if(xctx->nl_state==0) {
      drawtempline(xctx->gctiled, NOW, xctx->nl_xx1,xctx->nl_yy1,xctx->nl_xx2,xctx->nl_yy2);
      restore_selection(xctx->nl_xx1, xctx->nl_yy1, xctx->nl_xx2, xctx->nl_yy2);
      xctx->nl_x2 = xctx->mousex_snap;xctx->nl_y2 = xctx->mousey_snap;
      xctx->nl_xx1 = xctx->nl_x1; /* This **is** needed. Don't remove! */
      xctx->nl_yy1 = xctx->nl_y1; /* This **is** needed. Don't remove! */
      xctx->nl_xx2 = xctx->mousex_snap;
      xctx->nl_yy2 = xctx->mousey_snap;
      ORDER(xctx->nl_xx1,xctx->nl_yy1,xctx->nl_xx2,xctx->nl_yy2);
      /* RUBBER|CLEAR: erase only -- see new_polygon() above (abort_shape_draw(), callback.c) */
      if(!(what & CLEAR)) {
        drawtempline(xctx->gc[SELLAYER], NOW, xctx->nl_xx1,xctx->nl_yy1,xctx->nl_xx2,xctx->nl_yy2);
      }
    }
    else if(xctx->nl_state==1) {
      xctx->nl_x3 = xctx->mousex_snap;
      xctx->nl_y3 = xctx->mousey_snap;
      if(xctx->nl_r>0.)
          drawtemparc(xctx->gctiled, NOW, xctx->nl_x, xctx->nl_y, xctx->nl_r, xctx->nl_a, xctx->nl_b);
      arc_3_points(xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2,
          xctx->nl_x3, xctx->nl_y3, &xctx->nl_x, &xctx->nl_y, &xctx->nl_r, &xctx->nl_a, &xctx->nl_b);
      restore_selection(xctx->nl_xx1, xctx->nl_yy1, xctx->nl_xx2, xctx->nl_yy2);
      arc_bbox(xctx->nl_x, xctx->nl_y, xctx->nl_r, xctx->nl_a, xctx->nl_b,
                &xctx->nl_xx1, &xctx->nl_yy1, &xctx->nl_xx2, &xctx->nl_yy2);
      if(xctx->nl_sweep_angle==360.) xctx->nl_b=360.;
      /* RUBBER|CLEAR: erase only -- see new_polygon() (abort_shape_draw(), callback.c) */
      if(!(what & CLEAR) && xctx->nl_r>0.) drawtemparc(xctx->gc[xctx->rectcolor], NOW,
           xctx->nl_x, xctx->nl_y, xctx->nl_r, xctx->nl_a, xctx->nl_b);
    }
  }
}

void new_line(int what, double mx_snap, double my_snap)
{
  int modified = 0;
  double nl_xx1, nl_yy1, nl_xx2, nl_yy2;

  if( (what & PLACE) )
  {
    if( (xctx->nl_x1!=xctx->nl_x2 || xctx->nl_y1!=xctx->nl_y2) && (xctx->ui_state & STARTLINE) )
    {
      xctx->push_undo();
      if(xctx->manhattan_lines & 1) {
        if(xctx->nl_x2!=xctx->nl_x1) {
          nl_xx1 = xctx->nl_x1; nl_yy1 = xctx->nl_y1;
          nl_xx2 = xctx->nl_x2; nl_yy2 = xctx->nl_y2;
          ORDER(nl_xx1,nl_yy1,nl_xx2,nl_yy1);
          storeobject(-1, nl_xx1,nl_yy1,nl_xx2,nl_yy1,LINE,xctx->rectcolor,0,NULL);
          log_action("xschem line %.16g %.16g %.16g %.16g", nl_xx1, nl_yy1, nl_xx2, nl_yy1);
          modified = 1;
          drawline(xctx->rectcolor,NOW, nl_xx1,nl_yy1,nl_xx2,nl_yy1, 0.0, 0, NULL);
        }
        if(xctx->nl_y2!=xctx->nl_y1) {
          nl_xx1 = xctx->nl_x1; nl_yy1 = xctx->nl_y1;
          nl_xx2 = xctx->nl_x2; nl_yy2 = xctx->nl_y2;
          ORDER(nl_xx2,nl_yy1,nl_xx2,nl_yy2);
          storeobject(-1, nl_xx2,nl_yy1,nl_xx2,nl_yy2,LINE,xctx->rectcolor,0,NULL);
          log_action("xschem line %.16g %.16g %.16g %.16g", nl_xx2, nl_yy1, nl_xx2, nl_yy2);
          modified = 1;
          drawline(xctx->rectcolor,NOW, nl_xx2,nl_yy1,nl_xx2,nl_yy2, 0.0, 0, NULL);
        }
      } else if(xctx->manhattan_lines & 2) {
        if(xctx->nl_y2!=xctx->nl_y1) {
          nl_xx1 = xctx->nl_x1; nl_yy1 = xctx->nl_y1;
          nl_xx2 = xctx->nl_x2; nl_yy2 = xctx->nl_y2;
          ORDER(nl_xx1,nl_yy1,nl_xx1,nl_yy2);
          storeobject(-1, nl_xx1,nl_yy1,nl_xx1,nl_yy2,LINE,xctx->rectcolor,0,NULL);
          log_action("xschem line %.16g %.16g %.16g %.16g", nl_xx1, nl_yy1, nl_xx1, nl_yy2);
          modified = 1;
          drawline(xctx->rectcolor,NOW, nl_xx1,nl_yy1,nl_xx1,nl_yy2, 0.0, 0, NULL);
        }
        if(xctx->nl_x2!=xctx->nl_x1) {
          nl_xx1=xctx->nl_x1;nl_yy1=xctx->nl_y1;
          nl_xx2=xctx->nl_x2;nl_yy2=xctx->nl_y2;
          ORDER(nl_xx1,nl_yy2,nl_xx2,nl_yy2);
          storeobject(-1, nl_xx1,nl_yy2,nl_xx2,nl_yy2,LINE,xctx->rectcolor,0,NULL);
          log_action("xschem line %.16g %.16g %.16g %.16g", nl_xx1, nl_yy2, nl_xx2, nl_yy2);
          modified = 1;
          drawline(xctx->rectcolor,NOW, nl_xx1,nl_yy2,nl_xx2,nl_yy2, 0.0, 0, NULL);
        }
      } else {
        nl_xx1 = xctx->nl_x1; nl_yy1 = xctx->nl_y1;
        nl_xx2 = xctx->nl_x2; nl_yy2 = xctx->nl_y2;
        ORDER(nl_xx1,nl_yy1,nl_xx2,nl_yy2);
        storeobject(-1, nl_xx1,nl_yy1,nl_xx2,nl_yy2,LINE,xctx->rectcolor,0,NULL);
        log_action("xschem line %.16g %.16g %.16g %.16g", nl_xx1, nl_yy1, nl_xx2, nl_yy2);
        modified = 1;
        drawline(xctx->rectcolor,NOW, nl_xx1,nl_yy1,nl_xx2,nl_yy2, 0.0, 0, NULL);
      }
      if(modified) set_modify(1);
    }
    xctx->nl_x1=xctx->nl_x2=mx_snap;xctx->nl_y1=xctx->nl_y2=my_snap;
    xctx->ui_state |= STARTLINE;
  }
  if( what & END)
  {
    xctx->ui_state &= ~STARTLINE;
  }
  if( (what & RUBBER)  ) {
    drawtemp_manhattanline(xctx->gctiled, NOW, xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2, 0);
    restore_selection(xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2);
    xctx->nl_x2 = mx_snap; xctx->nl_y2 = my_snap;
    if(!(what & CLEAR)) {
      drawtemp_manhattanline(xctx->gc[xctx->rectcolor], NOW, xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2, 0);
    }
  }
}

void new_rect(int what, double mousex_snap, double mousey_snap)
{
  int modified = 0;
  double nl_xx1, nl_yy1, nl_xx2, nl_yy2;
  if( (what & PLACE) )
  {
   if( (xctx->nl_x1!=xctx->nl_x2 || xctx->nl_y1!=xctx->nl_y2) && (xctx->ui_state & STARTRECT) )
   {
    int save_draw;
    RECTORDER(xctx->nl_x1,xctx->nl_y1,xctx->nl_x2,xctx->nl_y2);
    xctx->push_undo();
    drawrect(xctx->rectcolor, NOW, xctx->nl_x1,xctx->nl_y1,xctx->nl_x2,xctx->nl_y2, 0.0, 0, -1, -1);
    save_draw = xctx->draw_window;
    xctx->draw_window = 1;
    /* draw fill pattern even in xcopyarea mode */
    filledrect(xctx->rectcolor, NOW, xctx->nl_x1,xctx->nl_y1,xctx->nl_x2,xctx->nl_y2, 1, -1, -1);
    xctx->draw_window = save_draw;
    storeobject(-1, xctx->nl_x1,xctx->nl_y1,xctx->nl_x2,xctx->nl_y2,xRECT,xctx->rectcolor, 0, NULL);
    log_action("xschem rect %.16g %.16g %.16g %.16g",
      xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2);
    modified = 1;
   }
   xctx->nl_x1 = xctx->nl_x2 = mousex_snap;xctx->nl_y1 = xctx->nl_y2 = mousey_snap;
   xctx->ui_state |= STARTRECT;
   if(modified) set_modify(1);
  }
  if( what & END)
  {
   xctx->ui_state &= ~STARTRECT;
  }
  if(what & RUBBER)
  {
   nl_xx1 = xctx->nl_x1;nl_yy1 = xctx->nl_y1;nl_xx2 = xctx->nl_x2;nl_yy2 = xctx->nl_y2;
   RECTORDER(nl_xx1,nl_yy1,nl_xx2,nl_yy2);
   drawtemprect(xctx->gctiled,NOW, nl_xx1,nl_yy1,nl_xx2,nl_yy2);
   restore_selection(xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2);
   xctx->nl_x2 = xctx->mousex_snap;xctx->nl_y2 = xctx->mousey_snap;
   nl_xx1 = xctx->nl_x1;nl_yy1 = xctx->nl_y1;nl_xx2 = xctx->nl_x2;nl_yy2 = xctx->nl_y2;
   RECTORDER(nl_xx1,nl_yy1,nl_xx2,nl_yy2);
   /* RUBBER|CLEAR: erase only, no re-stroke -- see the same guard in new_wire()/new_line() and the
    * reason in new_polygon() above (abort_shape_draw(), callback.c). */
   if(!(what & CLEAR)) {
     drawtemprect(xctx->gc[xctx->rectcolor], NOW, nl_xx1,nl_yy1,nl_xx2,nl_yy2);
   }
  }
}


void new_polygon(int what, double mousex_snap, double mousey_snap)
{
   if( what & PLACE ) xctx->nl_points=0; /*  start new polygon placement */

   if(xctx->nl_points >= xctx->nl_maxpoints-1) {  /*  check storage for 2 xctx->nl_points */
     xctx->nl_maxpoints = (1+xctx->nl_points / CADCHUNKALLOC) * CADCHUNKALLOC;
     my_realloc(_ALLOC_ID_, &xctx->nl_polyx, sizeof(double)*xctx->nl_maxpoints);
     my_realloc(_ALLOC_ID_, &xctx->nl_polyy, sizeof(double)*xctx->nl_maxpoints);
   }
   if( what & PLACE )
   {
     /* fprintf(errfp, "new_poly: PLACE, nl_points=%d\n", xctx->nl_points); */
     xctx->nl_polyy[xctx->nl_points]=mousey_snap;
     xctx->nl_polyx[xctx->nl_points]=mousex_snap;
     xctx->nl_points++;
     xctx->nl_polyx[xctx->nl_points]=xctx->nl_polyx[xctx->nl_points-1]; /* prepare next point for rubber */
     xctx->nl_polyy[xctx->nl_points] = xctx->nl_polyy[xctx->nl_points-1];
     /* fprintf(errfp, "added point: %.16g %.16g\n", xctx->nl_polyx[xctx->nl_points-1],
         xctx->nl_polyy[xctx->nl_points-1]); */
     xctx->nl_x1=xctx->nl_x2=mousex_snap;xctx->nl_y1=xctx->nl_y2=mousey_snap;
     xctx->ui_state |= STARTPOLYGON;
     /* ISSUE 0270 -- the set_modify(1) that used to sit HERE has moved to the commit branch, beside
      * store_poly(). It was the polygon's ONLY modify write, and it fired at the ARM: `xschem
      * polygon gui` on a clean document reported the buffer dirty with nothing stored (measured,
      * modified 0 -> 1). Harmless while the only exit was ESC (which COMMITS the polygon, so the
      * flag became true one call later), but abort_shape_draw() (callback.c) can now abandon the
      * gesture, and a teardown that leaves a false `modified` is the issue 0244 class. Moving it
      * rather than deleting it: the commit branch had no set_modify of its own, so deleting it
      * would stop a finished polygon marking the file dirty at all. */
   }
   if( what & ADD)
   {
     if(mousex_snap < xctx->nl_x1) xctx->nl_x1 = mousex_snap;
     if(mousex_snap > xctx->nl_x2) xctx->nl_x2 = mousex_snap;
     if(mousey_snap < xctx->nl_y1) xctx->nl_y1 = mousey_snap;
     if(mousey_snap > xctx->nl_y2) xctx->nl_y2 = mousey_snap;
     /* closed poly */
     if(what & END) {
       /* delete last rubber */
       drawtemppolygon(xctx->gctiled, NOW, xctx->nl_polyx, xctx->nl_polyy, xctx->nl_points+1, 0);
       xctx->nl_polyx[xctx->nl_points] = xctx->nl_polyx[0];
       xctx->nl_polyy[xctx->nl_points] = xctx->nl_polyy[0];
     /* add point */
     } else if(xctx->nl_polyx[xctx->nl_points] != xctx->nl_polyx[xctx->nl_points-1] ||
          xctx->nl_polyy[xctx->nl_points] != xctx->nl_polyy[xctx->nl_points-1]) {
       xctx->nl_polyx[xctx->nl_points] = mousex_snap;
       xctx->nl_polyy[xctx->nl_points] = mousey_snap;
     } else {
       return;
     }
     xctx->nl_points++;
     /* prepare next point for rubber */
     xctx->nl_polyx[xctx->nl_points]=xctx->nl_polyx[xctx->nl_points-1];
     xctx->nl_polyy[xctx->nl_points]=xctx->nl_polyy[xctx->nl_points-1];
   }
   /* end open or closed poly  by user request */
   if((what & SET || (what & END)) ||
        /* closed poly end by clicking on first point */
        ((what & ADD) && xctx->nl_polyx[xctx->nl_points-1] == xctx->nl_polyx[0] &&
         xctx->nl_polyy[xctx->nl_points-1] == xctx->nl_polyy[0]) ) {
     xctx->push_undo();
     drawtemppolygon(xctx->gctiled, NOW, xctx->nl_polyx, xctx->nl_polyy, xctx->nl_points+1, 0);
     store_poly(-1, xctx->nl_polyx, xctx->nl_polyy, xctx->nl_points, xctx->rectcolor, 0, NULL);
     set_modify(1);   /* ISSUE 0270 -- moved down from the PLACE arm; see the comment there */
     /* action-log Layer C: the stored point list replays through the
      * `xschem polygon x1 y1 ...` coordinate form (Phase 3 slice B);
      * dynamic length, so the line is assembled before logging */
     {
       char *logcmd = NULL, chunk[128];
       int i;
       my_strdup(_ALLOC_ID_, &logcmd, "xschem polygon");
       for(i = 0; i < xctx->nl_points; ++i) {
         my_snprintf(chunk, S(chunk), " %.16g %.16g", xctx->nl_polyx[i], xctx->nl_polyy[i]);
         my_strcat(_ALLOC_ID_, &logcmd, chunk);
       }
       log_action("%s", logcmd);
       my_free(_ALLOC_ID_, &logcmd);
     }
     /* fprintf(errfp, "new_poly: finish: nl_points=%d\n", xctx->nl_points); */
     drawtemppolygon(xctx->gc[xctx->rectcolor], NOW, xctx->nl_polyx, xctx->nl_polyy, xctx->nl_points, 0);
     xctx->ui_state &= ~STARTPOLYGON;
     drawpolygon(xctx->rectcolor, NOW, xctx->nl_polyx, xctx->nl_polyy, xctx->nl_points, 0, 0, 0.0, 0);
     my_free(_ALLOC_ID_, &xctx->nl_polyx);
     my_free(_ALLOC_ID_, &xctx->nl_polyy);
     xctx->nl_maxpoints = xctx->nl_points = 0;
   }
   if(what & RUBBER)
   {
     if(mousex_snap < xctx->nl_x1) xctx->nl_x1 = mousex_snap;
     if(mousex_snap > xctx->nl_x2) xctx->nl_x2 = mousex_snap;
     if(mousey_snap < xctx->nl_y1) xctx->nl_y1 = mousey_snap;
     if(mousey_snap > xctx->nl_y2) xctx->nl_y2 = mousey_snap;
     /* fprintf(errfp, "new_poly: RUBBER\n"); */
     drawtemppolygon(xctx->gctiled, NOW, xctx->nl_polyx, xctx->nl_polyy, xctx->nl_points+1, 0);
     xctx->nl_polyy[xctx->nl_points] = mousey_snap;
     xctx->nl_polyx[xctx->nl_points] = mousex_snap;
     restore_selection(xctx->nl_x1, xctx->nl_y1, xctx->nl_x2, xctx->nl_y2);
     /* xctx->nl_x2 = mousex_snap; xctx->nl_y2 = mousey_snap; */
     /* RUBBER|CLEAR erases the band and does NOT re-stroke it -- the idiom new_wire()/new_line()
      * have always had, added here for abort_shape_draw() (callback.c, plan phase 3): a teardown
      * owes the erase, and the erase must tile from save_pixmap BEFORE any full draw() regenerates
      * it. The `nl_points+1` above is load-bearing: index nl_points is the live rubber vertex. */
     if(!(what & CLEAR)) {
       drawtemppolygon(xctx->gc[xctx->rectcolor], NOW, xctx->nl_polyx, xctx->nl_polyy, xctx->nl_points+1, 0);
     }
   }
}

#if HAS_CAIRO==1
int text_bbox(const char *str, double xscale, double yscale,
    short rot, short flip, int hcenter, int vcenter, double x1,double y1, double *rx1, double *ry1,
    double *rx2, double *ry2, int *cairo_lines, double *cairo_longest_line)
{
  int c=0;
  char *str_ptr, *s = NULL;
  double size;
  cairo_text_extents_t ext;
  cairo_font_extents_t fext;
  double ww, hh, maxw;

  /* if no cairo_ctx is available use text_bbox_nocairo().
  * will not match exactly font metrics when doing ps/svg output, but better than nothing */
  if(!has_x && !xctx->cairo_ctx) return text_bbox_nocairo(str, xscale, yscale, rot, flip, hcenter, vcenter, x1, y1,
                                      rx1, ry1, rx2, ry2, cairo_lines, cairo_longest_line);
  size = xscale*52.*cairo_font_scale;

  /*  if(size*xctx->mooz>800.) { */
  /*    return 0; */
  /*  } */

  cairo_set_font_size (xctx->cairo_ctx, size*xctx->mooz);
  cairo_font_extents(xctx->cairo_ctx, &fext);
  ww=0.; hh=1.;
  c=0;
  *cairo_lines=1;
  my_strdup2(_ALLOC_ID_, &s, str);
  str_ptr = s;
  while( s && s[c] ) {
    if(s[c] == '\n') {
      s[c]='\0';
      ++hh;
      (*cairo_lines)++;
      if(str_ptr[0]!='\0') {
        cairo_text_extents(xctx->cairo_ctx, str_ptr, &ext);
        maxw = ext.x_advance > ext.width ? ext.x_advance : ext.width;
        if(maxw > ww) ww= maxw;
      }
      s[c]='\n';
      str_ptr = s+c+1;
    } else {
    }
    ++c;
  }
  if(str_ptr && str_ptr[0]!='\0') {
    cairo_text_extents(xctx->cairo_ctx, str_ptr, &ext);
    maxw = ext.x_advance > ext.width ? ext.x_advance : ext.width;
    if(maxw > ww) ww= maxw;
  }
  my_free(_ALLOC_ID_, &s);
  hh = hh*fext.height * cairo_font_line_spacing;
  *cairo_longest_line = ww;

  *rx1=x1;*ry1=y1;
  if(hcenter) {
    if     (rot==0 && flip == 0) { *rx1-= ww*xctx->zoom/2;}
    else if(rot==1 && flip == 0) { *ry1-= ww*xctx->zoom/2;}
    else if(rot==2 && flip == 0) { *rx1+= ww*xctx->zoom/2;}
    else if(rot==3 && flip == 0) { *ry1+= ww*xctx->zoom/2;}
    else if(rot==0 && flip == 1) { *rx1+= ww*xctx->zoom/2;}
    else if(rot==1 && flip == 1) { *ry1+= ww*xctx->zoom/2;}
    else if(rot==2 && flip == 1) { *rx1-= ww*xctx->zoom/2;}
    else if(rot==3 && flip == 1) { *ry1-= ww*xctx->zoom/2;}
  }

  if(vcenter) {
    if     (rot==0 && flip == 0) { *ry1-= hh*xctx->zoom/2;}
    else if(rot==1 && flip == 0) { *rx1+= hh*xctx->zoom/2;}
    else if(rot==2 && flip == 0) { *ry1+= hh*xctx->zoom/2;}
    else if(rot==3 && flip == 0) { *rx1-= hh*xctx->zoom/2;}
    else if(rot==0 && flip == 1) { *ry1-= hh*xctx->zoom/2;}
    else if(rot==1 && flip == 1) { *rx1+= hh*xctx->zoom/2;}
    else if(rot==2 && flip == 1) { *ry1+= hh*xctx->zoom/2;}
    else if(rot==3 && flip == 1) { *rx1-= hh*xctx->zoom/2;}
  }


  ROTATION(rot, flip, 0.0,0.0, ww*xctx->zoom,hh*xctx->zoom,(*rx2),(*ry2));
  *rx2+=*rx1;*ry2+=*ry1;
  if     (rot==0) {*ry1-=cairo_vert_correct; *ry2-=cairo_vert_correct;}
  else if(rot==1) {*rx1+=cairo_vert_correct; *rx2+=cairo_vert_correct;}
  else if(rot==2) {*ry1+=cairo_vert_correct; *ry2+=cairo_vert_correct;}
  else if(rot==3) {*rx1-=cairo_vert_correct; *rx2-=cairo_vert_correct;}
  RECTORDER((*rx1),(*ry1),(*rx2),(*ry2));
  return 1;
}
int text_bbox_nocairo(const char *str,double xscale, double yscale,
    short rot, short flip, int hcenter, int vcenter, double x1,double y1, double *rx1, double *ry1,
    double *rx2, double *ry2, int *cairo_lines, double *cairo_longest_line)
#else
int text_bbox(const char *str,double xscale, double yscale,
    short rot, short flip, int hcenter, int vcenter, double x1,double y1, double *rx1, double *ry1,
    double *rx2, double *ry2, int *cairo_lines, double *cairo_longest_line)
#endif
{
 register int c=0, length =0;
 double w, h;

  w=0;h=1;
  *cairo_lines = 1;
  if(str!=NULL) while( str[c] )
  {
   if((str)[c++]=='\n') {(*cairo_lines)++; h++; length=0;}
   else length++;
   if(length > w)
     w = length;
  }
  w *= (FONTWIDTH+FONTWHITESPACE)*xscale* tclgetdoublevar("nocairo_font_xscale") * cairo_font_scale;
  *cairo_longest_line = w;
  h *= (FONTHEIGHT+FONTDESCENT+FONTWHITESPACE)*yscale* tclgetdoublevar("nocairo_font_yscale") * cairo_font_scale;
  *rx1=x1;*ry1=y1;
  if(     rot==0) *ry1-=nocairo_vert_correct;
  else if(rot==1) *rx1+=nocairo_vert_correct;
  else if(rot==2) *ry1+=nocairo_vert_correct;
  else            *rx1-=nocairo_vert_correct;

  if(hcenter) {
    if     (rot==0 && flip == 0) { *rx1-= w/2;}
    else if(rot==1 && flip == 0) { *ry1-= w/2;}
    else if(rot==2 && flip == 0) { *rx1+= w/2;}
    else if(rot==3 && flip == 0) { *ry1+= w/2;}
    else if(rot==0 && flip == 1) { *rx1+= w/2;}
    else if(rot==1 && flip == 1) { *ry1+= w/2;}
    else if(rot==2 && flip == 1) { *rx1-= w/2;}
    else if(rot==3 && flip == 1) { *ry1-= w/2;}
  }

  if(vcenter) {
    if     (rot==0 && flip == 0) { *ry1-= h/2;}
    else if(rot==1 && flip == 0) { *rx1+= h/2;}
    else if(rot==2 && flip == 0) { *ry1+= h/2;}
    else if(rot==3 && flip == 0) { *rx1-= h/2;}
    else if(rot==0 && flip == 1) { *ry1-= h/2;}
    else if(rot==1 && flip == 1) { *rx1+= h/2;}
    else if(rot==2 && flip == 1) { *ry1+= h/2;}
    else if(rot==3 && flip == 1) { *rx1-= h/2;}
  }

  ROTATION(rot, flip, 0.0,0.0,w,h,(*rx2),(*ry2));
  *rx2+=*rx1;*ry2+=*ry1;
  RECTORDER((*rx1),(*ry1),(*rx2),(*ry2));
  return 1;
}

/* round() does not exist in C89 */
double my_round(double a)
{
  /* return 0.0 or -0.0 if a == 0.0 or -0.0 */
  return (a > 0.0) ? floor(a + 0.5) : (a < 0.0) ? ceil(a - 0.5) : a;
}

/* snap a schematic coordinate to the current snap grid (cadsnap) -- the
 * "effective" position an interactive click resolves to. The action log must
 * record effective coordinates, not the raw mouse position with float noise
 * (doc/claude/specs/select_at.md). cadsnap <= 0 returns the value unchanged. */
double snap_to_grid(double c)
{
  double s = tclgetdoublevar("cadsnap");
  double r;
  if(s <= 0.0) return c;
  r = my_round(c / s) * s;
  return (r == 0.0) ? 0.0 : r; /* normalize -0.0 so logs never show "-0" */
}

double round_to_n_digits(double x, int n)
{
  double scale;
  if(x == 0.0) return x;
  scale = pow(10.0, ceil(log10(fabs(x))) - n);
  return my_round(x / scale) * scale;
}

double floor_to_n_digits(double x, int n)
{
  double scale;
  if(x == 0.0) return x;
  scale = pow(10.0, ceil(log10(fabs(x))) - n);
  return floor(x / scale) * scale;
}

double ceil_to_n_digits(double x, int n)
{
  double scale;
  if(x == 0.0) return x;
  scale = pow(10.0, ceil(log10(fabs(x))) - n);
  return ceil(x / scale) * scale;
}



int create_text(int draw_text, double x, double y, int rot, int flip, const char *txt,
    const char *props, double hsize, double vsize)
{
  int textlayer;
  xText *t;
  int save_draw;
  #if HAS_CAIRO==1
  const char  *textfont;
  #endif

  check_text_storage();
  t = &xctx->text[xctx->texts];
  t->txt_ptr=NULL;
  t->prop_ptr=NULL;  /*  20111006 added missing initialization of pointer */
  t->floater_ptr = NULL;
  t->font=NULL;
  t->floater_instname=NULL;
  t->owner_pin_id=0; /* ordinary text by default; synth_pin_views() stamps views */
  my_strdup2(_ALLOC_ID_, &t->txt_ptr, txt);
  t->x0=x;
  t->y0=y;
  t->rot=(short int) rot;
  t->flip=(short int) flip;
  t->sel=0;
  t->xscale= hsize;
  t->yscale= vsize;
  my_strdup(_ALLOC_ID_, &t->prop_ptr, props);
  /*  debug ... */
  /*  t->prop_ptr=NULL; */
  dbg(1, "create_text(): done text input\n");
  set_text_flags(t);
  textlayer = t->layer;
  if(textlayer < 0 || textlayer >= cadlayers) textlayer = TEXTLAYER;

  if(draw_text) {
    #if HAS_CAIRO==1
    textfont = t->font;
    if((textfont && textfont[0]) || (t->flags & (TEXT_BOLD | TEXT_OBLIQUE | TEXT_ITALIC))) {
      cairo_font_slant_t slant;
      cairo_font_weight_t weight;
      textfont = (t->font && t->font[0]) ? t->font : tclgetvar("cairo_font_name");
      weight = ( t->flags & TEXT_BOLD) ? CAIRO_FONT_WEIGHT_BOLD : CAIRO_FONT_WEIGHT_NORMAL;
      slant = CAIRO_FONT_SLANT_NORMAL;
      if(t->flags & TEXT_ITALIC) slant = CAIRO_FONT_SLANT_ITALIC;
      if(t->flags & TEXT_OBLIQUE) slant = CAIRO_FONT_SLANT_OBLIQUE;
      cairo_save(xctx->cairo_ctx);
      cairo_save(xctx->cairo_save_ctx);
      xctx->cairo_font =
            cairo_toy_font_face_create(textfont, slant, weight);
      cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
      cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
      cairo_font_face_destroy(xctx->cairo_font);
    }
    #endif
    save_draw=xctx->draw_window;
    xctx->draw_window=1;
    draw_string(textlayer, NOW, get_text_floater(xctx->texts), t->rot, t->flip,
        t->hcenter, t->vcenter, t->x0,t->y0, t->xscale, t->yscale);
    xctx->draw_window = save_draw;
    #if HAS_CAIRO==1
    if((textfont && textfont[0]) || (t->flags & (TEXT_BOLD | TEXT_OBLIQUE | TEXT_ITALIC))) {
      cairo_restore(xctx->cairo_ctx);
      cairo_restore(xctx->cairo_save_ctx);
    }
    #endif
  }
  text_register(xctx->texts);
  return 1;
}

int place_text(int draw_text, double mx, double my)
{
  char *txt, *props, *hsize, *vsize;

  tclsetvar("props","");
  tclsetvar("tctx::retval","");

  if(!tclgetvar("tctx::hsize"))
   tclsetvar("tctx::hsize","0.4");
  if(!tclgetvar("tctx::vsize"))
   tclsetvar("tctx::vsize","0.4");
  xctx->semaphore++;
  tcleval("enter_text {text:} normal");
  xctx->semaphore--;

  dbg(1, "place_text(): hsize=%s vsize=%s\n",tclgetvar("tctx::hsize"), tclgetvar("tctx::vsize") );
  /* get: retval, hsize, vsize, props,  */
  txt =  (char *)tclgetvar("tctx::retval");
  props =  (char *)tclgetvar("props");
  hsize =  (char *)tclgetvar("tctx::hsize");
  vsize =  (char *)tclgetvar("tctx::vsize");
  if(!txt || !strcmp(txt,"")) return 0;   /*  dont allocate text object if empty string given */
  xctx->push_undo();
  dbg(1,"props=%s, txt=%s\n", props, txt);

  create_text(draw_text, mx, my, 0, 0, txt, props, atof(hsize), atof(vsize));
  select_text(xctx->texts - 1, SELECTED, 0, 1);
  rebuild_selected_array(); /* sets xctx->ui_state |= SELECTION */
  drawtemprect(xctx->gc[SELLAYER], END, 0.0, 0.0, 0.0, 0.0);
  drawtempline(xctx->gc[SELLAYER], END, 0.0, 0.0, 0.0, 0.0);
  return 1;
}

void pan(int what, int mx, int my)
{
  int dx, dy, ddx, ddy;
  if(what & START) {
    xctx->mmx_s = xctx->mx_s = mx;
    xctx->mmy_s = xctx->my_s = my;
    xctx->xorig_save = xctx->xorigin;
    xctx->yorig_save = xctx->yorigin;
  }
  else if(what == RUBBER) {
    dx = mx - xctx->mx_s;
    dy = my - xctx->my_s;
    ddx = abs(mx -xctx->mmx_s);
    ddy = abs(my -xctx->mmy_s);
    if(ddx>5 || ddy>5) {
      xctx->xorigin = xctx->xorig_save + dx*xctx->zoom;
      xctx->yorigin = xctx->yorig_save + dy*xctx->zoom;
      draw();
      xctx->mmx_s = mx;
      xctx->mmy_s = my;
    }
  }
}

/* instead of doing a drawtemprect(xctx->gctiled, NOW, ....) do 4
 * XCopy Area operations */
void fix_restore_rect(double x1, double y1, double x2, double y2)
{
  dbg(1, "%g %g %g %g\n", x1, y1, x2, y2);
  /* horizontal lines */
  MyXCopyAreaDouble(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
      x1, y1, x2, y1, x1, y1,
      xctx->lw);

  MyXCopyAreaDouble(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
      x1, y2, x2, y2, x1, y2,
      xctx->lw);

  /* vertical lines */
  MyXCopyAreaDouble(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
      x1, y1, x1, y2, x1, y1,
      xctx->lw);

  MyXCopyAreaDouble(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
      x2, y1, x2, y2, x2, y1,
      xctx->lw);
}


/*  20150927 select=1: select objects, select=0: unselect objects
 * uses static variables:
 *   xctx->nl_xr, xctx->nl_yr, xctx->nl_xr2, xctx->nl_yr2: The selection box
 *   xctx->nl_sel: selection mode (1=select, 0=unselect) as set in what == START
 *   xctx->nl_dir: drag direction: 1=right, 1=left
 *   xctx->nl_sem: semaphore used internally to detect misuse of the function.
 */
void select_rect(int stretch, int what, int select)
{
 double nl_xx1, nl_yy1, nl_xx2, nl_yy2;
 int incremental_select = tclgetboolvar("incremental_select");
 int sel_touch = tclgetboolvar("select_touch");
 dbg(1, "select_rect(): what=%d, mousex_save=%g mousey_save=%g, mousex=%g mousey=%g\n",
        what, xctx->mx_double_save, xctx->my_double_save, xctx->mousex, xctx->mousey);
 if(what & RUBBER)
 {
    if(xctx->nl_sem==0) {
      fprintf(errfp, "ERROR: select_rect() RUBBER called before START\n");
      tcleval("alert_ {ERROR: select_rect() RUBBER called before START} {}");
    }
    nl_xx1=xctx->nl_xr;nl_xx2=xctx->nl_xr2;nl_yy1=xctx->nl_yr;nl_yy2=xctx->nl_yr2;
    RECTORDER(nl_xx1,nl_yy1,nl_xx2,nl_yy2);
    drawtemprect(xctx->gctiled,NOW, nl_xx1,nl_yy1,nl_xx2,nl_yy2);
    xctx->nl_xr2=xctx->mousex;xctx->nl_yr2=xctx->mousey;

    if(!xctx->nl_sel || (incremental_select && xctx->nl_dir == 0))
       select_inside(stretch, nl_xx1, nl_yy1, nl_xx2, nl_yy2, xctx->nl_sel);
    else if(incremental_select && xctx->nl_dir == 1 && sel_touch)
       select_touch(nl_xx1, nl_yy1, nl_xx2, nl_yy2, xctx->nl_sel);
    nl_xx1=xctx->nl_xr;nl_xx2=xctx->nl_xr2;nl_yy1=xctx->nl_yr;nl_yy2=xctx->nl_yr2;
    RECTORDER(nl_xx1,nl_yy1,nl_xx2,nl_yy2);
    drawtemprect(xctx->gc[SELLAYER],NOW, nl_xx1,nl_yy1,nl_xx2,nl_yy2);

    rebuild_selected_array();
    draw_selection(xctx->gc[SELLAYER], 0);
 }
 else if(what & START)
 {
    /*
     * if(xctx->nl_sem==1) {
     *  fprintf(errfp, "ERROR: reentrant call of select_rect()\n");
     *  tcleval("alert_ {ERROR: reentrant call of select_rect()} {}");
     * }
     */
    xctx->nl_sel = select;
    xctx->ui_state |= STARTSELECT;

    /*  use m[xy]_double_save instead of mouse[xy]_snap */
    /*  to avoid delays in setting the start point of a */
    /*  selection rectangle, this is noticeable and annoying on */
    /*  networked / slow X servers. 20171218 */
    /* xctx->nl_xr=xctx->nl_xr2=xctx->mousex_snap; */
    /* xctx->nl_yr=xctx->nl_yr2=xctx->mousey_snap; */
    xctx->nl_xr=xctx->nl_xr2=xctx->mx_double_save;
    xctx->nl_yr=xctx->nl_yr2=xctx->my_double_save;
    xctx->nl_sem=1;
 }
 else if(what & END)
 {
    RECTORDER(xctx->nl_xr,xctx->nl_yr,xctx->nl_xr2,xctx->nl_yr2);
    drawtemprect(xctx->gctiled, NOW, xctx->nl_xr,xctx->nl_yr,xctx->nl_xr2,xctx->nl_yr2);

    if(!sel_touch || xctx->nl_dir == 0)
      select_inside(stretch, xctx->nl_xr,xctx->nl_yr,xctx->nl_xr2,xctx->nl_yr2, xctx->nl_sel);
    else
      select_touch(xctx->nl_xr,xctx->nl_yr,xctx->nl_xr2,xctx->nl_yr2, xctx->nl_sel);

    draw_selection(xctx->gc[SELLAYER], 0);
    xctx->ui_state &= ~STARTSELECT;
    xctx->nl_sem=0;
 }
}

/* needed to dynamically reassign the `manhattan_lines` value for wire-drawing */
void recompute_orthogonal_manhattanline(double linex1, double liney1, double linex2, double liney2) {
  double origin_shifted_x2, origin_shifted_y2;
  /* Origin shift the cartesian coordinate p2(x2,y2) w.r.t. p1(x1,y1) */
  origin_shifted_x2 = linex2 - linex1;
  origin_shifted_y2 = liney2 - liney1;
  /* Draw whichever component of the resulting orthogonal-wire is bigger (either horizontal or vertical), first */
  if(origin_shifted_x2*origin_shifted_x2 > origin_shifted_y2*origin_shifted_y2)
    xctx->manhattan_lines = 1;
  else
    xctx->manhattan_lines = 2;

  return;
}

