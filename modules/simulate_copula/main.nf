process simulate_copula {
    conda params.conda_modina_env

    publishDir "${params.out_dir}/copula_simulation", mode: 'copy'

    when: params.data_type == 'simulation'

    input:
        val meta  // meta map: [id: simulation_id]

    output:
        tuple val(meta), path("${params.name_context_1}_simulated_data_${meta.id}.csv"), emit: file_context_1
        tuple val(meta), path("${params.name_context_2}_simulated_data_${meta.id}.csv"), emit: file_context_2
        tuple val(meta), path("meta_${meta.id}.csv"), emit: file_meta
        tuple val(meta), path("ground_truth_simulated_nodes_${meta.id}.txt"), emit: file_ground_truth_nodes
        tuple val(meta), path("ground_truth_simulated_edges_${meta.id}.txt"), emit: file_ground_truth_edges
    
    script:
    """
        simulate_copula.py \
            --context_1 "${params.name_context_1}" \
            --context_2 "${params.name_context_2}" \
            --n_bi "${params.simulation.n_bi}" \
            --n_cont "${params.simulation.n_cont}" \
            --n_cat "${params.simulation.n_cat}" \
            --n_samples "${params.simulation.n_samples}" \
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
            --shift "${params.simulation.shift}" \
            --corr ${params.simulation.corr} \
            --output_suffix "${meta.id}"
    """
    
}