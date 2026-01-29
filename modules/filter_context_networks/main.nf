process filter_context_networks {
    publishDir "${params.out_dir}/context_network_inference", mode: 'copy'

    cpus 8
    memory '32 GB'

    tag "${params.data_type == 'simulation' ? "sim${simulation_id}" : "filtering"}"

    input:
        tuple val(simulation_id), path(network_context_1), path(network_context_2), path(context_file_1), path(context_file_2)

    output:
        tuple val(simulation_id), path("${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}filtered_${params.name_context_1}_association_scores.csv"), emit: filtered_network_context_1
        tuple val(simulation_id), path("${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}filtered_${params.name_context_2}_association_scores.csv"), emit: filtered_network_context_2
        tuple val(simulation_id), path("${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}filtered_${params.name_context_1}_data.csv"), emit: filtered_input_context_1
        tuple val(simulation_id), path("${params.data_type == 'simulation' ? "sim${simulation_id}_" : ""}filtered_${params.name_context_2}_data.csv"), emit: filtered_input_context_2
    
    script:
    """
        filter_context_networks.py \
            --context_1 "${params.name_context_1}" \
            --context_2 "${params.name_context_2}" \
            --network_context_1 "${network_context_1}" \
            --network_context_2 "${network_context_2}" \
            --context_file_1 "${context_file_1}" \
            --context_file_2 "${context_file_2}" \
            --filter_method "${params.diff_net_analysis.filter_method}" \
            --filter_param "${params.diff_net_analysis.filter_param}" \
            --filter_metric "${params.diff_net_analysis.filter_metric}" \
            --filter_rule "${params.diff_net_analysis.filter_rule}" \
            ${params.data_type == 'simulation' ? "--output_suffix _sim${simulation_id}" : ""}
    """
    
}