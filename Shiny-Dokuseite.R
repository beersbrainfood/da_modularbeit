library(shiny)
library(shinydashboard)

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
  dashboardHeader(title = "Datenqualitäts-Dashboard"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Übersicht", tabName = "uebersicht", icon = icon("table")),
      menuItem("Qualitätsdokumentation", tabName = "dokumentation", icon = icon("book"))
    )
  ),
  dashboardBody(
    tabItems(
      
      # Placeholder für weitere Inhalte
      tabItem(tabName = "uebersicht",
              h2("Übersicht über die Datenqualität (Platzhalter für Analyse)")
      ),
      
      # Dokumentationstab
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
# Server
# -------------------------------
server <- function(input, output, session) {
  output$beschreibung_zeit <- renderText({
    dimensionen_beschreibung[[input$dimension]]$Zeit
  })
  
  output$beschreibung_messwert <- renderText({
    dimensionen_beschreibung[[input$dimension]]$Messwert
  })
}

# -------------------------------
# App starten
# -------------------------------
shinyApp(ui, server)

