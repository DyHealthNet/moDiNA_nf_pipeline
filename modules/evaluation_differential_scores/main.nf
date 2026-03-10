process evaluation_differential_scores {
    conda params.conda_eval_env
    publishDir "${params.out_dir}/evaluation_differential_scores", mode: 'copy'

    input:
    path summary_file

    output:
    path "node_metrics_point_plots.png", emit: node_metrics_point_plot
    path "edge_metrics_point_plots.png", emit: edge_metrics_point_plot

    script:
    """
    evaluation_differential_scores.R ${summary_file} ${params.data_type}
    """
}