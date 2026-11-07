# oa-uitrol

**Uitrol** van het werkende prototype van de Office Assistent: één machine voor ontwikkeling, of drie VPS'en verdeeld naar vertrouwensgrens.

> Een prototype, geen product. Alleen testgegevens.

## De repositories

| Repository | Wat |
|---|---|
| `oa-contract` | Het contract: inhoud, vermogens, bevindingen, gebeurtenissen, de twee ingangen |
| `oa-kern` | De assistentkern met de modules, zonder framework |
| `oa-paneel` | Het paneel in React met NL Design System |
| `oa-adapters` | Adapters per werkomgeving en de demo-werkomgeving |
| `oa-integratielaag` | Next.js: identiteit, twee ingangen, de browser praat alleen hiermee |
| `oa-services` | Assistent-services achter de lezende ingang |
| `opendop-mini` | Minimaal platform: Object Service op PostgreSQL en S3 |
| `oa-uitrol` | Deze repository |

`haal-op.sh` haalt ze naast elkaar op in `./bron` en zet daar een npm-workspace neer die ze lokaal koppelt. Zolang de pakketten `@oa/*` niet in een registry staan, bouwt de `Dockerfile` alles uit die map.

## Op één machine

```
./haal-op.sh <github-account>
docker compose -f lokaal.yml up --build
```

Open `http://localhost:3000` en kies een testgebruiker. Zonder Keycloak (`OA_AUTH=dev`).

## Op drie VPS'en

| VPS | Bestand | Draait | Bereikbaar voor |
|---|---|---|---|
| 1 — toegang | `vps1-toegang.yml` | Caddy (TLS), integratielaag met paneel en demo | Internet: `oa.<domein>`, `id.<domein>` |
| 2 — platform | `vps2-platform.yml` | opendop-mini, PostgreSQL, S3-opslag met Object Lock, worker | Alleen de integratielaag |
| 3 — diensten | `vps3-diensten.yml` | Assistent-services, Keycloak met eigen PostgreSQL | Integratielaag; Keycloak via de proxy op VPS 1 |

Een vierde VPS met Nextcloud en Collabora volgt in fase 2.

1. Zorg voor een privaat netwerk tussen de VPS'en (netwerk van de provider of WireGuard). Verkeer tussen de VPS'en loopt alleen daarover.
2. Zet op elke VPS `./haal-op.sh <github-account>` en een `.env` op basis van `voorbeeld.env`. De gedeelde sleutels zijn op de betrokken VPS'en gelijk.
3. Start in de volgorde VPS 2, VPS 3, VPS 1: `docker compose -f <bestand> --env-file .env up -d --build`.
4. Wijzig in Keycloak direct de tijdelijke wachtwoorden van de testgebruikers, of verwijder ze uit `keycloak/realm-gemeenten.json` vóór de eerste start.

Nieuwe medewerkers krijgen in Keycloak het attribuut `gemeente` (bijvoorbeeld `haarlem`) en de rol `medewerker`. De gemeente moet ook in `GEMEENTEN` op VPS 2 staan.

## Wat in fase 1 is getest

| Onderdeel | Getest |
|---|---|
| Contract, kern, toegankelijkheidsdienst | Eenheidstests |
| Platform | Integratietest tegen PostgreSQL 16: scheiding per gemeente, onveranderlijke gebeurtenissen, 409 bij een verouderde stand, versies, objecttypen, outbox |
| Geheel | Eind-tot-eind in Chromium met `OA_AUTH=dev` en lokale opslag: registreren, metadata, beoordelen en herstellen in de rijke en de beperkte werkomgeving, herkennen na heropenen, Zandvoort ziet Haarlem niet |
| Compose-bestanden | Geldig volgens `docker compose config` |

**Nog niet getest:** de containers zelf, de S3-opslag met Object Lock, en het inloggen via Keycloak (inclusief de realm-import). Die test volgt op de eerste VPS.

## Open punten

- **S3-opslag.** MinIO publiceert sinds oktober 2025 geen community-images meer en de community-repository is in april 2026 gearchiveerd. Het prototype gebruikt het gratis image van Chainguard (`cgr.dev/chainguard/minio`). Het platform gebruikt alleen de S3-API; een opvolger moet Object Lock ondersteunen.
- **Pakketten publiceren.** Zodra het GitHub-account er is: de scope `@oa` vervangen door de naam van het account en `@oa/contract`, `@oa/kern` en `@oa/paneel` publiceren in GitHub Packages. Dan kan elke repository los bouwen.
- **Sessies** van de integratielaag in Redis of PostgreSQL bij meer dan één instantie.
- **mTLS** tussen integratielaag, platform en diensten in plaats van gedeelde sleutels.

## Licentie

© 2026 Gemeente Haarlem. EUPL 1.2, zie `LICENSE`.

Gemaakt door Erik Hoekstra, programma-architect en senior consultant, afdeling i-Ontwikkeling, Gemeente Haarlem, met assistentie van Claude (Anthropic).
