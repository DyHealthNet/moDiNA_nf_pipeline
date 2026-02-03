process context_network_inference {
    publishDir "${params.out_dir}/context_network_inference", mode: 'copy'

    cpus 8
    memory '32 GB'

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
            --cont_cont "${params.diff_net_analysis.cont_cont}" \\
            --bi_cont "${params.diff_net_analysis.bi_cont}" \\
            --cont_cat "${params.diff_net_analysis.cont_cat}" \\
            --multiple_testing "${params.diff_net_analysis.multiple_testing}" \\
            --num_workers "${task.cpus}" \\
            --output_prefix "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.context}_association_scores"       
    """
    
}