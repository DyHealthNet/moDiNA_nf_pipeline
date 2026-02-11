#!/usr/bin/env Rscript

######## ------------- Libraries ------------- ########
library(pROC)
library(data.table)
library(ggplot2)
library(argparse)
library(RColorBrewer)

######## ------------- Utils ------------- ########
calculate_AUC_per_simulation <- function(ranking, ground_truth, node_ranking = TRUE) {
  # Sort ranking
  ranking <- ranking[order(rank)]
  
  # Vector of labels (1 for GT nodes, 0 for non-GT nodes)
  ranking[, is_ground_truth := ifelse(node %in% ground_truth$node, 1, 0)]
  
  # Calculate AUC
  roc_obj <- roc(ranking$is_ground_truth, ranking$rank, quiet = TRUE)
  return(auc(roc_obj))
}

calculate_AUC_for_row <- function(ground_truth_file, ranking_file, row_num, node_ranking = TRUE) {
  tryCatch({
    ground_truth <- fread(ground_truth_file)
    ranking <- fread(ranking_file)
    return(calculate_AUC_per_simulation(ranking, ground_truth))
  }, error = function(e) {
    cat("\n=== ERROR in row", row_num, "===\n")
    cat("Ground truth file:", ground_truth_file, "\n")
    cat("Ranking file:", ranking_file, "\n")
    cat("Error message:", e$message, "\n")
    cat("========================\n")
    return(NA)
  })
}

node_metrics <- c("WDC-P", "WDC-E", "DC-P", "DC-E", "PRC-P", "PRC-E", "STC", "None")
node_metrics_colors <- c("#8DD3C7", "#41B6C4", "#F1B6DA", "#DD1C77","#CCCCCC", "#636363", "#FFD700","#FF6B6B")
names(node_metrics_colors) <- node_metrics
  
edge_metrics <- c("pre-CS", "post-CS", "pre-LS", "post-LS", "pre-P", "post-P", "pre-E", "post-E", "pre-PE", "post-PE", "int-IS", "None")
edge_metrics_colors <- c("#A6CEE3", "#1F78B4", "#B2DF8A", "#33A02C","#FB9A99", "#E31A1C", "#FDBF6F", "#FF7F00", "#CAB2D6","#6A3D9A" , "#FFFF99", "#B15928")
names(edge_metrics_colors) <- edge_metrics

######## ------------- Argument parser ------------- ########
parser <- ArgumentParser(description='AUC Heatmap Generator')
parser$add_argument('summary_file', 
                    help='Input summary data file storing all generated configurations and their results.')
args <- parser$parse_args()

summary_file <- args$summary_file

######## ------------- Process data ------------- ########
######## ------------- Process data ------------- ########
summary_dt <- fread(summary_file)

# Store edge ranking independently
edge_ranking_dt <- summary_dt[algorithm == "direct_edge",]

# Remove direct_edge ranking
summary_dt <- summary_dt[summary_dt$algorithm != "direct_edge",]

# Calculate AUC for each row with row number tracking
summary_dt[, auc := mapply(calculate_AUC_for_row, 
                           ground_truth_file, 
                           ranking_file,
                           row_num = .I,  # Pass row index
                           SIMPLIFY = TRUE)]

# Replace names
summary_dt[algorithm == "direct_node", algorithm := "Direct Node"]
summary_dt[node_metric == "", node_metric := "None"]
summary_dt[edge_metric == "", edge_metric := "None"]

# Level algorithms
summary_dt$algorithm <- factor(summary_dt$algorithm, levels = c("absDimontRank", "DimontRank", "PageRank", "PageRank+", "Direct Node"))

# Group by configuration and calculate mean/sd AUC
results <- summary_dt[, .(
  mean_auc = mean(auc),
  sd_auc = sd(auc),
  n_simulations = .N
), by = .(node_metric, edge_metric, algorithm)]

results$node_metric <- factor(results$node_metric, levels = names(node_metrics_colors))
results$edge_metric <- factor(results$edge_metric, levels = names(edge_metrics_colors))

# Plot
p <- ggplot(results, aes(x = edge_metric, y = node_metric, fill = mean_auc)) +
  geom_tile(color="black") + 
  geom_text(aes(label = sprintf('%.2f', mean_auc)), size = 3) +
  facet_grid(algorithm~., scales = "free", space = "free") +
  labs(x = "Edge Metric", y = "Node Metric", fill = "Mean AUC") +
  scale_fill_gradient(low = 'white', high = '#C03830', name = 'AUC', guide = guide_colorbar(barwidth = 1.5, barheight = 10), limits = c(0.4, 1.0)) +
  theme_minimal() +
  theme(
    panel.grid = element_blank(),
    panel.spacing.x = unit(1, 'lines'),
    axis.text.x = element_text(size = 10, angle=90, hjust=1, vjust=0.5),
    axis.text.y = element_text(size = 10),
    strip.text.y = element_text(size = 10, angle = 0),
    strip.text.x = element_text(size = 10),
    axis.title.x = element_text(size = 10),
    axis.title.y = element_text(size = 10),
    strip.background = element_rect(fill = 'grey90', color = 'black', linewidth = 0.5)
  )

ggsave("overall_heatmap_auc.png", width = 8, height = 10, dpi = 300, bg = "white")
  
for(al in unique(results$algorithm)){
  print(paste0("Algorithm: ", al))
  dt <- results[results$algorithm == al,]
  n_uniq_comb <- nrow(unique(dt[, c("node_metric", "edge_metric")]))
  ggplot(dt, aes(y = node_metric, x = mean_auc, fill = edge_metric)) +
    geom_bar(stat = "identity", position = position_dodge(0.9), width = 0.9) +
    geom_errorbar(aes(xmin = mean_auc - sd_auc, xmax = mean_auc + sd_auc), 
                  position = position_dodge(0.9), width = 0.5) +
    labs(x = "Mean AUC", y = "Node Metric", fill = "Edge Metric") +
    theme_bw() +
    ggtitle(al)+
    theme(
      panel.spacing.x = unit(1, 'lines'),
      axis.text.x = element_text(size = 10),
      axis.text.y = element_text(size = 10),
      strip.text.y = element_text(size = 10, angle = 0),
      strip.text.x = element_text(size = 10),
      axis.title.x = element_text(size = 10),
      axis.title.y = element_text(size = 10),
      strip.background = element_rect(fill = 'grey90', color = 'black', linewidth = 0.5),
      plot.title = element_text(size = 12, hjust = 0.5) 
    ) +
    scale_fill_manual(values = edge_metrics_colors)
  ggsave(paste0("barplot_auc_algorithm_", al, "_edge_metrics_colored.png"), width = 8, height = 5, dpi = 300, bg = "white")

  ggplot(dt, aes(y = edge_metric, x = mean_auc, fill = node_metric)) +
    geom_bar(stat = "identity", position = position_dodge(0.9)) +
    geom_errorbar(aes(xmin = mean_auc - sd_auc, xmax = mean_auc + sd_auc), 
                  position = position_dodge(0.9), width = 0.5) +
    labs(x = "Mean AUC", y = "Edge Metric", fill = "Node Metric") +
    theme_bw() +
    ggtitle(al)+
    theme(
      panel.spacing.x = unit(1, 'lines'),
      axis.text.x = element_text(size = 10),
      axis.text.y = element_text(size = 10),
      strip.text.y = element_text(size = 10, angle = 0),
      strip.text.x = element_text(size = 10),
      axis.title.x = element_text(size = 10),
      axis.title.y = element_text(size = 10),
      strip.background = element_rect(fill = 'grey90', color = 'black', linewidth = 0.5),
      plot.title = element_text(size = 12, hjust = 0.5) 
    ) +
    scale_fill_manual(values = node_metrics_colors)
  ggsave(paste0("barplot_auc_algorithm_", al, "_node_metrics_colored.png"), width = 8, height = 5, dpi = 300, bg = "white")
  
  
}


# Plot edge ranking

#edge_ranking_dt <- edge_ranking_dt[algorithm == "direct_edge",]

#if (nrow(edge_ranking_dt) > 0) {
  # Calculate AUC for each row with row number tracking
#  edge_ranking_dt[, auc := mapply(calculate_AUC_for_row, 
#                                  ground_truth_file, 
#                                  ranking_file,
#                                  row_num = .I,  # Pass row index
#                                  node_ranking = FALSE,
#                                  SIMPLIFY = TRUE)]
  
  
  

 # }

