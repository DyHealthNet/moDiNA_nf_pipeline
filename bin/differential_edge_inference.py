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
    
    args = parser.parse_args()
    
    
    if args.edge_metric == "":
        edge_metric = None
        print("No edge metrics calculated.")
        # Write empty file
        edges_diff = pd.DataFrame()
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

        # Perform differential network analysis
        edges_diff = modina.compute_diff_edges(
            scores1=scores1,
            scores2=scores2,
            edge_metric=edge_metric,
            max_path_length=max_path_length
        )
        
        if 'post' in edge_metric:
            edges_diff = edges_diff[['label1', 'label2', 'test_type', edge_metric]]
        else:
            edge_metric_signed = edge_metric + '_signed'
            edges_diff = edges_diff[['label1', 'label2', 'test_type', edge_metric, edge_metric_signed]]
                
 
    edges_diff.to_csv(f'{args.output_prefix}_{edge_metric}_edge_metrics.csv', index=True)

    print("Differential edge inference completed successfully")
