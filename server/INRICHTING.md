# De drie VPS'en inrichten, stap voor stap

Dit stappenplan is voor wie geen systeembeheerder is. Je typt of plakt
steeds een paar opdrachten; de scripts doen de rest en zeggen wat de
volgende stap is. Reken op twee tot drie uur, waarvan veel wachten.

> **Niet wat je zoekt?** Wil je de assistent alleen *uitproberen* op een
> omgeving die al draait: zie [TESTEN.md](../TESTEN.md) en de downloadpagina
> van die omgeving (`https://office.<domein>`). Wil je *ontwikkelen* op je
> eigen computer: zie "Op één machine" in de [README](../README.md).

| VPS | Rol | Wat erop komt |
|---|---|---|
| VPS 1 | toegang | Caddy (HTTPS), de integratielaag, Collabora Online, de downloadpagina en het beheerportaal. De enige die van buiten bereikbaar is. |
| VPS 2 | platform | PostgreSQL, SILO (opslag), OpenSearch, platform en worker |
| VPS 3 | diensten | assistent-services, OpenAnonymiser (persoonsgegevens herkennen), oa-wcag (toegankelijkheid van het bestand), Keycloak (inloggen), OpenBao (sleutels) |

De VPS'en praten met elkaar over een eigen, versleuteld netwerk
(WireGuard, adressen 10.66.0.1, .2 en .3). Heb je bij de provider een
privénetwerk (bij Contabo: Private Network, 10.0.20.0/22), dan loopt
WireGuard daaroverheen en gaat de WireGuard-poort niet open op internet.
Zonder privénetwerk loopt het via de publieke adressen; ook dat is
versleuteld.

Waarom niet alleen het privénetwerk? Dat is afgeschermd, maar niet
versleuteld. Tussen VPS 2 en VPS 3 gaan ontsleutelde datasleutels, en
tussen VPS 1 en VPS 2 documenten. WireGuard versleutelt dat en laat alleen
de drie eigen servers toe.

## 0. Wat je klaar moet hebben

- De **IP-adressen en root-wachtwoorden** van de drie VPS'en (uit de mail van de provider).
- Een **domein** waarvan je de DNS kunt beheren, bijvoorbeeld `prototype.digitaalgemeengoed.nl`. De Office Assistent komt op `oa.<domein>`, het inloggen op `id.<domein>`.
- Een **wachtwoordmanager** (Bitwarden, 1Password, KeePass). Je krijgt onderweg een paar dingen die je echt niet kwijt mag raken.
- **Kladblok** open, om koppelregels tussendoor te bewaren.
- Op Windows: **Terminal** of **PowerShell** (zit in Windows 10 en 11). Op een Mac: Terminal.

**Geheugen:** VPS 3 heeft het meeste nodig. OpenAnonymiser gebruikt ongeveer 1 GB (grens 2 GB), oa-wcag tot 512 MB, en daarnaast draaien Keycloak met zijn database en de assistent-services. Neem voor VPS 3 dus niet de kleinste VPS. `inrichten.sh` zet op elke VPS 2 GB wisselgeheugen als reserve.

Kies bij de provider als besturingssysteem **Ubuntu 24.04**. Heb je iets anders gekozen, installeer dan opnieuw; dat kan in het klantenpaneel.

## 1. Een SSH-sleutel maken (op je eigen computer, één keer)

Met een SSH-sleutel log je in zonder wachtwoord. Wachtwoorden zetten we straks uit, want die worden de hele dag door robots geprobeerd.

Open PowerShell en typ:

```
ssh-keygen -t ed25519 -C "erik-oa"
```

Druk op Enter bij de vraag waar hij moet komen. Kies daarna een **wachtwoordzin** en bewaar die in je wachtwoordmanager. Laat dan de **publieke** sleutel zien:

```
type $env:USERPROFILE\.ssh\id_ed25519.pub
```

(Op een Mac: `cat ~/.ssh/id_ed25519.pub`.) Dat is één regel die begint met `ssh-ed25519`. Die mag iedereen zien. Het bestand **zonder** `.pub` is geheim: dat geef je nooit aan iemand.

## 2. DNS instellen (nu meteen, dan heeft het tijd)

Maak bij je DNS-beheerder twee **A-records** die naar het IP-adres van **VPS 1** wijzen:

| Naam | Type | Waarde |
|---|---|---|
| `oa.<domein>` | A | IP van VPS 1 |
| `id.<domein>` | A | IP van VPS 1 |

Allebei naar VPS 1, ook `id`: VPS 1 stuurt het verkeer voor het inloggen door naar Keycloak op VPS 3.

Later komen er nog twee bij, ook naar VPS 1: `office.<domein>` voor Collabora Online (stap 8) en `oa-admin.<domein>` voor het beheerportaal (stap 9). Maak ze gerust nu al.

## 3. Elke VPS inrichten

Doe dit voor **alle drie** de VPS'en. De volgorde maakt niet uit.

Log in als root met het wachtwoord uit de mail:

```
ssh root@<IP van de VPS>
```

De eerste keer vraagt SSH of je de server vertrouwt: typ `yes`. Je ziet niets terwijl je het wachtwoord typt; dat hoort zo. Plakken doe je in de terminal met de rechtermuisknop.

Plak dan deze drie regels:

```
apt-get update && apt-get install -y git
git clone https://github.com/digitaalgemeengoed/oa-uitrol /opt/oa-uitrol
/opt/oa-uitrol/server/inrichten.sh
```

Het script vraagt:

1. **Welke VPS dit is** (1, 2 of 3).
2. **Je publieke SSH-sleutel**, als je die niet al bij de bestelling hebt opgegeven. Plak de regel uit stap 1.
3. **Een wachtwoord voor de gebruiker `beheer`.** Dat heb je nodig als je `sudo` typt, niet bij het inloggen. Bewaar het in je wachtwoordmanager.

Daarna werkt het een paar minuten zelf door. Het laat aan het eind een **koppelregel** zien, zoals

```
OA-KOPPEL platform 185.12.34.56 jNTKwvE39vZWjY1IC5bTSU+GkWVfb8Ys3OXA42JrzLU=
```

Kopieer die regel naar Kladblok. Je hebt de koppelregels van VPS 2 en VPS 3 straks nodig.

**Wat het script heeft gedaan:** alles bijgewerkt; de gebruiker `beheer` aangemaakt; een firewall aangezet (alleen SSH open, op VPS 1 ook HTTP en HTTPS); fail2ban, dat adressen blokkeert die te vaak fout inloggen; strengere netwerkinstellingen; elke dag automatisch beveiligingsupdates; Docker geïnstalleerd met een filter dat de interne poorten afschermt; een WireGuard-sleutel gemaakt.

## 4. SSH dichtzetten

Sluit het root-venster nog **niet**. Open een **nieuw** venster en log in als `beheer`:

```
ssh beheer@<IP van de VPS>
```

Lukt dat zonder om het wachtwoord van de server te vragen (wel om de wachtwoordzin van je sleutel), dan werkt je sleutel. Typ dan:

```
sudo /opt/oa-uitrol/server/ssh-afsluiten.sh
```

Het script controleert eerst of je echt met je sleutel bent ingelogd. Daarna zet het inloggen als root en inloggen met een wachtwoord uit. Test in nog een venster dat `ssh beheer@…` werkt en `ssh root@…` geweigerd wordt. Daarna mag je de andere vensters sluiten.

Zegt een script dat een **herstart** nodig is, typ dan `sudo reboot` en log na een minuut opnieuw in als `beheer`.

Doe dit voor alle drie.

> **Tip:** zet dit in het bestand `C:\Users\<jij>\.ssh\config` (maak het aan met Kladblok, zonder extensie). Daarna is `ssh oa1` genoeg.
> ```
> Host oa1
>   HostName <IP van VPS 1>
>   User beheer
> Host oa2
>   HostName <IP van VPS 2>
>   User beheer
> Host oa3
>   HostName <IP van VPS 3>
>   User beheer
> ```

## 5. De VPS'en koppelen

**Eerst op VPS 1:**

```
sudo /opt/oa-uitrol/server/koppelen.sh
```

Plak de koppelregels van VPS 2 en VPS 3 en geef het domein op. Je krijgt twee **koppelblokken**, elk één lange regel die begint met `OA-BLOK-platform:` of `OA-BLOK-diensten:`. Kopieer ze naar Kladblok.

**Dan op VPS 2 en op VPS 3:**

```
sudo /opt/oa-uitrol/server/koppelen.sh
```

Plak het blok voor die VPS. Een blok op de verkeerde VPS plakken is niet erg: het script herkent dat en vraagt om het goede.

Na de laatste VPS moeten alle drie elkaar zien. Controleer dat op elke VPS met `sudo /opt/oa-uitrol/server/controleer.sh`, onder "Privénetwerk". De koppelblokken bevatten sleutels: **wis ze daarna uit Kladblok**.

## 6. De Office Assistent installeren

Altijd in deze volgorde: **VPS 3, dan VPS 2, dan VPS 1.** Op elke VPS:

```
sudo /opt/oa-uitrol/server/installeer.sh
```

De eerste keer duurt dat 5 tot 15 minuten per VPS, omdat alles wordt gebouwd.

**VPS 3** laat aan het eind een kader zien met de **OpenBao-ontzegelsleutel**. Zet die **meteen** in je wachtwoordmanager. Zonder die sleutel kan na een herstart niemand meer bij de versleutelde documenten, en hij staat niet op de server. Het script wacht tot je zegt dat je hem hebt bewaard. Het laat ook een **token voor het platform** zien (nodig bij VPS 2), het wachtwoord voor Keycloak-beheer en het eerste wachtwoord van de testgebruikers.

**VPS 2** vraagt om dat token. Plak het; je ziet niets terwijl je plakt.

**VPS 1** controleert eerst of de DNS uit stap 2 klopt. Zo niet, dan zegt het wat er mis is. Wacht dan even en probeer opnieuw. Daarna haalt Caddy zelf de HTTPS-certificaten op.

## 7. Proberen

Ga naar `https://oa.<domein>` en log in als `test.haarlem` (of `test.zandvoort`, of `beheer.haarlem` voor de beheerdersrol) met het eerste wachtwoord van VPS 3. Keycloak vraagt je meteen een eigen wachtwoord te kiezen. Open dan de demo-werkomgeving: `https://oa.<domein>/werkomgeving`.

Log met alle drie de testgebruikers één keer in, ook als je ze niet meteen nodig hebt. Het eerste wachtwoord is willekeurig, maar het blijft geldig tot iemand het heeft vervangen.

Staat er bij Anonimiseren "Jouw niveau: PPL 0", dan heeft die gebruiker nog geen niveau voor persoonsgegevens. Anonimiseren werkt dan wel, maar de originelen zijn niet in te zien en de grondslag niet te wijzigen. Zie "Niveaus voor persoonsgegevens" in stap 9.

## 8. De assistent in Word, Collabora en LibreOffice

Naast de demo-werkomgeving werkt de assistent in drie echte werkomgevingen.
Het paneel is overal hetzelfde; alleen de adapter verschilt.

### Eerst: Collabora een adres geven

Collabora Online draait op VPS 1 en krijgt een eigen adres: `office.<domein>`.
Maak daarvoor een DNS-record, net als in stap 2: een A-record naar het
IP-adres van VPS 1, of een CNAME naar de naam waar `oa` en `id` al naar
wijzen. `installeer.sh` en `bijwerken.sh` zeggen of het klopt.

### Microsoft Word, Excel en PowerPoint (ook voor het web)

1. Download het manifest: `https://oa.<domein>/word/manifest.xml`.
2. Open Word. Zonder Word op je computer kan dat in de browser, op
   office.com, met een (gratis) Microsoft-account.
3. Kies op het tabblad **Start** de knop **Invoegtoepassingen** en daarna
   **Meer invoegtoepassingen → Mijn invoegtoepassingen → Mijn
   invoegtoepassing uploaden**. Kies het manifest.
4. Er is nu een tabblad **Assistent**, met dezelfde knoppen als de demo:
   **Paneel**, de modules (Overzicht, Metadateren, Toegankelijkheid …) en
   **Beoordelen**. Een knop opent het paneel rechts in Word op die module.
   Log in; het inloggen opent in een apart venster. Blokkeert de browser
   dat venster, sta pop-ups toe voor office.com. De knoppen hebben een
   recente Office nodig (Microsoft 365 of de webversie; Word vanaf versie
   2205).

Het paneel past herstellingen aan in Word zelf: kopniveaus, alternatieve
tekst van afbeeldingen, linkteksten en de kopregel van tabellen. De opmaak
blijft staan. De afdruk van het platform komt in de documenteigenschappen.

Hetzelfde manifest werkt in **Excel** en **PowerPoint**: upload het daar op
dezelfde manier. In Excel hernoemt het paneel bladen en vult het
alternatieve tekst bij afbeeldingen in; in PowerPoint vult het titels van
dia's en alternatieve tekst in. Dat is gebouwd maar nog niet getest in een
echte Excel of PowerPoint. Had je het manifest al eerder geüpload,
verwijder het dan en upload het nieuwe als het versienummer is veranderd
(dat staat op de downloadpagina).

### Collabora Online (LibreOffice in de browser)

Ga naar `https://oa.<domein>/collabora` en kies **Nieuw voorbeelddocument**.
Links staat Collabora, rechts het paneel. In de werkbalk van Collabora
komen de knoppen van de assistent erbij (Paneel, de modules, Beoordelen).
Collabora kan geen deel van een tekstdocument vervangen. De assistent
vervangt daarom het hele document en laadt het opnieuw: dat is de terugval
uit de architectuur, hier in het echt.

### LibreOffice op je eigen computer

De assistent staat in Writer, Calc en Impress zelf, als tabblad
**Assistent** in de zijbalk rechts (naast Eigenschappen en de Navigator),
met daarbij een werkbalk **Assistent** met dezelfde knoppen als de demo. Dat
is hetzelfde webpaneel als in de browser en in Word. Op Linux is dat
beproefd; op Windows (WebView2) en Mac (WebKit) is het nog een proef. Lukt
de webweergave niet, dan krijg je het eigen paneel van LibreOffice, met de
reden erbij. Anonimiseren in het document gaat dan via **Office Assistent →
Assistent in de browser openen**.

1. **Alleen Linux, één keer:** installeer de webweergave voor Python:
   `sudo apt install python3-gi gir1.2-webkit2-4.1` (Ubuntu en Debian).
2. Download de extensie: `https://oa.<domein>/libreoffice` (of de
   voorpagina `https://office.<domein>`) → **office-assistent.oxt**. Het
   adres van jouw omgeving zit er al in. Een eerdere versie wordt vervangen.
3. In LibreOffice: **Extra → Extensiebeheer → Toevoegen**, kies het bestand,
   en herstart LibreOffice.
4. Open een document in Writer. Klik in de werkbalk **Assistent** op een
   knop, of in de zijbalk rechts op het groene **A** (of kies **Office
   Assistent → Assistent tonen**). Zie je de werkbalk niet: **Beeld →
   Werkbalken → Assistent**. Zie je geen zijbalk: **Beeld → Zijbalk**.
5. **Webpaneel:** log in het paneel in, met je gewone inlog en je
   authenticator-app. Je blijft ingelogd zolang de sessie van de server
   geldt. **Eigen paneel:** kies **Aanmelden**; je browser opent, log in en
   sta toe dat de pagina je computer bereikt. Daarna kun je het tabblad
   sluiten.
6. Wisselen tussen beide: **Office Assistent → Zijpaneel: webpaneel van de
   server** of **Zijpaneel: eigen paneel van LibreOffice**. Dat geldt voor
   documenten die je daarna opent.

Liever het paneel in de browser, naast Writer? Kies **Office Assistent →
Assistent in de browser openen**.

Komt het menu **Office Assistent** niet tevoorschijn op Linux, installeer
dan de Python-ondersteuning van LibreOffice:
`sudo apt install libreoffice-script-provider-python` (Ubuntu en Debian).

## 9. Het beheerportaal

Op `https://oa-admin.<domein>` beheert de gemeente wie de Office Assistent mag beheren: accounts, groepen met rechten, de audit en instellingen. Het draait op VPS 1, met een eigen database die niet van buiten bereikbaar is. Het ontwerp staat in [`oa-beheer/docs/security.md`](https://github.com/digitaalgemeengoed/oa-beheer/blob/main/docs/security.md).

Er zijn twee manieren om binnen te komen:

- **Gewoon**: via Keycloak, met wachtwoord en authenticator-app, elke keer opnieuw.
- **Nood**: `https://oa-admin.<domein>/emergency`, met het hoofdaccount `beheerder@<domein>`, een wachtwoord en een TOTP-code. Werkt ook als Keycloak of e-mail plat ligt. Elk gebruik komt in de audit en gaat per e-mail naar de superadmins; de sessie stopt na 30 minuten.

### DNS

Nog een record naar VPS 1, net als `oa` en `id`:

| Naam | Type | Waarde |
|---|---|---|
| `oa-admin.<domein>` | A (of CNAME naar je domein) | IP van VPS 1 |

Controleer na een kwartier op je eigen computer: `nslookup oa-admin.<domein>`.

### Installeren

Het portaal komt mee met `bijwerken.sh` (of `installeer.sh` bij een nieuwe VPS 1). Werk bij in de gewone volgorde: VPS 3, 2, 1. Op VPS 1 verschijnen nieuwe wachtwoorden voor het portaal in `.env`; de bestaande blijven gelijk.

```
sudo /opt/oa-uitrol/server/bijwerken.sh
sudo /opt/oa-uitrol/server/beheer.sh status
```

### Het noodaccount instellen (VPS 1)

```
sudo /opt/oa-uitrol/server/beheer.sh nood
```

Je krijgt **één keer** een wachtwoord en een TOTP-geheim te zien. Zet ze meteen in je wachtwoordmanager en voeg het geheim toe aan een authenticator-app (Microsoft Authenticator, Google Authenticator of je wachtwoordmanager; bij "handmatig invoeren" plak je het TOTP-geheim). Kwijt? Draai dezelfde opdracht opnieuw; het oude werkt dan niet meer.

Log in op `https://oa-admin.<domein>/emergency` met wachtwoord, code en een reden ("Eerste inrichting"). Dan:

1. **Groepen** → een groep `Superbeheer`, niveau 4, superadmin aan, alle rechten.
2. **Accounts** → een account voor jezelf, met **precies het e-mailadres van je Keycloak-gebruiker**, in de groep `Superbeheer`.

### Inloggen via Keycloak aanzetten (VPS 3, dan VPS 1)

Op **VPS 3**:

```
sudo /opt/oa-uitrol/server/keycloak-beheer.sh
```

Dat maakt in Keycloak de client `oa-beheer`, zorgt dat Keycloak doorgeeft dat je een authenticator-app gebruikte, zet de blokkade na tien foute wachtwoorden aan en maakt op verzoek een Keycloak-gebruiker voor je (met een tijdelijk wachtwoord; bij de eerste inlog kies je een eigen wachtwoord en koppel je een app). Aan het eind staat een **client-geheim**.

Op **VPS 1**:

```
sudo /opt/oa-uitrol/server/beheer.sh keycloak
```

Plak het client-geheim. Het script controleert het bij Keycloak en herstart het portaal. Ga naar `https://oa-admin.<domein>` en kies **Inloggen**.

**Kom je niet binnen** en staat in de audit (via `/emergency`) `geen-tweede-factor`? Dan geeft Keycloak niet door dat er een tweede factor was. Dat deel is nog niet getest tegen een echte Keycloak. Tijdelijk oplossen: in het portaal bij **Instellingen** `mfa.vereist` uitzetten (Keycloak vraagt de code dan nog steeds, het portaal controleert het alleen niet meer). Meld het, dan zoeken we het uit.

### Niveaus voor persoonsgegevens (VPS 3)

Bij anonimiseren versleutelt het platform persoonsgegevens per AVG-categorie. Wie welke categorie mag inzien, hangt af van een Keycloak-rol:

| Rol | Mag inzien |
|---|---|
| `ppl-1` | gewone persoonsgegevens (art. 6) |
| `ppl-2` | ook bijzondere persoonsgegevens (art. 9) |
| `ppl-3` | ook strafrechtelijke gegevens (art. 10), en de versies van vóór het anonimiseren |

`keycloak-beheer.sh` (zie hierboven) maakt de rollen aan, geeft elke medewerker zonder niveau `ppl-1`, en vraagt bij een nieuwe eigen gebruiker welk niveau die krijgt. Gebruikers die al bestonden voordat je het script draaide, krijgen pas een niveau als je het (opnieuw) draait. Een ander niveau geven: in het Keycloak-beheer (via de tunnel uit stap 10, realm `gemeenten`) bij **Users** → de gebruiker → **Role mapping** → **Assign role**, en kies `ppl-1`, `ppl-2` of `ppl-3`. Het nieuwe niveau geldt na opnieuw inloggen.

### Metadatamodel

Onder **Metadatamodel** stelt informatiebeheer in welke metadata medewerkers in het paneel invullen: een basismodel (MDTO, RGBZ of TMLO), welke velden aan staan en verplicht zijn, labels en hulpteksten, waardelijsten (ook uit TOOI) en eigen velden. Publiceren maakt een nieuwe versie van het objecttype; stukken die al zijn vastgelegd houden hun versie. Er is een voorbeeld van het paneel en een overzicht van wat er verandert. Wat je nog aan het opstellen bent, blijft als concept bewaard.

- Geef een groep het recht `metadata.manage` (wijzigen en publiceren) of `metadata.view` (alleen bekijken), bij **Groepen**.
- Het portaal beheert één gemeente: `BEHEER_GEMEENTE` in `.env` op VPS 1 (standaard `haarlem`). Het gebruikt `PLATFORM_INTERN` en `PLATFORM_DIENSTSLEUTEL`, die er al staan.
- Elke publicatie staat in de audit van het portaal (met reden) en als gebeurtenis in het platform.
- Geef het model bij stap 1 een naam, zoals "RGBZ Haarlem". Medewerkers zien naam en versie klein bovenaan het paneel Metadateren. Een andere naam is ook een nieuwe versie.
- Elk vastgelegd stuk houdt de versie waarmee het is vastgelegd; het paneel toont dan die velden en zegt welke versie nu geldt. In het bestand staan de documenteigenschappen **Identificatie**, **Versie**, **Metadatamodel** en (als het model een status heeft, zoals RGBZ) **Status**. Die kun je in een veld tonen, bijvoorbeeld in de koptekst.

### Anonimiseren → Kwaliteit

Onder **Anonimiseren**, tab **Kwaliteit**, zie je hoe goed de assistent persoonsgegevens herkent. Bij elke bevestiging telt het paneel wat de medewerker deed: bevestigd, *Laat staan* (met reden: geen persoonsgegeven, mag openbaar, verkeerde soort) of zelf toegevoegd. Daaruit volgen de precisie en hoeveel de assistent zelf vond, per soort en per versie van de herkenner, en de vormen die vaak gemist of onterecht gevonden worden ("06-51209934" wordt `9-9`), met een regexp als begin voor een nieuw patroon.

- Geef een groep het recht `anonimiseren.view` bij **Groepen**.
- Er worden geen waarden bewaard en geen koppeling met het stuk; alleen tellingen, vormen, lengtes en signaalwoorden van een vaste lijst, per dag. Een vorm verschijnt pas als hij in minstens 5 bevestigingen voorkwam.
- "Gevonden" is een bovengrens: wat de assistent én de medewerker missen, ziet niemand. Wil je de echte recall weten, laat dan af en toe een steekproef door een tweede persoon nakijken.

### E-mail (VPS 1)

```
sudo /opt/oa-uitrol/server/beheer.sh smtp
```

Server, poort, gebruikersnaam, wachtwoord en afzender van het SMTP-account. Het portaal mailt bij een nieuw account, bij elk noodgebruik (naar de superadmins) en, als je bij Instellingen `audit.dagelijkse_hash_aan` invult, elke ochtend de hash van de audit. Bewaar die mails buiten de server: alleen daarmee kun je later aantonen dat de audit niet is herschreven.

### Back-up

```
cd /opt/oa-uitrol && sudo docker compose -f vps1-toegang.yml exec -T beheer-db pg_dump -U oa_beheer_eigenaar oa_beheer > ~/beheer-$(date -I).sql
```

Bewaar die niet op dezelfde plek als `/opt/oa-uitrol/.env`: met `BEHEER_ADMIN_SECRET` erbij is het geheim van het noodaccount te ontsleutelen.

## 10. Dagelijks beheer

| Wat | Hoe |
|---|---|
| Hoe staat een VPS ervoor? | `sudo /opt/oa-uitrol/server/controleer.sh` |
| Nieuwe versie van GitHub installeren | `sudo /opt/oa-uitrol/server/bijwerken.sh`, in de volgorde VPS 3, 2, 1 |
| Herstarten na updates (meldt `controleer.sh`) | `sudo reboot`, één VPS tegelijk |
| **Na elke herstart van VPS 3** | `sudo /opt/oa-uitrol/server/ontzegel.sh` en plak de ontzegelsleutel |
| Beheerportaal: draait het, wat staat aan | `sudo /opt/oa-uitrol/server/beheer.sh status` (op VPS 1) |
| Logboek van een onderdeel | `cd /opt/oa-uitrol && sudo docker compose -f vps2-platform.yml logs --tail 100 platform` |

**Anonimiseren** gebruikt OpenAnonymiser van Conduction op VPS 3, alleen intern bereikbaar. `bijwerken.sh` bouwt het uit de broncode, op de vaste versie in `haal-op.sh`. De eerste keer duurt dat enkele minuten, want het Nederlandse taalmodel wordt meegebouwd. Het gebruikt ongeveer 1 GB geheugen; kijk met `free -h` of VPS 3 dat over heeft. Draait het niet, dan zegt de module Anonimiseren dat; de rest van de assistent werkt gewoon. Logboek: `cd /opt/oa-uitrol && sudo docker compose -f vps3-diensten.yml logs --tail 50 openanonymiser`.

**Toegankelijkheid van het bestand** gebruikt oa-wcag op VPS 3 (Java), ook alleen intern bereikbaar. Het controleert docx, xlsx en pptx en vult de controle van de inhoud aan. `bijwerken.sh` bouwt het; de eerste keer duurt dat een paar minuten. Draait het niet, dan meldt de module Toegankelijkheid dat en doet ze de rest gewoon. Logboek: `cd /opt/oa-uitrol && sudo docker compose -f vps3-diensten.yml logs --tail 50 wcag`.

**Wat er veranderd is** per versie staat in de [CHANGELOG](../CHANGELOG.md), met bij elke versie welke VPS je moet bijwerken en of de LibreOffice-extensie of het Word-manifest opnieuw moet.

**Beveiligingsupdates** gaan elke dag automatisch, zonder herstart. Een server herstart nooit vanzelf: na een herstart moet OpenBao met de hand worden ontzegeld, en tot dat gebeurt kan het platform geen documenten openen of opslaan. Kijk daarom eens per week met `controleer.sh` of een herstart nodig is.

**Keycloak-beheer** (gebruikers, rollen) is van buiten afgesloten. Je komt erbij via een tunnel over SSH:

```
ssh -L 8080:10.66.0.3:8080 beheer@<IP van VPS 1>
```

Laat dat venster open en ga in je browser naar `http://localhost:8080/admin`. De gebruiker is `beheer`; het wachtwoord liet VPS 3 zien. Het staat ook in `/opt/oa-uitrol/.env` op VPS 3.

**Kom je er niet meer in?** Elke provider heeft in het klantenpaneel een noodconsole (VNC). Daar log je in als root, met het root-wachtwoord uit de mail. Dat werkt ook als SSH dicht staat.

## 11. Als het misgaat

| Melding | Wat het betekent |
|---|---|
| `Permission denied (publickey)` | De server kent deze sleutel niet, of je logt in als root. Gebruik `ssh beheer@…`. Op een andere computer moet je de sleutel eerst daar neerzetten. |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` | Je hebt de VPS opnieuw geïnstalleerd. Typ `ssh-keygen -R <IP>` en probeer opnieuw. |
| `sudo` vraagt om een wachtwoord | Dat is het wachtwoord van `beheer` uit stap 3, niet de wachtwoordzin van je sleutel. |
| VPS niet bereikbaar onder "Privénetwerk" | Draai `koppelen.sh` op die VPS. Klopt het IP-adres in de koppelregel? |
| Platform zegt "verzegeld" of geeft fouten bij opslaan | OpenBao op VPS 3 is herstart: draai `ontzegel.sh`. |
| Collabora: "Collabora Online staat niet aan" of een lege editor | Klopt het DNS-record `office.<domein>`? Kijk op VPS 1 met `sudo docker compose -f vps1-toegang.yml logs collabora`. |
| Word: "Het aanmeldvenster ging niet open" | Sta pop-ups toe voor office.com en probeer opnieuw. |
| Beheerportaal: "Inloggen is niet gelukt" | Heeft je e-mailadres een account in het portaal (aanmaken via `/emergency`), en is het in Keycloak geverifieerd? Meldt Keycloak geen tweede factor, dan staat dat in de audit (`geen-tweede-factor`); zie stap 9. |
| Beheerportaal start niet | `sudo /opt/oa-uitrol/server/beheer.sh logs`. De eerste regels noemen de instelling die niet klopt. |
| LibreOffice: "Geen verbinding met LibreOffice" | Kies in Writer opnieuw **Office Assistent → Assistent openen bij dit document**. De verbinding hoort bij één document en stopt als LibreOffice sluit. |

Een script opnieuw draaien kan altijd. Het slaat over wat al klaar is en houdt bestaande wachtwoorden.

## Wat dit wel en niet beveiligt

**Wel:** alleen SSH met een sleutel, en geen root via SSH; een firewall en fail2ban; elke dag beveiligingsupdates; van buiten alleen HTTPS op VPS 1; tussen de VPS'en alleen versleuteld verkeer; per interne poort alleen de VPS die hem nodig heeft; willekeurige wachtwoorden per installatie; documenten versleuteld met sleutels op een andere machine; het Keycloak-beheer niet van buiten bereikbaar.

**Nog niet (prototype):**
- Back-ups alleen via de automatische back-up van de provider. Die back-ups van VPS 3 bevatten ook sleutels die al zijn vernietigd. Een document is pas echt onleesbaar als de laatste back-up met die sleutel is verlopen.
- OpenBao met één ontzegelsleutel, zonder TLS (het verkeer gaat wel door WireGuard).
- Geen monitoring of meldingen; `controleer.sh` doe je zelf.
- Sessies van de integratielaag gaan verloren als die herstart: gebruikers moeten dan opnieuw inloggen.
- De gebruiker `beheer` mag alles met sudo. Wie zijn sleutel en wachtwoord heeft, heeft de server.
- **Gebruik geen echte persoonsgegevens of vertrouwelijke stukken** zolang dit een prototype is.
