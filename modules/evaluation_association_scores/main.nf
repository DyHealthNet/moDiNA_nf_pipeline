process evaluation_association_scores {
    conda "/home/larend/miniforge3/envs/modina-evaluation-env"
    publishDir "${params.out_dir}/evaluation_association_scores", mode: 'copy'

    input:
    path summary_file

    output:
    path "association_scores_point_plot.png", emit: heatmap

    script:
    """
    evaluation_association_scores.R ${summary_file} ${params.data_type} ${params.name_context_1} ${params.name_context_2}
    """
}