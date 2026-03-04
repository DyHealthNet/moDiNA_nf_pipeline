nextflow.enable.dsl = 2

include {simulate_copula} from './modules/simulate_copula/main.nf'
include {validate_params} from './subworkflows/validate_params/main.nf'
include {context_network_inference} from './modules/context_network_inference/main.nf'
include {filter_context_networks} from './modules/filter_context_networks/main.nf'
include {differential_node_inference} from './modules/differential_node_inference/main.nf'
include {differential_edge_inference} from './modules/differential_edge_inference/main.nf'
include {rescaling_networks} from './modules/rescaling_networks/main.nf'
include {node_edge_ranking} from './modules/node_edge_ranking/main.nf'
include {evaluation_auc} from './modules/evaluation_auc/main.nf'
include {evaluation_association_scores} from './modules/evaluation_association_scores/main.nf'
include {evaluation_differential_scores} from './modules/evaluation_differential_scores/main.nf'
include {create_summary_file} from './modules/create_summary_file/main.nf'
include {snapshot_parameters} from './subworkflows/snapshot_parameters/main.nf'
include {evaluation_roc_recall_enrichment} from './modules/evaluation_roc_recall_enrichment/main.nf'
include {evaluation_ranking_similarity} from './modules/evaluation_ranking_similarity/main.nf'
include {evaluation_mean_shifts} from './modules/evaluation_mean_shifts/main.nf'

workflow {

    // ----------- Parameter validation -----------
    validate_params()

    // ----------- Data preparation -----------

    // Conditional data source based on params.data_type
    if (params.data_type == 'simulation') {
        // Create simulation iteration channel with meta map (id: simulation_id)
        sim_iterations = Channel.of(1..params.simulation.n_simulations)
            .map { id -> [id: id] }
        
        // Copula Simulation
        simulate_copula(sim_iterations)

        // Access outputs as [meta, file]
        file_context_1 = simulate_copula.out.file_context_1
        file_context_2 = simulate_copula.out.file_context_2
        file_meta = simulate_copula.out.file_meta
        file_ground_truth_nodes = simulate_copula.out.file_ground_truth_nodes
        file_ground_truth_edges = simulate_copula.out.file_ground_truth_edges
    } else {
        // Use real-world data from params (single iteration)
        sim_iterations = Channel.of([id: 1])
        file_context_1 = sim_iterations.map { meta -> [meta, file(params.real_world_data.path_context_1)] }
        file_context_2 = sim_iterations.map { meta -> [meta, file(params.real_world_data.path_context_2)] }
        file_meta = sim_iterations.map { meta -> [meta, file(params.real_world_data.path_meta)] }
        file_ground_truth_nodes = Channel.empty()  // This is fine - empty channel of tuples
        file_ground_truth_edges = Channel.empty()  // This is fine - empty channel of tuples
    }
    
    // ----------- Context-specific network inference -----------

    // Create input channels for both contexts with meta map (id: simulation_id; context: context name)
    input_context_1 = file_context_1
        .join(file_meta, by: 0)
        .map { meta, ctx_file, meta_file -> 
            [meta + [context: params.name_context_1], ctx_file, meta_file] 
        }
    
    input_context_2 = file_context_2
        .join(file_meta, by: 0)
        .map { meta, ctx_file, meta_file -> 
            [meta + [context: params.name_context_2], ctx_file, meta_file] 
        }
    
    // Run inference on both contexts
    context_network_inference(input_context_1.mix(input_context_2))

    // Separate the outputs by context
    network_context_1 = context_network_inference.out
        .filter { meta, file -> meta.context == params.name_context_1 }
        .map { meta, file -> [meta.subMap('id'), file] }
    
    network_context_2 = context_network_inference.out
        .filter { meta, file -> meta.context == params.name_context_2 }
        .map { meta, file -> [meta.subMap('id'), file] }


    // ----------- Rescaling of association scores -----------
    rescaling_input = network_context_1.combine(network_context_2)
        .filter { meta1, net1, meta2, net2 -> meta1.id == meta2.id }
        .map { meta1, net1, meta2, net2 -> [meta1, net1, net2] }
    rescaling_networks(rescaling_input)

    rescaled_network_context_1 = rescaling_networks.out.rescaled_network_context_1
    rescaled_network_context_2 = rescaling_networks.out.rescaled_network_context_2

    // ----------- Filtering of context-specific networks (optional) -----------
    if (params.diff_net_analysis.filter_method) {
        // Join all inputs by meta.id
        filter_input = rescaled_network_context_1
            .join(rescaled_network_context_2, by: 0)
            .join(file_context_1, by: 0)
            .join(file_context_2, by: 0)
            .map { meta, net1, net2, ctx1, ctx2 ->
                [meta, net1, net2, ctx1, ctx2]
            }
        
        filter_context_networks(filter_input)
        // These reassignments are correct - they maintain [meta, file] structure
        rescaled_network_context_1 = filter_context_networks.out.filtered_network_context_1
        rescaled_network_context_2 = filter_context_networks.out.filtered_network_context_2
        file_context_1 = filter_context_networks.out.filtered_input_context_1
        file_context_2 = filter_context_networks.out.filtered_input_context_2
    }

    // ----------- Differential network creation -----------
    // Join all files by meta.id first, then combine with metric pairs
    joined_files = rescaled_network_context_1
        .join(rescaled_network_context_2, by: 0)
        .join(file_context_1, by: 0)
        .join(file_context_2, by: 0)
        .join(file_meta, by: 0)
        // Result: [meta, net1, net2, ctx1, ctx2, meta_file]
    
    // Combine with unique node_metrics to create all configurations for node inference
    diff_node_input = validate_params.out.node_metrics
        .combine(joined_files)
        .map { node_m, meta, net1, net2, ctx1, ctx2, meta_file ->
            [meta + [node_metric: node_m], net1, net2, ctx1, ctx2, meta_file]
        }
    
    differential_node_inference(diff_node_input)

    // Combine with unique edge_metrics to create all configurations for edge inference
    diff_edge_input = validate_params.out.edge_metrics
        .combine(joined_files)
        .map { edge_m, meta, net1, net2, ctx1, ctx2, file_meta ->
            [meta + [edge_metric: edge_m], net1, net2]
        }
    
    differential_edge_inference(diff_edge_input)

    // ----------- Ranking nodes / edges -----------
    // Combine all algorithm configs with differential network results
    ranking_input = validate_params.out.config_combs
        .combine(differential_node_inference.out.node_metrics)
        .combine(differential_edge_inference.out.edge_metrics)
        .filter { node_m, edge_m, algo, meta_node, node_file, file_meta, meta_edge,edge_file ->
            node_m == meta_node.node_metric && edge_m == meta_edge.edge_metric && meta_node.id == meta_edge.id
        }
        .map { node_m, edge_m, algo, meta_node, node_file, file_meta, meta_edge, edge_file ->
            [meta_node + [edge_metric: edge_m, algorithm: algo], node_file, edge_file, file_meta]
        }
    
    node_edge_ranking(ranking_input)

    // ----------- Create summary file -----------
    summary_data = node_edge_ranking.out
        .map { meta, node_metrics_file, edge_metrics_file, ranking_file  ->
            [meta, ranking_file, node_metrics_file, edge_metrics_file]
        }
        // Add network_context_1 and network_context_2 by matching meta.id
        .combine(network_context_1)
        .filter { meta_ranking, ranking_file, node_metrics_file, edge_metrics_file, meta_network_1, net ->
            meta_ranking.id == meta_network_1.id}
        .combine(network_context_2)
        .filter { meta_ranking, ranking_file, node_metrics_file, edge_metrics_file, meta_network_1, net1, meta_network_2, net2 ->
            meta_ranking.id == meta_network_2.id}
        // Add file_context_1 and file_context_2 by matching meta.id
        .combine(joined_files)
        .filter { meta_ranking, ranking_file, node_metrics_file, edge_metrics_file, meta_network_1, net1, meta_network_2, net2, meta_joined, net1_j, net2_j, ctx1, ctx2, meta_file ->
            meta_ranking.id == meta_joined.id}
        .map { meta_ranking, ranking_file, node_metrics_file, edge_metrics_file, meta_network_1, net1, meta_network_2, net2, meta_joined, net1_j, net2_j, ctx1, ctx2, meta_file ->
            [meta_ranking.id, meta_ranking.node_metric, meta_ranking.edge_metric, meta_ranking.algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2, ctx1, ctx2, meta_file]
        }

    if(params.data_type == "simulation"){
        // Add ground truth files by matching meta.id
        summary_data = summary_data
            .combine(file_ground_truth_nodes)
            .filter {id, node_metric, edge_metric, algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2, ctx1, ctx2, meta_file, meta_gt_nodes, gt_file_nodes ->
                id == meta_gt_nodes.id
            }
            .map {id, node_metric, edge_metric, algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2, ctx1, ctx2, meta_file, meta_gt_nodes, gt_file_nodes ->
                [id, node_metric, edge_metric, algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2, ctx1, ctx2, meta_file, gt_file_nodes]
            }
            .combine(file_ground_truth_edges)
            .filter {id, node_metric, edge_metric, algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2, ctx1, ctx2, meta_file, gt_file_nodes, meta_gt_edges, gt_file_edges ->
                id == meta_gt_edges.id
            }
            .map {id, node_metric, edge_metric, algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2, ctx1, ctx2, meta_file, gt_file_nodes, meta_gt_edges, gt_file_edges ->
                [id, node_metric, edge_metric, algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2, ctx1, ctx2, meta_file, gt_file_nodes, gt_file_edges]
            }
    }

    // Write summary.csv
    // COLLECT THE CHANNEL INTO A LIST
    summary_data_collected = summary_data.collect()
    create_summary_file(summary_data_collected)

    // Evaluation

    evaluation_association_scores(create_summary_file.out.summary_csv)
    evaluation_differential_scores(create_summary_file.out.summary_csv)
    evaluation_ranking_similarity(create_summary_file.out.summary_csv)
    evaluation_mean_shifts(create_summary_file.out.summary_csv)

    if (params.data_type == 'simulation') {
        evaluation_auc(create_summary_file.out.summary_csv)
        //evaluation_roc_recall_enrichment(create_summary_file.out.summary_csv)
    }

    snapshot_parameters()
    
}