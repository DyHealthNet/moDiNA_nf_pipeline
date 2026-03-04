process create_summary_file {
    publishDir "${params.out_dir}", mode: 'copy'
    
    input:
    val summary_data
    
    output:
    path "summary.csv", emit: summary_csv
    
    script:
    def header = params.data_type == "simulation" ? 
        "id,node_metric,edge_metric,algorithm,ranking_file,node_metrics_file,edge_metrics_file,network_context_1,network_context_2,file_context_1,file_context_2,meta_file,ground_truth_nodes,ground_truth_edges" : 
        "id,node_metric,edge_metric,algorithm,ranking_file,node_metrics_file,edge_metrics_file,network_context_1,network_context_2,file_context_1,file_context_2,meta_file"
    
    def num_fields = params.data_type == "simulation" ? 14 : 12
    
    // Reshape flat list into rows
    def data = summary_data
    def rows = []
    for (int i = 0; i < data.size(); i += num_fields) {
        def end = Math.min(i + num_fields, data.size())
        def row = data[i..<end]
        rows << row.join(",")
    }
    def rows_str = rows.join("\n")  // Changed from \\n to \n
    
    """
    cat << 'EOF' > summary.csv
${header}
${rows_str}
EOF
    """
}