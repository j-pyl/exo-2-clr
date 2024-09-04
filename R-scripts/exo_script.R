library(tidyverse)
library(cowplot)
library(pracma) # to use the function findpeaks
library(zoo)
library(patchwork)
library(ggbeeswarm)

source("Script/exo_functions.R")

# Variables ----

# Parameters for peakfinding
minpeakheight <- 20
threshold <- 10
threshold2 <- 0.8

# Load data ----
# List all files in the Data folder
datalistIntensity <- list.files("Data", pattern = "*IntensityData.csv", full.names = TRUE)
datalistInfo <- list.files("Data", pattern = "*CellInfo.csv", full.names = TRUE)

# Read info csv files and compile
infodf <- do.call(rbind,
                  lapply(datalistInfo,
                         function(x) {
                           temp <- read.csv(x)
                           cnames <- temp$Info
                           temp <- as.data.frame(t(temp$Value))
                           colnames(temp) <- cnames
                           temp$file <- basename(x)
                           temp}
                  ))

# read intensity csv files and compile
intensity_0t_df <- read_intensity_data(datalistIntensity, "recy-0_t")
intensity_0s_df <- read_intensity_data(datalistIntensity, "recy-0_s")
intensity_1t_df <- read_intensity_data(datalistIntensity, "recy-1_t")
intensity_1s_df <- read_intensity_data(datalistIntensity, "recy-1_s")

paired_0t_df <- find_peaks_and_pair(intensity_0t_df, intensity_0s_df, infodf, minpeakheight, threshold, threshold2)
paired_1t_df <- find_peaks_and_pair(intensity_1t_df, intensity_1s_df, infodf, minpeakheight, threshold, threshold2)


# Save important df ----
write.csv(paired_0t_df, "Output/Data/paired_0t.csv", row.names = FALSE)
write.csv(paired_1t_df, "Output/Data/paired_1t.csv", row.names = FALSE)


# Save peak xyt coordinates
extract_peak_xyt(paired_0t_df,'0t')
extract_peak_xyt(paired_1t_df,'1t')


# Plotting ----

sparklines_0t <- ggplot() +
  geom_vline(xintercept = 0, colour = "#efefef") +
  geom_path(data = paired_0t_df, aes(x = RelativeTime, y = norm_0t), colour = "#00a651", size = 0.25) +
  geom_path(data = paired_0t_df, aes(x = RelativeTime, y = norm_0s), colour = "#da70d6", size = 0.25) +
  facet_wrap(. ~ UniqueIDspot, ncol = 10) +
  scale_x_continuous(limits = c(-1.5, 2), expand = c(0, 0)) +
  ylab(label = "Intensity") +
  xlab(label = "Time (s)") +
  theme_cowplot(4) +
  theme(legend.position="none",
        strip.background = element_blank(),
        strip.text.x = element_blank())

ggsave("sparklines_0t.png", sparklines_0t, path = "Output/Plots", width = 100, height = 100, units = "mm", dpi = 300, bg = "white")

sparklines_1t <- ggplot() +
  geom_vline(xintercept = 0, colour = "#efefef") +
  geom_path(data = paired_1t_df, aes(x = RelativeTime, y = norm_1t), colour = "#da70d6", size = 0.25) +
  geom_path(data = paired_1t_df, aes(x = RelativeTime, y = norm_1s), colour = "#00a651", size = 0.25) +
  facet_wrap(. ~ UniqueIDspot, ncol = 10) +
  scale_x_continuous(limits = c(-1.5, 2), expand = c(0, 0)) +
  ylab(label = "Intensity") +
  xlab(label = "Time (s)") +
  theme_cowplot(4) +
  theme(legend.position="none",
        strip.background = element_blank(),
        strip.text.x = element_blank())

ggsave("sparklines_1t.png", sparklines_1t, path = "Output/Plots", width = 100, height = 100, units = "mm", dpi = 300, bg = "white")
