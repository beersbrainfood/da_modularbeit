library(shiny)
library(DT)

# Daten laden
quality_results <- read.csv("data/data_quality_report.csv")
sensor_data_all <- read.csv("data/sensor_daten_buendelt.csv")

ui <- fluidPage(
  titlePanel("HM-SENSE Dashboard"),
  
  tabsetPanel(
    
    tabPanel("Alle Sensoren",
             br(),
             DTOutput("quality_table")
    ),
    
    tabPanel("Sensor/en im Detail",
             br(),
             selectInput("selected_sensor", "Sensor auswählen:",
                         choices = unique(sensor_data_all$Sensor)),
             br(),
             DTOutput("sensor_detail_table")
    ),
    
    tabPanel("Export",
             br(), br(),
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
  output$quality_table <- renderDT({
    datatable(
      quality_results,
      options = list(scrollX = TRUE, pageLength = 10),
      class = "stripe hover nowrap"
    )
  })
  
  # Tab 2 – Reaktive Sensorauswahl
  filtered_sensor_data <- reactive({
    req(input$selected_sensor)
    subset(sensor_data_all, Sensor == input$selected_sensor)
  })
  
  output$sensor_detail_table <- renderDT({
    datatable(
      filtered_sensor_data(),
      options = list(scrollX = TRUE, pageLength = 10),
      class = "stripe hover nowrap"
    )
  })
}

shinyApp(ui, server)
