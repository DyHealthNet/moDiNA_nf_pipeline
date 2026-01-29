process context_network_inference {
    publishDir "${params.out_dir}/context_network_inference", mode: 'copy'

    cpus 8
    memory '32 GB'

    tag "${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}${context_name}"

    input:
        tuple val(simulation_id), val(context_name), path(file_context_data), path(file_meta_data)

    output:
        tuple val(simulation_id), val(context_name), path("${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}${context_name}_association_scores.csv")
    script:
    """
        context_network_inference.py \\
            --context_file "${file_context_data}" \\
            --meta_file "${file_meta_data}" \\
            --cont_cont "${params.diff_net_analysis.cont_cont}" \\
            --bi_cont "${params.diff_net_analysis.bi_cont}" \\
            --cont_cat "${params.diff_net_analysis.cont_cat}" \\
            --multiple_testing "${params.diff_net_analysis.multiple_testing}" \\
            --num_workers "${task.cpus}" \\
            --output_prefix "${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}${context_name}_association_scores"       
    """
    
}