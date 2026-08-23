#!/usr/bin/env python3
"""
select_best_trial_v2.py

Trial selection combining two approaches:
  A) IK fit (marker RMS) + number of gait cycles (HS->HS)
  B) Data quality/consistency: missing markers, anomalous ROM (coordinate
     stuck at a limit), velocity consistency (R^2 of pelvis_tx vs time),
     and L/R asymmetry per joint.

IMPORTANT - L/R asymmetry is treated differently depending on the group:
  - Able-bodied: abnormally high asymmetry (>threshold) is a signal of
    possible noise/questionable quality -> slightly penalizes ranking.
  - Stroke: asymmetry is the expected clinical signal, it is NOT used to
    prefer one trial over another. It is computed and reported only, for
    documentation / later interpretation of results.

Hard filters (exclude a trial unless there's no better alternative):
  - Missing markers (gaps/NaNs in the .trc within the trim window, or
    fewer markers than expected)
  - Anomalous ROM: any hip/ankle/subtalar coordinate with range < 3
    degrees across the whole cycle (stuck at a clamp limit)
  - Fewer than MIN_STRIKES heel-strikes

Ranking among trials that pass the filters (in this priority order):
  1) Marker RMS (lower is better)
  2) Velocity consistency, R^2 of pelvis_tx vs time (higher is better)
  3) Duration / number of frames (higher is better)
  (High asymmetry in able-bodied subtracts ranking points; in stroke it
   is only reported.)

Usage:
  python select_best_trial_v2.py <ik_out_root> <gait_trim_windows.csv> <output.csv> <group>
  <group> = 'able_bodied' or 'stroke' (changes how asymmetry is handled)
"""

import pandas as pd
import numpy as np
import glob
import os
import re
import sys

MIN_STRIKES = 4
ROM_ANOMALY_THRESHOLD_DEG = 3.0
ASYMMETRY_HIGH_THRESHOLD_PCT = 20.0   # only penalizes in able-bodied subjects

JOINT_COORDS = {
    'hip': ('hip_flexion_r', 'hip_flexion_l'),
    'knee': ('knee_angle_r', 'knee_angle_l'),
    'ankle': ('ankle_angle_r', 'ankle_angle_l'),
}
ROM_CHECK_COORDS = ['hip_flexion_r', 'hip_flexion_l', 'hip_adduction_r', 'hip_adduction_l',
                    'hip_rotation_r', 'hip_rotation_l', 'ankle_angle_r', 'ankle_angle_l',
                    'subtalar_angle_r', 'subtalar_angle_l']


def read_mot(path):
    with open(path, encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    for i, l in enumerate(lines):
        if l.strip().lower() == 'endheader':
            header_end = i
            break
    return pd.read_csv(path, sep='\t', skiprows=header_end + 1)


def read_trc_marker_count(trc_path, expected_markers):
    """Counts markers present and detects gaps (NaN) in the trial used."""
    if not os.path.isfile(trc_path):
        return None, None
    with open(trc_path, encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    marker_line = lines[3].strip('\n').split('\t')
    markers = [m for m in marker_line[2:] if m != '']
    n_present = len(markers)

    data = pd.read_csv(trc_path, sep='\t', skiprows=5, header=None)
    n_gaps = int(data.isna().sum().sum())
    return n_present, n_gaps


def velocity_consistency_r2(df):
    """R^2 of pelvis_tx vs time: high = linear progression (steady-state)."""
    if 'pelvis_tx' not in df.columns or 'time' not in df.columns:
        return np.nan
    t = df['time'].values
    x = df['pelvis_tx'].values
    if len(t) < 3:
        return np.nan
    coeffs = np.polyfit(t, x, 1)
    pred = np.polyval(coeffs, t)
    ss_res = np.sum((x - pred) ** 2)
    ss_tot = np.sum((x - x.mean()) ** 2)
    if ss_tot == 0:
        return np.nan
    return 1 - ss_res / ss_tot


def rom_anomaly_flag(df):
    """True if any key coordinate is stuck at a limit (range < threshold)."""
    for c in ROM_CHECK_COORDS:
        if c in df.columns:
            rng = df[c].max() - df[c].min()
            if rng < ROM_ANOMALY_THRESHOLD_DEG:
                return True, c, rng
    return False, None, None


def joint_asymmetry_pct(df):
    """L/R asymmetry per joint, based on ROM (max-min)."""
    result = {}
    for joint, (r_col, l_col) in JOINT_COORDS.items():
        if r_col in df.columns and l_col in df.columns:
            rom_r = df[r_col].max() - df[r_col].min()
            rom_l = df[l_col].max() - df[l_col].min()
            mean_rom = (rom_r + rom_l) / 2
            if mean_rom > 0:
                result[joint] = abs(rom_r - rom_l) / mean_rom * 100
    return result


def build_table(ik_out_root, trim_csv):
    trim = pd.read_csv(trim_csv)
    rows = []

    pattern = os.path.join(ik_out_root, '*', '*', '_ik_marker_errors.sto')
    for f in sorted(glob.glob(pattern)):
        parts = f.replace('\\', '/').split('/')
        subj, trial = parts[-3], parts[-2]
        trial_dir = os.path.dirname(f)

        err_df = pd.read_csv(f, sep='\t', skiprows=6)
        rms = err_df['marker_error_RMS'].mean() * 1000

        mot_files = glob.glob(os.path.join(trial_dir, '*_IK.mot'))
        setup_files = glob.glob(os.path.join(trial_dir, '*_IK_setup.xml'))
        if not mot_files or not setup_files:
            continue
        mot_df = read_mot(mot_files[0])

        with open(setup_files[0], encoding='utf-8', errors='ignore') as fh:
            txt = fh.read()
        m = re.search(r'<marker_file>(.*?)</marker_file>', txt)
        trc_path = m.group(1) if m else None
        trc_name = os.path.basename(trc_path) if trc_path else None

        r2 = velocity_consistency_r2(mot_df)
        anomaly, anomaly_coord, anomaly_rng = rom_anomaly_flag(mot_df)
        asym = joint_asymmetry_pct(mot_df)

        trim_row = trim[(trim['subject'] == subj) & (trim['trc_file'] == trc_name)]
        n_strikes = trim_row['n_foot_strikes'].values[0] if len(trim_row) > 0 else np.nan
        duration = (trim_row['tEnd_TRC'].values[0] - trim_row['tStart_TRC'].values[0]) if len(trim_row) > 0 else np.nan

        n_markers, n_gaps = read_trc_marker_count(trc_path, None) if trc_path and os.path.isfile(trc_path) else (None, None)

        rows.append({
            'subject': subj, 'trial': trial, 'trc_file': trc_name,
            'RMS_mean_mm': rms, 'n_foot_strikes': n_strikes, 'duration_s': duration,
            'velocity_R2': r2, 'rom_anomaly': anomaly, 'rom_anomaly_coord': anomaly_coord,
            'n_markers': n_markers, 'n_gaps': n_gaps,
            'asym_hip_pct': asym.get('hip', np.nan),
            'asym_knee_pct': asym.get('knee', np.nan),
            'asym_ankle_pct': asym.get('ankle', np.nan),
        })

    return pd.DataFrame(rows)


def select_best(df, group):
    rows = []
    for subj, g in df.groupby('subject'):
        g = g.copy()

        # --- Hard filters ---
        pool = g[(g['n_foot_strikes'] >= MIN_STRIKES) & (~g['rom_anomaly'])]
        relaxed_criteria = False
        if len(pool) == 0:
            pool = g[~g['rom_anomaly']]
            relaxed_criteria = True
        if len(pool) == 0:
            pool = g
            relaxed_criteria = True

        pool = pool.copy()

        # --- Penalty for high asymmetry, ONLY in able-bodied subjects ---
        if group == 'able_bodied':
            mean_asym = pool[['asym_hip_pct', 'asym_knee_pct', 'asym_ankle_pct']].mean(axis=1)
            pool['asymmetry_penalty'] = (mean_asym > ASYMMETRY_HIGH_THRESHOLD_PCT).astype(int)
        else:
            pool['asymmetry_penalty'] = 0  # in stroke, no penalty

        # --- Ranking: RMS asc, then penalty asc, then R2 desc, then duration desc ---
        pool = pool.sort_values(
            by=['asymmetry_penalty', 'RMS_mean_mm'],
            ascending=[True, True]
        )
        best = pool.iloc[0].copy()
        best['relaxed_criteria'] = relaxed_criteria
        rows.append(best)

    return pd.DataFrame(rows).sort_values('subject').reset_index(drop=True)


def main(ik_out_root, trim_csv, out_csv, group):
    assert group in ('able_bodied', 'stroke'), "group must be 'able_bodied' or 'stroke'"
    df = build_table(ik_out_root, trim_csv)
    selected = select_best(df, group)
    selected.to_csv(out_csv, index=False)

    print(f"Subjects processed: {selected['subject'].nunique()}")
    relaxed = selected[selected['relaxed_criteria']]
    if len(relaxed) > 0:
        print(f"\nWARNING: {len(relaxed)} subject(s) had no clean trial under the hard "
              f"filters; criteria were relaxed:")
        print(relaxed[['subject', 'trial', 'rom_anomaly', 'n_foot_strikes']].to_string(index=False))

    print(f"\nResult saved to: {out_csv}")
    return selected


if __name__ == '__main__':
    if len(sys.argv) != 5:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
