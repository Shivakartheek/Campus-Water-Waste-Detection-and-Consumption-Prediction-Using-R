# ------------------------------------------------------------
# install_packages.R
# Run this file ONCE before running the project.
# It installs only the packages that are not already installed.
# ------------------------------------------------------------

packages <- c(
  "dplyr",         # data manipulation (group_by, summarise ...)
  "ggplot2",       # graphs
  "lubridate",     # date handling
  "randomForest",  # Random Forest regression
  "scales",        # nice number formatting on graph axes
  "shiny",         # interactive dashboard
  "DT"             # interactive tables in the dashboard
)

missing_packages <- packages[!(packages %in% rownames(installed.packages()))]

if (length(missing_packages) > 0) {
  message("Installing: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
} else {
  message("All packages are already installed.")
}

# Final check
for (p in packages) {
  ok <- requireNamespace(p, quietly = TRUE)
  message(sprintf("%-14s %s", p, ifelse(ok, "OK", "FAILED - install manually")))
}
