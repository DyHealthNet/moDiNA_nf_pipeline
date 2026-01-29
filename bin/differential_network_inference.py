#!/usr/bin/env python3
import argparse
import sys
import pandas as pd
import modina 

if __name__ == '__main__':

    """Parse command line arguments for differential network analysis."""
    parser = argparse.ArgumentParser(
        description='Perform differential network analysis between two contexts.',
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
    parser.add_argument('--node_metric', type=str, required=True,
                        help='Node-level metric to compute (e.g., degree, betweenness, closeness)')
    parser.add_argument('--edge_metric', type=str, required=True,
                        help='Edge-level metric to compute (e.g., weight, correlation)')
    
    # Statistical testing parameters
    parser.add_argument('--stc_test', type=str, required=False,
                        help='Statistical test to use for comparing contexts (e.g., t-test, wilcoxon, permutation)')
    parser.add_argument('--max_path_length', type=int, required=False,
                        help='Maximum path length for network analysis')
    parser.add_argument('--multiple_testing', type=str, required=True,
                        help='Multiple testing correction method (e.g., bonferroni, fdr_bh, none)')

    
    # Output
    parser.add_argument('--output_prefix', type=str, required=True,
                        help='Prefix for output files')
    
    args = parser.parse_args()
    
    # Read networks and input data
    scores1 = pd.read_csv(args.network_context_1)
    scores2 = pd.read_csv(args.network_context_2)
    data1 = pd.read_csv(args.context_file_1)
    data2 = pd.read_csv(args.context_file_2)
    
    # Check if stc_test and max_path_length are provided when needed
    if args.stc_test is None:
        stc_test = 'mwu'
    else:
        stc_test = args.stc_test
    
    if args.max_path_length is None:
        max_path_length = 2
    else:
        max_path_length = args.max_path_length
        
    
    # Perform differential network analysis
    edges_diff, nodes_diff = modina.compute_diff_network(
        scores1=scores1,
        scores2=scores2,
        context1=data1,
        context2=data2,
        node_metric=args.node_metric,
        edge_metric=args.edge_metric,
        stc_test=stc_test,
        max_path_length=max_path_length,
        correction=args.multiple_testing    
    )
    
    edges_diff.to_csv(f'{args.output_prefix}_edge_metrics.csv', index=False)
    nodes_diff.to_csv(f'{args.output_prefix}_node_metrics.csv', index=True)
    print("Differential network analysis completed successfully")

