#!/usr/bin/env python3
"""
generate_gait_trim_windows.py

Reads every dynamic walking .trc in the dataset, matches it to its source
.c3d, extracts the Foot Strike (heel-strike) events, corrects the C3D->TRC
time offset, and writes a CSV with the trim window (first HS -> last HS,
either foot) per trial in the TRC time axis.

The IK step (MATLAB) then reads this CSV to set <time_range> instead of
using the full trial, removing gait-initiation/termination noise.

Why the offset correction matters:
  The C3D keeps its original first_frame, so its time axis starts at
  first_frame/rate. The converted TRC resets time to start at 0. Event
  times from the C3D must therefore be shifted:  t_TRC = t_c3d - first_frame/rate

Usage:
  pip install ezc3d
  python generate_gait_trim_windows.py  <root_folder>  <output_csv>

  <root_folder> must contain one subfolder per subject (SUBJ*, TVC*),
  each holding the dynamic .c3d files and their matching *walk*.trc files.
"""

import ezc3d
import numpy as np
import os
import glob
import csv
import sys


def read_trc_nframes(trc_path):
    with open(trc_path, encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    # Line index 2 (third line) holds numeric metadata; column 2 = NumFrames
    return int(lines[2].split('\t')[2])


def process(root, out_csv):
    rows = []
    subjects = sorted(
        d for d in os.listdir(root)
        if os.path.isdir(os.path.join(root, d))
        and (d.startswith('SUBJ') or d.startswith('TVC') or d.startswith('BWA'))
    )

    for subj in subjects:
        subj_dir = os.path.join(root, subj)
        trcs = sorted(glob.glob(os.path.join(subj_dir, '*walk_RCNL2025.trc')))

        # candidate dynamic c3d files (exclude static/calibration)
        c3ds = [
            f for f in glob.glob(os.path.join(subj_dir, '*.c3d'))
            if '(0)' not in f and 'Cal' not in f and 'cal' not in f
        ]

        for trc in trcs:
            base = os.path.basename(trc)
            try:
                n_trc = read_trc_nframes(trc)
            except Exception as e:
                rows.append([subj, base, 'TRC_READ_ERROR', '', '', '', ''])
                continue

            # match c3d by frame count
            match = None
            for c3d in c3ds:
                try:
                    c = ezc3d.c3d(c3d)
                    n = (c['header']['points']['last_frame']
                         - c['header']['points']['first_frame'] + 1)
                    if n == n_trc:
                        match = c3d
                        break
                except Exception:
                    pass

            if match is None:
                rows.append([subj, base, 'NO_MATCH', '', '', '', ''])
                continue

            c = ezc3d.c3d(match)
            rate = c['header']['points']['frame_rate']
            first_frame = c['header']['points']['first_frame']
            offset = first_frame / rate

            if 'EVENT' not in c['parameters']:
                rows.append([subj, base, os.path.basename(match), 'NO_EVENTS', '', '', ''])
                continue

            times = np.array(c['parameters']['EVENT']['TIMES']['value'])
            ev = times[1] if times.ndim > 1 else times
            labels = c['parameters']['EVENT']['LABELS']['value']

            fs = sorted(ev[i] - offset for i in range(len(ev))
                        if labels[i] == 'Foot Strike')

            if not fs:
                rows.append([subj, base, os.path.basename(match), f'{offset:.3f}', 0, '', ''])
                continue

            t0 = max(fs[0], 0.0)
            t1 = fs[-1]
            rows.append([subj, base, os.path.basename(match),
                         f'{offset:.3f}', len(fs), f'{t0:.3f}', f'{t1:.3f}'])

    with open(out_csv, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['subject', 'trc_file', 'c3d_file', 'offset_s',
                    'n_foot_strikes', 'tStart_TRC', 'tEnd_TRC'])
        w.writerows(rows)

    # brief report
    ok = sum(1 for r in rows if r[4] not in ('', 0) and str(r[4]).isdigit())
    print(f'Processed {len(rows)} trials, {ok} with valid Foot Strike windows.')
    problems = [r for r in rows if r[2] in ('NO_MATCH', 'NO_EVENTS', 'TRC_READ_ERROR') or r[4] in ('', 0)]
    if problems:
        print(f'{len(problems)} trials need attention:')
        for p in problems:
            print('  ', p[0], p[1], '->', p[2], p[3])
    print(f'CSV written to: {out_csv}')


if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    out_csv = sys.argv[2] if len(sys.argv) > 2 else 'gait_trim_windows.csv'
    process(root, out_csv)
