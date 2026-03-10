process evaluation_mean_shifts {
    conda params.conda_eval_env

    publishDir "${params.out_dir}/evaluation_mean_shifts", mode: 'copy'

    input:
    path summary_file

    output:
    path "mean_shift_point_plot.png", emit: mean_shift_point_plot

    script:
    """
    evaluation_mean_shifts.R ${summary_file} ${params.data_type} ${params.name_context_1} ${params.name_context_2}
    """
}