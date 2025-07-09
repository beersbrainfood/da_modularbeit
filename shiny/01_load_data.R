library(yaml)

# Build full config path
config <- yaml::read_yaml("config.yml")

# Access nested values
hmsense_config <- config$default$hmsense

url    <- hmsense_config$url
token  <- hmsense_config$token
org    <- hmsense_config$org
bucket <- hmsense_config$bucket

# Compose Flux query
flux_query <- paste0(
  'from(bucket: "', bucket, '")',
  ' |> range(start: -1d)'
)

library(httr)

# Send POST request to InfluxDB
################# TAKES SOME TIME ##################
response <- httr::POST(
  url = paste0(url, "api/v2/query?org=", org),
  add_headers(
    Authorization = paste("Token", token),
    `Content-Type` = "application/vnd.flux",
    Accept = "application/csv"
  ),
  body = flux_query,
  encode = "raw"
)

# Check if query failed
if (status_code(response) != 200) {
  stop("Query failed: ", status_code(response), "\n", content(response, "text"))
}

# 1. Get raw CSV response
csv_text <- content(response, as = "text", encoding = "UTF-8")
lines <- strsplit(csv_text, "\n")[[1]]

# 2. Find indices of header lines (e.g., lines with _time, _value, etc.)
header_indices <- grep("(^|,)X?_time(,|$)", lines)  # detects "_time" or "X_time" as header

# 3. Add end-of-file as final boundary
header_indices <- c(header_indices, length(lines) + 1)

# 4. Iterate through each block between headers and save as CSV
for (i in seq_along(header_indices[-length(header_indices)])) {
  start <- header_indices[i]
  end <- header_indices[i + 1] - 1
  
  block_lines <- lines[start:end]
  
  # Skip empty blocks
  if (length(block_lines) < 2) next
  
  # Combine block into CSV text
  block_text <- paste(block_lines, collapse = "\n")
  
  # Try reading as CSV
  df <- tryCatch(
    read.csv(text = block_text),
    error = function(e) {
      message("⚠️ Skipping malformed block ", i)
      return(NULL)
    }
  )
  
  if (!is.null(df)) {
    filename <- sprintf("data/influx_block_%d.csv", i)
    write.csv(df, filename, row.names = FALSE)
    cat("✅ Wrote", filename, "with", nrow(df), "rows\n")
  }
}
