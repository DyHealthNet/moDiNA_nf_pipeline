process filter_differential_network {
    conda params.conda_modina_env

    publishDir "${params.out_dir}/filtered_differential_network", mode: 'copy'

    tag "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.edge_metric}"

    input:
        tuple val(meta), path(edge_metrics), path(edge_node_stats)

    output: // keep the same tuple shape as differential_edge_inference so ranking is unaffected
        tuple val(meta), path("*_filtered_edge_metrics.csv"), path("*_filtered_edge_node_stats.csv"), emit: edge_metrics

    script:
    """
        filter_differential_network.py \\
            --edges "${edge_metrics}" \\
            --edge_metric "${meta.edge_metric}" \\
            --filter_method "${params.diff_net_analysis.filter_method}" \\
            --filter_param "${params.diff_net_analysis.filter_param}" \\
            --output_prefix "${params.data_type == 'simulation' ? "sim${meta.id}" : ""}"
    """

}
