# ==============================================================================
# FA WSL Scouting & Performance Matrix (Live API Ingestion)
# Designed & Developed by Emily Hollingshead (ejh-analysis)
# ==============================================================================

library(dplyr)
library(ggplot2)
library(StatsBombR)
library(shinythemes)
library(shiny)
library(plotly)
library(DT)

# --- 1. Live StatsBomb API Ingestion (Optimized for Cloud Deployment) ---

competitions <- FreeCompetitions()
available_leagues <- competitions %>%
  select(competition_id, season_id, competition_name, season_name) %>%
  distinct()

print("Available Leagues:")
print(head(available_leagues, 10))



selected_comp <- competitions %>%
  filter(competition_name == "FA Women's Super League" & season_name == "2020/2021")

live_matches <- FreeMatches(selected_comp)
total_live_matches <- nrow(live_matches)

# Ingest player analytics dataset
players_data <- readRDS("players_data.rds")

metric_choices <- c(
  "Non-Penalty xG /90" = "npxG_90",
  "Key Passes (xA) /90" = "xA_90",
  "Passes /90" = "passes_90",
  "Pressures /90" = "pressures_90",
  "Tackles + Interceptions /90" = "tackles_interceptions_90"
)

# tactical_palette <- c("Attacker / Midfielder" = "#2563eb")


# 2. Shiny User Interface (UI)

ui <- fluidPage(
  theme = shinytheme("flatly"),
  
  titlePanel(
    div(
      h2("StatsBomb Open Data — Player Scouting & Metric Explorer", style = "font-weight: 700; color: #1e293b;"),
      h5("EJH-Analytics Portfolio Project: WSL Data | Built with R Shiny, ggplot2 & Plotly", style = "color: #64748b; margin-bottom: 25px;")
    )
  ),
  
  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("Filter & Controls", style = "font-weight: 600;"),
      hr(),
      
      selectInput(
        inputId = "selected_position",
        label = "Filter by Position:",
        choices = c("All Positions", sort(unique(players_data$position))),
        selected = "All Positions"
      ),
      
      selectInput(
        inputId = "x_metric",
        label = "X-Axis Metric:",
        choices = metric_choices,
        selected = "passes_90"
      ),
      
      selectInput(
        inputId = "y_metric",
        label = "Y-Axis Metric:",
        choices = metric_choices,
        selected = "xA_90"
      ),
      
      sliderInput(
        inputId = "min_minutes",
        label = "Minimum Minutes Played:",
        min = floor(min(players_data$minutes_played)),
        max = ceiling(max(players_data$minutes_played)),
        value = floor(min(players_data$minutes_played)), # Uses actual min (~404)
        step = 50
      ),
      
      hr(),
      helpText("Hover over points on the Metric Scatter Matrix tab to view player details."),
      br(),
      
      # Clean StatsBomb & Hudl Attribution Badge
      div(
        style = "text-align: center; padding-top: 15px; border-top: 1px solid #e2e8f0; margin-top: 15px;",
        tags$a(
          href = "https://statsbomb.com/",
          target = "_blank",
          style = "display: inline-block; padding: 6px 14px; background-color: #1e293b; color: #ffffff; border-radius: 6px; font-size: 11px; font-weight: 600; text-decoration: none; letter-spacing: 0.5px; margin-bottom: 8px;",
          "STATSBOMB OPEN DATA"
        ),
        p(
          style = "font-size: 11px; color: #94a3b8; line-height: 1.4; margin: 0;",
          "Match event data provided courtesy of ",
          tags$a(href = "https://statsbomb.com/", target = "_blank", "StatsBomb"),
          " (part of Hudl).", br(),
          "Used under the StatsBomb Open Data Terms of Use."
        )
      )
    ), # End sidebarPanel
    
    mainPanel(
      width = 9,
      tabsetPanel(
        type = "tabs",
        
        tabPanel(
          "Metric Scatter Matrix",
          br(),
          plotlyOutput("scatter_plot", height = "650px"),
          br(),
          wellPanel(
            h5("Tactical Takeaway:", style = "font-weight: 700; color: #0f172a;"),
            p("Players situated in the top-right quadrant exhibit high efficiency across both selected metrics, highlighting elite creators or dual-threat performers.", style = "margin: 0; font-size: 13px;")
          )
        ),
        
        tabPanel(
          "Raw Player Index",
          br(),
          DTOutput("player_table")
        )
      )
    ) # End mainPanel
  ), # End sidebarLayout
  
  hr(style = "margin-top: 40px; border-color: #e2e8f0;"),
  
  # Footer placed globally across bottom of fluidPage
  div(
    style = "text-align: center; padding: 15px 0 25px 0; color: #64748b; font-size: 12px;",
    p(
      style = "margin-bottom: 4px;",
      "Designed & Developed by ",
      tags$strong("Emily Hollingshead"), 
      " (", tags$a(href = "https://github.com/ejh-analysis", target = "_blank", "ejh-analysis"), ")"
    ),
    p(
      style = "margin: 0; font-size: 11px; color: #94a3b8;",
      "FA WSL 2020/21 Analytics | Built with R Shiny, ggplot2 & Plotly | Open Source Portfolio Project"
    )
  )
)

# --- 3. Shiny Server ---
server <- function(input, output, session) {
  
  filtered_data <- reactive({
    df <- players_data %>% filter(minutes_played >= input$min_minutes)
    if (input$selected_position != "All Positions") {
      df <- df %>% filter(position == input$selected_position)
    }
    df
  })
  
  output$scatter_plot <- renderPlotly({
    req(nrow(filtered_data()) > 0)
    
    df <- filtered_data() %>%
      mutate(
        hover_text = paste0(
          "<b>", player_name, "</b> (", team_name, ")<br>",
          "Position: ", position, "<br>",
          "Minutes: ", round(minutes_played, 0), "<br>",
          names(metric_choices)[metric_choices == input$x_metric], ": ", .data[[input$x_metric]], "<br>",
          names(metric_choices)[metric_choices == input$y_metric], ": ", .data[[input$y_metric]]
        )
      )
    
    p <- ggplot(df, aes(
      x = .data[[input$x_metric]], 
      y = .data[[input$y_metric]],
      text = hover_text
    )) +
      geom_point(aes(color = team_name, size = minutes_played), alpha = 0.75) +
      scale_size_continuous(range = c(2.5, 7), guide = "none") +
      theme_minimal(base_family = "sans") +
      labs(
        x = names(metric_choices)[metric_choices == input$x_metric],
        y = names(metric_choices)[metric_choices == input$y_metric]
      ) +
      theme(
        axis.title = element_text(face = "bold", size = 11),
        legend.title = element_blank()
      )
    
    ggplotly(p, tooltip = "text") %>%
      layout(
        legend = list(
          orientation = "h",
          x = 0,
          y = -0.2,
          font = list(size = 9),
          itemsizing = "constant"
        ),
        margin = list(b = 100)
      )
  })
    
  
  output$player_table <- renderDT({
    filtered_data() %>%
      select(player_name, team_name, position, minutes_played, .data[[input$x_metric]], .data[[input$y_metric]]) %>%
      rename(
        "Player" = player_name,
        "Team" = team_name,
        "Position" = position,
        "Minutes" = minutes_played
      ) %>%
      mutate(Minutes = round(Minutes, 0))
  }, options = list(pageLength = 10, scrollX = TRUE))
}

# --- 4. Launch App ---
shinyApp(ui = ui, server = server)

