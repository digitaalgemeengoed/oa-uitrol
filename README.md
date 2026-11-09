# oa-uitrol

**Uitrol** van het werkende prototype van de Office Assistent: één machine voor ontwikkeling, of drie VPS'en verdeeld naar vertrouwensgrens.

> Een prototype, geen product. Alleen testgegevens.

## Begin hier

| Je wilt … | Lees |
|---|---|
| de assistent **uitproberen** op een omgeving die al draait | [TESTEN.md](TESTEN.md) en de downloadpagina van die omgeving (`https://office.<domein>`) |
| een eigen omgeving **inrichten** op drie VPS'en | [server/INRICHTING.md](server/INRICHTING.md): stap voor stap, ook voor wie geen systeembeheerder is |
| **ontwikkelen** op je eigen computer | [Op één machine](#op-één-machine) hieronder, en de README van de repository waar je aan werkt |
| weten **wat er veranderd is** | [CHANGELOG.md](CHANGELOG.md) |

## De repositories

| Repository | Wat |
|---|---|
| `oa-contract` | Het contract: inhoud, vermogens, bevindingen, gebeurtenissen, de twee ingangen |
| `oa-kern` | De assistentkern met de modules, zonder framework |
| `oa-paneel` | Het paneel in React met NL Design System |
| `oa-adapters` | Adapters per werkomgeving en de demo-werkomgeving |
| `oa-integratielaag` | Next.js: identiteit, twee ingangen, de browser praat alleen hiermee |
| `oa-beheer` | Beheerportaal: accounts, groepen, audit en instellingen (`oa-admin.<domein>`) |
| `oa-services` | Assistent-services achter de lezende ingang |
| `opendop-mini` | Minimaal platform: Object Service op PostgreSQL en S3 |
| `oa-wcag` | Toegankelijkheidscontrole van docx, xlsx en pptx (Java), achter de assistent-services |
| `oa-uitrol` | Deze repository |

Daarnaast haalt `haal-op.sh` [OpenAnonymiser](https://github.com/ConductionNL/anonymiq-light) van Conduction op, op een vaste versie: het herkent persoonsgegevens voor de module Anonimiseren.

`haal-op.sh` haalt ze naast elkaar op in `./bron` en zet daar een npm-workspace neer die ze lokaal koppelt. Zolang de pakketten `@digitaalgemeengoed/oa-*` niet in een registry staan, bouwt de `Dockerfile` alles uit die map.

## Op één machine

```
./haal-op.sh digitaalgemeengoed
docker compose -f lokaal.yml up --build
```

Open `http://localhost:3000` en kies een testgebruiker. Zonder Keycloak (`OA_AUTH=dev`).

## Op drie VPS'en

| VPS | Bestand | Draait | Bereikbaar voor |
|---|---|---|---|
| 1 — toegang | `vps1-toegang.yml` | Caddy (TLS), integratielaag met paneel, demo en de pagina's voor Word, Collabora en LibreOffice; Collabora Online (profiel `collabora`); het beheerportaal met eigen database | Internet: `oa.<domein>`, `id.<domein>`, `office.<domein>`, `oa-admin.<domein>` |
| 2 — platform | `vps2-platform.yml` | opendop-mini, PostgreSQL, SILO (S3 met Object Lock), worker; optioneel OpenSearch | Alleen de integratielaag |
| 3 — diensten | `vps3-diensten.yml` | Assistent-services, OpenAnonymiser, oa-wcag, Keycloak met eigen PostgreSQL; optioneel OpenBao | Integratielaag; Keycloak via de proxy op VPS 1 |

Nextcloud volgt in fase 2. Hoe je de assistent in Word, Collabora en LibreOffice gebruikt, staat in stap 8 van `server/INRICHTING.md`.

**Inrichten: volg [`server/INRICHTING.md`](server/INRICHTING.md).** Dat is een stappenplan voor wie geen systeembeheerder is. De scripts in `server/` doen het werk:

| Script | Wat het doet |
|---|---|
| `inrichten.sh` | Basis en hardening: updates, gebruiker `beheer`, firewall, fail2ban, kernelinstellingen, dagelijkse beveiligingsupdates, Docker met een filter op containerpoorten, WireGuard-sleutel |
| `ssh-afsluiten.sh` | Alleen inloggen met een sleutel, geen root. Controleert eerst of je sleutel werkt. |
| `koppelen.sh` | WireGuard tussen de drie VPS'en (10.66.0.1–3) en het verdelen van de gedeelde sleutels; elke VPS krijgt alleen de sleutels die hij nodig heeft |
| `installeer.sh` | Schrijft `.env` met willekeurige wachtwoorden, bouwt en start; richt OpenBao in |
| `controleer.sh`, `ontzegel.sh`, `bijwerken.sh` | Dagelijks beheer |

Het verkeer tussen de VPS'en loopt via WireGuard: versleuteld en onafhankelijk van de provider. De interne poorten luisteren alleen op het WireGuard-adres, en `docker-filter.sh` laat per poort alleen de VPS toe die hem nodig heeft (Docker gaat anders langs ufw heen).

De testgebruikers in Keycloak krijgen bij elke installatie een willekeurig, tijdelijk eerste wachtwoord.

### Inloggen: Keycloak

Keycloak 26 draait op VPS 3 (realm `gemeenten`, uit `keycloak/realm-gemeenten.json`) en is van buiten alleen bereikbaar als `id.<domein>`, via de proxy op VPS 1. Het beheer gaat via een SSH-tunnel (zie INRICHTING.md, stap 10).

- De integratielaag is de client `oa-integratielaag`: authorization code flow met PKCE, als vertrouwelijke client. Tokens blijven op de server; de browser krijgt een httpOnly-sessiecookie. Platform en diensten krijgen de identiteit van de integratielaag, met een dienstsleutel.
- Het beheerportaal is de client `oa-beheer` en eist een tweede factor (`server/keycloak-beheer.sh` richt dat in).
- Per medewerker: het attribuut `gemeente` (bijvoorbeeld `haarlem`; die gemeente moet ook in `GEMEENTEN` op VPS 2 staan), de rol `medewerker` (of `beheerder`) en een niveau voor persoonsgegevens `ppl-1`, `ppl-2` of `ppl-3`.
- `keycloak-beheer.sh` zet de blokkade na tien foute wachtwoorden aan en laat nieuwe eigen gebruikers bij de eerste inlog een authenticator-app koppelen.

## Wat is getest

| Onderdeel | Getest |
|---|---|
| Contract, kern, toegankelijkheidsdienst | Eenheidstests |
| Platform | Integratietests tegen PostgreSQL 16: scheiding per gemeente, onveranderlijke gebeurtenissen, 409 bij een verouderde stand, versies, objecttypen, outbox; versleuteling per object, onleesbaar maken, zoeken met bevestiging in het register |
| OpenBao en OpenSearch | Tegen nabootsingen van de transit-API en van de zoek-API (met de echte OpenSearch-client), omdat beide hier niet te installeren waren |
| Geheel | Eind-tot-eind in Chromium met `OA_AUTH=dev` en lokale opslag: registreren, metadata, beoordelen en herstellen in de rijke en de beperkte werkomgeving, herkennen na heropenen, Zandvoort ziet Haarlem niet; versleuteld registreren, zoeken, openen in een sandbox, onleesbaar maken (medewerker geweigerd, beheerder toegestaan) |
| Compose-bestanden | Geldig volgens `docker compose config` |

Sinds november 2026 draait het op drie echte VPS'en (Haarlem): de serverscripts, de containers, Keycloak met tweestapsverificatie en OpenBao zijn daar in gebruik. De werkomgevingen worden getest volgens [TESTEN.md](TESTEN.md).

**Nog niet getest:** SILO met Object Lock (alleen in de broncode nagegaan), OpenSearch op een echte server, Excel en PowerPoint in een echte Office, en het webpaneel van LibreOffice op Windows en Mac.

## Zoeken en sleutelbeheer (optioneel)

Beide staan standaard uit; zet ze per VPS aan in `.env`.

| Wat | Waar | Aanzetten |
|---|---|---|
| Zoekindex: OpenSearch, één index per gemeente (OA-ADR-007) | VPS 2, alleen binnen het compose-netwerk | `COMPOSE_PROFILES=zoeken` en `ZOEKINDEX=opensearch` |
| Sleutelbeheer: OpenBao, één sleutel per object (OA-ADR-008) | VPS 3, op het private adres; bewust niet naast de gegevens | `COMPOSE_PROFILES=sleutels`, dan `openbao/init.sh`; op VPS 2 `SLEUTELBEHEER=openbao` en het token uit het script |

Aandachtspunten:

- **OpenSearch** vraagt ruim 1 GB geheugen extra (`OPENSEARCH_GEHEUGEN`). De index bevat leesbare tekst, ook van versleutelde stukken: bescherm het volume en eventuele snapshots even goed als de opslag.
- **OpenBao** moet na elke herstart worden ontzegeld (`docker compose -f vps3-diensten.yml exec sleutelbeheer bao operator unseal <sleutel>`). Het init-script gebruikt één ontzegelsleutel; voor productie 3 van 5 en auto-unseal met een HSM of KMS. Het platform krijgt alleen het beleid `openbao/beleid-oa-platform.hcl`.
- **Snapshots van OpenBao** bevatten vernietigde sleutels nog. Begrens hun bewaartermijn, anders is onleesbaar maken niet definitief.
- **Sleutelbeheer achteraf uitzetten** kan niet zonder verlies: versleutelde stukken zijn dan niet meer te lezen.

Lokaal staat versleuteling aan met sleutels op een volume; OpenBao en OpenSearch komen erbij met `--profile volledig` (zie de kop van `lokaal.yml`).

## S3-opslag: SILO

De opslag is [SILO](https://github.com/pgsty/silo), de open-source voortzetting van MinIO onder AGPLv3 (OA-ADR-006). MinIO publiceert sinds oktober 2025 geen community-images meer; AIStor is gesloten en mag niet worden meegeleverd. SILO houdt de S3-API, de `MINIO_*`-variabelen en het schijfformaat gelijk, en ondersteunt Object Lock, retention en legal hold.

De versie staat vast via `SILO_VERSIE` (standaard `RELEASE.2026-10-26T00-00-00Z`). Werk bij na het lezen van de release notes. Terug naar een MinIO-image is volgens SILO niet veilig. Het platform gebruikt alleen de S3-API, dus een andere S3-opslag met Object Lock (AIStor Enterprise, Ceph) blijft mogelijk.

## Open punten

- **Pakketten publiceren.** `@digitaalgemeengoed/oa-contract`, `@digitaalgemeengoed/oa-kern` en `@digitaalgemeengoed/oa-paneel` publiceren in GitHub Packages (de `publishConfig` staat klaar). Dan kan elke repository los bouwen.
- **Sessies** van de integratielaag in Redis of PostgreSQL bij meer dan één instantie.
- **mTLS** tussen integratielaag, platform en diensten in plaats van gedeelde sleutels.

## Licentie

© 2026 Gemeente Haarlem. EUPL 1.2, zie `LICENSE`.

Gemaakt door Erik Hoekstra, programma-architect en senior consultant, afdeling i-Ontwikkeling, Gemeente Haarlem, met assistentie van Claude (Anthropic).
