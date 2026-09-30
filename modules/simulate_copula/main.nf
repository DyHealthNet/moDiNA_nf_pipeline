process simulate_copula {
    conda params.conda_modina_env

    publishDir "${params.out_dir}/copula_simulation", mode: 'symlink'

    when: params.data_type == 'simulation'

    input:
        val meta  // meta map: [id: simulation_id]

    output:
        tuple val(meta), path("${params.name_context_1}_simulated_data_${meta.id}.csv"), emit: file_context_1
        tuple val(meta), path("${params.name_context_2}_simulated_data_${meta.id}.csv"), emit: file_context_2
        tuple val(meta), path("meta_${meta.id}.csv"), emit: file_meta
        tuple val(meta), path("ground_truth_simulated_nodes_${meta.id}.txt"), emit: file_ground_truth_nodes
        tuple val(meta), path("ground_truth_simulated_edges_${meta.id}.txt"), emit: file_ground_truth_edges
    
    // `background_seed` is offset by meta.id so each replicate draws its own background network
    // rather than all n_simulations replicates sharing one; results then are not conditional on a
    // single lucky or unlucky background draw, while the set as a whole stays reproducible. Leave
    // the parameter unset for a non-reproducible fresh background per replicate.
    // The `?:` fallbacks keep the process working for params files that predate the background;
    // every value they guard is invalid when falsy, so none of them can mask a deliberate setting.
    script:
    """
        simulate_copula.py \
            --context_1 "${params.name_context_1}" \
            --context_2 "${params.name_context_2}" \
            --n_bi "${params.simulation.n_bi}" \
            --n_cont "${params.simulation.n_cont}" \
            --n_cat "${params.simulation.n_cat}" \
            --n_samples_1 "${params.simulation.n_samples_1}" \
            --n_samples_2 "${params.simulation.n_samples_2}" \
            --n_shift_cont "${params.simulation.n_shift_cont}" \
            --n_shift_bi "${params.simulation.n_shift_bi}" \
            --n_shift_cat "${params.simulation.n_shift_cat}" \
            --n_corr_cont_cont "${params.simulation.n_corr_cont_cont}" \
            --n_corr_bi_bi "${params.simulation.n_corr_bi_bi}" \
            --n_corr_cat_cat "${params.simulation.n_corr_cat_cat}" \
            --n_corr_bi_cat "${params.simulation.n_corr_bi_cat}" \
            --n_corr_cont_cat "${params.simulation.n_corr_cont_cat}" \
            --n_corr_bi_cont "${params.simulation.n_corr_bi_cont}" \
            --n_both_cont_cont "${params.simulation.n_both_cont_cont}" \
            --n_both_bi_bi "${params.simulation.n_both_bi_bi}" \
            --n_both_cat_cat "${params.simulation.n_both_cat_cat}" \
            --n_both_bi_cat "${params.simulation.n_both_bi_cat}" \
            --n_both_cont_cat "${params.simulation.n_both_cont_cat}" \
            --n_both_bi_cont "${params.simulation.n_both_bi_cont}" \
            --corr_low ${params.simulation.corr_low} \
            --corr_high ${params.simulation.corr_high} \
            --shift_low ${params.simulation.shift_low} \
            --shift_high ${params.simulation.shift_high} \
            --hub_reuse_prob ${params.simulation.hub_reuse_prob ?: 0.0} \
            --background_topology "${params.simulation.background_topology ?: 'none'}" \
            --background_strength ${params.simulation.background_strength ?: 0.2} \
            --background_density ${params.simulation.background_density ?: 2} \
            ${params.simulation.background_seed != null ? "--background_seed ${params.simulation.background_seed + meta.id}" : ''} \
            --binary_p_low ${params.simulation.binary_p_low ?: 0.3} \
            --binary_p_high ${params.simulation.binary_p_high ?: 0.7} \
            --ordinal_concentration ${params.simulation.ordinal_concentration ?: 20.0} \
            --output_suffix "${meta.id}"
    """
    
}