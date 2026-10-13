process node_ranking {
    conda params.conda_modina_env

    publishDir "${params.out_dir}/rankings", mode: 'symlink'

    // One job per ranking algorithm computes all of its configurations
    tag "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.algorithm}"

    input:
        tuple val(meta), val(configs), path(node_rankings), path(edge_rankings), path(edge_node_stats), path(meta_file)

    output: // one ranking file per entry in configs; main.nf splits them back into per-configuration tuples
        tuple val(meta), val(configs), path("*_ranking.csv")


    script:
    // Metric names and file names contain neither commas nor single quotes
    def config_lines = ['node_metric,edge_metric,node_file,edge_file,stats_file,output_prefix'] +
        configs.collect { c -> [c.node_metric, c.edge_metric, c.node_file, c.edge_file, c.stats_file, c.output_prefix].join(',') }
    """
        printf '%s\\n' ${config_lines.collect { "'${it}'" }.join(' ')} > configs.csv

        node_ranking.py \\
            --config_file configs.csv \\
            --meta_file "${meta_file}" \\
            --ranking_algorithm "${meta.algorithm}"
    """
    
}
