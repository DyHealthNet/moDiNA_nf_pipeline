process evaluation_auc {
    conda params.conda_eval_env
    publishDir "${params.out_dir}/evaluation_auc", mode: 'copy'

    input:
    path summary_file

    output:
    path "overall_heatmap_auc.png", emit: heatmap
    path "barplot_auc_algorithm_*_edge_metrics_colored.png", emit: edge_plots
    path "barplot_auc_algorithm_*_node_metrics_colored.png", emit: node_plots

    script:
    """
    evaluation_auc.R ${summary_file}
    """
}