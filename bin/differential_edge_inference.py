#!/usr/bin/env python3
import argparse
import sys
import pandas as pd
import modina

if __name__ == '__main__':

    """Parse command line arguments for differential edge inference."""
    parser = argparse.ArgumentParser(
        description='Perform differential edge inference between two contexts.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )


    # Network input files
    parser.add_argument('--network_context_1', type=str, required=True,
                        help='Path to network file for context 1')
    parser.add_argument('--network_context_2', type=str, required=True,
                        help='Path to network file for context 2')

    # Metrics
    parser.add_argument('--edge_metric', type=str, required=True,
                        help='Edge-level metric to compute (e.g., weight, correlation)')

    parser.add_argument('--max_path_length', type=int, required=False,
                        help='Maximum path length for network analysis')

    # Output
    parser.add_argument('--output_prefix', type=str, required=True,
                        help='Prefix for output files')

    # Context names (used to label the per-context raw-P/raw-E columns). Default: derived from
    # the network filenames (e.g. "Male_rescaled_association_scores.csv" -> "Male").
    parser.add_argument('--name_context_1', type=str, required=False, default=None,
                        help='Name of context 1 (labels its raw-P/raw-E columns)')
    parser.add_argument('--name_context_2', type=str, required=False, default=None,
                        help='Name of context 2 (labels its raw-P/raw-E columns)')

    args = parser.parse_args()

    import os
    def _derive_name(pth):
        base = os.path.basename(pth)
        for suffix in ('.csv', '_association_scores', '_rescaled_association_scores', '_filtered'):
            base = base.replace(suffix, '')
        return base or 'context'
    name_context_1 = args.name_context_1 or _derive_name(args.network_context_1)
    name_context_2 = args.name_context_2 or _derive_name(args.network_context_2)


    if args.edge_metric == "":
        edge_metric = None
        print("No edge metrics calculated.")
        # Write empty files
        edges_diff = pd.DataFrame()
        edge_node_stats = pd.DataFrame()
    else:
        edge_metric = args.edge_metric
        # Read networks and input data
        scores1 = pd.read_csv(args.network_context_1)
        scores2 = pd.read_csv(args.network_context_2)

        if args.max_path_length is None:
            max_path_length = 2
        else:
            max_path_length = args.max_path_length


        print("Starting differential edge inference...")

        # Perform differential network analysis. The per-node edge statistics are computed here,
        # once per edge metric, so that the ranking stage can retrieve them for every ranking
        # configuration without recomputation.
        edges_diff, edge_node_stats = modina.compute_diff_edges(
            scores1=scores1,
            scores2=scores2,
            edge_metric=edge_metric,
            max_path_length=max_path_length,
            name1=name_context_1,
            name2=name_context_2
        )

    edges_diff.to_csv(f'{args.output_prefix}_{edge_metric}_edge_metrics.csv', index=True)
    edge_node_stats.to_csv(f'{args.output_prefix}_{edge_metric}_edge_node_stats.csv', index=True)

    print("Differential edge inference completed successfully")
