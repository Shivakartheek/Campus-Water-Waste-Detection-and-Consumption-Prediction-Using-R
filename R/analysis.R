# ============================================================
# analysis.R
# Exploratory Data Analysis (EDA) graphs using ggplot2.
# Each function takes the processed data frame and returns a plot.
# ============================================================

library(dplyr)
library(ggplot2)
library(lubridate)
library(scales)

# Simple common look for all graphs
theme_water <- function() {
  theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"),
          legend.position = "bottom")
}

# Usage_Index = usage / typical (median) usage of the same building.
# 1.0 = typical day. Lets us compare buildings of very different size.
add_usage_index <- function(df) {
  df$Usage_Index <- ave(df$Water_Usage_Liters, df$Building,
                        FUN = function(v) v / median(v))
  df
}

# 1. Daily campus consumption
plot_daily_total <- function(df) {
  daily <- df %>%
    group_by(Date) %>%
    summarise(Total = sum(Water_Usage_Liters), .groups = "drop") %>%
    arrange(Date)
  daily$Avg7 <- as.numeric(stats::filter(daily$Total, rep(1 / 7, 7), sides = 1))

  ggplot(daily, aes(x = Date)) +
    geom_line(aes(y = Total / 1000, colour = "Daily total"), alpha = 0.7) +
    geom_line(aes(y = Avg7 / 1000, colour = "7-day average"), linewidth = 1, na.rm = TRUE) +
    scale_colour_manual(values = c("Daily total" = "steelblue", "7-day average" = "darkred"),
                        name = "") +
    labs(title = "Daily Campus Water Consumption",
         x = "Date", y = "Water usage (kilolitres per day)") +
    theme_water()
}

# 2. Weekly consumption (only complete 7-day weeks)
plot_weekly_total <- function(df) {
  weekly <- df %>%
    mutate(Week_Start = floor_date(Date, "week", week_start = 1)) %>%
    group_by(Week_Start) %>%
    summarise(Total = sum(Water_Usage_Liters), Days = n_distinct(Date), .groups = "drop") %>%
    filter(Days == 7)

  ggplot(weekly, aes(x = Week_Start, y = Total / 1000)) +
    geom_col(fill = "steelblue") +
    labs(title = "Weekly Campus Water Consumption",
         x = "Week starting", y = "Water usage (kilolitres per week)") +
    theme_water()
}

# 3. Monthly consumption
plot_monthly_total <- function(df) {
  monthly <- df %>%
    mutate(Month_Start = floor_date(Date, "month")) %>%
    group_by(Month_Start) %>%
    summarise(Total = sum(Water_Usage_Liters), .groups = "drop")

  ggplot(monthly, aes(x = Month_Start, y = Total / 1000)) +
    geom_col(fill = "steelblue") +
    scale_x_date(date_breaks = "1 month", date_labels = "%b") +
    labs(title = "Monthly Campus Water Consumption",
         x = "Month", y = "Water usage (kilolitres per month)") +
    theme_water()
}

# 4. Average daily consumption by building
plot_building_avg <- function(df) {
  b <- df %>%
    group_by(Building) %>%
    summarise(Avg = mean(Water_Usage_Liters), .groups = "drop")

  ggplot(b, aes(x = reorder(Building, Avg), y = Avg, fill = Building)) +
    geom_col(show.legend = FALSE) +
    coord_flip() +
    scale_y_continuous(labels = comma) +
    labs(title = "Average Daily Water Consumption by Building",
         x = "Building", y = "Average usage (litres per day)") +
    theme_water()
}

# 5. Consumption per student (only buildings that have students)
plot_per_student <- function(df) {
  b <- df %>%
    filter(Students > 0) %>%
    group_by(Building) %>%
    summarise(PerStudent = mean(Usage_Per_Student, na.rm = TRUE), .groups = "drop")

  ggplot(b, aes(x = reorder(Building, PerStudent), y = PerStudent, fill = Building)) +
    geom_col(show.legend = FALSE) +
    coord_flip() +
    labs(title = "Average Water Use per Student",
         subtitle = "Administration Block has no students and is not shown",
         x = "Building", y = "Litres per student per day") +
    theme_water()
}

# 6. Temperature vs consumption
plot_temp_vs_usage <- function(df) {
  ggplot(df, aes(x = Temperature, y = Water_Usage_Liters)) +
    geom_point(alpha = 0.3, colour = "steelblue", size = 1) +
    geom_smooth(method = "lm", se = FALSE, colour = "red", formula = y ~ x) +
    facet_wrap(~ Building, scales = "free_y", ncol = 4) +
    scale_y_continuous(labels = comma) +
    labs(title = "Temperature vs Water Consumption",
         x = "Temperature (degrees C)", y = "Water usage (litres per day)") +
    theme_water()
}

# 7. Rainfall vs consumption
plot_rain_vs_usage <- function(df) {
  ggplot(df, aes(x = Rainfall, y = Water_Usage_Liters)) +
    geom_point(alpha = 0.3, colour = "darkgreen", size = 1) +
    geom_smooth(method = "lm", se = FALSE, colour = "red", formula = y ~ x) +
    facet_wrap(~ Building, scales = "free_y", ncol = 4) +
    scale_y_continuous(labels = comma) +
    labs(title = "Rainfall vs Water Consumption",
         x = "Rainfall (mm per day)", y = "Water usage (litres per day)") +
    theme_water()
}

# 8. Tank level vs consumption (usage index so buildings are comparable)
plot_tank_vs_usage <- function(df) {
  df <- add_usage_index(df)
  ggplot(df, aes(x = Usage_Index, y = Tank_Level)) +
    geom_point(alpha = 0.3, colour = "purple", size = 1) +
    geom_smooth(method = "lm", se = FALSE, colour = "red", formula = y ~ x) +
    labs(title = "Tank Level vs Water Consumption",
         subtitle = "Usage index 1.0 = typical day for that building",
         x = "Usage index (usage / typical usage of the building)",
         y = "End-of-day tank level (%)") +
    theme_water()
}

# 9. Leakage status vs consumption
plot_leak_status <- function(df) {
  df <- add_usage_index(df)
  ggplot(df, aes(x = Leakage_Status, y = Usage_Index, fill = Leakage_Status)) +
    geom_boxplot(show.legend = FALSE) +
    labs(title = "Leakage Status vs Water Consumption",
         subtitle = "Usage index 1.0 = typical day for that building",
         x = "Leakage status (from maintenance log)",
         y = "Usage index") +
    theme_water()
}

# Daily line chart for one building (used in the dashboard)
plot_building_daily <- function(df, building) {
  d <- df[df$Building == building, ]
  ggplot(d, aes(x = Date, y = Water_Usage_Liters)) +
    geom_line(colour = "steelblue") +
    scale_y_continuous(labels = comma) +
    labs(title = paste("Daily Water Consumption -", building),
         x = "Date", y = "Water usage (litres per day)") +
    theme_water()
}

# ---- Save all EDA plots to the plots/ folder ----------------
save_eda_plots <- function(df, plots_dir = "plots") {
  dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)
  save_one <- function(plot, name, w = 9, h = 5) {
    ggsave(file.path(plots_dir, name), plot, width = w, height = h, dpi = 150)
  }
  save_one(plot_daily_total(df),    "01_daily_consumption.png")
  save_one(plot_weekly_total(df),   "02_weekly_consumption.png")
  save_one(plot_monthly_total(df),  "03_monthly_consumption.png")
  save_one(plot_building_avg(df),   "04_building_consumption.png")
  save_one(plot_per_student(df),    "05_usage_per_student.png")
  save_one(plot_temp_vs_usage(df),  "06_temperature_vs_usage.png", 12, 6)
  save_one(plot_rain_vs_usage(df),  "07_rainfall_vs_usage.png", 12, 6)
  save_one(plot_tank_vs_usage(df),  "08_tank_level_vs_usage.png")
  save_one(plot_leak_status(df),    "09_leakage_status_vs_usage.png")
  message("EDA plots saved in: ", plots_dir)
}
