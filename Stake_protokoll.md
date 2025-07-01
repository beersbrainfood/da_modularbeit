# Stakeholder:innen-Gespräch - Protokoll

## Allgemeine Informationen
Datum:              25.06.2025
Uhrzeit:            10:00 - 10:30
Raum:               3.013
Teilnehmer:innen:   
-   Gruppe 6: Aron Winter, Erik Kun, Eunseo Yi, Sandra Nguyen, Simon Paulus
-   Stakeholderin:  Sarah Brockhaus

## Ablauf
1. Vorstellungsrunde (3 Minuten)
2. Vorstellung aktueller Stand + Idee (10 Minuten)
3. Fragenklärung (17 Minuten)

### 1. Vorstellungsrunde
Die Teilnehmer:innen des Stakeholder:innen-Gespräch haben sich jeweils kurz vorgestellt.

Sarah Brockhaus:
-   Professorin für Data Science und Angewandte Mathematik
-   Hintergrund im Data Science Bereich

Eunseo Yi:
-   Bachelor im Wirtschaftsingenieurwesen
-   Master in Data Analytics

Erik Kun:
-   Bachelor im Wirtschaftsingenieurwesen
-   Master in Data Analytics

Simon Paulus:
-   Bachelor in Wirtschaftsmathematik
-   Master in Data Analytics

Aron Winter:
-   Bachelor in Informatik
-   Master in Informatik

Sandra Nguyen:
-   Bachelor in Wirtschaftsinformatik
-   Master in Informatik


### 2. Vorstellung aktueller Stand + Idee
Die Gruppe 6 hat in diesem Teil des Gesprächs ihren aktuellen Stand und die Idee zur Umsetzung des Dashboards vorgestellt. Während der Vorstellung hat die Stakeholderin einige Fragen gestellt, welche von der Gruppe 6 beantwortet wurden.

Gruppe 6:
-   Zuerst wurden die Daten angefragt und eingelesen aus der Datenbank. Die empfangenen Daten wurden in unterschiedliche Tabellen aufgeteilt und in jeweilige .csv Datein abgespeichert.
-   Die relevante .csv Datei wurde nach den Sensoren geordnet und es wurden Dataframes mit den Sensor und den jeweiligen Messwerten aufgebaut. Die Messwerte wurden auf die Qualitätsdimensionen untersucht und jeweils ein Dataframe erzeugt, in welchem die Qualitätsdimensionen der Messwerte ersichtlich sind.
-   Es wurden vorab mittels Brainstorming die Anforderungen an das Dashboard gesammelt sowie Fragen in welchem Umfang das Dashboard aufgebaut werden soll.

Fragen der Stakeholderin:
- Wie granular ist die Zeit? Ist sie regelmäßig?
    - Die Zeit ist relativ granular. Die Zeitabstände sind nicht immer regelmäßig.
- Was sind die Sensormesswerte?
    - Temperatur, Luftfeuchtigkeit, CO2 Konzentration, Lichtintensität, Bewegung und die Batteriespannung
- Welche sind die betrachteten Qualitätsdimensionen?
    - Accuracy, completeness, consistency, timeliness, validity und uniqueness
- Welche Qualitätsdimensionen werden für das Dashboard untersucht?
    - Alle sechs Dimensionen.

### 3.Fragenklärung
- Welche Optionen sollten für den Export aus dem Dashboard auswählbar sein?
    - Ein auswählbarer Start- und Endzeitpunkt, die zeitliche Frequenz.
- Wie sollte der Export aufgebaut sein?
    - Eine .csv Datei mit Zeitspalte und den sechs Qualitätsdimensionen in einzelnen Spalten zu den im Dashboard ausgewählten Sensoren.
- Sollen im Dashboard nur die bewerteten Qualitätsdimensionen enthalten sein oder auch noch die Messwerte?
    - Neben den Bewertungen zur Qualitätsdimensionen sollen auch die Messwerte enthalten sein. Eine Erklärung zur Berechnung der Qualitätsdimensionen ist hilfreich.

## Wesentliche Erkenntnisse
- Die Exportdatei soll eine csv. Datei sein mit einer Zeitspalte und den sechs bewerteten Qualitätsdimensionen.
- Im Dashboard sollte eine Registerkarte sein, welche anzeigt welcher Sensor in welchem Zeitraum gemessen hat.
- Im Dashboard sollte zusätzlich eine Exportfunktion für die Messwerte integriert sein.
- Im Dashboard sollte auswählbar sein, über welchen Zeitraum interpoliert wird.

## Ergänzungsmöglichkeiten für die Zukunft (Für unser Dashboard nicht relevant)
- Prüfung anhand der Messwerte, ob in dem Raum eine Veranstaltung stattfindet.
- Prüfung, ob man Lücken in den Messwerten auf eine fehlende Batteriespannung zurückführen kann.

