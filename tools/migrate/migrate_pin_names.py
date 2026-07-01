#!/usr/bin/env python3
"""migrate_pin_names — give xschem symbol pins the Cadence-style owned name text.

Part of the pin-owned-name-text feature (see
doc/claude/specs/cadence_pin_name_text.md, Option B). A migrated `.sym` file has,
on every eligible pin rect (`B 5 ... {...}`), the tokens that the running editor now
writes for a natively-created pin:

    show_pinname=true|false  name_dx=<dx> name_dy=<dy> name_size=<s>
    [name_rot=<r>] [name_flip=<f>] [name_font=<font>]

There is NO separate persisted name `T` record: the displayed name is derived from
these tokens (a synth view in symbol-edit, drawn from tokens on instances). Per the
locked design decisions (spec §3.2.1, §5.2):

  * ADOPT — if a pin has a literal `T {<exactname>}` label (no `@`) sitting near it
    whose text EXACTLY equals the pin's name, fold that label's geometry into the
    pin's name_* tokens, set show_pinname=true, and DROP the `T` record.
  * CREATE — otherwise give the pin default name_* tokens (matching the editor's
    create_pin defaults) and set show_pinname=FALSE (hidden), leaving any
    non-matching legacy text untouched as an ordinary note.
  * SKIP — pins already carrying a show_pinname token (idempotency), @-templated or
    empty names, symbols with 0 pins, and label/logo/title/... symbol types.

Display-only: pin `name=`/`dir=` are never changed, so netlists are byte-identical.

stdlib only. Non-destructive by default (writes FILE.sym.bak first). Idempotent:
re-running is a no-op. Every write is self-checked (the result is re-parsed and the
pin count / token invariants verified) and aborted on any mismatch.

CLI:
    migrate_pin_names.py FILE.sym [FILE2.sym ...]
    migrate_pin_names.py --recursive DIR
    migrate_pin_names.py --dry-run DIR -r         # report only, write nothing
See --help for all options.
"""

import argparse
import fnmatch
import json
import math
import os
import sys

# --------------------------------------------------------------------------- #
# .sym record model + escape-aware scanner (mirrors save.c save/load_ascii_string:
# a {...} field is delimited by the first '{' and the first UNESCAPED '}'; inside,
# '\', '{' and '}' are backslash-escaped, so braces never nest).
# --------------------------------------------------------------------------- #

# per-tag field grammar: 'n' = a whitespace/brace-delimited word (number/tag),
# 's' = an escape-aware {...} braced string. 'P' (polygon) is variable and handled
# specially. 'N'/'C' only occur in schematics but are accepted for robustness.
FIELD_SPECS = {
    'v': ['s'], 'G': ['s'], 'K': ['s'], 'V': ['s'], 'S': ['s'], 'E': ['s'], 'F': ['s'],
    'L': ['n', 'n', 'n', 'n', 'n', 's'],
    'B': ['n', 'n', 'n', 'n', 'n', 's'],
    'A': ['n', 'n', 'n', 'n', 'n', 'n', 's'],
    'T': ['s', 'n', 'n', 'n', 'n', 'n', 'n', 's'],
    'N': ['n', 'n', 'n', 'n', 's'],
    'C': ['s', 'n', 'n', 'n', 'n', 's'],
}

# symbol types (K {type=...}) that are not real pin-bearing cells -> never migrated
SKIP_TYPES = frozenset((
    'label', 'launcher', 'logo', 'probe', 'architecture', 'noconn', 'title',
    'netlist', 'package', 'use', 'only_toplevel',
))


class ParseError(Exception):
    pass


class Field(object):
    __slots__ = ('kind', 'start', 'end', 'text', 'content', 'cstart', 'cend')

    def __init__(self, kind, start, end, text, content, cstart, cend):
        self.kind = kind        # 'n' or 's'
        self.start = start      # raw span [start, end) in the source text
        self.end = end
        self.text = text        # raw substring (for 'n': the word; for 's': {...})
        self.content = content  # decoded inner text ('s' only)
        self.cstart = cstart    # inner-content raw span (between the braces, 's' only)
        self.cend = cend        # index of the closing '}' -> insertion point


class Record(object):
    __slots__ = ('tag', 'start', 'end', 'fields')

    def __init__(self, tag, start, end, fields):
        self.tag = tag
        self.start = start      # index of the tag char (records start at column 0)
        self.end = end          # index just past the last field
        self.fields = fields


def _read_braced(text, i):
    """i is at '{'. Return (Field, next_index)."""
    n = len(text)
    start = i
    i += 1
    cstart = i
    out = []
    esc = False
    while i < n:
        c = text[i]
        if esc:
            out.append(c)
            esc = False
            i += 1
            continue
        if c == '\\':
            esc = True
            i += 1
            continue
        if c == '}':
            f = Field('s', start, i + 1, text[start:i + 1], ''.join(out), cstart, i)
            return f, i + 1
        out.append(c)
        i += 1
    raise ParseError("unterminated {...} string starting at %d" % start)


def _read_word(text, i):
    """i is at the first non-space char. Reads up to whitespace or '{'."""
    n = len(text)
    start = i
    while i < n and not text[i].isspace() and text[i] != '{':
        i += 1
    if i == start:
        raise ParseError("expected a value at %d" % start)
    return Field('n', start, i, text[start:i], None, None, None), i


def _skip_ws(text, i):
    n = len(text)
    while i < n and text[i].isspace():
        i += 1
    return i


def _read_field(text, i, kind):
    i = _skip_ws(text, i)
    if i >= len(text):
        raise ParseError("unexpected end of file while reading a field")
    if kind == 's':
        if text[i] != '{':
            raise ParseError("expected '{' at %d, got %r" % (i, text[i]))
        return _read_braced(text, i)
    return _read_word(text, i)


def scan_records(text):
    """Tokenize a .sym/.sch into Records. Raises ParseError on any unknown tag or
    malformed field so a surprising file is SKIPPED, never corrupted."""
    recs = []
    i = 0
    n = len(text)
    while True:
        i = _skip_ws(text, i)
        if i >= n:
            break
        c = text[i]
        if c == '#':                       # comment: to end of line
            start = i
            while i < n and text[i] != '\n':
                i += 1
            recs.append(Record('#', start, i, []))
            continue
        tag = c
        start = i
        i += 1
        fields = []
        if tag == 'P':                     # polygon: layer npts (2*npts coords) props
            f, i = _read_field(text, i, 'n'); fields.append(f)
            f, i = _read_field(text, i, 'n'); fields.append(f)
            try:
                npts = int(float(f.text))
            except ValueError:
                raise ParseError("bad polygon point count %r" % f.text)
            for _ in range(2 * npts):
                f, i = _read_field(text, i, 'n'); fields.append(f)
            f, i = _read_field(text, i, 's'); fields.append(f)
        else:
            spec = FIELD_SPECS.get(tag)
            if spec is None:
                raise ParseError("unknown record tag %r at %d" % (tag, start))
            for kind in spec:
                f, i = _read_field(text, i, kind)
                fields.append(f)
        end = fields[-1].end if fields else i
        recs.append(Record(tag, start, end, fields))
    return recs


# --------------------------------------------------------------------------- #
# token helpers (a faithful-enough get_tok_value for real symbol props)
# --------------------------------------------------------------------------- #

def get_tok(props, tok):
    """Return (found, value) for `tok=value` in a prop string. Whole-token match;
    handles a quoted value. Mirrors xschem get_tok_value closely enough for the
    simple values (name/dir/type/font/show_pinname) migration reads."""
    i = 0
    n = len(props)
    while i < n:
        while i < n and props[i].isspace():
            i += 1
        if i >= n:
            break
        s = i
        while i < n and not props[i].isspace() and props[i] != '=':
            i += 1
        name = props[s:i]
        if i < n and props[i] == '=':
            i += 1
            while i < n and props[i].isspace():   # value starts at next non-space
                i += 1
            val = []
            if i < n and props[i] == '"':
                i += 1
                while i < n and props[i] != '"':
                    if props[i] == '\\' and i + 1 < n:
                        i += 1
                    val.append(props[i])
                    i += 1
                if i < n:
                    i += 1
            else:
                while i < n and not props[i].isspace():
                    if props[i] == '\\' and i + 1 < n:   # unescape like get_tok_value
                        i += 1
                    val.append(props[i])
                    i += 1
            if name == tok:
                return True, ''.join(val)
        # else: a bare flag token -> skip, keep scanning
    return False, None


def fmt(x):
    """Format a coordinate/size like C's %g (6 sig figs, no trailing zeros); folds
    away tiny float noise from the center/offset subtraction."""
    s = '%g' % x
    if s == '-0':
        s = '0'
    return s


# --------------------------------------------------------------------------- #
# core migration
# --------------------------------------------------------------------------- #

class Opts(object):
    def __init__(self, adopt=True, default_size=0.2, show_created=False,
                 adopt_radius=100.0, verbose=False):
        self.adopt = adopt
        self.default_size = default_size
        self.show_created = show_created
        self.adopt_radius = adopt_radius
        self.verbose = verbose


def _pin_info(rec):
    x1 = float(rec.fields[1].text); y1 = float(rec.fields[2].text)
    x2 = float(rec.fields[3].text); y2 = float(rec.fields[4].text)
    props = rec.fields[5].content
    found_name, name = get_tok(props, 'name')
    found_dir, direction = get_tok(props, 'dir')
    # "owned" == carries any pin-name token, not just show_pinname: a hand-authored or
    # partially-migrated pin with a stray name_* must be skipped, not have a second set
    # of tokens appended (which would leave contradictory duplicates in the prop).
    has_owned = any(get_tok(props, t)[0] for t in
                    ('show_pinname', 'name_dx', 'name_dy', 'name_size',
                     'name_rot', 'name_flip', 'name_font'))
    return {
        'rec': rec,
        'cx': (x1 + x2) / 2.0,
        'cy': (y1 + y2) / 2.0,
        'name': name if found_name else '',
        # match create_pin: an absent OR empty dir defaults to inout (left-side name)
        'dir': direction if (found_dir and direction) else 'inout',
        'has_owned': has_owned,
        # Insertion point = just AFTER the props '{' (prepend), NOT before the '}'. A pin
        # prop may END with an empty-valued token (e.g. `dir=` in gschem/viewdraw imports);
        # appending after it makes xschem's tokenizer read the first appended token as that
        # token's value (get_tok_value: an empty value takes the next token). Prepending puts
        # our tokens ahead of any such trailing empty token so they are always read whole.
        'cstart': rec.fields[5].cstart,
    }


def _prop_token_names(props):
    """The set of token NAMES (the part before '=') present in a prop string."""
    names = set()
    i = 0
    n = len(props)
    while i < n:
        while i < n and props[i].isspace():
            i += 1
        s = i
        while i < n and not props[i].isspace() and props[i] != '=':
            i += 1
        if i > s:
            names.add(props[s:i])
        if i < n and props[i] == '=':          # consume the value (respecting quotes)
            i += 1
            while i < n and props[i].isspace():
                i += 1
            if i < n and props[i] == '"':
                i += 1
                while i < n and props[i] != '"':
                    if props[i] == '\\' and i + 1 < n:
                        i += 1
                    i += 1
                if i < n:
                    i += 1
            else:
                while i < n and not props[i].isspace():
                    i += 1
    return names


def _label_info(rec):
    hsize = float(rec.fields[5].text)
    vsize = float(rec.fields[6].text)
    props = rec.fields[7].content
    # Only adopt a PLAIN label: square scale + no props the name_* model cannot represent
    # (the model carries size/offset/rot/flip/font only). A label on a custom layer, with
    # hide=, a color/style, or a non-square scale is left untouched as a stray note so the
    # symbol's appearance is preserved exactly; the pin then gets a hidden created name.
    adoptable = (abs(hsize - vsize) <= 1e-9
                 and _prop_token_names(props) <= {'font'})
    return {
        'rec': rec,
        'content': rec.fields[0].content,
        'tx': float(rec.fields[1].text),
        'ty': float(rec.fields[2].text),
        'rot': int(round(float(rec.fields[3].text))),
        'flip': int(round(float(rec.fields[4].text))),
        'hsize': hsize,
        'vsize': vsize,
        'props': props,
        'adoptable': adoptable,
        'adopted': False,
    }


def _create_tokens(pin, opts):
    """Default name_* tokens for a pin with no adoptable label (matches the editor's
    create_pin: in-pins name on the right dx=+25; out/inout on the left dx=-25 flip)."""
    flip = 1 if pin['dir'] in ('out', 'inout') else 0
    dx = -25.0 if flip else 25.0
    show = 'true' if opts.show_created else 'false'
    parts = ['show_pinname=' + show, 'name_dx=' + fmt(dx), 'name_dy=' + fmt(-5.0),
             'name_size=' + fmt(opts.default_size)]
    if flip:
        parts.append('name_flip=1')
    return ' '.join(parts)


def _tokval(name, value):
    """A `name=value` token, quoting the value if it contains whitespace so a multi-word
    value (e.g. a font 'Courier New') stays a single token that get_tok_value reads whole."""
    if value and any(c.isspace() for c in value):
        return '%s="%s"' % (name, value.replace('\\', '\\\\').replace('"', '\\"'))
    return '%s=%s' % (name, value)


def _adopt_tokens(pin, label):
    """Fold a matched PLAIN literal label's geometry into name_* tokens (offset relative to
    the pin center; size/rot/flip/font from the label). Only square, style-free labels reach
    here (see _label_info.adoptable), so hsize==vsize and there are no props but font=."""
    dx = label['tx'] - pin['cx']
    dy = label['ty'] - pin['cy']
    parts = ['show_pinname=true', 'name_dx=' + fmt(dx), 'name_dy=' + fmt(dy),
             'name_size=' + fmt(label['hsize'])]
    if label['rot']:
        parts.append('name_rot=' + str(label['rot']))
    if label['flip']:
        parts.append('name_flip=' + str(label['flip']))
    found_font, font = get_tok(label['props'], 'font')
    if found_font and font:
        parts.append(_tokval('name_font', font))
    return ' '.join(parts)


def _delete_line_edit(text, rec):
    """An edit tuple that removes a whole record line (its trailing spaces + newline,
    tolerating a CRLF '\\r\\n' line ending)."""
    j = rec.end
    n = len(text)
    while j < n and text[j] in ' \t\r':
        j += 1
    if j < n and text[j] == '\n':
        j += 1
    return (rec.start, j, '')


def _apply_edits(text, edits):
    for start, end, repl in sorted(edits, key=lambda e: e[0], reverse=True):
        text = text[:start] + repl + text[end:]
    return text


def migrate_text(text, opts, fname='<mem>'):
    """Return (new_text_or_None, stats). new_text is None when the file is skipped
    (nothing to do); stats always has a 'status' key."""
    st = {'file': fname, 'status': 'skip', 'reason': '', 'created': 0, 'adopted': 0,
          'skipped_pins': 0, 'warnings': []}
    try:
        recs = scan_records(text)
    except ParseError as e:
        # an unknown/unsupported record (e.g. an LCC/embedded-symbol '[...]' block) or a
        # malformed field: leave the file untouched and SKIP it -- not an error, so a bulk
        # --recursive run does not fail its exit code over files it correctly declines.
        st['reason'] = 'unparseable (left untouched): %s' % e
        return None, st

    ktype = None
    for r in recs:
        if r.tag == 'K':
            found, ktype = get_tok(r.fields[0].content, 'type')
            break
    pins = [_pin_info(r) for r in recs
            if r.tag == 'B' and r.fields[0].text.strip() == '5']
    labels = [_label_info(r) for r in recs if r.tag == 'T']

    if not pins:
        st['reason'] = '0 pins'
        return None, st
    if ktype and ktype in SKIP_TYPES:
        st['reason'] = 'type=%s' % ktype
        return None, st

    names = [p['name'] for p in pins if p['name']]
    dups = sorted({nm for nm in names if names.count(nm) > 1})
    if dups:
        st['warnings'].append('duplicate pin names (bound to nearest label): '
                              + ', '.join(dups))

    already_owned = 0
    edits = []
    for p in pins:
        if p['has_owned']:                         # already carries pin-name tokens -> skip
            st['skipped_pins'] += 1
            already_owned += 1
            continue
        name = p['name']
        if not name or '@' in name:                # @-templated / empty -> leave legacy
            st['skipped_pins'] += 1
            if opts.verbose:
                st['warnings'].append("skipped pin (empty/@ name): %r" % name)
            continue
        chosen = None
        if opts.adopt:
            best = None
            bestd = None
            for L in labels:
                if (L['adopted'] or not L['adoptable']
                        or '@' in L['content'] or L['content'] != name):
                    continue
                d = math.hypot(L['tx'] - p['cx'], L['ty'] - p['cy'])
                if d <= opts.adopt_radius and (bestd is None or d < bestd):
                    best, bestd = L, d
            chosen = best
        if chosen is not None:
            chosen['adopted'] = True
            toks = _adopt_tokens(p, chosen)
            edits.append((p['cstart'], p['cstart'], toks + ' '))
            edits.append(_delete_line_edit(text, chosen['rec']))
            st['adopted'] += 1
            if opts.verbose:
                st['warnings'].append("adopt '%s' <- label" % name)
        else:
            toks = _create_tokens(p, opts)
            edits.append((p['cstart'], p['cstart'], toks + ' '))
            st['created'] += 1
            if opts.verbose:
                st['warnings'].append("create '%s' (hidden)" % name)

    if st['created'] == 0 and st['adopted'] == 0:
        st['reason'] = 'nothing to do (all pins already migrated/skipped)'
        return None, st

    new_text = _apply_edits(text, edits)

    # self-check: the result must still parse, keep the same pin count, and carry exactly
    # one show_pinname token per (already-owned + created + adopted) pin -- i.e. every pin
    # we touched is now owned, with no token duplicated. Abort the write on any mismatch.
    try:
        vrecs = scan_records(new_text)
    except ParseError as e:
        st['status'] = 'error'
        st['reason'] = 'self-check parse failed: %s' % e
        return None, st
    vpins = [r for r in vrecs if r.tag == 'B' and r.fields[0].text.strip() == '5']
    if len(vpins) != len(pins):
        st['status'] = 'error'
        st['reason'] = ('self-check pin-count mismatch (%d -> %d)'
                        % (len(pins), len(vpins)))
        return None, st
    want_owned = already_owned + st['created'] + st['adopted']
    got_owned = 0
    for r in vpins:
        props = r.fields[5].content
        if get_tok(props, 'show_pinname')[0]:
            got_owned += 1
        # a created/adopted pin must not have ended up with duplicate name_size tokens
        if props.count('name_size=') > 1 or props.count('show_pinname=') > 1:
            st['status'] = 'error'
            st['reason'] = 'self-check found duplicate name tokens'
            return None, st
    if got_owned != want_owned:
        st['status'] = 'error'
        st['reason'] = ('self-check show_pinname count %d != expected %d'
                        % (got_owned, want_owned))
        return None, st

    st['status'] = 'migrated'
    return new_text, st


# --------------------------------------------------------------------------- #
# file / tree driver
# --------------------------------------------------------------------------- #

# Byte-faithful text I/O: surrogateescape lets any non-UTF8 byte round-trip through a str
# losslessly (xschem itself reads such files fine), and newline='' disables universal-newline
# translation so a CRLF file's line endings are preserved -- both required for the
# "untouched records byte-identical" / non-destructive (.bak) guarantees.
_ENC = 'utf-8'
_ERRS = 'surrogateescape'


def migrate_file(path, opts, dry_run=False, backup=True):
    st = {'file': path, 'status': 'skip', 'reason': '', 'created': 0, 'adopted': 0,
          'skipped_pins': 0, 'warnings': []}
    try:
        with open(path, 'r', encoding=_ENC, errors=_ERRS, newline='') as fp:
            text = fp.read()
    except (IOError, OSError) as e:
        st['status'] = 'error'
        st['reason'] = 'read failed: %s' % e
        return st

    new_text, st = migrate_text(text, opts, fname=path)
    if st['status'] != 'migrated':
        return st
    if dry_run:
        st['status'] = 'would-migrate'
        return st
    try:
        if backup:                                       # back up the ORIGINAL bytes verbatim
            with open(path + '.bak', 'w', encoding=_ENC, errors=_ERRS, newline='') as fp:
                fp.write(text)
        tmp = path + '.tmp'
        with open(tmp, 'w', encoding=_ENC, errors=_ERRS, newline='') as fp:
            fp.write(new_text)
        os.replace(tmp, path)
    except (IOError, OSError) as e:
        st['status'] = 'error'
        st['reason'] = 'write failed: %s' % e
    return st


def iter_sym_paths(paths, recursive, excludes):
    def excluded(p):
        return any(fnmatch.fnmatch(p, g) or fnmatch.fnmatch(os.path.basename(p), g)
                   for g in excludes)
    for p in paths:
        if os.path.isdir(p):
            if recursive:
                for root, _dirs, files in os.walk(p):
                    for fn in sorted(files):
                        if fn.endswith('.sym'):
                            fp = os.path.join(root, fn)
                            if not excluded(fp):
                                yield fp
            else:
                for fn in sorted(os.listdir(p)):
                    fp = os.path.join(p, fn)
                    if fn.endswith('.sym') and os.path.isfile(fp) and not excluded(fp):
                        yield fp
        elif os.path.isfile(p):
            if p.endswith('.sym') and not excluded(p):
                yield p
            else:
                sys.stderr.write("skip (not a .sym): %s\n" % p)
        else:
            sys.stderr.write("skip (not found): %s\n" % p)


def main(argv=None):
    ap = argparse.ArgumentParser(
        description='Migrate xschem symbol pins to Cadence-style owned name text.')
    ap.add_argument('paths', nargs='+', metavar='PATH', help='.sym file(s) or directory')
    ap.add_argument('-r', '--recursive', action='store_true',
                    help='recurse into directories')
    ap.add_argument('-n', '--dry-run', action='store_true',
                    help='report only, write nothing')
    ap.add_argument('--no-backup', dest='backup', action='store_false',
                    help='do not write FILE.sym.bak before editing')
    ap.add_argument('--no-adopt', dest='adopt', action='store_false',
                    help='never adopt existing literal labels; always create hidden names')
    ap.add_argument('--default-size', type=float, default=0.2,
                    help='name_size for created (non-adopted) names (default 0.2). Set this '
                         'to your xschemrc sym_pin_name_size if you changed it, so migrated '
                         'names match ones the editor creates.')
    ap.add_argument('--show-created', action='store_true',
                    help='make created (non-adopted) names visible (default: hidden)')
    ap.add_argument('--adopt-radius', type=float, default=100.0,
                    help='max distance to bind a label to a pin (default 100)')
    ap.add_argument('--exclude', action='append', default=[], metavar='GLOB',
                    help='skip matching paths (repeatable)')
    ap.add_argument('--report', metavar='FILE', help='write a JSON summary to FILE')
    ap.add_argument('-v', '--verbose', action='store_true',
                    help='log per-pin actions')
    args = ap.parse_args(argv)

    opts = Opts(adopt=args.adopt, default_size=args.default_size,
                show_created=args.show_created, adopt_radius=args.adopt_radius,
                verbose=args.verbose)

    results = []
    tot = {'migrated': 0, 'would-migrate': 0, 'skip': 0, 'error': 0,
           'created': 0, 'adopted': 0}
    for path in iter_sym_paths(args.paths, args.recursive, args.exclude):
        st = migrate_file(path, opts, dry_run=args.dry_run, backup=args.backup)
        results.append(st)
        tot[st['status']] = tot.get(st['status'], 0) + 1
        tot['created'] += st['created']
        tot['adopted'] += st['adopted']
        if st['status'] in ('migrated', 'would-migrate'):
            tag = 'DRY ' if st['status'] == 'would-migrate' else ''
            print('%s%s: +%d created, +%d adopted, %d skipped'
                  % (tag, path, st['created'], st['adopted'], st['skipped_pins']))
            for w in st['warnings']:
                print('    - %s' % w)
        elif st['status'] == 'error':
            sys.stderr.write('ERROR %s: %s\n' % (path, st['reason']))
        elif args.verbose:
            print('skip %s: %s' % (path, st['reason']))

    print('\n%d migrated, %d skipped, %d errors; %d names created, %d adopted'
          % (tot['migrated'] + tot['would-migrate'], tot['skip'], tot['error'],
             tot['created'], tot['adopted']))

    if args.report:
        with open(args.report, 'w', encoding='utf-8') as fp:
            json.dump({'totals': tot, 'files': results}, fp, indent=2)

    return 1 if tot['error'] else 0


if __name__ == '__main__':
    sys.exit(main())
