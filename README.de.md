# WLAN beim Laden für KOReader

*English: [README.md](README.md)*

KOReader schaltet das WLAN ab, wenn ein paar Minuten kaum Daten fließen (Einstellung „WLAN-Verbindung bei Inaktivität trennen“). Das spart Akku, unterbricht aber z. B. lange KI-Anfragen oder Downloads. Solange der E-Reader am Ladekabel hängt, verhindert dieses Plugin das. Auf Wunsch schaltet es das WLAN beim Einstecken auch ein.

## Was es kann

Menü: Zahnrad → Netzwerk → **„WLAN beim Laden“**, direkt unter „WLAN-Verbindung bei Inaktivität trennen“. Drei Stufen:

- **Aus:** KOReader verhält sich wie immer.
- **WLAN anlassen** (Standard): Am Ladekabel bleibt ein eingeschaltetes WLAN an. Von selbst eingeschaltet wird es nie. Die vorsichtige Wahl, z. B. an der Powerbank oder im Flugzeug.
- **WLAN anlassen und beim Einstecken einschalten:** Zusätzlich geht das WLAN kurz nach dem Einstecken an. Gut für zu Hause.

Nie von selbst eingeschaltet wird das WLAN,
- wenn du es von Hand ausgeschaltet hast (bis du es selbst wieder einschaltest),
- wenn das Plugin [AirPlaneMode](https://github.com/kodermike/airplanemode.koplugin) installiert und der Flugmodus an ist.

Ziehst du das Kabel ab, gilt wieder die normale Regel. Ausschalten von Hand geht immer.

## Installieren

1. Die ZIP-Datei unter [Releases](../../releases) herunterladen und entpacken, oder dieses Projekt herunterladen.
2. Den Ordner **`wifiwhilecharging.koplugin`** in KOReaders `plugins`-Ordner kopieren. Auf dem Kobo ist das `.adds/koreader/plugins/`.
3. KOReader neu starten.

## Wie es funktioniert

Am Ladekabel schläft der E-Reader nicht von selbst ein (dabei würde KOReader das WLAN ausschalten). Dafür nutzt das Plugin KOReaders eigenen Schalter. Hülle zuklappen und Einschaltknopf wirken weiter.

Außerdem zählt KOReader alle paar Minuten die gesendeten Datenpakete. Am Ladekabel meldet das Plugin dort „keine Messung“, dann überspringt KOReader das Abschalten. Diesen Fall sieht KOReader selbst vor. Ändert ein KOReader-Update diese interne Stelle, hängt sich das Plugin nicht ein und zeigt im Menü einen Hinweis, statt abzustürzen. Dann bitte ein [Issue](../../issues) anlegen.

## Getestet auf

Kobo Libra Colour mit KOReader 2026.07.1 und ZenOS.

## Wer das gemacht hat

Der Code wurde vollständig von **Claude** geschrieben, einer KI von Anthropic (in Claude Code). Der Inhaber dieses Projekts hatte die Idee, hat das Plugin auf dem Kobo getestet und Rückmeldungen gegeben, aber keinen Code geschrieben.

Es gibt keine Garantie und keinen festen Support. Fehlermeldungen sind als [Issue](../../issues) willkommen. Bitte die `crash.log` aus dem KOReader-Ordner anhängen.

## Lizenz

[MIT](LICENSE)
