# Fokusthema der Gruppe 6:

Entwicklung eines Dashboards zur Darstellung der **Datenqualität je
Sensor und je Raum** mit Exportfunktion (CSV), Zeitrastertransformation
und Spaltenauswahl.

## Phasen der Modularbeit:

-   Phase 1: Überblick über vorhandene Daten machen.
    -   Daten laden.
    -   Daten nach relevanten Sensordaten filtern.
    -   Daten nach den Dimensionen der Datenqualität bewerten.
-   Phase 2: Entwicklung des Dashboards.
    -   Genauen Anforderungen mit den Stakeholder:innen absprechen.
    -   Anforderungen an das Dashboard programmieren.
    -   Funktionen im Dashboard testen.

### Ziele der Phase 1:

-   Daten wurden erfolgreich geladen.
-   Auffälligkeiten und mögliche Probleme wurden notiert.
-   Gesamtdaten wurden auf die relevanten Daten gefiltert.
-   Gefilterte Daten wurden nach den Dimensionen der Datenqualität bewertet.

### Ziele der Phase 2:

-   Anforderungen der Stakeholder:innen wurden geklärt.
-   Dashboard zur Darstellung der Datenqualität wurde entwickelt.
-   Dashboard zur Darstellung der Datenqualität funktioniert
    ordnungsgemäß.

## Vorgehen:

### Abfrage, Verarbeitung und Speicherung von InfluxDB-Daten in R
- Zugriff auf eine InfluxDB-Instanz über eine Flux-Abfrage realisiert – URL, Token, Organisation und Bucket werden dynamisch aus der `config.yml` geladen.
- POST-Anfrage an die InfluxDB mit dem `httr`-Paket umgesetzt, inklusive Fehlerprüfung bei fehlgeschlagenem Response (Statuscode ≠ 200).
- Die Antwort im CSV-Format enthält mehrere Datenblöcke mit jeweils eigenem Header – daher wurde eine Block-Erkennung über `_time`-Headerzeilen implementiert.
- Jeder Block wird einzeln gelesen, mit `tryCatch` auf Lesefehler geprüft und als separate CSV-Datei gespeichert (`data/influx_block_*.csv`).
- Leere oder fehlerhafte Blöcke werden übersprungen, erfolgreiche Importe inklusive Zeilenanzahl geloggt.
- Der Code ist modular aufgebaut, über die Konfigurationsdatei leicht anpassbar und vorbereitet für spätere Erweiterungen (z. B. Zeitfilter, Visualisierungen).

### Aufbereitung und Auswahl relevanter Daten
Daten aus den exportierten CSV-Dateien (InfluxDB-Export) eingelesen.
- Gruppierung der Daten nach MQTT-Topic (Sensor-ID) zur Trennung der einzelnen Sensoren.
- Transformation der Messwerte vom Long- ins Wide-Format (Pivot).
- Auswahl und Umbenennung relevanter Spalten für lesbare Analysen und Visualisierungen.

### Bestimmung der Datenqualität anhand der sechs Qualitätsdimensionen
- Zwei Funktionen `evaluate_quality()` und `evaluate_quality_time()` zur Bewertung der Datenqualität implementiert.
- Die Funktion `check_data_quality()` analysiert alle Sensor-DataFrames, berechnet Metriken pro Messgröße und ergänzt eine zusammenfassende Bewertung pro Sensor.

#### Bewertete Qualitätsdimensionen

##### Für numerische Messgrößen (`evaluate_quality`)
- **Accuracy**: Liegen die Werte im definierten Wertebereich?
- **Completeness**: Gibt es fehlende Werte (NA)?
- **Consistency**: Sind die Werte einheitlich formatiert?
- **Timeliness**: Sind die zeitlichen Abstände gleichmäßig und plausibel?
- **Validity**: Sind die Werte numerisch interpretierbar?
- **Uniqueness**: Wie hoch ist der Anteil eindeutiger Werte? *(optional weglassbar)*

##### Für Zeitangaben (`evaluate_quality_time`)
- **Accuracy**: Haben alle Zeitstempel die gleiche Genauigkeit (z. B. Stringlänge)?
- **Completeness**: Gibt es fehlende Zeitwerte (NA)?
- **Consistency**: Sind alle Zeitangaben parsebar?
- **Timeliness**: *(nicht geprüft bei Zeit)*
- **Validity**: Liegen gültige Datumswerte vor (keine Fehlerstrings)?
- **Uniqueness**: Kommt jeder Zeitpunkt nur einmal vor?

Die Ergebnisse werden als `data_quality_report.csv` gespeichert und stehen für das Dashboard zur Verfügung.

### Erstellung einer Shiny-Dokuseite zur Datenqualitätsbewertung
- Erstellen einer Shiny-Dokuseite in der beschrieben wird, wie die einzelnen Datenqualitätsdimensionen bestimmt werden.

## Arbeitsorganisation:

-   Aron Winter:
    -   Daten einlesen.
    -   Übersicht zur Datenqualität exportieren.
-   Erik Kun:
    -   Dokumentation.
    -   Stakeholdergespräch.
-   Eunseo Yi:
    -   Plots erstellen.
    -   xx
-   Sandra Nguyen:
    -   Dashboard entwickeln.
    -   xx
-   Simon Paulus:
    -   Datenaufbereitung.
    -   xx
