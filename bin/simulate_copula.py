#!/usr/bin/env python3
import argparse
import random

import numpy as np
import modina


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
    parser.add_argument('--n_samples_1', type=int, required=True,
                        help='Number of samples for the first context')
    parser.add_argument('--n_samples_2', type=int, required=True,
                        help='Number of samples for the second context')

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

    # Magnitude parameters. Each ground truth effect draws its own magnitude uniformly from the
    # given range, so one run spans the whole weak-to-strong spectrum instead of a single operating
    # point; the drawn value is written into the ground truth files for post-hoc ranking/binning.
    # These replace the former single-valued --shift/--corr, which modina no longer accepts.
    parser.add_argument('--corr_low', type=float, required=True,
                        help='Lower end of the correlation-difference range (0 <= corr_low <= corr_high <= 0.95)')
    parser.add_argument('--corr_high', type=float, required=True,
                        help='Upper end of the correlation-difference range (0 <= corr_low <= corr_high <= 0.95)')
    parser.add_argument('--shift_low', type=float, required=True,
                        help='Lower end of the mean-shift range (0 <= shift_low <= shift_high)')
    parser.add_argument('--shift_high', type=float, required=True,
                        help='Upper end of the mean-shift range (0 <= shift_low <= shift_high)')
    parser.add_argument('--hub_reuse_prob', type=float, default=0.0,
                        help='Fraction of each pair type\'s correlation/both pairs that reuse an '
                             'already-placed node as a hub instead of drawing two fresh nodes, spread '
                             'evenly across node types (0.0 = one edge per node, the default)')

    # Shared scale-free background correlation structure. Built once and copied to both contexts, so every
    # non-ground-truth pair holds identical values in the two correlation matrices and its true
    # between-context difference is exactly zero.
    parser.add_argument('--background_strength', type=float, default=0.2,
                        help='Target mean |r| over the directly wired pairs of the background')
    parser.add_argument('--background_density', type=int, default=2,
                        help='Connections each node makes when it is added to the background '
                             'network')
    parser.add_argument('--background_seed', type=int, default=None,
                        help='Seed for the background\'s own random generator, kept separate from '
                             'the streams the rest of the simulation draws from. Omit for a fresh '
                             'background per replicate')

    parser.add_argument('--seed', type=int, default=None,
                        help='Seed for the planting and sampling streams (`random` and `np.random`). '
                             'Omit for a fresh, non-reproducible draw')

    parser.add_argument('--output_suffix', type=str, default='',
                        help='Suffix to append to output filenames (e.g., "_sim1")')


    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)
        np.random.seed(args.seed)
    
    # Run simulation
    context1, context2, meta, (shift_nodes, corr_nodes, shift_corr_nodes), effects = modina.simulate_copula(
                           name1 =args.context_1,
                           name2 =args.context_2,
                           n_bi =args.n_bi,
                           n_cont =args.n_cont,
                           n_cat = args.n_cat,
                           n_samples_1 =args.n_samples_1,
                           n_samples_2 =args.n_samples_2,
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
                           corr_low = args.corr_low,
                           corr_high = args.corr_high,
                           shift_low = args.shift_low,
                           shift_high = args.shift_high,
                           hub_reuse_prob = args.hub_reuse_prob,
                           background_strength = args.background_strength,
                           background_density = args.background_density,
                           background_seed = args.background_seed)

    # Per-node ground-truth stats (n_edges_tweaked, sum_magnitude) for save_gt's node file;
    # a node absent here (mean-shift-only) falls back to (0, 0.0) via save_gt's own .get() default.
    gt_nodes = set(shift_nodes)
    for pair in corr_nodes + shift_corr_nodes:
        gt_nodes.update(pair)
    node_stats = {node: (effects['node_degree'].get(node, 0), effects['node_sum_magnitude'].get(node, 0.0))
                  for node in gt_nodes}

    # Write output files
    context1.to_csv(f'{args.context_1}_simulated_data_{args.output_suffix}.csv', index=False)
    context2.to_csv(f'{args.context_2}_simulated_data_{args.output_suffix}.csv', index=False)
    meta.to_csv(f'meta_{args.output_suffix}.csv', index=False)
    # `node_shift_magnitude` adds the per-node drawn shift as a further named column. Ranged draws
    # make this necessary: without it the realized shift of a node is unrecoverable from the output.
    modina.save_gt((shift_nodes, corr_nodes, shift_corr_nodes), f'ground_truth_simulated_nodes_{args.output_suffix}.txt', mode = 'node', node_stats=node_stats, node_shift_magnitude=effects['node_shift_magnitude'])
    modina.save_gt((shift_nodes, corr_nodes, shift_corr_nodes), f'ground_truth_simulated_edges_{args.output_suffix}.txt', mode = 'edge', edge_magnitude=effects['edge_magnitude'])
    