library(shiny)
library(DT)

# Daten laden
quality_results <- read.csv("data/data_quality_report.csv")
sensor_data_all <- read.csv("data/sensor_daten_buendelt.csv")
# Zeitspalte vorbereiten (Z abschneiden, Millisekunden behalten, korrekt parsen)
sensor_data_all$Zeit <- gsub("Z$", "", sensor_data_all$Zeit)
sensor_data_all$Zeit <- substr(sensor_data_all$Zeit, 1, 23)
sensor_data_all$Zeit <- as.POSIXct(sensor_data_all$Zeit, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")

# Dropdown-Zeitoptionen: 00:00 bis 23:30 im 30-Minuten-Takt
zeit_optionen <- format(seq(
  as.POSIXct("00:00", format = "%H:%M"),
  as.POSIXct("23:30", format = "%H:%M"),
  by = "30 min"
), "%H:%M")

ui <- fluidPage(
  titlePanel("HM-SENSE Dashboard"),
  
  # Sensor-Auswahl: eigene Zeile
  fluidRow(
    column(12,
           selectInput("selected_sensor", "Sensor auswählen:",
                       choices = c("Alle", unique(sensor_data_all$Sensor)),
                       selected = "Alle")
           
    )
  ),
  
  br(),
  
  # Datum + Uhrzeiten in einer Zeile kompakt nebeneinander
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
    # die restlichen 5 Spalten (12 - 3 - 2 - 2 = 5) bleiben automatisch leer = rechts Whitespace
  ),
  
  br(),
  
  # Zeitraum-Anzeige & Zurücksetzen
  fluidRow(
    column(6,
           textOutput("selected_period")
    ),
    column(6, align = "right",
           actionButton("reset_date", "Zeitraum zurücksetzen")
    )
  ),
  
  tabsetPanel(
    
    tabPanel("Alle Sensoren",
             br(),
             DTOutput("quality_table")
    ),
    
    # tabPanel("Sensor/en im Detail",
    #          # Sensor- und Zeitraum-Auswahl nebeneinander
    #          br(),
    #          fluidRow(
    #            column(6,
    #                   fluidRow(
    #                     column(6,
    #                            selectInput("selected_sensor", "Sensor auswählen:",
    #                                        choices = unique(sensor_data_all$Sensor))
    #                     ),
    #                     column(6,
    #                            dateRangeInput("date_range", "Zeitraum wählen:",
    #                                           start = min(sensor_data_all$Zeit),
    #                                           end = max(sensor_data_all$Zeit))
    #                     )
    #                   ),
    #                   br(),
    #                   fluidRow(
    #                     column(6,
    #                            selectInput("time_from", "Von (Uhrzeit):", choices = zeit_optionen, selected = "00:00")
    #                     ),
    #                     column(6,
    #                            selectInput("time_to", "Bis (Uhrzeit):", choices = zeit_optionen, selected = "23:30")
    #                     )
    #                   )
    #            )
    #          ),
    #          
    #          br(),
    #          
    #          # Zeitraum-Anzeige & Zurücksetzen
    #          fluidRow(
    #            column(6,
    #                   textOutput("selected_period")
    #            ),
    #            column(6, align = "right",
    #                   actionButton("reset_date", "Zeitraum zurücksetzen")
    #            )
    #          ),
    #          
    #          br(),
    #          
    #          # Tabelle
    #          DTOutput("sensor_detail_table")
    # ),
    
    tabPanel("Sensor/en im Detail",
             br(),
             
             # # Sensor-Auswahl: eigene Zeile
             # fluidRow(
             #   column(12,
             #          selectInput("selected_sensor", "Sensor auswählen:",
             #                      choices = unique(sensor_data_all$Sensor))
             #   )
             # ),
             # 
             # br(),
             # 
             # # Datum + Uhrzeiten in einer Zeile kompakt nebeneinander
             # fluidRow(
             #   column(3,
             #          dateRangeInput("date_range", "Zeitraum wählen:",
             #                         start = min(sensor_data_all$Zeit),
             #                         end = max(sensor_data_all$Zeit))
             #   ),
             #   column(2,
             #          selectInput("time_from", "Von (Uhrzeit):", choices = zeit_optionen, selected = "00:00")
             #   ),
             #   column(2,
             #          selectInput("time_to", "Bis (Uhrzeit):", choices = zeit_optionen, selected = "23:30")
             #   )
             #   # die restlichen 5 Spalten (12 - 3 - 2 - 2 = 5) bleiben automatisch leer = rechts Whitespace
             # ),
             # 
             # br(),
             # 
             # # Zeitraum-Anzeige & Zurücksetzen
             # fluidRow(
             #   column(6,
             #          textOutput("selected_period")
             #   ),
             #   column(6, align = "right",
             #          actionButton("reset_date", "Zeitraum zurücksetzen")
             #   )
             # ),
             
             br(),
             
             # Tabelle
             DTOutput("sensor_detail_table")
    ),
    
    tabPanel("Export",
             br(),
             
             # Frequenz-Dropdown nur hier sichtbar
             fluidRow(
               column(3,
                      selectInput("frequency", "Frequenz (Minuten):",
                                  choices = c(5, 10, 15, 20, 30, 60),
                                  selected = 15)
               )
             ),
             
             br(),
             
             # Exportbutton wie gehabt
             fluidRow(
               column(12, align = "right",
                      tags$div(style = "position: fixed; bottom: 20px; right: 20px;",
                               actionButton("export_btn", "😄 Export starten", class = "btn btn-primary", disabled = TRUE)
                      )
               )
             )
    )
  )
)

server <- function(input, output, session) {
  
  # Tab 1
  # output$quality_table <- renderDT({
  #   datatable(
  #     quality_results,
  #     options = list(
  #       scrollX = TRUE,
  #       scrollY = "500px",  # vertikaler Scrollbereich
  #       paging = FALSE      # Seiten blättern deaktivieren
  #     ),
  #     class = "stripe hover nowrap"
  #   )
  # })
  
  
  # output$quality_table <- renderDT({
  #   req(input$selected_sensor)  # Sicherstellen, dass ein Sensor ausgewählt ist
  #   
  #   df <- subset(quality_results, sensor == input$selected_sensor)
  #   
  #   datatable(
  #     df,
  #     options = list(
  #       scrollX = TRUE,
  #       scrollY = "500px",
  #       paging = FALSE
  #     ),
  #     class = "stripe hover nowrap"
  #   )
  # })
  
  output$quality_table <- renderDT({
    df <- if (input$selected_sensor == "Alle") {
      quality_results
    } else {
      subset(quality_results, sensor == input$selected_sensor)
    }
    
    datatable(
      df,
      options = list(
        scrollX = TRUE,
        scrollY = "500px",
        paging = FALSE
      ),
      class = "stripe hover nowrap"
    )
  })
  
  
  # Tab 2 – Reaktive Sensorauswahl
  filtered_sensor_data <- reactive({
    req(input$selected_sensor, input$date_range)
    
    # Falls "Alle" ausgewählt wurde → gib leeren DataFrame zurück
    if (input$selected_sensor == "Alle") {
      return(data.frame(Hinweis = "Bitte einen einzelnen Sensor auswählen."))
    }
    
    df <- subset(sensor_data_all, Sensor == input$selected_sensor)
    
    # Datum filtern
    start_dt <- as.POSIXct(input$date_range[1], tz = "UTC")
    end_dt   <- as.POSIXct(input$date_range[2], tz = "UTC") + 86399
    df <- df[df$Zeit >= start_dt & df$Zeit <= end_dt, ]
    
    # Uhrzeit-Filter anwenden
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
  
  
#   filtered_sensor_data <- reactive({
#     req(input$selected_sensor, input$date_range)
# 
# #    df <- subset(sensor_data_all, Sensor == input$selected_sensor)
#     df <- if (input$selected_sensor == "Alle") {
#       sensor_data_all
#     } else {
#       subset(sensor_data_all, Sensor == input$selected_sensor)
#     }
# 
#     # Eingabewerte ebenfalls korrekt parsen (Date → POSIXct mit UTC)
#     start_dt <- as.POSIXct(input$date_range[1], tz = "UTC")
#     end_dt   <- as.POSIXct(input$date_range[2], tz = "UTC") + 86399  # inkl. kompletter Tag
# 
#     # Filter anwenden
#     df <- df[df$Zeit >= start_dt & df$Zeit <= end_dt, ]
#     
#     # Uhrzeiten aus Dropdowns in Minuten umwandeln
#     from_split <- strsplit(input$time_from, ":")[[1]]
#     to_split   <- strsplit(input$time_to, ":")[[1]]
#     from_min <- as.numeric(from_split[1]) * 60 + as.numeric(from_split[2])
#     to_min   <- as.numeric(to_split[1])   * 60 + as.numeric(to_split[2])
#     
#     # Zeit jeder Zeile in Minuten berechnen
#     zeit_h <- as.numeric(format(df$Zeit, "%H", tz = "UTC"))
#     zeit_m <- as.numeric(format(df$Zeit, "%M", tz = "UTC"))
#     zeit_min <- zeit_h * 60 + zeit_m
#     
#     # Zeitfilter anwenden
#     df <- df[zeit_min >= from_min & zeit_min <= to_min, ]
#     
# 
#     return(df)
#   })
  
  
  output$sensor_detail_table <- renderDT({
    datatable(
      filtered_sensor_data(),
      options = list(
        scrollX = TRUE,
        scrollY = "500px",
        paging = FALSE
      ),
      class = "stripe hover nowrap"
    )
  })
  
  observeEvent(input$reset_date, {
    req(input$selected_sensor)
    
    df <- subset(sensor_data_all, Sensor == input$selected_sensor)
    
    start_dt <- min(df$Zeit, na.rm = TRUE)
    end_dt   <- max(df$Zeit, na.rm = TRUE)
    
    updateDateRangeInput(
      session,
      "date_range",
      start = start_dt,
      end = end_dt
    )
    
    # Zeit-Auswahl zurücksetzen (Standard: 00:00 bis 23:30)
    updateSelectInput(session, "time_from", selected = "00:00")
    updateSelectInput(session, "time_to", selected = "23:30")
    
  })
  
}

shinyApp(ui, server)
