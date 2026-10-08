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
| Held | Zwölf spielbare Vögel als leuchtende Geistvögel; zu Beginn nur der „Kampfspatz“ (golden, mit Fliegerbrille), die übrigen über Aufgaben (siehe „Charaktere“) |
 
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
 
Standardbelegung (Tastatur und Controller frei änderbar, siehe unten):

| Eingabe | Tastatur | Touch | Controller |
| --- | --- | --- | --- |
| Links / rechts | A / D oder ← / → | Buttons ◀ ▶ unten links | Linker Stick (Totzone 0,35, fest) oder Steuerkreuz |
| Fliegen / hoch (halten) | W, ↑ oder Leertaste | Button „Flug“ unten rechts (Kolibri: „▲“) | A, RB oder RT |
| Sinkflug / runter (halten) | S oder ↓ | – (Kolibri: Knopf ▼ über „Flug“) | Linker Stick nach unten (fest) oder Steuerkreuz ↓ |
| Aktion 1 / 2 sofort auslösen (optional; sonst automatisch) | Q oder Shift / E | – (lösen automatisch aus) | X oder LB / Y |
| Pause | P; Esc immer (fest) | Button oben rechts | Menü-Taste („Start“); in der Pause B zum Weiterspielen |
| Vollbild / Fenster (PC) | F11 oder Alt+Enter (fest); Knopf im Startmenü und in der Pause | – | – |

**Belegung ändern:** Unter Einstellungen → Steuerung lässt sich zwischen Tastatur und Controller umschalten (geöffnet wird die Ansicht des zuletzt benutzten Geräts). Jede der sieben Spielaktionen (links, rechts, fliegen/hoch, Sinkflug/runter, Aktion 1, Aktion 2, Pause) hat drei Plätze. Feld wählen, dann die neue Taste drücken; Esc bricht ab, Entf/Rücktaste leert das Feld, beim Controller endet die Erfassung nach 5 s ohne Eingabe. Eine Taste gilt immer nur für eine Aktion – wird sie neu vergeben, verschwindet sie an der alten Stelle. „Standard“ stellt die gerade gezeigte Belegung zurück. Die Belegung wird gespeichert. Tasten erscheinen als Tastenkappen, Controller-Knöpfe in Xbox-Farben (A grün, B rot, X blau, Y gelb). Fest bleiben: Menüsteuerung (Pfeile, Tab, Enter; Steuerkreuz bzw. Stick, A bestätigt, B zurück), Esc, F11/Alt+Enter, F3 und der linke Stick; die Trigger zählen ab halbem Druck als Knopf. Das HUD zeigt bei den Aktionen jeweils die erste belegte Taste (mit Controller den Knopf).

Controller folgen der Xbox-Standardbelegung (Paket `gamepads`); mehrere angeschlossene Controller steuern gemeinsam. Sobald ein Controller benutzt wurde, werden die Touch-Buttons ausgeblendet.

Am PC (Windows, macOS, Linux) startet das Spiel im Vollbild; die Wahl Vollbild/Fenster wird gespeichert. Im Fenstermodus ist es standardmäßig 1280 × 720 (logisch, also bei 150 % Skalierung 1920 × 1080 Pixel) groß, mindestens 960 × 540. Unter Einstellungen → Auflösung lässt sich die Fenstergröße in Bildschirmpixeln wählen (16:9: 1280 × 720, 1600 × 900, 1920 × 1080, 2560 × 1440, 3200 × 1800, 3840 × 2160; angeboten werden nur Größen, die kleiner als der Bildschirm sind und die Mindestgröße einhalten). Die Wahl wird gespeichert, das Fenster wird dabei zentriert; im Vollbild wechselt die Auswahl in den Fenstermodus. Als letzter Eintrag steht die volle Bildschirmauflösung mit „(Vollbild)“ – sie ist im Vollbild ausgewählt und schaltet ins Vollbild. Das Vollbild nutzt immer die volle Bildschirmauflösung. Während des Spielens ist der Mauszeiger ausgeblendet, in Menüs sichtbar.
 
| Parameter | Wert |
| --- | --- |
| Maximale Horizontalgeschwindigkeit | 230 × (1 + Tempo %) × Vogel-Tempo, mindestens 40 %; am Boden zusätzlich × Bodentempo des Vogels |
| Horizontale Beschleunigung | 1500 × Vogel-Beschleunigung |
| Ausrollen ohne Eingabe | Geschwindigkeit × 0,002 pro Sekunde |
| Schwerkraft | 650 |
| Schub beim Halten | 1250 × Vogel-Schub × (1 + Schub %) (Kampfspatz: netto 600 nach oben) |
| Steiggeschwindigkeit max. | 340 |
| Fallgeschwindigkeit beim Gleiten max. | 150 × Vogel-Gleiten ÷ (1 + Gleiten %) |
| Sinkflug | zusätzlich 900 nach unten, höchstens 380 |
| Freier Flug (nur Kolibri) | keine Schwerkraft; senkrecht höchstens 260 × (1 + Schub %), Beschleunigung 1500 × Vogel-Beschleunigung, ohne Eingabe bleibt er stehen |
| Kollisionsradius Spieler | 16 (je Vogel 11–17) |
| Unverwundbarkeit nach Treffer | 0,6 s (Blinken) |
 
Am Boden kann der Spieler laufen, an der Decke wird er gestoppt. Der Vogel neigt sich je nach Vertikalgeschwindigkeit, die Flügel schlagen beim Fliegen schneller. Jeder Vogel hat ein eigenes Flugprofil (Faktoren siehe „Charaktere“).
 
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

- **Held:** Stil „leuchtender Geist“ passend zur Welt: Jeder Vogel ist ein Wesen aus Licht. Kopf, Körper (beim Strauß auch der Hals) bilden eine verschmolzene Silhouette mit eigenen Maßen je Art; innen ein warmer, heller Kern, nach außen die Körperfarbe und ein durchscheinender, in der Leuchtfarbe getönter Rand, oben eine feine Gegenlichtkante mit weichem Schein, unten eine sanfte Schattierung und wenige feine Federzüge. Flügel aus Licht, die zur Spitze hin ausblenden, mit heller Vorderkante und Federstreifen (hinterer Flügel gedämpft, Kolibri schwirrend als Unschärfe, Adler mit gespreizten Fingerfedern, Pinguin mit kurzen Flossen, Strauß mit weißen Federbüscheln). Schwanzformen als spitz auslaufende, wehende Lichtstreifen: fließender Schweif mit dünnem Band (Standard), Gabel (Schwalbe), langer Stufenschwanz (Elster), Fächer (Eule, Adler), Sicheln (Huhn), Keil (Rabe, Specht), Stummel (Kolibri, Pinguin), Federbusch (Strauß). Dunkle, mandelförmige Augen mit Glanzpunkt, die blinzeln und zum nächsten Gegner schauen (Eule: zwei große Bernsteinaugen, Rabe: violett leuchtend, Adler: golden mit strenger Lichtbraue); leuchtender Schnabel in eigener Form. Leuchtakzente je Art: Fliegerbrille als leuchtendes Band (Kampfspatz), glühende Brust und orange Funken (Glutkehlchen), rostrote Kehle (Schwalbe), schillernde Kehle (Kolibri), Kehlfedern (Rabe), dunkler Kopf und helle Brust (Pinguin), rote Haube und Wangenstreif (Specht), Federohren (Eule), weißer Schulterfleck (Elster), Kamm und Kehllappen (Huhn), weißer Kopf mit goldenem Nacken (Adler). Beine als Lichtfäden – am Boden laufend, in der Luft nur beim Halten der Waffe (Krallen in der Leuchtfarbe), beim Strauß immer lang sichtbar. Kleine Lichtfunken steigen vom Körper auf. Dazu Lichtschweif, Aura und Bodenlicht wie bisher; ein aktiver Seifenblasenschild liegt als leuchtende Blase um ihn.
- **Gegner:** Stil „Fäulnis“ als Gegenstück zu den Lichtvögeln: fast schwarze Silhouetten mit schwachem violettem Schimmer im Inneren, einer kränklich-violetten Gegenlichtkante oben und glühenden Schlitzaugen (kleines, scharfes Leuchten statt großer Lichthöfe); Risse und Adern pulsieren in ihrer Farbe (Glut, Gift, Magenta). Jeder Gegner hat eine eigene ausgearbeitete Form: Glutkäfer mit gewölbten Flügeldecken, Glutnaht, Halsschild, Fühlern und sechs Beinen; Spucker als pulsierender Schleimbeutel mit durchscheinendem Giftsack (aufsteigende Blasen), Tentakeln, Warzen und Spuckmaul; Brocken aus Bruchflächen mit Glutadern, Fäulnismoos und Zahnkiefer; Pusteling als Stachelkugel mit Giftadern, die sich vor dem Platzen aufbläht; Vogelscheuche mit zerlumptem Mantel, Sackkopf mit Naht und Krempenhut; Fledermaus mit Hautflügeln über Fingerknochen, großen Ohren und Fangzähnen; Wetterhahn als rostige Blechsilhouette mit Kamm über einer Windrose; Spinne mit gegliederten Beinen, gemustertem Hinterleib, vier Augen und Kieferklauen; Felsadler mit zerfetzten Flügeln, Hakenschnabel, Braue und Fängen, die er im Sturzflug ausstreckt; Lawinenkäfer mit Frostrillen und Frostzacken; Krähennest aus verflochtenen Zweigen mit Augen im Dunkel; Wespennest aus Papierschichten mit glühendem Flugloch; Fäulniswespe mit Glasflügeln und Stachel; Sporenpilz mit Lamellen, Leuchtpunkten und Wurzeln; Sporen mit Härchen; Käferkönigin mit massigem Panzer, Frostkrone und leuchtendem Eiersack. Die Fäulniskrähe hat zerfetzte Flügel mit Lücken in der Hinterkante, einen zerfransten Schwanz, magenta Adern und dezente Rauchschwaden; die Bosse sind deutlich detaillierter gezeichnet: Der Geierkönig hat gefächerte, zerfetzte Schwanzfedern, Riesenflügel aus drei Lagen (Deckfedern, Armschwingen, zerfetzte Handschwingen mit violetter Vorderkante), die er majestätisch hebt, einen Körper aus Reihen dunkler Federschuppen mit violettem Saum und Schattierung, ein Adernetz, das mit jeder Phase heller und dicker wird, eine Halskrause aus spitzen Federn, kahlen faltigen Hals und Kopf, Hakenschnabel, glühendes Schlitzauge mit Brauenwulst, kräftige Krallen, herabtropfende Fäulnis und eine schwebende Krone aus Lichtsplittern, die in Phase 3 lodert. Der Strohkönig ist eine morsche Vogelscheuche mit gemasertem Holz, zerfetztem Umhang mit Flicken, Naht und Glutriss, Stroh an Saum, Ärmeln und Kragen, geripptem Kürbiskopf mit flackerndem Gesicht, Strohkrone, Glutfunken und zwei Fäulniskrähen auf den Armen. Die Glocke hat Joch mit Eisenbändern, profilierten Körper mit Metallglanz, Zierbänder mit glühender Inschrift, Glutrisse (im Warnzustand gleißend), Fäulnisranken und statt des Klöppels ein glühendes Auge, das nachschwingt. Die Spinnenmutter hat acht gegliederte, behaarte Beine mit Gelenken und Klauen, einen gemusterten Hinterleib mit roter Sanduhr, einen Eiersack mit pulsierenden Eiern, acht leuchtende Augen, Kieferklauen, die sich öffnen, und Gifttropfen. Formen und Verläufe werden je Gegnertyp einmal gebaut und wiederverwendet. fast schwarze „Fäulnis“-Kreaturen mit violetter Aura und glühenden Augen; Krähe mit zerfransten Flügeln, Käfer mit glühenden Panzerrissen, Spucker mit grün pulsierendem Giftsack, Brocken mit Glutadern (HP-Leiste als Glutstreifen), Pusteling als stachlige Pollenkugel mit grünem Kern, Vogelscheuche mit Strohhut und Glutaugen, Fledermaus mit schnellen Flügeln, Wetterhahn auf einer Stange mit goldenem Zeigerpfeil, Spinne an einem feinen Faden mit vier roten Augen, Irrlicht als flackernder blasser Lichtkern, Felsadler mit eingeklappten Flügeln im Sturzflug, Lawinenkäfer als Panzer oder rollende Kugel mit Streifen; Torwächter: Strohkönig mit glühendem Kürbisgesicht und Strohkrone, Glocke an einer Kette mit glühenden Rissen und schwingendem Klöppel, Spinnenmutter mit sechs Augen und schimmerndem Eiersack; Geierkönig mit Krone aus magentafarbenen Lichtsplittern und pulsierender Aura. Giftwolken leuchten grün, Netze kleben sichtbar am Vogel. Bei Treffern blitzen die Körper hell auf; beim Tod zerfallen sie in violette Funken.
- **Waffen & Kugeln:** Jede Waffe hat ein eigenes Modell: Lichtfeder als Federkiel, Sonnenstrahl als Rohr mit Linse, Diskokugel mit drehenden Facetten, Glutkern als glühende Kohlenkanone, Funkenfächer mit fünf Speichen, Popcornmaschine als gestreifter Wagen mit Kurbel, Böenschwarm als Windrad, Federwirbel als Handfächer, Pusteblume, Dornenranke als dornige Peitsche, Krähenruf als Knochenhorn, Paktlaterne mit Flamme, Wasserpistole, Seifenblasen-Ring, Regenwolke am Stab, Kieselschleuder, Gartenzwerg-Mörser, Bowlingkugel in einer Rinne. Alle Waffen erscheinen im Leuchtstil als Lichtobjekte in ihrer Klassenfarbe (helle Partien leuchten, dunkle werden durchscheinend, additiv gezeichnet), mit Schein in Klassen- und Stufenfarbe. Schussmomente sind animiert (Rückstoß, Mündungslicht, Kurbel, Gummi spannt sich, Windrad dreht schneller, Zipfelmütze fliegt mit); ein farbiger Edelstein am Griff zeigt die Stufe. Die erste Waffe hält der Vogel in den Krallen unter dem Bauch (schwingt mit dem Flügelschlag), die übrigen schweben im Kreis um ihn; Rundum- und Henkelwaffen (Diskokugel, Popcornmaschine, Laterne, Regenwolke, Fächer) drehen nicht mit, alle anderen zielen. Der Federwirbel zeigt zusätzlich seine kreisenden Federklingen. Eigene Kugeln sind leuchtende Kugeln mit weißem Kern und Schweif (Krit gold); eigene Formen haben Popcorn, Gartenzwerg, Bowlingkugel, Seifenblase, Pusteblumen-Schirmchen und Kiesel. Dazu Geisterkrähen, Regenwolken mit Regenstrichen, ein Peitschenbogen für die Dornenranke, Blitze und Henriettes Eier. Gegnerkugeln haben einen dunklen Kern mit farbigem Leuchten.
- **Status an Gegnern:** Brand (orange), Kleben (weiß), Verlangsamung (blau) und Fluch (violett über dem Kopf) leuchten am Gegner; eingefangene Gegner stecken in einer Blase, betäubte haben kreisende Sterne.
- **Drops:** Material als leuchtender Kristall (Farbe und Größe nach Wert: mint, blau, violett, gold), Herz als leuchtendes Herz, Geschenk der Elster als blaues Päckchen; alle pulsieren.

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
 
Der Spieler trägt bis zu 6 Waffen (Glitzer: 4), die im Kreis um ihn schweben und jeweils selbstständig arbeiten. Die Startwaffe hängt vom gewählten Vogel ab (siehe „Charaktere“); Henriette startet ohne Waffe.

### Klassen & Set-Boni

Jede Waffe gehört zu einer von sechs Klassen. Wer mehrere Waffen derselben Klasse trägt (auch gleiche Waffen), bekommt einen Set-Bonus ab 2, 4 und 6 Waffen. Eine Waffe mit Gaben zählt für ihre eigene Klasse und die Klassen ihrer Spender.

| Klasse | Spielgefühl | Set-Bonus 2 / 4 / 6 |
| --- | --- | --- |
| Licht | präzise, Krits, Durchschlag | +5 / +10 / +20 % Krit-Chance |
| Glut | Explosionen, Brand | Brandschaden und Explosionsradius +15 / +30 / +50 % |
| Wind | schnell, viele Projektile, Nahbereich | +8 / +16 / +30 % Angriffstempo |
| Böse | Lebensraub, Fluch, Risiko | +2 / +4 / +8 % Lebensraub; verfluchte Gegner nehmen zusätzlich +15 / +30 / +50 % Schaden |
| Wasser | Verlangsamen, Einfangen, Flächen | Verlangsamung stärker und länger (+20 / +40 / +70 %, höchstens 85 % langsamer), Einfangen etwas länger, +1 / +2 / +4 Regeneration |
| Stein | schwere Treffer, Rückstoß, Betäuben | +2 / +4 / +8 Rüstung; schwere Waffen (Abklingzeit ab 1 s) +10 / +20 / +35 % Schaden |

### Waffenliste

| Klasse | Waffe | Art | Schaden | Abklingzeit (s) | Reichweite | Tempo | Besonderheit | Basispreis |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Licht | Lichtfeder | Schuss | 8 | 0,75 | 330 | 720 | Allrounder | 15 |
| Licht | Sonnenstrahl | Schuss | 22 | 1,7 | 470 | 1500 | durchschlägt alle Gegner | 28 |
| Licht | Diskokugel | rundum | 5 × 6 | 0,9 | 300 | 680 | 6 Strahlen gleichmäßig rundherum, die Kugel dreht sich weiter – zielt nie | 24 |
| Glut | Glutkern | Schuss | 15 | 1,6 | 390 | 420 | Explosion, Radius 75 | 30 |
| Glut | Funkenfächer | Schuss | 5 × 5 | 1,15 | 210 | 640 | 5 Funken im 0,6-rad-Fächer, Brand 2 s | 20 |
| Glut | Popcornmaschine | Wurf | 9 × 2 | 1,0 | 320 | 380 | Körner landen im Bogen und explodieren nach 1 s („PLOPP!“), Radius 50 | 24 |
| Wind | Böenschwarm | Schuss | 3 | 0,18 | 270 | 760 | Streuung 0,22 rad | 18 |
| Wind | Federwirbel | Nahkampf | 6 | 0,4 je Gegner | Kreis 58 | 4,2 rad/s | 3 Federklingen kreisen um den Vogel; jede trifft denselben Gegner höchstens alle 0,4 s | 22 |
| Wind | Pusteblume | Schuss | 2 × 3 | 0,6 | 260 | 150 | Schirmchen schweben leicht aufwärts, kleben 3 s am Gegner und schaden weiter (Trefferschaden pro Sekunde), kein Rückstoß | 20 |
| Böse | Dornenranke | Nahkampf | 12 | 0,9 | 125 | – | Hieb im 1,7-rad-Bogen trifft alles darin; 15 % Chance je Treffer auf +1 HP, Fluch 2 s, Rückstoß 18 | 22 |
| Böse | Krähenruf | Begleiter | 6 | 2,5 | Suche 420 | 260 | ruft bis zu 3 Geisterkrähen (je 8 s), die selbst Gegner jagen; Fluch 2 s | 26 |
| Böse | Paktlaterne | Schuss | 26 | 1,0 | 360 | 900 | kostet 1 HP pro Schuss (nie den letzten), Fluch 3 s | 26 |
| Wasser | Wasserpistole | Schuss | 2 | 0,12 | 230 | 650 | verlangsamt um 35 % für 1,2 s, Rückstoß 7 | 16 |
| Wasser | Seifenblasen | Schuss | 3 × 2 | 1,4 | 300 | 220 | fangen Gegner 1,8 s ein, kein Rückstoß | 22 |
| Wasser | Regenwolke | Wolke | 3 | 3,0 | 380 | – | Wolke (Breite 46) folgt dem Ziel 3 s und trifft alle 0,5 s alles darunter; verlangsamt um 40 % | 26 |
| Stein | Kieselschleuder | Schuss | 11 | 1,0 | 320 | 620 | Rückstoß 40 | 18 |
| Stein | Gartenzwergwerfer | Wurf | 14 | 1,5 | 340 | 430 | Explosion beim Aufprall, Radius 45, betäubt 1 s | 26 |
| Stein | Bowlingkugel | Rollen | 20 | 2,2 | 620 | 430 | fällt zu Boden und rollt Richtung Ziel, durchschlägt alles, Rückstoß 25 | 28 |

Würfe (Popcorn, Gartenzwerg) fliegen im Bogen (Schwerkraft 650) und werden so stark geworfen, dass sie das Ziel ungefähr erreichen. Schüsse werden vom Wind verweht, rollende Kugeln nicht.

### Treffereffekte

| Effekt | Wirkung |
| --- | --- |
| Brand | Schaden über Zeit, alle 0,5 s: Grundschaden × Stufe × 0,45 × (1 + Schaden %) pro Sekunde (× Glut-Set) |
| Kleben | Schaden über Zeit wie Brand, Höhe = Trefferschaden pro Sekunde |
| Verlangsamen | Gegner bewegt und greift um den Anteil langsamer an |
| Betäuben | Gegner bleibt stehen und verursacht keinen Berührungsschaden; der Boss nur 30 % der Dauer |
| Einfangen | Gegner treibt in einer Blase hilflos nach oben (55/s), kein Berührungsschaden; der Boss wird stattdessen 50 % verlangsamt |
| Fluch | verfluchte Gegner nehmen +25 % Schaden (+ Böse-Set) |
| Rückstoß | schiebt Gegner (außer Boss) um den Wert in Schussrichtung |
| Nass | jeder Treffer einer Wasser-Waffe macht den Gegner 3 s nass (bei Regen 6 s); Grundlage für Reaktionen |
| Eingefroren | nur durch die Reaktion Frost: 1,2 s starr (auch die Animation), kein Berührungsschaden, nimmt +25 % Schaden; der Boss nur 30 % der Dauer |

**Sichtbare Zustände:** Brand – Glutkern und aufsteigende Flammenzungen; nass – abperlende Tropfen und bläulicher Glanz; eingefroren – Eiskristall-Hülle mit hellen Kanten und kaltem Schein; verflucht – drei violette Runen kreisen über dem Kopf; verlangsamt, Kleben und Betäuben wie bisher (Schein bzw. kreisende Sterne).

Schaden über Zeit zeigt kleine orange Zahlen und löst keine weiteren Effekte aus. Gegner, die brennend sterben, zählen als „verbrannt“ (Freischalten).
 
### Elementar-Reaktionen

Trifft eine Waffe einen Gegner mit passendem Zustand, löst sie eine Reaktion aus – das belohnt Waffen verschiedener Klassen (die Set-Boni belohnen reine Builds). Maßgeblich ist der Zustand vor dem Treffer; jeder Gegner reagiert höchstens alle 0,8 s, und je Treffer gibt es höchstens eine Reaktion (Reihenfolge wie in der Tabelle). Explosionen von Waffen (Glutkern, Popcorn, Gartenzwerg) zählen zur Klasse ihrer Waffe; Schaden aus Reaktionen, Aktionen und Schaden über Zeit löst keine weiteren Reaktionen aus. „Treffer“ meint den Schaden des auslösenden Treffers.

| Reaktion | Klassen | Bedingung | Wirkung |
| --- | --- | --- | --- |
| Zerschmettern | Stein + Wasser | eingefroren + Stein-Treffer | Treffer × 3 (statt +25 %), der Frost endet, Eissplitter |
| Dampfstoß | Glut + Wasser | nass + Glut-Treffer oder brennend + Wasser-Treffer | Explosion Radius 60, Schaden 2 × Treffer; löscht Brand und Nässe |
| Frost | Wasser + Wind | nass + Wind-Treffer | eingefroren 1,2 s (Boss 30 %), verbraucht die Nässe |
| Feuersturm | Glut + Wind | brennend + Wind-Treffer | der Brand springt auf alle Gegner im Umkreis 70 über |
| Regenbogen | Licht + Wasser | nass + Licht-Treffer | 3 Lichtsplitter auf die nächsten Gegner im Umkreis 200 (je 40 % Schaden); verbraucht die Nässe |
| Bannstrahl | Licht + Böse | verflucht + Licht-Treffer | Lichtbogen auf bis zu 2 weitere verfluchte Gegner im Umkreis 400 (je 60 % Schaden) |
| Höllenfeuer | Böse + Glut | verfluchter Gegner stirbt brennend | Brand (mindestens 2 s) und Fluch (2 s) springen auf die 2 nächsten Gegner im Umkreis 120 |

Jede Reaktion zeigt kurz ihren Namen in ihrer Farbe („DAMPF!“, „FROST!“, „ZERSCHMETTERT!“ …, je Reaktion höchstens alle 0,5 s) und einen eigenen Effekt (Dampfwolke mit Ring, Eissplitter, Feuerring, Lichtbögen). Das Kompendium hat einen Reiter **Reaktionen**; eine Reaktion gilt als entdeckt, sobald sie einmal ausgelöst wurde.

**Stufen:** Jede Waffe gibt es in Stufe I bis IV. Eine gekaufte Waffe kommt immer in einen freien Slot, auch wenn der Spieler sie in gleicher Stufe schon besitzt. Zwei gleiche Waffen gleicher Stufe (unter IV) kann er im Shop per Knopf am Waffenslot verschmelzen: Der angetippte Slot steigt eine Stufe auf und wählt eine Eigenschaft (siehe unten), der andere wird frei; dessen Gaben gehen mit über, soweit Platz ist, seine Eigenschaften verfallen. Ketten laufen nicht automatisch, jeder Schritt ist ein eigener Klick.
 
| Stufe | Farbe | Schaden | Abklingzeit | Preis |
| --- | --- | --- | --- | --- |
| I | Grau | × 1,0 | × 1,0 | × 1,0 |
| II | Blau | × 1,7 | × 0,9 | × 1,9 |
| III | Lila | × 2,7 | × 0,8 | × 3,3 |
| IV | Rot | × 4,2 | × 0,7 | × 5,5 |
 
### Verschmelzen: Eigenschaften und Gaben

**Eigenschaften (gleiche Waffen):** Bei jedem Verschmelzen zweier gleicher Waffen – auch beim Kauf mit vollen Slots – wählt der Spieler 1 aus 3 zufälligen Eigenschaften, die zur Waffenart passen; der Shop ist so lange gesperrt. Eigenschaften stapeln sich.

| Eigenschaft | Wirkung | Für |
| --- | --- | --- |
| Geschliffen | +20 % Schaden | alle |
| Flink | +20 % Angriffstempo | alle |
| Scharfsinn | +10 % Krit-Chance | alle |
| Weitblick | +60 Reichweite (Federwirbel: +10 Kreisradius) | alle außer Begleitern |
| Mehrfach | +1 Projektil; Diskokugel +2 Strahlen, Federwirbel +1 Klinge, Krähenruf +1 Begleiter (Schüsse ohne eigene Streuung fächern leicht auf) | Schuss, Wurf, Diskokugel, Federwirbel, Krähenruf |
| Durchschlag | durchschlägt 2 Gegner mehr | Schüsse ohne Explosion, die nicht ohnehin alles durchschlagen |
| Wucht | +40 % Explosionsradius | Waffen mit Explosion |
| Weiter Bogen | Hieb +0,5 rad breiter | Dornenranke |
| Breite Wolke | Wolke 40 % breiter | Regenwolke |

**Gaben (verschiedene Waffen):** Jede Waffe kann auch mit einer anderen Waffe verschmolzen werden. Im Shop wählt der Spieler im Waffenring den Spender, tippt „✦ Gabe“ und dann eine der violett leuchtenden Ziel-Waffen (Vorschau beim Darüberfahren). Das Ziel behält Art und Stufe, erbt die Gabe des Spenders und zählt zusätzlich zu dessen Klasse – für Set-Boni und Reaktionen. Der Spender verschwindet, seine eigenen Gaben gehen verloren. Eine Waffe trägt höchstens Stufe + 1 Gaben (I: 1 … IV: 4), jede Gabe nur einmal; gleiche Waffen verschmelzen stattdessen normal.

| Spender | Gabe | Wirkung |
| --- | --- | --- |
| Lichtfeder | Präzision | +10 % Krit-Chance |
| Sonnenstrahl | Fernlicht | +80 Reichweite |
| Diskokugel | Blendung | 10 % Chance, 0,5 s zu betäuben |
| Glutkern | Zündfunke | jeder Treffer explodiert klein (Radius 30, 35 % des Treffers) |
| Funkenfächer | Funkenflug | setzt 2 s in Brand |
| Popcornmaschine | Plopp | 20 % Chance auf eine Explosion (Radius 50, 80 %) |
| Böenschwarm | Rückenwind | +15 % Angriffstempo |
| Federwirbel | Wirbel | +25 Rückstoß |
| Pusteblume | Flugsamen | Treffer kleben 2 s |
| Dornenranke | Dornen | +10 % Lebensraub |
| Krähenruf | Krähenfluch | verflucht 2 s |
| Paktlaterne | Pakt | +20 % Schaden |
| Wasserpistole | Spritzer | verlangsamt um 30 % für 1 s |
| Seifenblasen | Blase | 8 % Chance, 1,5 s einzufangen |
| Regenwolke | Nieselregen | verlangsamt um 20 % für 2 s |
| Kieselschleuder | Wucht | +12 % Schaden, +25 Rückstoß |
| Gartenzwergwerfer | Zwergenmütze | 15 % Chance, 0,8 s zu betäuben |
| Bowlingkugel | Strike | +10 % Schaden, +40 Rückstoß |

Gleiche Werte aus mehreren Gaben addieren sich (Schaden und Angriffstempo multiplizieren sich); bei Verlangsamen, Betäuben, Einfangen und Explosionsgröße zählt die stärkste. Kleine Explosionen aus Gaben lassen das Bild nicht wackeln und lösen keine Reaktionen aus. Info-Panels zeigen Klassen, Eigenschaften, Gaben (n / Höchstzahl), die Reaktionen ihrer Klassen (mit Partnerklasse bzw. „löst sie selbst aus“, wenn die Waffe durch Gaben beide Klassen hat) und bei jeder Waffe, welche Gabe sie weitergibt.

Endwerte (kritische Treffer ×2, beim Adler ×2,5): Schaden × (1 + Schaden %) × Klassenbonus des Vogels (× 1,25) × schwere Waffen (Stein-Set) × Welt-/Wetter-Faktor (Professor Uhu, Gießkanne) × Spiegelscherbe (× 0,7 für Schüsse, Würfe und Diskokugel); Abklingzeit ÷ (1 + Angriffstempo %) mit Untergrenze Faktor 0,3; Reichweite + Reichweiten-Bonus (Federwirbel: + Bonus ÷ 6 auf den Kreisradius). Jeder Treffer würfelt einzeln auf einen kritischen Treffer (doppelter Schaden, gelbe Zahl).
 
## Gegner
 
Fäulnis-Kreaturen mit klar unterscheidbarem Verhalten, gern mit Augenzwinkern. Jede Welt bringt zwei eigene Gegner mit, die früheren bleiben dabei. Schaden entsteht durch Berührung, Projektile oder Flächen. Angriffe der neuen Gegner werden angekündigt: Sie halten kurz inne und leuchten hell auf (Schuss, Sturz, Explosion). Werte gelten für Welle 1.
 
| Gegner | Welt / ab Welle | HP | Tempo | Schaden | Radius | Material | Verhalten |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Fäulniskrähe | überall / 1 | 6 | 95 | 2 | 13 | 1 | Fliegt direkt auf den Spieler zu, leichtes Auf und Ab |
| Glutkäfer | überall / 2 | 12 | 75 | 3 | 15 | 1 | Läuft am Boden, springt hoch, wenn der Spieler über ihm ist (alle 1,5–2,5 s) |
| Spucker | überall / 3 | 9 | 70 | 2 | 14 | 1 | Hält 200–300 Abstand, schießt alle \~2,4 s eine Kugel (Tempo 240) |
| Brocken | überall / 5 | 45 | 42 | 5 | 27 | 3 | Langsamer, schwerer Verfolger mit HP-Leiste |
| Pusteling | Felder / 2 | 10 | 35 | 2 | 15 | 1 | Treibt langsam heran; platzt bei Berührung oder Tod in eine Giftwolke (Radius 60, 3 s, Schaden bei Kontakt; bei Berührung ohne Material) |
| Vogelscheuche | Felder / 3 | 26 | – | 3 | 18 | 2 | Steht fest im Feld, wirft alle \~2,4 s brennendes Stroh im Bogen auf die Stelle des Spielers (bis 560 entfernt) |
| Fledermaus | Dorf / 5 | 7 | 150 | 2 | 11 | 1 | Zickzackflug: Richtung Spieler mit kräftigem Pendeln quer dazu |
| Wirrling | Dorf / 5 | 14 | 55 | 2 | 14 | 1 | Schwebender Sporenquall: hält 160–220 Abstand, stößt alle 3,5–4,5 s nach 0,6 s Warnung (helles Leuchten) eine Chaos-Wolke aus, beim Tod ebenfalls (siehe „Chaos“) |
| Wetterhahn | Dorf / 6 | 22 | – | 3 | 16 | 2 | Steht fest auf seiner Stange, dreht sich gleichmäßig (0,9 rad/s) und schießt alle 0,8 s in Zeigerichtung (Tempo 210) |
| Spinne | Wald / 9 | 16 | 60 | 3 | 15 | 1 | Hängt am Faden von oben, folgt dem Spieler und seilt sich bis knapp über ihn ab; schießt alle \~2,8 s ein Netz (verlangsamt 2 s: Tempo × 0,55, Schub × 0,75) |
| Irrlicht | Wald / 10 | 9 | – | 5 | 12 | 1 | Springt alle 2,2 s neben den Spieler; nach drei Sprüngen oder in seiner Nähe 0,8 s Warnung, dann Explosion (Radius 75, ohne Material) |
| Felsadler | Gebirge / 13 | 30 | 120 | 5 | 20 | 2 | Kreist oben über dem Spieler, hält alle 2,5–3,5 s inne (0,7 s Warnung) und stürzt sich auf dessen Position (560) |
| Lawinenkäfer | Gebirge / 13 | 40 | 70 | 6 | 18 | 2 | Läuft heran, rollt sich in Reichweite (380) ein (0,6 s Warnung) und rast 1,6 s über den Boden (430) |
| Geierkönig (Boss) | Gipfel / 15 | 4500 | 55 | 6 | 52 | – | siehe „Geierkönig“ |

Stationäre Gegner (Vogelscheuche, Wetterhahn) lassen sich nicht verschieben und nicht einfangen; der Wind treibt sie nicht ab.

**Gewichtung je Welle** (Pool wächst mit, siehe „Wellen & Spawns“): Krähe 10, Käfer 7 (ab 2), Spucker 4 + 0,3 · w (ab 3), Brocken 2 + 0,3 · w (ab 5), Pusteling 4 in den Feldern / sonst 2 (ab 2), Vogelscheuche 2 / 1 (ab 3), Fledermaus 6 im Dorf / sonst 3 (ab 5), Wetterhahn 2,5 / 1 (ab 6), Wirrling 2,5 im Dorf / sonst 1,5 (ab 5), Spinne 4 im Wald / sonst 2 (ab 9), Irrlicht 3 / 1,5 (ab 10), Felsadler 4 und Lawinenkäfer 3 (ab 13). Spinne und Felsadler erscheinen oben an der Decke, Bodengegner am Boden.
 
Skalierung pro Welle w (gilt nicht für den Boss):
 
- HP × (1 + 0,38 · (w − 1))
- Schaden × (1 + 0,15 · (w − 1)), gerundet
- Tempo × (1 + 0,02 · w)

**Wenige, aber zähe Gegner:** Statt immer mehr Gegner gleichzeitig werden reguläre Gegner mit jeder Welle zäher. Zähigkeit k(w) = 1 + 0,25 · (w − 1): HP × k(w); Material × Faktor je Welle (siehe Tabelle; zufällig gerundet – 1,3 ergibt in 30 % der Fälle 2, sonst 1 –, fällt als wenige wertvolle Kristalle); Schaden zusätzlich × (1 + 0,04 · (w − 1)). Ausgenommen sind Boss, Torwächter und Spawner-Kinder.

Der Material-Faktor ist aus dem Einkommen pro Welle abgeleitet (XP entsteht aus Material): Wellen 1–6 bringen so viel wie vor der Umstellung auf wenige, zähe Gegner, danach sinkt das Einkommen gleichmäßig bis auf 80 % in Welle 14, weil spät sonst zu viel Geld übrig blieb. Der Faktor springt, weil die Gruppengröße in Stufen wächst; das Einkommen pro Welle steigt gleichmäßig (rechnerisch, wenn alle Gegner besiegt werden: Welle 1: 22, 4: 43, 8: 190, 14: 521).

| Welle | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 (und Boss) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Material × | 1,3 | 1,35 | 1,95 | 1,45 | 2,05 | 2,15 | 2,25 | 3,0 | 3,15 | 2,95 | 2,7 | 2,5 | 2,65 | 2,45 |
 
Gegner stoßen sich gegenseitig ab, damit sie sich nicht stapeln (Boss, Torwächter und stationäre Gegner bleiben stehen). Treffer werfen sie leicht zurück und lassen sie kurz weiß aufblitzen.

### Chaos

Verrückte Zustände des Spielers aus den Chaos-Wolken des Wirrlings. Eine Wolke (Radius 55, 3,5 s) wirbelt in der Farbe ihres Zustands mit einer Spirale in der Mitte; wer hineinfliegt, bekommt ihn. Jeder Zustand ist kurz, wird mit einem farbig pulsierenden Bildschirmrand und unten in der Mitte mit Name, Wirkung und Restzeit angezeigt und ist danach 6 s lang nicht erneut möglich. Neue Welle und Menü heben alle Zustände auf.

| Zustand | Dauer | Wirkung |
| --- | --- | --- |
| Verwirrt | 3 s | links und rechts vertauscht |
| Kopfüber | 2,5 s | Schwerkraft umgekehrt: ohne Eingabe steigt der Vogel, Flügelschlag drückt nach unten |
| Spiegelwelt | 4 s | das ganze Spielbild ist horizontal gespiegelt (das HUD nicht) |
| Verklebt | 3 s | halber Schub, sinkt 1,7-mal so schnell |

### Spawner

Gegner, die weitere Gegner erzeugen – gute Ziele für zuerst. Was ein Spawner erzeugt („Kinder“), erscheint immer mit kurzer Warnung (Fäulnis-Riss), lässt **kein Material** fallen und zählt zu seiner Obergrenze; der Spawner selbst gibt mehr Material. Höchstens 3 Spawner leben gleichzeitig, darüber erscheint stattdessen eine Krähe. Vor dem Erzeugen wackelt bzw. leuchtet der Spawner.

| Spawner | Welt / ab Welle | HP | Material | Verhalten | Kinder |
| --- | --- | --- | --- | --- | --- |
| Krähennest | Felder / 3 | 30 | 3 | steht fest auf einem Pfahl, alle 4 s eine Krähe | höchstens 3 |
| Wespennest | Dorf / 6 | 34 | 3 | hängt an der Decke und tut nichts – jeder Treffer (höchstens alle 0,3 s) lässt eine Fäulniswespe ausschwärmen (HP 4, Tempo 190, Schaden 1, Zickzack) | höchstens 6 |
| Sporenpilz | Wald / 9 | 40 | 3 | steht fest, alle 5 s drei Sporen (HP 4, Tempo 45, Schaden 2, treiben langsam heran) | höchstens 9 |
| Käferkönigin | Gebirge / 13 | 90 | 4 | großer, langsamer Käfer (Tempo 30, Schaden 6), legt alle 4 s ein Ei hinter sich (HP 8); nach 2,5 s schlüpft daraus ein Lawinenkäfer, wenn es nicht vorher zerstört wird | höchstens 6 (Eier und Schlüpflinge) |
| Fäulnisriss | alle / 6 | 50 | 3 | ein Spawn-Riss, der offen bleibt: 12 s lang alle 3 s ein zufälliger Gegner der Welle (keine Spawner oder stationären); danach schließt er sich ohne Material, Beschießen schließt ihn früher | – |

Gewichtung: Krähennest 1,5 in den Feldern / sonst 0,6, Wespennest 1,5 im Dorf / 0,6, Sporenpilz 1,5 im Wald / 0,6, Käferkönigin 1,5, Fäulnisriss 1. Spawner und Kinder sind keine Elitegegner-Ausnahme: auch ein Spawner kann Elite sein (stationäre statt „teilend“ gepanzert).

### Elitegegner

Ab Welle 5 kann ein regulär erscheinender Gegner (nicht Boss oder Torwächter) als Elite kommen: Chance min(25 %, 6 % + 1,5 % · (w − 5)). Elitegegner haben × 2,5 HP, sind 18 % größer, tragen einen pulsierenden Goldring, einen goldenen Schein, eine schmale HP-Leiste und das Zeichen ihres Modifikators über dem Kopf (als Form gezeichnet). Sie lassen × 3 Material fallen und mit 25 % Chance ein Geschenk (zufälliges gewöhnliches oder seltenes Werte-Item).

| Modifikator | Zeichen | Wirkung |
| --- | --- | --- |
| Flink | » (cyan) | Tempo × 1,25, alles läuft 35 % schneller (Bewegung, Abklingzeiten) |
| Gepanzert | Raute (silber) | nimmt nur halben Schaden, kein Rückstoß |
| Explosiv | Stern (orange) | hinterlässt beim Tod einen Sprengsatz: 0,7 s wachsender Warnkreis, dann Explosion (Radius 80, Schaden × 1,5) |
| Teilend | zwei Kreise (grün) | zerfällt beim Tod in zwei kleine Kopien (35 % HP, 70 % Größe); stationäre Gegner werden stattdessen gepanzert |
| Heiler | Plus (mint) | heilt Gegner im Umkreis 140 um 2 % ihrer Max-HP alle 0,5 s (grünes Aufleuchten), sichtbarer Heilkreis |

### Torwächter

Am Ende jeder Welt außer dem Gipfel (Welle 4, 8, 12) bewacht ein Torwächter das Ziel. Er erscheint, sobald der Spieler 1000 vor dem Ziel ist, 260 davor (mit Beben, Funken und großem Namen „TORWÄCHTER …“ nach dem Wellenbanner). Solange er lebt, ist das Ziel versperrt (violette Gitterstäbe, „VERSPERRT“): Der Spieler wird zurückgeschoben und bekommt den Hinweis „Besiege zuerst …“. Läuft die Zeit ab, endet die Welle wie gewohnt. Das HUD zeigt seinen Namen und eine HP-Kapsel unter der Zielstrecke. Besiegt lässt er 15 Material und ein Geschenk fallen („DAS TOR IST OFFEN“). Torwächter sind wie der Boss immun gegen Einfangen und Rückstoß, Betäubung wirkt nur 30 %; sie skalieren mit der Welle wie normale Gegner und bleiben im Umkreis von 220 um ihren Platz.

| Torwächter | Welle | HP | Tempo | Schaden | Radius | Angriffe |
| --- | --- | --- | --- | --- | --- | --- |
| Der Strohkönig | 4 | 220 | 25 | 5 | 40 | Riesige Vogelscheuche mit Kürbiskopf: Fächer aus drei brennenden Strohbündeln alle 2,6 s (0,6 s Warnung), ruft alle 8 s zwei Krähen |
| Die Glocke | 8 | 260 | 40 | 5 | 36 | Hängt an einer Kette: Ring aus 10 Kugeln alle 2,2 s (jedes Mal gedreht); alle 6 s Glockenschlag – 1 s wachsender Warnkreis (Radius 230), dann Schaden × 1,5 im ganzen Kreis |
| Die Spinnenmutter | 12 | 300 | 70 | 6 | 40 | Hängt oben: Fächer aus drei Netzen alle 2,6 s, ruft alle 7 s zwei Spinnen; alle 9 s 0,8 s Warnung, dann lässt sie sich bis zum Boden fallen und klettert zurück |

### Geierkönig

Der Boss der Welle 15 hat drei Phasen (Wechsel bei 66 % und 33 % HP, jeweils mit Beben, Funken und Text „DER GEIERKÖNIG TOBT!“ bzw. „LETZTE KRAFT!“). Die Boss-Leiste zeigt die Phasengrenzen und „PHASE n“.

| Phase | Angriffe |
| --- | --- |
| 1 | Schwebt, Fächer aus 7 Kugeln alle 1,5 s, ruft alle 6 s drei Krähen |
| 2 | dazu Federregen alle 5 s: 6 rosa Warnlinien über das Bild verteilt, nach 0,8 s fallen dort Federn von der Decke (Tempo 330) |
| 3 | Fächer aus 9 Kugeln alle 1,1 s, Krähen alle 4 s, Federregen alle 4 s mit 8 Linien; dazu alle 7 s Sturzflug: 0,9 s Warnung (helles Leuchten), dann quer durchs Bild auf Höhe des Spielers (680) |
 
## Wellen & Spawns
 
Wellen 1–14 laufen auf Zeit, Welle 15 endet erst mit dem Tod des Bosses. Zu Beginn jeder Welle wird der Spieler voll geheilt und an den Start gesetzt (x = 120; Bosswelle: Arenamitte).
 
- **Dauer:** 20 s + 4 s pro Welle ohne Obergrenze (Welle 1 = 20 s, Welle 9 = 52 s, Welle 14 = 72 s).
- **Schlussphase:** Damit das Ende nicht abrupt kommt, warnt der Timer oben ab 10 s Restzeit (orange, pulsiert) und ab 5 s rot und stärker pulsierend; die letzten 5 s laufen zusätzlich als großer, halbtransparenter Countdown „5 … 1“ in der Bildmitte (jede Zahl ploppt kurz auf und verblasst, ab 3 rot, darunter „WELLE ENDET“). In den letzten 3 s erscheinen keine neuen Gegner mehr (gilt nicht in der Bosswelle).
- **Ende:** Erreicht der Spieler das Ziel, ist die Welle sofort bestanden und er bekommt ⌊Restzeit / 2⌋ Material als Zeitbonus. Läuft vorher der Timer ab, ist die Welle ebenfalls bestanden, aber ohne Bonus.
- **Steigende Schwierigkeit:** Gegnerwerte (siehe Skalierung und Zähigkeit), Gruppengröße und der Anteil von Spuckern und Brocken wachsen mit jeder Welle weiter. Das Spawn-Intervall erreicht ab Welle 14 seine Untergrenze von 1,6 s.
- **Spawn-Intervall:** max(1,6; 3,0 − 0,1 · w) s, zufällig ±30 %; in der Bosswelle × 1,7.
- **Gruppengröße:** 1 + ⌊w / 5⌋, mit 40 % Chance einer mehr; in den Wellen 1–4 je Gruppe 1 Gegner zusätzlich (sonst reicht das Material früh für keine Käufe). Die Gruppe erscheint gebündelt an einer Stelle im sichtbaren Bild: mindestens 280 vom Spieler entfernt, höchstens bis 40 vor den Bildrand (und nie weiter als 700), mit 65 % Chance vor ihm (in Richtung Ziel). Ist der Bildschirm auf der Seite zu schmal, erscheint sie im Mindestabstand knapp außerhalb; fehlt am Weltrand der Platz, kommt sie von der anderen Seite. In der Bosswelle erscheint sie irgendwo in der Arena, mindestens 280 entfernt.
- **Warnung:** Ein pulsierender Fäulnis-Riss (dunkler Kern, violett-rotes Leuchten, der sich bis zum Erscheinen schließt) markiert jeden Spawn 0,9 s vorher (Boss: 2 s, größer).
- **Obergrenze:** keine neuen Spawns ab 40 lebenden Gegnern.
- **Nachzügler:** Gegner, die mehr als 1400 hinter dem Spieler zurückliegen, verschwinden ohne Drop (nicht in der Bosswelle, nie Boss oder Torwächter).
- **Gewichtung:** siehe „Gegner“; dazu ab Welle 5 Elitegegner und in Welle 4, 8, 12 ein Torwächter am Ziel.
 
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
 
Material ist gleichzeitig Währung und Erfahrung: Jedes aufgesammelte Stück gibt 1 Geld und 1 XP. Jeder Run startet mit 15 Geld (ohne XP). Für Level L braucht der Spieler (L + 3)² XP; jedes Level gibt sofort +1 Max-HP und eine Verbesserung nach der Welle.
 
- **Drops:** Gegner lassen Material dort, wo sie sterben. Es springt kurz auf; auf Küken und Spatz bleibt es dann schwebend an dieser Stelle (leichtes Wippen) – man holt es sich im Flug. Ab Falke sinkt es zu Boden (mit Frack auf jeder Stufe mit 70/s), je höher die Stufe desto schneller (höchstens 12 / 35 / 70 Einheiten pro Sekunde, bei Regen × 1,5), und bleibt dort liegen; wer es spät noch will, muss tief zu den Käfern hinunter. Im Sammelradius (70 + Bonus) fliegt es zum Spieler. 4 % Chance auf ein Herz (+3 HP, bei Ruß +2; mit Glück häufiger), das sich genauso verhält.
- **Kristallwerte:** Die Ausbeute eines Gegners fällt als möglichst wenige Kristalle: Wert 10 (gold, größer), 5 (violett), 3 (blau), 1 (mint) – z. B. 9 Material als 5 + 3 + 1. Jeder Kristall gibt beim Einsammeln seinen Wert als Geld und XP.
- **Level-up-Auswahl:** 4 zufällige Optionen, jede mit 20 % Chance „selten“ (doppelter Wert), + 1 % je Punkt Glück. Schub und Gleiten sind keine Level-up-Optionen (sie veränderten nur das Fluggefühl und wurden kaum gewählt); es gibt sie über Flug-Items und das Flugprofil der Vögel.
 
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
| Lebensraub % | 0 | +1 | Chance pro Treffer auf +1 HP; höchstens 1 HP alle 0,5 s (gilt für alle Lebensraub-Quellen zusammen) |
| Glück | 0 | +5 | Je Punkt im Shop Selten +0,5 %, Episch +0,3 %, Legendär +0,1 % (ab Welle 8); seltene Level-up-Option +1 %; Herzen und Geschenke (Elite, Elster) + 2 % relativ |
| Ausweichen % | 0 | +3 | Chance, einem Treffer ganz auszuweichen („Ausgewichen“), höchstens 60 % |
| Aktionstempo % | 0 | +8 | Verkürzt die Abklingzeit der Aktionstasten (Abklingzeit ÷ (1 + Wert / 100), höchstens auf 30 %) |
| Sammelradius | 0 | – | Nur über Items |
| Schub % | 0 | – | Stärkerer Schub beim Fliegen; nur über Items |
| Gleiten % | 0 | – | Langsameres Sinken beim Gleiten; nur über Items |
 
Jeder erlittene Treffer macht mindestens 1 Schaden. Die Werte im Shop enthalten Set-Boni und Item-Effekte (z. B. Kieselsammlung).
 
## Shop & Items
 
Nach jeder Welle bietet der Shop 4 zufällige Angebote und dazu als fünftes Feld immer ein Aktions-Item. Jedes der 4 Angebote ist mit Chance max(55 %, 80 % − 4 % × (w − 1)) eine Waffe, sonst ein Item (Welle 1: 80 %, Welle 5: 64 %, ab Welle 8: 55 %); in den Wellen 1–3 sind mindestens 2 der 4 Angebote Waffen. Ab Welle 3 können Waffen in Stufe II (25 %), ab Welle 7 in Stufe III (8 %) und ab Welle 11 in Stufe IV (3 %) auftauchen. Die Chancen sind kumulativ: Ein Wurf unter 3 % ergibt Stufe IV, unter 8 % Stufe III, unter 25 % Stufe II.
 
- **Preise:** Waffen Basis × 0,85 × Stufe × (1 + 0,1 · (w − 1) + 0,009 · (w − 1)²), Items Basis × (1 + 0,15 · (w − 1) + 0,015 · (w − 1)²); bei Glitzer jeweils × 0,85. Der quadratische Anteil sorgt dafür, dass die Preise mit dem späten Einkommen mithalten.

| Welle | Waffen | Items | Neu würfeln |
| --- | --- | --- | --- |
| 1 | × 1,0 | × 1,0 | 2 |
| 5 | × 1,54 | × 1,84 | 7 |
| 9 | × 2,38 | × 3,16 | 12 |
| 14 | × 3,82 | × 5,49 | 21 |

- **Zurückhalten:** Jedes Angebot (auch das Aktions-Angebot) lässt sich per Schloss-Knopf zurückhalten. Es bleibt beim Neu würfeln und in den folgenden Shops am selben Platz liegen, bis es gekauft oder wieder freigegeben wird; der Preis richtet sich immer nach der aktuellen Welle. Ein zurückgehaltenes Aktions-Item verschwindet, sobald es nichts mehr bewirken würde. In den Wellen 1–3 zählen zurückgehaltene Waffen zur Mindestzahl, zurückgehaltene Items werden nicht ersetzt.
- **Neu würfeln:** ⌊2 + 0,8 · w + 0,04 · w²⌋, pro weiterem Wurf in derselben Shopphase +2; mit Glückskeks ist der erste Wurf je Shop gratis.
- **Verkaufen:** 40 % des aktuellen Waffenpreises; die letzte Waffe kann nicht verkauft werden.
- **Slots voll:** Sind alle Slots belegt (6, Glitzer 4), ist ein Kauf nur möglich, wenn die Waffe mit einer gleichen Waffe gleicher Stufe verschmelzen kann; sie verschmilzt dann direkt beim Kauf (eine Stufe, mit Wahl einer Eigenschaft).

**Aktions-Angebot:** Das fünfte Feld zeigt ein noch sinnvolles Aktions-Item (neu, Stufe II oder Ersatz); Aktionen, die zur Stufe II führen oder mit einer eigenen Aktion ein Rezept ergeben, sind dreimal so wahrscheinlich. Aktions-Items kommen nur über dieses Feld, nicht über die normalen Angebote. Neu würfeln würfelt alle fünf Felder neu.

**Seltenheit:** Items haben eine Seltenheit mit Farbe: Gewöhnlich (grau), Selten (blau), Episch (lila), Legendär (rot). Für jedes normale Item-Angebot wird zuerst die Seltenheit gewürfelt (Glück erhöht die Chancen, siehe „Progression“), dann ein verfügbares Item dieser Stufe (gibt es keins mehr, eine Stufe darunter).

| Seltenheit | Chance |
| --- | --- |
| Legendär | 4 % ab Welle 8, vorher nie |
| Episch | 3 % bis Welle 3, ab Welle 4: 12 % + 1 % je weitere Welle |
| Selten | 30 % |
| Gewöhnlich | Rest |

Werte-Items stapeln sich unbegrenzt. Items mit besonderer Wirkung gibt es nur einmal pro Run; danach werden sie nicht mehr angeboten.
 
| Item | Seltenheit | Basispreis | Effekt |
| --- | --- | --- | --- |
| Magnet | Gewöhnlich | 10 | +70 Sammelradius |
| Riesenapfel | Gewöhnlich | 12 | +5 Max-HP |
| Blechhelm | Gewöhnlich | 14 | +2 Rüstung |
| Goldfeder | Gewöhnlich | 14 | +12 % Tempo |
| Pflasterrolle | Gewöhnlich | 15 | +2 Regeneration |
| Fernglas | Gewöhnlich | 16 | +60 Reichweite |
| Kleeblatt | Selten | 16 | +8 Glück, +3 % Krit-Chance |
| Hufeisen | Selten | 18 | +12 Glück |
| Glücksmünze | Episch | 26 | +22 Glück, −5 % Schaden |
| Hantel | Selten | 18 | +12 % Schaden, −3 % Tempo |
| Doppelter Espresso | Selten | 18 | +15 % Angriffstempo |
| Schildkrötenpanzer | Selten | 20 | +5 Rüstung, −8 % Tempo |
| Fetter Wurm | Selten | 20 | +8 Max-HP, +1 Regeneration |
| Vampirzahn | Selten | 22 | +3 % Lebensraub |
| Energiedose | Selten | 22 | +25 % Angriffstempo, −2 Rüstung |
| Glaskanone | Selten | 25 | +30 % Schaden, −6 Max-HP |

**Flug-Items:**

| Item | Seltenheit | Basispreis | Effekt |
| --- | --- | --- | --- |
| Leichte Knochen | Selten | 16 | +15 % Schub |
| Segelfeder | Selten | 16 | +30 % Gleiten |
| Windfahne | Episch | 22 | Wind schiebt nur in die eigene Blickrichtung, Gegenwind entfällt |
| Regenmantel | Selten | 18 | keine Regen-Nachteile beim Fliegen (Schub und Sinken) |

**Spezial-Items:**

| Item | Seltenheit | Basispreis | Effekt |
| --- | --- | --- | --- |
| Socke mit Loch | Selten | 18 | +20 % Tempo, −2 Rüstung |
| Glückskeks | Selten | 16 | erstes Neu würfeln je Shop gratis |
| Gießkanne | Selten | 18 | bei Regen +20 % Schaden |
| Kieselsammlung | Selten | 18 | +1 Rüstung je Stein-Waffe |
| Rückenwind-Kompass | Selten | 18 | doppelter Zeitbonus am Ziel |
| Goldgier | Selten | 22 | 15 % Chance auf doppelte Drops, −5 Max-HP |
| Wirrkraut | Selten | 22 | 8 % der Treffer verwirren Gegner 3 s: Sie jagen den nächsten anderen Gegner und rammen ihn (alle 0,5 s doppelter Berührungsschaden), greifen dich nicht an und schießen nicht (nicht Boss, Torwächter, stationäre Gegner); zwei kreisende Wirbel über dem Kopf |
| Hühnerzauber | Episch | 26 | 5 % der Treffer verwandeln Gegner 3 s in ein harmloses Huhn: hüpft ziellos, sinkt zu Boden, kein Berührungsschaden, keine Angriffe, nimmt +50 % Schaden (nicht Boss, Torwächter, stationäre Gegner) |
| Gummiflügel | Selten | 20 | Fliegst du schneller als 150 gegen die Decke, prallst du ab („BOING!“) und löst eine Schockwelle aus (Radius 90, Schaden wie Aktionen, höchstens alle 1 s) |
| Gummiente | Episch | 26 | +2 Rüstung, 10 % der Treffer werden ignoriert („Quietsch!“) |
| Sparschwein | Episch | 28 | am Wellenende 10 % Zinsen auf das Material, höchstens 25 |
| Brennglas | Episch | 26 | Krits von Licht-Waffen setzen 2 s in Brand (30 % des Treffers pro Sekunde) |
| Dornenkleid | Episch | 26 | +1 Rüstung; Berührungsschaden geht × 3 an den Gegner zurück |
| Sternenstaub | Episch | 30 | +3 % Krit; Krits lösen eine kleine Explosion aus (Radius 36, 40 % des Treffers) |
| Lichtschild | Episch | 30 | blockt alle 8 s einen Treffer |
| Spiegelscherbe | Legendär | 40 | jedes Projektil doppelt (Schüsse, Würfe, Diskokugel), dafür −30 % Schaden |
| Phönixasche | Legendär | 45 | einmal pro Run bei 0 HP mit 30 % HP weiter (2 s unverwundbar) |

Aktions-Items stehen unter „Aktionstasten“.
 
## Aktionstasten

Zwei Aktionsplätze tragen **Signature-Moves**: wenige, klar verschiedene Kräfte mit großem, sichtbarem Effekt. Jede Waffenklasse hat eine eigene Kraft; ihre Treffer zählen als Treffer dieser Klasse und lösen damit Reaktionen aus (siehe „Elementar-Reaktionen“). Bewegungs- und Einsammel-Aktionen gibt es nicht mehr – seit die Aktionen automatisch auslösen, passten sie nicht mehr.

Passend zu den Designpfeilern (eine Taste zum Fliegen, Waffen zielen selbst) **lösen Aktionen automatisch aus**, sobald sie bereit sind und es sich lohnt; Q/E bzw. X/Y lösen sie auf Wunsch sofort aus, auf Touch-Geräten gibt es dafür keine Knöpfe. Kampf-Kräfte (alle außer der Seifenblase) lösen spätestens 6 s nach dem Bereitwerden aus, sobald irgendein Gegner im Bild ist.

**Ankündigung:** Eine automatisch ausgelöste Aktion lädt zuerst 0,6 s sichtbar auf (die Seifenblase nur 0,15 s, damit sie rechtzeitig schützt): oben in der Bildmitte erscheinen ihr Symbol mit einem sich füllenden Ring in ihrer Farbe und ihr Name. Gezielte Kräfte zeigen dabei im Spielfeld einen pulsierenden Zielkreis, der sich bis zum Auslösen zusammenzieht – am Einschlagsort der Glutbombe bzw. des Höllenschlunds, an der Stelle, an der der Wirbel- bzw. Gewittersturm entsteht, und beim Felsbeben am Boden um den Vogel. Das Ziel wird beim Ankündigen festgelegt. Beim Auslösen ploppt der Name groß mit Ausrufezeichen auf und verblasst in 1 s (wie der Countdown am Wellenende); per Taste ausgelöst entfällt das Aufladen, der Name erscheint trotzdem. Die Abklingzeiten beginnen bei jedem Run bei 0 und laufen über Wellen hinweg weiter.

Schadensbasis für Aktionen: (8 + 2,5 × Welle) × (1 + Schaden %) × Welt-/Wetter-Faktor (× 1,5 in Stufe II).

| Aktion | Klasse | Quelle | Wirkung (Stufe I) | löst automatisch aus, wenn … | Abklingzeit |
| --- | --- | --- | --- | --- | --- |
| Glutbombe | Glut | Item (Episch, 24), Rudi Rennfeder | Explosion auf der dichtesten Gegnergruppe im Bild (Radius 110): Schadensbasis × 2 als Glut-Treffer, alle darin brennen 3 s (Schadensbasis × 0,3 pro s) | mindestens 3 Gegner im Umkreis 110 eines Gegners | 12 s |
| Platzregen | Wasser | Item (Episch, 24), Frack | Wolkenbruch über dem ganzen Bild: jeder Gegner im Bild bekommt einen Wasser-Treffer (Schadensbasis × 0,3), ist 4 s nass und 30 % langsamer | mindestens 4 Gegner im Bild oder ein Boss bzw. Torwächter | 14 s |
| Wirbelsturm | Wind | Item (Episch, 26), Glitzer | Tornado (Radius 70) entsteht bei der dichtesten Gruppe und treibt 4 s zum nächsten Gegner; zieht Gegner (außer Boss und stationären) und Material im Umkreis 168 heran, alle 0,4 s Wind-Treffer (Schadensbasis × 0,45) | mindestens 3 Gegner im Umkreis 260 oder mindestens 12 Material im Bild | 14 s |
| Lichtblitz | Licht | Item (Episch, 22), Professor Uhu | betäubt alle Gegner im Bild 1,5 s und trifft sie als Licht-Treffer (Schadensbasis × 0,3), Bildschirm blitzt weiß | mindestens 5 Gegner im Bild, ein Boss im Bild oder unter 35 % HP | 12 s |
| Fluchschrei | Böse | Item (Episch, 22), Aurelius | alle Gegner im Bild 5 s verflucht, sie weichen 0,8 s zurück | wie Lichtblitz | 10 s |
| Felsbeben | Stein | Item (Selten, 20), Hacki | Schockwelle im Umkreis 220: Bodengegner 1,5 s betäubt, Flieger (außer Boss) zu Boden geschleudert und 0,6 s betäubt; alle bekommen einen Stein-Treffer (Schadensbasis × 0,8) | mindestens 2 Gegner im Umkreis 220 oder Gefahr näher als 78 | 9 s |
| Seifenblase | – | Item (Selten, 20) | Blase schluckt 1,5 s lang jeden Treffer | eine Gegnerkugel oder ein angreifender Gegner näher als 70, oder unter 35 % HP mit Gegnern im Umkreis 200 | 14 s |
| Ei legen | – | Henriette | Ei rollt zum nächsten Gegner (der Vogel dreht sich zu ihm) und explodiert nach 1,6 s oder bei Gegnerkontakt (Radius 75, Schadensbasis × 1,6) | ein Gegner im Umkreis 260 | 2,5 s |

**Aktions-Items kaufen:**

- **Neu und ein Platz frei:** Die Aktion kommt in den freien Platz.
- **Gleiche Aktion schon vorhanden:** Sie steigt auf Stufe II – Abklingzeit × 0,7, Wirkung × 1,5 (Dauer, Schaden; Radien × 1,3). Stufe II ist das Maximum; danach wird das Item nicht mehr angeboten.
- **Beide Plätze belegt:** Der Spieler wählt im Shop, welche Aktion ersetzt wird (oder bricht ab).

**Evolution:** Liegen zwei passende Aktionen in den Plätzen, erscheint im Shop „Verschmelzen → …“. Ein Klick macht daraus die Evolution in Platz 1, Platz 2 wird frei. Dazu läuft eine kurze Verschmelz-Animation (2,3 s, mit Klick/Enter/A überspringbar): beide Aktions-Symbole kreisen aufeinander zu, ein Lichtblitz, dann wächst die Evolution mit rotierendem Goldring und Funken heraus, darunter „EVOLUTION“, der Name groß in Gold und die Wirkung. Die Stufe der Zutaten geht dabei verloren; Evolutionen haben keine Stufe II. Rezepte sind sofort sichtbar: im Shop unter den eigenen Aktionen und auf Aktions-Items („passt zu … → …“). Es gibt nur drei Evolutionen – jeweils aus zwei Klassen-Kräften, wie eine große Reaktion:

| Zutaten | Evolution | Wirkung | löst aus, wenn … | Abklingzeit |
| --- | --- | --- | --- | --- |
| Platzregen + Wirbelsturm | Gletscher | alle Gegner im Bild frieren 2 s ein (Boss 0,6 s), Gegnerkugeln stehen 2 s still | wie Lichtblitz | 18 s |
| Glutbombe + Fluchschrei | Höllenschlund | Glutbombe mit Schadensbasis × 2,6 und größerem Radius, danach alle Gegner im Bild 5 s verflucht – brennend verfluchte Gegner lösen beim Tod Höllenfeuer aus | wie Glutbombe, oder 5 Gegner bzw. ein Boss im Bild | 16 s |
| Wirbelsturm + Lichtblitz | Gewittersturm | Wirbelsturm, der zusätzlich alle 0,3 s einen Blitz in einen Gegner im Umkreis 220 schleudert | wie Wirbelsturm | 18 s |

## Charaktere

Zwölf spielbare Vögel. Jeder hat eine Stärke, einen Nachteil und vor allem ein eigenes **Flugverhalten**. Der gewählte Vogel wird gespeichert; gesperrte Vögel zeigen ihre Aufgabe.

| Vogel | Rolle | Stärke | Nachteil | Fliegt … | Start |
| --- | --- | --- | --- | --- | --- |
| Kampfspatz (Spatz) | Allround | +10 % Material (jedes Stück hat 10 % Chance auf +1) | keine Spezialität | normal – das Maß aller Dinge | Lichtfeder / Böenschwarm / Funkenfächer (keine Startaktion) |
| Glutkehlchen (Rotkehlchen) | Glut | Brand hält 50 % länger und schadet 25 % mehr | −30 Reichweite | normal, mit Funkenspur | Funkenfächer / Glutkern / Popcornmaschine |
| Böe (Schwalbe) | Wind | +20 % Angriffstempo, schnellster Flieger | −5 Max-HP | sehr schnell, enge Kurven | Böenschwarm / Federwirbel / Pusteblume |
| Schillerchen (Kolibri) | Licht | +15 % Krit, winzige Trefferfläche | −40 % Max-HP | fliegt frei in alle Richtungen, steht in der Luft | Diskokugel / Lichtfeder / Sonnenstrahl |
| Ruß (Rabe, abtrünnige Fäulnis-Krähe) | Böse | Böse-Waffen +25 %, +3 % Lebensraub | Herzen heilen nur 2 statt 3 | schwer, gleitet lange | Dornenranke / Krähenruf / Paktlaterne |
| Frack (Pinguin) | Wasser | +50 % Max-HP, +3 Rüstung; Material fällt auf jeder Stufe schnell zu Boden (70/s, wie auf Phönix), weil er schwebendes kaum erreicht | kann kaum fliegen | mühsam in der Luft, am Boden rasend schnell | Wasserpistole / Seifenblasen / Regenwolke + Platzregen |
| Hacki (Specht) | Stein | Stein-Waffen +25 %, +3 Rüstung | −15 % Angriffstempo | ruckartig, klammert sich an den Weltrand | Kieselschleuder / Gartenzwergwerfer / Bowlingkugel + Felsbeben |
| Professor Uhu (Eule) | Licht/Böse | +25 % Erfahrung; in Wald, Gebirge, Gipfel +20 % Schaden | in Feldern und Dorf −10 % Schaden | lautlos, sinkt sehr langsam | Lichtfeder / Sonnenstrahl / Krähenruf + Lichtblitz |
| Glitzer (Elster) | Wirtschaft | Shop −15 %; 1 % je Kill ein Geschenk (zufälliges gewöhnliches oder seltenes Werte-Item) | nur 4 Waffenslots | normal | Wasserpistole / Diskokugel / Kieselschleuder + Wirbelsturm |
| Henriette (Huhn) | Glut/Stein | +40 % Max-HP, +2 Rüstung, Eier als Bomben | keine Startwaffe, fliegt nur kurze Hüpfer | flattert in Hüpfern, viel Bodenzeit | Ei legen; Waffen nur aus dem Shop |
| Rudi Rennfeder (Strauß) | Boden/Stein | schnellster Läufer (am Boden × 2), +60 % Max-HP, +2 Rüstung; Material fällt auf jeder Stufe schnell zu Boden (70/s) | kann nicht fliegen – nur hohe Sprünge, sinkt schnell | rennt und springt | Kieselschleuder / Bowlingkugel / Federwirbel + Glutbombe |
| Seine Hoheit Aurelius (Steinadler) | Licht/Stein | +20 % Schaden, kritische Treffer ×2,5 statt ×2, Adleraugen +80 Reichweite | groß (leichter zu treffen), träge in Kurven | majestätischer Gleiter, sinkt sehr langsam | Sonnenstrahl / Glutkern / Kieselschleuder + Fluchschrei |

**Startwaffe:** Jeder Vogel außer Henriette hat drei Startwaffen zur Auswahl (Spalte „Start“, die erste ist voreingestellt). Gewählt wird unter „Run vorbereiten“; die Wahl wird je Vogel gespeichert.

Max-HP: Start 20, dann Änderungen des Vogels, dann × Max-HP-Faktor (gerundet).

**Flugprofile** (Faktoren auf die Werte unter „Steuerung & Bewegung“; nicht genannte = 1):

| Vogel | Tempo | Beschleunigung | Schub | Gleiten (Sinken) | Am Boden | Radius | Größe | Besonderheit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Kampfspatz | 1 | 1 | 1 | 1 | 1 | 16 | 1 | – |
| Glutkehlchen | 1 | 1 | 1 | 1 | 1 | 16 | 1 | Funkenspur |
| Böe | 1,3 | 1,5 | 1 | 1 | 1 | 16 | 1 | – |
| Schillerchen | 1 | 1 | – | – | 1 | 11 | 0,75 | freier Flug ohne Schwerkraft: Stick analog in alle Richtungen (halber Ausschlag = halbes Tempo), Tastatur hoch mit Leertaste/W/↑, runter mit S/↓; Touch „▲“ und „▼“; Gleiten-Werte wirken nicht |
| Ruß | 1 | 0,8 | 1 | 0,6 | 1 | 16 | 1 | – |
| Frack | 1 | 1 | 0,62 | 1,4 | 1,7 | 17 | 1,1 | aufrechter Körper |
| Hacki | 1 | 1,3 | 1 | 1 | 1 | 16 | 1 | hält sich am linken/rechten Weltrand fest, solange er dagegen drückt und nicht fliegt |
| Professor Uhu | 1 | 1 | 1 | 0,35 | 1 | 17 | 1,1 | – |
| Glitzer | 1 | 1 | 1 | 1 | 1 | 16 | 1 | – |
| Henriette | 1 | 1 | 1 | 1 | 1,1 | 17 | 1,1 | Schub nur 0,55 s am Stück, lädt am Boden in knapp 0,5 s wieder auf |
| Rudi Rennfeder | 1 | 1 | 1,25 | 2,6 | 2 | 18 | 1,2 | Schub nur 0,4 s am Stück (ein hoher Sprung, etwa ein Drittel der Bildhöhe), lädt am Boden wieder auf; immer sichtbare lange Beine |
| Aurelius | 1,1 | 0,7 | 1,1 | 0,4 | 1 | 20 | 1,25 | – |

**Freischalten:** Der Kampfspatz ist von Anfang an verfügbar, die übrigen über Aufgaben. Geprüft wird am Ende jedes Runs; Zähler über alle Runs werden gespeichert. Neu freigeschaltete Vögel erscheinen im Game-Over-Fenster. Die Aufgaben dienen später zugleich als Erfolge (Steam).

| Vogel | Aufgabe |
| --- | --- |
| Glutkehlchen | 500 Gegner durch Brand besiegen (über alle Runs) |
| Böe | Welle 8 erreichen |
| Schillerchen | Einen Run gewinnen |
| Ruß | 2000 Gegner besiegen (über alle Runs) |
| Frack | Welle 10 mit mindestens 3 Wasser-Waffen erreichen |
| Hacki | Welle 10 mit mindestens 3 Stein-Waffen erreichen |
| Professor Uhu | In einem Run Level 15 erreichen |
| Glitzer | 3000 Material sammeln (über alle Runs) |
| Henriette | Mit dem Kampfspatz auf Falke (oder höher) gewinnen |
| Rudi Rennfeder | Mit Frack Welle 10 erreichen |
| Aurelius | Auf Stufe Adler (oder höher) gewinnen – mit einem beliebigen Vogel |

## UI & HUD
 
Im Spiel zeigt ein schlankes HUD nur das Nötigste; alle Menüs sind Overlays über der angehaltenen Szene.
 
- **HUD oben links:** Level als leuchtender Orb, die XP laufen als Lichtbogen um ihn herum; daneben die HP als leuchtende Glaskapsel mit Zahl darunter und der Materialzähler mit Mint-Kristall.
- **HUD oben Mitte:** „WELLE X“ klein, darunter der Countdown (rosarot unter 5 s) und eine feine Lichtlinie bis zum Ziel mit leuchtendem Punkt für den Spieler und kleiner Lichtsäule am Ende; in Welle 15 stattdessen „DER GEIERKÖNIG“ mit magentafarbener HP-Kapsel.
- **Aktionen unten links:** je Platz ein Glaskreis mit dem Symbol der Aktion (Evolutionen in kräftigerem Gold, Stufe II mit Punkt); während der Abklingzeit läuft ein Lichtbogen und daneben die Restsekunden, bereit leuchtet er golden mit dem Namen der Aktion; darunter die erste belegte Taste (mit Controller der Knopf). Wird eine Aktion wieder bereit, springt ihr Kreis 0,8 s lang kurz auf, ein Lichtring läuft nach außen, darüber steht „BEREIT!“, und um den Vogel leuchtet ein kleiner Ring mit Funken in der Farbe der Aktion; solange sie bereit ist, pulsiert der Kreis sanft. Mit Touch-Steuerung sitzen sie über den Bewegungsknöpfen. Der Lichtblitz lässt das Bild kurz weiß aufblitzen.
- **Wetteranzeige:** Unter Timer bzw. Boss-Leiste steht das aktuelle Wetter (bei Wind mit Richtungszeichen, z. B. „Wind ›“); das Wellenbanner nennt es ebenfalls.
- **Einblendungen:** Wellenbanner zu Beginn (Weltname in der Kantenfarbe der Welt darüber), schwebende Schadenszahlen (weiß, Krit gelb, Spieler rot, Heilung mint; höchstens 40 gleichzeitig, mit scharfem Schatten statt Schein), „LEVEL UP“ am Spieler. Texte im Spiel haben einen weichen Schein in ihrer Farbe statt einer Kontur.
- **Titelbildschirm:** großes, sanft atmend leuchtendes „FEDERFEUER“ über der lebendigen Felder-Welt (Kamera gleitet, der Geistvogel zieht ruhige Bögen unter dem Menü), darunter „Flieg durch das Licht bis zum Gipfel“ und die Menüpunkte als leuchtender Text: Spielen, Einstellungen, Rekorde, Kompendium, Credits, Debug (nur Debug-Builds), Beenden (nur PC). Der gewählte Punkt leuchtet weiß mit Lichtkugel davor. Unten links die Version, unten rechts die Bedienhinweise. Esc bzw. Controller-B führt von jeder Unterseite zurück zum Titel.
- **Run vorbereiten (Spielen):** Links die Schwierigkeit als Leiste mit fünf Stufen (gesperrte mit Schloss; darunter Faktoren und Rekord der gewählten Stufe) und eine Kurzerklärung. Rechts „Vogel wählen“: zehn Kacheln mit Vogel-Vorschau (gesperrte als dunkle Silhouette mit Schloss; antippen zeigt die Aufgabe mit Fortschritt), darunter der gewählte Vogel mit Flügelschlag-Vorschau, Name, Art und Rolle, Stärke, Nachteil und Flugverhalten, darunter „Startwaffe“ mit den drei wählbaren Waffen des Vogels (gewählte golden mit ✓, Info-Panel mit den Werten inklusive Klassenbonus des Vogels; Henriette: „keine Startwaffe“), dann Startaktion und ggf. Waffenslots sowie der Knopf „Starten“.
- **Einstellungen:** Anzeige (Vollbild/Fenster) und Auflösung (PC) als Auswahllisten, Skalierung (alle Plattformen), Bildschirmwackeln an/aus, FPS-Anzeige an/aus (beides gespeichert), die Steuerung als umschaltbare Übersicht Tastatur/Controller mit Neubelegung (siehe „Steuerung & Bewegung“) und auf Touch-Geräten die Touch-Knöpfe.
- **Rekorde:** Bestleistung je Schwierigkeitsstufe (geschafft, erreichte Welle, gesperrt), Statistik-Kacheln (Runs, Siege, besiegte Gegner, höchstes Level, verbrannte Gegner, gesammeltes Material) und die Liste der Vögel mit „freigeschaltet“ bzw. Aufgabe und Fortschritt.
- **Kompendium:** Sammlung aller Inhalte mit Reitern Vögel, Waffen, Items, Aktionen (inkl. Evolutionen), Kombinationen, Reaktionen, Werkbank und Gegner. Die **Werkbank** baut Waffen zusammen: Grundwaffe wählen (unentdeckte als „?“), Stufe I–IV, Gaben aus den anderen entdeckten Waffen (höchstens Stufe + 1) und Eigenschaften (je Stufe eine, mehrfach möglich); daneben zeigt das Waffen-Info-Panel live Werte, Klassen, Effekte und Reaktionen der Kombination. „Reaktion suchen“ listet alle Kombinationen aus Grundwaffe und Gabe, mit denen eine Waffe die gewählte Reaktion allein auslöst; Antippen lädt sie. Die übrigen Reiter: jeder Reiter und die Kopfzeile zeigen „entdeckt / gesamt“. Sichtbar ist nur, was schon einmal gesehen wurde: Waffen und Items, sobald sie im Shop lagen oder besessen wurden; Aktionen ebenso bzw. als Startaktion oder Evolution; Gegner, sobald einer erschienen ist (der Reiter zeigt auch Torwächter und die fünf Elite-Modifikatoren, letztere sobald ein solcher Elitegegner aufgetaucht ist); Kombinationen, sobald eine ihrer Zutaten besessen wurde (dann zeigt der Shop das Rezept ohnehin) – selbst verschmolzene tragen „✓ verschmolzen“ und einen goldenen Rand. Der Reiter Kombinationen zeigt ein **Sternbild** auf eigenem Nachthimmel (dunkelblauer Verlauf, zwei Nebelschleier, rund 110 funkelnde Hintergrundsterne): die 13 Vogel- und Shop-Aktionen als Sterne mit atmendem Lichthof auf einer feinen Umlaufbahn (Ellipse über die volle Breite; jede Vogel-Aktion sitzt zwischen ihren beiden Rezeptpartnern), jedes Rezept als leicht gebogene Lichtbahn zwischen den Zutaten und die Evolution als etwas kleinere Kugel wie die Aktionen, nur mit goldenem Rand und dezentem Schein, dazwischen (etwas zur Mitte gerückt; anschließend stoßen sich die Evolutionen untereinander und von den Aktions-Sternen ab, damit nichts überlappt). Unentdeckt: gestrichelt, „?“ ohne Beschriftung; gesehen: schwach leuchtende Bahn; selbst verschmolzen: gedämpft goldene Bahn mit Lichtpartikeln, die zur Evolution wandern. Oben links „x / 28 verschmolzen“. Ein angewählter Stern hebt alle seine Verbindungen hervor (hell, mit Partikeln) und zeigt das Info-Panel. Unbekanntes erscheint als „?“ / „???“ mit kurzem Hinweis, wo es zu finden ist. Vögel sind immer gelistet, gesperrte als dunkle Silhouette mit Aufgabe und Fortschritt. Kacheln zeigen statt Emojis die echte Darstellung: Vögel und Gegner in ihrer Spielgrafik (leuchtender Geist bzw. Fäulnis, Bosse in voller Zeichnung), Waffen als ihr Modell im Klassen-Leuchten, Items und Werte als kleine leuchtende Objekte in ihren eigenen Farben (Lichtverlauf, Glanzpunkt, Lichtkante, Schein), Aktionen ebenso auf einem dunklen Medaillon mit Ring in ihrer Aktionsfarbe, Evolutionen auf einem goldenen Doppelring mit eigenem Motiv (z. B. Rakete in der Blase, Kamera, Sanduhr). Die Seltenheit zeigt der Kachelrand. Auch Bedien-Symbole (Pfeile in Texten, Würfeln, Schloss, Play, Stern, Herz, Material, Pokal …) sind gezeichnete Lichtsymbole statt Emojis, damit sie auf jeder Plattform gleich aussehen. Dieselben Symbole nutzen Shop, Run-Übersicht, Level-up, Info-Panels, Sternbild, Verschmelz-Animation, Touch-Knöpfe und HUD. Jede Kachel ist ansteuerbar und zeigt das Info-Panel wie im Shop (Waffen in Stufe I mit Grundwerten, Gegner mit Werten aus Welle 1 auf Küken). Gespeichert über alle Runs; „Alles freischalten“ (Debug) zeigt alles.
- **Credits:** Engine, Schriften mit Lizenzhinweis (SIL OFL 1.1), Bibliotheken, Version.
- **Debug (nur Debug-Builds):** Alles freischalten (Stufen und Vögel), Unverwundbar, Welle wählen (direkt oder mit Shop davor), Performance-Test, Render-Analyse.
- **Level-up:** 4 Karten mit großem Wert (z. B. „+4 %“); die ganze Karte ist wählbar. Seltene Karten haben ein lila Kopfband und das Badge „SELTEN“.
- **Shop-Kurztasten:** R bzw. Controller-X = Neu würfeln, N bzw. Start = Welle starten, L bzw. Y = gewähltes Angebot zurückhalten, Bild ↓/↑ bzw. RB/LB = zum nächsten/vorigen Bereich springen (Angebote → Waffen & Items → Aktionen & Werte; scrollt mit). Bewusst nicht W/Leertaste/S, die im Spiel zum Fliegen dienen; in den ersten 0,5 s nach dem Öffnen wirken die Kurztasten nicht. Neben „Neu würfeln“ und „Welle starten“ steht die Taste (Tastenkappe bzw. Controller-Knopf); mit Tastatur zeigt die Fußleiste „R würfeln · L zurückhalten · Bild ↑↓ Bereich“, mit Controller die Hinweiszeile „Ⓐ Kaufen · Ⓧ Neu würfeln · Ⓨ Zurückhalten · LB/RB Bereich · Menü Welle starten“.
- **Shop:** Kopfzeile mit Hinweisen (Zeitbonus, nächste Welt); feste Fußleiste unter dem Scrollbereich mit Geld links und dem Start der nächsten Welle rechts – immer sichtbar, auch wenn die Seite gescrollt werden muss. Fünf Angebotskarten in einer Reihe (rechts das Aktions-Angebot) mit Kopfband in Stufenfarbe bzw. Seltenheitsfarbe (gewöhnliche Items apricot), Badge mit Stufe, Seltenheit oder „AKTION“; grün „STUFE … · PAAR“, wenn der Spieler die Waffe in gleicher Stufe schon hat, bzw. „⤴ STUFE …“, wenn der Kauf bei vollen Slots direkt verschmilzt. Waffenkarten zeigen ihre Klasse und grün „Set N!“, wenn der Kauf die nächste Set-Stufe erreicht; Item-Karten ihre Beschreibung; Aktions-Items zusätzlich grün „⤴ STUFE II“ bzw. „passt zu … → …“ (eine Zeile; bei mehreren passenden Rezepten mit „(+n)“, die übrigen zeigt das Info-Panel) und ggf. „Plätze voll – ersetzt eine Aktion“ (beim Kauf erst den Platz wählen). Preis-Etikett als Fußzeile; zu teure Karten sind ausgegraut und nicht kaufbar, lassen sich aber ansteuern, um das Info-Panel zu sehen; gekaufte werden zu einem leeren Platz. Unter jeder Karte ein Schloss-Knopf „🔓 Zurückhalten“, zurückgehalten golden „🔒 Zurückgehalten“. **Details:** Alles im Shop ist ansteuerbar (Pfeile/Tab, Controller, Maus) – Angebote, Waffenslots, Items, Aktionen, Set-Boni und Werte; zu teure Angebote bleiben ansteuerbar; Klassennamen erscheinen überall in ihrer Klassenfarbe (Info-Panels, Waffenslots, Klassen-Tags); Anzeigen ohne eigenen Knopf bekommen beim Fokus einen weißen Lichtrand. Zum gewählten bzw. überfahrenen Element erscheint daneben ein Info-Panel (rechts, sonst links, sonst darunter; immer im Bild, wächst mit der UI-Skalierung): Waffen mit allen Werten der Stufe, Effekten, Klassen-Set (erreichte Stufen grün, die nächste per Kauf gold), Schaden der nächsten Stufe und ggf. Preis bzw. Verkaufserlös; Verschmelzen-Knöpfe zeigen eine Vorschau – bei Waffen die Werte vorher → nachher (Schaden, Abklingzeit, ggf. Brand/Kleben, Verkaufswert) und dass der zweite Slot frei wird, bei Aktionen die Evolution mit Wirkung und Abklingzeit, dass Platz 2 frei wird und ggf. dass Stufe II der Zutaten verloren geht; Items mit Seltenheit, Werten, Wirkung und Besitz; Aktionen mit Abklingzeit, Stufe II, Wirkung des Kaufs und allen Rezepten (passende grün); Set-Boni mit allen Schwellen und den Waffen der Klasse; Werte mit Erklärung und Anteil aus Set-Boni/Items. Es ist immer nur ein Panel offen. Darunter der **Waffenring**: Die eigenen Waffen schweben wie im Spiel im Kreis um den Vogel (alle Plätze, freie gestrichelt); jede Waffe ist eine runde Leuchtkachel mit Rahmen in Stufenfarbe, Stufen-Abzeichen, Punkten in ihren Klassenfarben und Rauten für die Gaben-Plätze (gefüllt = belegt). Antippen wählt eine Waffe; darunter erscheint eine Aktionsleiste mit Name, Klassen und den Knöpfen Verschmelzen (der passende Partner leuchtet grün), Gabe und Verkaufen, jeder mit eigenem Info-Panel. Nach „Gabe“ leuchten alle möglichen Empfänger violett, Antippen gibt die Gabe ab („abbrechen“ in der Leiste). Rechts „Aktionen“ (beide Plätze mit Stufe und Abklingzeit, grüner Knopf „Verschmelzen → …“ samt Wirkung, sonst die möglichen Rezepte; beim Ersetzen die Auswahl des Platzes), „Set-Boni“ (je Klasse Anzahl und aktiver Bonus bzw. „n/nächste Schwelle“) und die Werte in zwei Spalten.
- **Pause & Game Over:** Pause zeigt eine komplette Übersicht des Runs: Vogel mit Vorschau, Level, HP, Material, Welle, Welt und Stufe; links Waffen (Stufe, Klasse), Items mit Anzahl (Seltenheitsfarbe) und Aktionen mit Abklingzeit; rechts Set-Boni und alle Werte. Alles ist ansteuerbar und zeigt das Info-Panel wie im Shop (ohne Verkaufsinfo). Weiterspielen und Aufgeben (am PC auch Vollbild) stehen in einer festen Fußleiste; Controller-B spielt weiter. Game Over zeigt „SIEG!“ bzw. „ABGESTÜRZT“ (mit dem Namen des Vogels), Kacheln für Welle, Gegner und Level, die Stufe, ggf. die neu freigeschaltete Stufe und neu freigeschaltete Vögel mit Vorschau, „Neue Runde“ (führt direkt zu „Run vorbereiten“) und „Hauptmenü“.
- **Controller-Hinweise:** Sobald ein Controller benutzt wird, zeigen alle Menüs unten eine feste Hinweiszeile mit Knopf-Symbolen in Xbox-Farben – Titel „Ⓐ Bestätigen · ✚ Wählen“ (statt der Tastaturhinweise), Unterseiten „Ⓐ Auswählen · Ⓑ Zurück · ✚ Navigieren“, Level-up „Ⓐ Verbesserung wählen“, Shop siehe „Shop-Kurztasten“, Pause „Ⓐ Auswählen · Ⓑ Weiterspielen“, Game Over „Ⓐ Auswählen“. In Welle 1 steht unter dem Wellenbanner die aktuelle Belegung (z. B. „A halten: fliegen · X / Y: Aktionen · Menü: Pause“). Ein Tastendruck auf der Tastatur blendet die Hinweise wieder aus.
- **Menü-Navigation:** Alle Buttons sind per Tastatur (Pfeile/Tab, Enter/Leertaste) und Controller (Steuerkreuz oder Stick, A bestätigt) bedienbar; der fokussierte Knopf bzw. die fokussierte Karte hebt sich an, leuchtet heller und bekommt einen weißen Lichtrand (bei Mauszeiger darüber ohne Rand). Mit Controller ist in jedem neuen Menü sofort der erste Button fokussiert. In den ersten 0,5 s nach dem Öffnen eines Menüs wird Controller-A ignoriert, damit ein Tippen zum Fliegen nichts versehentlich auswählt.
 
Stil: leuchtendes Glas passend zur Spielwelt – ruhig und edel statt Arcade-Sticker.

- **Panels:** dunkles, durchscheinendes Glas (Nachtblau) mit feiner Lichtkante, bläulichem Schein nach außen und einem Lichtschimmer oben.
- **Karten und Knöpfe:** dunkles Glas, getönt in der Akzentfarbe (Gold für Hauptaktionen, Mint für Start/Weiter, Lila für Seltenes, Stufenfarben bei Waffen); oben ein leuchtendes Farbband mit Symbol im Lichtkreis. Bei Fokus/Hover werden Kante und Schein heller und das Glas hebt sich leicht; beim Antippen sinkt es ein.
- **Skalierung:** Menüs und HUD sind für 1280 × 720 (logische Pixel) ausgelegt und wachsen auf größeren Bildschirmen gleichmäßig mit: Faktor = min(Breite / 1280, Höhe / 720), mindestens 1, höchstens 2,2 (Full HD = 1,5). Auf kleineren Bildschirmen (Handys) bleibt alles in Originalgröße. Unter Einstellungen → Skalierung lässt sich das Ergebnis auf 50–100 % (in 10er-Schritten, Standard 100 %) verkleinern; größer geht nicht, weil der Standard den Bildschirm bereits ausfüllt. Die Wahl wird gespeichert und wirkt sofort auf Menüs und HUD.
- **Touch-Knöpfe und Pause:** Glaskreise mit feiner Lichtkante; gedrückt leuchten sie golden.
- **Schrift:** Cinzel (elegante Versalien) für Titel und Beschriftungen, Nunito für Fließtext und für alle Zahlen (Cinzel zeichnet die 1 wie ein römisches I); beide unter SIL Open Font License in `assets/fonts/`. Die System-Schriftgröße wird in den Menüs ignoriert, weil Karten feste Größen haben.
 
## Technische Umsetzung (Flutter + Flame)
 
Die Spielwelt läuft komplett in Flame, alle Menüs und Touch-Buttons sind Flutter-Widgets als Overlays des `GameWidget`. Kollisionen werden manuell per Kreisabstand geprüft statt über `HasCollisionDetection` – bei vielen Kugeln schneller und deterministisch.

Gebaut wird mit Flutter 3.47.6 (lokal und in GitHub Actions). Unter Windows rendert das Spiel mit Skia statt Impeller (`windows/runner/main.cpp`): Mit Impeller (OpenGL ES) dauerte ein Bild in der Render-Analyse etwa doppelt so lange.
 
| Datei | Verantwortung |
| --- | --- |
| `lib/main.dart` | App-Start, Querformat, `GameWidget` mit Overlay-Map |
| `game/federfeuer_game.dart` | `FlameGame`: Phasen, Wellen, Spawns, Kamera, Kampf, Tastatur |
| `game/config.dart` | Alle Daten: Waffenklassen und Set-Boni, Waffen, Stufen, Aktionen, Items mit Seltenheit, Charaktere mit Freischaltaufgaben, Level-ups, Gegner, Farben, Welten (`biomeDefs`), Wetter (`WeatherConfig`) |
| `game/run_state.dart` | Zustand eines Runs: Vogel, Werte inkl. Set-Boni, Waffenwerte (`WeaponStats`), Inventar, Aktion, Shop- und Level-Logik |
| `components/player.dart` | Flugphysik mit Flugprofil des Vogels, Chaos-Zustände, Blinzeln und Blick, Aura und Schweif |
| `components/bird_art.dart` | Haltung der Vögel (`BirdPose`: Flügelschlag, Blick, Blinzeln, Laufen, Halten, Zeit) und Einstieg fürs Zeichnen, auch für Menü-Vorschauen |
| `components/boss_art.dart` | Ausführliche Zeichnungen der Bosse: Geierkönig, Strohkönig, Glocke, Spinnenmutter (`BossLook`: Zeit, Puls, Warnung, Treffer, Phase) |
| `components/enemy_art.dart` | Ausgearbeitete Formen der übrigen Gegner (`EnemyLook`) |
| `components/glyph_art.dart` | Leuchtende Symbole für UI und HUD (`GlyphRef`: Waffe, Item, Aktion, Wert, Gegner, Vogel, Bedien-Symbol), das `Glyph`-Widget und `GlyphText` (ersetzt Symbolzeichen im Text) |
| `components/glyph_objects.dart` | Zeichnungen der Item-, Aktions-, Evolutions-, Wert- und Bedien-Symbole samt wiederverwendbarer Motive (Blitz, Blase, Ei, Horn, Uhr, Sonne …) |
| `components/rot_art.dart` | Bausteine des Fäulnis-Stils der Gegner (dunkle Füllung mit violettem Kern, glühende Adern, Gegenlichtkante, Rauch, zerfetzte Flügel) und die Fäulniskrähe |
| `components/spirit_bird_art.dart` | Vögel im Stil „leuchtender Geist“: Maße je Art, Silhouette, Lichtflügel, Schwanzformen, Augen, Leuchtakzente, Funken |
| `components/weapon_art.dart` | Modelle aller 18 Waffen und die Krallen der gehaltenen Waffe |
| `components/weapon_mount.dart` | Waffe in den Krallen bzw. im Ring um den Spieler, Zielsuche, Verhalten je Waffenart (Schuss, Wurf, Kreis, Hieb, Begleiter, Wolke, Rollen, rundum) |
| `components/weapon_fx.dart` | Geisterkrähen, Regenwolke, Peitschenbogen, Henriettes Ei (auch Gewitterei), Blitz (Mixin `CombatEffect`) |
| `components/enemy.dart` | KI und Zeichnung der Grundgegner, Statuseffekte, Elitegegner; Teil-Dateien `enemy_world.dart` (Welt-Gegner, Giftwolke, Sprengsatz), `enemy_gate.dart` (Torwächter), `enemy_boss.dart` (Phasen des Geierkönigs, Federregen), `enemy_sprites.dart` (vorgerenderte Gegner: je Typ ein Atlas mit den Phasen der Hauptbewegung, Pulsstufen und Varianten in Bildschirmauflösung; alle Körper werden gebündelt per drawAtlas gezeichnet, Treffer-Blitz über die Atlas-Farbe; live bleiben Rauch, Fäden, Zeiger, Statusanzeigen sowie Boss, Torwächter, Irrlicht, Riss und Ei) |
| `components/projectiles.dart` | Spielerkugeln (Durchschlag, Explosion, Bogenwurf, Zünder, Rollen, Treffereffekte) und Gegnerkugeln |
| `components/pickups.dart` | Material-, Herz- und Geschenk-Drops und Spawn-Warnungen |
| `components/effects.dart` | Partikel, Explosionsring, schwebende Zahlen |
| `components/scenery.dart` | Himmel, Licht und Strahlen, Sterne, Polarlicht, vier Silhouetten-Ebenen mit Dunst und Schnee, Boden mit Lichtkante, Leuchtpflanzen, Fluss, Weltgrenzen – je nach Welt |
| `components/decor.dart` | Kulissen-Silhouetten auf dem Boden mit Lichtkante und Leuchtpunkten |
| `components/atmosphere.dart` | Unscharfer Vordergrund (Parallax 1,35), Lichtpartikel und Vignette |
| `components/light.dart` | Glow- und Strahl-Textur, additive Leuchtpunkte und Lichtstrahlen, gesammelt zeichnen (`GlowBatch`, `Rays`) |
| `components/tris.dart` | Silhouetten als Dreiecke (`TriBatch`: Rechteck, Oval, Polygon mit Ear Clipping, Gelände, Streifen) |
| `components/goal.dart` | Ziel am rechten Weltende |
| `components/hud.dart` | HUD im Viewport, Randpfeile |
| `game/weather.dart` | Wetterzustand, Würfeln pro Welle, Modifikatoren |
| `platform/desktop_window.dart` | Fenster und Vollbild am PC (window_manager), F11/Alt+Enter, gespeicherter Modus und Fenstergröße |
| `game/perf.dart` | Debug: Frame-Messung, FPS-Anzeige, Ergebnisse von Performance-Test und Render-Analyse, abschaltbare Bildteile |
| `ui/workbench.dart` | Werkbank im Kompendium: Waffen mit Stufe, Gaben und Eigenschaften zusammenstellen, Reaktion suchen |
| `game/progress.dart` | Fortschritt über Runs: freigeschaltete Stufen und Vögel, gewählter Vogel, Bestleistung pro Stufe, Statistik, Freischalt-Prüfung, Kompendium (gesehene Einträge, Evolutionen), Debug-Modus |
| `game/settings.dart` | Gespeicherte Einstellungen (Bildschirmwackeln, FPS-Anzeige, Skalierung, Tastenbelegung) |
| `game/input_bindings.dart` | Frei belegbare Spielaktionen für Tastatur und Controller, Standardbelegung, Speichern, Tastennamen |
| `game/gamepad_input.dart` | Controller-Eingaben nach Belegung: Bewegung, Fliegen, Aktionen, Pause; feste Menü-Navigation; Erfassung beim Neubelegen |
| `components/weather_layer.dart` | Regen, Windlinien und Blätter im Viewport, Pfützen am Boden |
| `ui/*.dart` | Startmenü mit Unterseiten (`menu.dart`), Level-up, Shop, Pause, Game Over, Touch-Steuerung; `widgets.dart` enthält die Bausteine (Panel, Sticker, Knöpfe, Karten, Etiketten), `bird_preview.dart` die Vogel-Vorschau, `controls_editor.dart` die Steuerungs-Übersicht mit Neubelegung, `inspect.dart`/`inspect_info.dart` die Info-Panels (Shop, Kompendium), `compendium.dart` das Kompendium, `run_overview.dart` die Run-Übersicht in der Pause, `constellation.dart` das Sternbild der Verschmelzungen, `fusion.dart` die Verschmelz-Animation |
 
Phasen: `menu → play → cleared → levelUp → shop → play … → over`; `cleared` ist die kurze Einblendung nach einer Welle. Außerhalb von `play` läuft die Engine mit dt = 0 weiter, damit Entfernen/Hinzufügen von Komponenten verarbeitet wird, ohne dass sich etwas bewegt. Temporäre Komponenten tragen das Mixin `Transient` und werden beim Wellenwechsel gesammelt entfernt; Kampf-Effekte (`CombatEffect`) verschwinden schon am Wellenende bzw. beim Tod des Bosses.

Debug-Werkzeuge (in Debug-Builds oder mit `--dart-define=FEDERFEUER_DEBUG=true`; die Web-Version auf GitHub Pages wird als Testversion damit gebaut):

- **Tasten 1 / 2 / 3:** Wetter Klar / Wind / Regen.
- **F3:** FPS-Anzeige oben rechts (für alle Spieler auch über Einstellungen → FPS-Anzeige) – FPS, schlechteste Frame-Zeit der letzten 120 Frames, Build- und Raster-Zeit der Engine, Anzahl Gegner, Kugeln und Komponenten.
- **Menüseite „Debug“ – Alles freischalten:** alle Schwierigkeitsstufen und Vögel frei.
- **Menüseite „Debug“ – Unverwundbar:** der Vogel nimmt keinen Schaden (bleibt für die Sitzung an, wird nicht gespeichert).
- **Menüseite „Debug“ – Welle wählen:** Welle 1–15 auswählen (Torwächter-Wellen violett, Boss rosa) und mit gewähltem Vogel und Stufe direkt starten; oder „Erst Shop“ – Shop vor dieser Welle mit 30 Material je übersprungener Welle zusätzlich zum Startgeld. Mit „Passende Ausrüstung“ (Standard: an) bekommt der Run, was ein typischer Run bis dahin ungefähr hätte: Level ≈ 1,2 je geschaffter Welle (Verbesserungen zufällig), Waffen aus zwei Klassen (die der Startwaffe und eine zufällige) mit wachsender Anzahl (≈ 1 + geschaffte Wellen ÷ 2,6, höchstens Slots) und Stufe (I–II ab Welle 4, II–III ab Welle 8, III ab Welle 13, ab Welle 11 teils eine Stufe mehr), ≈ 0,8 Items je Welle mit der Seltenheit der jeweiligen Welle, ab Welle 5 eine zweite Aktion, ab Welle 9 manchmal Stufe II und ab Welle 11 eine Verschmelzung, wenn möglich.
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
- [ ] Soundeffekte und Musik (`flame_audio`)
- [ ] Performance-Test mit 110 Gegnern auf einem Mittelklasse-Android (Werkzeug vorhanden: „Performance-Test“ im Startmenü, siehe Debug-Werkzeuge)
 
Phase 2 – Inhalte:
 
- [x] Charaktere: zehn Vögel mit Stärke, Nachteil, Flugverhalten und Freischaltaufgaben
- [x] Waffen: sechs Klassen mit Set-Boni, 18 Waffen inkl. Nahkampf, Brand, Verlangsamen, Betäuben
- [x] Gegner pro Welt, Elitegegner, Torwächter am Ende der Welten, Geierkönig mit drei Phasen
- [ ] Balancing der neuen Gegner nach Spieltests
- [x] Weniger, aber zähere Gegner (Spawn-Takt, Gruppengröße, Obergrenze 40, Zähigkeit für HP und Material)
- [x] Neue Werte Glück, Ausweichen und Aktionstempo statt Schub/Gleiten im Level-up; Material wächst langsamer als die Gegner-HP
- [ ] Waffen im Shop gegen Geld aufwerten (falls spät weiter Geld übrig bleibt)
- [x] Elementar-Reaktionen zwischen den Waffenklassen, neuer Zustand Nass, sichtbare Zustände (Brand, Nass, Frost, Fluch)
- [x] Verschmelzen mit Gaben: verschiedene Waffen verschmelzen (Grundwaffe erbt die Gabe der Spenderwaffe, zählt für beide Klassen), gleiche Waffen mit Wahl einer Eigenschaft
- [x] Chaos: Wirrling mit Chaos-Wolken (verwirrt, kopfüber, Spiegelwelt, verklebt) und verrückte Items (Wirrkraut, Hühnerzauber, Gummiflügel)
- [ ] Wellen-Ereignisse (z. B. Glutregen, Lava-Boden, Elitennacht, Nebel, Chaos-Welle), Schwierigkeitsstufen mit verändertem Gegnerverhalten
- [ ] Auslöser-Items („wenn …, dann …“, z. B. nach Ausweichen, beim Sinkflug, je Flughöhe) und verfluchte Items mit spürbarem Nachteil
- [ ] Gegner mit neuen Angriffen in späteren Wellen, Angriffsmuster, die die Flugsteuerung fordern (Strahlen, Bodenwellen, Decke), Trupps mit Anführer
- [x] Items: Seltenheitsstufen, Flug-Items (Schub, Gleiten), Spezial-Items
- [x] Zwei Aktionstasten mit aktiven Fähigkeiten aus Items und Charakteren, Stufe II und Evolutionen
- [x] Aktionen lösen automatisch aus (Regeln je Art), Tasten nur noch optional; keine Touch-Aktionsknöpfe
- [x] Aktionen überarbeitet: acht Signature-Moves (eine Kraft je Waffenklasse plus Seifenblase und Ei), drei Evolutionen; keine Bewegungs- und Einsammel-Aktionen mehr
- [x] Tastenbelegung frei einstellbar (Tastatur und Controller)
- [ ] Balancing der neuen Waffen, Items und Vögel nach Spieltests
- [ ] Weitere Wetter: Nebel, Gewitter, Hitze, Schnee (z. B. Schnee für Gebirge und Gipfel)
- [x] Fünf Schwierigkeitsstufen mit Freischalten durch Sieg
- [x] Wetter-Pools pro Welt
 
Phase 3 – Politur & Release:
 
- [ ] Sprites, Animationen und Treffer-Feedback
- [ ] Einstellungen (Lautstärke, Button-Größe, Linkshänder)
- [ ] Meta-Progression zwischen Runs
- [ ] Store-Release über Codemagic auf Google Play