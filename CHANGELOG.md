# Wijzigingen

## 0.20.1 — 2026-11-10

**Woo: "geen categorie"** (oa-contract 0.8.1, opendop-mini 0.11.1, oa-beheer 0.5.1). Niet elk stuk valt in een informatiecategorie van artikel 3.3 Woo. In het beheerportaal, bij Metadatamodel, zet je bij de Woo-informatiecategorie *Ook "geen categorie (niet actief openbaar)" aanbieden* aan en publiceer je een nieuwe versie; dan kan een medewerker dat kiezen in plaats van een categorie die niet klopt. Nieuwe modellen hebben het al aan.

## 0.20.0 — 2026-11-10

**Classificeren, bewaren en vergrendelen** (oa-beheer 0.5.0, opendop-mini 0.11.0, oa-contract 0.8.0, oa-kern 0.8.0, oa-paneel 0.12.0, oa-adapters 0.19.0, oa-integratielaag 0.10.0, oa-services 0.5.4).

- **Classificatie** in het beheerportaal: het classificatiemodel op basis van de Selectielijst gemeenten 2020 (VNG), met afwijkingen, eigen attributen, vergrendelen bij status en de status waarop de bewaartermijn ingaat.
- **Classificeren** in het paneel: de assistent stelt een klasse voor; het Overzicht toont tot wanneer het stuk bewaard wordt.
- Een vergrendeld stuk krijgt geen nieuwe versie; een wijziging wordt een **wijzigingsvoorstel** dat een vrijgever beoordeelt.
- Een **laadscherm** met voortgang tijdens het laden van de Assistent.

Zie INRICHTING.md, stap 9, "Classificatie en vergrendelen".

- Bijwerken in de volgorde VPS 3, VPS 2, VPS 1. Migratie 009 van het platform en migratie 004 van het portaal draaien vanzelf.
- Op VPS 3 opnieuw `sudo /opt/oa-uitrol/server/keycloak-beheer.sh` draaien: dat maakt de rol **vrijgever** aan. Ken hem toe aan wie mag vrijgeven.
- Geef een groep in het portaal `classificatie.manage` (en wie mag afwijken `bewaartermijn.afwijken`), en publiceer een classificatiemodel. Zonder model wordt niets vergrendeld.

## 0.19.0 — 2026-11-10

**Naam en versie van het metadatamodel** (oa-beheer 0.4.0, opendop-mini 0.10.0, oa-contract 0.7.0, oa-kern 0.7.0, oa-paneel 0.11.0, oa-adapters 0.18.0 met LibreOffice-extensie 0.15.0, oa-services 0.5.3, oa-integratielaag 0.9.8). De beheerder geeft het model een naam; een andere naam is een nieuwe versie. Het paneel toont naam en versie bovenaan Metadateren, en bij een stuk met een ouder model welke versie nu geldt. Het overzicht toont identificatie, versie, status en metadatamodel. In het bestand staan de documenteigenschappen Identificatie, Versie, Metadatamodel en Status, en de afdruk noemt de modelversie. Zie INRICHTING.md, stap 9, "Metadatamodel".

- Bijwerken in de volgorde VPS 3, VPS 2, VPS 1. Geen nieuwe migraties.
- Wie de LibreOffice-extensie zelf installeert: versie 0.15.0.

## 0.18.0 — 2026-11-09

**Kwaliteit van het anonimiseren in het beheerportaal** (oa-beheer 0.3.0, opendop-mini 0.9.0, oa-contract 0.6.0, oa-kern 0.6.0, oa-paneel 0.10.0, oa-adapters 0.17.0, oa-services 0.5.2, oa-integratielaag 0.9.7): een pagina Anonimiseren met de tab Kwaliteit. *Laat staan* in het paneel vraagt nu waarom. Bij bevestigen bewaart het platform een meting zonder waarden en zonder koppeling met het stuk: wat bevestigd, gelaten of toegevoegd werd, met vorm (`9-9`), lengte en signaalwoord. Het portaal toont precisie, gevonden (bovengrens voor de recall), zekerheid tegen terecht/onterecht, en de vormen die vaak gemist of onterecht gevonden worden, met een regexp om te kopiëren. Zie INRICHTING.md, stap 9, "Anonimiseren → Kwaliteit".

- Bijwerken in de volgorde VPS 3, VPS 2, VPS 1. Migratie 008 van het platform en migratie 003 van het portaal draaien vanzelf.
- Geef een groep het recht `anonimiseren.view`.

## 0.17.0 — 2026-11-09

**Metadatamodel in het beheerportaal** (oa-beheer 0.2.0, oa-contract 0.5.0, opendop-mini 0.8.0, oa-services 0.5.1, oa-integratielaag 0.9.6, oa-kern 0.5.1, oa-paneel 0.9.0, oa-adapters 0.16.1): informatiebeheer kiest een basismodel (MDTO, RGBZ of TMLO), zet velden aan of uit, maakt ze verplicht, past labels, hulpteksten en waardelijsten (ook uit TOOI) aan en voegt eigen velden toe. Publiceren maakt een nieuwe versie van het objecttype voor die gemeente; het paneel Metadateren volgt die meteen, en stukken die al zijn vastgelegd houden hun versie. Zie INRICHTING.md, stap 9, "Metadatamodel".

- VPS 1: het portaal praat met het platform (`PLATFORM_INTERN`, `PLATFORM_DIENSTSLEUTEL`, die er al staan) voor één gemeente: `BEHEER_GEMEENTE` (standaard haarlem).
- Geef een groep het recht `metadata.manage` (migratie 002 van het portaal draait vanzelf).

Lockfile bijgewerkt. Bijwerken: **VPS 3, VPS 2, dan VPS 1**. LibreOffice-extensie 0.14.1 opnieuw installeren.

## 0.16.3 — 2026-11-09

Lockfile voor oa-adapters 0.15.3: in LibreOffice is het paneel weer helemaal naar beneden te scrollen als er onderin een werkbalk staat (zoals de zoekbalk). Bijwerken: VPS 1 is genoeg; LibreOffice-extensie 0.13.3 opnieuw installeren. Wie 0.16.0 tot en met 0.16.2 nog niet had bijgewerkt: VPS 3, VPS 2, VPS 1.

## 0.16.2 — 2026-11-09

Alleen documentatie, bijwerken hoeft niet. README: "Begin hier" per rol (uitproberen, inrichten, ontwikkelen) en oa-wcag en OpenAnonymiser in het overzicht. INRICHTING.md bijgewerkt: wat er op VPS 3 draait en hoeveel geheugen dat vraagt, PPL 0 na het inloggen, het Word-manifest zonder vast versienummer, het webpaneel van LibreOffice ook op Windows en Mac (proef), niveaus toekennen via de tunnel (er is geen `auth.<domein>`), en oa-wcag bij dagelijks beheer.

## 0.16.1 — 2026-11-09

**Grondslag bij anonimiseren begrijpelijk en aan te passen** (oa-contract 0.4.2, opendop-mini 0.7.2, oa-integratielaag 0.9.5, oa-kern 0.4.3, oa-paneel 0.8.4, oa-adapters 0.15.2): bij elk persoonsgegeven staat de grondslag in gewone taal ("AVG art. 9 · bijzondere persoonsgegevens") met uitleg. Zolang het een voorvertoning is, kies je een andere; het gegeven gaat dan over naar de sleutel van die categorie en de plaatshouder krijgt de kleur van het nieuwe niveau. Elke wijziging is een gebeurtenis (`pii.categorie-gewijzigd`). Geen databasemigratie.

Lockfile bijgewerkt. Samen met 0.16.0 bijwerken: **VPS 3, VPS 2, VPS 1** (in die volgorde). LibreOffice: extensie 0.13.2 opnieuw installeren.

## 0.16.0 — 2026-11-09

**Toegankelijkheid van het bestand zelf:** [oa-wcag](https://github.com/digitaalgemeengoed/oa-wcag) 0.1.0 op VPS 3, naast de assistent-services en alleen voor hen bereikbaar (geen poort naar buiten). 34 controles voor docx, xlsx en pptx; de assistent dekt daarmee 20 WCAG-criteria in plaats van 5 (titel, taal, contrast, tekstafstand, leesvolgorde, alt-tekst van grafieken, tabellen …).

- `vps3-diensten.yml`: dienst `wcag` (Java, ongeveer 150 MB, grens 512 MB, alleen-lezen bestandssysteem). `haal-op.sh` haalt oa-wcag op.
- `WCAG_DIENSTSLEUTEL` in `.env` op VPS 3 mag leeg blijven: dan dezelfde als `DIENSTEN_DIENSTSLEUTEL`.
- TESTEN.md, stap 10: let op bevindingen *uit het bestand*.

Bijwerken: **VPS 3** (bouwt oa-wcag; de eerste keer duurt dat een paar minuten), daarna VPS 1.

## 0.15.3 — 2026-11-09

Lockfile voor oa-adapters 0.15.1: anonimiseren ook in opmerkingen (LibreOffice-extensie 0.13.1; opnieuw installeren). Bijwerken: VPS 1 is genoeg.

## 0.15.2 — 2026-11-09

Lockfile voor oa-contract 0.4.1, oa-kern 0.4.2, oa-services 0.5.0, oa-paneel 0.8.3 en oa-adapters 0.15.0 (voorbereiding op de toegankelijkheidscontrole van het bestand; die gaat aan zodra oa-wcag op VPS 3 staat). Bijwerken mag; er verandert nog niets zichtbaars, behalve de LibreOffice-extensie 0.13.0 op de downloadpagina.

## 0.15.1 — 2026-11-09

**Inloggen en verlopen sessies netjes afgevangen** (oa-integratielaag 0.9.4, oa-paneel 0.8.2, oa-adapters 0.14.1): geen kale foutmelding meer na te lang wachten op het inlogscherm, een knop *Opnieuw inloggen* als de sessie verloopt, en een melding in plaats van een leeg paneel als de server weg is. Zie TESTEN.md, stap 11 (toen 10).

Lockfile bijgewerkt. Bijwerken: VPS 1 is genoeg. Geen nieuwe extensie of manifest nodig.

## 0.15.0 — 2026-11-09

- **LibreOffice op Windows en Mac:** het webpaneel in de zijbalk als proef (oa-adapters 0.14.0, extensie 0.12.0). Extensie opnieuw installeren.
- **TESTEN.md:** dezelfde testronde voor elke werkomgeving, en wat testers meesturen (met het logboek van de extensie). De downloadpagina verwijst ernaar en is bijgewerkt.

Lockfile voor oa-adapters 0.14.0. Bijwerken: VPS 1 is genoeg.

## 0.14.1 — 2026-11-09

Downloadpagina (office.<domein>): het versienummer bij het manifest en de extensie (ook op de knop), een tabel met de versies op de servers, en de tekst over anonimiseren bijgewerkt. De pagina haalt dat op bij oa.<domein>/versies.json; de Content-Security-Policy staat het script (op hash) en die ene verbinding toe. Lockfile voor oa-integratielaag 0.9.3.

## 0.14.0 — 2026-11-09

**Anonimiseren in het document in alle werkomgevingen**: Word, Excel, PowerPoint, LibreOffice Calc en Impress, en Collabora (zie de CHANGELOG van oa-adapters 0.13.0 voor wat per omgeving kan).

Lockfile voor oa-kern 0.4.1, oa-paneel 0.8.1, oa-adapters 0.13.0 en oa-integratielaag 0.9.2. Bijwerken (VPS 1 is genoeg). Daarna:
- het **Office-manifest (0.6.0.0)** opnieuw uploaden in Word, Excel en PowerPoint;
- de **LibreOffice-extensie (0.11.0)** opnieuw installeren.

## 0.13.0 — 2026-11-09

LibreOffice Writer anonimiseert nu in het document zelf, zoals de demo-werkomgeving: lockfile voor oa-adapters 0.12.0. Bijwerken (VPS 1 is genoeg; de volgorde 3, 2, 1 mag ook) en daarna de **LibreOffice-extensie 0.10.0** opnieuw installeren.

## 0.12.1 — 2026-11-09

Lockfile voor opendop-mini 0.7.1, oa-services 0.4.3 en oa-integratielaag 0.9.1: de overzichtspagina toont welke versies er draaien en welke versie van het Office-manifest en de LibreOffice-extensie hoort bij deze omgeving. Bijwerken in de volgorde VPS 3, 2, 1.

## 0.12.0 — 2026-11-09

**Anonimiseren in het document** (fase A): in de demo-werkomgeving gebeurt het anonimiseren nu in het document zelf, zoals in de MIRA-demo, met kaarten in het paneel, versies die je kunt herkennen en terugzetten, en het versienummer als documenteigenschap. Word en LibreOffice volgen (fase B).

Lockfile voor oa-contract 0.4.0, opendop-mini 0.7.0 (migratie 007, draait vanzelf), oa-services 0.4.2, oa-kern 0.4.0, oa-paneel 0.8.0, oa-adapters 0.11.0 en oa-integratielaag 0.9.0. Bijwerken in de volgorde VPS 3, 2, 1. Extensie en manifest hoeven niet opnieuw.

## 0.11.0 — 2026-11-09

**Anonimiseren bij de bron.** Persoonsgegevens worden na bevestiging versleuteld in een register (in PostgreSQL, bij de metadata), met een sleutel per document per AVG-categorie, en in het document vervangen door plaatshouders.

- Keycloak: rollen `ppl-1`, `ppl-2` en `ppl-3` (wie welk niveau persoonsgegevens mag inzien). `keycloak-beheer.sh` maakt ze aan (op VPS 3), geeft medewerkers zonder niveau `ppl-1`, en vraagt bij een eigen gebruiker om het niveau. Daarna opnieuw inloggen.
- Lockfile voor oa-contract 0.3.3, opendop-mini 0.6.0 (migratie 006, draait vanzelf), oa-services 0.4.1, oa-kern 0.3.4, oa-paneel 0.7.0, oa-adapters 0.10.0 en oa-integratielaag 0.8.0. Bijwerken in de volgorde VPS 3, 2, 1.
- LibreOffice-extensie 0.9.0 opnieuw installeren (vervangen en selectie lezen). Het Office-manifest hoeft niet opnieuw.

## 0.10.0 — 2026-11-09

**Anonimiseren.** VPS 3 krijgt OpenAnonymiser (Conduction, EUPL-1.2): herkenning van persoonsgegevens met Presidio en het Nederlandse taalmodel van spaCy. We bouwen het zelf uit de broncode, op een vaste versie (`haal-op.sh`), zonder poort naar buiten; alleen de assistent-services gebruiken het. Ongeveer 1 GB geheugen.

Lockfile voor oa-contract 0.3.2, opendop-mini 0.5.0 (migratie 005, draait vanzelf), oa-services 0.4.0, oa-kern 0.3.3, oa-paneel 0.6.0, oa-adapters 0.9.1 en oa-integratielaag 0.7.1. Bijwerken in de volgorde VPS 3, 2, 1. Het Office-manifest (0.5.1.0) en de LibreOffice-extensie (0.8.1) hoeven niet opnieuw, maar het mag.

## 0.9.0 — 2026-11-09

Lockfile voor oa-contract 0.3.1, opendop-mini 0.4.0, oa-kern 0.3.2, oa-paneel 0.5.0, oa-adapters 0.9.0 en oa-integratielaag 0.7.0:

- Het paneel heeft de modules van de demo, met knoppen in de werkbalk van elke werkomgeving (LibreOffice: werkbalk Assistent; Office: tabblad Assistent; Collabora: in de eigen werkbalk).
- Zakelijk of persoonlijk. Het platform maakt per gemeente een tweede bucket (`…-persoonlijk`, zonder Object Lock); de migratie (004) draait vanzelf bij het bijwerken van VPS 2.
- Bijwerken in de volgorde VPS 3, VPS 2, VPS 1. Daarna: het Office-manifest opnieuw uploaden en de LibreOffice-extensie (0.8.0) opnieuw installeren.

Overzichtspagina en INRICHTING bijgewerkt.

## 0.8.0 — 2026-11-08

Lockfile voor oa-adapters 0.8.0 en oa-integratielaag 0.6.0: de invoegtoepassing werkt ook in Excel en PowerPoint (één manifest; gebouwd, nog niet getest in een echte Excel of PowerPoint). De overzichtspagina op office.<domein> en INRICHTING zeggen wat werkt: Collabora en LibreOffice nu ook met rekenblad en presentatie. Wie het manifest al had geüpload, uploadt het nieuwe opnieuw.

## 0.7.0 — 2026-11-08

Ook: integratielaag 0.5.0 (Collabora met rekenblad en presentatie; nieuwe afhankelijkheid `@xmldom/xmldom`).


Lockfile voor oa-services 0.3.0, oa-kern 0.3.1, oa-paneel 0.4.1 en oa-adapters 0.7.0: rekenbladen en presentaties, en het zijpaneel in LibreOffice Calc en Impress. Bijwerken in de volgorde VPS 3 (services), VPS 2, VPS 1.

## 0.6.0 — 2026-11-08

- LibreOffice: het webpaneel van de server in de zijbalk (oa-adapters 0.6.0). `INRICHTING.md` stap 8 en de voorpagina van `office.<domein>` beschrijven installeren (op Linux `python3-gi` en `gir1.2-webkit2-4.1`) en kiezen tussen webpaneel en eigen paneel.
- Lockfile voor oa-adapters 0.6.0.

## 0.5.2 — 2026-11-08

- Voorpagina op `office.<domein>`: overzicht van de werkomgevingen, met de downloads (Word-manifest, LibreOffice-extensie) en wat waar werkt. Collabora blijft op dezelfde naam; alleen `/` is de voorpagina.
- Caddy krijgt de hele map `caddy/` in plaats van alleen de Caddyfile, en `bijwerken.sh` herlaadt Caddy. Eerder bleef een gewijzigde Caddyfile (zoals het blok voor `oa-admin`) ongebruikt tot een herstart.

## 0.5.1 — 2026-11-08

- `bijwerken.sh` start zichzelf opnieuw na het ophalen, zodat nieuwe instellingen in `.env` er meteen bij komen. Voorheen draaide de oude `lib.sh` nog en ontbraken de geheimen van het beheerportaal.
- De LibreOffice-extensie heeft een eigen zijpaneel in Writer (oa-adapters 0.5.0); `INRICHTING.md` stap 8 beschrijft installeren en aanmelden.
- Lockfile bijgewerkt voor oa-adapters 0.5.0.

## 0.5.0 — 2026-11-08

- Het beheerportaal (`oa-beheer`) op VPS 1: `oa-admin.<domein>` in Caddy, services `beheer-db` (niet gepubliceerd), `beheer-migreer` en `beheer` (alleen-lezen, zonder rechten). `haal-op.sh` haalt `oa-beheer` op.
- `installeer.sh` en `bijwerken.sh` vullen `.env` aan met nieuwe geheimen voor het portaal; DNS-controle voor `oa-admin.<domein>`.
- `server/beheer.sh` (VPS 1): noodaccount, Keycloak-client-geheim, SMTP, status en logboek.
- `server/keycloak-beheer.sh` (VPS 3): client `oa-beheer`, AMR-mapper, referentie `otp` op de OTP-stap, brute-force-detectie, en op verzoek een eigen Keycloak-gebruiker.
- `INRICHTING.md` stap 9: het beheerportaal.

## 0.4.2 — 2026-11-08

- `haal-op.sh` probeert tot drie keer bij een netwerkhapering; `bijwerken.sh` en `installeer.sh` stoppen als ophalen mislukt.
- Lokaal gebouwde images (`oa/platform`) worden niet meer van een registry gehaald (`pull_policy: never`).

## 0.4.1 — 2026-11-08

Lockfile bijgewerkt voor contract 0.3.0 en de nieuwe versies. Bijwerken in de volgorde VPS 2 (migratie 003), VPS 3, VPS 1.

## 0.4.0 — 2026-11-08

- Collabora Online op VPS 1 (profiel `collabora`, adres `office.<domein>`), met volume voor werkbestanden.
- `installeer.sh` en `bijwerken.sh` vullen een bestaande `.env` aan met nieuwe instellingen; DNS-controle voor `office.<domein>`.
- `INRICHTING.md`: de assistent in Word, Collabora en LibreOffice.
- Caddy zet geen `X-Frame-Options` meer; de integratielaag regelt het inbedden zelf.

## 0.3.0 — 2026-11-07

- `server/`: scripts om drie VPS'en in te richten en te beveiligen (`inrichten.sh`, `ssh-afsluiten.sh`, `koppelen.sh`, `installeer.sh`, `controleer.sh`, `ontzegel.sh`, `bijwerken.sh`) en het stappenplan `INRICHTING.md`.
- Verkeer tussen de VPS'en via WireGuard (10.66.0.0/24); een filter op `DOCKER-USER` laat per containerpoort alleen de VPS toe die hem nodig heeft.
- OpenBao: `server` zonder extra `-config` (de map werd anders dubbel geladen), opslag in `/openbao/file`, mlock uit bij raft.
- Keycloak: het beheerscherm via een SSH-tunnel (`KC_HOSTNAME_ADMIN`); testgebruikers krijgen een willekeurig tijdelijk wachtwoord (`OA_TESTWACHTWOORD`); testbeheerder `beheer.haarlem`.
- `openbao/init.sh`: met `OA_ROOT_INTREKKEN=1` wordt het root-token meteen ingetrokken.

## 0.2.0 — 2026-11-07

OpenSearch (profiel `zoeken`, VPS 2) en OpenBao (profiel `sleutels`, VPS 3) als optionele onderdelen, met `openbao/init.sh` en een beleid voor het platform. De worker krijgt dezelfde instellingen als het platform.

## 0.1.1 — 2026-11-07

S3-opslag in de uitrol is SILO, de open-source voortzetting van MinIO (OA-ADR-006).

## 0.1.0 — 2026-11-07

Fase 1 van het werkende prototype: contract, minimaal platform, integratielaag met twee ingangen, assistentkern, paneel en een demo-werkomgeving met de modules metadateren en toegankelijkheid.
