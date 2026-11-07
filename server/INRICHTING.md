# De drie VPS'en inrichten, stap voor stap

Dit stappenplan is voor wie geen systeembeheerder is. Je typt of plakt
steeds een paar opdrachten; de scripts doen de rest en zeggen wat de
volgende stap is. Reken op twee tot drie uur, waarvan veel wachten.

| VPS | Rol | Wat erop komt |
|---|---|---|
| VPS 1 | toegang | Caddy (HTTPS) en de integratielaag. De enige die van buiten bereikbaar is. |
| VPS 2 | platform | PostgreSQL, SILO (opslag), OpenSearch, platform en worker |
| VPS 3 | diensten | assistent-services, Keycloak (inloggen), OpenBao (sleutels) |

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

## 8. Dagelijks beheer

| Wat | Hoe |
|---|---|
| Hoe staat een VPS ervoor? | `sudo /opt/oa-uitrol/server/controleer.sh` |
| Nieuwe versie van GitHub installeren | `sudo /opt/oa-uitrol/server/bijwerken.sh`, in de volgorde VPS 3, 2, 1 |
| Herstarten na updates (meldt `controleer.sh`) | `sudo reboot`, één VPS tegelijk |
| **Na elke herstart van VPS 3** | `sudo /opt/oa-uitrol/server/ontzegel.sh` en plak de ontzegelsleutel |
| Logboek van een onderdeel | `cd /opt/oa-uitrol && sudo docker compose -f vps2-platform.yml logs --tail 100 platform` |

**Beveiligingsupdates** gaan elke dag automatisch, zonder herstart. Een server herstart nooit vanzelf: na een herstart moet OpenBao met de hand worden ontzegeld, en tot dat gebeurt kan het platform geen documenten openen of opslaan. Kijk daarom eens per week met `controleer.sh` of een herstart nodig is.

**Keycloak-beheer** (gebruikers, rollen) is van buiten afgesloten. Je komt erbij via een tunnel over SSH:

```
ssh -L 8080:10.66.0.3:8080 beheer@<IP van VPS 1>
```

Laat dat venster open en ga in je browser naar `http://localhost:8080/admin`. De gebruiker is `beheer`; het wachtwoord liet VPS 3 zien. Het staat ook in `/opt/oa-uitrol/.env` op VPS 3.

**Kom je er niet meer in?** Elke provider heeft in het klantenpaneel een noodconsole (VNC). Daar log je in als root, met het root-wachtwoord uit de mail. Dat werkt ook als SSH dicht staat.

## 9. Als het misgaat

| Melding | Wat het betekent |
|---|---|
| `Permission denied (publickey)` | De server kent deze sleutel niet, of je logt in als root. Gebruik `ssh beheer@…`. Op een andere computer moet je de sleutel eerst daar neerzetten. |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` | Je hebt de VPS opnieuw geïnstalleerd. Typ `ssh-keygen -R <IP>` en probeer opnieuw. |
| `sudo` vraagt om een wachtwoord | Dat is het wachtwoord van `beheer` uit stap 3, niet de wachtwoordzin van je sleutel. |
| VPS niet bereikbaar onder "Privénetwerk" | Draai `koppelen.sh` op die VPS. Klopt het IP-adres in de koppelregel? |
| Platform zegt "verzegeld" of geeft fouten bij opslaan | OpenBao op VPS 3 is herstart: draai `ontzegel.sh`. |

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
