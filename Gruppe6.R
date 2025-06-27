# ------------------------------------------------------------
# Bibliotheken laden
# ------------------------------------------------------------
library(dplyr)     # für Datenmanipulation
library(tidyr)     # für Datenumformung (z. B. pivot_wider)
library(lubridate) # für Zeitverarbeitung (wird später indirekt genutzt)
library(purrr)     # funktionale Programmierung (z. B. lapply)
library(stringr)   # für Zeichenkettenoperationen (z. B. Regex)
library(tibble)    # für moderne DataFrames (tibbles)

# ------------------------------------------------------------
# CSV-Dateien einlesen und in eine Liste speichern
# ------------------------------------------------------------
dateianzahl <- 1:7                # Nummern der vorhandenen CSV-Dateien
daten_liste <- list()             # Leere Liste für geladene Daten

# Schleife über alle Dateiindizes – Dateien werden nacheinander eingelesen
for (i in dateianzahl) {
  dateipfad <- paste0("D:/Data Analytics/Data Engineering/de_ma_group6-main-data/de_ma_group6-main-data/data/influx_block_", i, ".csv")
  daten_liste[[i]] <- read.csv(dateipfad)
}

# ------------------------------------------------------------
# Sensor-Daten aus einer bestimmten Datei extrahieren (z.B. Datei 7)
# ------------------------------------------------------------
daten_sensoren <- daten_liste[[7]]

#Entferne Zeilen mit '/normalized' am Ende
daten_sensoren <- daten_sensoren %>%
  filter(!str_detect(mqtt_topic, "/normalized$"))

#Extrahiere den Sensor-Namen (z.B. sensor25 oder sensor25-1)
daten_sensoren$mqtt_topic <- str_extract(daten_sensoren$mqtt_topic, "sensor\\d+(?:-\\d+)?")

# Daten nach Sensorname aufteilen in eine Liste
sensoren_liste <- split(daten_sensoren, daten_sensoren$mqtt_topic)

# ------------------------------------------------------------
# Gruppierung vorbereiten: Sensornamen in derselben Reihenfolge wie spätere Tabellen
# ------------------------------------------------------------
sensor_names <- daten_sensoren %>%
  distinct(mqtt_topic) %>%
  pull(mqtt_topic)

# ------------------------------------------------------------
# Daten in breite Tabellen pro Sensor umwandeln
# ------------------------------------------------------------
sensor_tabellen <- daten_sensoren %>%
  select(X_time, X_field, X_value, mqtt_topic) %>%
  group_by(mqtt_topic) %>%
  group_split() %>%
  lapply(function(sensor_df) {
    sensor_df %>%
      pivot_wider(                 # Spalten „X_field“ werden zu Spaltennamen
        id_cols = X_time,         # Zeitstempel als Identifier
        names_from = X_field,     # Spaltennamen generieren
        values_from = X_value     # Werte in neue Spalten schreiben
      ) %>%
      arrange(X_time)             # Nach Zeit sortieren
  })

# Namen der Tabellen entsprechend der Sensorreihenfolge vergeben
names(sensor_tabellen) <- sensor_names

# ------------------------------------------------------------
# Spaltenauswahl & Umbenennung für lesbare Darstellung
# ------------------------------------------------------------
# Relevante Felder definieren – nur diese sollen in den Ausgaben enthalten sein
behalten <- c(
  "X_time",
  "uplink_message_decoded_payload_temperature",
  "uplink_message_decoded_payload_humidity",
  "uplink_message_decoded_payload_co2",
  "uplink_message_decoded_payload_light",
  "uplink_message_decoded_payload_motion"
  
)

# In jedem Sensor-DataFrame: Spalten selektieren und benennen
sensor_tabellen <- lapply(sensor_tabellen, function(df) {
  df %>%
    select(any_of(behalten)) %>%  # Selektiere nur gewünschte Spalten (falls vorhanden)
    rename(                       # Umbenennung für bessere Lesbarkeit
      Zeit = X_time,
      Temperatur = uplink_message_decoded_payload_temperature,
      Luftfeuchtigkeit = uplink_message_decoded_payload_humidity,
      CO2 = uplink_message_decoded_payload_co2,
      Licht = uplink_message_decoded_payload_light,
      Bewegung = uplink_message_decoded_payload_motion
    )
})

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


# ------------------------------------------------------------
# Qualitätsbewertung ausführen
# ------------------------------------------------------------
quality_results <- check_data_quality(sensor_tabellen)

# ------------------------------------------------------------
# Ergebnis exportieren
# ------------------------------------------------------------
write.csv(quality_results, "D:/Data Analytics/Data Engineering/data_quality_report.csv", row.names = FALSE)

# Optional im Viewer anzeigen
View(quality_results)
