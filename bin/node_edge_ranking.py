#!/usr/bin/env python3
import argparse
import sys
import modina
import pandas as pd

if __name__ == '__main__':


    """Parse command line arguments for computing rankings."""
    parser = argparse.ArgumentParser(
        description='Compute node and/or edge rankings from differential network.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    # Input files
    parser.add_argument('--node_metric_file', type=str, required=True,
                        help='Path to differential node scores file (CSV)')
    parser.add_argument('--edge_metric_file', type=str, required=True,
                        help='Path to differential edge scores file (CSV)')
    parser.add_argument('--meta_file', type=str, required=True,
                        help='Path to metadata file')
    
    # Ranking algorithm
    parser.add_argument('--ranking_algorithm', type=str, required=True,
                        choices=['PageRank+', 'PageRank', 'absDimontRank', 
                                'DimontRank', 'nodeRank', 'edgeRank'],
                        help='Ranking algorithm to compute')
    
    # Output
    parser.add_argument('--output_prefix', type=str, required=True,
                        help='Prefix for output files')
    
    args = parser.parse_args()
    
    # Load data with error handling
    try:
        nodes_diff = pd.read_csv(args.node_metric_file, index_col=0)
    except pd.errors.EmptyDataError:
        nodes_diff = None
    if nodes_diff is not None and nodes_diff.empty:
        nodes_diff = None

    try:
        edges_diff = pd.read_csv(args.edge_metric_file, index_col=0)
    except pd.errors.EmptyDataError:
        edges_diff = None
    if edges_diff is not None and edges_diff.empty:
        edges_diff = None
        
    meta_df = pd.read_csv(args.meta_file)


    # Run ranking computation
    ranks = modina.compute_ranking(
        nodes_diff=nodes_diff,
        edges_diff=edges_diff,
        ranking_alg=args.ranking_algorithm,
        meta_file=meta_df
    )
    
    #ranking_df = pd.DataFrame({"node": ranks, "rank": range(1, len(ranks) + 1)})
    #ranking_df = ranking_df.sort_values("node")
    ranks.to_csv(f'{args.output_prefix}_ranking.csv', index=False)
    
    # For each list in ranks_per_type, check if not empty and save as csv -> first item is cont, binary, categorical
    #for type_name, type_ranks in ranks_per_type.items():
    #    if type_ranks:
    #        type_ranking_df = pd.DataFrame({"node": type_ranks, "rank": range(1, len(type_ranks) + 1)})
    #        type_ranking_df = type_ranking_df.sort_values("node")
    #        type_ranking_df.to_csv(f'{args.output_prefix}_ranking_{type_name}.csv', index=False)
    print("Ranking computation completed successfully")
    
    