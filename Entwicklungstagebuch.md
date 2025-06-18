feat Simon: Aufbereitung und Auswählen der relevanten Daten

- Daten aus CSV-Dateien (InfluxDB-Export) eingelesen, gruppiert nach MQTT-Topic (Sensor-ID)
- Sensorwerte transformiert (Pivot), relevante Spalten ausgewählt und umbenannt

feat Simon: Bestimmung der Datenqualität anhand der 6 Datenqualitätsdimensionen

- Zwei Quality-Evaluation-Funktionen (`evaluate_quality`, `evaluate_quality_time`) implementiert
  zur Bewertung von Accuracy, Completeness, Consistency, Timeliness, Validity und Uniqueness
- `check_data_quality()` analysiert alle Sensor-Dataframes, berechnet Metriken pro Messwert
  und ergänzt eine Zusammenfassung der Qualitätsdimensionen pro Sensor (ohne Zeit)
- Ergebnis wird in `data_quality_report.csv` gespeichert
