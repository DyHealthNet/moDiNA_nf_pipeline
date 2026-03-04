#!/usr/bin/env Rscript

######## ------------- Libraries ------------- ########
library(data.table)
library(ggplot2)
library(argparse)
library(stringr)
library(dplyr)


######## ------------- Utils ------------- ########

# Set colors for multiple ground truth types
ground_truth_palette <- c(
  "diff. corr."                = "#fdbf6f",
  "mean shift"                  = "#C195C4",
  "mean shift + diff. corr."    = "#b2df8a",
  "non-ground truth"            = "lightgray"
)


######## ------------- Argument parser ------------- ########
parser <- ArgumentParser(description='Mean Shift Detection') 
parser$add_argument('summary_file', 
                     help='Input summary data file storing all generated configurations and their results.')
parser$add_argument('data_type', help = 'Type of data (simulation or real)')
parser$add_argument('name_context_1', help = 'Name of the first context (default: Context 1)')
parser$add_argument('name_context_2', help = 'Name of the second context (default: Context 2)')

args <- parser$parse_args()

summary_file <- args$summary_file
name_context_1 <- args$name_context_1
name_context_2 <- args$name_context_2
data_type <- args$data_type


######## ------------- Process data ------------- ########
summary_dt <- fread(summary_file)

colnames <- c("id", "file_context_1", "file_context_2", "meta_file")
if(data_type == "simulation"){
  colnames <- c(colnames, "ground_truth_nodes")
}

summary_dt <- unique(summary_dt[,..colnames])

all_data <- data.table()
for (i in unique(summary_dt$id)){
  # Get paths
  data1_path <- summary_dt[id == i, file_context_1]
  data2_path <- summary_dt[id == i, file_context_2]
  meta_file <- summary_dt[id == i, meta_file]
  
  # Read data
  data1 <- fread(data1_path)
  data2 <- fread(data2_path)
  meta_dt <- fread(meta_file)
  
  if(data_type == "simulation"){
    gt_path <- summary_dt[id == i, ground_truth_nodes]
    gt_dt <- fread(gt_path)
    #edge_nodes <- gt_dt[gt_dt$description == "diff. corr.",]
    #data1 <- data1[, !edge_nodes$node, with = FALSE]
    #data2 <- data2[, !edge_nodes$node, with = FALSE]
  }
  
  data1$sample <- paste0("sample", 1:nrow(data1))
  data2$sample <- paste0("sample", 1:nrow(data2))
  
  
  data1 <- melt(data1, id.vars = "sample", variable.name = "node", value.name = "value")
  data1$context <- name_context_1
  data2 <- melt(data2, id.vars = "sample", variable.name = "node", value.name = "value")
  data2$context <- name_context_2
  
  data <- rbind(data1, data2)
  data$sim <- i
  data <- merge(data, meta_dt[, .(label, type)], by.x = "node", by.y = "label", all.x = TRUE)
  
  if(data_type == "simulation"){
    data <- merge(data, gt_dt,by = "node", all.x = TRUE)
    data[is.na(data$description),]$description <- "non-ground truth"
  }
  
  all_data <- rbind(all_data, data)
}

# Mean plot
if(data_type == "simulation"){
  mean_data <- all_data %>% group_by(node, context, description, sim, type) %>% 
    summarize(mean = mean(value, na.rm = TRUE)) %>% as.data.table()
} else {
  mean_data <- all_data %>% group_by(node, context, sim, type) %>% 
    summarize(mean = mean(value, na.rm = TRUE)) %>% as.data.table()
}

# Capitalize node_types
mean_data$type <- str_to_title(mean_data$type)

if(data_type == "simulation"){
  ggplot(mean_data, aes(x = context, y = mean, color = description, shape = as.factor(sim))) +
    geom_point() +
    geom_line(aes(group = interaction(node, sim)), alpha = 0.5) +
    theme_bw() +
    scale_color_manual(values = ground_truth_palette) +
    labs( x= "", y = "Mean Value", color = "Ground Truth", shape = "Simulation") +
    facet_wrap(~type, scales = "free")
} else {
  ggplot(mean_data, aes(x = context, y = mean)) +
    geom_point() +
    geom_line(aes(group = node), alpha = 0.5) +
    theme_bw() +
    labs( x= "", y = "Mean Value") +
    facet_wrap(~type, scales = "free")
}
ggsave("mean_shift_point_plot.png", width = 8, height = 5)