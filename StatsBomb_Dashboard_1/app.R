library(dplyr)
library(ggplot2)
library(StatsBombR)
library(shinythemes)
library(shiny)
library(ggrepel)
library(plotly)
library(DT)
setwd("C:/OneDrive/Project/football-analytics-portfolio/StatsBomb_Dashboard_1")
competitions <- FreeCompetitions()
available_leagues <- competitions %>%
  select(competition_id, season_id, competition_name, season_name) %>%
  distinct()

print("Available Leagues:")
print(head(available_leagues, 10))



selected_comp <- competitions %>%
  filter(competition_name == "FA Women's Super League" & season_name == "2020/2021")

matches <- FreeMatches(selected_comp)
events <- free_allevents(MatchesDF = matches)

clean_events <- allclean(events)

raw_player_minutes <- get.minutesplayed(clean_events)

print("Extraction Complete! Preview of cleaned events:")
print(head(clean_events %>% select(player.name, team.name, type.name, location.x, location.y)))

min_col <- grep("minute", colnames(raw_player_minutes), value = TRUE, ignore.case = TRUE)[1]
id_col  <- grep("player.*id", colnames(raw_player_minutes), value = TRUE, ignore.case = TRUE)[1]

player_minutes <- raw_player_minutes %>%
  rename(
    player.id = all_of(id_col),
    minutes = all_of(min_col)
  ) %>%
  group_by(player.id) %>%
  summarise(
    total_minutes = sum(as.numeric(minutes), na.rm = TRUE),
    .groups = "drop"
  )

colnames(player_minutes)
head(player_minutes)

player_shots <- clean_events %>%
  filter(type.name == "Shot") %>%
  group_by(player.id) %>%
  summarise(
    Total_Shots = n(),
    Total_xG = sum(shot.statsbomb_xg, na.rm = TRUE),
    .groups = "drop"
  )

player_passes <- clean_events %>%
  filter(type.name == "Pass") %>%
  group_by(player.id) %>%
  summarise(
    Total_Passes = n(),
    # Count key passes that led to shots (Assists / Shot Assists)
    Key_Passes = sum(pass.shot_assist == TRUE | pass.goal_assist == TRUE, na.rm = TRUE),
    .groups = "drop"
  )

player_defensive <- clean_events %>%
  filter(type.name %in% c("Duel", "Interception", "Pressure")) %>%
  group_by(player.id) %>%
  summarise(
    Pressures = sum(type.name == "Pressure", na.rm = TRUE),
    Tackles_Interceptions = sum(type.name %in% c("Duel", "Interception"), na.rm = TRUE),
    .groups = "drop"
  )

player_meta <- clean_events %>%
  filter(!is.na(player.id) & !is.na(player.name)) %>%
  group_by(player.id) %>%
  summarise(
    player.name = dplyr::first(na.omit(player.name)),
    team.name   = dplyr::first(na.omit(team.name)),
    .groups = "drop"
  )

player_stats <- player_minutes %>%
  inner_join(player_meta, by = "player.id") %>%
  left_join(player_shots, by = "player.id") %>%
  left_join(player_passes, by = "player.id") %>%
  left_join(player_defensive, by = "player.id") %>%
  mutate(
    Total_Shots = coalesce(Total_Shots, 0),
    Total_xG = coalesce(Total_xG, 0),
    Total_Passes = coalesce(Total_Passes, 0),
    Key_Passes = coalesce(Key_Passes, 0),
    Pressures = coalesce(Pressures, 0),
    Tackles_Interceptions = coalesce(Tackles_Interceptions, 0)
  ) %>%
  filter(total_minutes >= 400) %>%
  mutate(
    xG_90 = round((Total_xG / total_minutes) * 90, 2),
    Passes_90 = round((Total_Passes / total_minutes) * 90, 1),
    Key_Passes_90 = round((Key_Passes / total_minutes) * 90, 2),
    pressures_90 = round((Pressures / total_minutes) * 90, 1),
    tackles_interceptions_90 = round((Tackles_Interceptions / total_minutes) * 90, 1)
  )

cat("Total qualified players:", nrow(player_stats), "\n")

# Plots
# Static Threat Matrix Plot Export
top_players_plot <- ggplot(player_stats, aes(x = Key_Passes_90, y = xG_90)) +
  geom_point(aes(size = total_minutes, color = team.name), alpha = 0.7) +
  geom_text_repel(
    data = player_stats %>% filter(xG_90 > 0.3 | Key_Passes_90 > 1.8),
    aes(label = player.name),
    size = 3.5,
    max.overlaps = 15
  ) +
  theme_minimal(base_family = "sans") +
  labs(
    title = "FA WSL 2020/21: Offensive Threat Matrix",
    subtitle = "Non-Penalty xG /90 vs. Key Passes /90 (Min. 400 Minutes Played)",
    x = "Key Passes (Shot Assists) per 90",
    y = "Expected Goals (xG) per 90",
    size = "Minutes Played",
    color = "Team",
    caption = "Data Source: StatsBomb Open Data | Portfolio Analytics"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 16, color = "#0f172a"),
    plot.subtitle = element_text(size = 11, color = "#64748b"),
    axis.title = element_text(face = "bold", size = 11),
    legend.position = "bottom"
  )

# Save high-res asset for repository README
ggsave("wsl_offensive_threat_matrix.png", plot = top_players_plot, width = 10, height = 7, dpi = 300)

# --- Football Analytics Portfolio: Player Scouting & Metric Explorer Dashboard ---

# Preparation for dashboard
player_positions <- clean_events %>%
  filter(!is.na(player.id) & !is.na(position.name)) %>%
  group_by(player.id) %>%
  summarise(
    position = dplyr::first(na.omit(position.name)),
    .groups = "drop"
  )

players_data <- player_stats %>%
  left_join(player_positions, by = "player.id") %>%
  transmute(
    player_name = player.name,
    team_name = team.name,
    position = coalesce(position, "Attacker / Midfielder"),
    minutes_played = total_minutes,
    npxG_90 = xG_90,
    xA_90 = Key_Passes_90,
    passes_90 = Passes_90,
    pressures_90 = pressures_90,
    tackles_interceptions_90 = tackles_interceptions_90
  )

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

# --- 5. Shiny Server ---
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

# --- 6. Launch App ---
shinyApp(ui = ui, server = server)

