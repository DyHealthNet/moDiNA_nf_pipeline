#!/usr/bin/env Rscript

######## ------------- Libraries ------------- ########
library(patchwork)
library(ggplot2)
library(dplyr)
library(stringr)
library(data.table)
library(colorspace)
library(argparse)

######## ------------- Utils ------------- ########

# Colors
ground_truth_palette <- c(
  "diff. corr."                = "#fdbf6f",
  "mean shift"                  = "#C195C4",
  "mean shift + diff. corr."    = "#b2df8a",
  "non-ground truth"            = "lightgray"
)

# Create dictionary for ground truth edges
create_gt_edge_dict <- function(path, mode){
  gt_table <- fread(path)
  colnames(gt_table) <- c("node", "description")
  gt_table$description <- str_trim(gt_table$description)
  
  gt_dict <- list()
  pair <- c()
  
  for (j in seq_len(nrow(gt_table))) {
    row <- gt_table[j, ]
    if (str_detect(row$description, "corr\\.")) {
      pair <- c(pair, row$node)
      if (length(pair) == 2) {
        edge <- paste(sort(pair), collapse = "_")
        gt_dict[[edge]] <- row$description
        pair <- c()
      }
    }
  }
  
  return(gt_dict)
}

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

# Data for jitter plot of differential scores
diff_scores_jitter <- function(configs, metric, mode = 'edges', study = 'simulation'){
  if (study == 'simulation'){
    
    # Loop through all provided configurations
    all_data <- list()
    for (i in seq_along(configs)) {
      config <- configs[[i]]
      
      # Extract scores and paths
      scores <- fread(config$scores)
      gt_path <- config$groundtruth
      sim <- config$sim
      
      # Read ground truths
      gt_table <- fread(config$groundtruth)
      colnames(gt_table) <- c("node", "description")
      gt_table$description <- str_trim(gt_table$description)
      
      if (mode == "edges") {
        # Create dictionary containing all ground truth edges
        gt_dict <- create_gt_edge_dict(config$groundtruth)
      } else{
        # Create dictionary containing all ground truth nodes
        gt_table <- fread(config$groundtruth)
        colnames(gt_table) <- c("node", "description")
        gt_table$description <- str_trim(gt_table$description)
        gt_dict <- setNames(gt_table$description, gt_table$node)
        colnames(scores)[1] <- "node"
      }
      
      # Map scores using the ground truth dictionary and add gt column to scores
      gt <- t(apply(scores, 1, get_gt_info, mode=mode, gt_dict=gt_dict))
      scores <- cbind(scores, as.data.frame(gt))
      scores$sim <- sim
      
      # Collect all data
      all_data[[i]] <- scores %>% select(all_of(metric), groundtruth, description, sim)
    }
    
    # Combine all data
    combined_data <- bind_rows(all_data)
    combined_data$description <- factor(combined_data$description, levels = names(ground_truth_palette))
    combined_data$value <- combined_data[[metric]]
    combined_data$metric <- metric
    combined_data[[metric]] <- NULL
    
  } else if (study == 'real'){
    # Loop through all provided configurations
    all_data <- list()
    for (i in seq_along(configs)) {
      config <- configs[[i]]
      
      # Extract scores
      scores <- fread(config$scores)
      
      if (mode == "nodes") {
        colnames(scores)[1] <- "node"
      }
      
      # Collect all data
      all_data[[i]] <- scores %>% select(all_of(metric))
    }
    
    # Combine all data
    combined_data <- bind_rows(all_data)
    
    combined_data$value <- combined_data[[metric]]
    combined_data$metric <- metric
    combined_data[[metric]] <- NULL
  }
  return(combined_data)
}

# Valid metrics
edge_metrics_subset = c('pre-P', 'post-P', 'pre-E', 'post-E', 'int-IS', 'pre-LS', 'post-LS', 'pre-PE', 'post-PE')
node_metrics_subset = c('DC-P', 'DC-E', 'STC', 'PRC-P', 'PRC-E', 'WDC-P', 'WDC-E')

######## ------------- Argument parser ------------- ########
parser <- ArgumentParser(description='Differential Scores Point Plots')
parser$add_argument('summary_file', 
                    help='Input summary data file storing all generated configurations and their results.')
parser$add_argument('data_type', help = 'Type of data: simulation or real')
args <- parser$parse_args()

summary_file <- args$summary_file
data_type <- args$data_type

######## ------------- Process data ------------- ########

summary_dt <- fread(summary_file)
simulations <- max(summary_dt$id, na.rm = TRUE)

# Plot differential scores  
if (data_type == 'simulation'){
  summary_dt <- unique(summary_dt[, c("id", "edge_metric", "node_metric", "node_metrics_file", "edge_metrics_file", "ground_truth_nodes")])
  
  # Edge metrics
  all_plot_data <- list()
  
  summary_dt_edge_metrics <- unique(summary_dt[, c("id", "edge_metric", "edge_metrics_file", "ground_truth_nodes")])
  summary_dt_edge_metrics <- summary_dt_edge_metrics[edge_metric %in% edge_metrics_subset,]
  unique_edge_metrics <- unique(summary_dt_edge_metrics$edge_metric) 
  
  for (metric in unique_edge_metrics){
    configs = c()
    
    summary_dt_edge_metric_subset <- summary_dt_edge_metrics[edge_metric == metric,]
    
    # Get scores and ground truth paths for each simulation and append to configs list
    for (i in 1:simulations){
      scores = summary_dt_edge_metric_subset[id == i, edge_metrics_file][[1]]
      groundtruth = summary_dt_edge_metric_subset[id == i, ground_truth_nodes][[1]]
      if (file.exists(scores)){
        configs <- c(configs, list(list(
          groundtruth = groundtruth,
          scores = scores,
          sim = i
        )))
      }
    }
    if (identical(configs, c())) next
    
    # Append to list
    dt = diff_scores_jitter(configs, metric, mode='edges', study='simulation')
    all_plot_data <- rbind(all_plot_data, dt)
  }
  
  # Plot edge jitter plot only if data exists
  if (is.data.frame(all_plot_data) && nrow(all_plot_data) > 0) {
    edge_metrics_plot <- ggplot(all_plot_data, aes(x=description, y = value, fill = description, color = description, shape = as.factor(sim))) +
      geom_jitter(
        size = 2,
        position = position_jitterdodge(jitter.width = 0.15, jitter.height = 0, dodge.width = 0.5)
      ) +
      facet_grid(metric ~ ., scales = "free_y") +
      guides(color = "none", fill = "none") +
      labs(
        y = "Edge Value",
        x = "Ground Truth",
        fill = "Ground Truth",
        shape = "Simulation",
      ) +
      scale_color_manual(values = ground_truth_palette) +
      theme_minimal() +
      theme(legend.position = "bottom", 
            panel.grid.major.x = element_blank(),
            axis.title.x = element_text(size = 12),  
            axis.title.y = element_text(size = 12),
            axis.text.x  = element_text(size = 10),
            axis.text.y  = element_text(size = 10),
            strip.text = element_text(size = 12),
            panel.spacing.y = unit(1.7, "lines"),
            panel.spacing.x = unit(0.1, "lines"),
            legend.text = element_text(size=10),
            legend.title = element_text(size=12),
            strip.background = element_rect(fill = "grey90", color = "black", linewidth = 0.5))
    
    ggsave('edge_metrics_point_plots.png',
          edge_metrics_plot, width = 8, height = 3 * length(unique(all_plot_data$metric)), limitsize = FALSE)
  }
  
  
  # Node metrics
  summary_dt_node_metrics <- unique(summary_dt[, c("id", "node_metric", "node_metrics_file", "ground_truth_nodes")])
  summary_dt_node_metrics <- summary_dt_node_metrics[node_metric %in% node_metrics_subset,]
  unique_node_metrics <- unique(summary_dt_node_metrics$node_metric) 
  all_plot_data <- list()
  for (metric in unique_node_metrics){
    configs = c()
    
    summary_dt_node_metric_subset <- summary_dt_node_metrics[node_metric == metric,]
    
    # Get scores and ground truth paths for each simulation and append to configs list
    for (i in 1:simulations){
      scores = summary_dt_node_metric_subset[id == i, node_metrics_file][[1]]
      groundtruth = summary_dt_node_metric_subset[id == i, ground_truth_nodes][[1]]
      if (file.exists(scores)){
        configs <- c(configs, list(list(
          groundtruth = groundtruth,
          scores = scores,
          sim = i
        )))
      }
    }
    if (identical(configs, c())) next
    
    # Append to list
    dt = diff_scores_jitter(configs, metric, mode='nodes', study='simulation')
    all_plot_data <- rbind(all_plot_data, dt)
  }
  
  
  # Plot node jitter plot only if data exists
  if (is.data.frame(all_plot_data) && nrow(all_plot_data) > 0) {
    node_metrics_plot <- ggplot(all_plot_data, aes(x=description, y = value, fill = description, color = description, shape = as.factor(sim))) +
      geom_jitter(
        size = 2,
        position = position_jitterdodge(jitter.width = 0.15, jitter.height = 0, dodge.width = 0.5)
      ) +
      facet_grid(metric ~ ., scales = "free_y") +
      guides(color = "none", fill = "none") +
      labs(
        y = "Node Value",
        x = "Ground Truth",
        fill = "Ground Truth",
        shape = "Simulation"
      ) +
      scale_color_manual(values = ground_truth_palette) +
      theme_minimal() +
      theme(legend.position = "bottom", 
            panel.grid.major.x = element_blank(),
            axis.title.x = element_text(size = 12),  
            axis.title.y = element_text(size = 12),
            axis.text.x  = element_text(size = 10),
            axis.text.y  = element_text(size = 10),
            strip.text = element_text(size = 12),
            panel.spacing.y = unit(1.7, "lines"),
            panel.spacing.x = unit(0.1, "lines"),
            legend.text = element_text(size=10),
            legend.title = element_text(size=12),
            strip.background = element_rect(fill = "grey90", color = "black", linewidth = 0.5))
    
    ggsave('node_metrics_point_plots.png',
          node_metrics_plot, width = 8, height = 3 * length(unique(all_plot_data$metric)), limitsize = FALSE)
  }
  
} else if (data_type == 'real'){
  
  summary_dt <- unique(summary_dt[, c("id", "edge_metric", "node_metric", "node_metrics_file", "edge_metrics_file")])
  
  
  # Edge metrics
  all_plot_data <- list()
  
  summary_dt_edge_metrics <- unique(summary_dt[, c("id", "edge_metric", "edge_metrics_file")])
  summary_dt_edge_metrics <- summary_dt_edge_metrics[edge_metric %in% edge_metrics_subset,]
  unique_edge_metrics <- unique(summary_dt_edge_metrics$edge_metric) 
  
  for (metric in unique_edge_metrics){
    configs = c()
    
    summary_dt_edge_metric_subset <- summary_dt_edge_metrics[edge_metric == metric,]
    
    # Get scores and ground truth paths for each simulation and append to configs list
    for (i in 1:simulations){
      scores = summary_dt_edge_metric_subset[id == i, edge_metrics_file][[1]]
      if (file.exists(scores)){
        configs <- c(configs, list(list(
          scores = scores
        )))
      }
    }
    if (identical(configs, c())) next
    
    # Append to list
    dt = diff_scores_jitter(configs, metric, mode='edges', study='real')
    all_plot_data <- rbind(all_plot_data, dt)
  }
  
  # Plot edge jitter plot only if data exists
  if (is.data.frame(all_plot_data) && nrow(all_plot_data) > 0) {
  edge_metrics_plot <- ggplot(all_plot_data, aes(x=1, y = value)) +
    geom_jitter(
      shape = 21, size = 2.0, alpha = 0.6, stroke = 1,color="gray50", fill="gray70"
    )+
    facet_grid(metric ~ ., scales = "free_y") +
    labs(
      y = "Edge Value",
      x = ""
    ) +
    theme_minimal() +
    theme(legend.position = "bottom", 
          panel.grid.major.x = element_blank(),
          axis.title.x = element_blank(),  
          axis.title.y = element_text(size = 12),
          axis.text.x  = element_blank(),
          axis.text.y  = element_text(size = 10),
          strip.text = element_text(size = 12),
          panel.spacing.y = unit(1.7, "lines"),
          panel.spacing.x = unit(0.1, "lines"),
          legend.text = element_text(size=10),
          legend.title = element_text(size=12),
          strip.background = element_rect(fill = "grey90", color = "black", linewidth = 0.5))
  
    ggsave('edge_metrics_point_plots.png',
          edge_metrics_plot, width = 6, height = 3 * length(unique(all_plot_data$metric)), limitsize = FALSE)
  }
  
  # Node metrics
  all_plot_data <- list()
  
  summary_dt_node_metrics <- unique(summary_dt[, c("id", "node_metric", "node_metrics_file")])
  summary_dt_node_metrics <- summary_dt_node_metrics[node_metric %in% node_metrics_subset,]
  unique_node_metrics <- unique(summary_dt_node_metrics$node_metric) 
  
  for (metric in unique_node_metrics){
    configs = c()
    
    summary_dt_node_metric_subset <- summary_dt_node_metrics[node_metric == metric,]
    
    # Get scores and ground truth paths for each simulation and append to configs list
    for (i in 1:simulations){
      scores = summary_dt_node_metric_subset[id == i, node_metrics_file][[1]]
      if (file.exists(scores)){
        configs <- c(configs, list(list(
          scores = scores
        )))
      }
    }
    if (identical(configs, c())) next
    
    # Append to list
    dt = diff_scores_jitter(configs, metric, mode='nodes', study='real')
    all_plot_data <- rbind(all_plot_data, dt)
  }
  
  # Plot node jitter plot only if data exists
  if (is.data.frame(all_plot_data) && nrow(all_plot_data) > 0) {
    node_metrics_plot <- ggplot(all_plot_data, aes(x=1, y = value)) +
      geom_jitter(
        shape = 21, size = 2.0, alpha = 0.6, stroke = 1,color="gray50", fill="gray70"
      ) +
      facet_grid(metric ~ ., scales = "free_y") +
      labs(
        y = "Node Value",
        x = ""
      ) +
      theme_minimal() +
      theme(legend.position = "bottom", 
            panel.grid.major.x = element_blank(),
            axis.title.x = element_blank(),  
            axis.title.y = element_text(size = 12),
            axis.text.x  = element_blank(),
            axis.text.y  = element_text(size = 10),
            strip.text = element_text(size = 12),
            panel.spacing.y = unit(1.7, "lines"),
            panel.spacing.x = unit(0.1, "lines"),
            legend.text = element_text(size=10),
            legend.title = element_text(size=12),
            strip.background = element_rect(fill = "grey90", color = "black", linewidth = 0.5))
    
    ggsave('node_metrics_point_plots.png',
          node_metrics_plot, width = 6, height = 3 * length(unique(all_plot_data$metric)), limitsize = FALSE)
    }
  
}
