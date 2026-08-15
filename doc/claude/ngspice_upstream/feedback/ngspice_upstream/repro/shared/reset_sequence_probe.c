/* doc/codex/issues/0062 -- which call orders survive.
 *
 * argv[1] is a string of one-letter API calls, executed left to right:
 *
 *     I  ngSpice_Init()      C  ngSpice_Circ(deck)
 *     R  ngSpice_Reset()     X  ngSpice_Command("echo CMD-RAN")
 *
 * An initial ngSpice_Init() is always done first, so "C" is one Init and one
 * Circ.  Prints "== step <letter> ==" before each call and "== survived ==" if
 * it reaches the end; a SIGSEGV is therefore attributable to the last step
 * printed.
 *
 *     gcc -g -O0 -o /tmp/reset_sequence_probe \
 *         doc/claude/feedback/ngspice_upstream/repro/shared/reset_sequence_probe.c \
 *         -I src/include -L build-shared/src/.libs -lngspice
 *     LD_LIBRARY_PATH=build-shared/src/.libs SPICE_SCRIPTS=build-shared/src \
 *         /tmp/reset_sequence_probe CRC
 */

#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "ngspice/sharedspice.h"

static int cb_char(char *s, int i, void *p)
{ (void) i; (void) p; printf("NG| %s\n", s); fflush(stdout); return 0; }

static int cb_exit(int st, NG_BOOL a, NG_BOOL b, int i, void *p)
{ (void) a; (void) b; (void) i; (void) p; printf("EXIT %d\n", st); fflush(stdout); return 0; }

static char l0[] = "* t";
static char l1[] = "v1 in 0 dc 1";
static char l2[] = "r1 in 0 1k";
static char l3[] = ".end";
static char *deck[] = { l0, l1, l2, l3, NULL };

int main(int argc, char **argv)
{
    const char *seq = argc > 1 ? argv[1] : "RC";

    ngSpice_Init(cb_char, NULL, cb_exit, NULL, NULL, NULL, NULL);

    for (const char *c = seq; *c; c++) {
        printf("== step %c ==\n", *c);
        fflush(stdout);
        switch (*c) {
        case 'C': ngSpice_Circ(deck); break;
        case 'R': ngSpice_Reset(); break;
        case 'X': ngSpice_Command("echo CMD-RAN"); break;
        case 'I': ngSpice_Init(cb_char, NULL, cb_exit, NULL, NULL, NULL, NULL); break;
        }
    }
    puts("== survived ==");
    fflush(stdout);
    return 0;
}
