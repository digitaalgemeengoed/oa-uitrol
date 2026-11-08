# Wijzigingen

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
