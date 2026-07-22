process node_ranking {
    conda params.conda_modina_env

    publishDir "${params.out_dir}/rankings", mode: 'copy'

    tag "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.node_metric}_${meta.edge_metric}_${meta.algorithm}"

    input:
        tuple val(meta), path(node_rankings), path(edge_rankings), path(edge_node_stats), path(meta_file)

    output:
        tuple val(meta), path(node_rankings), path(edge_rankings), path("${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.node_metric}_${meta.edge_metric}_${meta.algorithm}_ranking.csv")


    script:
    """
        node_ranking.py \\
            --node_metric_file "${node_rankings}" \\
            --edge_metric_file "${edge_rankings}" \\
            --edge_node_stats_file "${edge_node_stats}" \\
            --meta_file "${meta_file}" \\
            --ranking_algorithm "${meta.algorithm}" \\
            --output_prefix "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.node_metric}_${meta.edge_metric}_${meta.algorithm}"
    """
    
}