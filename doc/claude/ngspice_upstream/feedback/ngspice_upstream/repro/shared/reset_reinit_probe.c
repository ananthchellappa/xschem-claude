/* doc/codex/issues/0062 -- the smallest program that shows both halves.
 *
 * After ngSpice_Reset() the library is de-initialised: ngSpice_Command()
 * returns 1 without running anything or saying why, and ngSpice_Circ(), which
 * consults no init flag at all, reads the device table that totalreset() has
 * already freed and dies.
 *
 * Build (from the repo root), against a --with-ngshared tree:
 *
 *     mkdir -p build-shared && cd build-shared && ../configure --with-ngshared
 *     make -j8 && cd ..
 *     gcc -g -O0 -o /tmp/reset_reinit_probe \
 *         doc/claude/feedback/ngspice_upstream/repro/shared/reset_reinit_probe.c \
 *         -I src/include -L build-shared/src/.libs -lngspice
 *     LD_LIBRARY_PATH=build-shared/src/.libs SPICE_SCRIPTS=build-shared/src \
 *         /tmp/reset_reinit_probe          # SIGSEGV
 *     LD_LIBRARY_PATH=build-shared/src/.libs SPICE_SCRIPTS=build-shared/src \
 *         /tmp/reset_reinit_probe --reinit # exits 0
 *
 * --reinit adds one ngSpice_Init() call after the reset and nothing else.
 * Both halves go away, which is what identifies the missing half.
 */

#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "ngspice/sharedspice.h"

static int cb_char(char *s, int id, void *p)
{ (void) id; (void) p; printf("NG| %s\n", s); fflush(stdout); return 0; }

static int cb_exit(int st, NG_BOOL a, NG_BOOL b, int id, void *p)
{ (void) a; (void) b; (void) id; (void) p; printf("EXIT %d\n", st); return 0; }

static char l0[] = "* t";
static char l1[] = "v1 in 0 dc 1";
static char l2[] = "r1 in 0 1k";
static char l3[] = ".end";
static char *deck[] = { l0, l1, l2, l3, NULL };

int main(int argc, char **argv)
{
    bool reinit = (argc > 1 && strcmp(argv[1], "--reinit") == 0);

    ngSpice_Init(cb_char, NULL, cb_exit, NULL, NULL, NULL, NULL);
    ngSpice_Reset();

    if (reinit)
        ngSpice_Init(cb_char, NULL, cb_exit, NULL, NULL, NULL, NULL);

    printf("Command rc=%d\n", ngSpice_Command("echo COMMAND-RAN"));
    fflush(stdout);
    printf("Circ rc=%d\n", ngSpice_Circ(deck));
    puts("survived");
    return 0;
}
