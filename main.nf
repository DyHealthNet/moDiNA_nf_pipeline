nextflow.enable.dsl = 2

include {simulate_copula} from './modules/simulate_copula/main.nf'
include {validate_params} from './subworkflows/validate_params/main.nf'
include {context_network_inference} from './modules/context_network_inference/main.nf'
include {filter_context_networks} from './modules/filter_context_networks/main.nf'
include {filter_differential_network} from './modules/filter_differential_network/main.nf'
include {differential_node_inference} from './modules/differential_node_inference/main.nf'
include {differential_edge_inference} from './modules/differential_edge_inference/main.nf'
include {rescaling_networks} from './modules/rescaling_networks/main.nf'
include {node_ranking} from './modules/node_ranking/main.nf'
include {evaluation_auc} from './modules/evaluation_auc/main.nf'
include {evaluation_association_scores} from './modules/evaluation_association_scores/main.nf'
include {evaluation_differential_scores} from './modules/evaluation_differential_scores/main.nf'
include {create_summary_file} from './modules/create_summary_file/main.nf'
include {snapshot_parameters} from './subworkflows/snapshot_parameters/main.nf'
include {evaluation_roc_recall_enrichment} from './modules/evaluation_roc_recall_enrichment/main.nf'
include {evaluation_ranking_similarity} from './modules/evaluation_ranking_similarity/main.nf'
include {evaluation_mean_shifts} from './modules/evaluation_mean_shifts/main.nf'

// Output file prefix of a simulation ('' for real-world data), as used by the inference and ranking scripts
def outputPrefix(id) { params.data_type == 'simulation' ? "sim${id}".toString() : '' }

// The inference scripts name the files of the empty placeholder metric '' after Python's None
def metricFileName(id, metric, suffix) { "${outputPrefix(id)}_${metric ?: 'None'}_${suffix}".toString() }

// Batched processes emit one file per metric/configuration; pick the one with the expected name
def fileByName(files, name) {
    // A glob matching a single file yields a bare Path instead of a list
    def candidates = files instanceof Collection ? files : [files]
    def file = candidates.find { it.name == name }
    if (file == null) {
        error "ERROR: Expected output file '${name}' not found among ${candidates*.name}"
    }
    return file
}

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
    network_context_1 = context_network_inference.out.association_scores
        .filter { meta, file -> meta.context == params.name_context_1 }
        .map { meta, file -> [meta.subMap('id'), file] }

    network_context_2 = context_network_inference.out.association_scores
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
    if (params.diff_net_analysis.filter_target == 'context-specific') {
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
    
    // One node inference job per simulation and metric family (STC, WDC, PRC, none)
    diff_node_input = validate_params.out.node_metric_groups
        .combine(joined_files)
        .map { family, node_ms, meta, net1, net2, ctx1, ctx2, meta_file ->
            [meta + [node_family: family, node_metrics: node_ms], net1, net2, ctx1, ctx2, meta_file]
        }
    
    differential_node_inference(diff_node_input)

    // Split back into one [meta(id, node_metric), file, meta_file] tuple per node metric
    diff_node_metrics = differential_node_inference.out.node_metrics
        .flatMap { meta, node_files, meta_file ->
            meta.node_metrics.collect { node_m ->
                [meta.subMap('id') + [node_metric: node_m], fileByName(node_files, metricFileName(meta.id, node_m, 'node_metrics.csv')), meta_file]
            }
        }

    // One edge inference job per simulation and metric family (diff, sum, none)
    diff_edge_input = validate_params.out.edge_metric_groups
        .combine(joined_files)
        .map { family, edge_ms, meta, net1, net2, ctx1, ctx2, file_meta ->
            [meta + [edge_family: family, edge_metrics: edge_ms], net1, net2]
        }
    
    differential_edge_inference(diff_edge_input)

    // Split back into one [meta(id, edge_metric), edge file, stats file] tuple per edge metric
    diff_edge_metrics = differential_edge_inference.out.edge_metrics
        .flatMap { meta, edge_files, stats_files ->
            meta.edge_metrics.collect { edge_m ->
                [meta.subMap('id') + [edge_metric: edge_m],
                 fileByName(edge_files, metricFileName(meta.id, edge_m, 'edge_metrics.csv')),
                 fileByName(stats_files, metricFileName(meta.id, edge_m, 'edge_node_stats.csv'))]
            }
        }

    // ----------- Filtering of the differential network (optional) -----------
    if (params.diff_net_analysis.filter_target == 'differential') {
        filter_differential_network(diff_edge_metrics)
        diff_edge_metrics = filter_differential_network.out.edge_metrics
    }

    // ----------- Ranking nodes / edges -----------
    // Combine all algorithm configs with differential network results
    ranking_input = validate_params.out.config_combs
        .combine(diff_node_metrics)
        .combine(diff_edge_metrics)
        .filter { node_m, edge_m, algo, meta_node, node_file, file_meta, meta_edge, edge_file, stats_file ->
            node_m == meta_node.node_metric && edge_m == meta_edge.edge_metric && meta_node.id == meta_edge.id
        }
        .map { node_m, edge_m, algo, meta_node, node_file, file_meta, meta_edge, edge_file, stats_file ->
            [meta_node + [edge_metric: edge_m, algorithm: algo], node_file, edge_file, stats_file, file_meta]
        }

    // One ranking job per simulation and algorithm. groupKey carries the group size so each group is
    // released as soon as it is complete; sorting keeps the job's inputs (and so its -resume hash) stable.
    ranking_batches = ranking_input
        .combine(validate_params.out.configs_per_algorithm)
        .map { meta, node_file, edge_file, stats_file, meta_file, configs_per_algorithm ->
            def config = [node_metric: meta.node_metric, edge_metric: meta.edge_metric,
                          node_file: node_file.name, edge_file: edge_file.name, stats_file: stats_file.name,
                          node_path: node_file.toString(), edge_path: edge_file.toString(),
                          output_prefix: "${outputPrefix(meta.id) ? outputPrefix(meta.id) + '_' : ''}${meta.node_metric}_${meta.edge_metric}_${meta.algorithm}".toString()]
            [groupKey(meta.subMap(['id', 'algorithm']), configs_per_algorithm[meta.algorithm]), config, node_file, edge_file, stats_file, meta_file]
        }
        .groupTuple()
        .map { key, configs, node_files, edge_files, stats_files, meta_files ->
            [key.getGroupTarget(),
             configs.sort { it.output_prefix },
             node_files.unique().sort { it.name },
             edge_files.unique().sort { it.name },
             stats_files.unique().sort { it.name },
             meta_files[0]]
        }

    node_ranking(ranking_batches)

    // Split back into one [meta(id, node_metric, edge_metric, algorithm), node file, edge file, ranking file] tuple per configuration
    rankings = node_ranking.out
        .flatMap { meta, configs, ranking_files ->
            configs.collect { config ->
                [meta.subMap('id') + [node_metric: config.node_metric, edge_metric: config.edge_metric, algorithm: meta.algorithm],
                 config.node_path, config.edge_path, fileByName(ranking_files, "${config.output_prefix}_ranking.csv".toString())]
            }
        }

    // ----------- Create summary file -----------
    summary_data = rankings
        .map { meta, node_metrics_file, edge_metrics_file, ranking_file  ->
            [meta, ranking_file, node_metrics_file, edge_metrics_file]
        }
        // Add rescaled_network_context_1 and rescaled_network_context_2 by matching meta.id
        .combine(rescaled_network_context_1)
        .filter { meta_ranking, ranking_file, node_metrics_file, edge_metrics_file, meta_network_1, net ->
            meta_ranking.id == meta_network_1.id}
        .combine(rescaled_network_context_2)
        .filter { meta_ranking, ranking_file, node_metrics_file, edge_metrics_file, meta_network_1, net1, meta_network_2, net2 ->
            meta_ranking.id == meta_network_2.id}
        // Add file_context_1 and file_context_2 by matching meta.id
        .combine(joined_files)
        .filter { meta_ranking, ranking_file, node_metrics_file, edge_metrics_file, meta_network_1, net1, meta_network_2, net2, meta_joined, net1_j, net2_j, ctx1, ctx2, meta_file ->
            meta_ranking.id == meta_joined.id}
        .map { meta_ranking, ranking_file, node_metrics_file, edge_metrics_file, meta_network_1, net1, meta_network_2, net2, meta_joined, net1_j, net2_j, ctx1, ctx2, meta_file ->
            [meta_ranking.id, meta_ranking.node_metric, meta_ranking.edge_metric, meta_ranking.algorithm, ranking_file.toString(), node_metrics_file.toString(), edge_metrics_file.toString(), net1.toString(), net2.toString(), ctx1.toString(), ctx2.toString(), meta_file.toString()]
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
                [id, node_metric, edge_metric, algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2, ctx1, ctx2, meta_file, gt_file_nodes.toString(), gt_file_edges.toString()]
            }
    }

    // Write summary.csv
    // COLLECT THE CHANNEL INTO A LIST
    summary_data_collected = summary_data.collect()
    create_summary_file(summary_data_collected)

    // Evaluation
    if(params.evaluation){
   	evaluation_association_scores(create_summary_file.out.summary_csv)
    	evaluation_differential_scores(create_summary_file.out.summary_csv)
    	evaluation_ranking_similarity(create_summary_file.out.summary_csv)
    	evaluation_mean_shifts(create_summary_file.out.summary_csv)

    	if (params.data_type == 'simulation') {
        	evaluation_auc(create_summary_file.out.summary_csv)
        	evaluation_roc_recall_enrichment(create_summary_file.out.summary_csv)
    	}
    }

    snapshot_parameters()
    
}
