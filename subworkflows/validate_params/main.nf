// Helper function to validate filtering parameters
def validateFilteringParams(filter_method, filter_param, filter_metric, filter_rule) {
    def valid_filter_methods = ['degree', 'density', 'quantile']
    
    if (!valid_filter_methods.contains(filter_method)) {
        error "ERROR: Parameter 'diff_net_analysis.filter_method' must be one of: ${valid_filter_methods.join(', ')}"
    }
    
    // Validate filter_param is provided
    if (filter_param == null) {
        error "ERROR: Parameter 'diff_net_analysis.filter_param' must be provided when filter_method is set"
    }
    
    // Validate filter_param based on filter_method
    if (filter_method == 'degree') {
        // degree: must be an integer, 0 < param < (total_nodes - 1)
        if (!(filter_param instanceof Number) || filter_param != filter_param.intValue()) {
            error "ERROR: Parameter 'diff_net_analysis.filter_param' must be an integer when filter_method is 'degree'"
        }
        if (filter_param <= 0) {
            error "ERROR: Parameter 'diff_net_analysis.filter_param' must be greater than 0 when filter_method is 'degree'"
        }
    } else if (filter_method == 'density' || filter_method == 'quantile') {
        // density/threshold: must be a float in the open interval (0, 1)
        if (!(filter_param instanceof Number)) {
            error "ERROR: Parameter 'diff_net_analysis.filter_param' must be a number when filter_method is '${filter_method}'"
        }
        if (filter_param <= 0 || filter_param >= 1) {
            error "ERROR: Parameter 'diff_net_analysis.filter_param' must be in the open interval (0, 1) when filter_method is '${filter_method}'"
        }
    }
    
    // Check filter_metric (pre-P or pre-E)
    def valid_filter_metrics = ['pre-P', 'pre-E']
    if (filter_metric && filter_metric != '') {
        if (!valid_filter_metrics.contains(filter_metric)) {
            error "ERROR: Parameter 'diff_net_analysis.filter_metric' must be one of: ${valid_filter_metrics.join(', ')}"
        }
    } else {
        error "ERROR: Parameter 'diff_net_analysis.filter_metric' must be provided when filter_method is set"
    }
    
    // Check filter_rule (zero or union)
    def valid_filter_rules = ['zero', 'union']
    if (filter_rule && filter_rule != '') {
        if (!valid_filter_rules.contains(filter_rule)) {
            error "ERROR: Parameter 'diff_net_analysis.filter_rule' must be one of: ${valid_filter_rules.join(', ')}"
        }
    } else {
        error "ERROR: Parameter 'diff_net_analysis.filter_rule' must be provided when filter_method is set"
    }
}

def validateNodeMetric(node_metric) {
    def valid_node_metrics = ['STC', 'DC-P', 'DC-E', 'WDC-P', 'WDC-E', 'PRC-P', 'None'] // Note: PRC-E include again
    if (!node_metric) {
        error "ERROR: Parameter 'node_metric' must be provided. If you do not wish to use a node metric, please provide an empty string ''"
    }
    if (!valid_node_metrics.contains(node_metric)) {
        error "ERROR: Parameter 'diff_net_analysis.node_metric' must be one of: ${valid_node_metrics.join(', ')}"
    }
}

def validateEdgeMetric(edge_metric) {
    def valid_edge_metrics = ['pre-P', 'pre-E', 'post-E', 'post-P', 'int-IS', 'pre-LS', 'post-LS', 'pre-PE', 'post-PE', 'None']
    if (!edge_metric) {
        error "ERROR: Parameter 'edge_metric' must be provided. If you do not wish to use an edge metric, please provide an empty string ''"
    }
    if (!valid_edge_metrics.contains(edge_metric)) {
        error "ERROR: Parameter 'diff_net_analysis.edge_metric' must be one of: ${valid_edge_metrics.join(', ')}"
    }
}

def validateRankingAlgorithm(ranking_algorithm) {
    def valid_algorithms = ['PageRank+', 'PageRank', 'absDimontRank', 'DimontRank', 'direct_node', 'direct_edge']
    if (!ranking_algorithm || ranking_algorithm == '') {
        error "ERROR: Parameter 'ranking_algorithm' must be provided"
    }
    if (!valid_algorithms.contains(ranking_algorithm)) {
        error "ERROR: Parameter 'diff_net_analysis.ranking_algorithm' must be one of: ${valid_algorithms.join(', ')}"
    }
}

def removeInvalidConfigurations(configs, warn = true){
    def validConfigs = []
    for (config in configs) {
        node_metric = config[0]
        edge_metric = config[1]
        ranking_algo = config[2]
        // Check whether edge_metric = post-P, post-E, post-CS, post-LS, post-PE and DimontRank is used -> give error
        if (['post-P', 'post-E', 'post-CS', 'post-LS', 'post-PE'].contains(edge_metric) && ranking_algo == 'DimontRank') {
            if (warn) log.warn "WARNING: Configuration with edge_metric '${edge_metric}' and ranking_algorithm 'DimontRank' is invalid and will be skipped."
            continue
        }

        // Check whether DimontRank, absDimontRank, PageRank, direct_edge is used with any node_metric -> just give warning
        if (['DimontRank', 'absDimontRank', 'PageRank', 'direct_edge'].contains(ranking_algo)) {
            if (node_metric != '') {
                if (warn) log.warn "WARNING: Configuration with ranking_algorithm '${ranking_algo}' does not use node_metric and will ignore the provided node_metric '${node_metric}'."
                config[0] = ''
            }
        }

        // Check whether direct_node is used with any edge_metric -> just give warning
        if (ranking_algo == 'direct_node') {
            if (edge_metric != '') {
                if (warn) log.warn "WARNING: Configuration with ranking_algorithm 'direct_node' does not use edge_metric and will ignore the provided edge_metric '${edge_metric}'."
                config[1] = ''
            }
        }

        // Check whether for configs with algorithm PageRank+ the node and edge metrics are given
        if (ranking_algo == 'PageRank+') {
            if (node_metric == '' || edge_metric == '') {
                if (warn) log.warn "WARNING: Configuration with ranking_algorithm 'PageRank+' requires both node_metric and edge_metric to be provided. This configuration will be skipped."
                continue
            }
        }
        validConfigs.add(config)
    }

    def uniqueConfigs = validConfigs.unique()

    return validConfigs
}

workflow validate_params {
    main:
    // Validate general parameters
    if (!params.name_context_1 || params.name_context_1 == '') {
        error "ERROR: Parameter 'name_context_1' must be provided"
    }
    
    if (!params.name_context_2 || params.name_context_2 == '') {
        error "ERROR: Parameter 'name_context_2' must be provided"
    }
    
    if (!params.run_type) {
        error "ERROR: Parameter 'run_type' must be provided"
    }
    
    def valid_run_types = ['single', 'all', 'file']
    if (!valid_run_types.contains(params.run_type)) {
        error "ERROR: Parameter 'run_type' must be one of: ${valid_run_types.join(', ')}"
    }
    
    if (!params.data_type) {
        error "ERROR: Parameter 'data_type' must be provided"
    }
    
    def valid_data_types = ['simulation', 'real']
    if (!valid_data_types.contains(params.data_type)) {
        error "ERROR: Parameter 'data_type' must be one of: ${valid_data_types.join(', ')}"
    }
    
    if (!params.out_dir || params.out_dir == '') {
        error "ERROR: Parameter 'out_dir' must be provided"
    }
    
    // Validate simulation parameters if data_type is 'simulation'
    if (params.data_type == 'simulation') {
        integer_params = ['n_simulations','n_bi', 'n_cont', 'n_cat', 'n_samples', 'n_shift_cont', 'n_shift_bi', 'n_shift_cat','n_corr_cont_cont', 'n_corr_bi_bi', 'n_corr_cat_cat', 'n_corr_bi_cat', 'n_corr_cont_cat', 'n_corr_bi_cont', 'n_both_cont_cont', 'n_both_bi_bi', 'n_both_cat_cat', 'n_both_bi_cat', 'n_both_cont_cat', 'n_both_bi_cont']
        integer_params.each { param_name ->
            if (params.simulation[param_name] == null || !(params.simulation[param_name] instanceof Number) || params.simulation[param_name] < 0 || params.simulation[param_name] != params.simulation[param_name].intValue()) {
                error "ERROR: Parameter 'simulation.${param_name}' must be a non-negative integer (>= 0)"
            }
        }   
        
        if (params.simulation.shift == null || !(params.simulation.shift instanceof Number) || params.simulation.shift < 0) {
            error "ERROR: Parameter 'simulation.shift' must be a non-negative number (>= 0)"
        }

        if (params.simulation.corr == null || !(params.simulation.corr instanceof Number) || params.simulation.corr < 0 || params.simulation.corr > 1) {
            error "ERROR: Parameter 'simulation.corr' must be a number between 0 and 1 (inclusive)"
        }
        
        log.info "✓ All simulation parameters are valid"
    }
    
    // Validate real world data parameters if data_type is 'real'
    if (params.data_type == 'real') {        
        if (!params.real_world_data.path_context_1 || params.real_world_data.path_context_1 == '') {
            error "ERROR: Parameter 'real_world_data.path_context_1' must be provided when data_type is 'real'"
        }
        
        if (!params.real_world_data.path_context_2 || params.real_world_data.path_context_2 == '') {
            error "ERROR: Parameter 'real_world_data.path_context_2' must be provided when data_type is 'real'"
        }
        
        if (!params.real_world_data.path_meta || params.real_world_data.path_meta == '') {
            error "ERROR: Parameter 'real_world_data.path_meta' must be provided when data_type is 'real'"
        }
        
        // Check if files exist
        def file_context_1 = file(params.real_world_data.path_context_1)
        if (!file_context_1.exists()) {
            error "ERROR: File not found: ${params.real_world_data.path_context_1}"
        }
        
        def file_context_2 = file(params.real_world_data.path_context_2)
        if (!file_context_2.exists()) {
            error "ERROR: File not found: ${params.real_world_data.path_context_2}"
        }
        
        def file_meta = file(params.real_world_data.path_meta)
        if (!file_meta.exists()) {
            error "ERROR: File not found: ${params.real_world_data.path_meta}"
        }
        
        log.info "✓ All real world data parameters are valid"
    }

    // Validate filtering
    if (params.diff_net_analysis.filter_method && params.diff_net_analysis.filter_method != '') {
        validateFilteringParams(
            params.diff_net_analysis.filter_method,
            params.diff_net_analysis.filter_param,
            params.diff_net_analysis.filter_metric,
            params.diff_net_analysis.filter_rule,
        )
        log.info "✓ All filtering parameters are valid"
    } else {
        log.info "No filtering method provided, filtering will not be applied"
    }

    // Validate differential network analysis parameters

    def configs

    if (params.run_type == 'single'){
        // Validate single configuration parameters
        validateNodeMetric(params.diff_net_analysis.node_metric)
        validateEdgeMetric(params.diff_net_analysis.edge_metric)
        validateRankingAlgorithm(params.diff_net_analysis.ranking_algorithm)

        configs = [[params.diff_net_analysis.node_metric, 
                   params.diff_net_analysis.edge_metric, 
                   params.diff_net_analysis.ranking_algorithm]]
        // Validating each configuration and removing invalid ones
        configs = removeInvalidConfigurations(configs, warn = true)
    }

    if (params.run_type == 'all'){
        def valid_node_metrics = ['STC', 'DC-P', 'DC-E', 'WDC-P', 'WDC-E', 'PRC-P'] // Note: PRC-E include again
        def valid_edge_metrics = ['pre-P', 'pre-E', 'post-E', 'post-P', 'int-IS', 'pre-LS', 'post-LS', 'pre-PE', 'post-PE']
        def valid_algorithms = ['PageRank+', 'PageRank', 'absDimontRank', 'DimontRank', 'direct_node', 'direct_edge']
    
        configs = [valid_node_metrics, valid_edge_metrics, valid_algorithms].combinations()

        // Validating each configuration and removing invalid ones
        configs = removeInvalidConfigurations(configs, warn = false)

    }

    if (params.run_type == 'file'){
        // Read configurations from file
        if (!params.diff_net_analysis.path_config || params.diff_net_analysis.path_config == '') {
            error "ERROR: Parameter 'diff_net_analysis.path_config' must be provided when run_type is 'file'"
        }
        
        def config_file = file(params.diff_net_analysis.path_config)
        if (!config_file.exists()) {
            error "ERROR: Configuration file not found: ${params.diff_net_analysis.path_config}"
        }
        
        // Read CSV file and parse configurations
        configs = []
        config_file.withReader { reader ->
            def header = reader.readLine() // Skip header line
            reader.eachLine { line ->
                if (line.trim()) { // Skip empty lines
                    def parts = line.split(',').collect { it.trim() }
                    if (parts.size() >= 3) {
                        def node_metric = parts[0]
                        def edge_metric = parts[1]
                        def algo = parts[2]
                        
                        // Validate each configuration
                        validateNodeMetric(node_metric)
                        validateEdgeMetric(edge_metric)
                        validateRankingAlgorithm(algo)
                        
                        configs << [node_metric, edge_metric, algo]
                    }
                }
            }
        }

        log.info "Loaded ${configs.size()} configurations from file"
        // Validating each configuration and removing invalid ones
        configs = removeInvalidConfigurations(configs, warn = true)
    }

        
    if (configs.size() == 0) {
        error "ERROR: No valid configurations found after validation. Please check your parameters."
    }

    // Validate additional differential network analysis parameters

    // Check if any configuration uses int-IS
    def uses_int_is = configs.any { node_metric, edge_metric, ranking_algo ->
        edge_metric == 'int-IS'
    }
    
    if (uses_int_is) {
        if (!params.diff_net_analysis.max_path_length || params.diff_net_analysis.max_path_length == '') {
            error "ERROR: Parameter 'diff_net_analysis.max_path_length' must be provided when using int-IS as edge_metric"
        }
        // Check whether it is an integer [0, 4]
        if (!(params.diff_net_analysis.max_path_length instanceof Number) || params.diff_net_analysis.max_path_length != params.diff_net_analysis.max_path_length.intValue() || params.diff_net_analysis.max_path_length < 0 || params.diff_net_analysis.max_path_length > 4) {
            error "ERROR: Parameter 'diff_net_analysis.max_path_length' must be an integer between 0 and 4"
        }
    }

    log.info "✓ All differential network analysis parameters are valid"


    // Valide context network inference parameters
    if (params.diff_net_analysis.data_type) {
        def valid_cont_cont = ['parametric', 'nonparametric']
        if (!valid_cont_cont.contains(params.diff_net_analysis.data_type)) {
            error "ERROR: Parameter 'diff_net_analysis.data_type' must be one of: ${valid_cont_cont.join(', ')}"
        }
    }
    
    if (params.diff_net_analysis.multiple_testing) {
        def valid_multiple_testing = ['bh','by']
        if (!valid_multiple_testing.contains(params.diff_net_analysis.multiple_testing)) {
            error "ERROR: Parameter 'diff_net_analysis.multiple_testing' must be one of: ${valid_multiple_testing.join(', ')}"
        }
    }
    
    log.info "✓ All context-specific network inference parameters are valid"

    // Extract unique (node_metric, edge_metric) pairs from configs
    def unique_node_metrics = configs.collect { node_metric, edge_metric, ranking_algo ->
        [node_metric]
    }.unique()

    def unique_edge_metrics = configs.collect { node_metric, edge_metric, ranking_algo ->
        [edge_metric]
    }.unique()


    log.info "-- Parameter validation completed successfully --"
    
    emit:
    config_combs = Channel.fromList(configs)
    node_metrics = Channel.fromList(unique_node_metrics).flatten()
    edge_metrics = Channel.fromList(unique_edge_metrics).flatten()

}
