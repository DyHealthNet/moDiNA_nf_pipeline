process evaluation_roc_recall_enrichment {
    conda params.conda_eval_env

    publishDir "${params.out_dir}/evaluation_roc_recall_enrichment", mode: 'copy'

    input:
    path summary_file

    output:
    path "ROC_curves_*.png", emit: roc_plots
    path "recall_curve_*.png", emit: recall_plots
    path "enrichment_boxplot_*.png", emit: enrichment_plots

    script:
    """
    evaluation_roc_recall_enrichment.R ${summary_file}
    """
}