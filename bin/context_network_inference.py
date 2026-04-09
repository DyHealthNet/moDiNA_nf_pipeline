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
    parser.add_argument('--test_type', type=str, default='nonparametric',
                        help='Type of statistical test to use for association score computation (e.g., "parametric", "nonparametric")')
    parser.add_argument('--multiple_testing', type=str, default='bh',
                        help='Correction method for multiple testing')
    parser.add_argument('--nan_value', type=int, default=-89,
                        help='Value that represents the NA values in the input data')
    
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
        test_type=args.test_type,
        correction=args.multiple_testing,
        nan_value=args.nan_value,
        num_workers=args.num_workers,
    )
    
    association_scores.to_csv(f'{args.output_prefix}.csv', index=False)
    print("Context network inference completed successfully")
