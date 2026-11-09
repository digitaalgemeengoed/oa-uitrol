# Testen van de Office Assistent

Voor wie het prototype helpt testen. Dank je wel! Gebruik **alleen testgegevens**: verzonnen namen, adressen en nummers.

Alles begint op de downloadpagina van de omgeving (bijvoorbeeld `https://office.haarlem.dev`). Daar staan de werkomgevingen, de downloads en de versies. Inloggen gaat met het testaccount dat je van de beheerder krijgt.

## Wat we willen weten

Per werkomgeving dezelfde ronde, zodat de bevindingen te vergelijken zijn. Noteer bij elke stap: **lukt / lukt deels / lukt niet**, en wat je zag.

1. **Paneel openen.** Opent het paneel van de assistent? Zie je je naam en "PPL"-niveau bovenaan bij Anonimiseren?
2. **Vastleggen.** Metadateren → Zakelijk → voorstellen overnemen → Registreren.
3. **Anonimiseren zoeken.** Anonimiseren → Persoonsgegevens zoeken. Verschijnen de plaatshouders (zoals `[PERSOON 1]`) **in het document zelf**? Gekleurd of gemarkeerd?
4. **Klikken.** Klik in het document op een plaatshouder. Opent het paneel de kaart van dat gegeven?
5. **Grondslag.** Open een kaart. Is de grondslag met de uitleg te begrijpen? Kies een andere grondslag: verandert de kleur van de plaatshouder in het document? Klopt de waarschuwing als je een lagere kiest?
6. **Laat staan.** Kies op een kaart *Laat staan*. Komt het origineel terug in het document?
7. **Selectie.** Selecteer in het document een stuk tekst dat gemist is (bijvoorbeeld een ziekte). Kies *Anonimiseer selectie*: via de werkbalk/het lint, en via de **rechtermuisknop**. Komt er een plaatshouder?
8. **Bevestigen.** *Bevestigen: nieuwe versie vastleggen*. Verdwijnt de stippellijn/onderstreping? Zie je bij Overzicht → Versies "geanonimiseerd uit versie 1"?
9. **Versienummer.** Staat het versienummer in de documenteigenschappen (Word: Bestand → Info → Eigenschappen → Geavanceerd; LibreOffice: Bestand → Eigenschappen → Aangepaste eigenschappen)?
10. **Toegankelijkheid.** Toegankelijkheid → Beoordelen, en een herstelling toepassen. Staan er ook bevindingen met *uit het bestand* (bijvoorbeeld over titel, taal of contrast)? Kloppen ze? Zijn er onterechte meldingen? (Niet in de demo: die heeft geen bestand.)
11. **Inloggen dat misgaat** (mag kort). Laat het inlogscherm een half uur openstaan en log dan pas in: kom je gewoon binnen, of op een pagina met uitleg en een knop? Breekt het inloggen halverwege af (Annuleren, terugknop): zie je uitleg in plaats van een technische foutmelding? Krijg je tijdens het werk "niet meer ingelogd" (bijvoorbeeld na een update van de server): werkt de knop *Opnieuw inloggen*?

## Per werkomgeving

| Werkomgeving | Te installeren | Bijzonderheden |
|---|---|---|
| Demo in de browser | niets | Snelste controle dat alles werkt. |
| Collabora Online | niets | Klikken (4) en selectie (6) kan Collabora niet doorgeven: gebruik *Tekst anonimiseren…* in het paneel. |
| Word, Excel, PowerPoint (web, Windows, Mac) | het manifest | Na een nieuwe versie van het manifest: opnieuw uploaden. Excel en PowerPoint: alle stappen graag, ze zijn nog niet eerder in het echt getest. |
| LibreOffice op Linux | de extensie | Het paneel staat in de zijbalk (tabblad met de groene A). |
| **LibreOffice op Windows** | de extensie | **Nieuw, proef:** het webpaneel in de zijbalk via WebView2. |
| **LibreOffice op Mac** | de extensie | **Nieuw, proef:** het webpaneel in de zijbalk via WKWebView. |

### Extra voor LibreOffice op Windows en Mac

Het webpaneel in de zijbalk is daar nieuw en nog nooit op een echte machine gezien. Juist hier zijn bevindingen waardevol:

- Zie je in de zijbalk het **webpaneel** (zoals in de demo), of het **eigen paneel** van LibreOffice (grijze knoppen) met een melding "Het webpaneel kan hier niet: …"? Noteer die melding letterlijk.
- Kun je **typen** in het paneel (bijvoorbeeld in een veld bij Metadateren), of gaan je toetsen naar het document?
- Wordt het paneel goed **groter en kleiner** als je de zijbalk breder maakt of het venster vergroot?
- Werkt **inloggen**, en blijf je ingelogd als je LibreOffice herstart?
- Gaat een link naar buiten open in je gewone browser?
- Lukt het webpaneel niet, dan kan alles nog via **Office Assistent → Assistent in de browser openen**. Probeer daar dan stap 1 tot en met 9.

Op Windows is de WebView2 Runtime nodig. Die zit in Windows 11 en een bijgewerkte Windows 10. Ontbreekt hij, dan staat dat in de melding.

## Wat je meestuurt

- De **werkomgeving**, het **besturingssysteem** (met versie) en de **versie** van LibreOffice of Office.
- De **versies** van de downloadpagina (manifest, extensie) en wat je zelf hebt geïnstalleerd.
- Per stap: lukt / lukt deels / lukt niet, plus een schermafdruk als iets er vreemd uitziet.
- Bij LibreOffice: het **logboek** (Office Assistent → Logboek openen). Het bevat geen documentinhoud en geen sleutels, alleen wat de extensie deed en wat er misging.
- Bij Office in de browser: eventuele foutmeldingen in de console van de browser (F12 → Console).

Stuur het naar de beheerder van de omgeving, of maak een issue in [digitaalgemeengoed/oa-adapters](https://github.com/digitaalgemeengoed/oa-adapters/issues) met in de titel de werkomgeving en het systeem (bijvoorbeeld "LibreOffice 24.8 · Windows 11 · webpaneel zichtbaar, typen gaat naar document").
