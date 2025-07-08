# Liste aller benötigten Pakete
packages <- c(
  "httr", "yaml", "jsonlite",
  "dplyr", "tidyr", "lubridate",
  "purrr", "stringr", "tibble",
  "shiny", "shinyalert", "shinydashboard", "DT"
)

# Nur fehlende Pakete installieren
installed <- packages %in% rownames(installed.packages())
if (any(!installed)) {
  install.packages(packages[!installed])
}

x <- 42
print(x)