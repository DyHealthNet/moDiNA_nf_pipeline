#!/usr/bin/env python3
import argparse
import pandas as pd
import modina

if __name__ == '__main__':

    """Parse command line arguments for filtering the differential network."""
    parser = argparse.ArgumentParser(
        description='Filter the differential network on the computed edge metric.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    # Input file - differential edge scores
    parser.add_argument('--edges', type=str, required=True,
                        help='Path to the differential edge metrics file')

    # Filtering parameters
    parser.add_argument('--edge_metric', type=str, required=True,
                        help='Edge metric column to filter on (the metric that was computed)')
    parser.add_argument('--filter_method', type=str, default=None,
                        help='Method used for filtering (degree or density)')
    parser.add_argument('--filter_param', type=float, default=0.0,
                        help='Parameter for the specified filtering method')
    parser.add_argument('--output_prefix', type=str, default='',
                        help='Prefix for output filenames')

    args = parser.parse_args()

    # Read the differential edges (written with index=True by differential edge inference)
    edges_diff = pd.read_csv(args.edges, index_col=0)

    # Apply differential filtering. filter_metric / filter_rule are intentionally absent:
    # the differential network is always filtered on the already-computed edge_metric.
    edges_filtered, edge_node_stats = modina.filter_differential(
        edges_diff=edges_diff,
        edge_metric=args.edge_metric,
        filter_method=args.filter_method,
        filter_param=args.filter_param,
    )

    # Save filtered outputs. The '_filtered_' infix keeps the output globs distinct from the
    # staged input file so the process captures only the newly written files.
    prefix = f"{args.output_prefix}_" if args.output_prefix else ""
    edges_filtered.to_csv(f"{prefix}{args.edge_metric}_filtered_edge_metrics.csv", index=True)
    edge_node_stats.to_csv(f"{prefix}{args.edge_metric}_filtered_edge_node_stats.csv", index=True)

    print("Differential network filtering completed successfully")
