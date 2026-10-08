# ============================================================
# recommendations.R
# Simple rule-based recommendations (if-else rules, no ML).
#
# IMPORTANT: the software only flags POSSIBLE leakage / wastage.
# It cannot confirm a physical leak. Wording always says
# "physical inspection recommended".
# ============================================================

add_recommendations <- function(df) {
  category <- df$Waste_Category
  days     <- df$Consecutive_Abnormal_Days

  df$Recommendation <- ifelse(
    days >= 3,
    paste0("Usage more than 20% above expected for ", days,
           " consecutive days. Possible leakage/wastage detected - physical inspection recommended."),
    ifelse(
      category == "Possible Water Wastage",
      "Check this building for possible leakage or unusual water usage. Possible leakage/wastage detected - physical inspection recommended.",
      ifelse(
        category == "High Consumption",
        "Inspect the building for excessive water usage.",
        ifelse(
          category == "Moderate Usage",
          "Monitor water usage in this building.",
          "Water consumption is within the expected range."
        )
      )
    )
  )
  df
}

# Which buildings need attention? Looks at the last `days` days.
attention_table <- function(df, days = 14) {
  last_date <- max(df$Date)
  recent <- df[df$Date > last_date - days, ]

  result <- do.call(rbind, lapply(split(recent, recent$Building), function(d) {
    d <- d[order(d$Date), ]
    latest <- d[nrow(d), ]
    data.frame(
      Building = latest$Building,
      Abnormal_Days_Recent = sum(d$Is_Anomaly),
      Longest_Abnormal_Streak = max(d$Consecutive_Abnormal_Days),
      Latest_Category = latest$Waste_Category,
      Recommendation = latest$Recommendation,
      stringsAsFactors = FALSE
    )
  }))

  result <- result[order(-result$Abnormal_Days_Recent, -result$Longest_Abnormal_Streak), ]
  rownames(result) <- NULL
  result
}
