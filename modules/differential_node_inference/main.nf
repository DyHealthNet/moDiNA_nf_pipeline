process differential_node_inference {
    conda params.conda_modina_env

    publishDir "${params.out_dir}/differential_node_inference", mode: 'symlink'

    // One job per metric family (STC, WDC, PRC, none) computes all of its requested node metrics
    tag "${params.data_type == 'simulation' ? "sim${meta.id}_" : ""}${meta.node_family}"

    input:
        tuple val(meta), path(network_context_1), path(network_context_2), path(file_context_1), path(file_context_2), path(file_meta)

    output: // one file per metric in meta.node_metrics; main.nf splits them back into per-metric tuples
        tuple val(meta), path("*_node_metrics.csv"), path(file_meta), emit: node_metrics
    
    
    script:
    """
    differential_node_inference.py \
        --network_context_1 "${network_context_1}" \
        --network_context_2 "${network_context_2}" \
        --context_file_1 "${file_context_1}" \
        --context_file_2 "${file_context_2}" \
        --node_metrics "${meta.node_metrics.join(',')}" \
        ${params.diff_net_analysis.lp_cap ? "--lp_cap ${params.diff_net_analysis.lp_cap}" : ""} \
        --multiple_testing "${params.diff_net_analysis.multiple_testing}" \
        --nan_value "${params.diff_net_analysis.nan_value}" \
        --num_workers "${task.cpus}" \
        --output_prefix "${params.data_type == 'simulation' ? "sim${meta.id}" : ""}" \
        --meta-file "${file_meta}" \
        --test-type "${params.diff_net_analysis.test_type}"
    """
    
}
