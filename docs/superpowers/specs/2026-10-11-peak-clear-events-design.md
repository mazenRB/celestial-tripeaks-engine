# Gipfel-Ereignisse im Zugergebnis

## Ziel

Ein erfolgreiches Zugergebnis weist alle Gipfel aus, die durch genau diesen
Zug erstmals als abgeräumt gewertet wurden, einschließlich der pro Gipfel
gutgeschriebenen Punkte. Verbraucher müssen dafür keine Zustände vergleichen
und keine Wertungsregeln nachbilden.

## Schnittstelle

`TriPeaksReduceResult` erhält das Feld `peakClearedEvents` als unveränderliche
Liste von `PeakClearedEvent`-Werten. Jeder Eintrag enthält eine stabile,
nullbasierte `peakId` und `pointsAwarded`. Die IDs folgen der vorhandenen
Gipfeldefinition in `TriPeaksState` (0 bis 2). Das Ereignis ist ein
serialisierbarer Engine-Datentyp mit `type`- und `schemaVersion`-Feldern sowie
`toMap` und fehlertolerantem `tryFromMap`, entsprechend den vorhandenen
Serialisierungskonventionen.

Ein ungültiger Zug und ein gültiger Zug ohne neue Gipfel liefern eine leere
Liste. Jeder neue Gipfel wird genau einmal gemeldet. Falls ein Zug mehrere
Gipfel zugleich erstmals abräumt, enthält die Liste für jeden einen Eintrag.
Ein neuer Gipfel bleibt auch dann ein Ereignis, wenn seine konfigurierte
Punktzahl null beträgt.

## Wertung und Datenfluss

Die Reducer-Wertung bleibt maßgeblich. Die neue Information wird aus derselben
Erkennung neu abgeräumter Gipfel gewonnen, die bereits die Gipfelprämie
berechnet. `pointsAwarded` entspricht der konfigurierten Prämie je Gipfel
(`ScoreConfig.pointsPeakCleared`); die bestehende Regel wendet den Zugmultiplikator
nicht auf diese Prämie an. Die Summe der Ereignispunkte entspricht daher dem
Gipfelanteil `scoreBreakdown.peakBonusPoints` des Zuges.

Die Ereignisse enthalten ausschließlich stabile IDs und Zahlen. UI-Texte,
Farben, Animationen oder Zeitabhängigkeiten gehören nicht in die Engine.

## Kompatibilität

Die bestehende API und die Felder des Zugergebnisses bleiben erhalten; die
Ereignisliste wird additiv ergänzt. Das serialisierbare Ereignis erhält eine
eigene Schema-Version. Die Spielzustands- und Aktionsformate ändern sich nicht.

## Tests

- Zug ohne neu abgeräumten Gipfel: Ereignisliste ist leer.
- Erstmaliges Abräumen: ID und konfigurierte Punkte stehen im Ereignis; die
  Gipfelprämie wird wie bisher nur einmal angerechnet.
- Bereits gewerteter Gipfel: späterer Zug meldet ihn nicht erneut.
- Ein Zug räumt mehrere noch nicht gewertete Gipfel ab: alle IDs werden
  gemeldet und die Ereignispunktesumme entspricht der Breakdown-Prämie.
- Null konfigurierte Gipfelpunkte: ein neu abgeräumter Gipfel wird mit null
  Punkten gemeldet.
- Ereignis-Map lässt sich erfolgreich dekodieren; unbekannte oder ungültige
  Payloads liefern den etablierten Decode-Fehler.

Zusätzlich müssen `dart analyze` und `dart test` erfolgreich sein.
