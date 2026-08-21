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

    # Nodes present in only one of the two contexts' networks -- flagged (single observed
    # category, or entirely missing) in that context. This is the first step in the pipeline
    # where both contexts' scores meet, so it's the right place to report them: probit_rescaling
    # below silently removes them from both networks (via reconcile_flagged_variables) to keep
    # scores1/scores2 row-aligned, and no later step sees them again to report them.
    removed_nodes = modina.find_flagged_variables(scores1, scores2)
    pd.DataFrame({'label': removed_nodes}).to_csv('removed_nodes.csv', index=False)

    # Rescaling
    scores1, scores2 = modina.probit_rescaling(scores1=scores1, scores2=scores2, metric='rescaled-E')

    scores1.to_csv(f"{args.name_context_1}_rescaled_association_scores.csv", index=False)
    scores2.to_csv(f"{args.name_context_2}_rescaled_association_scores.csv", index=False)

    print("Rescaling of networks completed successfully")