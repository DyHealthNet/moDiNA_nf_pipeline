#!/usr/bin/env python3
import argparse
import sys
import pandas as pd
import modina 

if __name__ == '__main__':

    """Parse command line arguments for rescaling networks."""
    parser = argparse.ArgumentParser(
        description='Perform rescaling of network association scores.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    # Network input files
    parser.add_argument('--network_context_1', type=str, required=True,
                        help='Path to network file for context 1')
    parser.add_argument('--network_context_2', type=str, required=True,
                        help='Path to network file for context 2')
    
    parser.add_argument('--name_context_1', type=str, required=True,
                        help='Name of context 1')
    parser.add_argument('--name_context_2', type=str, required=True,
                        help='Name of context 2')
    
    args = parser.parse_args()
    
    # Read networks and input data
    scores1 = pd.read_csv(args.network_context_1)
    scores2 = pd.read_csv(args.network_context_2)
    
    # Rescaling
    scores1, scores2 = modina.pre_rescaling(scores1=scores1, scores2=scores2, metric='pre-E')
    scores1, scores2 = modina.pre_rescaling(scores1=scores1, scores2=scores2, metric='pre-P')  
    
    scores1.to_csv(f"{args.name_context_1}_rescaled_association_scores.csv", index=False)
    scores2.to_csv(f"{args.name_context_2}_rescaled_association_scores.csv", index=False)

    print("Rescaling of networks completed successfully")