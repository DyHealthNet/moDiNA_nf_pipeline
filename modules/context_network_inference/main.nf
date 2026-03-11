process context_network_inference {
    conda params.conda_modina_env

    publishDir "${params.out_dir}/context_network_inference", mode: 'copy'

    tag "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.context}"

    input:
        tuple val(meta), path(file_context_data), path(file_meta_data)

    output:
        tuple val(meta), path("${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.context}_association_scores.csv")
    
    script:
    """
        context_network_inference.py \\
            --context_file "${file_context_data}" \\
            --meta_file "${file_meta_data}" \\
            --test_type "${params.diff_net_analysis.test_type}" \\
            --multiple_testing "${params.diff_net_analysis.multiple_testing}" \\
            --num_workers "${task.cpus}" \\
            --nan_value "${params.diff_net_analysis.nan_value}" \\
            --output_prefix "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.context}_association_scores"       
    """
    
}