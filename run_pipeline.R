# ============================================================
# run_pipeline.R
# Runs the WHOLE project (everything except the dashboard):
#   Data -> Preprocessing -> EDA -> Expected vs Actual ->
#   Anomaly detection -> Recommendations -> ML models ->
#   Best model -> Future prediction
#
# How to run (RStudio):
#   1. Double-click Campus-Water-Analytics.Rproj
#   2. Open this file and click "Source"   (or type source("run_pipeline.R"))
# ============================================================

if (!file.exists("R/data_generation.R")) {
  stop("Working directory is wrong. Open Campus-Water-Analytics.Rproj in RStudio ",
       "or use setwd() to go to the project folder.")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(lubridate)
  library(randomForest)
  library(scales)
})

for (d in c("data/raw", "data/processed", "models", "plots")) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

source("R/data_generation.R")
source("R/preprocessing.R")
source("R/analysis.R")
source("R/anomaly_detection.R")
source("R/prediction.R")
source("R/recommendations.R")

raw_path <- "data/raw/campus_water_consumption.csv"

# ---- Step 1: Data (generate only if the file does not exist) ----
# If you put your REAL campus data in this file, it will NOT be overwritten.
cat("\n=== STEP 1: Data collection ===\n")
if (!file.exists(raw_path)) {
  generate_and_save_data(raw_path)
} else {
  message("Using existing file: ", raw_path)
}

# ---- Step 2: Preprocessing ----
cat("\n=== STEP 2: Preprocessing ===\n")
pre <- preprocess_data(raw_path, "data/processed/campus_water_processed.csv")
print(pre$report, row.names = FALSE)
df <- pre$data

# ---- Step 3: EDA plots ----
cat("\n=== STEP 3: Exploratory data analysis ===\n")
save_eda_plots(df, "plots")

# ---- Step 4: Expected consumption + anomaly detection ----
cat("\n=== STEP 4: Water waste / anomaly detection ===\n")
expected_model <- fit_expected_model(df)
saveRDS(expected_model, "models/expected_model.rds")

results <- detect_waste(df, expected_model)
results <- add_recommendations(results)          # Step 5: recommendations

det <- summarise_detection(results)
cat("Records in each waste category:\n"); print(det$category_counts)
cat("\nNatural variation of normal days (std dev of % above expected): ",
    det$sd_normal_excess_pct, "%\n", sep = "")
cat("So the 10% 'Normal' limit is about ", det$threshold_10_in_sd,
    " standard deviations above expected.\n", sep = "")
cat("\nDetection vs maintenance log (rows = Leakage_Status, columns = detected category):\n")
print(det$vs_maintenance_log)

rank_df <- build_ranking(results)
cat("\nBuilding ranking (highest waste risk first):\n")
print(rank_df, row.names = FALSE)

write.csv(results, "data/processed/water_analysis_results.csv", row.names = FALSE)
write.csv(rank_df, "data/processed/building_ranking.csv", row.names = FALSE)
write.csv(attention_table(results, 14), "data/processed/buildings_needing_attention.csv", row.names = FALSE)
save_anomaly_plots(results, rank_df, "plots")

# ---- Step 6: Machine learning ----
cat("\n=== STEP 6: Machine learning prediction ===\n")
pred <- run_prediction_stage(df, horizon = 7)
cat("Training records: ", pred$n_train, " (up to ", format(pred$train_end),
    ")   Test records: ", pred$n_test, "\n", sep = "")
cat("\nModel performance on TEST data:\n")
print(pred$metrics, row.names = FALSE)
cat("\nBest model (lowest RMSE): ", pred$best_model_name, "\n", sep = "")

saveRDS(pred$lm_model, "models/linear_regression_model.rds")
saveRDS(pred$rf_model, "models/random_forest_model.rds")
saveRDS(pred$final_model, "models/final_model.rds")
write.csv(pred$metrics, "models/model_metrics.csv", row.names = FALSE)
write.csv(pred$test_results, "data/processed/test_predictions.csv", row.names = FALSE)

# ---- Step 7: Future prediction ----
cat("\n=== STEP 7: Future water consumption (next 7 days) ===\n")
print(pred$forecast$total, row.names = FALSE)
write.csv(pred$forecast$total, "data/processed/future_predictions.csv", row.names = FALSE)
write.csv(pred$forecast$by_building, "data/processed/future_predictions_by_building.csv", row.names = FALSE)
save_prediction_plots(pred, df, "plots")

cat("\n=== DONE ===\n")
cat("Plots     -> plots/\nModels    -> models/\nResults   -> data/processed/\n")
cat("Now start the dashboard: open app.R and click 'Run App'.\n")
