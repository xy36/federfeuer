# Federfeuer – Game Design Document
 
Sep 30, 2026 · @Chris
 
## Überblick
 
Federfeuer ist ein 2D-Arena-Shooter im Stil von Brotato, bei dem der Spieler fliegt statt läuft: In 15 Wellen fliegt er jeweils von links nach rechts zum Ziel, am Ende besiegt er den Geierkönig. Dieses Dokument beschreibt den Stand des Prototyps (Web-Version und Flutter/Flame-Port) und dient als Vorlage für die Weiterentwicklung.
 
| Aspekt | Festlegung |
| --- | --- |
| Genre | Arena-Shooter / Roguelite-Light, Runs von ca. 12–15 Minuten |
| Perspektive | 2D-Seitenansicht mit leichter Schrägsicht (Bodenschatten, Parallax) |
| Plattform | Flutter + Flame; zuerst Android/iOS im Querformat, Desktop mit Tastatur; Controller auf allen Plattformen |
| Zielgruppe | Gelegenheitsspieler, die kurze Runs mit Build-Entscheidungen mögen |
| Held | „Kampfspatz“ – leuchtender, goldener Geistvogel mit Fliegerbrille |
 
Designpfeiler:
 
- **Eine Taste zum Fliegen:** Die Flugsteuerung ist das Alleinstellungsmerkmal. Ausweichen passiert vertikal und horizontal.
- **Waffen zielen selbst:** Der Spieler kümmert sich nur um Position und Build, nicht ums Zielen.
- **Kurze Entscheidungen zwischen Wellen:** Level-up und Shop sind schnell lesbar und in unter 30 Sekunden erledigt.
 
## Kernloop
 
Ein Run besteht aus 15 Wellen; zwischen den Wellen trifft der Spieler Build-Entscheidungen, bevor es weitergeht.
 
&#91;embedded content: Kernloop · Welle, Level-up, Shop, Boss\]
 
Wellen 1–14 enden, sobald der Spieler das Ziel am rechten Weltende erreicht oder der Timer abläuft; danach folgen Level-ups (nur wenn XP gereicht hat) und der Shop. Jede Welle dauert länger und ist schwerer als die vorige. Nach Welle 14 führt der Shop in die Bosswelle, die erst mit dem Tod des Geierkönigs endet. HP auf 0 beendet den Run in jeder Welle.
 
## Steuerung & Bewegung
 
Halten lässt den Vogel steigen, Loslassen lässt ihn langsam gleiten; links/rechts bewegt ihn frei in beide Richtungen. Alle Werte sind in Welteinheiten pro Sekunde (virtuelle Bildhöhe = 540).
 
| Eingabe | Tastatur | Touch | Controller |
| --- | --- | --- | --- |
| Links / rechts | A / D oder Pfeiltasten | Buttons ◀ ▶ unten links | Linker Stick (Totzone 0,35) oder Steuerkreuz |
| Fliegen (halten) | Leertaste, W oder ↑ | Button „Flug“ unten rechts | A, RB oder RT |
| Pause | P oder Esc | Button oben rechts | Start; in der Pause B zum Weiterspielen |
| Vollbild / Fenster (PC) | F11 oder Alt+Enter; Knopf im Startmenü und in der Pause | – | – |

Controller folgen der Xbox-Standardbelegung (Paket `gamepads`); mehrere angeschlossene Controller steuern gemeinsam. Sobald ein Controller benutzt wurde, werden die Touch-Buttons ausgeblendet.

Am PC (Windows, macOS, Linux) startet das Spiel im Vollbild; die Wahl Vollbild/Fenster wird gespeichert. Im Fenstermodus ist es 1280 × 720 groß, mindestens 960 × 540. Während des Spielens ist der Mauszeiger ausgeblendet, in Menüs sichtbar.
 
| Parameter | Wert |
| --- | --- |
| Maximale Horizontalgeschwindigkeit | 230 × (1 + Tempo %), mindestens 40 % |
| Horizontale Beschleunigung | 1500 |
| Ausrollen ohne Eingabe | Geschwindigkeit × 0,002 pro Sekunde |
| Schwerkraft | 650 |
| Schub beim Halten | 1250 (netto 600 nach oben) |
| Steiggeschwindigkeit max. | 340 |
| Fallgeschwindigkeit beim Gleiten max. | 150 |
| Kollisionsradius Spieler | 16 |
| Unverwundbarkeit nach Treffer | 0,6 s (Blinken) |
 
Am Boden kann der Spieler laufen, an der Decke wird er gestoppt. Der Vogel neigt sich je nach Vertikalgeschwindigkeit, die Flügel schlagen beim Fliegen schneller.
 
## Arena & Kamera
 
Die Welt ist 540 Einheiten hoch; ihre Breite wächst mit der Welle. Der Spieler startet links, das Ziel liegt am rechten Ende. Die Kamera folgt ihm nur horizontal, zurück nach links darf er jederzeit.

- **Weltbreite:** Mit Grundtempo (230) ist die Strecke in 3/5 der Wellenzeit durchflogen: Breite = 230 × 0,6 × Wellendauer. Welle 1 = 2760, Welle 9 = 7176, Welle 14 = 9936.
- **Bosswelle:** Feste Arena von 2400 ohne Ziel, Start in der Mitte.
- **Ziel:** Lichtsäule mit aufsteigenden Lichtkugeln und leuchtendem Fuß, 90 vor dem rechten Weltende.
 
- **Grenzen:** Boden bei y = 468, Decke bei y = 24, links und rechts leuchtende Lichtvorhänge in der Kantenfarbe der Welt. Außerhalb wird abgedunkelt.
- **Kamera:** Zoom = min(Bildhöhe / 540, Bildbreite / 560). Sie führt leicht in Flugrichtung vor (Geschwindigkeit × 0,35) und folgt weich nach. Im Hochformat wird oben mehr Himmel gezeigt.
- **Kamerawackeln:** 8 bei Spielertreffer, 5 bei Explosionen, 20 beim Tod des Bosses; klingt schnell ab.
- **Tiefenwirkung:** Jede Figur wirft einen Schatten auf den Boden, der mit der Flughöhe kleiner und blasser wird. Dahinter vier Silhouetten-Ebenen mit Parallax (Faktor 0,12 / 0,26 / 0,45 / 0,68), nach hinten heller und dunstiger, mit Dunstbändern dazwischen. Davor ein unscharfer, dunkler Vordergrund mit Parallax 1,35, der überwiegend unter der Bodenlinie bleibt.
- **Randpfeile:** Leuchtende, rosarote Pfeile am Bildschirmrand zeigen Gegner außerhalb des sichtbaren Bereichs.
 
Stil der Spielwelt: leuchtend und geschichtet, angelehnt an die Stimmung von „Ori and the Blind Forest“ (keine übernommenen Inhalte). Dunkle Silhouetten mit leuchtenden Lichtkanten, weiche Lichthöfe, lebendige Lichtstrahlen (8 weiche Strahlen je Lichtquelle; jeder wandert langsam, atmet und blendet in einem eigenen Rhythmus von 20–40 s auf und ab; sie fallen vor den mittleren Ebenen durch das Bild, nur die vorderste Ebene liegt davor), schwebende Lichtpartikel, leuchtende Pflanzen und eine Vignette. Leuchten wird über eine einmal gerenderte Glow-Textur additiv gezeichnet. Weichzeichner über große Flächen gibt es bewusst nicht (auf großen Bildschirmen zu teuer); weiche Kanten entstehen über Farbverläufe. Die Hintergrundebenen füllen nur bis knapp unter die nächste Ebene, um Überzeichnung zu sparen. Silhouetten (Hintergrundebenen, Schnee, Boden, Kulisse, Vordergrund) werden selbst in Dreiecke zerlegt und je Ebene mit einem `drawVertices`-Aufruf gezeichnet – große zusammengesetzte Pfade füllt die Engine sonst per Stencil über die ganze Hüllfläche. Viele gleichartige Leuchtpunkte werden gesammelt in einem Aufruf gezeichnet (Gegner-Leuchten in zwei Durchgängen hinter und vor den Körpern, Partikel, Funken), der Regen ebenso. Mit den Welten wandert das Licht von der goldenen Stunde bis in die Nacht. Sonnengelb bleibt die Farbe des Helden, Mint die des Materials. Umbau in Etappen: 1. Welt und Licht, 2. Held, Gegner, Projektile und Effekte, 3. HUD und Menüs – alle fertig.

Figuren und Effekte:

- **Held:** Lichtkern mit weichem Verlauf, durchscheinende Lichtflügel, die beim Flügelschlag aufleuchten, Lichtschweif aus den letzten Positionen, goldene Aura; er erhellt den Boden unter sich (je höher, desto schwächer). Die Fliegerbrille hat leuchtende Gläser.
- **Gegner:** fast schwarze „Fäulnis“-Kreaturen mit violetter Aura und glühenden Augen; Krähe mit zerfransten Flügeln, Käfer mit glühenden Panzerrissen, Spucker mit grün pulsierendem Giftsack, Brocken mit Glutadern (HP-Leiste als Glutstreifen), Geierkönig mit Krone aus magentafarbenen Lichtsplittern und pulsierender Aura. Bei Treffern blitzen die Körper hell auf; beim Tod zerfallen sie in violette Funken.
- **Waffen & Kugeln:** Waffen schweben als Lichtsplitter in Stufenfarbe und zeigen aufs Ziel, mit Mündungsblitz beim Schuss. Eigene Kugeln sind leuchtende Kugeln mit weißem Kern und Schweif (Krit gold), Gegnerkugeln haben einen dunklen Kern mit farbigem Leuchten.
- **Drops:** Material als leuchtender Mint-Kristall, Herz als leuchtendes Herz; beide pulsieren.

## Welten

Der Run führt durch fünf Welten, die sich nach der Welle richten. Welten bestimmen Kulisse (Himmel, Licht, Ebenen, Boden, Objekte) und Wetter (siehe „Wetter“); Gegner, Spawns und Werte hängen weiter nur an der Wellennummer. Beim Betreten einer neuen Welt steht ihr Name über dem Wellenbanner, der Shop davor kündigt sie an.

| Welt | Wellen | Licht | Ebenen | Boden & Kulisse |
| --- | --- | --- | --- | --- |
| Felder | 1–4 | Goldene Stunde, Sonne mit Strahlen, goldene Kanten | Flache Hügel mit einzelnen Bäumen und Windmühle | Weizen, Zäune, Vogelscheuchen, Bäume als Silhouetten; leuchtende Blüten, Pollen |
| Dorf | 5–8 | Dämmerung, warme Kanten | Hügel mit Ruinen und Türmen, einzelne erleuchtete Fenster | Eingestürzte Mauern mit Fensterlicht, Laternen, Zäune; Glut am Boden |
| Wald mit Fluss | 9–12 | Nachtblau, Mond mit Strahlen, türkise Kanten | Dichter Wald, vorn riesige Stämme bis aus dem Bild | Farne, Stämme, große Leuchtpilze, hängende Ranken; leuchtender Fluss |
| Gebirge | 13–14 | Blaue Stunde, Mond, schwache Strahlen | Spitze Gipfel (× 1,7), hintere Ketten mit Schnee entlang der Grate, Latschen | Findlinge, Latschen; leuchtende Kristalle |
| Gipfel | 15 (Boss) | Nacht mit Mond, Sternen und Polarlicht | Verschneite Gipfel tief unten | Schneewehen, Felsen, Gipfelkreuz mit glimmenden Gebetsfahnen in der Arenamitte; Eiskristalle |

Im Menü ist die Felder-Kulisse zu sehen. Die Kulisse wird nur im sichtbaren Ausschnitt gezeichnet; Art und Position jedes Objekts hängen fest am Index, sodass eine Welt bei jedem Besuch gleich aussieht.
 
## Waffen
 
Der Spieler trägt bis zu 6 Waffen, die als Lichtsplitter im Kreis um ihn schweben und jeweils selbstständig auf den nächsten Gegner in Reichweite feuern. Zu Beginn wählt er Pistole, Maschinenpistole oder Schrotflinte.
 
| Waffe | Schaden | Abklingzeit (s) | Reichweite | Projektil-Tempo | Besonderheit | Basispreis |
| --- | --- | --- | --- | --- | --- | --- |
| Pistole | 8 | 0,75 | 330 | 720 | Allrounder | 15 |
| Maschinenpistole | 3 | 0,18 | 270 | 760 | Streuung 0,22 rad | 18 |
| Schrotflinte | 5 × 5 | 1,15 | 210 | 640 | 5 Kugeln im 0,6-rad-Fächer | 20 |
| Railgun | 22 | 1,7 | 470 | 1500 | Durchschlägt alle Gegner | 28 |
| Raketenwerfer | 15 | 1,6 | 390 | 420 | Explosion, Radius 75 | 30 |
 
**Stufen:** Jede Waffe gibt es in Stufe I bis IV. Eine gekaufte Waffe kommt immer in einen freien Slot, auch wenn der Spieler sie in gleicher Stufe schon besitzt. Zwei gleiche Waffen gleicher Stufe (unter IV) kann er im Shop per Knopf am Waffenslot verschmelzen: Der angetippte Slot steigt eine Stufe auf, der andere wird frei. Ketten laufen nicht automatisch, jeder Schritt ist ein eigener Klick.
 
| Stufe | Farbe | Schaden | Abklingzeit | Preis |
| --- | --- | --- | --- | --- |
| I | Grau | × 1,0 | × 1,0 | × 1,0 |
| II | Blau | × 1,7 | × 0,9 | × 1,9 |
| III | Lila | × 2,7 | × 0,8 | × 3,3 |
| IV | Rot | × 4,2 | × 0,7 | × 5,5 |
 
Endwerte: Schaden × (1 + Schaden %), Abklingzeit ÷ (1 + Angriffstempo %) mit Untergrenze Faktor 0,3, Reichweite + Reichweiten-Bonus. Jede Kugel würfelt einzeln auf einen kritischen Treffer (doppelter Schaden, gelbe Zahl).
 
## Gegner
 
Fünf Gegnertypen mit klar unterscheidbarem Verhalten; Schaden entsteht durch Berührung oder Projektile. Werte gelten für Welle 1.
 
| Gegner | Ab Welle | HP | Tempo | Schaden | Radius | Material | Verhalten |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Krähe | 1 | 6 | 95 | 2 | 13 | 1 | Fliegt direkt auf den Spieler zu, leichtes Auf und Ab |
| Käfer | 2 | 12 | 75 | 3 | 15 | 1 | Läuft am Boden, springt hoch, wenn der Spieler über ihm ist (alle 1,5–2,5 s) |
| Spucker | 3 | 9 | 70 | 2 | 14 | 1 | Hält 200–300 Abstand, schießt alle \~2,4 s eine Kugel (Tempo 240) |
| Brocken | 5 | 45 | 42 | 5 | 27 | 3 | Langsamer, schwerer Verfolger mit HP-Leiste |
| Geierkönig (Boss) | 15 | 4500 | 55 | 6 | 52 | – | Schwebt, Fächer aus 7 Kugeln alle 1,5 s, ruft alle 6 s drei Krähen |
 
Skalierung pro Welle w (gilt nicht für den Boss):
 
- HP × (1 + 0,38 · (w − 1))
- Schaden × (1 + 0,15 · (w − 1)), gerundet
- Tempo × (1 + 0,02 · w)
 
Gegner stoßen sich gegenseitig ab, damit sie sich nicht stapeln. Treffer werfen sie leicht zurück und lassen sie kurz weiß aufblitzen.
 
## Wellen & Spawns
 
Wellen 1–14 laufen auf Zeit, Welle 15 endet erst mit dem Tod des Bosses. Zu Beginn jeder Welle wird der Spieler voll geheilt und an den Start gesetzt (x = 120; Bosswelle: Arenamitte).
 
- **Dauer:** 20 s + 4 s pro Welle ohne Obergrenze (Welle 1 = 20 s, Welle 9 = 52 s, Welle 14 = 72 s).
- **Ende:** Erreicht der Spieler das Ziel, ist die Welle sofort bestanden und er bekommt ⌊Restzeit / 2⌋ Material als Zeitbonus. Läuft vorher der Timer ab, ist die Welle ebenfalls bestanden, aber ohne Bonus.
- **Steigende Schwierigkeit:** Gegnerwerte (siehe Skalierung), Gruppengröße und der Anteil von Spuckern und Brocken wachsen mit jeder Welle weiter. Das Spawn-Intervall erreicht ab Welle 10 seine Untergrenze von 0,9 s.
- **Spawn-Intervall:** max(0,9; 2,4 − 0,15 · w) s, zufällig ±30 %; in der Bosswelle × 1,7.
- **Gruppengröße:** 1 + ⌊w / 2,5⌋, mit 40 % Chance einer mehr. Die Gruppe erscheint gebündelt an einer Stelle im sichtbaren Bild: mindestens 280 vom Spieler entfernt, höchstens bis 40 vor den Bildrand (und nie weiter als 700), mit 65 % Chance vor ihm (in Richtung Ziel). Ist der Bildschirm auf der Seite zu schmal, erscheint sie im Mindestabstand knapp außerhalb; fehlt am Weltrand der Platz, kommt sie von der anderen Seite. In der Bosswelle erscheint sie irgendwo in der Arena, mindestens 280 entfernt.
- **Warnung:** Ein pulsierender Fäulnis-Riss (dunkler Kern, violett-rotes Leuchten, der sich bis zum Erscheinen schließt) markiert jeden Spawn 0,9 s vorher (Boss: 2 s, größer).
- **Obergrenze:** keine neuen Spawns bei mehr als 110 lebenden Gegnern.
- **Nachzügler:** Gegner, die mehr als 1400 hinter dem Spieler zurückliegen, verschwinden ohne Drop (nicht in der Bosswelle).
- **Gewichtung:** Krähe 10, Käfer 7, Spucker 4 + 0,3 · w, Brocken 2 + 0,3 · w.
 
Am Wellenende verpuffen alle Gegner und Projektile. Material, das schon zum Spieler fliegt, wird noch gutgeschrieben; alles, was noch am Boden liegt, verfällt. Die Szene steht dann 1,2 s still mit der Einblendung „WELLE X GESCHAFFT“ und darunter „Ziel erreicht! +N Zeitbonus“ bzw. „Zeit abgelaufen“; erst danach erscheinen Level-up oder Shop. Wer zum Ziel eilt, tauscht also zurückgelassene Beute gegen den Zeitbonus.
 
## Schwierigkeitsstufen

Es gibt fünf Stufen. Zu Beginn ist nur Küken spielbar; wer eine Stufe gewinnt, schaltet die nächste frei. Gewählt wird im Startmenü, die Wahl bleibt gespeichert.

| Stufe | Name | Gegner-HP | Gegner-Schaden | Spawnrate | Schlechtwetter (Grundchance) | Drops |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Küken | × 1,0 | × 1,0 | × 1,0 | 20 % | schweben |
| 2 | Spatz | × 1,15 | × 1,1 | × 1,1 | 35 % | schweben |
| 3 | Falke | × 1,3 | × 1,25 | × 1,2 | 50 % | sinken sehr langsam (12) |
| 4 | Adler | × 1,5 | × 1,4 | × 1,3 | 65 % | sinken (35) |
| 5 | Phönix | × 1,75 | × 1,6 | × 1,4 | 80 % | fallen zu Boden (70) |

- **HP und Schaden** werden nach der Wellenskalierung multipliziert und gelten auch für den Boss (Schaden gerundet).
- **Spawnrate:** Das Spawn-Intervall wird durch den Faktor geteilt.
- **Schlechtwetter:** 20 % + 15 % pro Stufe über 1, dazu der Zuschlag der Welt (siehe „Wetter“).
- **Fortschritt:** Gespeichert werden die höchste freigeschaltete Stufe, die gewählte Stufe, die Bestleistung pro Stufe und eine Statistik (Runs, Siege, besiegte Gegner gesamt, höchstes Level). Die Bestleistung aus der Zeit vor den Stufen zählt für Küken.
- **Debug-Modus:** In Debug-Builds (oder mit `--dart-define=FEDERFEUER_DEBUG=true`) gibt es im Startmenü einen Schalter, der alle Stufen freigibt. Er wird nicht gespeichert; Siege im Debug-Modus zählen trotzdem für den Fortschritt.

## Wetter

Zu Beginn jeder Welle wird das Wetter gewürfelt; es bleibt die ganze Welle über gleich. Wetter verändert die Flugphysik und zwingt so zu anderen Ausweichmustern. Bisher gibt es Klar, Wind und Regen; Nebel, Gewitter, Hitze und Schnee sind geplant.

- **Häufigkeit:** Chance auf schlechtes Wetter = 20 % + 15 % pro Schwierigkeitsstufe über 1 (Stufe 1–5) + Zuschlag der Welt, begrenzt auf 100 %. Sonst ist es klar. Das schlechte Wetter kommt gleichverteilt aus dem Wetter-Pool der Welt.

| Welt | Wetter-Pool | Zuschlag | Chance (Küken) |
| --- | --- | --- | --- |
| Felder | Wind, Regen | 0 | 20 % |
| Dorf | Regen | 0 | 20 % |
| Wald mit Fluss | Regen | +15 % | 35 % |
| Gebirge | Wind | +25 % | 45 % |
| Gipfel | Wind | +40 % | 60 % |

| Wetter | Wirkung |
| --- | --- |
| Klar | Keine |
| Wind | Seitlicher Drift von 80 auf Spieler, Gegner und alle Kugeln; ±15 % Böen. Richtung zufällig, wechselt alle 8–12 s; Aufbau und kompletter Richtungswechsel dauern 1,5 s |
| Regen | Schub × 0,9, maximale Fallgeschwindigkeit beim Gleiten × 1,3, Material sinkt × 1,5 schneller |

Wind addiert sich zur Bewegung, ohne die Höchstgeschwindigkeit zu ändern: Gegen den Wind kommt der Spieler langsamer voran. Gegner werden je nach Klasse unterschiedlich stark verschoben:

| Gegner | Windanfälligkeit |
| --- | --- |
| Krähe | 1,0 |
| Spucker | 0,8 |
| Käfer | 0,5 |
| Brocken | 0,35 |
| Geierkönig | 0,2 |

Darstellung: Regenschleier mit Pfützen am Boden, die sich füllen und danach wieder trocknen; bei Wind Windlinien und Blätter. Das Wetter wird beim Wechsel in 1,2 s weich ein- und ausgeblendet. Im Debug-Build schalten die Tasten 1 / 2 / 3 direkt auf Klar / Wind / Regen.

## Progression
 
Material ist gleichzeitig Währung und Erfahrung: Jedes aufgesammelte Stück gibt 1 Geld und 1 XP. Für Level L braucht der Spieler (L + 3)² XP; jedes Level gibt sofort +1 Max-HP und eine Verbesserung nach der Welle.
 
- **Drops:** Gegner lassen Material dort, wo sie sterben. Es springt kurz auf; auf Küken und Spatz bleibt es dann schwebend an dieser Stelle (leichtes Wippen) – man holt es sich im Flug. Ab Falke sinkt es zu Boden, je höher die Stufe desto schneller (höchstens 12 / 35 / 70 Einheiten pro Sekunde, bei Regen × 1,5), und bleibt dort liegen; wer es spät noch will, muss tief zu den Käfern hinunter. Im Sammelradius (70 + Bonus) fliegt es zum Spieler. 4 % Chance auf ein Herz (+3 HP), das sich genauso verhält.
- **Level-up-Auswahl:** 4 zufällige Optionen, jede mit 20 % Chance „selten“ (doppelter Wert).
 
| Wert | Start | Level-up normal | Wirkung |
| --- | --- | --- | --- |
| Max-HP | 20 | +3 | Lebenspunkte |
| Regeneration | 0 | +1 | Heilt Wert ÷ 5 HP pro Sekunde |
| Schaden % | 0 | +6 | Multipliziert Waffenschaden |
| Angriffstempo % | 0 | +6 | Verkürzt Abklingzeiten |
| Krit-Chance % | 5 | +4 | Chance auf doppelten Schaden |
| Reichweite | 0 | +25 | Addiert auf Waffenreichweite |
| Rüstung | 0 | +1 | Schaden × 15 / (15 + Rüstung); negativ erhöht Schaden |
| Tempo % | 0 | +5 | Bewegungsgeschwindigkeit |
| Lebensraub % | 0 | +2 | Chance pro Treffer auf +1 HP |
| Sammelradius | 0 | – | Nur über Items |
 
Jeder erlittene Treffer macht mindestens 1 Schaden.
 
## Shop & Items
 
Nach jeder Welle bietet der Shop 4 zufällige Angebote: mit 45 % Chance eine Waffe, sonst ein Item. Ab Welle 3 können Waffen in Stufe II (25 %), ab Welle 7 in Stufe III (8 %) und ab Welle 11 in Stufe IV (3 %) auftauchen. Die Chancen sind kumulativ: Ein Wurf unter 3 % ergibt Stufe IV, unter 8 % Stufe III, unter 25 % Stufe II.
 
- **Preise:** Waffen Basis × Stufe × (1 + 0,12 · (w − 1) + 0,012 · (w − 1)²), Items Basis × (1 + 0,15 · (w − 1) + 0,015 · (w − 1)²). Der quadratische Anteil sorgt dafür, dass die Preise mit dem späten Einkommen mithalten.

| Welle | Waffen | Items | Neu würfeln |
| --- | --- | --- | --- |
| 1 | × 1,0 | × 1,0 | 2 |
| 5 | × 1,67 | × 1,84 | 7 |
| 9 | × 2,73 | × 3,16 | 12 |
| 14 | × 4,59 | × 5,49 | 21 |

- **Neu würfeln:** ⌊2 + 0,8 · w + 0,04 · w²⌋, pro weiterem Wurf in derselben Shopphase +2.
- **Verkaufen:** 40 % des aktuellen Waffenpreises; die letzte Waffe kann nicht verkauft werden.
- **Slots voll:** Bei 6 Waffen ist ein Kauf nur möglich, wenn die Waffe mit einer gleichen Waffe gleicher Stufe verschmelzen kann; sie verschmilzt dann direkt beim Kauf (eine Stufe).
 
| Item | Basispreis | Effekt |
| --- | --- | --- |
| Magnet | 10 | +70 Sammelradius |
| Riesenapfel | 12 | +5 Max-HP |
| Blechhelm | 14 | +2 Rüstung |
| Goldfeder | 14 | +12 % Tempo |
| Pflasterrolle | 15 | +2 Regeneration |
| Fernglas | 16 | +60 Reichweite |
| Kleeblatt | 16 | +8 % Krit-Chance |
| Hantel | 18 | +12 % Schaden, −3 % Tempo |
| Doppelter Espresso | 18 | +15 % Angriffstempo |
| Schildkrötenpanzer | 20 | +5 Rüstung, −8 % Tempo |
| Fetter Wurm | 20 | +8 Max-HP, +1 Regeneration |
| Vampirzahn | 22 | +4 % Lebensraub |
| Energiedose | 22 | +25 % Angriffstempo, −2 Rüstung |
| Glaskanone | 25 | +30 % Schaden, −6 Max-HP |
 
Items stapeln sich unbegrenzt.
 
## UI & HUD
 
Im Spiel zeigt ein schlankes HUD nur das Nötigste; alle Menüs sind Overlays über der angehaltenen Szene.
 
- **HUD oben links:** Level als leuchtender Orb, die XP laufen als Lichtbogen um ihn herum; daneben die HP als leuchtende Glaskapsel mit Zahl darunter und der Materialzähler mit Mint-Kristall.
- **HUD oben Mitte:** „WELLE X“ klein, darunter der Countdown (rosarot unter 5 s) und eine feine Lichtlinie bis zum Ziel mit leuchtendem Punkt für den Spieler und kleiner Lichtsäule am Ende; in Welle 15 stattdessen „DER GEIERKÖNIG“ mit magentafarbener HP-Kapsel.
- **Wetteranzeige:** Unter Timer bzw. Boss-Leiste steht das aktuelle Wetter (bei Wind mit Richtungszeichen, z. B. „Wind ›“); das Wellenbanner nennt es ebenfalls.
- **Einblendungen:** Wellenbanner zu Beginn (Weltname in der Kantenfarbe der Welt darüber), schwebende Schadenszahlen (weiß, Krit gelb, Spieler rot, Heilung mint; höchstens 40 gleichzeitig, mit scharfem Schatten statt Schein), „LEVEL UP“ am Spieler. Texte im Spiel haben einen weichen Schein in ihrer Farbe statt einer Kontur.
- **Titelbildschirm:** großes, sanft atmend leuchtendes „FEDERFEUER“ über der lebendigen Felder-Welt (Kamera gleitet, der Geistvogel zieht ruhige Bögen unter dem Menü), darunter „Flieg durch das Licht bis zum Gipfel“ und die Menüpunkte als leuchtender Text: Spielen, Einstellungen, Rekorde, Credits, Debug (nur Debug-Builds), Beenden (nur PC). Der gewählte Punkt leuchtet weiß mit Lichtkugel davor. Unten links die Version, unten rechts die Bedienhinweise. Esc bzw. Controller-B führt von jeder Unterseite zurück zum Titel.
- **Run vorbereiten (Spielen):** Schwierigkeit als Leiste mit fünf Stufen (gesperrte mit Schloss; darunter Faktoren und Rekord der gewählten Stufe), Kurzerklärung und drei Waffenkarten; ein Tipp auf die Karte startet den Run.
- **Einstellungen:** Vollbild/Fenster (PC), Bildschirmwackeln an/aus, FPS-Anzeige an/aus (beides gespeichert) und eine Übersicht der Steuerung für Tastatur, Controller und Touch.
- **Rekorde:** Bestleistung je Schwierigkeitsstufe (geschafft, erreichte Welle, gesperrt) und Statistik-Kacheln: Runs, Siege, besiegte Gegner, höchstes Level.
- **Credits:** Engine, Schriften mit Lizenzhinweis (SIL OFL 1.1), Bibliotheken, Version.
- **Debug (nur Debug-Builds):** Alles freischalten, Performance-Test, Render-Analyse.
- **Level-up:** 4 Karten mit großem Wert (z. B. „+4 %“); die ganze Karte ist wählbar. Seltene Karten haben ein lila Kopfband und das Badge „SELTEN“.
- **Shop:** Kopfzeile mit Hinweisen (Zeitbonus, nächste Welt) und Geld. Angebotskarten mit Kopfband in Stufenfarbe (Items apricot), Badge mit Stufe; grün „STUFE … · PAAR“, wenn der Spieler die Waffe in gleicher Stufe schon hat, bzw. „⤴ STUFE …“, wenn der Kauf bei vollen Slots direkt verschmilzt; und Preis-Etikett als Fußzeile; zu teure Karten sind ausgegraut, gekaufte werden zu einem leeren Platz. Darunter sechs Waffenslots (leere Slots sichtbar) mit Verkaufen-Knopf und – wenn ein Partner gleicher Stufe da ist – grünem Verschmelzen-Knopf („⤴ II“), Items als Etiketten, Werte in zwei Spalten, rechts unten der Start der nächsten Welle.
- **Pause & Game Over:** Pause zeigt Welle, Welt und Stufe, dazu Weiterspielen/Aufgeben. Game Over zeigt „SIEG!“ bzw. „ABGESTÜRZT“, Kacheln für Welle, Gegner und Level, die Stufe, ggf. die neu freigeschaltete Stufe, „Neue Runde“ (führt direkt zu „Run vorbereiten“) und „Hauptmenü“.
- **Menü-Navigation:** Alle Buttons sind per Tastatur (Pfeile/Tab, Enter/Leertaste) und Controller (Steuerkreuz oder Stick, A bestätigt) bedienbar; der fokussierte Knopf bzw. die fokussierte Karte hebt sich an, leuchtet heller und bekommt einen weißen Lichtrand (bei Mauszeiger darüber ohne Rand). Mit Controller ist in jedem neuen Menü sofort der erste Button fokussiert. In den ersten 0,5 s nach dem Öffnen eines Menüs wird Controller-A ignoriert, damit ein Tippen zum Fliegen nichts versehentlich auswählt.
 
Stil: leuchtendes Glas passend zur Spielwelt – ruhig und edel statt Arcade-Sticker.

- **Panels:** dunkles, durchscheinendes Glas (Nachtblau) mit feiner Lichtkante, bläulichem Schein nach außen und einem Lichtschimmer oben.
- **Karten und Knöpfe:** dunkles Glas, getönt in der Akzentfarbe (Gold für Hauptaktionen, Mint für Start/Weiter, Lila für Seltenes, Stufenfarben bei Waffen); oben ein leuchtendes Farbband mit Symbol im Lichtkreis. Bei Fokus/Hover werden Kante und Schein heller und das Glas hebt sich leicht; beim Antippen sinkt es ein.
- **Skalierung:** Menüs und HUD sind für 1280 × 720 (logische Pixel) ausgelegt und wachsen auf größeren Bildschirmen gleichmäßig mit: Faktor = min(Breite / 1280, Höhe / 720), mindestens 1, höchstens 2,2 (Full HD = 1,5). Auf kleineren Bildschirmen (Handys) bleibt alles in Originalgröße.
- **Touch-Knöpfe und Pause:** Glaskreise mit feiner Lichtkante; gedrückt leuchten sie golden.
- **Schrift:** Cinzel (elegante Versalien) für Titel und Beschriftungen, Nunito für Fließtext und für alle Zahlen (Cinzel zeichnet die 1 wie ein römisches I); beide unter SIL Open Font License in `assets/fonts/`. Die System-Schriftgröße wird in den Menüs ignoriert, weil Karten feste Größen haben.
 
## Technische Umsetzung (Flutter + Flame)
 
Die Spielwelt läuft komplett in Flame, alle Menüs und Touch-Buttons sind Flutter-Widgets als Overlays des `GameWidget`. Kollisionen werden manuell per Kreisabstand geprüft statt über `HasCollisionDetection` – bei vielen Kugeln schneller und deterministisch.
 
| Datei | Verantwortung |
| --- | --- |
| `lib/main.dart` | App-Start, Querformat, `GameWidget` mit Overlay-Map |
| `game/federfeuer_game.dart` | `FlameGame`: Phasen, Wellen, Spawns, Kamera, Kampf, Tastatur |
| `game/config.dart` | Alle Daten: Waffen, Stufen, Items, Level-ups, Gegner, Farben, Welten (`biomeDefs`), Wetter (`WeatherConfig`) |
| `game/run_state.dart` | Zustand eines Runs: Werte, Inventar, Shop- und Level-Logik |
| `components/player.dart` | Flugphysik und Zeichnung des Spielers |
| `components/weapon_mount.dart` | Waffe im Ring um den Spieler, Zielsuche, Feuern |
| `components/enemy.dart` | KI und Zeichnung aller Gegnertypen inkl. Boss |
| `components/projectiles.dart` | Spielerkugeln (Durchschlag, Explosion) und Gegnerkugeln |
| `components/pickups.dart` | Material/Herz-Drops und Spawn-Warnungen |
| `components/effects.dart` | Partikel, Explosionsring, schwebende Zahlen |
| `components/scenery.dart` | Himmel, Licht und Strahlen, Sterne, Polarlicht, vier Silhouetten-Ebenen mit Dunst und Schnee, Boden mit Lichtkante, Leuchtpflanzen, Fluss, Weltgrenzen – je nach Welt |
| `components/decor.dart` | Kulissen-Silhouetten auf dem Boden mit Lichtkante und Leuchtpunkten |
| `components/atmosphere.dart` | Unscharfer Vordergrund (Parallax 1,35), Lichtpartikel und Vignette |
| `components/light.dart` | Glow- und Strahl-Textur, additive Leuchtpunkte und Lichtstrahlen, gesammelt zeichnen (`GlowBatch`, `Rays`) |
| `components/tris.dart` | Silhouetten als Dreiecke (`TriBatch`: Rechteck, Oval, Polygon mit Ear Clipping, Gelände, Streifen) |
| `components/goal.dart` | Ziel am rechten Weltende |
| `components/hud.dart` | HUD im Viewport, Randpfeile |
| `game/weather.dart` | Wetterzustand, Würfeln pro Welle, Modifikatoren |
| `platform/desktop_window.dart` | Fenster und Vollbild am PC (window_manager), F11/Alt+Enter, gespeicherter Modus |
| `game/perf.dart` | Debug: Frame-Messung, FPS-Anzeige, Ergebnisse von Performance-Test und Render-Analyse, abschaltbare Bildteile |
| `game/progress.dart` | Fortschritt über Runs: freigeschaltete Stufen, Bestleistung pro Stufe, Statistik, Debug-Modus |
| `game/settings.dart` | Gespeicherte Einstellungen (Bildschirmwackeln, FPS-Anzeige) |
| `game/gamepad_input.dart` | Controller-Eingaben: Bewegung, Fliegen, Pause, Menü-Navigation |
| `components/weather_layer.dart` | Regen, Windlinien und Blätter im Viewport, Pfützen am Boden |
| `ui/*.dart` | Startmenü mit Unterseiten (`menu.dart`), Level-up, Shop, Pause, Game Over, Touch-Steuerung; `widgets.dart` enthält die Bausteine (Panel, Sticker, Knöpfe, Karten, Etiketten) |
 
Phasen: `menu → play → cleared → levelUp → shop → play … → over`; `cleared` ist die kurze Einblendung nach einer Welle. Außerhalb von `play` läuft die Engine mit dt = 0 weiter, damit Entfernen/Hinzufügen von Komponenten verarbeitet wird, ohne dass sich etwas bewegt. Temporäre Komponenten tragen das Mixin `Transient` und werden beim Wellenwechsel gesammelt entfernt.

Debug-Werkzeuge (in Debug-Builds oder mit `--dart-define=FEDERFEUER_DEBUG=true`):

- **Tasten 1 / 2 / 3:** Wetter Klar / Wind / Regen.
- **F3:** FPS-Anzeige oben rechts (für alle Spieler auch über Einstellungen → FPS-Anzeige) – FPS, schlechteste Frame-Zeit der letzten 120 Frames, Build- und Raster-Zeit der Engine, Anzahl Gegner, Kugeln und Komponenten.
- **Menüseite „Debug“ – Alles freischalten:** alle Schwierigkeitsstufen frei.
- **Menüseite „Debug“ – Performance-Test:** schwerste Szene – Wald mit Regen, Stufe Phönix, dauerhaft 110 Gegner rund um den Spieler, sechs Waffen der Stufe IV, Held unverwundbar. Nach 3 s Aufwärmen wird 30 s gemessen; Ergebnis (Ø FPS, 1%-Low, schlechtester Frame, Raster/Build Ø und max) oben rechts und in der Konsole. Aussagekräftig nur im Profile- oder Release-Build.
- **Menüseite „Debug“ – Render-Analyse:** dieselbe Lastszene, abschnittsweise gemessen (3 s Aufwärmen, je Abschnitt 1 s Einschwingen + 4 s Messung): zuerst alles an, dann jeweils ohne einen Bildteil (Hintergrund, Kulisse, Boden, Vordergrund, Atmosphäre, Wetter, Gegner-Körper, Gegner-Leuchten, Kugeln, Effekte, HUD). Ergebnis: Rasterzeit je Abschnitt und Ersparnis je Bildteil, größte zuerst – oben rechts und in der Konsole.
 
## Offene Punkte & Roadmap
 
Der Prototyp ist spielbar; als Nächstes geht es um Stabilität, dann um Tiefe und Wiederspielwert.
 
Offene Fragen:
 
- ~~Soll es bei 10 Wellen bleiben oder wie bei Brotato 20 Wellen mit Boss in der Mitte und am Ende?~~ **Entschieden:** 15 Wellen, Boss am Ende (Welle 15); jede Welle dauert länger und ist schwerer.
- Bleibt die Grafik prozedural gezeichnet, oder kommen Sprites/Spritesheets? (Der leuchtende Stil ist bisher komplett prozedural umgesetzt.)
- Monetarisierung: Einmalkauf, Free-to-play oder rein privat?
- Credits: Wer steht als Entwickler/Studio im Spiel (Credits-Seite, Store)?
 
Phase 1 – Fundament:
 
- [x] Flutter-Port lokal bauen und `flutter analyze` fehlerfrei bekommen
- [x] Bestleistung mit `shared_preferences` speichern (pro Stufe, Schlüssel `bestWave_<Stufe>`)
- [ ] Soundeffekte und Musik – vertagt, bis Waffen, Gegner und Inhalte feststehen. Bereits entschieden: Technik `flutter_soloud` (geringe Latenz, viele gleichzeitige Effekte; statt `flame_audio`). Musik und Effekte sollen per KI erzeugt werden – dafür nur Tarife mit kommerziellen Nutzungsrechten, Prompt/Datum/Werkzeug je Datei dokumentieren, KI-Hinweis bei Steam angeben. Klangkonzept: ruhige, atmosphärische Musik je Welt (plus Titel, Boss, Sieg/Niederlage), Effekte für Waffen, Treffer, Tod, Sammeln (steigende Tonhöhe), Level-up, Wellen, Ziel, Spawn, Boss, Menü; Wind/Regen als Ambiente; Lautstärkeregler in den Einstellungen.
- [ ] Performance-Test mit 110 Gegnern auf einem Mittelklasse-Android (Werkzeug vorhanden: „Performance-Test“ im Startmenü, siehe Debug-Werkzeuge)
 
Phase 2 – Inhalte:
 
- [ ] Charakterklassen mit eigenen Start-Boni und Nachteilen
- [ ] Nahkampfwaffen und weitere Fernwaffen
- [ ] Elitegegner und ein Zwischenboss
- [ ] Seltene Items mit Spezialeffekten (z. B. Kettenblitz, Dornen)
- [ ] Weitere Wetter: Nebel, Gewitter, Hitze, Schnee (z. B. Schnee für Gebirge und Gipfel)
- [x] Fünf Schwierigkeitsstufen mit Freischalten durch Sieg
- [x] Wetter-Pools pro Welt
 
Phase 3 – Politur & Release:
 
- [ ] Sprites, Animationen und Treffer-Feedback
- [ ] Einstellungen (Lautstärke, Button-Größe, Linkshänder)
- [ ] Meta-Progression zwischen Runs
- [ ] Store-Release über Codemagic auf Google Play