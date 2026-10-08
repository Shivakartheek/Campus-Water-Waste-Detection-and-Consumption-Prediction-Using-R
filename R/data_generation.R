# ============================================================
# data_generation.R
# Creates a SIMULATED (not real) campus water dataset.
# The data is generated with fixed rules + random noise so that:
#   * normal days look realistic,
#   * some one-day high-usage events exist (e.g. sports meet),
#   * some multi-day "possible leakage" periods exist,
#   * a few data-quality problems exist (missing values,
#     duplicates, invalid values) so preprocessing can be shown.
# A fixed random seed makes the result reproducible.
# ============================================================

library(lubridate)

DAY_NAMES <- c("Monday", "Tuesday", "Wednesday", "Thursday",
               "Friday", "Saturday", "Sunday")

# ---- Settings for every building --------------------------
get_building_settings <- function() {
  data.frame(
    Building = c("Hostel A", "Hostel B", "Academic Block", "Canteen",
                 "Laboratory", "Administration Block", "Library", "Sports Block"),
    Building_Type = c("Hostel", "Hostel", "Academic", "Canteen",
                      "Laboratory", "Administration", "Library", "Sports"),
    Base_Students      = c(420, 360, 1100, 700, 300, 0, 350, 150),
    Base_Staff         = c(10, 8, 45, 18, 22, 50, 12, 14),
    Liters_Per_Student = c(70, 70, 9, 6, 14, 0, 6, 18),
    Liters_Per_Staff   = c(40, 40, 20, 60, 30, 15, 15, 25),
    Fixed_Liters       = c(800, 700, 1500, 1200, 900, 400, 300, 900),  # cleaning, gardening, etc.
    Temp_Coef          = c(0.020, 0.020, 0.012, 0.015, 0.010, 0.010, 0.010, 0.030),
    Rain_Coef          = c(0.002, 0.002, 0.003, 0.003, 0.003, 0.003, 0.003, 0.008),
    stringsAsFactors = FALSE
  )
}

# How busy each building is on Mon, Tue, ..., Sun (1 = normal weekday)
get_day_factors <- function() {
  list(
    "Hostel A"             = c(1, 1, 1, 1, 1, 0.85, 0.85),
    "Hostel B"             = c(1, 1, 1, 1, 1, 0.85, 0.85),
    "Academic Block"       = c(1, 1, 1, 1, 1, 0.25, 0.05),
    "Canteen"              = c(1, 1, 1, 1, 1, 0.70, 0.60),
    "Laboratory"           = c(1, 1, 1, 1, 1, 0.30, 0.05),
    "Administration Block" = c(1, 1, 1, 1, 1, 0.40, 0.05),
    "Library"              = c(1, 1, 1, 1, 1, 0.80, 0.40),
    "Sports Block"         = c(0.9, 0.9, 0.9, 0.9, 0.9, 1.2, 1.1)
  )
}

# How many "possible leakage" periods to create for each building
get_leak_episodes <- function() {
  c("Hostel A" = 3, "Hostel B" = 2, "Academic Block" = 2, "Canteen" = 3,
    "Laboratory" = 2, "Administration Block" = 1, "Library" = 1, "Sports Block" = 1)
}

# ---- Main generator ---------------------------------------
generate_campus_data <- function(seed = 42,
                                 start_date = as.Date("2024-01-01"),
                                 end_date   = as.Date("2024-12-31")) {
  set.seed(seed)

  settings    <- get_building_settings()
  day_factors <- get_day_factors()
  episodes    <- get_leak_episodes()

  dates  <- seq(start_date, end_date, by = "day")
  n_days <- length(dates)
  dow    <- lubridate::wday(dates, week_start = 1)   # 1 = Monday ... 7 = Sunday
  doy    <- lubridate::yday(dates)                   # day of year

  # ---- Campus-wide weather (same for all buildings on a date) ----
  # Temperature: smooth yearly wave (warmest around May) + daily noise
  temperature <- 28 + 6 * sin(2 * pi * (doy - 30) / 365) + rnorm(n_days, 0, 1.8)

  # Rainfall: more likely in monsoon months (Jun-Sep)
  month_num <- lubridate::month(dates)
  rain_prob <- ifelse(month_num %in% 6:9, 0.60,
               ifelse(month_num %in% 10:11, 0.30, 0.07))
  rained   <- runif(n_days) < rain_prob
  rainfall <- ifelse(rained, round(pmin(rexp(n_days, rate = 1 / 12), 80), 1), 0)

  all_rows <- list()

  for (i in seq_len(nrow(settings))) {
    s <- settings[i, ]
    f <- day_factors[[s$Building]][dow]     # activity factor for every date

    # People present
    students <- round(s$Base_Students * f * runif(n_days, 0.96, 1.00))
    staff    <- round(s$Base_Staff    * f * runif(n_days, 0.95, 1.00))
    staff    <- pmax(staff, 2)

    # Normal (expected) water usage in litres
    base_use    <- students * s$Liters_Per_Student +
                   staff * s$Liters_Per_Staff +
                   s$Fixed_Liters * (0.6 + 0.4 * f)
    temp_effect <- 1 + s$Temp_Coef * (temperature - 28)     # hotter -> more water
    rain_effect <- 1 - s$Rain_Coef * pmin(rainfall, 30)     # rainy -> slightly less water
    noise       <- exp(rnorm(n_days, 0, 0.045))             # ~4.5% natural variation
    usage       <- base_use * temp_effect * rain_effect * noise

    status <- rep("No Leak", n_days)

    # ---- Possible-leakage periods (3 to 10 days, +30% to +80%) ----
    leak_mult <- rep(1, n_days)
    n_ep <- episodes[[s$Building]]
    if (n_ep > 0) {
      for (e in seq_len(n_ep)) {
        start <- sample(10:(n_days - 15), 1)
        len   <- sample(3:10, 1)
        idx   <- start:(start + len - 1)
        leak_mult[idx] <- runif(1, 1.30, 1.80) * runif(length(idx), 0.97, 1.03)
        status[idx]    <- sample(c("Leak Suspected", "Leak Confirmed"), 1)
      }
    }

    # ---- One-day high-usage events (functions, sports meet, ...) ----
    event_mult <- rep(1, n_days)
    event_idx  <- which(runif(n_days) < 0.015 & leak_mult == 1)
    event_mult[event_idx] <- runif(length(event_idx), 1.20, 1.40)

    usage <- usage * leak_mult * event_mult

    # ---- Tank level (%) at end of day: heavier use -> lower level ----
    rel_use <- usage / median(usage)
    tank    <- 75 - 25 * (rel_use - 1) + rnorm(n_days, 0, 4)
    tank    <- pmin(pmax(tank, 5), 100)

    all_rows[[i]] <- data.frame(
      Date               = dates,
      Building           = s$Building,
      Building_Type      = s$Building_Type,
      Students           = students,
      Staff              = staff,
      Temperature        = round(temperature, 1),
      Rainfall           = rainfall,
      Day                = DAY_NAMES[dow],
      Water_Usage_Liters = round(usage),
      Tank_Level         = round(tank, 1),
      Leakage_Status     = status,
      stringsAsFactors = FALSE
    )
  }

  data <- do.call(rbind, all_rows)
  data <- data[order(data$Date, data$Building), ]
  rownames(data) <- NULL

  # A few staff "false alarms": leak suspected but usage was normal
  normal_rows <- which(data$Leakage_Status == "No Leak")
  data$Leakage_Status[sample(normal_rows, 6)] <- "Leak Suspected"

  # ---- Add a few data-quality problems on purpose ----
  n <- nrow(data)
  data$Temperature[sample(n, 12)] <- NA
  data$Rainfall[sample(n, 6)]     <- NA
  data$Tank_Level[sample(n, 25)]  <- NA
  data$Students[sample(which(data$Students > 0), 8)] <- NA
  bad <- sample(n, 7)
  data$Water_Usage_Liters[bad[1:4]] <- NA                # missing
  data$Water_Usage_Liters[bad[5:7]] <- c(-150, -80, 0)   # invalid values

  # Exact duplicate rows
  data <- rbind(data, data[sample(n, 12), ])

  data
}

# ---- Generate and save to CSV ------------------------------
generate_and_save_data <- function(path = "data/raw/campus_water_consumption.csv") {
  data <- generate_campus_data()
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write.csv(data, path, row.names = FALSE)
  message("SIMULATED dataset saved: ", path, " (", nrow(data), " rows)")
  message("NOTE: this is a simulated academic dataset, NOT real campus data.")
  invisible(data)
}
