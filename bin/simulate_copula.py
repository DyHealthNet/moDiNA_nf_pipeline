#!/usr/bin/env python3
import modina
import argparse


if __name__ == '__main__':
    """Parse command line arguments for copula simulation."""
    parser = argparse.ArgumentParser(
        description='Simulate mixed-type data using copula methods for differential network analysis.'
    )
    
    # Context names
    parser.add_argument('--context_1', type=str, required=True,
                        help='Name of the first context (e.g., "control")')
    parser.add_argument('--context_2', type=str, required=True,
                        help='Name of the second context (e.g., "disease")')
    
    # Number of nodes
    parser.add_argument('--n_bi', type=int, required=True,
                        help='Number of binary nodes to simulate')
    parser.add_argument('--n_cont', type=int, required=True,
                        help='Number of continuous nodes to simulate')
    parser.add_argument('--n_cat', type=int, required=True,
                        help='Number of categorical nodes to simulate')

    # Sample size
    parser.add_argument('--n_samples', type=int, required=True,
                        help='Number of samples per context')

    # Mean shift nodes
    parser.add_argument('--n_shift_cont', type=int, required=True,
                        help='Number of continuous nodes with an artificially introduced mean shift')
    parser.add_argument('--n_shift_bi', type=int, required=True,
                        help='Number of binary nodes with an artificially introduced mean shift')
    parser.add_argument('--n_shift_cat', type=int, required=True,
                        help='Number of categorical nodes with an artificially introduced mean shift')

    # Correlation difference node pairs
    parser.add_argument('--n_corr_cont_cont', type=int, required=True,
                        help='Number of continuous node pairs with an artificially introduced correlation difference')
    parser.add_argument('--n_corr_bi_bi', type=int, required=True,
                        help='Number of binary node pairs with an artificially introduced correlation difference')
    parser.add_argument('--n_corr_cat_cat', type=int, required=True,
                        help='Number of categorical node pairs with an artificially introduced correlation difference')
    parser.add_argument('--n_corr_bi_cat', type=int, required=True,
                        help='Number of binary-categorical node pairs with an artificially introduced correlation difference')
    parser.add_argument('--n_corr_cont_cat', type=int, required=True,
                        help='Number of continuous-categorical node pairs with an artificially introduced correlation difference')
    parser.add_argument('--n_corr_bi_cont', type=int, required=True,
                        help='Number of binary-continuous node pairs with an artificially introduced correlation difference')

    # Both mean shift and correlation difference node pairs
    parser.add_argument('--n_both_cont_cont', type=int, required=True,
                        help='Number of continuous node pairs with both an artificially introduced mean shift and correlation difference')
    parser.add_argument('--n_both_bi_bi', type=int, required=True,
                        help='Number of binary node pairs with both an artificially introduced mean shift and correlation difference')
    parser.add_argument('--n_both_cat_cat', type=int, required=True,
                        help='Number of categorical node pairs with both an artificially introduced mean shift and correlation difference')
    parser.add_argument('--n_both_bi_cat', type=int, required=True,
                        help='Number of binary-categorical node pairs with both an artificially introduced mean shift and correlation difference')
    parser.add_argument('--n_both_cont_cat', type=int, required=True,
                        help='Number of continuous-categorical node pairs with both an artificially introduced mean shift and correlation difference')
    parser.add_argument('--n_both_bi_cont', type=int, required=True,
                        help='Number of binary-continuous node pairs with both an artificially introduced mean shift and correlation difference')

    # Magnitude parameters
    parser.add_argument('--shift', type=float, required=True,
                        help='Magnitude of the mean shift')
    parser.add_argument('--corr', type=float, required=True,
                        help='Magnitude of the correlation difference (measured as correlation coefficient between 0 and 1)')
    parser.add_argument('--output_suffix', type=str, default='',
                        help='Suffix to append to output filenames (e.g., "_sim1")')

    
    args = parser.parse_args()
    
    # Run simulation
    context1, context2, meta, (shift_nodes, corr_nodes, shift_corr_nodes) = modina.simulate_copula(
                           name1 =args.context_1,
                           name2 =args.context_2,
                           n_bi =args.n_bi,
                           n_cont =args.n_cont,
                           n_cat = args.n_cat,
                           n_samples =args.n_samples,
                           n_shift_cont =args.n_shift_cont,
                           n_shift_bi =args.n_shift_bi,
                           n_shift_cat = args.n_shift_cat,
                           n_corr_cont_cont =args.n_corr_cont_cont,
                           n_corr_bi_bi =args.n_corr_bi_bi,
                           n_corr_cat_cat = args.n_corr_cat_cat,
                           n_corr_bi_cont = args.n_corr_bi_cont,
                           n_corr_bi_cat = args.n_corr_bi_cat,
                           n_corr_cont_cat = args.n_corr_cont_cat,
                           n_both_cont_cont =args.n_both_cont_cont,
                           n_both_bi_bi =args.n_both_bi_bi,
                           n_both_cat_cat =args.n_both_cat_cat,
                           n_both_bi_cont = args.n_both_bi_cont,
                           n_both_bi_cat = args.n_both_bi_cat,
                           n_both_cont_cat = args.n_both_cont_cat,
                           shift = args.shift,
                           corr =args.corr)
    
    # Write output files
    context1.to_csv(f'{args.context_1}_simulated_data_{args.output_suffix}.csv', index=False)
    context2.to_csv(f'{args.context_2}_simulated_data_{args.output_suffix}.csv', index=False)
    meta.to_csv(f'meta_{args.output_suffix}.csv', index=False)
    modina.save_gt((shift_nodes, corr_nodes, shift_corr_nodes), f'ground_truth_simulated_nodes_{args.output_suffix}.txt', mode = 'node')
    modina.save_gt((shift_nodes, corr_nodes, shift_corr_nodes), f'ground_truth_simulated_edges_{args.output_suffix}.txt', mode = 'edge')
    