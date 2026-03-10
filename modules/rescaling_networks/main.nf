process rescaling_networks {
    conda params.conda_modina_env

    publishDir "${params.out_dir}/rescaled_networks", mode: 'copy'

    tag "${params.data_type == 'simulation' ? "sim${meta.id}" : ""}"

    input:
    tuple val(meta), path(network_context_1), path(network_context_2)
    
    output:
    tuple val(meta), path("${params.name_context_1}_rescaled_association_scores.csv"), emit: rescaled_network_context_1
    tuple val(meta), path("${params.name_context_2}_rescaled_association_scores.csv"), emit: rescaled_network_context_2
    
    script:
    """
    rescaling_networks.py \\
        --network_context_1 "${network_context_1}" \\
        --network_context_2 "${network_context_2}" \\
        --name_context_1 "${params.name_context_1}" \\
        --name_context_2 "${params.name_context_2}"
    """
}