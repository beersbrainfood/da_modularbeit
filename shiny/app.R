library(shiny)
library(shinyalert)
library(shinydashboard)
library(DT)
library(dplyr)
library(lubridate)
library(tidyr)
library(ggplot2)

# -------------------------------
# Daten laden
# -------------------------------
quality_results <- read.csv("../data/data_quality_report.csv")
sensor_data_all <- read.csv("../data/sensor_daten_buendelt.csv")

# Zeitspalte vorbereiten
sensor_data_all$Zeit <- gsub("Z$", "", sensor_data_all$Zeit)
sensor_data_all$Zeit <- substr(sensor_data_all$Zeit, 1, 23)
sensor_data_all$Zeit <- as.POSIXct(sensor_data_all$Zeit, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")

# Dropdown-Zeitoptionen: 00:00 bis 23:30 im 30-Minuten-Takt
zeit_optionen <- format(seq(
  as.POSIXct("00:00", format = "%H:%M"),
  as.POSIXct("23:30", format = "%H:%M"),
  by = "30 min"
), "%H:%M")

# ------------------------------------------------------------
# Funktion zur Bewertung der Zeitspalte (separat)
# ------------------------------------------------------------
evaluate_quality_time <- function(df, column, time_col = "Zeit") {
  total <- nrow(df)
  col_data <- df[[column]]
  
  # Versuche, Zeitstempel als POSIXct zu parsen
  parsed_times <- suppressWarnings(as.POSIXct(gsub("Z$", "", col_data), format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC"))
  
  # Prüfe, ob alle Zeitstempel gleich formatiert sind (z. B. gleicher String-Länge)
  time_lengths <- nchar(gsub("Z$", "", col_data))
  accuracy <- if (length(unique(time_lengths[!is.na(time_lengths)])) == 1) 1 else 0
  
  completeness <- mean(!is.na(col_data))                     # Anteil nicht-leerer Zeitstempel
  consistency <- mean(!is.na(parsed_times))                  # Anteil korrekt parsebarer Zeitangaben
  timeliness <- NA_real_                                     # Zeit selbst hat keine "Aktualität"
  validity <- mean(!tolower(as.character(col_data)) %in% c("err", "error", "nan", "na", ""), na.rm = TRUE)
  uniqueness <- if (total > 0) length(unique(col_data)) / total else NA_real_
  
  return(c(accuracy, completeness, consistency, timeliness, validity, uniqueness))
}

# ------------------------------------------------------------
# Funktion zur Qualitätsbewertung einer Messspalte
# ------------------------------------------------------------
evaluate_quality <- function(df, column, time_col = "time") {
  total <- nrow(df)
  col_data <- df[[column]]
  col_data_char <- as.character(col_data)
  col_data_num <- suppressWarnings(as.numeric(col_data))
  
  # Vordefinierte Wertebereiche für bestimmte Messgrößen zur Bewertung der Genauigkeit
  ranges <- list(
    Temperatur = c(0, 50),
    Temperatur_C = c(0, 50),
    Luftfeuchtigkeit = c(0, 85),
    Luftfeuchte = c(0, 85),
    CO2 = c(0, 10000),
    Licht = c(4, 2000),
    Bewegung = c(0, 256)
  )
  
  # Prüfe, ob Werte innerhalb zulässiger Bereiche liegen (Accuracy)
  if (column %in% names(ranges)) {
    limits <- ranges[[column]]
    validity <- mean(!is.na(col_data_num) & col_data_num >= limits[1] & col_data_num <= limits[2], na.rm = TRUE)
  } else {
    validity <- mean(!is.na(col_data_num) & col_data_num > -1e6 & col_data_num < 1e6, na.rm = TRUE)
  }
  
  completeness <- mean(!is.na(col_data))                     # Nicht-NA-Anteil
  format_patterns <- gsub("[0-9]", "d", col_data_char)
  format_patterns <- gsub("[^d]", "_", format_patterns)
  mode_pattern <- names(sort(table(format_patterns), decreasing = TRUE))[1]
  consistency <- mean(format_patterns == mode_pattern, na.rm = TRUE)
  
  # Bewertung der zeitlichen Abstände (nur bei Vorhandensein einer Zeitspalte)
  if (time_col %in% names(df)) {
    times <- as.POSIXct(gsub("Z$", "", df[[time_col]]), format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")
    diffs <- diff(times)
    std <- sd(as.numeric(diffs, units = "secs"), na.rm = TRUE)
    timeliness <- ifelse(length(diffs) > 1 && !is.na(std) && std < 600, 1, 0)
  } else {
    timeliness <- NA_real_
  }
  
  
  uniqueness <- if (total > 0) length(unique(col_data)) / total else NA_real_
  
  return(c( completeness, consistency, timeliness, validity, uniqueness))
}

# ------------------------------------------------------------
# Hauptfunktion zur Datenqualitätsanalyse aller Sensoren
# ------------------------------------------------------------
check_data_quality <- function(sensor_tabellen, time_col = "Zeit", include_uniqueness = FALSE) {
  # Zeit bekommt immer alle 6 Dimensionen
  dimensions_Zeit <- c("Accuracy", "Completeness", "Consistency", "Timeliness", "Validity", "Uniqueness")
  
  # Für andere Spalten optional ohne Uniqueness
  all_dimensions <- c("Completeness", "Consistency", "Timeliness", "Validity", "Uniqueness")
  dimensions <- if (include_uniqueness) all_dimensions else setdiff(all_dimensions, "Uniqueness")
  
  result <- lapply(seq_along(sensor_tabellen), function(i) {
    df <- sensor_tabellen[[i]]
    sensor_name <- names(sensor_tabellen)[i]
    
    # Bestimme Messspalten (alles außer Zeit)
    cols_to_check <- names(df)[sapply(df, function(x) any(!is.na(x)))]
    daten_spalten <- setdiff(cols_to_check, time_col)
    
    # Qualitätsbewertung je Messspalte
    metrics_list <- lapply(daten_spalten, function(col) {
      metrics <- evaluate_quality(df, col, time_col = time_col)
      metric_names <- paste0(col, "_", all_dimensions)  # alle 5 Dimensionen inkl. Uniqueness
      metrics_df <- as.data.frame(t(metrics))
      names(metrics_df) <- metric_names
      return(metrics_df)
    })
    
    metrics_df <- if (length(metrics_list) > 0) do.call(cbind, metrics_list) else NULL
    
    # Zeitspalte separat bewerten (immer mit allen 6 Dimensionen)
    if (time_col %in% names(df)) {
      zeit_metrics <- evaluate_quality_time(df, time_col, time_col = time_col)
      names(zeit_metrics) <- paste0(time_col, "_", dimensions_Zeit)
      zeit_df <- as.data.frame(t(zeit_metrics))
    } else {
      zeit_df <- as.data.frame(t(setNames(rep(NA_real_, length(dimensions_Zeit)), paste0(time_col, "_", dimensions_Zeit))))
    }
    
    # Zusammenführen
    all_metrics <- cbind(metrics_df, zeit_df)
    df_out <- data.frame(sensor = sensor_name, all_metrics, check.names = FALSE)
    
    # Durchschnitt pro Dimension über alle Messwerte (nicht Zeit)
    messwert_spalten <- grep(paste0("^(", paste0(daten_spalten, collapse = "|"), ")_"), names(df_out), value = TRUE)
    summary_values <- sapply(dimensions, function(dim) {
      relevant_cols <- grep(paste0("_", dim, "$"), messwert_spalten, value = TRUE)
      mean(unlist(df_out[1, relevant_cols]), na.rm = TRUE)
    })
    
    # Durchschnitt pro Messwert über relevante Dimensionen
    avg_cols <- lapply(daten_spalten, function(col) {
      relevant_metrics <- paste0(col, "_", dimensions)
      avg <- mean(unlist(df_out[1, relevant_metrics]), na.rm = TRUE)
      setNames(avg, paste0(col, "_avg_quality"))
    })
    
    avg_df <- as.data.frame(t(unlist(avg_cols)))
    df_out <- cbind(df_out, as.data.frame(t(summary_values)), avg_df)
    
    return(df_out)
  })
  
  do.call(rbind, result)
}

# -------------------------------
# Beschreibungen zu den Dimensionen
# -------------------------------
dimensionen_beschreibung <- list(
  Accuracy = list(
    Zeit = "Es wird geprüft, ob alle Zeitangaben gleich formatiert sind – genauer: ob alle die gleiche Zeichenlänge besitzen. Wenn ja, beträgt die Genauigkeit 100 %. Andernfalls 0 %.",
    Messwert = "Für Messwerte wird keine Genauigkeit berechnet."
  ),
  Completeness = list(
    Zeit = "Vollständigkeit gibt den Anteil nicht-leerer Zeitangaben an. Prozentwert = Anzahl vorhandener Zeitwerte geteilt durch Gesamtanzahl der Zeilen.",
    Messwert = "Gibt an, wie viele Werte in der Messspalte vorhanden sind. Prozentwert = vorhandene Werte geteilt durch Gesamtanzahl der Zeilen."
  ),
  Consistency = list(
    Zeit = "Misst, ob Zeitangaben korrekt als Zeit interpretiert werden können. Prozentwert = gültig interpretierbare Zeitangaben geteilt durch Gesamtzahl.",
    Messwert = "Misst den Anteil aller einheitlich aufgebauter Werte. Dazu wird das häufigste Formatmuster gesucht und gezählt, wie viele Werte diesem entsprechen."
  ),
  Timeliness = list(
    Zeit = "Nicht berechnet für Zeitangaben, da sie die Grundlage für diese Dimension darstellen.",
    Messwert = "Es wird geprüft, ob die zeitlichen Abstände der Messwerte regelmäßig sind. Sind die Abweichungen gering (Standardabweichung unter 600 Sekunden), beträgt die Aktualität 100 %."
  ),
  Validity = list(
    Zeit = "Misst den Anteil gültiger Zeitangaben. Ungültig sind z. B. 'error', 'NaN' oder leere Felder.",
    Messwert = "Ein Wert gilt als gültig, wenn er innerhalb des erwarteten Bereichs liegt. Der Prozentwert zeigt, wie viele der vorhandenen Werte zulässig sind."
  ),
  Uniqueness = list(
    Zeit = "Zeigt den Anteil an einzigartigen Zeitwerten. Prozentwert = Anzahl verschiedener Zeitangaben geteilt durch Gesamtzahl.",
    Messwert = "Misst optional den Anteil verschiedener Messwerte. Wird standardmäßig nicht berücksichtigt, kann aber bei Bedarf aktiviert werden."
  )
)

# -------------------------------
# UI
# -------------------------------
ui <- dashboardPage(
  dashboardHeader(title = "HM-SENSE Dashboard"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Sensoren-Analyse", tabName = "analyse", icon = icon("chart-line")),
      menuItem("Qualitätsdokumentation", tabName = "dokumentation", icon = icon("book"))
    )
  ),
  dashboardBody(
    tabItems(
      
      # ---------------------------
      # TAB 1: Analyse & Visualisierung
      # ---------------------------
      tabItem(tabName = "analyse",
              
              fluidPage(
                titlePanel("HM-SENSE Dashboard"),
                
                
                fluidRow(
                  column(10,
                         selectizeInput("selected_sensor", "Sensor auswählen:",
                                        choices = c("Alle", unique(sensor_data_all$Sensor)),
                                        selected = "Alle",
                                        multiple = TRUE)
                  ),
                  column(2, align = "right",
                         actionButton("reset_sensor", "Sensorwahl zurücksetzen")
                  )
                ),
                
                
                br(),
                
                fluidRow(
                  column(3,
                         dateRangeInput("date_range", "Zeitraum wählen:",
                                        start = min(sensor_data_all$Zeit),
                                        end = max(sensor_data_all$Zeit))
                  ),
                  column(2,
                         selectInput("time_from", "Von (Uhrzeit):", choices = zeit_optionen, selected = "00:00")
                  ),
                  column(2,
                         selectInput("time_to", "Bis (Uhrzeit):", choices = zeit_optionen, selected = "23:30")
                  )
                ),
                
                br(),
                
                fluidRow(
                  column(6,
                         textOutput("selected_period")
                  ),
                  column(6, align = "right",
                         actionButton("reset_date", "Zeitraum zurücksetzen")
                  )
                ),
                
                tabsetPanel(
                  
                  # tabPanel("Alle Sensoren",
                  #          
                  #          br(),
                  #          
                  #          # Qualitätstabelle
                  #          DTOutput("quality_table")
                  # ),
                  tabPanel("Alle Sensoren",
                           
                           br(),
                           
                           # KPI-Kacheln
                           fluidRow(
                             valueBoxOutput("kpi_completeness"),
                             valueBoxOutput("kpi_validity"),
                             valueBoxOutput("kpi_consistency"),
                             valueBoxOutput("kpi_timeliness"),
                             valueBoxOutput("kpi_uniqueness")
                           ),
                           
                           br(),
                           
                           # Qualitätstabelle
                           DTOutput("quality_table")
                  ),
                  
                  
                  
                  tabPanel("Sensor/en im Detail",
                           br(),
                           DTOutput("sensor_detail_table")
                  ),
                  
                  tabPanel("Plots",
                           br(),
                           h4("Qualitätsübersicht"),
                           fluidRow(
                             column(4,
                                    uiOutput("sensor_selector_ui")
                             )
                           ),
                           plotOutput("plot_messwerte", height = "400px"),
                           
                           # br(),
                           # h4("Zeitreihe der Datenqualität"),
                           # fluidRow(
                           #   column(4,
                           #          selectInput("selected_metric", "Qualitätsdimension wählen:",
                           #                      choices = c("Completeness", "Consistency", "Timeliness", "Validity", "Uniqueness"),
                           #                      selected = "Completeness")
                           #   )
                           # ),
                           # plotOutput("plot_quality_time"),
                           # 
                           br(),
                           h4("Qualitäts-Heatmap je Sensor"),
                           
                           fluidRow(
                             column(10,
                                    selectizeInput("selected_sensor_heatmap", 
                                                   "Sensor auswählen:",
                                                   choices = unique(quality_results$sensor),
                                                   selected = unique(quality_results$sensor)[1:3],
                                                   multiple = TRUE,
                                                   options = list(placeholder = 'Sensoren wählen oder abwählen'))
                             ),
                             column(2, align = "right",
                                    actionButton("reset_sensor_heatmap", "Sensorwahl zurücksetzen")
                             )
                           ),
                           
                           
                           plotOutput("quality_heatmap", height = "600px")
                  ),
                  
                  tabPanel("Export",
                           br(),
                           fluidRow(
                             column(3,
                                    selectInput("frequency", "Frequenz (Minuten):",
                                                choices = c(5, 10, 15, 20, 30, 60),
                                                selected = 15)
                             )
                           ),
                           br(),
                           fluidRow(
                             column(12, align = "right",
                                    tags$div(style = "position: fixed; bottom: 20px; right: 20px;",
                                             actionButton("export_btn", "😄 Export starten", class = "btn btn-primary", disabled = FALSE)
                                    )
                             )
                           )
                  )
                )
              )
      ),
      
      # ---------------------------
      # TAB 2: Dokumentation
      # ---------------------------
      tabItem(tabName = "dokumentation",
              fluidRow(
                box(width = 12, title = "Datenqualitätsdimensionen", status = "primary", solidHeader = TRUE,
                    selectInput("dimension", "Wähle eine Dimension:",
                                choices = names(dimensionen_beschreibung), selected = "Completeness"),
                    h4("Für Zeitangaben:"),
                    textOutput("beschreibung_zeit"),
                    br(),
                    h4("Für Messwerte:"),
                    textOutput("beschreibung_messwert")
                )
              )
      )
    )
  )
)

# -------------------------------
# SERVER
# -------------------------------
server <- function(input, output, session) {
  
  # Qualitätsbeschreibung
  output$beschreibung_zeit <- renderText({
    dimensionen_beschreibung[[input$dimension]]$Zeit
  })
  
  output$beschreibung_messwert <- renderText({
    dimensionen_beschreibung[[input$dimension]]$Messwert
  })
  
  # Reaktive Funktion zur dynamischen Zählung der Messwerte pro Sensor
  filtered_sensor_counts <- reactive({
    req(input$selected_sensor, input$date_range, input$time_from, input$time_to)
    
    # Auswahl bereinigen
    selected <- if ("Alle" %in% input$selected_sensor) {
      unique(sensor_data_all$Sensor)
    } else {
      input$selected_sensor
    }
    
    # Filtere Sensor-Daten
    df <- sensor_data_all %>%
      filter(Sensor %in% selected) %>%
      filter(Zeit >= as.POSIXct(input$date_range[1], tz = "UTC") &
               Zeit <= as.POSIXct(input$date_range[2], tz = "UTC") + 86399)
    
    # Uhrzeitfilter berechnen
    from_split <- strsplit(input$time_from, ":")[[1]]
    to_split   <- strsplit(input$time_to, ":")[[1]]
    from_min <- as.numeric(from_split[1]) * 60 + as.numeric(from_split[2])
    to_min   <- as.numeric(to_split[1])   * 60 + as.numeric(to_split[2])
    
    zeit_h <- as.numeric(format(df$Zeit, "%H", tz = "UTC"))
    zeit_m <- as.numeric(format(df$Zeit, "%M", tz = "UTC"))
    zeit_min <- zeit_h * 60 + zeit_m
    
    df <- df[zeit_min >= from_min & zeit_min <= to_min, ]
    
    # Gruppiere und zähle
    df %>%
      group_by(Sensor) %>%
      summarise(N = n(), .groups = "drop")
  })
  
  # KPI-Auswertung: dynamisch je nach Auswahl und Zeitraum
  output_kpis <- reactive({
    req(input$selected_sensor)
    
    selected <- if ("Alle" %in% input$selected_sensor) {
      unique(quality_results$sensor)
    } else {
      input$selected_sensor
    }
    
    counts <- filtered_sensor_counts()
    
    # Merge mit quality_results
    kpi_data <- quality_results %>%
      filter(sensor %in% selected) %>%
      inner_join(counts, by = c("sensor" = "Sensor"))
    
    total_n <- sum(kpi_data$N)
    
    kpis <- c("Completeness", "Validity", "Consistency", "Timeliness", "Uniqueness")
    
    weighted_kpis <- sapply(kpis, function(kpi) {
      sum(kpi_data[[kpi]] * kpi_data$N, na.rm = TRUE) / total_n
    })
    
    return(weighted_kpis)
  })
  
  
  
  # Qualitätstabelle
  output$quality_table <- renderDT({
    
    df <- if ("Alle" %in% input$selected_sensor) {
      quality_results
    } else {
      subset(quality_results, sensor %in% input$selected_sensor)
    }
    
    datatable(
      df,
      options = list(scrollX = TRUE, scrollY = "500px", paging = FALSE),
      class = "stripe hover nowrap"
    )
  })
  
  output$kpi_completeness <- renderValueBox({
    val <- output_kpis()[["Completeness"]]
    valueBox(
      paste0(round(val * 100), " %"),
      "Completeness",
      icon = icon("check-circle"),
      color = if (val >= 0.9) "green" else if (val >= 0.75) "yellow" else "red"
    )
  })
  
  output$kpi_validity <- renderValueBox({
    val <- output_kpis()[["Validity"]]
    valueBox(
      paste0(round(val * 100), " %"),
      "Validity",
      icon = icon("clipboard-check"),
      color = if (val >= 0.9) "green" else if (val >= 0.75) "yellow" else "red"
    )
  })
  
  output$kpi_consistency <- renderValueBox({
    val <- output_kpis()[["Consistency"]]
    valueBox(
      paste0(round(val * 100), " %"),
      "Consistency",
      icon = icon("project-diagram"),
      color = if (val >= 0.9) "green" else if (val >= 0.75) "yellow" else "red"
    )
  })
  
  output$kpi_timeliness <- renderValueBox({
    val <- output_kpis()[["Timeliness"]]
    valueBox(
      paste0(round(val * 100), " %"),
      "Timeliness",
      icon = icon("clock"),
      color = if (val >= 0.9) "green" else if (val >= 0.75) "yellow" else "red"
    )
  })
  
  output$kpi_uniqueness <- renderValueBox({
    val <- output_kpis()[["Uniqueness"]]
    valueBox(
      paste0(round(val * 100), " %"),
      "Uniqueness",
      icon = icon("fingerprint"),
      color = if (val >= 0.9) "green" else if (val >= 0.75) "yellow" else "red"
    )
  })
  
  
  # Sensor Detail Tabelle (filtered)
  filtered_sensor_data <- reactive({
    req(input$selected_sensor)
    
    selected <- setdiff(input$selected_sensor, "Alle")
    if (length(selected) == 0) {
      return(data.frame())  # Gebe leeren Dataframe zurück, falls keine Sensoren ausgewählt sind.
    }
    
    # Daten filtern
    df <- subset(sensor_data_all, Sensor %in% selected)
    
    # Zeitbereich filtern
    df <- df[df$Zeit >= as.POSIXct(input$date_range[1], tz = "UTC") &
               df$Zeit <= as.POSIXct(input$date_range[2], tz = "UTC") + 86399, ]
    
    # Uhrzeitbereich filtern
    from_split <- strsplit(input$time_from, ":")[[1]]
    to_split   <- strsplit(input$time_to, ":")[[1]]
    from_min <- as.numeric(from_split[1]) * 60 + as.numeric(from_split[2])
    to_min   <- as.numeric(to_split[1])   * 60 + as.numeric(to_split[2])
    
    zeit_h <- as.numeric(format(df$Zeit, "%H", tz = "UTC"))
    zeit_m <- as.numeric(format(df$Zeit, "%M", tz = "UTC"))
    zeit_min <- zeit_h * 60 + zeit_m
    
    df <- df[zeit_min >= from_min & zeit_min <= to_min, ]
    
    return(df)
  })
  
  output$sensor_detail_table <- renderDT({
    df <- filtered_sensor_data()
    
    if (nrow(df) == 0) {
      return(datatable(data.frame(Hinweis = "Bitte mindestens einen Sensor auswählen.")))
    }
    
    # Gruppiere nach Sensor – jede Seite soll einen Sensor enthalten
    dfs <- split(df, df$Sensor)
    max_rows <- max(sapply(dfs, nrow))
    
    padded <- lapply(dfs, function(d) {
      if (nrow(d) < max_rows) {
        # Fülle mit NA-Zeilen auf
        n_missing <- max_rows - nrow(d)
        empty_rows <- d[rep(1, n_missing), ]
        empty_rows[,] <- NA
        d <- rbind(d, empty_rows)
      }
      return(d)
    })
    
    final_df <- do.call(rbind, padded)
    
    datatable(
      final_df,
      options = list(
        pageLength = max_rows,
        scrollX = TRUE,
        scrollY = "500px",
        paging = TRUE,
        ordering = FALSE,
        lengthChange = FALSE
      ),
      rownames = FALSE,
      filter = "none",
      class = "stripe hover nowrap"
    )
  })
  
  # 1. Qualitätsübersicht
  output$sensor_selector_ui <- renderUI({
    req(quality_results)
    selectInput("selected_sensor_plot", "Sensor wählen:",
                choices = unique(quality_results$sensor),
                selected = unique(quality_results$sensor)[1])
  })
  
  output$plot_messwerte <- renderPlot({
    req(input$selected_sensor_plot)
    req(quality_results)
  
    df <- quality_results[1:37] %>%
      filter(sensor == input$selected_sensor_plot) %>%
      pivot_longer(
        cols = -sensor,
        names_to = "Dimension",
        values_to = "Score"
      ) %>%
      separate(Dimension, into = c("Messgröße", "Qualitätsdimension"), sep = "_")
    
    ggplot(df, aes(x = Messgröße, y = Score, fill = Qualitätsdimension)) +
      geom_col(position = "dodge") +
      ylim(0, 1) +
      labs(
        title = paste("Qualitätsmetriken für Sensor:", input$selected_sensor_plot),
        x = "Messgröße",
        y = "Wert (0-1)",
        fill = "Qualitätsdimension"
      ) +
      theme_light()
  })
  # # 2. Zeitverlauf
  # observe({
  #   req(input$selected_metric)
  #   
  #   metric <- input$selected_metric
  #   output$plot_quality_time <- renderPlot({
  #     
  #     ggplot(quality_results, aes_string(x = time, y = metric)) +
  #       geom_line() +
  #       geom_point() + 
  #       labs(
  #         title = paste("Sensorqualität –", metric),
  #         x = "Sensor",
  #         y = metric
  #       ) +
  #       theme_minimal()
  #   })
  # })
  
  # 3. Heatmap
  
  observeEvent(input$reset_sensor_heatmap, {
    updateSelectizeInput(session, "selected_sensor_heatmap",
                         selected = character(0))
  })
  
  output$quality_heatmap <- renderPlot({
    req(quality_results, input$selected_sensor_heatmap)
    
    filtered_quality <- quality_results[c(1, 38, 39, 40, 41)] %>%
      filter(sensor %in% input$selected_sensor_heatmap) %>%
      pivot_longer(-sensor, names_to = "Dimension", values_to = "Score")
    
    ggplot(filtered_quality, aes(x = Dimension, y = sensor, fill = Score)) +
      geom_tile(color = "white") +
      scale_fill_gradient(low = "pink", high = "skyblue", limits = c(0, 1)) +
      labs(title = "Heatmap der Qualitätsmetriken pro Sensor",
           x = "Qualitätsdimension", y = "Sensor", fill = "Score") +
      theme_minimal(base_size = 14) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  })
  
  observeEvent(input$export_btn, {
    req(input$frequency)  # ensure frequency is selected
    
    data <- filtered_sensor_data()
    
    if (nrow(data) == 0) {
      shinyalert("Kein Export möglich", "Bitte mindestens einen Sensor auswählen.", type = "error")
      return()
    }
    
    # Split by sensor
    dfs <- split(data, data$Sensor)
    
    # Round down to nearest frequency in minutes
    freq_min <- as.numeric(input$frequency)
    
    # Downsample each sensor separately
    downsampled <- lapply(names(dfs), function(sensor_name) {
      sensor_df <- dfs[[sensor_name]]
      
      sensor_df <- sensor_df %>%
        mutate(RoundedTime = floor_date(Zeit, unit = paste(freq_min, "mins"))) %>%
        group_by(RoundedTime) %>%
        summarise(across(where(is.numeric), mean, na.rm = TRUE), .groups = "drop") %>%
        mutate(Sensor = sensor_name)  # Tag with sensor name
      
      return(sensor_df)
    })
    
    # Combine into one final data frame
    final_df <- do.call(rbind, downsampled)
    
    # Ensure correct time formatting
    final_df$RoundedTime <- format(final_df$RoundedTime, "%Y-%m-%d %H:%M:%S")
    
    # Move Sensor column to front
    final_df <- final_df[, c("Sensor", setdiff(names(final_df), "Sensor"))]
    
    # Save CSV
    filename <- paste0("../data/export_", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), ".csv")
    write.csv(final_df, file = filename, row.names = FALSE)
    
    # Show popup
    shinyalert("Export created", type = "success")
  })
  
  
  observeEvent(input$reset_date, {
    req(input$selected_sensor)
    
    df <- subset(sensor_data_all, Sensor == input$selected_sensor)
    
    updateDateRangeInput(session, "date_range",
                         start = min(df$Zeit, na.rm = TRUE),
                         end = max(df$Zeit, na.rm = TRUE))
    
    updateSelectInput(session, "time_from", selected = "00:00")
    updateSelectInput(session, "time_to", selected = "23:30")
  })
  
  # Reset-Button für Sensorauswahl
  observeEvent(input$reset_sensor, {
    updateSelectizeInput(session, "selected_sensor", selected = character(0))
  })
  
}

# -------------------------------
# App starten
# -------------------------------
shinyApp(ui, server)

