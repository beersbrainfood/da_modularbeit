library(dplyr)
library(tidyr)
library(lubridate)
library(purrr)
library(stringr)
library(tibble)


dateianzahl<- c(1:7)
daten_liste <- list()

for (i in dateianzahl) {
  dateipfad <- paste0("D:/Data Analytics/Data Engineering/de_ma_group6-main-data/de_ma_group6-main-data/data/influx_block_", i, ".csv")
  daten_liste[[i]] <- read.csv(dateipfad)
}


daten_sensoren<-daten_liste[[7]]


daten_sensoren$mqtt_topic <- str_extract(daten_sensoren$mqtt_topic, "sensor[0-9]+")
sensoren_liste <- split(daten_sensoren, daten_sensoren$mqtt_topic)

# 1. Hole die eindeutigen mqtt_topic Werte in der Reihenfolge der Gruppen:
sensor_names <- daten_sensoren %>%
  distinct(mqtt_topic) %>%
  pull(mqtt_topic)

# 2. Erstelle die Liste mit group_split()
sensor_tabellen <- daten_sensoren %>%
  select(X_time, X_field, X_value, mqtt_topic) %>%
  group_by(mqtt_topic) %>%
  group_split() %>%
  lapply(function(sensor_df) {
    sensor_df %>%
      pivot_wider(
        id_cols = X_time,
        names_from = X_field,
        values_from = X_value
      ) %>%
      arrange(X_time)
  })

# 3. Weise die Namen zu
names(sensor_tabellen) <- sensor_names




# 🔧 1. Spalten definieren: behalten & umbenennen
behalten <- c(
  "X_time",
  "uplink_message_decoded_payload_temperature",
  "uplink_message_decoded_payload_humidity",
  "uplink_message_decoded_payload_co2",
  "uplink_message_decoded_payload_light",
  "uplink_message_decoded_payload_motion",
  "uplink_message_decoded_payload_vdd"
)
# 🔄 2. Spalten selektieren & umbenennen für alle DataFrames
sensor_tabellen <- lapply(sensor_tabellen, function(df) {
  df %>%
    select(any_of(behalten)) %>%
    rename(
      Zeit = X_time,
      Temperatur = uplink_message_decoded_payload_temperature,
      Luftfeuchtigkeit = uplink_message_decoded_payload_humidity,
      CO2 = uplink_message_decoded_payload_co2,
      Licht = uplink_message_decoded_payload_light,
      Bewegung = uplink_message_decoded_payload_motion,
      Spannung = uplink_message_decoded_payload_vdd
    )
})


library(dplyr)
library(stringr)
evaluate_quality_time <- function(df, column, time_col = "Zeit") {
  total <- nrow(df)
  col_data <- df[[column]]
  
  if (column == time_col) {
    # Zeitangaben parsebar?
    parsed_times <- suppressWarnings(as.POSIXct(gsub("Z$", "", col_data), format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC"))
    
    # ➕ Accuracy = gleiche Genauigkeit aller Zeitstempel prüfen
    time_lengths <- nchar(gsub("Z$", "", col_data))
    accuracy <- if (length(unique(time_lengths[!is.na(time_lengths)])) == 1) 1 else 0
    
    completeness <- mean(!is.na(col_data))  # Keine NAs
    consistency <- mean(!is.na(parsed_times))  # Konsistent parsebar
    timeliness <- NA_real_  # Nicht sinnvoll bei Zeit selbst
    validity <- mean(!tolower(as.character(col_data)) %in% c("err", "error", "nan", "na", ""), na.rm = TRUE)
    uniqueness <- if (total > 0) length(unique(col_data)) / total else NA_real_
    
  } else {
    # Normale Prüfungen für andere Spalten
    col_data_num <- suppressWarnings(as.numeric(col_data))
    accuracy <- if (all(is.na(col_data_num))) NA_real_ else mean(!is.na(col_data_num) & col_data_num > -1e6 & col_data_num < 1e6, na.rm = TRUE)
    completeness <- mean(!is.na(col_data))
    consistency <- mean(sapply(col_data, function(x) is.numeric(x) || grepl("^[0-9.-]+$", as.character(x))), na.rm = TRUE)
    
    if (time_col %in% names(df)) {
      times <- as.POSIXct(gsub("Z$", "", df[[time_col]]), format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")
      diffs <- diff(times)
      std <- sd(as.numeric(diffs, units = "secs"), na.rm = TRUE)
      timeliness <- ifelse(length(diffs) > 1 && !is.na(std) && std < 600, 1, 0)
    } else {
      timeliness <- NA_real_
    }
    
    validity <- mean(!tolower(as.character(col_data)) %in% c("err", "error", "nan", "na", ""), na.rm = TRUE)
    uniqueness <- if (total > 0) length(unique(col_data)) / total else NA_real_
  }
  
  return(c(accuracy, completeness, consistency, timeliness, validity, uniqueness))
}

evaluate_quality <- function(df, column, time_col = "time") {
  total <- nrow(df)
  col_data <- df[[column]]
  col_data_num <- suppressWarnings(as.numeric(col_data))
  
  accuracy <- if (all(is.na(col_data_num))) NA_real_ else mean(!is.na(col_data_num) & col_data_num > -1e6 & col_data_num < 1e6, na.rm = TRUE)
  completeness <- mean(!is.na(col_data))
  consistency <- mean(sapply(col_data, function(x) is.numeric(x) || str_detect(as.character(x), "^[0-9.-]+$")), na.rm = TRUE)
  
  if (time_col %in% names(df)) {
    times <- as.POSIXct(gsub("Z$", "", df[[time_col]]), format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")
    diffs <- diff(times)
    std <- sd(as.numeric(diffs, units = "secs"), na.rm = TRUE)
    timeliness <- ifelse(length(diffs) > 1 && !is.na(std) && std < 600, 1, 0)
  } else {
    timeliness <- NA_real_
  }
  
  validity <- mean(!tolower(as.character(col_data)) %in% c("err", "error", "nan", "na", ""), na.rm = TRUE)
  uniqueness <- if (total > 0) length(unique(col_data)) / total else NA_real_
  
  return(c(accuracy, completeness, consistency, timeliness, validity, uniqueness))
}

check_data_quality <- function(sensor_tabellen, time_col = "Zeit") {
  dimensions <- c("Accuracy", "Completeness", "Consistency", "Timeliness", "Validity", "Uniqueness")
  
  result <- lapply(seq_along(sensor_tabellen), function(i) {
    df <- sensor_tabellen[[i]]
    sensor_name <- names(sensor_tabellen)[i]
    
    cols_to_check <- names(df)[sapply(df, function(x) any(!is.na(x)))]
    daten_spalten <- setdiff(cols_to_check, time_col)
    
    # 1️⃣ Nicht-Zeit-Spalten prüfen
    metrics_list <- lapply(daten_spalten, function(col) {
      metrics <- evaluate_quality(df, col, time_col = time_col)
      names(metrics) <- paste0(col, "_", dimensions)
      as.data.frame(t(metrics))
    })
    
    metrics_df <- if (length(metrics_list) > 0) do.call(cbind, metrics_list) else NULL
    
    # 2️⃣ Zeit-Spalte separat prüfen mit eigener Funktion
    if (time_col %in% names(df)) {
      zeit_metrics <- evaluate_quality_time(df, time_col, time_col = time_col)
      
      names(zeit_metrics) <- paste0(time_col, "_", dimensions)
      zeit_df <- as.data.frame(t(zeit_metrics))
    } else {
      zeit_df <- as.data.frame(t(setNames(rep(NA_real_, length(dimensions)), paste0(time_col, "_", dimensions))))
    }
    
    # 3️⃣ Zusammenfügen
    all_metrics <- cbind(metrics_df, zeit_df)
    data.frame(sensor = sensor_name, all_metrics, check.names = FALSE)
  })
  
  do.call(rbind, result)
}







# 🚀 4. Ausführen
quality_results <- check_data_quality(sensor_tabellen)

# 📤 5. Ausgabe speichern
write.csv(quality_results, "data_quality_report.csv", row.names = FALSE)

# 💡 Optional anzeigen
View(quality_results)