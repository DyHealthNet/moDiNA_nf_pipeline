#!/usr/bin/env python3
import argparse
import sys
import pandas as pd
import modina

if __name__ == '__main__':

    """Parse command line arguments for filtering statistical association scores."""
    parser = argparse.ArgumentParser(
        description='Filter context-specific networks.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    # Context names
    parser.add_argument('--context_1', type=str, required=True,
                        help='Name of the first context (e.g., "control")')
    parser.add_argument('--context_2', type=str, required=True,
                        help='Name of the second context (e.g., "disease")')
   
    # Input files - statistical association scores
    parser.add_argument('--network_context_1', type=str, required=True,
                        help='Path to statistical association scores file for Context 1')
    parser.add_argument('--network_context_2', type=str, required=True,
                        help='Path to statistical association scores file for Context 2')
    
    # Context data files
    parser.add_argument('--context_file_1', type=str, required=True,
                        help='Path to the first context data file for differential network analysis')
    parser.add_argument('--context_file_2', type=str, required=True,
                        help='Path to the second context data file for differential network analysis')
    
    # Filtering parameters
    parser.add_argument('--filter_method', type=str, default=None,
                        help='Method used for filtering')
    parser.add_argument('--filter_param', type=float, default=0.0,
                        help='Parameter for the specified filtering method')
    parser.add_argument('--filter_metric', type=str, default=None,
                        help='Edge metric used for filtering')
    parser.add_argument('--filter_rule', type=str, default=None,
                        help='Rule to integrate the networks during filtering')
    parser.add_argument('--output_suffix', type=str, default='',
                        help='Suffix to append to output filenames (e.g., "_sim1")')
    
    args = parser.parse_args()
    
    # Read networks and input data
    scores1 = pd.read_csv(args.network_context_1)
    scores2 = pd.read_csv(args.network_context_2)
    data1 = pd.read_csv(args.context_file_1)
    data2 = pd.read_csv(args.context_file_2)
    
    # Apply filtering
    filtered_scores1, filtered_scores2, filtered_data1, filtered_data2 = modina.filter(
        scores1=scores1,
        scores2=scores2,
        context1=data1,
        context2=data2,
        filter_method=args.filter_method,
        filter_param=args.filter_param,
        filter_metric=args.filter_metric,
        filter_rule=args.filter_rule
    )
    
    # Save filtered outputs
    filtered_scores1.to_csv(f"{args.output_suffix}_filtered_{args.context_1}_association_scores.csv".lstrip('_'), index=False)
    filtered_scores2.to_csv(f"{args.output_suffix}_filtered_{args.context_2}_association_scores.csv".lstrip('_'), index=False)
    filtered_data1.to_csv(f"{args.output_suffix}_filtered_{args.context_1}_data.csv".lstrip('_'), index=False)
    filtered_data2.to_csv(f"{args.output_suffix}_filtered_{args.context_2}_data.csv".lstrip('_'), index=False)
    