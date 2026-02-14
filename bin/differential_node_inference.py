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
    parser.add_argument('--node_metric', type=str, required=True,
                        help='Node-level metric to compute (e.g., degree, betweenness, closeness)')
    
    parser.add_argument('--multiple_testing', type=str, required=True,
                        help='Multiple testing correction method (e.g., bonferroni, fdr_bh, none)')

    
    # Output
    parser.add_argument('--output_prefix', type=str, required=True,
                        help='Prefix for output files')
    
    # Meta File
    parser.add_argument('--meta-file', type=str, required=True,
                        help='Path to meta file storing the data types of input data.')
    
    args = parser.parse_args()

    
    if args.node_metric == "":
        node_metric = None
        print("No node metrics calculated.")
        # Write empty file
        nodes_diff = pd.DataFrame()
    else:
        # Read networks and input data
        scores1 = pd.read_csv(args.network_context_1)
        scores2 = pd.read_csv(args.network_context_2)
        data1 = pd.read_csv(args.context_file_1)
        data2 = pd.read_csv(args.context_file_2)
        
        node_metric = args.node_metric
        meta = pd.read_csv(args.meta_file)
    
        print("Starting differential node inference...")
        
        
        # Perform differential network analysis
        nodes_diff = modina.compute_diff_nodes(
            scores1=scores1,
            scores2=scores2,
            context1=data1,
            context2=data2,
            node_metric=node_metric,
            correction=args.multiple_testing,
            meta_file = meta    
        )
            
    nodes_diff.to_csv(f'{args.output_prefix}_{node_metric}_node_metrics.csv', index=True)

    print("Differential node inference completed successfully")

