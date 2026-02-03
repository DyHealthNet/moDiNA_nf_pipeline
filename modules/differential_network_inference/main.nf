process differential_network_inference {
    publishDir "${params.out_dir}/differential_network_inference", mode: 'copy'

    cpus 8
    memory '32 GB'

    tag "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.node_metric}_${meta.edge_metric}"

    input:
        tuple val(meta), path(network_context_1), path(network_context_2), path(file_context_1), path(file_context_2), path(file_meta)

    output: // here single tuple because we want to keep all files together as they are used together in ranking
        tuple val(meta), path("*_node_metrics.csv"), path("*_edge_metrics.csv"), path(file_meta), emit: all_outputs
    
    script:
    """
        differential_network_inference.py \
            --network_context_1 "${network_context_1}" \
            --network_context_2 "${network_context_2}" \
            --context_file_1 "${file_context_1}" \
            --context_file_2 "${file_context_2}" \
            --node_metric "${meta.node_metric}" \
            --edge_metric "${meta.edge_metric}" \
            ${params.diff_net_analysis.stc_test ? "--stc_test ${params.diff_net_analysis.stc_test}" : ""} \
            ${params.diff_net_analysis.max_path_length ? "--max_path_length ${params.diff_net_analysis.max_path_length}" : ""} \
            --multiple_testing "${params.diff_net_analysis.multiple_testing}" \
            --output_prefix "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.node_metric}_${meta.edge_metric}" 
    """
    
}