# ============================================================
# prediction.R
# Machine-learning prediction of water consumption.
#   Model 1: Linear Regression
#   Model 2: Random Forest Regression
# Both are trained on the first 80% of dates and tested on the
# last 20% (a time-based split, because we predict the future).
# The better model (lowest RMSE) is used to forecast the next 7 days.
# ============================================================

library(ggplot2)
library(scales)
library(randomForest)

DAY_NAMES <- c("Monday", "Tuesday", "Wednesday", "Thursday",
               "Friday", "Saturday", "Sunday")

# Columns used by the models.
# Tank_Level and Leakage_Status are NOT used: they are results of
# water use (not causes), so using them would be "data leakage".
ML_FEATURES <- c("Building", "Students", "Staff", "Temperature", "Rainfall", "Day_of_Week")

# ---- Prepare data for the models ---------------------------
prepare_ml_data <- function(df, building_levels, include_target = TRUE) {
  out <- data.frame(
    Building    = factor(df$Building, levels = building_levels),
    Students    = df$Students,
    Staff       = df$Staff,
    Temperature = df$Temperature,
    Rainfall    = df$Rainfall,
    Day_of_Week = factor(df$Day_of_Week, levels = DAY_NAMES)
  )
  if (include_target) out$Water_Usage_Liters <- df$Water_Usage_Liters
  out
}

# ---- Time-based train/test split ---------------------------
split_train_test <- function(df, train_frac = 0.8) {
  dates  <- sort(unique(df$Date))
  cutoff <- dates[floor(length(dates) * train_frac)]
  list(train = df[df$Date <= cutoff, ],
       test  = df[df$Date >  cutoff, ],
       cutoff = cutoff)
}

# ---- Metrics ------------------------------------------------
mae_fn  <- function(actual, pred) mean(abs(actual - pred))
rmse_fn <- function(actual, pred) sqrt(mean((actual - pred)^2))
r2_fn   <- function(actual, pred) 1 - sum((actual - pred)^2) / sum((actual - mean(actual))^2)

evaluate_model <- function(actual, pred) {
  data.frame(MAE  = round(mae_fn(actual, pred), 2),
             RMSE = round(rmse_fn(actual, pred), 2),
             R2   = round(r2_fn(actual, pred), 4))
}

# ---- Models -------------------------------------------------
fit_linear_model <- function(train_ml) {
  lm(Water_Usage_Liters ~ ., data = train_ml)
}

fit_rf_model <- function(train_ml, ntree = 300) {
  set.seed(42)
  randomForest(Water_Usage_Liters ~ ., data = train_ml, ntree = ntree, importance = TRUE)
}

# ---- Forecast the next days --------------------------------
# Assumptions for future days (we cannot know them in advance):
#   * Students/Staff: average of the same building and weekday
#     over the last 8 weeks
#   * Temperature and Rainfall: average of the last 14 days
forecast_future <- function(model, df, building_levels, horizon = 7) {
  last_date    <- max(df$Date)
  future_dates <- last_date + seq_len(horizon)

  recent  <- df[df$Date > last_date - 56, ]
  profile <- aggregate(cbind(Students, Staff) ~ Building + Day_of_Week, data = recent, FUN = mean)

  last14      <- df[df$Date > last_date - 14, ]
  temp_future <- mean(last14$Temperature)
  rain_future <- mean(last14$Rainfall)

  grid <- data.frame(
    Date     = rep(future_dates, times = length(building_levels)),
    Building = rep(building_levels, each = horizon),
    stringsAsFactors = FALSE
  )
  grid$Day_of_Week <- DAY_NAMES[lubridate::wday(grid$Date, week_start = 1)]
  grid <- merge(grid, profile, by = c("Building", "Day_of_Week"), all.x = TRUE)
  grid$Students[is.na(grid$Students)] <- mean(recent$Students)
  grid$Staff[is.na(grid$Staff)]       <- mean(recent$Staff)
  grid$Temperature <- temp_future
  grid$Rainfall    <- rain_future
  grid <- grid[order(grid$Building, grid$Date), ]

  grid_ml <- prepare_ml_data(grid, building_levels, include_target = FALSE)
  grid$Predicted_Usage_Liters <- round(pmax(predict(model, newdata = grid_ml), 0))

  by_building <- grid[, c("Date", "Building", "Day_of_Week", "Predicted_Usage_Liters")]

  total <- aggregate(Predicted_Usage_Liters ~ Date, data = by_building, FUN = sum)
  total$Day_of_Week <- DAY_NAMES[lubridate::wday(total$Date, week_start = 1)]
  total <- total[order(total$Date), c("Date", "Day_of_Week", "Predicted_Usage_Liters")]
  rownames(total) <- NULL
  rownames(by_building) <- NULL

  list(by_building = by_building, total = total)
}

# ---- Whole prediction stage --------------------------------
run_prediction_stage <- function(df, horizon = 7) {
  building_levels <- sort(unique(df$Building))

  sp       <- split_train_test(df, 0.8)
  train_ml <- prepare_ml_data(sp$train, building_levels)
  test_ml  <- prepare_ml_data(sp$test,  building_levels)

  lm_model <- fit_linear_model(train_ml)
  rf_model <- fit_rf_model(train_ml)

  lm_pred <- predict(lm_model, newdata = test_ml)
  rf_pred <- predict(rf_model, newdata = test_ml)

  metrics <- rbind(
    data.frame(Model = "Linear Regression", evaluate_model(test_ml$Water_Usage_Liters, lm_pred)),
    data.frame(Model = "Random Forest",     evaluate_model(test_ml$Water_Usage_Liters, rf_pred))
  )
  best_model_name <- metrics$Model[which.min(metrics$RMSE)]

  # Re-train the best model on ALL data before forecasting
  full_ml <- prepare_ml_data(df, building_levels)
  final_model <- if (best_model_name == "Random Forest") fit_rf_model(full_ml) else fit_linear_model(full_ml)

  forecast <- forecast_future(final_model, df, building_levels, horizon)

  test_results <- data.frame(
    Date = sp$test$Date, Building = sp$test$Building,
    Actual = test_ml$Water_Usage_Liters,
    Linear_Regression = round(lm_pred), Random_Forest = round(rf_pred)
  )

  list(metrics = metrics, best_model_name = best_model_name,
       lm_model = lm_model, rf_model = rf_model, final_model = final_model,
       test_results = test_results, forecast = forecast,
       train_end = sp$cutoff, n_train = nrow(sp$train), n_test = nrow(sp$test))
}

# ---- Plots --------------------------------------------------
# Actual vs predicted on the TEST data for both models
plot_model_comparison <- function(test_results) {
  n <- nrow(test_results)
  long <- data.frame(
    Actual    = rep(test_results$Actual, 2),
    Predicted = c(test_results$Linear_Regression, test_results$Random_Forest),
    Model     = rep(c("Linear Regression", "Random Forest"), each = n)
  )
  ggplot(long, aes(x = Actual, y = Predicted)) +
    geom_point(alpha = 0.4, colour = "steelblue", size = 1) +
    geom_abline(slope = 1, intercept = 0, colour = "red", linetype = "dashed") +
    facet_wrap(~ Model) +
    scale_x_continuous(labels = comma) + scale_y_continuous(labels = comma) +
    labs(title = "Actual vs Predicted Water Usage (Test Data)",
         subtitle = "Points close to the red line = good predictions",
         x = "Actual usage (litres per day)", y = "Predicted usage (litres per day)") +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))
}

# Future prediction graph.  history / future: data frames with Date, Usage_Liters
plot_future <- function(history, future, title = "Future Water Consumption Prediction") {
  ggplot() +
    geom_line(data = history, aes(x = Date, y = Usage_Liters, colour = "Actual (history)"),
              linewidth = 0.8) +
    geom_line(data = future, aes(x = Date, y = Usage_Liters, colour = "Predicted"),
              linewidth = 0.8, linetype = "dashed") +
    geom_point(data = future, aes(x = Date, y = Usage_Liters, colour = "Predicted"), size = 2) +
    scale_colour_manual(values = c("Actual (history)" = "steelblue", "Predicted" = "darkorange"),
                        name = "") +
    scale_y_continuous(labels = comma) +
    labs(title = title, x = "Date", y = "Water usage (litres per day)") +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"), legend.position = "bottom")
}

# Which factors matter most for the Random Forest?
plot_feature_importance <- function(rf_model) {
  imp <- randomForest::importance(rf_model, type = 1)
  imp_df <- data.frame(Factor = rownames(imp), Importance = imp[, 1])

  ggplot(imp_df, aes(x = reorder(Factor, Importance), y = Importance)) +
    geom_col(fill = "steelblue") +
    coord_flip() +
    labs(title = "Factors Affecting Water Consumption (Random Forest)",
         subtitle = "Higher = removing this factor hurts predictions more",
         x = "Factor", y = "Importance (% increase in MSE)") +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))
}

# ---- Save prediction plots ----------------------------------
save_prediction_plots <- function(pred, df, plots_dir = "plots") {
  dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)

  daily <- aggregate(Water_Usage_Liters ~ Date, data = df, FUN = sum)
  names(daily) <- c("Date", "Usage_Liters")
  history <- tail(daily[order(daily$Date), ], 30)
  future  <- pred$forecast$total
  names(future)[names(future) == "Predicted_Usage_Liters"] <- "Usage_Liters"

  ggsave(file.path(plots_dir, "14_model_comparison.png"),
         plot_model_comparison(pred$test_results), width = 10, height = 5, dpi = 150)
  ggsave(file.path(plots_dir, "15_future_prediction.png"),
         plot_future(history, future, "Campus Water Consumption: Next 7 Days Prediction"),
         width = 9, height = 5, dpi = 150)
  ggsave(file.path(plots_dir, "16_feature_importance.png"),
         plot_feature_importance(pred$rf_model), width = 8, height = 5, dpi = 150)
  message("Prediction plots saved in: ", plots_dir)
}
