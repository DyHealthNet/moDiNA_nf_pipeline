#!/usr/bin/env python3
import argparse
import sys
import modina
import pandas as pd


def load_metric_file(path, cache):
    """Load a differential score file; an empty file (placeholder for an unused metric) yields None.
    Files are cached because the configurations of one batch share their input files."""
    if path not in cache:
        try:
            df = pd.read_csv(path, index_col=0)
        except pd.errors.EmptyDataError:
            df = None
        if df is not None and df.empty:
            df = None
        cache[path] = df
    # compute_ranking must not see another configuration's modifications
    return None if cache[path] is None else cache[path].copy()


if __name__ == '__main__':


    """Parse command line arguments for computing rankings."""
    parser = argparse.ArgumentParser(
        description='Compute node rankings from differential networks for a batch of configurations.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    # Configurations: one row per ranking to compute
    parser.add_argument('--config_file', type=str, required=True,
                        help='CSV with columns node_metric, edge_metric, node_file, edge_file, stats_file, output_prefix')
    parser.add_argument('--meta_file', type=str, required=True,
                        help='Path to metadata file')

    # Ranking algorithm
    parser.add_argument('--ranking_algorithm', type=str, required=True,
                        choices=list(modina.RANKING_ALGORITHMS),
                        help='Ranking algorithm to compute')

    args = parser.parse_args()

    configs = pd.read_csv(args.config_file, dtype=str, keep_default_na=False)
    meta_df = pd.read_csv(args.meta_file)

    cache = {}
    for config in configs.itertuples(index=False):
        print(f"Computing {args.ranking_algorithm} ranking for node metric '{config.node_metric}' and edge metric '{config.edge_metric}'...")

        # Run ranking computation
        ranks = modina.compute_ranking(
            nodes_diff=load_metric_file(config.node_file, cache),
            edges_diff=load_metric_file(config.edge_file, cache),
            ranking_alg=args.ranking_algorithm,
            meta_file=meta_df.copy(),
            edge_node_stats=load_metric_file(config.stats_file, cache)
        )

        ranks.to_csv(f'{config.output_prefix}_ranking.csv', index=False)

    print("Ranking computation completed successfully")
