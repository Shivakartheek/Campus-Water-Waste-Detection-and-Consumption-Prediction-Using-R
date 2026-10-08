# Viva Questions and Simple Answers

**1. Why did you select this project?**
Water wastage is a real campus problem, and data analysis can give early warnings. It also lets me combine data cleaning, visualisation, anomaly detection and machine learning in one project.

**2. Why R?**
R is made for statistics and data visualisation. ggplot2 gives clear graphs, randomForest and lm give ready models, and Shiny builds a dashboard without web programming.

**3. Is the dataset real?**
No. It is simulated for academic purposes with fixed rules and random noise (seed 42). It is clearly stated in the README. Real data can replace it using the same column names.

**4. Why did you simulate data?**
Real campus meter data was not available. A simulated set also lets me create known abnormal periods to demonstrate detection.

**5. What is anomaly detection?**
Finding records that do not follow the normal pattern. Here: days when water use is much higher than expected.

**6. How do you detect water wastage?**
I calculate expected usage, compare it with actual usage, and compute Excess % = (Actual - Expected) / Expected x 100. Above 30% is "Possible Water Wastage".

**7. How is expected consumption calculated?**
With a Linear Regression using building, number of people, temperature, rainfall and weekday/weekend. It is trained twice: the second time leaves out days more than 15% above the first estimate, so abnormal days do not spoil the "normal" baseline.

**8. Why Linear Regression for expected usage?**
It is simple, fast and easy to explain: each factor has a clear effect on usage.

**9. What is the difference between expected, actual and predicted usage?**
Actual = what was measured. Expected = what usage should have been on that day, given that day's conditions (used for detection). Predicted = a forecast for future days when actual is not yet known.

**10. Why did you choose 10%, 20% and 30%?**
They are simple, easy-to-explain rules. The pipeline also prints the natural day-to-day variation of normal days, which shows how far above normal variation these limits are. With real data the limits should be tuned.

**11. What is Random Forest?**
An ensemble of many decision trees, each trained on a random sample of the data. The final prediction is the average of all trees. It handles non-linear patterns well.

**12. Why use Linear Regression for prediction too?**
As a simple baseline. Comparing it with Random Forest shows whether the more complex model is really better.

**13. What is MAE?**
Mean Absolute Error: the average size of the prediction error, in litres. Lower is better.

**14. What is RMSE?**
Root Mean Squared Error: like MAE but large errors are punished more. Also in litres. Lower is better.

**15. What is R-squared?**
The share of the variation in water usage explained by the model. Closer to 1 is better; 0 means no better than predicting the average.

**16. Why do you split data into train and test?**
To check the model on data it has not seen. Testing on training data would give over-optimistic results.

**17. Why a time-based split and not a random split?**
We predict the future, so the model should be trained on the past and tested on later dates, like real use.

**18. Which model performed better and why?**
Check `models/model_metrics.csv`: the model with the lower RMSE is selected. Usually Random Forest does better because buildings use water very differently and the relationships are not perfectly straight lines, but I must report what my own run shows.

**19. Why are Tank_Level and Leakage_Status not used as model inputs?**
They are results of water use, not causes. Using them would give the model the answer (data leakage) and make accuracy look falsely high.

**20. How does the future prediction work?**
The best model is re-trained on all data. For the next 7 days I assume students and staff equal the average of the same building and weekday over the last 8 weeks, and temperature and rainfall equal the last 14 days' average. The model then predicts each building and the totals are added.

**21. Can the system confirm a physical leakage?**
No. It only flags *possible* leakage or wastage. A physical inspection is needed to confirm.

**22. What happens if abnormal usage continues for several days?**
If usage is more than 20% above expected for 3 or more consecutive days, the recommendation becomes "Possible leakage/wastage detected - physical inspection recommended".

**23. What preprocessing did you do?**
Date conversion, type conversion, duplicate removal, validation of impossible values, median-based filling of missing values, IQR outlier check and feature creation.

**24. Why fill missing values with the median?**
The median is not affected by extreme values. I use the median of the same building and weekday (or same date for weather).

**25. Why are IQR outliers not deleted?**
High-usage days are exactly what we want to detect. They are only flagged.

**26. What factors affect water consumption in your project?**
Building type, number of people, temperature, rainfall and weekday/weekend. The Random Forest importance graph shows their ranking.

**27. What are the limitations?**
Simulated data, only flags possible leaks, fixed percentage thresholds, daily data only, forecast uses average weather.

**28. How can real campus data be integrated?**
Create a CSV with the same columns, save it as `data/raw/campus_water_consumption.csv`, delete old results and run `run_pipeline.R`.

**29. What is the Shiny dashboard?**
An interactive web page made with R. It has Home cards, Consumption Analysis, Waste Detection, Prediction and Building Analysis pages.

**30. What improvements can be made in the future?**
IoT water meters, hourly data for night-time leak detection, weather forecasts, Isolation Forest, time-series models and automatic alerts.
