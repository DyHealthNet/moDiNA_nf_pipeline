nextflow.enable.dsl = 2

include {simulate_copula} from './modules/simulate_copula/main.nf'
include {validate_params} from './subworkflows/validate_params/main.nf'
include {context_network_inference} from './modules/context_network_inference/main.nf'
include {filter_context_networks} from './modules/filter_context_networks/main.nf'
include {differential_network_inference} from './modules/differential_network_inference/main.nf'
include {node_edge_ranking} from './modules/node_edge_ranking/main.nf'

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
        file_ground_truth = simulate_copula.out.file_ground_truth
    } else {
        // Use real-world data from params (single iteration)
        sim_iterations = Channel.of([id: 1])
        file_context_1 = sim_iterations.map { meta -> [meta, file(params.real_world_data.path_context_1)] }
        file_context_2 = sim_iterations.map { meta -> [meta, file(params.real_world_data.path_context_2)] }
        file_meta = sim_iterations.map { meta -> [meta, file(params.real_world_data.path_meta)] }
        file_ground_truth = Channel.empty()  // This is fine - empty channel of tuples
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

    // ----------- Filtering of context-specific networks (optional) -----------
    if (params.diff_net_analysis.filter_method) {
        // Join all inputs by meta.id
        filter_input = network_context_1
            .join(network_context_2, by: 0)
            .join(file_context_1, by: 0)
            .join(file_context_2, by: 0)
            .map { meta, net1, net2, ctx1, ctx2 ->
                [meta, net1, net2, ctx1, ctx2]
            }
        
        filter_context_networks(filter_input)
        // These reassignments are correct - they maintain [meta, file] structure
        network_context_1 = filter_context_networks.out.filtered_network_context_1
        network_context_2 = filter_context_networks.out.filtered_network_context_2
        file_context_1 = filter_context_networks.out.filtered_input_context_1
        file_context_2 = filter_context_networks.out.filtered_input_context_2
    }

    // ----------- Differential network creation -----------
    // Join all files by meta.id first, then combine with metric pairs
    joined_files = network_context_1
        .join(network_context_2, by: 0)
        .join(file_context_1, by: 0)
        .join(file_context_2, by: 0)
        .join(file_meta, by: 0)
        // Result: [meta, net1, net2, ctx1, ctx2, meta_file]
    
    // Combine with metric pairs to create all configurations
    diff_net_input = validate_params.out.metric_pairs
        .combine(joined_files)
        .map { node_m, edge_m, meta, net1, net2, ctx1, ctx2, meta_file ->
            [meta + [node_metric: node_m, edge_metric: edge_m], net1, net2, ctx1, ctx2, meta_file]
        }
    
    differential_network_inference(diff_net_input)

    // ----------- Ranking nodes / edges -----------
    // Combine all algorithm configs with differential network results
    // Filter to match only configurations with same node/edge metrics
    ranking_input = validate_params.out.config_combs
        .combine(differential_network_inference.out)
        .filter { node_m, edge_m, algo, meta, node_file, edge_file, meta_file ->
            node_m == meta.node_metric && edge_m == meta.edge_metric
        }
        .map { node_m, edge_m, algo, meta, node_file, edge_file, meta_file ->
            [meta + [algorithm: algo], node_file, edge_file, meta_file]
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
        .map { meta_ranking, ranking_file, node_metrics_file, edge_metrics_file, meta_network_1, net1, meta_network_2, net2 ->
            [meta_ranking.id, meta_ranking.node_metric, meta_ranking.edge_metric, meta_ranking.algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2]
        }

    if(params.data_type == "simulation"){
        // Add ground truth files by matching meta.id
        summary_data = summary_data
        .combine(file_ground_truth)
        .filter {id, node_metric, edge_metric, algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2, meta_gt, gt_file ->
            id == meta_gt.id
        }
        .map {id, node_metric, edge_metric, algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2, meta_gt, gt_file ->
            [id, node_metric, edge_metric, algorithm, ranking_file, node_metrics_file, edge_metrics_file, net1, net2, gt_file]
        }
    }     

    // Write .csv file
    summary_data
        .map { row ->
            if(params.data_type == "simulation"){
                "${row[0]},${row[1]},${row[2]},${row[3]},${row[4]},${row[5]},${row[6]},${row[7]},${row[8]},${row[9]}"
            } else {
                "${row[0]},${row[1]},${row[2]},${row[3]},${row[4]},${row[5]},${row[6]},${row[7]},${row[8]}"
            }
        }
        .collect()
        .map { lines ->
            def header = params.data_type == "simulation" ? 
                "id,node_metric,edge_metric,algorithm,ranking_file,node_metrics_file,edge_metrics_file,network_context_1,network_context_2,ground_truth_file" : 
                "id,node_metric,edge_metric,algorithm,ranking_file,node_metrics_file,edge_metrics_file,network_context_1,network_context_2"
            def content = [header] + lines
            content.join("\n")
        }
        .collectFile(name: 'summary.csv', storeDir: params.out_dir)

    
   


}