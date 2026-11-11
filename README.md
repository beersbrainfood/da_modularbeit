# Data Quality Dashboard for Room-Climate Sensors

Master's group project (Hochschule München, SoSe 2025) · 5 students · R, Shiny, InfluxDB

**Problem:** Room-climate sensors (HMSENSE) continuously send measurements to an InfluxDB. The data arrive in long format, at irregular intervals and mixed with system monitoring data. Nobody could tell at a glance which sensors deliver reliable data.

**Goal:** A dashboard that scores each sensor's data quality and lets users explore and export the cleaned data.

## What we built
- **Data pipeline (R):**
  - loads the last 24 h from InfluxDB (Flux query)
  - filters the sensor data from the system data
  - extracts sensor IDs from MQTT topics
  - reshapes the data from long to wide format
  - aligns timestamps to a regular time grid
- **Quality scoring:** each sensor is rated on six dimensions: accuracy, completeness, consistency, timeliness, validity and uniqueness
- **Shiny app:**
  - overview table of quality metrics per sensor
  - filters by sensor, date range and time
  - raw-data detail view
  - quality visualizations
  - explanation of each dimension
  - CSV export at a chosen frequency

![Dashboard overview](README_Screenshots/dashboard_uebersicht.png)

## My contribution: quality visualizations
![Quality plots](README_Screenshots/dashboard_plot.png)
- **Per-sensor bar chart:** normalized quality metrics across six measurements (temperature, humidity, CO₂, light, motion, battery), with sensor selection via dropdown
- **Multi-sensor heatmap:** compares quality metrics across several sensors at once, with multi-select and reset

## How to run
1. Open `dashboard.Rproj` in RStudio. The scripts use relative paths.
2. Install the required packages: `source("setup_install.R")`
3. *(Optional, needs InfluxDB access via `config.yml`)* Load and prepare fresh data:
   `source("shiny/01_load_data.R")` → `source("shiny/02_prepare_sensor_data.R")`
4. Start the app: `shiny::runApp("shiny/app.R")`

Sample data (13–14 June 2025) is included in `data/`, so the app runs without database access.

## Repository
- `shiny/`: data loading, preparation and the Shiny app
- `data/`: sample sensor data and the generated quality report
- `README_de.md`: original detailed German documentation, incl. the data-format analysis
- `Entwicklungstagebuch.md`, `Stake_protokoll.md`: development log and stakeholder interview notes (German)
