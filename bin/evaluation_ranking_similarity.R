#!/usr/bin/env Rscript

######## ------------- Libraries ------------- ########
library(patchwork)
library(ggplot2)
library(dplyr)
library(stringr)
library(data.table)
library(colorspace)
library(argparse)
library(purrr)
library(tidyr)

######## ------------- Utils ------------- ########

# Colors
ground_truth_palette <- c(
  "diff. corr."                = "#fdbf6f",
  "mean shift"                  = "#C195C4",
  "mean shift + diff. corr."    = "#b2df8a",
  "non-ground truth"            = "lightgray"
)

# Valid focus values
edge_metrics_subset = c('pre-P', 'post-P', 'pre-E', 'post-E', 'int-IS', 'pre-LS', 'post-LS', 'pre-PE', 'post-PE')
node_metrics_subset = c('DC-P', 'DC-E', 'STC', 'PRC-P', 'PRC-E', 'WDC-P', 'WDC-E')
algorithms_subset = c('direct_node', 'PageRank', 'PageRank+', 'DimontRank', 'absDimontRank')


# Extract ground truth information from a row
get_gt_info <- function(row, mode, gt_dict) {
  if (mode == 'edges'){
    edge <- paste(sort(c(row['label1'], row['label2'])), collapse = "_")
    
    description <- ifelse(edge %in% names(gt_dict), gt_dict[[edge]], NA)
    gt <- !is.na(description)
    description <- ifelse(is.na(description), 'non-ground truth', description)
  }
  else{
    node <- row[['node']]
    description <- ifelse(node %in% names(gt_dict), gt_dict[[node]], NA)
    gt <- !is.na(description)
    description <- ifelse(is.na(description), 'non-ground truth', description)
  }
  
  return(c(groundtruth = gt, description = description))    
}


# Spearman correlation heatmap
corr_heatmap <- function(data){
  # Compute correlation matrix
  cor_mat <- cor(data[,-1], method = "spearman", use = "pairwise.complete.obs")
  dist_mat <- as.dist(1 - cor_mat)
  hc <- hclust(dist_mat)
  
  # Cluster
  cor_mat_ordered <- cor_mat[hc$order, hc$order]
  
  cor_df <- as.data.frame(cor_mat_ordered) %>%
    tibble::rownames_to_column(var="Method1") %>%
    pivot_longer(
      cols = -Method1,
      names_to = "Method2",
      values_to = "Similarity"
    )
  
  # Heatmap
  cor_heatmap <- ggplot(cor_df, aes(x = Method2, y = Method1, fill = Similarity)) +
    geom_tile(color="white") +
    geom_text(aes(label = sprintf("%.2f", Similarity)), size = 3) +
    scale_fill_gradient2(low = "#08519C", mid = "white", high = "#C03830", name = "Spearman Correlation", limits = c(-1, 1), midpoint = 0) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle=45, hjust=1),
      panel.grid = element_blank(),
      axis.title = element_blank()
    ) +
    coord_fixed()
  
  return(cor_heatmap)
}


# Create rank heatmaps for ground truth nodes
rank_heatmap <- function(data, data_type, gt_dict=NULL, top_k=20){
  # Prepare heatmap matrix
  m <- as.matrix(data[, -1])
  rownames(m) <- data$node
  
  if (ncol(m) < 2){
    return(FALSE)
  }
  
  # Cluster configs
  dist_cols <- dist(t(m), method = "euclidean")
  clust_cols <- hclust(dist_cols, method = "ward.D2")
  sorted_configs <- clust_cols$labels[clust_cols$order]
  
  # Rank columns
  df <- as.data.table(m, keep.rownames = "node")
  df <- melt(df, id.vars = "node", variable.name = "config", value.name = "rank")
  
  if (data_type == 'simulation'){
    # Extract ground truth nodes
    gt_nodes <- names(gt_dict)
    
    # Create ground truth annotation dataframe for heatmap
    gt_info <- as.data.table(data.frame(node = gt_nodes))
    gt_info <- gt_info[, groundtruth := gt_dict[match(node, names(gt_dict))]]
    
    # Sort according to ground truth annotation
    sorted_nodes <- gt_info$node[order(gt_info$groundtruth, decreasing = TRUE)]
    gt_info$node <- factor(gt_info$node, levels = rev(sorted_nodes))
    
    # Set gt palette
    gt_palette <- ground_truth_palette
    
    # Annotation column
    gt_info$groundtruth <- factor(gt_info$groundtruth, levels = c('mean shift + diff. corr.', 'mean shift', 'diff. corr.'))
    annotation <- ggplot(gt_info, aes(x = "Annotation", y = node, fill = groundtruth)) +
      geom_tile(color='white') +
      scale_fill_manual(values = gt_palette,
                        name = "Ground Truth",
                        na.value = 'snow2') +
      theme_void() +
      theme(legend.position = 'right')
  } else{
    # Mean rank per node
    node_means <- rowMeans(m, na.rm = TRUE)
    
    # Extract top-k nodes
    top_nodes <- names(sort(node_means))[1:min(top_k, length(node_means))]
    m_top <- m[top_nodes, , drop = FALSE]
    df <- df[node %in% top_nodes]
    
    # Cluster nodes
    dist_rows <- dist(m_top, method = "euclidean")
    clust_rows <- hclust(dist_rows, method = "ward.D2")
    sorted_nodes <- clust_rows$labels[clust_rows$order]
  }
  
  # Change order
  df$config <- factor(df$config, levels = sorted_configs)
  df$node <- factor(df$node, levels = rev(sorted_nodes))
  
  # Plot
  heatmap <- ggplot(df, aes(x = config, y = node, fill = rank)) + 
    geom_tile(color = "white") +
    scale_fill_gradient(low='#1A4D91',
                        high='white',
                        na.value='white',
                        name='Rank') +
    theme_minimal() +
    theme(legend.position = 'right',
          axis.text.x = element_text(angle = 45, hjust = 1),
          axis.text.y = element_blank(),
          plot.margin = margin(t = 5, r = 5, b = 5, l = 50),
    ) +
    labs(x = "",
         y = "")
  
  if (data_type == 'simulation'){
  heatmap <- heatmap + annotation + 
    plot_layout(widths = c(ncol(m), 1), guides = "collect") &
    theme(legend.position = "right",
          panel.grid = element_blank(),
          axis.ticks = element_blank()
    )
  }
  
  return(heatmap)
}


# Create a parallel coordinates plot to compare the rankings
par_coord <- function(data, metric, data_type, gt_dict=NULL){
  data <- as.data.table(data)
  
  # Replace NAs by last rank
  last_rank <- nrow(data)
  ranking_cols <- setdiff(colnames(data), "node")
  for (col in ranking_cols) {
    data[is.na(get(col)), (col) := last_rank]
  }
  
  # Add ground truth information
  if (data_type == 'simulation'){
    gt_data <- t(apply(data, 1, get_gt_info, mode='nodes', gt_dict=gt_dict))
    data <- cbind(data, as.data.table(gt_data))
  }
  
  # Get ranking columns
  ranking_cols <- setdiff(colnames(data),
                          c("node", "groundtruth", "description"))
  
  # Reshape to long format
  df_long <- data %>%
    mutate(.id = row_number()) %>%
    pivot_longer(cols = all_of(ranking_cols), names_to = "variable", values_to = "value") %>%
    mutate(value = as.numeric(value))
  
  # Normalize using globalminmax
  global_min <- min(df_long$value, na.rm = TRUE)
  global_max <- max(df_long$value, na.rm = TRUE)
  df_long <- df_long %>%
    mutate(value = (value - global_min) / (global_max - global_min),
           variable = factor(variable, levels = ranking_cols))
  
  # Plot
  if (data_type == 'simulation'){
    p <- ggplot(df_long, aes(x = variable, y = value, group = .id, color = description)) +
      geom_line(alpha = 1.0) +
      labs(x = '', y = 'Rank', color = 'Ground Truth') +
      scale_color_manual(values = ground_truth_palette) +
      theme_minimal() +
      theme(
        legend.position = "bottom",
        axis.text.y  = element_text(size = 18),
        axis.title.y = element_text(size = 18),
        legend.text  = element_text(size = 18),
        legend.title = element_text(size = 20),
        axis.text.x  = element_text(size = 18, angle = 45, hjust = 1)
      )
  } else{
    p <- ggplot(df_long, aes(x = variable, y = value, group = .id)) +
      geom_line(alpha = 1.0) +
      labs(x = '', y = 'Rank') +
      theme_minimal() +
      theme(
        legend.position = "bottom",
        axis.text.y  = element_text(size = 18),
        axis.title.y = element_text(size = 18),
        legend.text  = element_text(size = 18),
        legend.title = element_text(size = 20),
        axis.text.x  = element_text(size = 18, angle = 45, hjust = 1)
      )
  }
  
  return(p)
}

######## ------------- Argument parser ------------- ########

parser <- ArgumentParser(description='Ranking Similarity')
parser$add_argument('summary_file', 
                    help='Input summary data file storing all generated configurations and their results.')
parser$add_argument('data_type', help = 'Type of data: simulation or real')
args <- parser$parse_args()

summary_file <- args$summary_file
data_type <- args$data_type

######## ------------- Process data ------------- ########

summary_dt <- fread(summary_file)
simulations <- max(summary_dt$id, na.rm = TRUE)

if(data_type == 'simulation'){
  summary_dt <- unique(summary_dt[, c("id", "edge_metric", "node_metric", "algorithm", "ranking_file", "ground_truth_nodes")])
} else {
  summary_dt <- unique(summary_dt[, c("id", "edge_metric", "node_metric", "algorithm", "ranking_file")])
}

top_k <- 20

######## ------------- Plotting ------------- ########

for (sim in 1:simulations){
  sim_summary <- summary_dt[id == sim, ]

  if (data_type == 'simulation'){
    gt_table <- fread(unique(sim_summary[, ground_truth_nodes]))
    gt_dict <- setNames(gt_table$description, gt_table$node)
  }
  
  # For now, only take node rankings
  node_rankings <- sim_summary[algorithm!='direct_edge', ]
  
  # Edge metrics
  for (metric in unique(node_rankings$edge_metric)){
    # Filter for metric
    data <- node_rankings[edge_metric==metric, ]
    
    if (nrow(data) < 2){
      next
    }
    
    # Read in rankings
    ranking_list <- lapply(data$ranking_file, fread)
    
    # Create config column and rename rankings
    data[, config := paste(node_metric, algorithm, sep = ", ")]
    names(ranking_list) <- data$config
    
    # Merge ranking data
    merged_data <- reduce(ranking_list, full_join, by = "node")
    colnames(merged_data)[-1] <- data$config
    
    # Correlation heatmap
    heatmap <- corr_heatmap(data = merged_data)
    height = 1 + 0.5 * ncol(merged_data)
    height <- min(height, 13)
    ggsave(paste0(sim, '_spearman_corr_heatmap_', metric, '.png'), heatmap, width = height+2, height = height, limitsize = FALSE)
    
    # Rank heatmap
    heatmap <- rank_heatmap(data = merged_data, data_type = data_type, gt_dict = gt_dict)
    width = 5.5
    if (data_type == 'simulation'){
      height = 0.25 * nrow(gt_table)
    } else{
      height = 0.25 * top_k
    }
    height <- min(height, 13)
    ggsave(paste0(sim, '_rank_heatmap_', metric, '.png'), heatmap, width = width, height = height)
    
    # Parallel coordinates plot
    parallel_coordinates <- par_coord(data = merged_data, metric = metric, data_type = data_type, gt_dict = gt_dict)
    width = min(1.5 * ncol(merged_data), 12)
    ggsave(paste0(sim, '_parallel_coordinates_', metric, '.png'), parallel_coordinates, width = width, height = 8)
  }
  
  # Node metrics
  for (metric in unique(node_rankings$node_metric)){
    # Filter for metric
    data <- node_rankings[node_metric==metric, ]
    
    if (nrow(data) < 2){
      next
    }
    
    # Read in rankings
    ranking_list <- lapply(data$ranking_file, fread)
    
    # Create config column and rename rankings
    data[, config := paste(edge_metric, algorithm, sep = ", ")]
    names(ranking_list) <- data$config
    
    # Merge ranking data
    merged_data <- reduce(ranking_list, full_join, by = "node")
    colnames(merged_data)[-1] <- data$config
    
    # Correlation heatmap
    heatmap <- corr_heatmap(data = merged_data)
    height = 1 + 0.5 * ncol(merged_data)
    height <- min(height, 13)
    ggsave(paste0(sim, '_spearman_corr_heatmap_', metric, '.png'), heatmap, width = height+2, height = height, limitsize = FALSE)
    
    # Rank heatmap
    heatmap <- rank_heatmap(data = merged_data, data_type = data_type, gt_dict = gt_dict)
    width = 5.5
    if (data_type == 'simulation'){
      height = 0.25 * nrow(gt_table)
    } else{
      height = 0.25 * top_k
    }
    height <- min(height, 13)
    ggsave(paste0(sim, '_rank_heatmap_', metric, '.png'), heatmap, width = width, height = height)
    
    # Parallel coordinates plot 
    parallel_coordinates <- par_coord(data = merged_data, metric = metric, data_type = data_type, gt_dict = gt_dict)
    width = min(1.5 * ncol(merged_data), 12)
    ggsave(paste0(sim, '_parallel_coordinates_', metric, '.png'), parallel_coordinates, width = width, height = 8)
  }
  
  # Ranking algorithms
  for (ranking_alg in unique(node_rankings$algorithm)){
    # Filter for metric
    data <- node_rankings[algorithm==ranking_alg, ]
    
    if (nrow(data) < 2){
      next
    }
    
    # Read in rankings
    ranking_list <- lapply(data$ranking_file, fread)
    
    # Create config column and rename rankings
    data[, config := paste(node_metric, edge_metric, sep = ", ")]
    names(ranking_list) <- data$config
    
    # Merge ranking data
    merged_data <- reduce(ranking_list, full_join, by = "node")
    colnames(merged_data)[-1] <- data$config
    
    # Correlation heatmap
    heatmap <- corr_heatmap(data = merged_data)
    height = 1 + 0.5 * ncol(merged_data)
    height <- min(height, 13)
    ggsave(paste0(sim, '_spearman_corr_heatmap_', ranking_alg, '.png'), heatmap, width = height+2, height = height, limitsize = FALSE)
    
    # Rank heatmap
    heatmap <- rank_heatmap(data = merged_data, data_type = data_type, gt_dict = gt_dict)
    width = 5.5
    if (data_type == 'simulation'){
      height = 0.25 * nrow(gt_table)
    } else{
      height = 0.25 * top_k
    }
    height <- min(height, 13)
    ggsave(paste0(sim, '_rank_heatmap_', ranking_alg, '.png'), heatmap, width = width, height = height)
    
    # Parallel coordinates plot
    parallel_coordinates <- par_coord(data = merged_data, metric = ranking_alg, data_type = data_type, gt_dict = gt_dict)
    width = min(1.5 * ncol(merged_data), 12)
    ggsave(paste0(sim, '_parallel_coordinates_', ranking_alg, '.png'), parallel_coordinates, width = width, height = 8)
  }
}
