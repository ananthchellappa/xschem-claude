#!/usr/bin/env python3
"""Unit tests for migrate_pin_names.py (Cadence pin-owned-name-text migration).

Run:  python3 -m pytest tools/migrate/test_migrate_pin_names.py
  or: python3 tools/migrate/test_migrate_pin_names.py
"""

import contextlib
import io
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import migrate_pin_names as M


def sym(body, ktype='subcircuit'):
    head = ("v {xschem version=3.4.8RC file_version=1.3}\n"
            "G {}\n"
            "K {type=%s}\n"
            "V {}\n"
            "S {}\n"
            "E {}\n" % ktype)
    return head + body


def mig(body, **kw):
    """migrate_text(sym(body)) -> (new_text, stats)."""
    return M.migrate_text(sym(body), M.Opts(**kw))


class TestScanner(unittest.TestCase):
    def test_braced_escape_and_newline(self):
        # a T text with escaped braces + an embedded newline must not derail the scan
        body = ("B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"
                "T {a \\{b\\} c\nsecond line} 5 5 0 0 0.2 0.2 {}\n")
        recs = M.scan_records(sym(body))
        ts = [r for r in recs if r.tag == 'T']
        self.assertEqual(len(ts), 1)
        self.assertEqual(ts[0].fields[0].content, 'a {b} c\nsecond line')

    def test_polygon_and_unknown_tag(self):
        recs = M.scan_records(sym("P 4 3 0 0 10 0 10 10 {}\n"))
        self.assertTrue(any(r.tag == 'P' for r in recs))
        with self.assertRaises(M.ParseError):
            M.scan_records("Z 1 2 3\n")   # unknown tag


class TestGetTok(unittest.TestCase):
    def test_basic_and_quoted(self):
        self.assertEqual(M.get_tok('name=PLUS dir=in', 'name'), (True, 'PLUS'))
        self.assertEqual(M.get_tok('name=PLUS dir=in', 'dir'), (True, 'in'))
        self.assertEqual(M.get_tok('a=1 name="x y" b=2', 'name'), (True, 'x y'))
        self.assertEqual(M.get_tok('dir=in', 'name'), (False, None))

    def test_no_substring_match(self):
        # 'name' must not match 'pinname' / 'sim_pinnumber'
        self.assertEqual(M.get_tok('sim_pinnumber=5 dir=in', 'name'), (False, None))
        self.assertEqual(M.get_tok('show_pinname=true', 'pinname'), (False, None))


class TestAdopt(unittest.TestCase):
    def test_adopt_folds_geometry_and_drops_label(self):
        body = ("B 5 -62.5 -32.5 -57.5 -27.5 {name=PLUS dir=in}\n"
                "T {PLUS} -38.75 -30.25 0 0 0.2 0.2 {}\n"
                "T {@name} 0 0 0 0 0.2 0.2 {}\n")
        out, st = mig(body)
        self.assertEqual(st['status'], 'migrated')
        self.assertEqual((st['adopted'], st['created']), (1, 0))
        # pin center (-60,-30); label (-38.75,-30.25) -> dx=21.25 dy=-0.25
        self.assertIn('show_pinname=true name_dx=21.25 name_dy=-0.25 name_size=0.2', out)
        self.assertNotIn('T {PLUS}', out)     # adopted label dropped
        self.assertIn('T {@name}', out)       # @-text untouched

    def test_adopt_rot_flip_font(self):
        body = ("B 5 -2.5 -2.5 2.5 2.5 {name=A dir=out}\n"
                "T {A} 10 0 1 1 0.3 0.3 {font=Sans}\n")
        out, st = mig(body)
        self.assertEqual(st['adopted'], 1)
        self.assertIn('name_rot=1', out)
        self.assertIn('name_flip=1', out)
        self.assertIn('name_font=Sans', out)
        self.assertIn('name_size=0.3', out)

    def test_bus_name_adopt(self):
        body = ("B 5 -152.5 -22.5 -147.5 -17.5 {name=DIN[width-1:0] dir=in}\n"
                "T {DIN[width-1:0]} -125 -20 0 0 0.2 0.2 {}\n")
        out, st = mig(body)
        self.assertEqual(st['adopted'], 1)
        self.assertNotIn('T {DIN[width-1:0]}', out)
        self.assertIn('name=DIN[width-1:0]', out)   # pin name preserved verbatim

    def test_no_adopt_flag_creates(self):
        body = ("B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"
                "T {A} 10 0 0 0 0.2 0.2 {}\n")
        out, st = mig(body, adopt=False)
        self.assertEqual((st['adopted'], st['created']), (0, 1))
        self.assertIn('show_pinname=false', out)   # created hidden
        self.assertIn('T {A}', out)                # label left in place

    def test_case_mismatch_does_not_adopt(self):
        # the nmos4 D/d case: T {D} must NOT be adopted by pin name=d
        body = ("B 5 -2.5 -2.5 2.5 2.5 {name=d dir=inout}\n"
                "T {D} 25 -27.5 0 0 0.15 0.15 {}\n")
        out, st = mig(body)
        self.assertEqual((st['adopted'], st['created']), (0, 1))
        self.assertIn('T {D}', out)                # stray label preserved

    def test_at_label_not_adopted(self):
        body = ("B 5 -2.5 -2.5 2.5 2.5 {name=OUT dir=out}\n"
                "T {@#OUT:net_name} 10 0 0 0 0.2 0.2 {layer=15}\n")
        out, st = mig(body)
        self.assertEqual((st['adopted'], st['created']), (0, 1))
        self.assertIn('T {@#OUT:net_name}', out)


class TestCreate(unittest.TestCase):
    def test_create_defaults_match_create_pin(self):
        body = ("B 5 -2.5 -2.5 2.5 2.5 {name=IN dir=in}\n"
                "B 5 -2.5 17.5 2.5 22.5 {name=OUT dir=out}\n")
        out, st = mig(body)
        self.assertEqual((st['created'], st['adopted']), (2, 0))
        # in-pin: dx=+25 no flip; out-pin: dx=-25 flip=1  (matches create_pin). Tokens are
        # prepended (just after '{') so a trailing empty-valued token can't swallow them;
        # name=/dir= are preserved unchanged.
        self.assertIn('show_pinname=false name_dx=25 name_dy=-5 name_size=0.2', out)
        self.assertIn('name=IN dir=in', out)
        self.assertIn('show_pinname=false name_dx=-25 name_dy=-5 name_size=0.2 name_flip=1', out)
        self.assertIn('name=OUT dir=out', out)

    def test_show_created_flag(self):
        out, st = mig("B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n", show_created=True)
        self.assertIn('show_pinname=true', out)

    def test_default_size(self):
        out, _ = mig("B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n", default_size=0.4)
        self.assertIn('name_size=0.4', out)


class TestSkips(unittest.TestCase):
    def test_zero_pins_skipped(self):
        out, st = mig("L 4 0 0 10 0 {}\n")
        self.assertIsNone(out)
        self.assertEqual(st['reason'], '0 pins')

    def test_label_type_skipped(self):
        out, st = M.migrate_text(
            sym("B 5 -2.5 -2.5 2.5 2.5 {name=p dir=in}\n", ktype='label'),
            M.Opts())
        self.assertIsNone(out)
        self.assertIn('type=label', st['reason'])

    def test_at_templated_pin_name_skipped(self):
        out, st = mig("B 5 -2.5 -2.5 2.5 2.5 {name=@foo dir=in}\n")
        self.assertIsNone(out)           # only pin is @-named -> nothing to do
        self.assertEqual(st['skipped_pins'], 1)

    def test_empty_pin_name_skipped(self):
        out, st = mig('B 5 -2.5 -2.5 2.5 2.5 {name="" dir=in}\n')
        self.assertIsNone(out)
        self.assertEqual(st['skipped_pins'], 1)

    def test_idempotent_already_migrated(self):
        body = ("B 5 -2.5 -2.5 2.5 2.5 "
                "{name=A dir=in show_pinname=true name_dx=25 name_dy=-5 name_size=0.2}\n")
        out, st = mig(body)
        self.assertIsNone(out)           # owned pin -> skipped, nothing to do
        self.assertEqual(st['skipped_pins'], 1)

    def test_full_idempotency_roundtrip(self):
        body = ("B 5 -62.5 -32.5 -57.5 -27.5 {name=PLUS dir=in}\n"
                "T {PLUS} -38.75 -30.25 0 0 0.2 0.2 {}\n")
        once, st1 = mig(body)
        self.assertEqual(st1['status'], 'migrated')
        twice, st2 = M.migrate_text(once, M.Opts())
        self.assertIsNone(twice)         # second run is a no-op
        self.assertEqual(st2['status'], 'skip')


class TestDuplicateNames(unittest.TestCase):
    def test_nearest_binding_and_warning(self):
        # two pins both name=A; two labels {A}; each binds to its nearest
        body = ("B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"
                "B 5 97.5 -2.5 102.5 2.5 {name=A dir=in}\n"
                "T {A} 20 0 0 0 0.2 0.2 {}\n"
                "T {A} 120 0 0 0 0.2 0.2 {}\n")
        out, st = mig(body)
        self.assertEqual(st['adopted'], 2)
        self.assertTrue(any('duplicate pin names' in w for w in st['warnings']))
        self.assertNotIn('T {A}', out)   # both labels adopted


class TestNetlistInvariance(unittest.TestCase):
    def test_name_dir_tokens_unchanged(self):
        body = ("B 5 -2.5 -2.5 2.5 2.5 {name=PLUS dir=in sim_pinnumber=1}\n"
                "T {PLUS} 20 0 0 0 0.2 0.2 {}\n")
        out, _ = mig(body)
        f, v = M.get_tok(
            [r for r in M.scan_records(out)
             if r.tag == 'B'][0].fields[5].content, 'name')
        self.assertEqual((f, v), (True, 'PLUS'))
        self.assertIn('sim_pinnumber=1', out)   # unrelated tokens preserved


class TestFileDriver(unittest.TestCase):
    def _write(self, d, name, body):
        p = os.path.join(d, name)
        with open(p, 'w') as fp:
            fp.write(sym(body))
        return p

    def test_backup_and_write(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._write(d, 'a.sym',
                            "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"
                            "T {A} 20 0 0 0 0.2 0.2 {}\n")
            st = M.migrate_file(p, M.Opts())
            self.assertEqual(st['status'], 'migrated')
            self.assertTrue(os.path.exists(p + '.bak'))
            with open(p) as fp:
                self.assertIn('show_pinname=true', fp.read())

    def test_dry_run_writes_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._write(d, 'a.sym', "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n")
            with open(p) as fp:
                before = fp.read()
            st = M.migrate_file(p, M.Opts(), dry_run=True)
            self.assertEqual(st['status'], 'would-migrate')
            with open(p) as fp:
                self.assertEqual(fp.read(), before)
            self.assertFalse(os.path.exists(p + '.bak'))

    def test_no_backup(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._write(d, 'a.sym', "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n")
            M.migrate_file(p, M.Opts(), backup=False)
            self.assertFalse(os.path.exists(p + '.bak'))

    def test_exclude_and_recursion(self):
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, 'sub'))
            self._write(d, 'keep.sym', "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n")
            self._write(os.path.join(d, 'sub'), 'deep.sym',
                        "B 5 -2.5 -2.5 2.5 2.5 {name=B dir=in}\n")
            self._write(d, 'skip.sym', "B 5 -2.5 -2.5 2.5 2.5 {name=C dir=in}\n")
            paths = list(M.iter_sym_paths([d], recursive=True, excludes=['*skip.sym']))
            base = sorted(os.path.basename(x) for x in paths)
            self.assertEqual(base, ['deep.sym', 'keep.sym'])


class TestFormatting(unittest.TestCase):
    def test_untouched_lines_byte_identical(self):
        body = ("L 4 -20 -10 20 50 {}\n"
                "A 4 0 0 5 0 360 {}\n"
                "B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"
                "T {a note} 5 5 0 0 0.2 0.2 {}\n")
        src = sym(body)
        out, _ = M.migrate_text(src, M.Opts())
        # every line that is not the edited pin must survive verbatim
        for line in ("L 4 -20 -10 20 50 {}", "A 4 0 0 5 0 360 {}", "T {a note} 5 5 0 0 0.2 0.2 {}"):
            self.assertIn(line, out)


class TestReviewFixes(unittest.TestCase):
    """Regressions for the high code-review findings on this tool."""

    def test_multiword_font_quoted(self):   # [0]
        body = ('B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n'
                'T {A} 10 0 0 0 0.2 0.2 {font="Courier New"}\n')
        out, st = mig(body)
        self.assertEqual(st['adopted'], 1)
        self.assertIn('name_font="Courier New"', out)
        pin = [r for r in M.scan_records(out) if r.tag == 'B'][0]
        self.assertEqual(M.get_tok(pin.fields[5].content, 'name_font'), (True, 'Courier New'))

    def test_partial_migration_not_double_tokened(self):   # [1]
        # a stray name_dx without show_pinname -> pin is already "owned", skip (no duplicate)
        out, st = mig("B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in name_dx=30}\n")
        self.assertIsNone(out)
        self.assertEqual(st['skipped_pins'], 1)

    def test_empty_dir_defaults_inout(self):   # [3]
        out, st = mig('B 5 -2.5 -2.5 2.5 2.5 {name=A dir=""}\n')
        self.assertEqual(st['created'], 1)
        self.assertIn('name_dx=-25', out)     # inout -> left side, matches create_pin
        self.assertIn('name_flip=1', out)

    def test_empty_dir_token_does_not_swallow_show_pinname(self):
        # gschem/viewdraw imports have pins ending `... dir=`; tokens must be PREPENDED so the
        # empty dir= value does not eat show_pinname (xschem's tokenizer takes the next token
        # as an empty value's value). The strengthened self-check catches a regression here.
        out, st = mig("B 5 29.9 -0.1 30.1 0.1 {name=NG dir=}\n")
        self.assertEqual(st['status'], 'migrated')
        self.assertEqual(st['created'], 1)
        pin = [r for r in M.scan_records(out) if r.tag == 'B'][0]
        props = pin.fields[5].content
        self.assertEqual(M.get_tok(props, 'show_pinname'), (True, 'false'))
        self.assertEqual(M.get_tok(props, 'dir'), (True, ''))     # dir preserved empty
        self.assertEqual(M.get_tok(props, 'name'), (True, 'NG'))

    def test_unknown_tag_skips_not_errors(self):   # [4]
        out, st = M.migrate_text(
            sym("Z 1 2 3\nB 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"), M.Opts())
        self.assertIsNone(out)
        self.assertEqual(st['status'], 'skip')
        self.assertIn('unparseable', st['reason'])

    def test_anisotropic_label_not_adopted(self):   # [7]
        body = ("B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"
                "T {A} 10 0 0 0 0.3 0.15 {}\n")
        out, st = mig(body)
        self.assertEqual((st['adopted'], st['created']), (0, 1))
        self.assertIn('T {A}', out)           # non-square label preserved verbatim

    def test_styled_label_not_adopted(self):   # [8]
        body = ("B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"
                "T {A} 10 0 0 0 0.2 0.2 {layer=6 hide=instance}\n")
        out, st = mig(body)
        self.assertEqual((st['adopted'], st['created']), (0, 1))
        self.assertIn('layer=6 hide=instance', out)   # styled label kept as a stray note

    def test_font_only_label_is_adopted(self):
        body = ("B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"
                "T {A} 10 0 0 0 0.2 0.2 {font=Sans}\n")
        _out, st = mig(body)
        self.assertEqual(st['adopted'], 1)    # font-only + square IS adoptable

    def test_crlf_and_non_utf8_byte_preserved(self):   # [2][5]
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, 'a.sym')
            raw = (b"v {xschem version=3.4.8RC file_version=1.3}\r\n"
                   b"G {author \xb0C}\r\n"          # 0xB0: a lone non-UTF8 byte
                   b"K {type=subcircuit}\r\n"
                   b"V {}\r\nS {}\r\nE {}\r\n"
                   b"B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\r\n")
            with open(p, 'wb') as fp:
                fp.write(raw)
            st = M.migrate_file(p, M.Opts())
            self.assertEqual(st['status'], 'migrated')
            with open(p, 'rb') as fp:
                got = fp.read()
            self.assertIn(b'\r\n', got)                 # CRLF line endings preserved
            self.assertIn(b'\xb0', got)                 # non-UTF8 byte round-tripped
            self.assertIn(b'show_pinname=false', got)   # the pin was migrated
            self.assertNotIn(b'\r\r', got)              # no doubled CR from the edit
            with open(p + '.bak', 'rb') as fp:
                self.assertEqual(fp.read(), raw)        # .bak is the ORIGINAL bytes verbatim

    def test_bulk_run_exit_zero_with_unparseable(self):   # [4] end-to-end
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'ok.sym'), 'w') as fp:
                fp.write(sym("B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n"))
            with open(os.path.join(d, 'weird.sym'), 'w') as fp:
                fp.write(sym("Z 1 2 3\n"))              # unknown tag -> skip, not error
            rc = M.main(['-r', '--dry-run', d])
            self.assertEqual(rc, 0)


class TestNextStepHint(unittest.TestCase):
    def _run_main(self, argv):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = M.main(argv)
        return rc, buf.getvalue()

    def test_hint_names_the_library_defs(self):
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'library.defs'), 'w') as fp:
                fp.write('DEFINE devices devices\n')
            with open(os.path.join(d, 'a.sym'), 'w') as fp:
                fp.write(sym('B 5 -2.5 -2.5 2.5 2.5 {name=A dir=in}\n'))
            rc, out = self._run_main(['-r', '--dry-run', d])
            self.assertEqual(rc, 0)
            self.assertIn('XSCHEM_LIBRARY_DEFS', out)
            self.assertIn('doc/library_defs.md', out)
            self.assertIn(os.path.join(d, 'library.defs'), out)   # the exact registry file

    def test_no_hint_when_nothing_migrated(self):
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, 'a.sym'), 'w') as fp:   # already owned -> skipped
                fp.write(sym('B 5 -2.5 -2.5 2.5 2.5 '
                             '{name=A dir=in show_pinname=false name_dx=25}\n'))
            _rc, out = self._run_main(['-r', '--dry-run', d])
            self.assertNotIn('XSCHEM_LIBRARY_DEFS', out)


if __name__ == '__main__':
    unittest.main(verbosity=2)
