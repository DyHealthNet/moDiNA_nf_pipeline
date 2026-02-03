process node_edge_ranking {
    publishDir "${params.out_dir}/rankings", mode: 'copy'

    cpus 8
    memory '32 GB'

    tag "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.node_metric}_${meta.edge_metric}_${meta.algorithm}"

    input:
        tuple val(meta), path(node_rankings), path(edge_rankings), path(meta_file)

    output:
        tuple val(meta), path(node_rankings), path(edge_rankings), path("${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.node_metric}_${meta.edge_metric}_${meta.algorithm}_ranking.csv")

    
    script:
    """
        node_edge_ranking.py \\
            --node_metric_file "${node_rankings}" \\
            --edge_metric_file "${edge_rankings}" \\
            --meta_file "${meta_file}" \\
            --ranking_algorithm "${meta.algorithm}" \\
            --output_prefix "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.node_metric}_${meta.edge_metric}_${meta.algorithm}"
    """
    
}