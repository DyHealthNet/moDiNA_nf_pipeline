#!/usr/bin/env python3
import modina
import argparse
import pandas as pd


if __name__ == '__main__':
    """Parse command line arguments for context network inference."""
    parser = argparse.ArgumentParser(
        description='Infer context network using association scores with moDiNA.'
    )
    
    # Data inputs
    parser.add_argument('--context_file', type=str, required=True,
                        help='Path to the raw context data file (rows: samples, columns: variables)')
    parser.add_argument('--meta_file', type=str, required=True,
                        help='Path to metadata file containing label and type columns')
    
    # Statistical test parameters
    parser.add_argument('--cont_cont', type=str, default='spearman',
                        help='Test for continuous-continuous association scores')
    parser.add_argument('--bi_cont', type=str, default='mann-whitney u',
                        help='Test for categorical-continuous association (binary) scores')
    parser.add_argument('--cont_cat', type=str, default='kruskal-wallis',
                        help='Test for categorical-continuous association (multiple) scores')
    parser.add_argument('--multiple_testing', type=str, default='bh',
                        help='Correction method for multiple testing')
    
    # Additional parameters
    parser.add_argument('--num_workers', type=int, default=1,
                        help='Number of workers for parallel processing')
    parser.add_argument('--output_prefix', type=str, required=True,
                        help='Prefix for output files')
    
    args = parser.parse_args()
    
    # Load data
    context_data = pd.read_csv(args.context_file)
    meta_file = pd.read_csv(args.meta_file)
    
    # Run context network inference
    association_scores = modina.compute_context_scores(
        context_data=context_data,
        meta_file=meta_file,
        cont_cont=args.cont_cont,
        bi_cont=args.bi_cont,
        cont_cat=args.cont_cat,
        correction=args.multiple_testing,
        num_workers=args.num_workers,
    )
    
    association_scores.to_csv(f'{args.output_prefix}.csv', index=False)
    print("Context network inference completed successfully")