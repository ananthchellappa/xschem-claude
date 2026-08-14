/* doc/codex/issues/0066 -- does the netlist-read guard survive a fatal read?
 *
 * doc/codex/issues/0061 stopped a loaded plot's environment from answering
 * cp_getvar() while a netlist is being read, with a depth count raised and
 * lowered by inp_readall() (src/frontend/inpcom.c).  A netlist read that ends
 * fatally never returns through inp_readall(), so it never lowers the count.
 * In the standalone binary that does not matter -- controlled_exit() calls
 * exit() and the process is gone -- but in a --with-ngshared build it calls
 * shared_exit() (src/frontend/error.c), which discards the stack and hands
 * control back to the host, and the count stays raised for the rest of the
 * host process.  plot_cur->pl_env then answers nothing, ever again.
 *
 * NO TEST UNDER tests/ CAN PIN THIS.  Nothing there links libngspice, and
 * build-ver_50 is not a shared build, so `make check` never executes
 * shared_exit() at all.  This probe is the pin.
 *
 * Build and run (from the repo root):
 *
 *     mkdir -p build-shared && cd build-shared && ../configure --with-ngshared
 *     make -j8 && cd ..
 *     gcc -g -O0 -o /tmp/netlist_guard_probe \
 *         doc/claude/feedback/ngspice_upstream/repro/shared/netlist_guard_probe.c \
 *         -I src/include -L build-shared/src/.libs -lngspice
 *     cd /tmp
 *     for m in command circ bg; do
 *         LD_LIBRARY_PATH=$OLDPWD/build-shared/src/.libs \
 *         SPICE_SCRIPTS=$OLDPWD/build-shared/src \
 *             /tmp/netlist_guard_probe $m || echo "FAILED $m"
 *     done
 *
 * One mode per process, because a fatal read leaves the library asking to be
 * reset or detached and the modes must not contaminate each other.  Each mode
 * is a different way for a fatal read to leave inp_readall():
 *
 *     command   ngSpice_Command("source bad.cir")  -> longjmp to errbufc
 *     circ      ngSpice_Circ(deck with bad include) -> longjmp to errbufm
 *     bg        ngSpice_Command("bg_source bad.cir") -> pthread_exit, which
 *               lands at neither setjmp; this is why the fix is in
 *               shared_exit() and not at the two landing sites
 *
 * Each run makes two assertions, and the first is a positive control, so that
 * simply deleting the guard fails this probe rather than passing it:
 *
 *     HELD      a loaded 'Option: casemode=preserve' does not reconfigure the
 *               next read -- the mixed-case net comes back folded.  This is
 *               0061 criterion 1, measured in the shared build, which 0061
 *               could not do.
 *     RESTORED  with a loaded 'Option: nosort' plot current, `display` lists
 *               the file's own order both before and after the fatal read.
 *               Before the fix it listed file order, then sorted order.
 *
 * Exit 0 if both hold, 1 otherwise, and the whole captured session is printed
 * so a failure can be read rather than guessed at.  Measured 2026-08-13 on
 * ver_50: all three modes GUARD-STUCK before the shared_exit() line, all three
 * GUARD-OK after it.
 *
 * The four input files are written by the probe itself into the current
 * directory, so nothing has to be kept beside this file for it to run.
 *
 * NOTHING HERE IS COMMITTED, this probe included: doc/claude/feedback/ is
 * untracked in its entirety and is a working directory, not a fixture.  An
 * earlier version of this header implied otherwise by saying only that the
 * inputs were not committed.  If this probe is to survive as 0066's pin it has
 * to be added to the tree deliberately; until then it lives or dies with the
 * working copy.  (The *.raw inputs would want excluding in any case -- a
 * rawfile carries a wall-clock Date: -- which is what this directory's
 * .gitignore is for.)
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "ngspice/sharedspice.h"

/* The whole session, in delivery order.  It is parsed after the fact and not
   as it arrives, because without low_latency the shared build hands output to
   a printsend thread: the order of the messages is kept, their timing
   relative to the ngSpice_Command() that caused them is not.  So the phases
   are marked in band, with `echo`, rather than by a flag around the call. */

static char cap[1 << 20];
static size_t caplen;

static int cb_char(char *s, int i, void *p)
{
    (void) i; (void) p;
    if (caplen + strlen(s) + 2 < sizeof cap)
        caplen += (size_t) sprintf(cap + caplen, "%s\n", s);
    return 0;
}

static int cb_exit(int status, NG_BOOL immediate, NG_BOOL exit_upon_quit,
        int id, void *p)
{ (void) status; (void) immediate; (void) exit_upon_quit; (void) id; (void) p;
  return 0; }

/* Supplied because shared_exit() calls bgtr() through an unchecked pointer
   where it checks ngexit(); a NULL here segfaults the 'bg' mode before it can
   measure anything.  Unrelated to this issue and left alone. */

static int cb_bgrun(NG_BOOL noruns, int id, void *p)
{ (void) noruns; (void) id; (void) p; return 0; }

static char d0[] = "* fatal read through ngSpice_Circ";
static char d1[] = ".include ngp_no_such_file.inc";
static char d2[] = "vs in 0 dc 1";
static char d3[] = "r1 in 0 1k";
static char d4[] = ".op";
static char d5[] = ".end";
static char *baddeck[] = { d0, d1, d2, d3, d4, d5, NULL };

static void write_file(const char *name, const char *body)
{
    FILE *fp = fopen(name, "w");
    if (!fp) { perror(name); exit(2); }
    fputs(body, fp);
    fclose(fp);
}

static void write_inputs(void)
{
    /* An operating point with two vectors filed in an order that is not the
       sorted one: sorted is i(vs) then v(in), so file order is the visible
       difference and 'Option: nosort' is what selects it.  Hand-written
       rather than produced by a run, so that the vector order is fixed by
       this file and not by whatever the writer happens to emit. */
    write_file("ngp_guard.raw",
            "Title: netlist-read guard probe\n"
            "Date: Thu Aug 13 00:00:00  2026\n"
            "Plotname: Operating Point\n"
            "Option: nosort\n"
            "Flags: real\n"
            "No. Variables: 2\n"
            "No. Points: 1\n"
            "Variables:\n"
            "\t0\tv(in)\tvoltage\n"
            "\t1\ti(vs)\tcurrent\n"
            "Values:\n"
            " 0\t1.000000000000000e+00\n"
            "\t-1.000000000000000e-03\n");

    /* The positive control's header: the key 0061 was filed about. */
    write_file("ngp_case.raw",
            "Title: netlist-read guard probe, case key\n"
            "Date: Thu Aug 13 00:00:00  2026\n"
            "Plotname: Operating Point\n"
            "Option: casemode=preserve\n"
            "Flags: real\n"
            "No. Variables: 1\n"
            "No. Points: 1\n"
            "Variables:\n"
            "\t0\tv(a)\tvoltage\n"
            "Values:\n"
            " 0\t1.000000000000000e+00\n");

    /* The net is spelled MidNode: folded it comes back 'midnode', preserved
       it comes back 'MidNode'.  Same shape as repro/mix.cir one level up. */
    write_file("ngp_mix.cir",
            "* mixed-case net probe -- the net is spelled MidNode\n"
            "Vs In 0 DC 3\n"
            "Rl In MidNode 1k\n"
            "Rg MidNode 0 3k\n"
            ".control\n"
            "op\n"
            "display\n"
            ".endc\n"
            ".end\n");

    write_file("ngp_bad.cir",
            "* fatal read: the include does not exist\n"
            ".include ngp_no_such_file.inc\n"
            "vs in 0 dc 1\n"
            "r1 in 0 1k\n"
            ".op\n"
            ".end\n");
}

/* Everything the session printed after the named marker. */
static const char *after(const char *marker)
{
    const char *m = strstr(cap, marker);
    return m ? m + strlen(marker) : NULL;
}

/* 1 if the guard's plot is listed in file order (so 'nosort' was answered),
   0 if in sorted order, -1 if the two vectors were not both found. */
static int file_order(const char *from)
{
    const char *v, *i;
    if (!from) return -1;
    v = strstr(from, "v(in)");
    i = strstr(from, "i(vs)");
    if (!v || !i) return -1;
    return v < i;
}

int main(int argc, char **argv)
{
    const char *mode = argc > 1 ? argv[1] : "command";
    const char *ctl;
    int held, before, aft, fatal_first, ok;

    write_inputs();

    ngSpice_Init(cb_char, NULL, cb_exit, NULL, NULL, cb_bgrun, NULL);

    /* Positive control: the guard is up during a read that succeeds. */
    ngSpice_Command("echo ==CONTROL==");
    ngSpice_Command("load ngp_case.raw");
    ngSpice_Command("source ngp_mix.cir");

    /* Then make the nosort plot current and photograph it either side of a
       fatal read.  The fatal read files no plot of its own, so the same plot
       is current at both display points. */
    ngSpice_Command("load ngp_guard.raw");
    ngSpice_Command("echo ==BEFORE==");
    ngSpice_Command("display");

    if (!strcmp(mode, "circ"))
        ngSpice_Circ(baddeck);
    else if (!strcmp(mode, "bg")) {
        ngSpice_Command("bg_source ngp_bad.cir");
        usleep(3000000);        /* the thread dies; there is nothing to join */
    }
    else
        ngSpice_Command("source ngp_bad.cir");

    ngSpice_Command("echo ==AFTER==");
    ngSpice_Command("display");
    usleep(500000);             /* let the printsend thread drain */

    ctl = after("==CONTROL==");
    {
        const char *end = ctl ? strstr(ctl, "==BEFORE==") : NULL;
        const char *hit = ctl ? strstr(ctl, "MidNode") : NULL;
        held = (ctl && end && (!hit || hit > end));
    }
    before = file_order(after("==BEFORE=="));
    aft    = file_order(after("==AFTER=="));
    {
        const char *e = strstr(cap, "ngp_no_such_file.inc");
        const char *m = strstr(cap, "==AFTER==");
        fatal_first = (e && m && e < m);
    }

    fputs(cap, stdout);
    ok = (held && before == 1 && aft == 1 && fatal_first);
    printf("MODE %s  HELD=%d  before=%d after=%d  fatal-before-AFTER=%d  %s\n",
            mode, held, before, aft, fatal_first,
            ok ? "GUARD-OK" : "GUARD-STUCK");
    fflush(stdout);
    return ok ? 0 : 1;
}
