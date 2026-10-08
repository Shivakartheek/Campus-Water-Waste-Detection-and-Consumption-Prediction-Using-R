# Project Report Content
**Campus Water Waste Detection and Consumption Prediction Using R**

*Numbers marked [from output] must be copied from your own run: console output, `models/model_metrics.csv`, `data/processed/building_ranking.csv` and the graphs in `plots/`. Do not type numbers that your run did not produce.*

## 1. Abstract
Water wastage and undetected leakage are common problems in large campuses. This project builds an R-based system that studies campus water consumption, detects unusual usage and predicts future consumption. A simulated academic dataset of eight campus buildings for one year is used. First, the expected water usage of each building is estimated with Linear Regression using the number of people, temperature, rainfall and weekday/weekend. The actual usage is compared with the expected usage, and each record is classified as Normal, Moderate Usage, High Consumption or Possible Water Wastage. Then Linear Regression and Random Forest models are trained to predict daily water consumption and compared using MAE, RMSE and R-squared; the better model forecasts the next seven days. Rule-based recommendations suggest monitoring or physical inspection, and an R Shiny dashboard presents the results. The system only flags possible wastage; it cannot confirm a physical leak.

## 2. Introduction
Water is needed daily in hostels, canteens, laboratories and sports areas. A leaking pipe or an overflowing tank can waste thousands of litres before anyone notices. With data analysis we can learn what normal usage looks like and raise a warning when usage is much higher than normal. R is a popular language for statistics and data visualisation, so it is a good choice for this work.

## 3. Problem Statement
Campus water usage is usually checked manually from bills or meters, so abnormal usage is found late. There is no simple method that compares expected and actual usage for each building and also predicts future demand.

## 4. Existing System
- Manual meter reading and monthly bills
- Staff complaints or visible leakage are the main alert
- No comparison with expected usage, no prediction, no building-wise ranking

## 5. Proposed System
An R-based analytics system with: data cleaning, EDA, expected-usage model, actual-vs-expected anomaly detection, waste-risk categories, ML prediction (Linear Regression and Random Forest), rule-based recommendations and a Shiny dashboard.

## 6. Objectives
1. Analyse campus and building-wise water consumption.
2. Calculate expected consumption.
3. Detect abnormal usage and classify waste risk.
4. Predict tomorrow and next 7 days consumption.
5. Rank buildings that need attention.
6. Identify factors affecting consumption.
7. Provide an easy dashboard.

## 7. Methodology
1. Data collection (simulated dataset, seed 42)
2. Preprocessing: date conversion, type conversion, duplicate removal, validation, missing-value filling, outlier check
3. Feature engineering: Day_of_Week, Is_Weekend, Month, Total_People, Usage_Per_Student, Usage_Per_Person, Temp_Category, Rain_Category
4. EDA with ggplot2
5. Expected-usage model (Linear Regression, trained twice to avoid distortion by abnormal days)
6. Waste risk = Actual - Expected; category from % above expected
7. Time-based train/test split (80% / 20%), Linear Regression and Random Forest
8. Evaluation with MAE, RMSE, R-squared; best model selection
9. 7-day forecast, recommendations, dashboard

## 8. System Architecture
Layers: **Data layer** (raw CSV, processed CSV) -> **Processing layer** (preprocessing.R, analysis.R) -> **Intelligence layer** (anomaly_detection.R, prediction.R, recommendations.R) -> **Presentation layer** (plots, Shiny app.R).
*(Draw this as four boxes connected by arrows.)*

## 9. Data Flow
Raw CSV -> Cleaning and feature creation -> Processed data -> (a) Expected-usage model -> Actual vs expected -> Waste category -> Recommendation -> Results CSV; (b) Train/test split -> Two ML models -> Evaluation -> Best model -> Forecast CSV; Results CSV + Forecast CSV -> Dashboard.

## 10. Algorithms
- **Linear Regression:** fits a straight-line relationship between inputs and water usage. Used for the expected-usage baseline because it is simple to explain, and as ML Model 1.
- **Random Forest:** many decision trees, each trained on a random sample; the average of the trees is the prediction. It can capture non-linear effects (for example different water habits in each building). ML Model 2.
- **Percentage-excess rule:** Excess % = (Actual - Expected) / Expected x 100. Normal <= 10, Moderate 10-20, High 20-30, Possible Wastage > 30.
- **Supporting checks:** Z-score of the excess and the IQR outlier rule.
- **Metrics:** MAE, RMSE, R-squared.

## 11. Dataset Description
Simulated academic dataset (not real data). 8 buildings x 366 days = 2,928 clean records (raw file has 2,940 rows because 12 duplicates were added). Columns: Date, Building, Building_Type, Students, Staff, Temperature, Rainfall, Day, Water_Usage_Liters, Tank_Level, Leakage_Status. It includes weekday/weekend patterns, seasonal temperature, monsoon rainfall, one-day high-usage events and multi-day possible-leak periods. A few missing, invalid and duplicate values were added on purpose for preprocessing.

## 12. Implementation
Language R; packages dplyr, ggplot2, lubridate, randomForest, shiny, DT. Files: `data_generation.R`, `preprocessing.R`, `analysis.R`, `anomaly_detection.R`, `prediction.R`, `recommendations.R`, `run_pipeline.R`, `app.R`. Run `source("run_pipeline.R")` to execute all stages, then run `app.R` for the dashboard. *(Add screenshots of the console output and each dashboard page.)*

## 13. Results
Insert from your own run:
- Preprocessing report table (`data/processed/preprocessing_report.csv`)
- EDA graphs 01-09 (`plots/`)
- Waste-category counts and building ranking [from output]
- Model comparison table (MAE, RMSE, R-squared) and the selected model [from output]
- 7-day prediction table and graph (`plots/15_future_prediction.png`)
- Actual vs expected and anomaly graphs (`plots/10`, `plots/12`)
- Dashboard screenshots

Write what you observe: which building ranks highest in waste risk, which model had lower RMSE, which factors the Random Forest ranks as most important (`plots/16_feature_importance.png`), and how many records in the maintenance log's "Leak Suspected/Confirmed" periods were flagged (console table "Detection vs maintenance log").

## 14. Advantages
- Early warning of abnormal usage; simple and explainable method
- Separates anomaly detection from prediction
- Building-wise ranking helps maintenance staff decide where to inspect first
- Free tools; easy to rerun with real data

## 15. Limitations
- Simulated data; real behaviour may differ
- Only flags possible wastage; cannot confirm a physical leak
- Linear baseline and fixed percentage thresholds
- Forecast assumes average recent weather and normal occupancy
- Daily data only (no hourly or night-flow analysis)

## 16. Future Scope
Real meter/IoT data, hourly data, weather forecast and academic-calendar inputs, Isolation Forest and time-series models, automatic alerts, cost and water-saving estimates.

## 17. Conclusion
The project shows how expected-vs-actual comparison, anomaly detection and machine-learning prediction can work together to monitor campus water use. The Shiny dashboard makes the results easy to read. With real campus data the same pipeline can support practical water management; inspection by maintenance staff is still needed to confirm any leak.

## 18. References
1. R Core Team. *R: A Language and Environment for Statistical Computing.* https://www.r-project.org
2. Wickham, H. *ggplot2: Elegant Graphics for Data Analysis.* Springer.
3. Liaw, A. and Wiener, M. "Classification and Regression by randomForest." *R News*, 2002.
4. Chang, W. et al. *shiny: Web Application Framework for R.* https://shiny.posit.co
5. James, G., Witten, D., Hastie, T., Tibshirani, R. *An Introduction to Statistical Learning.* Springer.
6. Documentation of dplyr, lubridate, DT and scales on CRAN: https://cran.r-project.org
