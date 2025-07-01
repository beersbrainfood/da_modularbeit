# README - Gruppe 6

# Inhalte der README
- Management Summary
- Verzeichnisstruktur
- Schritt-für-Schritt Anleitung
- Weitere Dokumentationsabschnitte

## Management Summary
- **Ziel:**
    - Entwicklung eines Dashboards zur Übersicht der Datenqualität von Raumklimasensoren aus HMSENSE.
    - Möglichkeit im Dashboard die Daten im CSV-Format zu exportieren.
- **Ansatz:**
    - Umsetzung der Funktionen mit R. und Aufbau des Dashboards mittels Shiny.
- **Funktionalitäten des Prototyps:**
    - Datenimport
    - XXX
    - XXX

## Verzeichnisstruktur

```text
📁 data/
 ├── influx_block_7.csv         # Relevante Sensordaten (z. B. Temperatur, CO₂)
 ├── EXPORTDATEI                # Exportdatei aus dem Dashboard
 └── data_quality_report.csv    # Analyseergebnisse der Datenqualität
📄 README.md                    # Diese Datei
📄 Entwicklungstagebuch.md      # Entwicklungstagebuch
📄 Stake_protokoll.md           # Protokoll des Stakeholder:innen Gespräch
💻 setup_install.R              # Installationsbefehle
```

## Schritt-für-Schritt-Anleitung
1. XXX
2. XXX
3. XXX

## Weitere Dokumentationsabschnitte

### *Lösung für Aufgabe 1*

#### Aufgabe 1 – Überblick Datenformat & Transformation

##### 1. Datenabfrage

Die Daten werden über folgende Flux-Abfrage aus der InfluxDB geladen:

```flux
from(bucket: "raumklimasensoren") |> range(start: -1d)
```

Dabei werden alle Daten der letzten 24 Stunden aus dem im `config.yaml` angegebenen Bucket geladen.  
Die Daten werden beim Einlesen automatisch in mehrere CSV-Dateien aufgeteilt (`influx_block_1.csv` bis `influx_block_7.csv`).

---

##### 2. Beobachtungen zu den Daten

- **Formatstruktur**: Alle Dateien enthalten Spalten wie `_time`, `_field`, `_value`, `mqtt_topic`, `host` usw.
- **Datenlayout**: Die Struktur ist im Long-Format. Messgrößen stehen untereinander (`_field`) und die zugehörigen Werte daneben (`_value`).
- **Systemdaten**: Die meisten Dateien enthalten keine Sensordaten, sondern interne Monitoring-Daten (z. B. Fehlerzähler, Buffergrößen).
- **Sensordaten**: Nur `influx_block_7.csv` enthält echte Raumklima-Sensordaten (z. B. CO₂) mit `mqtt_topic`.
- **Zeitformat**: Die Zeitstempel liegen im UTC-Format mit Nanosekundenauflösung vor (`X_time`).
- **Sensorbezug**: Der Sensorname kann aus dem `mqtt_topic`-Pfad extrahiert werden (z. B. `"sensor09"`).
- **Raumbezug**: Es existiert kein explizites Feld für Raumangaben. Eine Zuordnung müsste ggf. manuell ergänzt werden.
- **Zeitabstände**: Die Daten kommen nicht gleichmäßig verteilt (asynchron) und erfordern eine Transformation auf ein gleichmäßiges Zeitraster.

---

##### 3. Probleme und pragmatische Lösungen

| Problem                                 | Lösungsvorschlag                                                              |
|----------------------------------------|-------------------------------------------------------------------------------|
| Systemdaten im Datensatz enthalten     | Nur Daten mit `mqtt_topic` und `uplink_message_*` berücksichtigen            |
| Daten im Long-Format                   | Umwandlung in Wide-Format mit `pivot_wider()`                                |
| Sensorname nicht direkt als Spalte     | Extraktion aus `mqtt_topic` mit regulärem Ausdruck (`sensor[0-9]+`)          |
| Kein Raum-Feld vorhanden               | Manuelle Zuordnung von Sensoren zu Räumen (z. B. über Mapping-Tabelle)       |
| Zeitstempel mit Nanosekunden, unregelmäßig | Konvertierung zu `POSIXct`, anschließend auf z. B. 15-Minuten-Raster runden |

---

##### 4. Weiteres Vorgehen

Für das Dashboard zur Übersicht der Datenqualität ist nur die Datei `influx_block_7.csv` relevant.  
Alle anderen Dateien enthalten ausschließlich technische Monitoring-Daten ohne Sensorbezug und werden daher ausgeschlossen.

Für die Weiterverarbeitung sind folgende Transformationen erforderlich:

- Filtern der relevanten Sensor-Messwerte
- Umwandlung ins Wide-Format für nutzerfreundliche Analyse
- Normierung der Zeitabstände auf gleichmäßige Intervalle
- *(Optional)*: Ergänzung einer Sensornamen-Raum-Zuordnung
