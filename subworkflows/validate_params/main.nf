// Helper function to validate filtering parameters
def validateFilteringParams(filter_method, filter_param, filter_metric, filter_rule, filter_target) {
    def valid_filter_targets = ['context-specific', 'differential']
    if (!valid_filter_targets.contains(filter_target)) {
        error "ERROR: Parameter 'diff_net_analysis.filter_target' must be one of: ${valid_filter_targets.join(', ')} (or empty to skip filtering)"
    }

    // filter_method is required whenever filter_target is set
    if (!filter_method || filter_method == '') {
        error "ERROR: Parameter 'diff_net_analysis.filter_method' must be provided when 'filter_target' is set"
    }

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
    
    // filter_metric and filter_rule only apply to context-specific filtering. For differential
    // filtering the differential network is filtered on the already-computed edge_metric, so
    // neither a metric ('P or E') selection nor an integration rule is needed.
    if (filter_target == 'differential') {
        if ((filter_metric && filter_metric != '') || (filter_rule && filter_rule != '')) {
            log.warn "WARNING: 'filter_metric' and 'filter_rule' are ignored when filter_target is 'differential'; filtering always uses the computed edge_metric."
        }
        return
    }

    // Check filter_metric (raw-P or rescaled-E)
    def valid_filter_metrics = ['raw-P', 'rescaled-E']
    if (filter_metric && filter_metric != '') {
        if (!valid_filter_metrics.contains(filter_metric)) {
            error "ERROR: Parameter 'diff_net_analysis.filter_metric' must be one of: ${valid_filter_metrics.join(', ')}"
        }
    } else {
        error "ERROR: Parameter 'diff_net_analysis.filter_metric' must be provided when filter_method is set and filter_target is 'context-specific'"
    }

    // Check filter_rule (zero or union)
    def valid_filter_rules = ['zero', 'union']
    if (filter_rule && filter_rule != '') {
        if (!valid_filter_rules.contains(filter_rule)) {
            error "ERROR: Parameter 'diff_net_analysis.filter_rule' must be one of: ${valid_filter_rules.join(', ')}"
        }
    } else {
        error "ERROR: Parameter 'diff_net_analysis.filter_rule' must be provided when filter_method is set and filter_target is 'context-specific'"
    }
}

def validateNodeMetric(node_metric) {
    def valid_node_metrics = ['STC', 'DC-P', 'DC-E', 'WDC-P', 'WDC-L-P', 'WDC-E', 'PRC-P', 'PRC-L-P', 'PRC-E', 'None']
    if (!node_metric) {
        error "ERROR: Parameter 'node_metric' must be provided. If you do not wish to use a node metric, please provide an empty string ''"
    }
    if (!valid_node_metrics.contains(node_metric)) {
        error "ERROR: Parameter 'diff_net_analysis.node_metric' must be one of: ${valid_node_metrics.join(', ')}"
    }
}

def validateEdgeMetric(edge_metric) {
    def valid_edge_metrics = [/*'int-IS-E',*/ 'diff-P', 'diff-E', 'diff-T-E', 'diff-L-PE', 'sum-diff-PE', 'sum-diff-L-PE', 'diff-L-P', 'None']
    if (!edge_metric) {
        error "ERROR: Parameter 'edge_metric' must be provided. If you do not wish to use an edge metric, please provide an empty string ''"
    }
    if (!valid_edge_metrics.contains(edge_metric)) {
        error "ERROR: Parameter 'diff_net_analysis.edge_metric' must be one of: ${valid_edge_metrics.join(', ')}"
    }
}

def validateRankingAlgorithm(ranking_algorithm) {
    def valid_algorithms = ['PageRank+', 'PageRank', 'absDimontRank', 'DimontRank', 'nodeRank']
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
        // Check whether DimontRank, absDimontRank, PageRank is used with any node_metric -> just give warning
        if (['DimontRank', 'absDimontRank', 'PageRank'].contains(ranking_algo)) {
            if (node_metric != '') {
                if (warn) log.warn "WARNING: Configuration with ranking_algorithm '${ranking_algo}' does not use node_metric and will ignore the provided node_metric '${node_metric}'."
                config[0] = ''
            }
        }

        // Check whether nodeRank is used with any edge_metric -> just give warning
        if (ranking_algo == 'nodeRank') {
            if (edge_metric != '') {
                if (warn) log.warn "WARNING: Configuration with ranking_algorithm 'nodeRank' does not use edge_metric and will ignore the provided edge_metric '${edge_metric}'."
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

    return uniqueConfigs
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
        integer_params = ['n_simulations','n_bi', 'n_cont', 'n_cat', 'n_samples_1', 'n_samples_2', 'n_shift_cont', 'n_shift_bi', 'n_shift_cat','n_corr_cont_cont', 'n_corr_bi_bi', 'n_corr_cat_cat', 'n_corr_bi_cat', 'n_corr_cont_cat', 'n_corr_bi_cont', 'n_both_cont_cont', 'n_both_bi_bi', 'n_both_cat_cat', 'n_both_bi_cat', 'n_both_cont_cat', 'n_both_bi_cont']
        integer_params.each { param_name ->
            if (params.simulation[param_name] == null || !(params.simulation[param_name] instanceof Number) || params.simulation[param_name] < 0 || params.simulation[param_name] != params.simulation[param_name].intValue()) {
                error "ERROR: Parameter 'simulation.${param_name}' must be a non-negative integer (>= 0)"
            }
        }   
        
        // Params files written before ranged magnitudes are silently wrong rather than broken:
        // Groovy would simply ignore the stale keys and the new ones would come back null, so the
        // failure would surface as an obscure "must be a number" further down. Name the migration
        // explicitly instead.
        if (params.simulation.containsKey('shift') || params.simulation.containsKey('corr')) {
            error """ERROR: Parameters 'simulation.shift' and 'simulation.corr' were replaced by ranges.
  Each ground truth effect now draws its own magnitude uniformly from the given interval, which is
  recorded per node/edge in the ground truth files so effects can be ranked by realized size.
  Replace   shift: X           with   shift_low: X
                                      shift_high: X
  Replace   corr: Y            with   corr_low: Y
                                      corr_high: Y
  to reproduce the previous fixed-magnitude behaviour, or widen the intervals to sweep a range."""
        }

        range_params = [['corr_low', 'corr_high', 0.95], ['shift_low', 'shift_high', null]]
        range_params.each { low_name, high_name, upper ->
            [low_name, high_name].each { param_name ->
                if (params.simulation[param_name] == null || !(params.simulation[param_name] instanceof Number) || params.simulation[param_name] < 0) {
                    error "ERROR: Parameter 'simulation.${param_name}' must be a non-negative number (>= 0)"
                }
            }
            if (params.simulation[low_name] > params.simulation[high_name]) {
                error "ERROR: Parameter 'simulation.${low_name}' must not exceed 'simulation.${high_name}'"
            }
            // The correlation ceiling is modina's: a magnitude at or above it leaves no room for the
            // positive-definiteness budget the planting step spends.
            if (upper != null && params.simulation[high_name] > upper) {
                error "ERROR: Parameter 'simulation.${high_name}' must be at most ${upper}"
            }
        }

        if (params.simulation.hub_reuse_prob != null && (!(params.simulation.hub_reuse_prob instanceof Number) || params.simulation.hub_reuse_prob < 0 || params.simulation.hub_reuse_prob > 1)) {
            error "ERROR: Parameter 'simulation.hub_reuse_prob' must be a number between 0 and 1 (inclusive)"
        }

        // Background structure. All optional; omitting background_topology reproduces the historical
        // behaviour in which every non-ground-truth pair is exactly independent.
        def valid_topologies = ['none', 'scale_free', 'erdos_renyi']
        def topology = params.simulation.background_topology
        if (topology != null && !valid_topologies.contains(topology)) {
            error "ERROR: Parameter 'simulation.background_topology' must be one of: ${valid_topologies.join(', ')}"
        }
        if (topology != null && topology != 'none') {
            if (params.simulation.background_strength != null && (!(params.simulation.background_strength instanceof Number) || params.simulation.background_strength <= 0 || params.simulation.background_strength >= 1)) {
                error "ERROR: Parameter 'simulation.background_strength' must be a number strictly between 0 and 1"
            }
            def n_vars = params.simulation.n_bi + params.simulation.n_cont + params.simulation.n_cat
            if (params.simulation.background_density != null && (!(params.simulation.background_density instanceof Number) || params.simulation.background_density < 1 || params.simulation.background_density >= n_vars)) {
                error "ERROR: Parameter 'simulation.background_density' must be an integer >= 1 and < the total number of variables (${n_vars})"
            }
            // corr_high must stay strictly below the background's smallest eigenvalue, which modina
            // only knows once the background is built. Catching the guaranteed-impossible case here
            // (a magnitude a correlation matrix cannot carry at all) keeps the cheap error cheap;
            // modina raises the exact, background-aware version.
            if (params.simulation.corr_high >= 1) {
                error "ERROR: Parameter 'simulation.corr_high' must be below 1 when a background is enabled"
            }
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
    if (params.diff_net_analysis.filter_target && params.diff_net_analysis.filter_target != '') {
        validateFilteringParams(
            params.diff_net_analysis.filter_method,
            params.diff_net_analysis.filter_param,
            params.diff_net_analysis.filter_metric,
            params.diff_net_analysis.filter_rule,
            params.diff_net_analysis.filter_target,
        )
        log.info "✓ All filtering parameters are valid"
    } else {
        log.info "No filter_target provided, filtering will not be applied"
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
        def valid_node_metrics = ['STC', 'DC-P', 'DC-E', 'WDC-P', 'WDC-L-P', 'WDC-E', 'PRC-P', 'PRC-L-P', 'PRC-E']
        def valid_edge_metrics = [/*'int-IS-E',*/ 'diff-P', 'diff-E', 'diff-T-E', 'diff-L-PE', 'sum-diff-PE', 'sum-diff-L-PE', 'diff-L-P']
        def valid_algorithms = ['PageRank+', 'PageRank', 'absDimontRank', 'DimontRank', 'nodeRank']
    
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

    // Check if any configuration uses int-IS-E
    def uses_int_is = configs.any { node_metric, edge_metric, ranking_algo ->
        edge_metric == 'int-IS-E'
    }

    if (uses_int_is) {
        if (!params.diff_net_analysis.max_path_length || params.diff_net_analysis.max_path_length == '') {
            error "ERROR: Parameter 'diff_net_analysis.max_path_length' must be provided when using 'int-IS-E' as edge_metric"
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
