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
        // Create simulation iteration channel
        sim_iterations = Channel.of(1..params.simulation.n_simulations)
        
        // Copula Simulation
        simulate_copula(sim_iterations)

        // Access the outputs using the emit names (now with simulation_id)
        file_context_1 = simulate_copula.out.file_context_1
        file_context_2 = simulate_copula.out.file_context_2
        file_meta = simulate_copula.out.file_meta
    } else {
        // Use real-world data from params (single iteration)
        sim_iterations = Channel.of(1)
        file_context_1 = sim_iterations.map { id -> [id, file(params.real_world_data.path_context_1)] }
        file_context_2 = sim_iterations.map { id -> [id, file(params.real_world_data.path_context_2)] }
        file_meta = sim_iterations.map { id -> [id, file(params.real_world_data.path_meta)] }
    }
    
    // ----------- Context-specific network inference -----------

    // Create input channels for both contexts (with simulation_id)
    // Use join to match by simulation_id, not combine (which creates Cartesian product)
    input_context_1 = file_context_1
        .join(file_meta)
        .map { sim_id, ctx_file, meta_file -> 
            [sim_id, params.name_context_1, ctx_file, meta_file] 
        }
    
    input_context_2 = file_context_2
        .join(file_meta)
        .map { sim_id, ctx_file, meta_file -> 
            [sim_id, params.name_context_2, ctx_file, meta_file] 
        }
    
    // Run inference on both contexts
    context_network_inference(input_context_1.mix(input_context_2))


    // Separate the outputs by context
    network_context_1 = context_network_inference.out
        .filter { sim_id, context_name, file -> context_name == params.name_context_1 }
        .map { sim_id, context_name, file -> [sim_id, file] }
    
    network_context_2 = context_network_inference.out
        .filter { sim_id, context_name, file -> context_name == params.name_context_2 }
        .map { sim_id, context_name, file -> [sim_id, file] }

    // ----------- Filtering of context-specific networks (optional) -----------
    if (params.diff_net_analysis.filter_method) {
        // Combine all inputs with matching simulation_ids
        filter_input = network_context_1
            .combine(network_context_2)
            .combine(file_context_1)
            .combine(file_context_2)
            .filter { sim1, net1, sim2, net2, sim3, ctx1, sim4, ctx2 ->
                sim1 == sim2 && sim2 == sim3 && sim3 == sim4
            }
            .map { sim1, net1, sim2, net2, sim3, ctx1, sim4, ctx2 ->
                [sim1, net1, net2, ctx1, ctx2]
            }
        
        filter_context_networks(filter_input)
        network_context_1 = filter_context_networks.out.filtered_network_context_1
        network_context_2 = filter_context_networks.out.filtered_network_context_2
        file_context_1 = filter_context_networks.out.filtered_input_context_1
        file_context_2 = filter_context_networks.out.filtered_input_context_2
    }

    // ----------- Differential network creation - run once per configuration per simulation -----------
    // Combine each config with the network files and metadata
    diff_net_input = validate_params.out.metric_pairs
        .combine(network_context_1)
        .combine(network_context_2)
        .combine(file_context_1)
        .combine(file_context_2)
        .combine(file_meta)
        .filter { node_m, edge_m, sim_id1, net1, sim_id2, net2, sim_id3, ctx1, sim_id4, ctx2, sim_id5, meta ->
            sim_id1 == sim_id2 && sim_id2 == sim_id3 && sim_id3 == sim_id4 && sim_id4 == sim_id5
        }
        .map { node_m, edge_m, sim_id1, net1, sim_id2, net2, sim_id3, ctx1, sim_id4, ctx2, sim_id5, meta ->
            [sim_id1, node_m, edge_m, net1, net2, ctx1, ctx2, meta]
        }
    
    differential_network_inference(diff_net_input)
    
    // Ranking nodes / edges
    // Map differential network outputs back to full configs (including ranking algorithm)
    ranking_input = validate_params.out.config_combs
        .combine(differential_network_inference.out)
        .filter { node_m, edge_m, algo, sim_id, diff_node, diff_edge, node_file, edge_file, meta_file ->
            node_m == diff_node && edge_m == diff_edge
        }
        .map { node_m, edge_m, algo, sim_id, diff_node, diff_edge, node_file, edge_file, meta_file ->
            [sim_id, node_m, edge_m, algo, node_file, edge_file, meta_file]
        }
    node_edge_ranking(ranking_input)

    // Create summary file with all results
    summary_data = node_edge_ranking.out
        .join(file_context_1)
        .join(file_context_2)
        .map { sim_id, node_m, edge_m, algo, ranking_file, meta1, ctx1_file, ctx2_file ->
            // Return as a list explicitly to preserve structure
            return [sim_id, node_m, edge_m, algo, ranking_file.name, ctx1_file.name, ctx2_file.name]
        }
        
    summary_data
    .toList()
    .map { rows ->
        // Create header
        def header = "sim_id,node_metric,edge_metric,algorithm,ranking_file,context1_file,context2_file"
        
        // Create CSV rows
        def csv_rows = rows.collect { row -> row.join(',') }.join('\n')
        
        // Combine header and rows
        return header + '\n' + csv_rows
    }
    .collectFile(name: 'summary.csv', storeDir: params.out_dir)
    
    // Evaluation of results

}