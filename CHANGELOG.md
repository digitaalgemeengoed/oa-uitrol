# Wijzigingen

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
