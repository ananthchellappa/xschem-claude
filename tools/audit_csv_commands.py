#!/usr/bin/env python3
"""Audit actions.csv command fields for common migration bugs.

Usage: python3 tools/audit_csv_commands.py
"""
import csv, re, sys

issues = []

# Load actions.csv, skipping comment lines
with open('src/actions.csv') as f:
    reader = csv.DictReader(line for line in f if not line.startswith('#'))
    rows = list(reader)

# Check for $topwin references in command fields
for row in rows:
    cmd = row.get('command', '').strip()
    if '$topwin' in cmd:
        issues.append(('TOPWIN_REF', row['id'], '', cmd[:80]))

# Check for $selectcolor references
for row in rows:
    cmd = row.get('command', '').strip()
    if '$selectcolor' in cmd:
        issues.append(('SELECTCOLOR_REF', row['id'], '', cmd[:80]))

# Load xschem.tcl for cross-reference
with open('src/xschem.tcl') as f:
    tcl = f.read()

# Check for multi-statement commands in original that lack semicolons in CSV
for row in rows:
    if row.get('type') != 'command':
        continue
    label = row['label']
    cmd = row.get('command', '').strip()
    
    # Find original command block in xschem.tcl by label
    pattern = rf'-label\s+["\']?{re.escape(label)}["\']?\s+.*?-command\s+\{{([^}}]+)\}}'
    m = re.search(pattern, tcl, re.DOTALL)
    if not m:
        continue
    
    orig = m.group(1).strip()
    orig_oneline = ' '.join(orig.split())
    csv_cmd = ' '.join(cmd.split())
    
    # Flag: multiple statements in original without semicolon in CSV
    if '\n' in orig and ';' not in cmd and len(cmd) > 0:
        issues.append(('MISSING_SEMICOLON', row['id'], orig_oneline[:120], csv_cmd[:80]))

for issue in issues:
    print(f'{issue[0]}: {issue[1]}')
    if issue[2]:
        print(f'  orig: {issue[2]}')
    print(f'  csv:  {issue[3]}')
    print()

print(f'Total issues: {len(issues)}')
sys.exit(0 if not issues else 1)
