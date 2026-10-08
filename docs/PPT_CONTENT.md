# 10-Slide Presentation Content

**Slide 1 - Title**
Campus Water Waste Detection and Consumption Prediction Using R
Your name | Roll no | B.Tech AI & Data Science (2nd year) | Guide name | College

**Slide 2 - Problem**
- Campuses use thousands of litres of water every day
- Leaks and careless use are noticed late
- No comparison of "should use" vs "actually used"
- No forecast of future demand

**Slide 3 - Existing System**
- Manual meter reading and monthly bills
- Action only after visible leakage or complaints
- No building-wise ranking, no prediction

**Slide 4 - Proposed System**
- Expected usage + Actual usage + Anomaly detection + Prediction + Waste risk
- Flags: Normal, Moderate, High, Possible Water Wastage
- Rule-based recommendation: "Possible leakage/wastage - physical inspection recommended"
- Shiny dashboard

**Slide 5 - Objectives**
1. Analyse campus and building consumption
2. Calculate expected consumption
3. Detect abnormal usage / waste risk
4. Predict tomorrow and next 7 days
5. Rank buildings needing attention
6. Find factors affecting usage

**Slide 6 - Architecture / Workflow**
Data -> Preprocessing -> Features -> Train/Test split -> Linear Regression + Random Forest -> Evaluation -> Best model -> Prediction
Expected vs Actual -> Anomaly detection -> Waste category -> Recommendation -> Dashboard

**Slide 7 - Dataset & Features**
- Simulated academic dataset (not real): 8 buildings x 366 days
- Inputs: Students, Staff, Temperature, Rainfall, Day, Building
- Also: Tank level, Leakage status
- Created features: Is_Weekend, Total_People, Usage per student/person, Temperature and Rainfall categories

**Slide 8 - ML Models & Anomaly Detection**
- Expected usage: Linear Regression baseline
- Excess % = (Actual - Expected) / Expected x 100
- Normal <= 10%, Moderate 10-20%, High 20-30%, Wastage > 30%
- Prediction models: Linear Regression vs Random Forest
- Time-based 80/20 split; metrics MAE, RMSE, R-squared; best = lowest RMSE

**Slide 9 - Results / Dashboard**
- Model comparison table [from your output]
- Building ranking table [from your output]
- Actual vs expected graph, anomaly graph, 7-day prediction graph
- Dashboard screenshots: Home, Consumption, Waste Detection, Prediction, Building Analysis

**Slide 10 - Conclusion & Future Scope**
- Early, explainable warning of abnormal water use
- Only flags possible leakage; inspection needed to confirm
- Future: real/IoT meter data, hourly data, weather forecast, Isolation Forest, time-series models, alerts
- Thank you / Questions
