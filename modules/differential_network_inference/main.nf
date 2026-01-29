process differential_network_inference {
    publishDir "${params.out_dir}/differential_network_inference", mode: 'copy'

    cpus 8
    memory '32 GB'

    tag "${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}${node_metric}_${edge_metric}"

    input:
        tuple val(simulation_id), val(node_metric), val(edge_metric), path(network_context_1), path(network_context_2), path(file_context_1), path(file_context_2), path(file_meta)

    output:
        tuple val(simulation_id), val(node_metric), val(edge_metric), path("${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}${node_metric}_${edge_metric}_node_metrics.csv"), path("${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}${node_metric}_${edge_metric}_edge_metrics.csv"), path(file_meta)
    
    script:
    """
        differential_network_inference.py \
            --network_context_1 "${network_context_1}" \
            --network_context_2 "${network_context_2}" \
            --context_file_1 "${file_context_1}" \
            --context_file_2 "${file_context_2}" \
            --node_metric "${node_metric}" \
            --edge_metric "${edge_metric}" \
            ${params.diff_net_analysis.stc_test ? "--stc_test ${params.diff_net_analysis.stc_test}" : ""} \
            ${params.diff_net_analysis.max_path_length ? "--max_path_length ${params.diff_net_analysis.max_path_length}" : ""} \
            --multiple_testing "${params.diff_net_analysis.multiple_testing}" \
            --output_prefix "${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}${node_metric}_${edge_metric}" 
    """
    
}