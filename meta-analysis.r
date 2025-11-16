# Data Analysis Dashboard with Forest Plot
# Compatible with Posit Connect Cloud

library(shiny)
library(ggplot2)
library(dplyr)
library(plotly)
library(DT)
library(readr)

# Conditional loading of forestplot (may not be available on all servers)
if (requireNamespace("forestplot", quietly = TRUE)) {
  library(forestplot)
  FORESTPLOT_AVAILABLE <- TRUE
} else {
  FORESTPLOT_AVAILABLE <- FALSE
}

# Define UI
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      .btn-primary { background-color: #007bff; border-color: #007bff; }
      .sidebar { background-color: #f8f9fa; padding: 15px; }
    "))
  ),
  
  titlePanel("Data Analysis Dashboard with Forest Plot"),
  
  sidebarLayout(
    sidebarPanel(
      width = 3,
      class = "sidebar",
      
      # Data Source Selection
      radioButtons("data_source", "Select Data Source:",
                   choices = c("URL Dataset" = "url",
                               "Upload CSV" = "upload",
                               "Sample Sales Data" = "sales"),
                   selected = "url"),
      
      # URL Input
      conditionalPanel(
        condition = "input.data_source == 'url'",
        textInput("data_url", "Enter CSV URL:",
                  value = "https://raw.githubusercontent.com/HEMANGANI/Enrollment-Forecast/refs/heads/main/test%20data.csv")
      ),
      
      # File Upload
      conditionalPanel(
        condition = "input.data_source == 'upload'",
        fileInput("file_upload", "Choose CSV File",
                  accept = c(".csv"))
      ),
      
      # Load Data Button
      actionButton("load_data", "Load Data", class = "btn-primary", style = "width: 100%;"),
      
      hr(),
      
      # Variable Selection (appears after data is loaded)
      uiOutput("var_selectors"),
      
      hr(),
      
      # Chart Type Selection
      selectInput("chart_type", "Select Chart Type:",
                  choices = c("Bar Chart" = "bar",
                              "Scatter Plot" = "scatter",
                              "Line Chart" = "line",
                              "Box Plot" = "box",
                              "Histogram" = "histogram",
                              "Correlation Heatmap" = "heatmap",
                              "Forest Plot" = "forest")),
      
      # Additional options for forest plot
      conditionalPanel(
        condition = "input.chart_type == 'forest'",
        checkboxInput("show_ci", "Show Confidence Intervals", TRUE),
        sliderInput("ci_level", "Confidence Level:", 
                    min = 0.8, max = 0.99, value = 0.95, step = 0.01)
      )
    ),
    
    mainPanel(
      width = 9,
      
      tabsetPanel(
        id = "main_tabs",
        
        tabPanel("Data Preview",
                 br(),
                 DTOutput("data_table")),
        
        tabPanel("Summary Statistics",
                 br(),
                 verbatimTextOutput("summary_stats")),
        
        tabPanel("Visualization",
                 br(),
                 uiOutput("plot_output")),
        
        tabPanel("Metadata",
                 br(),
                 verbatimTextOutput("metadata_info"))
      )
    )
  )
)

# Define Server
server <- function(input, output, session) {
  
  # Reactive value to store data
  data <- reactiveVal(NULL)
  
  # Generate sample sales data
  generate_sales_data <- function() {
    set.seed(123)
    data.frame(
      Product = rep(c("Product A", "Product B", "Product C", "Product D"), each = 50),
      Region = rep(c("North", "South", "East", "West"), 50),
      Sales = round(rnorm(200, mean = 5000, sd = 1500), 2),
      Quantity = sample(10:100, 200, replace = TRUE),
      Revenue = round(rnorm(200, mean = 15000, sd = 5000), 2),
      Profit = round(rnorm(200, mean = 3000, sd = 1000), 2),
      Month = sample(1:12, 200, replace = TRUE),
      Year = sample(2022:2024, 200, replace = TRUE),
      stringsAsFactors = FALSE
    )
  }
  
  # Load data based on source
  observeEvent(input$load_data, {
    tryCatch({
      if (input$data_source == "url") {
        req(input$data_url)
        df <- read_csv(input$data_url, show_col_types = FALSE)
        data(df)
        showNotification("Data loaded successfully from URL!", type = "message")
      } else if (input$data_source == "upload") {
        req(input$file_upload)
        df <- read_csv(input$file_upload$datapath, show_col_types = FALSE)
        data(df)
        showNotification("Data uploaded successfully!", type = "message")
      } else if (input$data_source == "sales") {
        df <- generate_sales_data()
        data(df)
        showNotification("Sample sales data loaded!", type = "message")
      }
    }, error = function(e) {
      showNotification(paste("Error loading data:", e$message), type = "error")
    })
  })
  
  # Dynamic variable selectors
  output$var_selectors <- renderUI({
    req(data())
    df <- data()
    
    numeric_vars <- names(df)[sapply(df, is.numeric)]
    all_vars <- names(df)
    
    if (length(numeric_vars) == 0) {
      numeric_vars <- all_vars
    }
    
    tagList(
      h4("Select Variables:"),
      selectInput("x_var", "X Variable:", 
                  choices = all_vars, 
                  selected = all_vars[1]),
      selectInput("y_var", "Y Variable:", 
                  choices = numeric_vars, 
                  selected = if(length(numeric_vars) > 0) numeric_vars[1] else NULL),
      selectInput("group_var", "Group/Color Variable:", 
                  choices = c("None", all_vars), 
                  selected = "None"),
      selectInput("forest_var", "Forest Plot Variable:", 
                  choices = numeric_vars, 
                  selected = if(length(numeric_vars) > 0) numeric_vars[1] else NULL)
    )
  })
  
  # Data table output
  output$data_table <- renderDT({
    req(data())
    datatable(data(), 
              options = list(
                pageLength = 10, 
                scrollX = TRUE,
                dom = 'Bfrtip'
              ))
  })
  
  # Summary statistics
  output$summary_stats <- renderPrint({
    req(data())
    summary(data())
  })
  
  # Metadata information
  output$metadata_info <- renderPrint({
    req(data())
    df <- data()
    
    cat("=== DATASET METADATA ===\n\n")
    cat("Dimensions:\n")
    cat(sprintf("  Rows: %d\n", nrow(df)))
    cat(sprintf("  Columns: %d\n", ncol(df)))
    cat("\n")
    
    cat("Column Names:\n")
    for(col in names(df)) {
      cat(sprintf("  - %s\n", col))
    }
    cat("\n")
    
    cat("Data Types:\n")
    for(col in names(df)) {
      cat(sprintf("  %s: %s\n", col, class(df[[col]])[1]))
    }
    cat("\n")
    
    cat("Missing Values:\n")
    missing <- colSums(is.na(df))
    for(col in names(missing)) {
      pct <- 100 * missing[col] / nrow(df)
      cat(sprintf("  %s: %d (%.2f%%)\n", col, missing[col], pct))
    }
    cat("\n")
    
    cat("Numeric Summary:\n")
    numeric_cols <- names(df)[sapply(df, is.numeric)]
    for (col in numeric_cols) {
      vals <- df[[col]]
      cat(sprintf("  %s:\n", col))
      cat(sprintf("    Min    = %.2f\n", min(vals, na.rm = TRUE)))
      cat(sprintf("    Max    = %.2f\n", max(vals, na.rm = TRUE)))
      cat(sprintf("    Mean   = %.2f\n", mean(vals, na.rm = TRUE)))
      cat(sprintf("    Median = %.2f\n", median(vals, na.rm = TRUE)))
      cat(sprintf("    SD     = %.2f\n", sd(vals, na.rm = TRUE)))
    }
  })
  
  # Dynamic plot output
  output$plot_output <- renderUI({
    if (input$chart_type == "forest" && FORESTPLOT_AVAILABLE) {
      plotOutput("forest_plot", height = "600px")
    } else if (input$chart_type == "forest" && !FORESTPLOT_AVAILABLE) {
      div(
        style = "padding: 20px; margin: 20px; background-color: #fff3cd; border: 1px solid #ffc107; border-radius: 5px;",
        h4("Forest Plot Not Available"),
        p("The forestplot package is not installed on this server."),
        p("Please select another chart type or contact the administrator.")
      )
    } else {
      plotlyOutput("main_plot", height = "600px")
    }
  })
  
  # Main plot output
  output$main_plot <- renderPlotly({
    req(data(), input$x_var, input$chart_type)
    
    if (input$chart_type == "forest") {
      return(NULL)
    }
    
    df <- data()
    
    # Handle grouping
    color_var <- if (input$group_var != "None") input$group_var else NULL
    
    # Create plots based on chart type
    p <- tryCatch({
      switch(input$chart_type,
        "bar" = {
          if (!is.null(color_var)) {
            ggplot(df, aes_string(x = input$x_var, fill = color_var)) +
              geom_bar(position = "dodge") +
              theme_minimal() +
              labs(title = paste("Bar Chart of", input$x_var)) +
              theme(axis.text.x = element_text(angle = 45, hjust = 1))
          } else {
            ggplot(df, aes_string(x = input$x_var)) +
              geom_bar(fill = "steelblue") +
              theme_minimal() +
              labs(title = paste("Bar Chart of", input$x_var)) +
              theme(axis.text.x = element_text(angle = 45, hjust = 1))
          }
        },
        
        "scatter" = {
          req(input$y_var)
          if (!is.null(color_var)) {
            ggplot(df, aes_string(x = input$x_var, y = input$y_var, color = color_var)) +
              geom_point(alpha = 0.6, size = 3) +
              theme_minimal() +
              labs(title = paste("Scatter:", input$y_var, "vs", input$x_var))
          } else {
            ggplot(df, aes_string(x = input$x_var, y = input$y_var)) +
              geom_point(alpha = 0.6, size = 3, color = "steelblue") +
              theme_minimal() +
              labs(title = paste("Scatter:", input$y_var, "vs", input$x_var))
          }
        },
        
        "line" = {
          req(input$y_var)
          if (!is.null(color_var)) {
            ggplot(df, aes_string(x = input$x_var, y = input$y_var, 
                                  color = color_var, group = color_var)) +
              geom_line(linewidth = 1) +
              geom_point() +
              theme_minimal() +
              labs(title = paste("Line:", input$y_var, "vs", input$x_var))
          } else {
            # Ensure data is sorted for line plot
            df_sorted <- df[order(df[[input$x_var]]), ]
            ggplot(df_sorted, aes_string(x = input$x_var, y = input$y_var)) +
              geom_line(color = "steelblue", linewidth = 1) +
              geom_point(color = "steelblue") +
              theme_minimal() +
              labs(title = paste("Line:", input$y_var, "vs", input$x_var))
          }
        },
        
        "box" = {
          req(input$y_var)
          if (!is.null(color_var)) {
            ggplot(df, aes_string(x = input$x_var, y = input$y_var, fill = color_var)) +
              geom_boxplot() +
              theme_minimal() +
              labs(title = paste("Box Plot:", input$y_var, "by", input$x_var)) +
              theme(axis.text.x = element_text(angle = 45, hjust = 1))
          } else {
            ggplot(df, aes_string(x = input$x_var, y = input$y_var)) +
              geom_boxplot(fill = "steelblue") +
              theme_minimal() +
              labs(title = paste("Box Plot:", input$y_var, "by", input$x_var)) +
              theme(axis.text.x = element_text(angle = 45, hjust = 1))
          }
        },
        
        "histogram" = {
          if (is.numeric(df[[input$x_var]])) {
            ggplot(df, aes_string(x = input$x_var)) +
              geom_histogram(bins = 30, fill = "steelblue", color = "white") +
              theme_minimal() +
              labs(title = paste("Histogram of", input$x_var))
          } else {
            ggplot(df, aes_string(x = input$x_var)) +
              geom_bar(fill = "steelblue") +
              theme_minimal() +
              labs(title = paste("Count of", input$x_var)) +
              theme(axis.text.x = element_text(angle = 45, hjust = 1))
          }
        },
        
        "heatmap" = {
          numeric_data <- df[sapply(df, is.numeric)]
          if (ncol(numeric_data) > 1) {
            cor_matrix <- cor(numeric_data, use = "complete.obs")
            cor_df <- as.data.frame(as.table(cor_matrix))
            names(cor_df) <- c("Var1", "Var2", "Correlation")
            
            ggplot(cor_df, aes(Var1, Var2, fill = Correlation)) +
              geom_tile() +
              scale_fill_gradient2(low = "blue", mid = "white", high = "red", 
                                   midpoint = 0, limits = c(-1, 1)) +
              theme_minimal() +
              theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
              labs(title = "Correlation Heatmap")
          } else {
            ggplot() + 
              annotate("text", x = 0.5, y = 0.5, 
                       label = "Need 2+ numeric variables", size = 6) +
              theme_void()
          }
        }
      )
    }, error = function(e) {
      ggplot() + 
        annotate("text", x = 0.5, y = 0.5, 
                 label = paste("Error:", e$message), size = 5) +
        theme_void()
    })
    
    ggplotly(p)
  })
  
  # Forest plot output
  output$forest_plot <- renderPlot({
    req(data(), input$chart_type == "forest", input$forest_var, FORESTPLOT_AVAILABLE)
    
    df <- data()
    var <- input$forest_var
    
    tryCatch({
      # Create forest plot data
      if (input$group_var != "None" && input$group_var %in% names(df)) {
        group_var <- input$group_var
        
        forest_data <- df %>%
          group_by(across(all_of(group_var))) %>%
          summarise(
            mean = mean(.data[[var]], na.rm = TRUE),
            sd = sd(.data[[var]], na.rm = TRUE),
            n = n(),
            .groups = "drop"
          ) %>%
          mutate(
            se = sd / sqrt(n),
            ci_lower = mean - qnorm((1 + input$ci_level) / 2) * se,
            ci_upper = mean + qnorm((1 + input$ci_level) / 2) * se
          )
        
        # Create forest plot
        forestplot(
          labeltext = as.matrix(forest_data[[group_var]]),
          mean = forest_data$mean,
          lower = forest_data$ci_lower,
          upper = forest_data$ci_upper,
          title = paste("Forest Plot:", var, "by", group_var),
          xlab = var,
          col = fpColors(box = "royalblue", line = "darkblue", summary = "royalblue"),
          boxsize = 0.3,
          lineheight = unit(8, "mm"),
          colgap = unit(3, "mm"),
          graphwidth = unit(60, "mm")
        )
      } else {
        # Overall forest plot
        overall_mean <- mean(df[[var]], na.rm = TRUE)
        overall_sd <- sd(df[[var]], na.rm = TRUE)
        overall_n <- sum(!is.na(df[[var]]))
        overall_se <- overall_sd / sqrt(overall_n)
        ci_lower <- overall_mean - qnorm((1 + input$ci_level) / 2) * overall_se
        ci_upper <- overall_mean + qnorm((1 + input$ci_level) / 2) * overall_se
        
        forestplot(
          labeltext = matrix("Overall", ncol = 1),
          mean = overall_mean,
          lower = ci_lower,
          upper = ci_upper,
          title = paste("Forest Plot:", var),
          xlab = var,
          col = fpColors(box = "royalblue", line = "darkblue", summary = "royalblue"),
          boxsize = 0.5
        )
      }
    }, error = function(e) {
      plot(1, type = "n", xlab = "", ylab = "", axes = FALSE)
      text(1, 1, paste("Error creating forest plot:", e$message), cex = 1.2)
    })
  })
}

# Run the application
shinyApp(ui = ui, server = server)
