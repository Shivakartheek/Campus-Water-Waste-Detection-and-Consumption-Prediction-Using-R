# ============================================================
# app.R  -  R Shiny dashboard
# Campus Water Waste Detection and Consumption Prediction
#
# Run: open this file in RStudio and click "Run App".
# If the results files do not exist yet, the pipeline is run first.
# NOTE: the data shown is a SIMULATED academic dataset.
# ============================================================

library(shiny)
library(DT)
library(dplyr)
library(ggplot2)
library(lubridate)
library(scales)
library(randomForest)

source("R/analysis.R")
source("R/anomaly_detection.R")
source("R/prediction.R")
source("R/recommendations.R")

# Run the pipeline automatically the first time
if (!file.exists("data/processed/water_analysis_results.csv") ||
    !file.exists("data/processed/future_predictions.csv")) {
  source("run_pipeline.R")
}

# ---- Load results created by run_pipeline.R ----------------
results <- read.csv("data/processed/water_analysis_results.csv", stringsAsFactors = FALSE)
results$Date <- as.Date(results$Date)
results$Waste_Category <- factor(results$Waste_Category, levels = WASTE_LEVELS)
results$Is_Anomaly <- as.logical(results$Is_Anomaly)

ranking <- read.csv("data/processed/building_ranking.csv", stringsAsFactors = FALSE)
attention <- read.csv("data/processed/buildings_needing_attention.csv", stringsAsFactors = FALSE)

future_total <- read.csv("data/processed/future_predictions.csv", stringsAsFactors = FALSE)
future_total$Date <- as.Date(future_total$Date)
future_building <- read.csv("data/processed/future_predictions_by_building.csv", stringsAsFactors = FALSE)
future_building$Date <- as.Date(future_building$Date)

metrics <- read.csv("models/model_metrics.csv", stringsAsFactors = FALSE)
rf_model <- if (file.exists("models/random_forest_model.rds")) readRDS("models/random_forest_model.rds") else NULL

buildings   <- sort(unique(results$Building))
latest_date <- max(results$Date)
min_date    <- min(results$Date)
fmt <- function(x) format(round(x), big.mark = ",")

# Daily campus totals (used in cards and history)
daily_total <- aggregate(Water_Usage_Liters ~ Date, data = results, FUN = sum)
names(daily_total) <- c("Date", "Usage_Liters")
daily_total <- daily_total[order(daily_total$Date), ]

css <- "
.card-row { display: flex; flex-wrap: wrap; gap: 12px; margin-bottom: 15px; }
.card { flex: 1; min-width: 170px; background: #f4f8fb; border-left: 5px solid #2a7fba;
        padding: 12px 15px; border-radius: 4px; }
.card-title { font-size: 13px; color: #555; }
.card-value { font-size: 22px; font-weight: bold; color: #1b4f72; }
.card-small { font-size: 12px; color: #777; }
"

make_card <- function(title, value, small = "") {
  div(class = "card",
      div(class = "card-title", title),
      div(class = "card-value", value),
      div(class = "card-small", small))
}

# ============================ UI ============================
ui <- navbarPage(
  title = "Campus Water Waste Detection & Prediction",
  header = tags$head(tags$style(HTML(css))),

  # ---------- Dashboard Home ----------
  tabPanel("Dashboard Home",
    br(),
    uiOutput("home_cards"),
    fluidRow(
      column(7, plotOutput("home_daily", height = "300px")),
      column(5, h4("Buildings needing attention (last 14 days)"),
                DTOutput("home_attention"))
    ),
    br(),
    p(em("Data note: this dashboard uses a SIMULATED academic dataset, not real campus data. ",
         "The system flags POSSIBLE wastage only; it cannot confirm a physical leak."))
  ),

  # ---------- Consumption Analysis ----------
  tabPanel("Consumption Analysis",
    sidebarLayout(
      sidebarPanel(width = 3,
        dateRangeInput("date_range", "Select date range",
                       start = min_date, end = latest_date,
                       min = min_date, max = latest_date)
      ),
      mainPanel(width = 9,
        fluidRow(column(12, plotOutput("ca_daily", height = "280px"))),
        fluidRow(column(6, plotOutput("ca_weekly", height = "280px")),
                 column(6, plotOutput("ca_monthly", height = "280px"))),
        fluidRow(column(6, plotOutput("ca_building", height = "300px")),
                 column(6, plotOutput("ca_student", height = "300px")))
      )
    )
  ),

  # ---------- Waste Detection ----------
  tabPanel("Waste Detection",
    sidebarLayout(
      sidebarPanel(width = 3,
        selectInput("w_building", "Building", choices = c("All Buildings", buildings)),
        checkboxInput("w_only_abnormal", "Show only High / Wastage records", value = TRUE),
        hr(),
        h5("Highest waste-risk building"),
        textOutput("w_top_building"),
        hr(),
        p("Categories (actual vs expected):"),
        tags$ul(tags$li("Normal: up to +10%"), tags$li("Moderate: +10% to +20%"),
                tags$li("High: +20% to +30%"), tags$li("Possible Wastage: above +30%"))
      ),
      mainPanel(width = 9,
        fluidRow(column(6, plotOutput("w_dist", height = "280px")),
                 column(6, plotOutput("w_ranking", height = "280px"))),
        plotOutput("w_actual_expected", height = "300px"),
        h4("Abnormal records"),
        DTOutput("w_table")
      )
    )
  ),

  # ---------- Prediction ----------
  tabPanel("Prediction",
    br(),
    fluidRow(
      column(5, h4("Model performance (test data)"), tableOutput("p_metrics"),
                textOutput("p_best"),
                p(em("MAE and RMSE are in litres per building per day; lower is better. ",
                     "R2 closer to 1 is better."))),
      column(7, plotOutput("p_future", height = "300px"))
    ),
    fluidRow(
      column(5, h4("Next 7 days - campus total"), tableOutput("p_table")),
      column(7, plotOutput("p_importance", height = "300px"))
    )
  ),

  # ---------- Building Analysis ----------
  tabPanel("Building Analysis",
    sidebarLayout(
      sidebarPanel(width = 3,
        selectInput("b_building", "Select building", choices = buildings)
      ),
      mainPanel(width = 9,
        uiOutput("b_cards"),
        plotOutput("b_daily", height = "260px"),
        plotOutput("b_actual_expected", height = "280px"),
        fluidRow(column(7, plotOutput("b_future", height = "260px")),
                 column(5, h4("Next 7 days"), tableOutput("b_table")))
      )
    )
  )
)

# ========================== SERVER ==========================
server <- function(input, output, session) {

  # ----- Dashboard Home -----
  output$home_cards <- renderUI({
    today_total <- sum(results$Water_Usage_Liters[results$Date == latest_date])
    avg_daily   <- mean(daily_total$Usage_Liters)
    tomorrow    <- future_total$Predicted_Usage_Liters[1]
    top_use     <- ranking$Building[which.max(ranking$Avg_Usage_Liters)]

    div(class = "card-row",
      make_card("Latest Day's Water Usage", paste(fmt(today_total), "L"), format(latest_date)),
      make_card("Average Daily Usage", paste(fmt(avg_daily), "L"), "whole campus"),
      make_card("Predicted Next-Day Usage", paste(fmt(tomorrow), "L"), format(future_total$Date[1])),
      make_card("Number of Anomalies", fmt(sum(results$Is_Anomaly)), "High / Wastage records"),
      make_card("Highest Consumption Building", top_use, "highest average usage")
    )
  })

  output$home_daily <- renderPlot({ plot_daily_total(results) })

  output$home_attention <- renderDT({
    datatable(attention[, c("Building", "Abnormal_Days_Recent", "Latest_Category")],
              colnames = c("Building", "Abnormal days", "Latest status"),
              options = list(dom = "t", pageLength = 8), rownames = FALSE)
  })

  # ----- Consumption Analysis -----
  filtered <- reactive({
    req(input$date_range)
    d <- results[results$Date >= input$date_range[1] & results$Date <= input$date_range[2], ]
    validate(need(nrow(d) > 0, "No data in the selected date range."))
    d
  })

  output$ca_daily    <- renderPlot({ plot_daily_total(filtered()) })
  output$ca_weekly   <- renderPlot({ plot_weekly_total(filtered()) })
  output$ca_monthly  <- renderPlot({ plot_monthly_total(filtered()) })
  output$ca_building <- renderPlot({ plot_building_avg(filtered()) })
  output$ca_student  <- renderPlot({ plot_per_student(filtered()) })

  # ----- Waste Detection -----
  w_data <- reactive({
    d <- results
    if (input$w_building != "All Buildings") d <- d[d$Building == input$w_building, ]
    d
  })

  output$w_top_building <- renderText({
    paste0(ranking$Building[1], " (", ranking$Waste_Risk_Level[1], " risk)")
  })

  output$w_dist    <- renderPlot({ plot_risk_distribution(w_data()) })
  output$w_ranking <- renderPlot({ plot_building_ranking(ranking) })

  output$w_actual_expected <- renderPlot({
    b <- if (input$w_building == "All Buildings") ranking$Building[1] else input$w_building
    plot_actual_vs_expected(results, b)
  })

  output$w_table <- renderDT({
    d <- w_data()
    if (input$w_only_abnormal) d <- d[d$Is_Anomaly, ]
    d <- d[order(d$Date, decreasing = TRUE),
           c("Date", "Building", "Water_Usage_Liters", "Expected_Usage",
             "Excess_Pct", "Waste_Category", "Recommendation")]
    datatable(d, rownames = FALSE,
              colnames = c("Date", "Building", "Actual (L)", "Expected (L)",
                           "Above expected (%)", "Category", "Recommendation"),
              options = list(pageLength = 8, scrollX = TRUE))
  })

  # ----- Prediction -----
  output$p_metrics <- renderTable({ metrics }, digits = 2)

  output$p_best <- renderText({
    paste("Best model (lowest RMSE):", metrics$Model[which.min(metrics$RMSE)])
  })

  output$p_future <- renderPlot({
    fut <- future_total
    names(fut)[names(fut) == "Predicted_Usage_Liters"] <- "Usage_Liters"
    plot_future(tail(daily_total, 30), fut, "Campus Water Consumption: Next 7 Days Prediction")
  })

  output$p_table <- renderTable({
    t <- future_total
    t$Date <- format(t$Date)
    names(t) <- c("Date", "Day", "Predicted Consumption (L)")
    t
  })

  output$p_importance <- renderPlot({
    validate(need(!is.null(rf_model), "Random Forest model file not found."))
    plot_feature_importance(rf_model)
  })

  # ----- Building Analysis -----
  b_data <- reactive({ results[results$Building == input$b_building, ] })

  output$b_cards <- renderUI({
    d <- b_data()
    r <- ranking[ranking$Building == input$b_building, ]
    div(class = "card-row",
      make_card("Average Daily Usage", paste(fmt(mean(d$Water_Usage_Liters)), "L")),
      make_card("Usage per Person", paste(round(mean(d$Usage_Per_Person), 1), "L/person/day")),
      make_card("High / Wastage Days", sum(d$Is_Anomaly), paste0(r$Anomaly_Pct, "% of days")),
      make_card("Waste Risk Level", r$Waste_Risk_Level, paste("Rank", r$Risk_Rank, "of", nrow(ranking)))
    )
  })

  output$b_daily <- renderPlot({ plot_building_daily(results, input$b_building) })
  output$b_actual_expected <- renderPlot({ plot_actual_vs_expected(results, input$b_building) })

  output$b_future <- renderPlot({
    fut <- future_building[future_building$Building == input$b_building, c("Date", "Predicted_Usage_Liters")]
    names(fut) <- c("Date", "Usage_Liters")
    d <- b_data()
    hist_b <- tail(d[order(d$Date), c("Date", "Water_Usage_Liters")], 30)
    names(hist_b) <- c("Date", "Usage_Liters")
    plot_future(hist_b, fut, paste("Next 7 Days Prediction -", input$b_building))
  })

  output$b_table <- renderTable({
    t <- future_building[future_building$Building == input$b_building,
                         c("Date", "Day_of_Week", "Predicted_Usage_Liters")]
    t$Date <- format(t$Date)
    names(t) <- c("Date", "Day", "Predicted (L)")
    t
  })
}

shinyApp(ui, server)
