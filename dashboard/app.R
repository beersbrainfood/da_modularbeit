# app.R
library(shiny)

ui <- fluidPage(
  titlePanel("HM-SENSE Dashboard"),
  
  sidebarLayout(
    sidebarPanel(
      sliderInput("obs", "Anzahl der Beobachtungen:", min = 1, max = 100, value = 50)
    ),
    
    mainPanel(
      plotOutput("distPlot")
    )
  )
)

server <- function(input, output) {
  output$distPlot <- renderPlot({
    hist(rnorm(input$obs))
  })
}

shinyApp(ui = ui, server = server)
