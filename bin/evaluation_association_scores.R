#!/usr/bin/env Rscript

######## ------------- Libraries ------------- ########
library(data.table)
library(ggplot2)
library(argparse)
library(RColorBrewer)
library(stringr)
library(dplyr)
library(colorspace)
library(patchwork)


######## ------------- Utils ------------- ########

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

# Jitter plot of association scores
assoc_scores_jitter <- function(scores, metric, data_type, label_positions = NULL){
  if (data_type == 'simulation'){
    if (metric == 'P'){
      p <- ggplot(scores, aes(x = x_jitter, y = `raw-P`, color = description)) +
        geom_point(aes(x = x_jitter, fill = description, color = description),
                   shape = 21, size = 2, alpha = 0.6, stroke = 1) +
        geom_line(aes(group = id), alpha = 0.2) +
        guides(color = "none") +
        labs(
          y = 'Adjusted P-Value',
          x = "",
          fill = "Ground Truth"
        ) +
        scale_fill_manual(values = ground_truth_palette_edges) +
        scale_color_manual(values = ground_truth_palette_edges_dark) + # Make circles a little darker
        theme_minimal() +
        theme(legend.position = "right", 
              panel.grid.major.x = element_blank(),
              axis.title.x = element_text(size = 12),  
              axis.title.y = element_text(size = 12),
              axis.text.x  = element_text(size = 10),
              axis.text.y  = element_text(size = 10),
              panel.spacing.y = unit(1.7, "lines"),
              panel.spacing.x = unit(0.1, "lines"),
              legend.text = element_text(size=10),
              legend.title = element_text(size=12),
              strip.background = element_blank(),
              strip.text = element_blank()) +
        facet_grid(test_type ~ ., scales = "free_y", label = "label_parsed") +
        scale_x_continuous(
          breaks = label_positions$x,
          labels = label_positions$context
        )
    } else if (metric == 'E'){
      p <- ggplot(scores, aes(x = x_jitter, y = `raw-E`, color = description)) +
        geom_point(aes(x = x_jitter, fill = description, color = description),
                   shape = 21, size = 2, alpha = 0.6, stroke = 1) +
        geom_line(aes(group = id), alpha = 0.2) +
        guides(color = "none") +
        labs(
          y = 'Raw Effect Size',
          x = "",
          fill = "Ground Truth"
        ) +
        scale_fill_manual(values = ground_truth_palette_edges) +
        scale_color_manual(values = ground_truth_palette_edges_dark) + # Make circles a little darker
        theme_minimal() +
        theme(legend.position = "right", 
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
              strip.background = element_rect(fill = "grey90", color = "black", linewidth = 0.5)) +
        facet_grid(test_type ~ ., scales = "free_y", label = "label_parsed") +
        scale_x_continuous(
          breaks = label_positions$x,
          labels = label_positions$context
        )
    }
  } else if (data_type == 'real'){
    if (metric == 'P'){
      p <- ggplot(scores, aes(x = factor(context), y = `raw-P`)) +
        geom_jitter(
          fill = 'grey90', 
          color = 'grey90',
          shape = 21, size = 2.0, alpha = 0.6, stroke = 1,
          position = position_jitter(width = 0.15, height = 0)
        ) +
        labs(
          y = 'Adjusted P-Value',
          x = ""
        ) +
        theme_minimal() +
        theme(
          panel.grid.major.x = element_blank(),
          axis.title = element_text(size = 12),
          axis.text  = element_text(size = 10),
          panel.spacing.y = unit(1.7, "lines"),
          panel.spacing.x = unit(0.1, "lines"),
          strip.background = element_blank(),
          strip.text = element_blank()) +
        facet_grid(test_type ~ ., scales = "free_y", label = "label_parsed") +
        scale_x_discrete(expand = expansion(add = 0.7))
    } else if (metric == 'E'){
      p <- ggplot(scores, aes(x = factor(context), y = `raw-E`)) +
        geom_jitter(
          fill = 'grey90', 
          color = 'grey90',
          shape = 21, size = 2.0, alpha = 0.6, stroke = 1,
          position = position_jitter(width = 0.15, height = 0)
        ) +
        labs(
          y = 'Raw Effect Size',
          x = ""
        ) +
        theme_minimal() +
        theme(
          panel.grid.major.x = element_blank(),
          axis.title = element_text(size = 12),
          axis.text  = element_text(size = 10),
          strip.text = element_text(size = 12),
          panel.spacing.y = unit(1.7, "lines"),
          panel.spacing.x = unit(0.1, "lines"),
          strip.background = element_rect(fill = "grey90", color = "black", linewidth = 0.5)) +
        facet_grid(test_type ~ ., scales = "free_y", label = "label_parsed") +
        scale_x_discrete(expand = expansion(add = 0.7))
    }
  }
}

# Set colors for multiple ground truth types
ground_truth_palette <- c(
  "diff. corr."                = "#fdbf6f",
  "mean shift"                  = "#C195C4",
  "mean shift + diff. corr."    = "#b2df8a",
  "non-ground truth"            = "lightgray"
)

ground_truth_palette_edges <- c(
  "diff. corr."                = "#fdbf6f",
  "mean shift + diff. corr."    = "#b2df8a",
  "non-ground truth"            = "lightgray"
)

# Create a darker ground truth palette
ground_truth_palette_dark <- darken(ground_truth_palette, amount = 0.4)
ground_truth_palette_edges_dark <- darken(ground_truth_palette_edges, amount = 0.4)

# Test naming
statistical_tests <-   c("pearson"="Pearson", 
                       "spearman"="Spearman",
                       "ttest" = "italic(t)~-Test",
                       "mwu" = "Mann-Whitney~italic(U)",
                       "anova" = "ANOVA",
                       "kruskal" = "Kruskal-Wallis",
                       "chi2" = "chi^2~-Test")


######## ------------- Argument parser ------------- ########
parser <- ArgumentParser(description='Association Scores Point Plots')
parser$add_argument('summary_file', 
                     help='Input summary data file storing all generated configurations and their results.')
parser$add_argument('data_type', help = 'Type of data: simulation or real')
parser$add_argument('name_context_1', default = "Context 1", help = 'Name for the first network context (default: Context 1)')
parser$add_argument('name_context_2', default = "Context 2", help = 'Name for the second network context (default: Context 2)')
args <- parser$parse_args()

summary_file <- args$summary_file
data_type <- args$data_type
name_context_1 <- args$name_context_1
name_context_2 <- args$name_context_2

######## ------------- Process data ------------- ########
summary_dt <- fread(summary_file)

summary_dt <- unique(summary_dt[, c("id", "network_context_1", "network_context_2", "ground_truth_nodes")])


if (data_type == 'simulation'){
  data <- data.table()
  
  for (i in unique(summary_dt$id)){
    # Get paths
    gt_path <- summary_dt[id == i, ground_truth_nodes]
    scores1 <- summary_dt[id == i, network_context_1]
    scores2 <- summary_dt[id == i, network_context_2]
    
    # Create dictionary with ground truth edges
    gt_dict <- create_gt_edge_dict(gt_path)
    
    # Read scores
    scores_a <- fread(scores1)
    scores_b <- fread(scores2)
    
    # Add context column and combine
    scores_a[, context := name_context_1]
    scores_b[, context := name_context_2]
    scores_ab <- rbind(scores_a, scores_b)
    
    # Map scores using the ground truth dictionary and add gt column to scores
    gt <- t(apply(scores_ab, 1, get_gt_info, mode='edges', gt_dict=gt_dict))
    scores_ab <- cbind(scores_ab, as.data.frame(gt))
    
    data <- rbind(data, scores_ab)
  }
  
  # Replace test type with more descriptive names from statistical_tests vector
  data[, test_type:= statistical_tests[test_type]]
  
  
  # Prepare data for plotting
  data <- data[, id := paste(label1, label2, sep = "_")]
  #data[description == "non-ground truth", id := paste0("nonGT_", .I)]
  data <- data %>%
    mutate(
      base_x = case_when(
        context == name_context_1 & description != 'non-ground truth' ~ 1.3,
        context == name_context_1 & description == 'non-ground truth' ~ 2.3,
        context == name_context_2 & description != 'non-ground truth' ~ 1.8,
        context == name_context_2 & description == 'non-ground truth' ~ 2.8,
        TRUE ~ NA_real_
      ),
      x_jitter = base_x + runif(n(), -0.15, 0.15)
    )
  
  label_positions <- data.frame(
    context = c(name_context_1, name_context_2, name_context_1, name_context_2),
    x = c(1.3, 1.8, 2.3, 2.8)
  )
  
  # Plot and save
  plot_p <- assoc_scores_jitter(data, 'P', data_type='simulation', label_positions=label_positions)
  plot_e <- assoc_scores_jitter(data, 'E', data_type='simulation', label_positions=label_positions)
  
  n_tests <- data[, uniqueN(test_type)]
  
  plot_all <- plot_p + plot_e + plot_layout(guides = "collect") & theme(legend.position = "bottom")
  
  ggsave('association_scores_point_plot.png', plot_all, width = 12, height = 3 * n_tests)
  
} else if (data_type == 'real'){
  # Get paths
  scores1 <- summary[id == 1, network_context_1]
  scores2 <- summary[id == 1, network_context_2]
  
  # Read scores
  scores_a <- fread(scores1)
  scores_b <- fread(scores2)
  
  # Add context column and combine
  scores_a[, context:=name_context_1]
  scores_b[, context:=name_context_2]
  scores_ab <- rbind(scores_a, scores_b)
  
  scores_ab[, test_type:= statistical_tests[test_type]]
  
  # Plot and save
  plot_p <- assoc_scores_jitter(scores_ab, 'P', data_type='real')
  plot_e <- assoc_scores_jitter(scores_ab, 'E', data_type='real')
  
  n_tests <- scores_ab[, uniqueN(test_type)]
  
  plot_all <- plot_p + plot_e + plot_layout(guides = "collect") & theme(legend.position = "bottom")
  
  ggsave('association_scores_point_plot.png', plot_all, width = 12, height = 3 * n_tests)
  
}
