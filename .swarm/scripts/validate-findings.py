#!/usr/bin/env python3
"""validate-findings, called by swarm.sh.

Mirrors the validate-findings verb in swarm.ps1 check for check, with the same
messages and exit codes, so the two platforms agree. If you change a rule,
change it in both places.

Usage: validate-findings.py <task> <swarm-dir>
Exit 0 valid, 1 invalid, 2 file missing or not parseable.
"""
import json
import os
import re
import sys

SEV = ['BLOCKER', 'HIGH', 'MEDIUM', 'LOW']
CLS = ['code_defect', 'test_defect', 'env_or_dependency', 'flaky', 'spec_ambiguity', 'architectural']
VERD = ['APPROVED', 'APPROVED WITH NOTES', 'CHANGES_REQUIRED', 'BLOCKED']


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def is_str(v, lo, hi):
    return isinstance(v, str) and lo <= len(v) <= hi


def matches(pattern, v):
    return isinstance(v, str) and re.fullmatch(pattern, v) is not None


def test_keys(o, path, req, opt, errs):
    if not isinstance(o, dict):
        errs.append(f"{path} must be an object")
        return False
    ok = True
    for k in req:
        if k not in o:
            errs.append(f"{path} missing required key: {k}")
            ok = False
    for n in o:
        if n not in req and n not in opt:
            errs.append(f"{path} has unknown key: {n}")
    return ok


def test_loc(loc, path, errs):
    if not test_keys(loc, path, ['file'], ['line'], errs):
        return
    if not is_str(loc['file'], 1, 1000):
        errs.append(f"{path}.file must be a non-empty string")
    if 'line' in loc:
        if not (is_int(loc['line']) and loc['line'] >= 1):
            errs.append(f"{path}.line must be an integer >= 1")


def unique(items):
    seen = set()
    out = []
    for i in items:
        if i not in seen:
            seen.add(i)
            out.append(i)
    return out


def main():
    if len(sys.argv) != 3:
        print("ERROR: usage: validate-findings.py <task> <swarm-dir>")
        return 2
    task, swarm = sys.argv[1], sys.argv[2]
    review_dir = os.path.join(swarm, 'reviews')
    ff = os.path.join(review_dir, f"{task}.findings.json")
    rf = os.path.join(review_dir, f"{task}.md")
    if not os.path.isfile(ff):
        print(f"ERROR: no findings file at {ff}")
        return 2
    try:
        with open(ff, encoding='utf-8-sig') as fh:
            fd = json.load(fh)
    except (ValueError, OSError) as e:
        print(f"ERROR: {ff} is not valid JSON: {e}")
        return 2

    errs, warns = [], []
    tally = {s: 0 for s in SEV}
    n_find, rnd, verdict = 0, 0, ''
    ids, sigs = {}, {}

    top_req = ['schema', 'task', 'review_round', 'head', 'verdict', 'counts',
               'findings', 'suggestions', 'prior_findings']
    if test_keys(fd, 'file', top_req, [], errs):
        if not (is_int(fd['schema']) and fd['schema'] == 1):
            errs.append('schema must be 1')
        if fd['task'] != task:
            errs.append(f"task is '{fd['task']}' but this review is for '{task}'")
        if not (is_int(fd['review_round']) and fd['review_round'] >= 1):
            errs.append('review_round must be an integer >= 1')
        else:
            rnd = fd['review_round']
        if not matches(r'[0-9a-f]{7,40}', fd['head']):
            errs.append('head must be a 7-40 character lowercase hex sha')
        if not (isinstance(fd['verdict'], str) and fd['verdict'] in VERD):
            errs.append('verdict must be one of: ' + ', '.join(VERD))
        else:
            verdict = fd['verdict']

        # counts
        cnt = fd['counts']
        cnt_ok = test_keys(cnt, 'counts', SEV, [], errs)
        if cnt_ok:
            for s in SEV:
                if not (is_int(cnt[s]) and cnt[s] >= 0):
                    errs.append(f"counts.{s} must be an integer >= 0")
                    cnt_ok = False

        # findings
        fa = fd['findings']
        if not isinstance(fa, list):
            errs.append('findings must be an array')
        else:
            for i, f in enumerate(fa, 1):
                p = f"findings[{i}]"
                req = ['id', 'severity', 'class', 'signature', 'title', 'location',
                       'evidence', 'phase', 'suggested_fix']
                if not test_keys(f, p, req, ['acs', 'repro', 'flaky_check'], errs):
                    continue
                n_find += 1
                if not matches(r'F-[0-9]{3}', f['id']):
                    errs.append(f"{p}.id must look like F-001")
                elif f['id'] in ids:
                    errs.append(f"{p}.id duplicates {f['id']}")
                else:
                    ids[f['id']] = True
                if not (isinstance(f['severity'], str) and f['severity'] in SEV):
                    errs.append(f"{p}.severity must be one of: " + ', '.join(SEV))
                    cnt_ok = False
                else:
                    tally[f['severity']] += 1
                if not (isinstance(f['class'], str) and f['class'] in CLS):
                    errs.append(f"{p}.class must be one of: " + ', '.join(CLS))
                sig = f['signature']
                if not (is_str(sig, 8, 120) and
                        re.fullmatch(r'(build|lint|type|test|e2e|contract|security|review):.+:.+', sig)):
                    errs.append(f"{p}.signature must be <check>:<locator>:<error>, 8-120 chars, "
                                "check one of build|lint|type|test|e2e|contract|security|review")
                else:
                    if sig in sigs:
                        errs.append(f"{p}.signature duplicates an earlier finding: {sig}")
                    else:
                        sigs[sig] = True
                    if any(re.fullmatch(r'[0-9]+', part) for part in sig.split(':')[1:]):
                        warns.append(f"{p}.signature has a purely numeric part; line numbers and counts "
                                     f"make signatures drift between rounds: {sig}")
                if not is_str(f['title'], 1, 120):
                    errs.append(f"{p}.title must be 1-120 chars")
                test_loc(f['location'], f"{p}.location", errs)
                ev = f['evidence']
                if test_keys(ev, f"{p}.evidence", ['cmd', 'exit_code', 'excerpt'], [], errs):
                    if ev['cmd'] is not None and not isinstance(ev['cmd'], str):
                        errs.append(f"{p}.evidence.cmd must be a string or null")
                    if ev['exit_code'] is not None and not is_int(ev['exit_code']):
                        errs.append(f"{p}.evidence.exit_code must be an integer or null")
                    if not is_str(ev['excerpt'], 0, 600):
                        errs.append(f"{p}.evidence.excerpt must be a string of at most 600 chars")
                if not is_str(f['phase'], 1, 16):
                    errs.append(f"{p}.phase must be 1-16 chars")
                if not is_str(f['suggested_fix'], 1, 400):
                    errs.append(f"{p}.suggested_fix must be 1-400 chars")
                if 'repro' in f and not is_str(f['repro'], 0, 300):
                    errs.append(f"{p}.repro must be a string of at most 300 chars")
                if 'acs' in f:
                    acs = f['acs']
                    if not isinstance(acs, list):
                        errs.append(f"{p}.acs must be an array of strings")
                    else:
                        for a in acs:
                            if not isinstance(a, str):
                                errs.append(f"{p}.acs must contain only strings")
                                break
                if 'flaky_check' in f:
                    fc = f['flaky_check']
                    if test_keys(fc, f"{p}.flaky_check", ['reruns', 'results'], [], errs):
                        if not (is_int(fc['reruns']) and fc['reruns'] >= 1):
                            errs.append(f"{p}.flaky_check.reruns must be an integer >= 1")
                        fr = fc['results']
                        if not isinstance(fr, list) or len(fr) < 2:
                            errs.append(f"{p}.flaky_check.results must list at least 2 outcomes")
                        else:
                            for x in fr:
                                if not (isinstance(x, str) and x in ('pass', 'fail')):
                                    errs.append(f"{p}.flaky_check.results must contain only pass or fail")
                                    break
                elif f['class'] == 'flaky':
                    errs.append(f"{p} is class flaky but has no flaky_check")

        # suggestions
        sa = fd['suggestions']
        if not isinstance(sa, list):
            errs.append('suggestions must be an array')
        else:
            for i, g in enumerate(sa, 1):
                p = f"suggestions[{i}]"
                if not test_keys(g, p, ['title', 'location'], ['note'], errs):
                    continue
                if not is_str(g['title'], 1, 120):
                    errs.append(f"{p}.title must be 1-120 chars")
                test_loc(g['location'], f"{p}.location", errs)
                if 'note' in g and not is_str(g['note'], 0, 300):
                    errs.append(f"{p}.note must be a string of at most 300 chars")

        # prior findings
        pa = fd['prior_findings']
        n_prior = 0
        if not isinstance(pa, list):
            errs.append('prior_findings must be an array')
        else:
            for i, q in enumerate(pa, 1):
                p = f"prior_findings[{i}]"
                if not test_keys(q, p, ['signature', 'status'], [], errs):
                    continue
                n_prior += 1
                if not is_str(q['signature'], 8, 120):
                    errs.append(f"{p}.signature must be 8-120 chars")
                if not (isinstance(q['status'], str) and q['status'] in ('resolved', 'still_open')):
                    errs.append(f"{p}.status must be resolved or still_open")
                elif q['status'] == 'still_open' and q['signature'] not in sigs:
                    errs.append(f"{p} is still_open but no finding carries signature {q['signature']}")
                elif q['status'] == 'resolved' and q['signature'] in sigs:
                    errs.append(f"{p} is resolved but a finding still carries signature {q['signature']}")
            if rnd == 1 and n_prior > 0:
                errs.append('review_round is 1 but prior_findings is not empty')

        # consistency: counts, verdict
        if cnt_ok:
            for s in SEV:
                if cnt[s] != tally[s]:
                    errs.append(f"counts.{s} is {cnt[s]} but findings contain {tally[s]}")
        # Unqualified APPROVED allows no MEDIUM, matching the rule that an unrunnable
        # gate is MEDIUM and blocks it. Relax here if you want MEDIUM under APPROVED.
        crit = tally['BLOCKER'] + tally['HIGH']
        if verdict == 'APPROVED' and crit + tally['MEDIUM'] > 0:
            errs.append('verdict APPROVED but findings include BLOCKER, HIGH or MEDIUM')
        if verdict == 'APPROVED WITH NOTES' and crit > 0:
            errs.append('verdict APPROVED WITH NOTES but findings include BLOCKER or HIGH')
        if verdict == 'CHANGES_REQUIRED' and n_find == 0:
            errs.append('verdict CHANGES_REQUIRED but there are no findings')

        # the report must carry every finding id, so prose and file cannot diverge
        if not os.path.isfile(rf):
            errs.append(f"review report not found: {rf}")
        else:
            with open(rf, encoding='utf-8-sig') as fh:
                rt = fh.read()
            for k in ids:
                if k not in rt:
                    errs.append(f"finding {k} is not mentioned in the review report")

    if not errs:
        for w in unique(warns):
            print(f"WARN {w}")
        print(f"OK validate-findings task={task} findings={n_find} round={rnd} verdict={verdict}")
        return 0
    for e in unique(errs):
        print(f"ERROR {e}")
    return 1


if __name__ == '__main__':
    sys.exit(main())
