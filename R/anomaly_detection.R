# ============================================================
# anomaly_detection.R
# Water waste / anomaly detection using
#     Expected consumption  vs  Actual consumption
#
# IDEA (easy to explain in viva):
#   1. Learn what "normal" usage looks like from history, using a
#      Linear Regression (people, building, temperature, rainfall,
#      weekday/weekend).  -> Expected_Usage
#   2. Compare with what really happened.  -> Excess_Pct
#   3. If actual is much higher than expected, flag it.
#
# NOTE: this is SEPARATE from future prediction (prediction.R).
#   Expected  = what usage SHOULD have been today, given today's conditions.
#   Predicted = a forecast for FUTURE days.
# ============================================================

library(dplyr)
library(ggplot2)
library(scales)

WASTE_LEVELS <- c("Normal", "Moderate Usage", "High Consumption", "Possible Water Wastage")
WASTE_COLORS <- c("Normal" = "#2e7d32",
                  "Moderate Usage" = "#f9a825",
                  "High Consumption" = "#ef6c00",
                  "Possible Water Wastage" = "#c62828")

# ---- Step 1: build the "expected usage" model --------------
# Two passes so that abnormal days do not distort the baseline:
#   pass 1: fit on all data
#   pass 2: remove days that are > 15% above pass-1 estimate, fit again
fit_expected_model <- function(df) {
  model_formula <- Water_Usage_Liters ~ Building * Total_People +
                                        Building * Temperature +
                                        Rainfall + Is_Weekend

  first_model <- lm(model_formula, data = df)
  ratio <- df$Water_Usage_Liters / pmax(fitted(first_model), 1)

  normal_df <- df[ratio <= 1.15, ]
  message("Expected-usage model trained on ", nrow(normal_df), " of ", nrow(df),
          " records (suspicious high days left out of the baseline).")

  lm(model_formula, data = normal_df)
}

# ---- Helper: count consecutive abnormal days ---------------
count_consecutive <- function(flag) {
  out <- integer(length(flag))
  run <- 0L
  for (i in seq_along(flag)) {
    if (flag[i] == 1L) run <- run + 1L else run <- 0L
    out[i] <- run
  }
  out
}

# ---- Step 2 & 3: compare actual with expected and classify -
# Categories (as % above expected):
#   Normal                 : <= 10%
#   Moderate Usage         : > 10% to 20%
#   High Consumption       : > 20% to 30%
#   Possible Water Wastage : > 30%
detect_waste <- function(df, expected_model) {
  df <- df[order(df$Building, df$Date), ]

  df$Expected_Usage     <- round(pmax(predict(expected_model, newdata = df), 1), 1)
  df$Waste_Risk_Liters  <- round(df$Water_Usage_Liters - df$Expected_Usage, 1)
  df$Excess_Pct         <- round(100 * df$Waste_Risk_Liters / df$Expected_Usage, 1)

  df$Waste_Category <- cut(df$Excess_Pct,
                           breaks = c(-Inf, 10, 20, 30, Inf),
                           labels = WASTE_LEVELS)
  df$Waste_Category <- as.character(df$Waste_Category)

  # Z-score of the excess (how unusual is it compared with normal days?)
  normal_rows <- df$Waste_Category == "Normal"
  mu <- mean(df$Excess_Pct[normal_rows])
  sdv <- sd(df$Excess_Pct[normal_rows])
  df$Z_Score <- round((df$Excess_Pct - mu) / sdv, 2)

  # Flag: High Consumption or Possible Water Wastage
  df$Is_Anomaly <- df$Waste_Category %in% c("High Consumption", "Possible Water Wastage")

  # Consecutive days with more than 20% above expected, per building
  df$Consecutive_Abnormal_Days <- ave(as.integer(df$Excess_Pct > 20), df$Building,
                                      FUN = count_consecutive)

  df <- df[order(df$Date, df$Building), ]
  rownames(df) <- NULL
  df
}

# ---- Step 4: simple validation figures (printed in pipeline) -
summarise_detection <- function(df) {
  normal_pct <- df$Excess_Pct[df$Waste_Category == "Normal"]
  noise_sd <- sd(df$Excess_Pct[df$Excess_Pct <= 10])
  list(
    sd_normal_excess_pct = round(noise_sd, 2),
    threshold_10_in_sd   = round(10 / noise_sd, 2),
    category_counts      = table(factor(df$Waste_Category, levels = WASTE_LEVELS)),
    vs_maintenance_log   = table(Leakage_Status = df$Leakage_Status,
                                 Detected = factor(df$Waste_Category, levels = WASTE_LEVELS))
  )
}

# ---- Building-wise ranking ---------------------------------
build_ranking <- function(df) {
  rank_df <- df %>%
    group_by(Building, Building_Type) %>%
    summarise(
      Avg_Usage_Liters     = round(mean(Water_Usage_Liters)),
      Avg_Usage_Per_Person = round(mean(Usage_Per_Person), 1),
      Anomaly_Days         = sum(Is_Anomaly),
      Anomaly_Pct          = round(100 * mean(Is_Anomaly), 1),
      Wastage_Days         = sum(Waste_Category == "Possible Water Wastage"),
      Excess_Liters        = round(sum(pmax(Waste_Risk_Liters, 0)[Is_Anomaly])),
      .groups = "drop"
    )

  rank_df$Waste_Risk_Level <- as.character(cut(rank_df$Anomaly_Pct,
                                               breaks = c(-Inf, 3, 8, Inf),
                                               labels = c("Low", "Medium", "High")))
  rank_df <- rank_df[order(-rank_df$Excess_Liters), ]
  rank_df$Risk_Rank <- seq_len(nrow(rank_df))
  rownames(rank_df) <- NULL
  as.data.frame(rank_df)
}

# ---- Plots --------------------------------------------------
# Actual vs expected for one building
plot_actual_vs_expected <- function(df, building) {
  d <- df[df$Building == building, ]
  flagged <- d[d$Is_Anomaly, ]

  p <- ggplot(d, aes(x = Date)) +
    geom_line(aes(y = Water_Usage_Liters, colour = "Actual"), linewidth = 0.6) +
    geom_line(aes(y = Expected_Usage, colour = "Expected"), linetype = "dashed", linewidth = 0.6)

  if (nrow(flagged) > 0) {
    p <- p + geom_point(data = flagged,
                        aes(y = Water_Usage_Liters, colour = "Flagged (high / wastage)"),
                        size = 2)
  }

  p +
    scale_colour_manual(values = c("Actual" = "steelblue", "Expected" = "black",
                                   "Flagged (high / wastage)" = "red"), name = "") +
    scale_y_continuous(labels = comma) +
    labs(title = paste("Actual vs Expected Water Consumption -", building),
         x = "Date", y = "Water usage (litres per day)") +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"), legend.position = "bottom")
}

# Waste-risk distribution (how many records in each category)
plot_risk_distribution <- function(df) {
  counts <- as.data.frame(table(factor(df$Waste_Category, levels = WASTE_LEVELS)))
  names(counts) <- c("Category", "Records")

  ggplot(counts, aes(x = Category, y = Records, fill = Category)) +
    geom_col(show.legend = FALSE) +
    geom_text(aes(label = Records), vjust = -0.3) +
    scale_fill_manual(values = WASTE_COLORS) +
    labs(title = "Waste-Risk Distribution",
         x = "Waste category", y = "Number of building-day records") +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))
}

# Anomaly detection graph: % above expected for every record
plot_anomaly_detection <- function(df) {
  df$Waste_Category <- factor(df$Waste_Category, levels = WASTE_LEVELS)

  ggplot(df, aes(x = Date, y = Excess_Pct, colour = Waste_Category)) +
    geom_point(size = 1) +
    geom_hline(yintercept = c(10, 20, 30), linetype = "dashed", colour = "grey40") +
    scale_colour_manual(values = WASTE_COLORS, name = "Category", drop = FALSE) +
    facet_wrap(~ Building, ncol = 2) +
    labs(title = "Anomaly Detection: Actual Usage Above Expected",
         subtitle = "Dashed lines = 10%, 20% and 30% above expected",
         x = "Date", y = "Actual above expected (%)") +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold"), legend.position = "bottom")
}

# Building ranking graph
plot_building_ranking <- function(rank_df) {
  ggplot(rank_df, aes(x = reorder(Building, Anomaly_Pct), y = Anomaly_Pct,
                      fill = Waste_Risk_Level)) +
    geom_col() +
    coord_flip() +
    scale_fill_manual(values = c("Low" = "#2e7d32", "Medium" = "#f9a825", "High" = "#c62828"),
                      name = "Waste risk level") +
    labs(title = "Building Ranking by Waste Risk",
         x = "Building", y = "Days flagged as High / Wastage (% of all days)") +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"), legend.position = "bottom")
}

# ---- Save anomaly plots -------------------------------------
save_anomaly_plots <- function(df, rank_df, plots_dir = "plots") {
  dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)
  top_building <- rank_df$Building[1]

  ggsave(file.path(plots_dir, "10_actual_vs_expected.png"),
         plot_actual_vs_expected(df, top_building), width = 10, height = 5, dpi = 150)
  ggsave(file.path(plots_dir, "11_waste_risk_distribution.png"),
         plot_risk_distribution(df), width = 8, height = 5, dpi = 150)
  ggsave(file.path(plots_dir, "12_anomaly_detection.png"),
         plot_anomaly_detection(df), width = 11, height = 10, dpi = 150)
  ggsave(file.path(plots_dir, "13_building_ranking.png"),
         plot_building_ranking(rank_df), width = 8, height = 5, dpi = 150)
  message("Anomaly plots saved in: ", plots_dir)
}
