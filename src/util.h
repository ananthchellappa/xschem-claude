/* File: util.h
 *
 * Prototypes for the general-purpose memory / string / file / debug utilities
 * in util.c (extracted verbatim from editprop.c; behavior-preserving move).
 * This file is part of XSCHEM. GPLv2 or later; see LICENSE.
 */
#ifndef XSCHEM_UTIL_H
#define XSCHEM_UTIL_H
#include <stdio.h>   /* FILE */
#include <stddef.h>  /* size_t */

/* char classification helpers used by the numeric parsers (my_atof/my_atod
 * here, and the spice/eng variants in editprop.c) */
#define DGT(c) ((c) >= '0' && (c) <= '9')
#define SPC(c) ((c) == ' ' || (c) == '\t')

extern FILE * my_fopen(const char *f, const char *m);
extern char *dtoa(double i);
extern char *my_expand(const char *s, int tabstop) ;
extern char *my_fgets(FILE *fd, size_t *line_len);
extern char *my_free(int id, void *ptr);
extern char *my_itoa(int i);
extern char *my_strcasestr(const char *haystack, const char *needle);
extern char *my_strtok_r(char *str, const char *delim, const char *quote, int keep_quote, char **saveptr);
extern char *str_replace(const char *str, const char *rep, const char *with, int escape, int count);
extern char* strtolower(char* s);
extern char* strtoupper(char* s);
extern double my_atod(const char *p);
extern float my_atof(const char *p);
extern int my_strcasecmp(const char *s1, const char *s2);
extern int my_strncasecmp(const char *s1, const char *s2, size_t n);
extern int my_strncpy(char *d, const char *s, size_t n);
extern int strboolcmp(const char *str, const char *boolean);
extern size_t my_fgets_skip(FILE *fd);
extern size_t my_mstrcat(int id, char **str, const char *append_str, ...);
/* append one key=value attribute, writing an EMPTY value as key="" (issue 0183) */
extern size_t my_mstrcat_tok(int id, char **str, const char *key, const char *value,
                             const char *tail);
extern size_t my_snprintf(char *str, size_t size, const char *fmt, ...);
extern size_t my_strcat(int id, char **, const char *);
extern size_t my_strcat2(int id, char **, const char *);
extern size_t my_strdup(int id, char **dest, const char *src);
extern size_t my_strdup2(int id, char **dest, const char *src);
extern size_t my_strncat(int id, char **str, size_t n, const char *append_str);
extern void *my_calloc(int id, size_t nmemb, size_t size);
extern void *my_malloc(int id, size_t size);
extern void dbg(int level, char *fmt, ...);
extern void snapshot_launch_line(int lc, char **lv);
extern void init_action_log(void);
extern void log_action(const char *fmt, ...);
extern void log_action_noecho(const char *fmt, ...);
/* Outcome-level logging (action_log_absorb.md): stash a provisional select_at,
 * flush the held line, or let `descend` absorb it into one stable line. */
extern void log_action_stash_select_at(double x, double y, int add, int inst);
extern void log_action_flush_pending(void);
extern void log_action_descend(const char *verb, int inst_n, const char *instname);
extern void log_action_argv(int argc, const char *const *argv); /* defined in callback.c */
extern void log_output(int iserr, const char *text);
/* one human-readable outcome line to BOTH sinks: the log file ('#= ' comment)
 * and the CIW pane. Pairs with the log_action() line that carries the command. */
extern void log_action_result(const char *msg);
/* Re-entrant suppress-scope guard for actionlog_suppress (issue 0071 Refactor A
 * step 2): wrap a replay or a composite op so its sub-lines re-EXECUTE but do
 * not re-LOG. Depth counter -> nested scopes stay suppressed until the outermost
 * pop. `xschem log_action -suppress push|pop` (Tcl) and abort_operation (C) use
 * these; `xschem set actionlog_suppress N` is the absolute form. */
extern void actionlog_suppress_push(void);
extern void actionlog_suppress_pop(void);
extern void my_realloc(int id, void *ptr,size_t size);
extern void my_strndup(int id, char **dest, const char *src, size_t n);

#endif
