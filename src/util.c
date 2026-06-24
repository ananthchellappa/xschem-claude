/* File: util.c
 *
 * This file is part of XSCHEM,
 * a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
 * simulation.
 * Copyright (C) 1998-2024 Stefan Frederik Schippers
 *
 * General-purpose memory / string / file / debug utilities, extracted
 * verbatim from editprop.c (behavior-preserving move; no logic changes).
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

#include <stdarg.h>
#include "xschem.h"

int my_strcasecmp(const char *s1, const char *s2)
{
  while(tolower(*s1) == tolower(*s2)) {
    if (*s1 == '\0') return 0;
    s1++;
    s2++;
  }
  return tolower(*s1) - tolower(*s2);
}
char *my_strcasestr(const char *haystack, const char *needle)
{
  const char *h, *n;
  int found = 0;
  if(needle[0] == '\0') return (char *)haystack;

  for(h = haystack; *h; h++) {
    found = 1;
    for(n = needle; *n; n++) {
      const char *hh = h + (n - needle);
      dbg(1, "%c   %c\n", *hh, *n);
      if(toupper(*hh) != toupper(*n)) {
        found = 0;
        break;
      }
    }
    if(found) return (char *)h;
  }
  return NULL;
}
int my_strncasecmp(const char *s1, const char *s2, size_t n)
{
  if (n == 0) return 0;
  while(tolower(*s1) == tolower(*s2)) {
    if (--n == 0) return 0;
    if (*s1 == '\0') return 0;
    s1++;
    s2++;
  }
  return tolower(*s1) - tolower(*s2);
}
/* same as case insensitive strcmp(), but allow '1, true, on, yes' for true value
 * any integer > 0 on str considered as 1
 * both in str and boolean */
int strboolcmp(const char *str, const char *boolean)
{
  int retval, s = 0, b = 0;
  int strval = -1;
  if(!my_strcasecmp(boolean, "true")) b = 1;
  else if(!my_strcasecmp(boolean, "false")) b = 0;
  else b = -1;
  if(isonlydigit(str)) {
    strval = atoi(str);
    s = strval ? 1 : 0;
  }
  else if(!my_strcasecmp(str, "true") ||
     !my_strcasecmp(str, "on") ||
     !my_strcasecmp(str, "yes")) s = 1;
  else if(!my_strcasecmp(str, "false") ||
     !my_strcasecmp(str, "off") ||
     !my_strcasecmp(str, "no")) s = 0;
  else s = -1;
  if(s == -1 || b == -1) retval = strcmp(str, boolean);
  else retval = (s != b);
  dbg(2, "strboolcmp(): str=%s boolean=%s retval=%d\n", str, boolean, retval);
  return retval;
}
/* return lenght of line and skip */
size_t my_fgets_skip(FILE *fd)
{
  enum { SIZE = 1024 };
  char buf[SIZE];
  size_t line_len = 0, len;

  while(fgets(buf, SIZE, fd)) {
    len = strlen(buf);
    line_len += len;
    if(buf[len - 1] == '\n') break;
  }
  return line_len;
}
/* caller should free allocated storage for s */
char *my_fgets(FILE *fd, size_t *line_len)
{
  enum { SIZE = 1024 };
  char buf[SIZE];
  char *s = NULL;
  size_t len;

  if(line_len) *line_len = 0;
  while(fgets(buf, SIZE, fd)) {
    my_strcat(_ALLOC_ID_, &s, buf);
    len = strlen(buf);
    if(line_len) *line_len += len;
    if(buf[len - 1] == '\n') break;
  }
  return s;
}
/* split a string into tokens like standard strtok_r,
 * if keep_quote == 0:
 *   if quote string is not empty any character matching quote is considered a quoting
 *   character, removed from input and all characters before next quote are considered
 *   as part of the token. backslash can be used to enter literal quoting characters and
 *   literal backslashes. Escaping backslash is removed from tokens.
 * if keep_quote == 1:
 *   keep quotes and backslahes
 * if keep_quote == 4:
 *   remove quoting characters, keep backslashes
 * if quote is empty no backslash/quote is removed from input and behavior is identical
 * to strtok_r
 *
 * Example:
 * my_strtok_r("aaa \\\"bbb\\\" \"ccc ddd\" eee", " ", "\"", 0);
 * aaa
 * "bbb"
 * ccc ddd
 * eee
 *
 * my_strtok_r("aaa \\\"bbb\\\" \"ccc ddd\" eee", " ", "\"", 1);
 * aaa
 * \"bbb\"
 * "ccc ddd"
 * eee
 *
 * my_strtok_r("aaa \\\"bbb\\\" \"ccc ddd\" eee", " ", "\"", 4);
 * aaa
 * \"bbb\"
 * ccc ddd
 * eee
 *
 */
char *my_strtok_r(char *str, const char *delim, const char *quote, int keep_quote, char **saveptr)
{
  char *tok;
  int q = 0; /* quote */
  int e = 0; /* escape */
  int ne = 0; /* number of escapes / quoting chars to remove */
  if(str) { /* 1st call */
    *saveptr = str;
  }
  while(**saveptr && strchr(delim, **saveptr) ) { /* skip separators */
    ++(*saveptr);
  }
  tok = *saveptr; /* start of token */
  while(**saveptr && (e || q || !strchr(delim, **saveptr)) ) { /* look for sep. marking end of current token */
    if(ne) *(*saveptr - ne) = **saveptr; /* shift back eating escapes / quotes */
    if(!e && strchr(quote, **saveptr)) {
      q = !q;
      if(!(keep_quote & 1)) ++ne; /* remove quoting character */
    }
    if(quote[0] && !e && **saveptr == '\\') { /* do not skip backslashes either */
      e = 1;
      if(!(keep_quote & 5)) ++ne; /* remove escaping backslash */
    } else e = 0;
    ++(*saveptr);
  }
  if(**saveptr) {
    **saveptr = '\0'; /* mark end of token */
    if(ne) *(*saveptr - ne) = **saveptr; /* shift back eating escapes / quotes */
    ++(*saveptr);     /* if not at end of string advance one char for next iteration */
  } else if(ne) *(*saveptr - ne ) = **saveptr; /* shift back eating escapes / quotes */
  if(tok[0]) return tok; /* return token */
  else return NULL; /* no more tokens */
}
size_t my_strdup(int id, char **dest, const char *src) /* empty source string --> dest=NULL */
{
 size_t len;

 if(*dest == src && src!=NULL)
   dbg(0, "my_strdup(): WARNING: src == *dest == %p, id=%d\n", src, id);
 if(src!=NULL && src[0]!='\0')  {
   len = strlen(src)+1;
   my_realloc(id, dest, len);
   memcpy(*dest, src, len);
   dbg(3,"my_strdup(%d,): duplicated string %s\n", id, src);
   return len-1;
 } else if(*dest) {
   my_free(_ALLOC_ID_, dest);
   dbg(3,"my_strdup(%d,): freed destination ptr\n", id);
 }

 return 0;
}
/* 20171004 copy at most n chars, adding a null char at end */
void my_strndup(int id, char **dest, const char *src, size_t n) /* empty source string --> dest=NULL */

{
 if(*dest!=NULL) {
   dbg(3,"  my_strndup:  calling my_free\n");
   my_free(_ALLOC_ID_, dest);
 }
 if(src!=NULL && src[0]!='\0')
 {
  /* 20180924 replace strndup() */
  char *p = memchr(src, '\0', n);
  if(p) n = p - src;
  *dest = my_malloc(id, n+1);
  if(*dest) {
    memcpy(*dest, src, n);
    (*dest)[n] = '\0';
  }
  /* *dest=strndup(src, n); */

  dbg(3,"my_strndup(%d,): duplicated string %s\n", id, src);
 }
}
/* replace TABs with required number of spaces
 * User must free returned string */
char *my_expand(const char *s, int tabstop)
{
  char pad[200];
  size_t spos = 0;
  char *t = NULL;
  const char *sptr = s;

  if(!s) {
    return NULL;
  }
  my_strcat2(_ALLOC_ID_, &t, "");
  while(*sptr) {
    if(*sptr == '\t') {
      int i;
      size_t npad = tabstop - spos % tabstop;
      for(i = 0; i < npad; i++) pad[i] = ' ';
      pad[i] = '\0';
      spos += npad;
    } else {
      pad[0] = *sptr;
      pad[1] = '\0';
      spos++;
    }
    my_strcat2(_ALLOC_ID_, &t, pad);
    if(*sptr == '\n') spos = 0;
    sptr++;
  }
  return t;
}
void dbg(int level, char *fmt, ...)
{
  if(debug_var>=level) {
    va_list args;
    va_start(args, fmt);
    vfprintf(errfp, fmt, args);
    va_end(args);
  }
}

/* Keep at most this many Xschem.log[.N] files per directory: repeated sessions
 * (every GUI run opens a fresh one) must not pile up logs without bound. */
#define ACTIONLOG_KEEP 10

/* Build the Nth action-log name ("Xschem.log" for 0, "Xschem.log.<n>" otherwise). */
static void actionlog_name(char *out, size_t sz, const char *dir, int n)
{
  if(n == 0) my_snprintf(out, sz, "%s/Xschem.log", dir);
  else       my_snprintf(out, sz, "%s/Xschem.log.%d", dir, n);
}

/* Action log (Phase 0).
 *
 * Opens a per-session log of user actions, each line a replayable `xschem ...`
 * Tcl command (call sites are added in later phases). The file is a SEPARATE
 * stream from errfp (the debug/stderr log) so replayable commands never mix
 * with debug output.
 *
 * Location: the directory given by --logdir (created if absent; if it cannot be
 * created this is fatal, per spec), else the current working directory.
 * Name: the first free name in the sequence Xschem.log, Xschem.log.1, ...
 * (same idiom as the untitled.sch namer in save.c).
 *
 * Phase-0 policy: only open the log for an interactive session (has_x) or when
 * --logdir was given explicitly. This keeps headless/script/test runs from
 * littering the cwd, while letting automation opt in by passing --logdir.
 * --nolog disables logging entirely (and, on the Tcl side, the CIW auto-open;
 * see issue 0002): combining it with --logdir is contradictory and fatal. */
void init_action_log(void)
{
  char dir[PATH_MAX];
  char fname[PATH_MAX];
  struct stat buf;
  int i;

  if(cli_opt_nolog) {
    if(cli_opt_logdir[0]) {
      fprintf(stderr, "xschem: --nolog and --logdir are mutually exclusive, aborting.\n");
      exit(EXIT_FAILURE);
    }
    return;
  }
  if(!has_x && !cli_opt_logdir[0]) return;

  if(cli_opt_logdir[0]) {
    my_strncpy(dir, cli_opt_logdir, S(dir));
    if(stat(dir, &buf)) {            /* does not exist (or not accessible) */
      if(mkdir(dir, 0777)) {         /* create it; honors umask */
        fprintf(stderr, "xschem: cannot create log directory '%s', aborting.\n", dir);
        exit(EXIT_FAILURE);
      }
    } else if(!S_ISDIR(buf.st_mode)) {
      fprintf(stderr, "xschem: log path '%s' exists but is not a directory, aborting.\n", dir);
      exit(EXIT_FAILURE);
    }
  } else {
    my_strncpy(dir, ".", S(dir));
  }

  /* Pick a slot in [0, ACTIONLOG_KEEP): reuse the first free one; if all are taken,
   * recycle (truncate) the OLDEST so the count stays capped instead of growing without
   * bound. The oldest is almost never a concurrently-open session (those have recent
   * mtimes), so this rarely clobbers a live log. */
  {
    int slot = -1, oldest = 0;
    time_t oldest_mtime = 0;
    for(i = 0; i < ACTIONLOG_KEEP; ++i) {
      actionlog_name(fname, S(fname), dir, i);
      if(stat(fname, &buf)) { slot = i; break; }   /* free slot */
      if(i == 0 || buf.st_mtime < oldest_mtime) { oldest_mtime = buf.st_mtime; oldest = i; }
    }
    if(slot < 0) slot = oldest;                     /* all full -> recycle the oldest */
    /* reap the orphan tail (.KEEP, .KEEP+1, ... contiguous) left by older builds that
     * incremented the name without a cap, so an existing pile collapses to the cap */
    for(i = ACTIONLOG_KEEP; ; ++i) {
      actionlog_name(fname, S(fname), dir, i);
      if(stat(fname, &buf)) break;                  /* gap -> tail ends */
      remove(fname);
    }
    actionlog_name(fname, S(fname), dir, slot);
  }

  actionlog_fp = fopen(fname, "w");
  if(!actionlog_fp) {
    /* Not fatal (only directory creation is, per spec): disable logging. */
    fprintf(stderr, "xschem: cannot open log file '%s', action logging disabled.\n", fname);
    return;
  }
  setvbuf(actionlog_fp, NULL, _IOLBF, 0); /* line-buffered, like errfp */
  my_strncpy(actionlog_filename, fname, S(actionlog_filename));
  /* header is a Tcl comment so the log stays source-able for replay */
  fprintf(actionlog_fp, "# xschem action log\n");
  dbg(1, "init_action_log(): logging actions to %s\n", fname);
}

/* Mirror one already-formatted action line to the CIW log pane (ciw.tcl).
 * The text travels through a Tcl variable and is never substituted into the
 * eval string, so arbitrary content (braces, brackets, $) cannot be
 * re-interpreted. Safe no-op before the interpreter / the CIW exist. */
static void log_action_echo(const char *str)
{
  if(!has_x || !interp) return;
  tclsetvar("ciw_line", str);
  tcleval("if {[info procs ciw_echo] ne {}} {ciw_echo $ciw_line}");
}

/* Append one action to the log as a single line and mirror it to the CIW
 * log pane. No-op when logging is disabled. Each call is one line; the
 * trailing newline is added here. */
void log_action(const char *fmt, ...)
{
  char buf[4096]; /* pane copy only; the file write below is unbounded */
  va_list args;
  if(!actionlog_fp) return;
  va_start(args, fmt);
  vfprintf(actionlog_fp, fmt, args);
  va_end(args);
  fputc('\n', actionlog_fp);
  va_start(args, fmt);
#ifdef HAS_SNPRINTF
  vsnprintf(buf, S(buf), fmt, args);
#else
  vsprintf(buf, fmt, args); /* action lines are short xschem commands */
#endif
  va_end(args);
  log_action_echo(buf);
}

/* log_action without the CIW mirror: used for commands typed INTO the CIW
 * entry, which ciw_exec already echoes itself (input-tagged) -- mirroring
 * would show them twice. */
void log_action_noecho(const char *fmt, ...)
{
  va_list args;
  if(!actionlog_fp) return;
  va_start(args, fmt);
  vfprintf(actionlog_fp, fmt, args);
  va_end(args);
  fputc('\n', actionlog_fp);
}
#ifdef HAS_SNPRINTF
size_t my_snprintf(char *str, size_t size, const char *fmt, ...)
{
  int  size_of_print;
  char s[200];

  va_list args;
  va_start(args, fmt);
  size_of_print = vsnprintf(str, size, fmt, args);
  if(has_x && size_of_print >=size) { /* output was truncated  */
    snprintf(s, S(s), "alert_ { Warning: overflow in my_snprintf print size=%d, buffer size=%d} {}",
             size_of_print, size);
    tcleval(s);
  }
  va_end(args);
  return size_of_print;
}
#else

/*
   this is a replacement for snprintf(), **however** it implements only
   the bare minimum set of formatting used by XSCHEM
*/
size_t my_snprintf(char *string, size_t size, const char *format, ...)
{
  va_list args;
  const char *f, *fmt = NULL, *prev;
  int overflow, format_spec;
  size_t l, n = 0;

  va_start(args, format);

  /* fprintf(errfp, "my_snprintf(): size=%d, format=%s\n", size, format); */
  prev = format;
  format_spec = 0;
  overflow = 0;
  for(f = format; *f; f++) {
    if(*f == '%') {
      format_spec = 1;
      fmt = f;
    }
    if(*f == 's' && format_spec) {
      char *sptr;
      sptr = va_arg(args, char *);
      l = fmt - prev;
      if(n+l > size) {
        overflow = 1;
        break;
      }
      memcpy(string + n, prev, l);
      string[n+l] = '\0';
      n += l;
      l = strlen(sptr);
      if(n+l+1 > size) {
        overflow = 1;
        break;
      }
      memcpy(string + n, sptr, l+1);
      n += l;
      format_spec = 0;
      prev = f + 1;
    }
    else if(format_spec && (*f == 'd' || *f == 'x' || *f == 'c' || *f == 'u') ) {
      char nfmt[50], nstr[50];
      int i, nlen;
      i = va_arg(args, int);
      l = f - fmt+1;
      strncpy(nfmt, fmt, l);
      nfmt[l] = '\0';
      l = fmt - prev;
      if(n+l > size) break;
      memcpy(string + n, prev, l);
      string[n+l] = '\0';
      n += l;
      nlen = sprintf(nstr, nfmt, i);
      if(n + nlen + 1 > size) {
        overflow = 1;
        break;
      }
      memcpy(string +n, nstr, nlen+1);
      n += nlen;
      format_spec = 0;
      prev = f + 1;
    }
    else if(format_spec && (*f == 'p') ) {
      char nfmt[50], nstr[50];
      void *i;
      int  nlen;
      i = va_arg(args, void *);
      l = f - fmt+1;
      strncpy(nfmt, fmt, l);
      nfmt[l] = '\0';
      l = fmt - prev;
      if(n+l > size) break;
      memcpy(string + n, prev, l);
      string[n+l] = '\0';
      n += l;
      nlen = sprintf(nstr, nfmt, i);
      if(n + nlen + 1 > size) {
        overflow = 1;
        break;
      }
      memcpy(string +n, nstr, nlen+1);
      n += nlen;
      format_spec = 0;
      prev = f + 1;
    }
    else if(format_spec && (*f == 'g' || *f == 'e' || *f == 'f')) {
      char nfmt[50], nstr[50];
      double i;
      int nlen;
      i = va_arg(args, double);
      l = f - fmt+1;
      strncpy(nfmt, fmt, l);
      nfmt[l] = '\0';
      l = fmt - prev;
      if(n+l > size) {
        overflow = 1;
        break;
      }
      memcpy(string + n, prev, l);
      string[n+l] = '\0';
      n += l;
      nlen = sprintf(nstr, nfmt, i);
      if(n + nlen + 1 > size) {
        overflow = 1;
        break;
      }
      memcpy(string +n, nstr, nlen+1);
      n += nlen;
      format_spec = 0;
      prev = f + 1;
    }
  }
  l = f - prev;
  if(!overflow && n+l+1 <= size) {
    memcpy(string + n, prev, l+1);
    n += l;
  } else {
    dbg(1, "my_snprintf(): overflow, target size=%d, format=%s\n", size, format);
  }

  va_end(args);
  /* fprintf(errfp, "my_snprintf(): returning: |%s|\n", string); */
  return n;
}
#endif /* HAS_SNPRINTF */
size_t my_strdup2(int id, char **dest, const char *src) /* 20150409 duplicates also empty string  */
{
 size_t len;
 if(*dest == src && src!=NULL)
   dbg(0, "my_strdup2(): WARNING: src == *dest == %p, id=%d\n", src, id);
 if(src!=NULL) {
   len = strlen(src)+1;
   my_realloc(id, dest, len);
   memcpy(*dest, src, len);
   dbg(3,"my_strdup2(%d,): duplicated string %s\n", id, src);
   return len-1;
 } else if(*dest) {
   my_free(_ALLOC_ID_, dest);
   dbg(3,"my_strdup2(%d,): freed destination ptr\n", id);
 }
 return 0;
}
char *my_itoa(int i)
{
  static char s[30];
  size_t n;
  n = my_snprintf(s, S(s), "%d", i);
  if(xctx) xctx->tok_size = n;
  return s;
}
char *dtoa(double i)
{
  static char s[70];
  size_t n;

  n = my_snprintf(s, S(s), "%.8g", i);
  if(xctx) xctx->tok_size = n;
  return s;
}
FILE *my_fopen(const char *f, const char *m)
{
  struct stat buf;
  FILE *fd = NULL;
  int st;

  st = stat(f, &buf);
  if(st) return NULL; /* not existing or error */
#ifdef __unix__
  if(!S_ISREG(buf.st_mode)) return NULL; /* not a regular file/symlink to a regular file */
#else
  /* TBD */
#endif
  fd = fopen(f, m);
  return fd;
}
size_t my_mstrcat(int id, char **str, const char *add, ...)
{
  va_list args;
  const char *append_str;
  size_t s, a;

  if(add == NULL) return 0;
  s = 0;
  if(*str != NULL) s = strlen(*str);
  va_start(args, add);
  append_str = add;
  do {
    if( *str != NULL) {
      if(append_str[0]) {
        a = strlen(append_str) + 1;
        my_realloc(id, str, s + a );
        memcpy(*str + s, append_str, a);
        s += a - 1;
        dbg(3,"my_mstrcat(%d,): reallocated string %s\n", id, *str);
      }
    } else {
      if(append_str[0]) {
        a = strlen(append_str) + 1;
        *str = my_malloc(id, a);
        memcpy(*str, append_str, a);
        s = a - 1;
        dbg(3,"my_mstrcat(%d,): allocated string %s\n", id, *str);
      }
    }
    append_str = va_arg(args, const char *);
  } while(append_str);
  va_end(args);
  return s;
}
size_t my_strcat(int id, char **str, const char *append_str)
{
  size_t s, a;
  dbg(3,"my_strcat(%d,): str=%s  append_str=%s\n", id,
    *str? *str : "<NULL>", append_str ? append_str : "<NULL>");
  if( *str != NULL)
  {
    s = strlen(*str);
    if(append_str == NULL || append_str[0]=='\0') return s;
    a = strlen(append_str) + 1;
    my_realloc(id, str, s + a );
    memcpy(*str + s, append_str, a);
    dbg(3,"my_strcat(%d,): reallocated string %s\n", id, *str);
    return s + a - 1;
  } else { /* str = NULL */
    if(append_str == NULL || append_str[0] == '\0') return 0;
    a = strlen(append_str) + 1;
    *str = my_malloc(id, a );
    memcpy(*str, append_str, a);
    dbg(3,"my_strcat(%d,): allocated string %s\n", id, *str);
    return a - 1;
  }
}
/* same as my_strcat, but appending "" to NULL returns "" instead of NULL */
size_t my_strcat2(int id, char **str, const char *append_str)
{
  size_t s, a;
  dbg(3,"my_strcat(%d,): str=%s  append_str=%s\n", id,
    *str? *str : "<NULL>", append_str ? append_str : "<NULL>");
  if( *str != NULL)
  {
    s = strlen(*str);
    if(append_str == NULL || append_str[0]=='\0') return s;
    a = strlen(append_str) + 1;
    my_realloc(id, str, s + a );
    memcpy(*str + s, append_str, a);
    dbg(3,"my_strcat(%d,): reallocated string %s\n", id, *str);
    return s + a - 1;
  } else { /* str == NULL */
    if(append_str == NULL ) return 0;
    a = strlen(append_str) + 1;
    *str = my_malloc(id, a );
    memcpy(*str, append_str, a);
    dbg(3,"my_strcat(%d,): allocated string %s\n", id, *str);
    return a - 1;
  }
}
size_t my_strncat(int id, char **str, size_t n, const char *append_str)
{
 size_t s, a;
 dbg(3,"my_strncat(%d,): str=%s  append_str=%s\n", id,
    *str? *str : "<NULL>", append_str ? append_str : "<NULL>");
 a = strlen(append_str) + 1;
 if(a > n + 1) a = n + 1;
 if( *str != NULL)
 {
  s = strlen(*str);
  if(append_str == NULL || append_str[0] == '\0') return s;
  my_realloc(id, str, s + a );
  memcpy(*str + s, append_str, a);
  *(*str + s + a - 1) = '\0';
  dbg(3,"my_strncat(%d,): reallocated string %s\n", id, *str);
  return s + a - 1;
 }
 else
 {
  if(append_str == NULL || append_str[0] == '\0') return 0;
  *str = my_malloc(id,  a );
  memcpy(*str, append_str, a);
  *(*str + a - 1) = '\0';
  dbg(3,"my_strncat(%d,): allocated string %s\n", id, *str);
  return a - 1;
 }
}
void *my_calloc(int id, size_t nmemb, size_t size)
{
   void *ptr;
   if(size*nmemb > 0) {
     ptr=calloc(nmemb, size);
     if(ptr == NULL)
        fprintf(errfp,"my_calloc(%d,): allocation failure %ld * %ld bytes\n", id, nmemb, size);
     dbg(3, "\nmy_calloc(%d,): allocating %p , %lu bytes\n",
               id, ptr, (unsigned long) (size*nmemb));
   }
   else ptr = NULL;
   return ptr;
}
void *my_malloc(int id, size_t size)
{
 void *ptr;
 if(size>0) {
   ptr=malloc(size);
   if(ptr == NULL) fprintf(errfp,"my_malloc(%d,): allocation failure for %ld bytes\n", id, size);
   dbg(3, "\nmy_malloc(%d,): allocating %p , %lu bytes\n", id, ptr, (unsigned long) size);
 }
 else ptr=NULL;
 return ptr;
}
void my_realloc(int id, void *ptr,size_t size)
{
 void *a;
 char old[100] = "";
 void *tmp;
 a = *(void **)ptr;
 if(debug_var > 2) my_snprintf(old, S(old), "%p", a);
 if(size == 0) {
   free(*(void **)ptr);
   dbg(3, "\nmy_free(%d,):  my_realloc_freeing %p\n",id, *(void **)ptr);
   *(void **)ptr=NULL;
 } else {
   tmp = realloc(*(void **)ptr,size);
   if(tmp == NULL) {
     fprintf(errfp,"my_realloc(%d,): allocation failure for %ld bytes\n", id, size);
   } else {
      *(void **)ptr = tmp;
      dbg(3, "\nmy_realloc(%d,): reallocating %s --> %p to %lu bytes\n",
             id, old, *(void **)ptr,(unsigned long) size);
   }
 }
}
char *my_free(int id, void *ptr)
{
 if(*(void **)ptr) {
   dbg(3, "\nmy_free(%d,):  freeing %p\n", id, *(void **)ptr);
   free(*(void **)ptr);
   *(void **)ptr=NULL;
 } else {
   dbg(3, "\n--> my_free(%d,): trying to free NULL pointer\n", id);
 }
 return NULL;
}
/* n characters at most are copied, *d will be always NUL terminated if *s does
 *   not fit(d[n-1]='\0')
 * return # of copied characters
 */
int my_strncpy(char *d, const char *s, size_t n)
{
  int i = 0;
  n -= 1;
  dbg(3, "my_strncpy():  copying %s to %lu\n", s, (unsigned long)d);
  while( (d[i] = s[i]) )
  {
    if(i == n) {
      if(s[i] != '\0') dbg(1, "my_strncpy(): overflow, n=%d, s=%s\n", n+1, s);
      d[i] = '\0';
      return i;
    }
    ++i;
  }
  return i;
}
char *strtolower(char* s) {
  char *p;
  if(s) for(p=s; *p; p++) *p=(char)tolower(*p);
  return s;
}
char *strtoupper(char* s) {
  char *p;
  if(s) for(p=s; *p; p++) *p=(char)toupper(*p);
  return s;
}
/* fast convert (decimal) string to float */
float my_atof(const char *p)
{
  static const float p10[]={
    1e-1f, 1e-2f, 1e-3f, 1e-4f, 1e-5f, 1e-6f, 1e-7f, 1e-8f
  };
  int frac;
  float sign, value, scale;
  unsigned int exponent = 0;

  /* skip initial spaces */
  while(SPC(*p)) p++;
  /* sign */
  sign = 1.0;
  if(*p == '-') {
    sign = -1.0;
    ++p;
  } else if(*p == '+') {
    ++p;
  }
  /* Get digits */
  for(value = 0.0; DGT(*p); p++) {
    value = value * 10.0f + (*p - '0');
  }
  /* get fractional part */
  if(*p == '.') {
    int cnt = 0;
    ++p;
    while (DGT(*p)) {
      if(cnt < 8) value += (*p - '0') * p10[cnt++];
      ++p;
    }
  }
  /* Exponent */
  frac = 0;
  scale = 1.0;
  if((*p == 'e') || (*p == 'E')) {
    /* Exponent sign */
    ++p;
    if(*p == '-') {
      frac = 1;
      ++p;
    } else if(*p == '+') p++;
    /* Get exponent. */
    for(; DGT(*p); p++) {
      exponent = exponent * 10 + (*p - '0');
    }
    if(exponent > 38) exponent = 38;
    /* Scale result */
    while(exponent >= 12) { scale *= 1E12f; exponent -= 12; }
    while(exponent >=  4) { scale *= 1E4f;  exponent -=  4; }
    while(exponent >   0) { scale *= 10.0f; exponent -=  1; }
    return sign * (frac ? (value / scale) : (value * scale));
  }
  return sign * value;
}
/* fast convert (decimal) string to double */
double my_atod(const char *p)
{
  static const double p10[]={
    1e-1, 1e-2, 1e-3, 1e-4, 1e-5, 1e-6, 1e-7, 1e-8, 1e-9,
    1e-10, 1e-11, 1e-12, 1e-13, 1e-14, 1e-15, 1e-16, 1e-17, 1e-18
  };
  int frac;
  double sign, value, scale;
  unsigned int exponent = 0;

  /* skip initial spaces */
  while(SPC(*p)) p++;
  /* sign */
  sign = 1.0;
  if(*p == '-') {
    sign = -1.0;
    ++p;
  } else if(*p == '+') {
    ++p;
  }
  /* Get digits */
  for(value = 0.0; DGT(*p); p++) {
    value = value * 10.0 + (*p - '0');
  }
  /* get fractional part */
  if(*p == '.') {
    int cnt = 0;
    ++p;
    while (DGT(*p)) {
      if(cnt < 18) value += (*p - '0') * p10[cnt++];
      ++p;
    }
  }
  /* Exponent */
  frac = 0;
  scale = 1.0;
  if((*p == 'e') || (*p == 'E')) {
    /* Exponent sign */
    ++p;
    if(*p == '-') {
      frac = 1;
      ++p;
    } else if(*p == '+') p++;
    /* Get exponent. */
    for(; DGT(*p); p++) {
      exponent = exponent * 10 + (*p - '0');
    }
    if(exponent > 308) exponent = 308;
    /* Scale result */
    while(exponent >= 50) { scale *= 1E50; exponent -= 50; }
    while(exponent >=  8) { scale *= 1E8;  exponent -=  8; }
    while(exponent >   0) { scale *= 10.0; exponent -=  1; }
    return sign * (frac ? (value / scale) : (value * scale));
  }
  return sign * value;
}
/* replace substring 'rep' in 'str' with 'with', if 'rep' not preceeded by an 'escape' char
 * 'count' indicates the number of replacements to do or all if -1
 */
char *str_replace(const char *str, const char *rep, const char *with, int escape, int count)
{
  static char *result = NULL;
  static size_t size=0;
  size_t result_pos = 0;
  size_t rep_len;
  size_t with_len;
  const char *s = str;
  int cond;
  int replacements = 0;

  if(s==NULL || rep == NULL || with == NULL || rep[0] == '\0') {
    my_free(_ALLOC_ID_, &result);
    size = 0;
    return NULL;
  }
  rep_len = strlen(rep);
  with_len = strlen(with);
  dbg(1, "str_replace(): %s, %s, %s\n", s, rep, with);
  if( size == 0 ) {
    size = CADCHUNKALLOC;
    my_realloc(_ALLOC_ID_, &result, size);
  }
  while(*s) {
    STR_ALLOC(&result, result_pos + with_len + 1, &size);

    cond = (count == -1 || replacements < count)  &&
           ((s == str) || ((*(s - 1) != escape))) &&
           (!strncmp(s, rep, rep_len));
    if(cond) {
      my_strncpy(result + result_pos, with, with_len + 1);
      result_pos += with_len;
      s += rep_len;
      replacements++;
    } else {
      result[result_pos++] = *s++;
    }
  }
  result[result_pos] = '\0';
  dbg(1, "str_replace(): returning %s\n", result);
  return result;
}
