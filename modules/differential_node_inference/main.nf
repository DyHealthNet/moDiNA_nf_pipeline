process differential_node_inference {
    conda params.conda_modina_env

    publishDir "${params.out_dir}/differential_node_inference", mode: 'copy'

    tag "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.node_metric}"

    input:
        tuple val(meta), path(network_context_1), path(network_context_2), path(file_context_1), path(file_context_2), path(file_meta)

    output: // here single tuple because we want to keep all files together as they are used together in ranking
        tuple val(meta), path("*_node_metrics.csv"), path(file_meta), emit: node_metrics
    
    
    script:
    """
    differential_node_inference.py \
        --network_context_1 "${network_context_1}" \
        --network_context_2 "${network_context_2}" \
        --context_file_1 "${file_context_1}" \
        --context_file_2 "${file_context_2}" \
        --node_metric "${meta.node_metric}" \
        --multiple_testing "${params.diff_net_analysis.multiple_testing}" \
        --output_prefix "${params.data_type == 'simulation' ? "sim${meta.id}" : ""}" \
        --meta-file "${file_meta}"
    """
    
}