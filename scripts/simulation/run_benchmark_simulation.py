#!/usr/bin/env python3
"""Benchmark simulation harness for moDiNA.

Reads benchmark_runs.csv (next to this script), writes one params file per run to
params_files/simulation/<category>/<name>.yml and runs the moDiNA Nextflow pipeline on each,
sequentially:

    nextflow run main.nf -profile <profile> -params-file <params.yml>

(blocking, cwd = the pipeline dir; each run fans out to Slurm itself).

CSV conventions:
  * `category` is only filled in on the first row of each block and carries down to the rows
    below it.
  * A row whose parameter columns are all empty is a placeholder for a level that is identical to
    the baseline (e.g. n_500 on the sample-size axis). It is skipped: the baseline run is that level.
  * Every other row must be complete. Exception: background_model, module_size, module_fraction and
    module_correlation may be left blank (defaults: modules, none, 0.1, 0.2; a blank module_size means
    module_fraction x the number of variables), and so may pagerank_damping (default 0.85, the damping factor of
    PageRank+ / PageRank). background_strength/background_density are only used by
    background_model scale_free.
  * The scale-free benchmark of the first submission is benchmark_runs_scale_free.csv (run it with --csv).

Run with: python3 run_benchmark_simulation.py [--only NAME_OR_CATEGORY ...] [--dry-run]
          [--resume] [--profile conda,slurm] [--path-config configs.csv] [--nextflow PATH]
"""

import argparse
import csv
import os
import subprocess
import sys
import time

SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
PIPELINE_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, '..', '..'))
CSV_PATH     = os.path.join(SCRIPT_DIR, 'benchmark_runs.csv')
PARAMS_ROOT  = os.path.join(PIPELINE_DIR, 'params_files', 'simulation')   # /<category>/<name>.yml

INT_COLS = ['n_simulations', 'seed', 'n_bi', 'n_cont', 'n_cat', 'n_samples_1', 'n_samples_2',
            'n_shift_cont', 'n_shift_bi', 'n_shift_cat',
            'n_corr_cont_cont', 'n_corr_bi_bi', 'n_corr_cat_cat', 'n_corr_bi_cont', 'n_corr_bi_cat', 'n_corr_cont_cat',
            'n_both_cont_cont', 'n_both_bi_bi', 'n_both_cat_cat', 'n_both_bi_cont', 'n_both_bi_cat', 'n_both_cont_cat',
            'background_density', 'background_seed']
FLOAT_COLS = ['corr_low', 'corr_high', 'shift_low', 'shift_high', 'hub_reuse_prob', 'background_strength']
SIMULATION_COLS = INT_COLS + FLOAT_COLS
# Background model columns: optional, a blank cell (or a missing column) means the default, the module background
# (benchmark_runs_scale_free.csv names scale_free explicitly). module_size None = module_fraction x n_vars.
OPTIONAL_COLS = {'background_model': ('modules', str), 'module_size': (None, int), 'module_fraction': (0.1, float),
                 'module_correlation': (0.2, float)}
DIFF_NET_STR_COLS = ['test_type', 'multiple_testing']
# Optional differential-analysis columns: a blank cell (or a missing column) means the default
DIFF_NET_OPTIONAL_COLS = {'pagerank_damping': (0.85, float)}
PARAM_COLS = INT_COLS + FLOAT_COLS + DIFF_NET_STR_COLS + ['out_dir']


def read_runs(path):
    """Parse the CSV into a list of run dicts, carrying categories down and skipping placeholders."""
    runs, skipped = [], []
    category = None
    with open(path, newline='') as f:
        reader = csv.DictReader(f)
        missing = [c for c in ['name', 'category'] + PARAM_COLS if c not in reader.fieldnames]
        if missing:
            raise SystemExit(f'{path} is missing columns: {", ".join(missing)}')
        for line_no, row in enumerate(reader, start=2):
            row = {k: (v or '').strip() for k, v in row.items()}
            if not row['name']:
                continue
            category = row['category'] or category
            if category is None:
                raise SystemExit(f'{path}:{line_no}: no category for {row["name"]!r}')
            if not any(row[c] for c in PARAM_COLS):
                skipped.append((category, row['name']))
                continue
            empty = [c for c in PARAM_COLS if not row[c]]
            if empty:
                raise SystemExit(f'{path}:{line_no}: {row["name"]!r} is partially filled; empty: {", ".join(empty)}')
            run = {'name': row['name'], 'category': category}
            try:
                run.update({c: int(row[c]) for c in INT_COLS})
                run.update({c: float(row[c]) for c in FLOAT_COLS})
                run.update({c: cast(row[c]) if row.get(c) else default
                            for c, (default, cast) in {**OPTIONAL_COLS, **DIFF_NET_OPTIONAL_COLS}.items()})
            except ValueError as e:
                raise SystemExit(f'{path}:{line_no}: {row["name"]!r}: {e}')
            run.update({c: row[c] for c in DIFF_NET_STR_COLS + ['out_dir']})
            runs.append(run)
    names = [(r['category'], r['name']) for r in runs]
    dupes = {n for n in names if names.count(n) > 1}
    if dupes:
        raise SystemExit(f'{path}: duplicate runs: {sorted(dupes)}')
    return runs, skipped


def render_params(run, path_config):
    """Build the params YAML for one run. Written by hand so the layout matches the existing files."""
    lines = [
        f'# Generated by scripts/simulation/run_benchmark_simulation.py from benchmark_runs.csv',
        f'# ({run["category"]}/{run["name"]}). Edit the CSV and regenerate rather than editing this file.',
        'name_context_1: "Context1"',
        'name_context_2: "Context2"',
        f'run_type: "{"file" if path_config else "all"}"',
        'data_type: "simulation"',
        f'out_dir: "{run["out_dir"]}"',
        '',
        'simulation:',
    ]
    lines += [f'  {c}: {run[c]}' for c in SIMULATION_COLS]
    lines += [f'  {c}: "{run[c]}"' if isinstance(run[c], str) else f'  {c}: {"null" if run[c] is None else run[c]}'
              for c in OPTIONAL_COLS]
    lines += ['', 'diff_net_analysis:']
    if path_config:
        lines.append(f'  path_config: "{path_config}"')
    lines += [f'  {c}: "{run[c]}"' for c in DIFF_NET_STR_COLS]
    lines += [f'  {c}: {run[c]}' for c in DIFF_NET_OPTIONAL_COLS]
    return '\n'.join(lines) + '\n'


def write_params(run, path_config):
    path = os.path.join(PARAMS_ROOT, run['category'], f'{run["name"]}.yml')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(render_params(run, path_config))
    return path


def last_session(params_file):
    """Session ID of the most recent run of this params file in .nextflow/history, or None.

    Every run is a Nextflow session of its own, and a bare -resume only looks into the cache of the last
    session of the pipeline directory (usually a different run). Runs with a custom -work-dir are ignored, as
    their cached tasks live in another work directory, and so are -preview runs, which execute no task. A resumed
    run keeps its session ID, so the most recent entry carries the cache of all earlier runs of this params file."""
    history = os.path.join(PIPELINE_DIR, '.nextflow', 'history')
    if not os.path.exists(history):
        return None
    target = os.path.realpath(params_file)
    session = None
    with open(history) as f:
        for line in f:
            fields = line.rstrip('\n').split('\t')
            if len(fields) < 7:
                continue
            tokens = fields[6].split()
            if '-params-file' not in tokens or {'-work-dir', '-w', '-preview'} & set(tokens):
                continue
            i = tokens.index('-params-file') + 1
            if i < len(tokens) and os.path.realpath(os.path.join(PIPELINE_DIR, tokens[i])) == target:
                session = fields[5]
    return session


def run_pipeline(params_file, nextflow, profile, resume, dry_run):
    cmd = [nextflow, 'run', 'main.nf', '-profile', profile, '-params-file', params_file]
    if resume:
        session = last_session(params_file)
        cmd += ['-resume'] + ([session] if session else [])
        if not session:
            print('  no earlier session of this params file in .nextflow/history: -resume without session ID',
                  flush=True)
    print('  $ ' + ' '.join(cmd), flush=True)
    if dry_run:
        return 0
    return subprocess.run(cmd, cwd=PIPELINE_DIR).returncode


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--csv', default=CSV_PATH, help='run sheet (default: benchmark_runs.csv next to this script)')
    ap.add_argument('--only', nargs='+', metavar='NAME_OR_CATEGORY',
                    help='run only these runs and/or categories, e.g. --only baseline prevalence')
    ap.add_argument('--dry-run', action='store_true', help='write the params files and print the commands, run nothing')
    ap.add_argument('--resume', action='store_true',
                    help='pass -resume to Nextflow, with the session ID of the last run of each params file '
                         '(from .nextflow/history)')
    ap.add_argument('--profile', default='conda,slurm', help='Nextflow profile(s) (default: conda,slurm)')
    ap.add_argument('--path-config', default=None,
                    help='samplesheet of moDiNA configurations; sets run_type "file" (default: run_type "all")')
    ap.add_argument('--nextflow', default='nextflow', help='Nextflow executable (default: nextflow on PATH)')
    args = ap.parse_args()

    path_config = os.path.abspath(args.path_config) if args.path_config else None
    if path_config and not os.path.exists(path_config):
        raise SystemExit(f'--path-config not found: {path_config}')

    runs, skipped = read_runs(args.csv)
    if args.only:
        wanted = set(args.only)
        unknown = wanted - {r['name'] for r in runs} - {r['category'] for r in runs}
        if unknown:
            raise SystemExit(f'--only: no run or category named {", ".join(sorted(unknown))}')
        runs = [r for r in runs if r['name'] in wanted or r['category'] in wanted]

    for category, name in skipped:
        print(f'skip {category}/{name}: empty row, identical to the baseline run')
    print(f'{len(runs)} run(s), pipeline dir {PIPELINE_DIR}\n', flush=True)

    failed = []
    for i, run in enumerate(runs, start=1):
        label = f'{run["category"]}/{run["name"]}'
        params_file = write_params(run, path_config)
        print(f'[{i}/{len(runs)}] {label}  ->  {os.path.relpath(params_file, PIPELINE_DIR)}', flush=True)
        start = time.time()
        code = run_pipeline(params_file, args.nextflow, args.profile, args.resume, args.dry_run)
        if code != 0:
            failed.append(label)
            print(f'  FAILED (exit {code}) after {time.time() - start:.0f}s; continuing', flush=True)
        elif not args.dry_run:
            print(f'  done in {time.time() - start:.0f}s', flush=True)

    if failed:
        print(f'\n{len(failed)} run(s) failed: {", ".join(failed)}')
        sys.exit(1)
    print('\nall runs finished' if not args.dry_run else '\ndry run: params files written, nothing executed')


if __name__ == '__main__':
    main()
