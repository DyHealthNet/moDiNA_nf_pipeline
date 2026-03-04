process evaluation_ranking_similarity {
    conda "/home/larend/miniforge3/envs/modina-evaluation-env"
    publishDir "${params.out_dir}/evaluation_ranking_similarity", mode: 'copy'

    input:
    path summary_file

    output:
    path "*_spearman_corr_heatmap_*.png", emit: corr_heatmaps, optional: true
    path "*_rank_heatmap_*.png", emit: rank_heatmaps, optional: true
    path "*_parallel_coordinates_*.png", emit: parallel_coords, optional: true

    script:
    """
    evaluation_ranking_similarity.R ${summary_file} ${params.data_type}
    """
}