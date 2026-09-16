# ==============================================================================
# FA WSL Scouting & Performance Matrix (Live API Ingestion)
# Designed & Developed by Emily Hollingshead (ejh-analysis)
# ==============================================================================
install.packages(c("shiny", "dplyr", "ggplot2", "plotly", "shinythemes", "remotes", "plotly", "DT", "rsconnect", "ggrepel"))
remotes::install_github("statsbomb/StatsBombR")

library(dplyr)
library(ggplot2)
library(StatsBombR)
library(shinythemes)
library(shiny)
library(plotly)
library(DT)
library(ggrepel)

# --- 1. Live StatsBomb API Call (Memory-Safe Architecture) ---
# Query competition and match meta-telemetry live from StatsBomb Open API
competitions <- FreeCompetitions()
selected_comp <- competitions %>%
  filter(competition_name == "FA Women's Super League" & season_name == "2020/2021")

matches <- FreeMatches(selected_comp)
events <- free_allevents(MatchesDF = matches)
clean_events <- allclean(events)


# --- 2. Minutes Played Normalisation ---

raw_minutes <- get.minutesplayed(clean_events)
min_col <- grep("minute", colnames(raw_minutes), value = TRUE, ignore.case = TRUE)[1]
id_col  <- grep("player.*id", colnames(raw_minutes), value = TRUE, ignore.case = TRUE)[1]

player_minutes <- raw_minutes %>%
  rename(player.id = all_of(id_col), minutes = all_of(min_col)) %>%
  group_by(player.id) %>%
  summarise(total_minutes = sum(as.numeric(minutes), na.rm = TRUE), .groups = "drop")

# --- 3. Event Aggregation ---

player_shots <- clean_events %>%
  filter(type.name == "Shot") %>%
  group_by(player.id) %>%
  summarise(Total_xG = sum(shot.statsbomb_xg, na.rm = TRUE), .groups = "drop")

player_passes <- clean_events %>%
  filter(type.name == "Pass") %>%
  group_by(player.id) %>%
  summarise(
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

player_positions <- clean_events %>%
  filter(!is.na(player.id) & !is.na(position.name)) %>%
  group_by(player.id) %>%
  summarise(
    position = dplyr::first(na.omit(position.name)),
    .groups = "drop"
  )

# --- 4. Join and Calculate Per-90 Statistics ---

player_stats <- player_minutes %>%
  inner_join(player_meta, by = "player.id") %>%
  left_join(player_positions, by = "player.id") %>%
  left_join(player_shots, by = "player.id") %>%
  left_join(player_passes, by = "player.id") %>%
  left_join(player_defensive, by = "player.id") %>%
  mutate(across(c(Total_xG, Total_Passes, Key_Passes, Pressures, Tackles_Interceptions), ~ coalesce(.x, 0))) %>%
  filter(total_minutes >= 400) %>%
  mutate(
    xG_90 = round((Total_xG / total_minutes) * 90, 2),
    Passes_90 = round((Total_Passes / total_minutes) * 90, 1),
    Key_Passes_90 = round((Key_Passes / total_minutes) * 90, 2),
    pressures_90 = round((Pressures / total_minutes) * 90, 1),
    tackles_interceptions_90 = round((Tackles_Interceptions / total_minutes) * 90, 1)
  )


# --- 5. Export Dashboard Data Binary (Required by app.R) ---

players_data <- player_stats %>%
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

saveRDS(players_data, file = "players_data.rds")
message("Saved: players_data.rds")

# --- 6. Render High-Resolution Plot for GitHub README ---

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



# --- 6. Export Dashboard Artifacts ---

# Save data binary for instant shinyapps.io loading
ggsave("wsl_offensive_threat_matrix.png", plot = top_players_plot, width = 10, height = 7, dpi = 300)
message("Asset generated successfully: wsl_offensive_threat_matrix.png")

