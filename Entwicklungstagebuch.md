feat Simon: Aufbereitung und Auswählen der relevanten Daten

- Daten aus CSV-Dateien (InfluxDB-Export) eingelesen, gruppiert nach MQTT-Topic (Sensor-ID)
- Sensorwerte transformiert (Pivot), relevante Spalten ausgewählt und umbenannt

feat Simon: Bestimmung der Datenqualität anhand der 6 Datenqualitätsdimensionen

- Zwei Quality-Evaluation-Funktionen (`evaluate_quality`, `evaluate_quality_time`) implementiert
  zur Bewertung von Accuracy, Completeness, Consistency, Timeliness, Validity und Uniqueness
- `check_data_quality()` analysiert alle Sensor-Dataframes, berechnet Metriken pro Messwert
  und ergänzt eine Zusammenfassung der Qualitätsdimensionen pro Sensor (ohne Zeit)
- Ergebnis wird in `data_quality_report.csv` gespeichert
- Anwendung der beiden Funktionen für jeden Sensordatensatz einzeln
-`evaluate_quality`: - Accuracy: Liegen die Werte im definierten Wertebereich
                     - Completeness: Sind NA's da
                     - Consistency: Sind alle Werte einer Spalte gleich formatiert
                     - Timeliness: Sind die zeitlichen Abstände gleichmäßig und plausibel
                     - Validity: Sind alle Werte numerisch
                     - Uniqueness: Gibt es doppelte Werte (Macht für die Messwerte eher nicht so viel Sinn. Weglassen?)
-`evaluate_quality_time`: - Accuracy: Sind alle Zeitangaben in der gleichen Genauigkeit
                          - Completeness: Gibt es NA'so
                          - Consistency: Sind alle Zeitangaben einheitlich parsebar
                          - Timeliness: Wird für Zeit nicht geprüft
                          - Validity: Zulässiges Datumsform, ohne irgendwelche Zeichenfolgen
                          - Uniqueness: Gibt es jeden Zeitpunkt nur einmal 
