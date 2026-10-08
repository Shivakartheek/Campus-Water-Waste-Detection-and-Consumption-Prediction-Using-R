# Campus Water Waste Detection and Consumption Prediction Using R

> **Data note:** the dataset in this project is **simulated for academic purposes**. It is NOT real campus data. See "Replacing the data with real campus data" below.

## 1. Introduction
Water is a costly and limited resource. Large campuses (hostels, canteens, labs, sports areas) use thousands of litres every day, and leaks or careless use often go unnoticed. This project analyses campus water consumption using R, detects unusual usage that may indicate wastage or leakage, and predicts future consumption.

## 2. Problem Statement
Campus water bills and tank levels are usually checked manually and only after a problem becomes serious. There is no simple way to compare **what a building should have used today** with **what it actually used**, and no early warning for abnormal usage.

## 3. Objectives
- Analyse how much water the campus and each building consume.
- Estimate the **expected (normal)** consumption using people, building, temperature, rainfall and weekday/weekend.
- Compare **actual vs expected** and flag Normal / Moderate / High / Possible Wastage.
- Predict tomorrow's and the next 7 days' consumption (Linear Regression vs Random Forest).
- Rank buildings by waste risk and give rule-based recommendations.
- Present everything in a simple R Shiny dashboard.

## 4. Proposed Solution
**Expected consumption + Actual consumption + Anomaly detection + Future prediction + Waste risk.**
Anomaly detection (is today abnormal?) and prediction (what will happen next?) are kept as two separate modules.

## 5. Features
- Simulated, reproducible dataset (2,928 building-day records, 8 buildings, 366 days) with normal days, one-day events and multi-day possible-leak periods
- Full preprocessing with a logged report
- 9 EDA graphs + 7 more result graphs saved in `plots/`
- Waste categories based on % above expected usage
- Consecutive-day rule for "physical inspection recommended"
- MAE / RMSE / R-squared comparison table calculated from the data
- 7-day forecast (campus total and per building)
- Shiny dashboard with 5 pages

## 6. Technologies Used
R, RStudio, dplyr, ggplot2, lubridate, randomForest, scales, shiny, DT

## 7. Dataset Description
File: `data/raw/campus_water_consumption.csv` (created by `R/data_generation.R`, seed = 42, dates 2024-01-01 to 2024-12-31).

| Column | Meaning |
|---|---|
| Date | Calendar date |
| Building | Hostel A, Hostel B, Academic Block, Canteen, Laboratory, Administration Block, Library, Sports Block |
| Building_Type | Type of building |
| Students, Staff | People present that day |
| Temperature | Daily temperature (deg C) |
| Rainfall | Daily rainfall (mm) |
| Day | Day name |
| Water_Usage_Liters | Water used that day (target) |
| Tank_Level | End-of-day tank level (%) |
| Leakage_Status | Maintenance log: No Leak / Leak Suspected / Leak Confirmed |

The raw file deliberately contains a few missing values, 3 invalid water values and 12 duplicate rows so preprocessing can be demonstrated. Staff "false alarms" (Leak Suspected on normal days) are included too, so the log is not a perfect answer key.

Features created in preprocessing: Day_of_Week, Is_Weekend, Month, Total_People, Usage_Per_Student, Usage_Per_Person, Temp_Category, Rain_Category, IQR_Outlier.

## 8. System Workflow
```
Data -> Preprocessing -> Feature Engineering -> Train/Test Split
     -> Linear Regression + Random Forest -> Evaluation (MAE, RMSE, R2)
     -> Best model -> Future prediction (7 days)

Cleaned data -> Expected-usage model -> Actual vs Expected
     -> Anomaly detection -> Waste-risk category -> Recommendation -> Dashboard
```

## 9. Algorithms
1. **Expected usage:** Linear Regression `usage ~ Building * Total_People + Building * Temperature + Rainfall + Is_Weekend`, fitted twice (second time without days more than 15% above the first fit, so abnormal days do not distort "normal").
2. **Waste risk:** `Excess % = (Actual - Expected) / Expected x 100`. Normal <= 10%, Moderate 10-20%, High 20-30%, Possible Wastage > 30%. The pipeline prints the natural day-to-day variation of normal days so the 10% limit can be justified statistically. A Z-score and an IQR outlier flag are also provided.
3. **Prediction:** Linear Regression and Random Forest (300 trees) on Building, Students, Staff, Temperature, Rainfall, Day_of_Week. Time-based split: first 80% of dates train, last 20% test. Best model = lowest RMSE, then re-trained on all data for the forecast.
4. **Why Tank_Level and Leakage_Status are not model inputs:** they are consequences of water use; using them would leak the answer into the model.

## 10. Installation
1. Install R (4.1 or newer) and RStudio.
2. Download/unzip this folder (`Campus-Water-Analytics`).
3. Double-click `Campus-Water-Analytics.Rproj` (this sets the correct working folder).
4. In the RStudio console run:
```r
source("requirements/install_packages.R")
```

## 11. How to Run
```r
source("run_pipeline.R")   # runs everything, creates plots, models and result files
```
Then open `app.R` and click **Run App** (or `shiny::runApp()`).
If you skip the pipeline, `app.R` will run it automatically the first time.

## 12. Expected Output
- Console: preprocessing report, category counts, building ranking, model metrics table, 7-day forecast
- `plots/` : 16 PNG graphs
- `models/` : saved models and `model_metrics.csv`
- `data/processed/` : cleaned data, `water_analysis_results.csv`, `building_ranking.csv`, `future_predictions.csv`, etc.
- Dashboard in the browser

All numbers (accuracy, ranking, counts) are calculated from the data when you run the code; none are typed in by hand.

## 13. Folder Structure
```
Campus-Water-Analytics/
|-- app.R                      Shiny dashboard
|-- run_pipeline.R             runs all stages
|-- Campus-Water-Analytics.Rproj
|-- R/
|   |-- data_generation.R
|   |-- preprocessing.R
|   |-- analysis.R             EDA graphs
|   |-- anomaly_detection.R    expected vs actual, waste risk, ranking
|   |-- prediction.R           Linear Regression, Random Forest, forecast
|   `-- recommendations.R
|-- data/raw/  data/processed/
|-- models/  plots/
|-- requirements/install_packages.R
`-- docs/                      report content, PPT content, viva questions
```
(`run_pipeline.R` is the only addition to the structure you requested; it lets you run all stages with one command.)

## 14. Replacing the Data with Real Campus Data
1. Create a CSV with the same column names as above (one row per building per day). `Tank_Level` and `Leakage_Status` may be filled with estimates/"No Leak" if unavailable.
2. Save it as `data/raw/campus_water_consumption.csv` (overwrite the simulated file). The pipeline only generates data when this file is missing.
3. Delete old results (`data/processed/*`, `models/*`) and run `source("run_pipeline.R")`.
4. Dates must be `YYYY-MM-DD` and each building should have one row per day.

## 15. Limitations
- Simulated data: results show the method, not real campus behaviour.
- The system flags **possible** wastage/leakage only; it cannot confirm a physical leak. Physical inspection is always needed.
- Expected usage is a Linear Regression, so it assumes mostly straight-line effects.
- Future forecasts assume recent average weather and normal occupancy; real weather forecasts and academic calendars are not used.
- The 10/20/30% thresholds are rules of thumb; real data may need different values.
- Models were trained on data that includes abnormal days.
- One record per building per day (no hourly data).

## 16. Future Enhancements
- Real campus meter data / IoT water-meter integration
- Hourly data for night-time leak detection
- Weather forecast and exam/holiday calendar as inputs
- Isolation Forest or time-series models (ARIMA/Prophet)
- Email/SMS alerts, per-building thresholds, cost savings estimate
