# ============================================================
# preprocessing.R
# Cleans the raw data and creates new useful columns (features).
# Every step is logged in a small "report" table.
# ============================================================

library(lubridate)

DAY_NAMES <- c("Monday", "Tuesday", "Wednesday", "Thursday",
               "Friday", "Saturday", "Sunday")

# Fill missing numbers with the MEDIAN of the same group.
# Example: a missing student count is replaced by the median student
# count of the same building on the same day of the week.
fill_missing <- function(x, ...) {
  group_median <- ave(x, ..., FUN = function(v) median(v, na.rm = TRUE))
  x[is.na(x)] <- group_median[is.na(x)]
  x[is.na(x)] <- median(x, na.rm = TRUE)   # safety net
  x
}

add_report <- function(report, step, result) {
  rbind(report, data.frame(Step = step, Result = result, stringsAsFactors = FALSE))
}

preprocess_data <- function(raw_path = "data/raw/campus_water_consumption.csv",
                            out_path = "data/processed/campus_water_processed.csv") {

  report <- data.frame(Step = character(), Result = character(), stringsAsFactors = FALSE)

  # ---- 1. Read data ----
  df <- read.csv(raw_path, stringsAsFactors = FALSE)
  report <- add_report(report, "1. Rows read from raw file", as.character(nrow(df)))

  # ---- 2. Date conversion (text -> Date) ----
  df$Date <- as.Date(df$Date, format = "%Y-%m-%d")
  bad_dates <- sum(is.na(df$Date))
  df <- df[!is.na(df$Date), ]
  report <- add_report(report, "2. Rows removed (invalid date)", as.character(bad_dates))

  # ---- 3. Data-type conversion ----
  num_cols <- c("Students", "Staff", "Temperature", "Rainfall",
                "Water_Usage_Liters", "Tank_Level")
  for (col in num_cols) df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
  df$Building       <- trimws(df$Building)
  df$Building_Type  <- trimws(df$Building_Type)
  df$Leakage_Status <- trimws(df$Leakage_Status)
  report <- add_report(report, "3. Numeric columns converted", paste(num_cols, collapse = ", "))

  # ---- 4. Duplicate removal ----
  n_before <- nrow(df)
  df <- df[!duplicated(df), ]                          # identical rows
  df <- df[!duplicated(df[, c("Date", "Building")]), ] # one record per building per day
  report <- add_report(report, "4. Duplicate rows removed", as.character(n_before - nrow(df)))

  # ---- 5. Day of week (calculated from Date, so it is always correct) ----
  df$Day_of_Week <- DAY_NAMES[lubridate::wday(df$Date, week_start = 1)]
  df$Is_Weekend  <- ifelse(df$Day_of_Week %in% c("Saturday", "Sunday"), "Weekend", "Weekday")

  # ---- 6. Basic validation: impossible values become NA ----
  invalid_water <- sum(!is.na(df$Water_Usage_Liters) & df$Water_Usage_Liters <= 0)
  df$Water_Usage_Liters[!is.na(df$Water_Usage_Liters) & df$Water_Usage_Liters <= 0] <- NA
  df$Temperature[!is.na(df$Temperature) & (df$Temperature < 5 | df$Temperature > 50)] <- NA
  df$Rainfall[!is.na(df$Rainfall) & df$Rainfall < 0] <- NA
  df$Tank_Level[!is.na(df$Tank_Level) & (df$Tank_Level < 0 | df$Tank_Level > 100)] <- NA
  df$Students[!is.na(df$Students) & df$Students < 0] <- NA
  df$Staff[!is.na(df$Staff) & df$Staff < 0] <- NA
  report <- add_report(report, "6. Invalid water values (<= 0) set to missing", as.character(invalid_water))

  # ---- 7. Missing-value handling ----
  missing_counts <- sapply(df[num_cols], function(x) sum(is.na(x)))
  missing_text <- paste(names(missing_counts), missing_counts, sep = "=", collapse = ", ")
  report <- add_report(report, "7. Missing values found (before filling)", missing_text)

  # Weather is the same for the whole campus on a date -> use that date's median
  df$Temperature <- fill_missing(df$Temperature, df$Date)
  df$Rainfall    <- fill_missing(df$Rainfall,    df$Date)
  # Others -> median of same building and weekday
  df$Students           <- fill_missing(df$Students, df$Building, df$Day_of_Week)
  df$Staff              <- fill_missing(df$Staff, df$Building, df$Day_of_Week)
  df$Water_Usage_Liters <- fill_missing(df$Water_Usage_Liters, df$Building, df$Day_of_Week)
  df$Tank_Level         <- fill_missing(df$Tank_Level, df$Building)
  report <- add_report(report, "7b. Missing values after filling", as.character(sum(is.na(df[num_cols]))))

  # ---- 8. Feature creation ----
  df$Month        <- month.name[lubridate::month(df$Date)]
  df$Month_Num    <- lubridate::month(df$Date)
  df$Total_People <- df$Students + df$Staff
  df$Usage_Per_Student <- ifelse(df$Students > 0, df$Water_Usage_Liters / df$Students, NA)
  df$Usage_Per_Person  <- df$Water_Usage_Liters / df$Total_People

  df$Temp_Category <- as.character(cut(df$Temperature,
                         breaks = c(-Inf, 24, 28, 32, Inf),
                         labels = c("Cool", "Moderate", "Warm", "Hot")))
  df$Rain_Category <- as.character(cut(df$Rainfall,
                         breaks = c(-Inf, 0, 5, 20, Inf),
                         labels = c("None", "Light", "Moderate", "Heavy")))
  report <- add_report(report, "8. New features created",
                       "Day_of_Week, Is_Weekend, Month, Total_People, Usage_Per_Student, Usage_Per_Person, Temp_Category, Rain_Category")

  # ---- 9. Outlier check (IQR rule, per building) ----
  q1  <- ave(df$Water_Usage_Liters, df$Building, FUN = function(v) quantile(v, 0.25))
  q3  <- ave(df$Water_Usage_Liters, df$Building, FUN = function(v) quantile(v, 0.75))
  iqr <- q3 - q1
  df$IQR_Outlier <- df$Water_Usage_Liters < (q1 - 1.5 * iqr) | df$Water_Usage_Liters > (q3 + 1.5 * iqr)
  report <- add_report(report, "9. IQR outliers flagged (kept, not deleted)", as.character(sum(df$IQR_Outlier)))

  # ---- 10. Save ----
  df <- df[order(df$Date, df$Building), ]
  rownames(df) <- NULL
  report <- add_report(report, "10. Final rows after cleaning", as.character(nrow(df)))

  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  write.csv(df, out_path, row.names = FALSE)
  write.csv(report, file.path(dirname(out_path), "preprocessing_report.csv"), row.names = FALSE)

  list(data = df, report = report)
}
