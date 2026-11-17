process context_network_inference {
    conda params.conda_modina_env

    publishDir "${params.out_dir}/context_network_inference", mode: 'symlink'

    tag "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.context}"

    input:
        tuple val(meta), path(file_context_data), path(file_meta_data)

    output:
        tuple val(meta), path("${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.context}_association_scores.csv"), emit: association_scores
        tuple val(meta), path("${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.context}_association_scores_flagged_variables.csv"), emit: flagged_variables
        tuple val(meta), path("${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.context}_association_scores_scores_na.csv"), emit: scores_na

    script:
    // Params files replace the whole diff_net_analysis map, so n_min_valid may be absent there;
    // the flag is then omitted and the script's default (10) applies.
    def n_min_valid_arg = params.diff_net_analysis.n_min_valid != null ? "--n_min_valid ${params.diff_net_analysis.n_min_valid}" : ""
    """
        context_network_inference.py \\
            --context_file "${file_context_data}" \\
            --meta_file "${file_meta_data}" \\
            --test_type "${params.diff_net_analysis.test_type}" \\
            --multiple_testing "${params.diff_net_analysis.multiple_testing}" \\
            --num_workers "${task.cpus}" \\
            --nan_value "${params.diff_net_analysis.nan_value}" \\
            ${n_min_valid_arg} \\
            --output_prefix "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.context}_association_scores"       
    """
    
}
