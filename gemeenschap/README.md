# Gemeenschapsplatform (VPS 4)

Het platform van Digitaal Gemeengoed en NL-Dit voor het netwerk rond de Office
Assistent: lid worden, profielen, fora, nieuwsbrief, meldingen en projecten.
Het draait op een eigen server en staat los van de Office Assistent (VPS 1
tot 3): een eigen Keycloak, geen WireGuard, geen toegang tot documenten.

| Adres | Dienst | Waarvoor |
|---|---|---|
| `digitaalgemeengoed.nl` | WordPress met BuddyPress, bbPress en CiviCRM | site, leden en groepen, fora onder `/forum/`, nieuwsbrief en contacten |
| `aanmelden.digitaalgemeengoed.nl` | Keycloak, realm `gemeenschap` | lid worden, inloggen, wachtwoord vergeten |
| `projecten.digitaalgemeengoed.nl` | Redmine | meldingen, wensen, roadmap, portfolio |
| `forum.digitaalgemeengoed.nl` | (doorverwijzing) | naar `/forum/` |

Het ontwerp met de afwegingen staat in het project als
`OA-ontwerp-gemeenschapsplatform.md`.

## Wie is de bron van wat

**Keycloak is de bron** voor wie lid is, van welke organisatie en in welke
groep. WordPress, CiviCRM en Redmine nemen dat over bij elke keer inloggen.
Een tweede bron (BuddyPress) zou betekenen dat twee systemen het oneens kunnen
zijn; daarom kan je je in WordPress niet zelf registreren: `/lid-worden/`
stuurt door naar het aanmeldformulier van Keycloak.

| In Keycloak | Wordt in WordPress | In bbPress | In Redmine |
|---|---|---|---|
| `/netwerk/gebruikers` (standaard) | abonnee, ledentype Gebruiker | deelnemer | groep Netwerk: Gebruikers |
| `/netwerk/contributors` | ledentype Contributor | deelnemer | groep Netwerk: Contributors |
| `/netwerk/members` | ledentype Member | deelnemer | groep Netwerk: Members |
| `/netwerk/kerngroep` | ledentype Kerngroep | moderator | groep Netwerk: Kerngroep |
| `/site/redactie` | redacteur | moderator | — |
| `/site/beheer` | beheerder | keymaster | beheerder |

Profielvelden uit het aanmeldformulier (organisatie, functie, werkveld,
toestemming voor de nieuwsbrief) komen in het BuddyPress-profiel (groep
"Netwerk", alleen zichtbaar voor ingelogde leden) en in CiviCRM: de
organisatie als werkgever, de groepen als "Netwerk: …", en de toestemming als
inschrijving op "Nieuwsbrief" met een activiteit per wijziging. Een
organisatie in Keycloak (met e-maildomein, zoals `haarlem.nl`) koppelt nieuwe
leden van die gemeente vanzelf.

Redmine haalt de groepen niet bij het inloggen maar elke tien minuten
(`redmine/redmine_groepen.py`).

## Bestanden

```
keycloak/import/realm-gemeenschap.json   realm, groepen, profielvelden, clients
keycloak/themes/digitaalgemeengoed/      kleuren voor het aanmeld- en inlogscherm
wordpress/dg-gemeenschap.php             mu-plugin: inloggen, rollen, profiel, CiviCRM
wordpress/inrichten.sh                   wp-cli: installeren en bijwerken
redmine/                                 image met redmine_oauth, inrichten.rb, groepssync
caddy/Caddyfile                          de vier adressen, certificaten
installeer.sh  bijwerken.sh  back-up.sh  beheer van de server
```

## Installeren

Zie INRICHTING.md, stap 12. Kort: `server/inrichten.sh` (kies 4),
`server/ssh-afsluiten.sh`, dan `server/installeer.sh`. Koppelen is niet nodig.

## Beheer

- **Bijwerken:** `sudo /opt/oa-uitrol/server/bijwerken.sh`. Werkt images,
  WordPress, plugins, vertalingen en CiviCRM bij (CiviCRM naar de versie in
  `CIVICRM_VERSIE` in `.env`).
- **Keycloak-beheer** is van buiten afgesloten. Vanaf je eigen computer:
  `ssh -L 8080:127.0.0.1:8080 beheer@<server>` en dan
  `http://localhost:8080/admin`.
- **Back-up:** elke nacht om 03:30 naar `/var/backups/dg-gemeenschap`, 14
  dagen. Kopieer die map naar een andere aanbieder; `.env` hoort in je
  wachtwoordmanager, niet in de back-up.
- **Controleren:** `sudo /opt/oa-uitrol/server/controleer.sh`.

## Privacy

Digitaal Gemeengoed en NL-Dit zijn samen verantwoordelijk (AVG artikel 26).
Leg in een regeling vast wie wat doet en zet de kern daarvan in de
privacyverklaring. Het aanmeldformulier vraagt toestemming voor de
nieuwsbrief apart van de voorwaarden; CiviCRM bewaart wanneer die gegeven of
ingetrokken is.
