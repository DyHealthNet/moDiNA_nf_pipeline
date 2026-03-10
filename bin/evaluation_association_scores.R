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

calculate_mean_difference <- function(scores, context1, context2, metric, data_type = "simulation"){
  data <- copy(scores)
  if(data_type == "simulation"){
    # Select columns
    cols_to_keep <- c("id", "sim", "groundtruth", "test_type", "context", metric)
    scores <- scores[, ..cols_to_keep]
    # Make sure scores is a data.table
    setDT(scores)  # Add this line
    scores <- dcast(scores, id + groundtruth + sim + test_type ~ context, value.var = metric)
    scores$diff <- abs(scores[[name_context_2]] - scores[[name_context_1]])
    # Average for ground truth and non-ground truth nodes
    scores_summary <- scores[, .(mean_diff = mean(diff, na.rm = TRUE)), by = .(groundtruth, test_type)]
    scores_summary$mean_diff <- paste0("Mean~Difference:~", round(scores_summary$mean_diff, 3))
    colnames(scores_summary) <- c("groundtruth", "test_type", paste0("mean_diff_", metric))
    data <- merge(data, scores_summary, by = c("groundtruth", "test_type"), all.x = TRUE)
  } else {
    # Select columns
    cols_to_keep <- c("id", "test_type", "context", metric)
    scores <- scores[, ..cols_to_keep]
    # Make sure scores is a data.table
    setDT(scores)  # Add this line
    scores <- dcast(scores, id + test_type ~ context, value.var = metric)
    scores$diff <- abs(scores[[name_context_2]] - scores[[name_context_1]])
    # Average
    scores_summary <- scores[, .(mean_diff = mean(diff, na.rm = TRUE)), by = .(test_type)]
    scores_summary$mean_diff <- paste0("Mean~Difference:~", round(scores_summary$mean_diff, 3))
    colnames(scores_summary) <- c("test_type", paste0("mean_diff_", metric))
    data <- merge(data, scores_summary, by = c("test_type"), all.x = TRUE)
  }
  return(data)
}

# Jitter plot of association scores
assoc_scores_jitter <- function(scores, metric, data_type){
  if(metric=="raw-P"){
    strip_background_element <- element_blank()
    strip_title_element <- element_blank()
    mean_col <- "mean_diff_raw-P"
  } else if (metric == "raw-E"){
    strip_background_element <- element_rect(fill = 'grey90', color = 'black', linewidth = 0.5)
    strip_title_element <- element_text(size = 12)
    mean_col <- "mean_diff_raw-E"
  }
  grid_formula <- as.formula(paste("test_type~`", mean_col,"`", sep=""))
  if (data_type == 'simulation'){
    all_plots <- list()
    for(i in 1:length(unique(scores$test_type))){
      t <- unique(scores$test_type)[i]
      if(i == length(unique(scores$test_type))){
        context_label_element <- element_text(size = 12)
      } else {
        context_label_element <- element_blank()
      }
      scores_tmp <- scores[scores$test_type == t,]
      p <- ggplot(scores_tmp, aes(x = context, y = get(metric), color = description, shape = as.factor(sim))) +
        geom_point(aes(group=interaction(id,sim)), position = position_dodge(width = 0.3), size = 2) +
        geom_line(aes(group=interaction(id,sim)), alpha = 0.2, position = position_dodge(width = 0.3)) +
        labs(
          y = "",
          x = "",
          color = "Ground Truth",
          shape = "Simulation"
        ) +
        scale_color_manual(values = ground_truth_palette) + 
        theme_minimal() +
        theme(legend.position = "right", 
              panel.grid.major.x = element_blank(),
              axis.text.x  = context_label_element,
              axis.text.y  = element_text(size = 10),
              panel.spacing.y = unit(1.7, "lines"),
              panel.spacing.x = unit(0.1, "lines"),
              legend.text = element_text(size=10),
              legend.title = element_text(size=12),
              strip.background.y = strip_background_element,
              strip.text.y = strip_title_element) +
        facet_grid(grid_formula, label = "label_parsed")
      all_plots[[t]] <- p
    }
  } else {
      all_plots <- list()
      for(i in 1:length(unique(scores$test_type))){
        t <- unique(scores$test_type)[i]
        if(i == length(unique(scores$test_type))){
          context_label_element <- element_text(size = 12)
        } else {
          context_label_element <- element_blank()
        }
        scores_tmp <- scores[scores$test_type == t,]
        p <- ggplot(scores_tmp, aes(x = context, y = get(metric))) +
          geom_point(aes(group=id), position = position_dodge(width = 0.3), size = 2, color="grey50") +
          geom_line(aes(group=id), alpha = 0.2, position = position_dodge(width = 0.3), color="grey50") +
          labs(
            y = "",
            x = ""
          ) +
          theme_minimal() +
          theme(legend.position = "right", 
                panel.grid.major.x = element_blank(),
                axis.text.x  = context_label_element,
                axis.text.y  = element_text(size = 10),
                panel.spacing.y = unit(1.7, "lines"),
                panel.spacing.x = unit(0.1, "lines"),
                legend.text = element_text(size=10),
                legend.title = element_text(size=12),
                strip.background.y = strip_background_element,
                strip.text.y = strip_title_element) +
          facet_grid(grid_formula, label = "label_parsed")
        all_plots[[t]] <- p
      }
    }
    
    p <- wrap_plots(all_plots, ncol = 1)
    return(p)
}

# Set colors for multiple ground truth types
ground_truth_palette <- c(
  "diff. corr."                = "#fdbf6f",
  "mean shift"                  = "#C195C4",
  "mean shift + diff. corr."    = "#b2df8a",
  "non-ground truth"            = "lightgray"
)


# Test naming
statistical_tests <-   c("pearson"="Pearson", 
                       "spearman"="Spearman",
                       "ttest" = "italic(t)~-Test",
                       "mwu" = "Mann-Whitney~italic(U)",
                       "anova" = "ANOVA",
                       "kruskal" = "Kruskal-Wallis",
                       "chi2" = "chi^2~-Test")

######## ------------- Argument parser ------------- ########
parser <- ArgumentParser(description='AUC Heatmap Generator')
parser$add_argument('summary_file', 
                    help='Input summary data file storing all generated configurations and their results.')
parser$add_argument('data_type', help = 'Type of data: simulation or real')
parser$add_argument('name_context_1', help = 'Name of the first context (default: Context 1)')
parser$add_argument('name_context_2', help = 'Name of the second context (default: Context 2)')

args <- parser$parse_args()

summary_file <- args$summary_file
data_type <- args$data_type
name_context_1 <- args$name_context_1
name_context_2 <- args$name_context_2


######## ------------- Process data ------------- ########
summary_dt <- fread(summary_file)

if (data_type == 'simulation'){
  summary_dt <- unique(summary_dt[, c("id", "network_context_1", "network_context_2", "ground_truth_nodes")])
  data <- data.table()
  nodes <- data.table()
  
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
    scores_ab$sim <- i
    data <- rbind(data, scores_ab)
  }
  
  # Replace test type with more descriptive names from statistical_tests vector
  data[, test_type:= statistical_tests[test_type]]
  
  
  # Prepare data for plotting
  data <- data[, id := paste(label1, label2, sep = "_")]
  
  # Calculate mean differences between context 1 and context 2
  data <- calculate_mean_difference(data, name_context_1, name_context_2, "raw-P")
  data <- calculate_mean_difference(data, name_context_1, name_context_2, "raw-E")

  # Plot and save
  plot_p <- assoc_scores_jitter(data, 'raw-P', data_type='simulation')
  plot_e <- assoc_scores_jitter(data, 'raw-E', data_type='simulation')
  
  n_tests <- data[, uniqueN(test_type)]
  
  y_label_p <- ggplot() +
    annotate("text", x = 0, y = 0, label = "Adjusted P-Value",
             angle = 90, size = 4) +
    theme_void()
  
  y_label_e <- ggplot() +
    annotate("text", x = 0, y = 0, label = "Raw Effect Size",
             angle = 90, size = 4) +
    theme_void()
  
  plot_all <- y_label_p + plot_p + y_label_e + plot_e + plot_layout(guides = "collect", widths = c(0.03, 1, 0.03, 1)) & theme(legend.position = "bottom")
  

  ggsave('association_scores_point_plot.png', plot_all, width = 12, height = 3 * n_tests)
  
} else if (data_type == 'real'){
  summary_dt <- unique(summary_dt[, c("id", "network_context_1", "network_context_2")])

  # Get paths
  scores1 <- summary_dt[id == 1, network_context_1]
  scores2 <- summary_dt[id == 1, network_context_2]
  
  # Read scores
  scores_a <- fread(scores1)
  scores_b <- fread(scores2)
  
  # Add context column and combine
  scores_a[, context:=name_context_1]
  scores_b[, context:=name_context_2]
  scores_ab <- rbind(scores_a, scores_b)
  
  scores_ab[, test_type:= statistical_tests[test_type]]
  
  # Prepare data for plotting
  scores_ab <- scores_ab[, id := paste(label1, label2, sep = "_")]
  
  # Calculate mean differences between context 1 and context 2
  scores_ab <- calculate_mean_difference(scores_ab, name_context_1, name_context_2, "raw-P", data_type = "real")
  scores_ab <- calculate_mean_difference(scores_ab, name_context_1, name_context_2, "raw-E", data_type = "real")
  
  # Plot and save
  plot_p <- assoc_scores_jitter(scores_ab, 'raw-P', data_type='real')
  plot_e <- assoc_scores_jitter(scores_ab, 'raw-E', data_type='real')
  
  n_tests <- scores_ab[, uniqueN(test_type)]

  y_label_p <- ggplot() +
    annotate("text", x = 0, y = 0, label = "Adjusted P-Value",
             angle = 90, size = 4) +
    theme_void()
  
  y_label_e <- ggplot() +
    annotate("text", x = 0, y = 0, label = "Raw Effect Size",
             angle = 90, size = 4) +
    theme_void()
  
  plot_all <- y_label_p + plot_p + y_label_e + plot_e + plot_layout(guides = "collect", widths = c(0.03, 1, 0.03, 1)) & theme(legend.position = "bottom")
  
  ggsave('association_scores_point_plot.png', plot_all, width = 12, height = 3 * n_tests)
  
}
