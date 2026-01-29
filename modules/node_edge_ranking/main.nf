process node_edge_ranking {
    publishDir "${params.out_dir}/rankings", mode: 'copy'

    cpus 8
    memory '32 GB'

    tag "${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}${node_metric}_${edge_metric}_${ranking_algorithm}"

    input:
        tuple val(simulation_id), val(node_metric), val(edge_metric), val(ranking_algorithm), path(node_rankings), path(edge_rankings), path(meta_file)

    output:
        tuple val(simulation_id), val(node_metric), val(edge_metric), val(ranking_algorithm), path("${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}${node_metric}_${edge_metric}_${ranking_algorithm}_ranking.csv"), path(meta_file)
    
    script:
    """
        node_edge_ranking.py \\
            --node_metric_file "${node_rankings}" \\
            --edge_metric_file "${edge_rankings}" \\
            --meta_file "${meta_file}" \\
            --ranking_algorithm "${ranking_algorithm}" \\
            --output_prefix "${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}${node_metric}_${edge_metric}_${ranking_algorithm}"
    """
    
}