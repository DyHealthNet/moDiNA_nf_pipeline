process differential_edge_inference {
    conda params.conda_modina_env

    publishDir "${params.out_dir}/differential_edge_inference", mode: 'symlink'

    // One job per metric family (diff, sum, none) computes all of its requested edge metrics
    tag "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.edge_family}"

    input:
        tuple val(meta), path(network_context_1), path(network_context_2)

    output: // one file pair per metric in meta.edge_metrics; main.nf splits them back into per-metric tuples
        tuple val(meta), path("*_edge_metrics.csv"), path("*_edge_node_stats.csv"), emit: edge_metrics

    script:
    """
        differential_edge_inference.py \
            --network_context_1 "${network_context_1}" \
            --network_context_2 "${network_context_2}" \
            --edge_metrics "${meta.edge_metrics.join(',')}" \
            ${params.diff_net_analysis.lp_cap ? "--lp_cap ${params.diff_net_analysis.lp_cap}" : ""} \
            --output_prefix "${params.data_type == 'simulation' ? "sim${meta.id}" : ""}"
    """
    
}
