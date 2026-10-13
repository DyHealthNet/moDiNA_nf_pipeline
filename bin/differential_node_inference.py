#!/usr/bin/env python3
import argparse
import sys
import pandas as pd
import modina 

if __name__ == '__main__':

    """Parse command line arguments for differential node inference."""
    parser = argparse.ArgumentParser(
        description='Perform differential node inference between two contexts.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    
    # Network input files
    parser.add_argument('--network_context_1', type=str, required=True,
                        help='Path to network file for context 1')
    parser.add_argument('--network_context_2', type=str, required=True,
                        help='Path to network file for context 2')
    
    # Context data files
    parser.add_argument('--context_file_1', type=str, required=True,
                        help='Path to data file for context 1')
    parser.add_argument('--context_file_2', type=str, required=True,
                        help='Path to data file for context 2')
    
    # Metrics
    parser.add_argument('--node_metrics', type=str, required=True,
                        help='Comma-separated node-level metrics to compute (e.g., STC-P,STC-LP); an empty string writes an empty placeholder file')
    parser.add_argument('--lp_cap', type=float, required=False, default=None,
                        help='Cap for -log10(p) in the capped product metrics (e.g. STC-LPxRE-cap)')
    
    parser.add_argument('--multiple_testing', type=str, required=True,
                        help='Multiple testing correction method (e.g., bonferroni, fdr_bh, none)')
    parser.add_argument('--nan_value', type=int, default=-89,
                        help='Value that represent the NA values in the input data')
    parser.add_argument('--num_workers', type=int, default=1, 
                        help='Number of workers for parallel computation of STC')

    # Output
    parser.add_argument('--output_prefix', type=str, required=True,
                        help='Prefix for output files')
    
    # Meta File
    parser.add_argument('--meta-file', type=str, required=True,
                        help='Path to meta file storing the data types of input data.')
    # Test Type
    parser.add_argument('--test-type', type=str, required=True,
                        help='Type of test to perform for differential node inference (e.g., t-test, wilcoxon)')
    
    args = parser.parse_args()

    
    node_metrics = args.node_metrics.split(',')

    if node_metrics != ['']:
        scores1 = pd.read_csv(args.network_context_1)
        scores2 = pd.read_csv(args.network_context_2)
        data1 = pd.read_csv(args.context_file_1)
        data2 = pd.read_csv(args.context_file_2)
        meta = pd.read_csv(args.meta_file)

    for metric in node_metrics:
        if metric == "":
            node_metric = None
            print("No node metrics calculated.")
            nodes_diff = pd.DataFrame()
        else:
            node_metric = metric
            print(f"Starting differential node inference for {node_metric}...")

            # Copies, so one metric's computation cannot leak into the next
            nodes_diff = modina.compute_diff_nodes(
                scores1=scores1.copy(),
                scores2=scores2.copy(),
                context1=data1.copy(),
                context2=data2.copy(),
                node_metric=node_metric,
                correction=args.multiple_testing,
                nan_value=args.nan_value,
                num_workers=args.num_workers,
                meta_file = meta.copy(),
                test_type = args.test_type,
                lp_cap = args.lp_cap
            )

        nodes_diff.to_csv(f'{args.output_prefix}_{node_metric}_node_metrics.csv', index=True)

    print("Differential node inference completed successfully")

