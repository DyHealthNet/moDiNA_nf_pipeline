process differential_edge_inference {
    publishDir "${params.out_dir}/differential_edge_inference", mode: 'copy'

    cpus 8
    memory '32 GB'

    tag "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.edge_metric}"

    input:
        tuple val(meta), path(network_context_1), path(network_context_2)

    output: // here single tuple because we want to keep all files together as they are used together in ranking
        tuple val(meta), path("*_edge_metrics.csv"), emit: edge_metrics
    
    script:
    """
        differential_edge_inference.py \
            --network_context_1 "${network_context_1}" \
            --network_context_2 "${network_context_2}" \
            --edge_metric "${meta.edge_metric}" \
            ${params.diff_net_analysis.max_path_length ? "--max_path_length ${params.diff_net_analysis.max_path_length}" : ""} \
            --output_prefix "${params.data_type == 'simulation' ? "sim${meta.id}" : ""}"
    """
    
}