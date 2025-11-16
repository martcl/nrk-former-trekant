# NRK Former - Trekantsøk 

Program som løser [NRK former spillet](https://www.nrk.no/spill/former-1.17105310) automatisk. 

## Bruk

```bash
nrkformer --help
Usage: nrkformer [--help] [--memory <bytes>] [DD-MM-YYYY]
```

* Minne i bytes som allokeres. (default: 1 GB)
* Datoen du ønsker å løse brettet for. (default: i dag)

## Hvordan fungerer det?

Spillet kan representeres som en graf der brettet er nodene og trekk er kanter. Målet er å lage den korteste veien gjennom grafen til det er tomt for mulige trekk. For å garantere at løsningen man finner er den beste må man gjøre et bredde-først-søk, noe som ikke er mulig fordi grafen er for stor. Derfor må man gjøre smarte søk for å finne ganske gode løsninger.

Denne løsningen fungerer ved å opprette en prioritetskø per _"trekk lengde"_. Fra start brettet, klikker man på alle mulige farge-blokker og putter dem i pri-kø nr. 1. Man tar ut det beste brettet og klikker på alle farge-blokker, der disse brettene puttes i pri-kø nr. 2. Igjen tar man ut den beste fra pri-kø nr. 1 og putter de nye brettene i pri-kø nr. 2. Etterpå tar man ut den beste fra pri-kø nr. 2, klikker på alle farge-blokker og putter dem i pri-kø nr. 3. Rekkefølgen på nodene er ut som en trekant - ref trekantsøk.

Steg:
```
A      # kø 1 (alle brett med 1 klikk fra start)
       # kø 2 (alle brett med 1 klikk unna brett A)
------------
AB     # kø 1
       # kø 2 (brett med 1 klikk unna brett A og B)
------------
AB     # kø 1
C      # kø 2
       # kø 3 (alle brett med 1 klikk unna brett C)
------------
ABD    # kø 1
CE     # kø 2 (brett med 1 klikk unna brett A, B og D)
       # kø 3 (alle brett med 1 klikk unna brett C og E)
------------
ABD    # kø 1
CE     # kø 2
F      # kø 3 (brett med 1 klikk unna brett C og E)
       # kø 4 (brett med 1 klikk unna brett F)
```

Alle prioritetskøene sorteres etter hvor mange mulige trekk det er på brettet. Dette gir iterativt bedre løsninger. Algoritmen balanserer utforsking og utnyttelse ved å prioritere brett med færrest mulige trekk, samtidig som flere nivåer med prioritetskøer sikrer at nye områder blir utforsket.

## Optimaliseringer

Jeg har løst dette problemet før, men da brukte jeg Golang og A*. Det funket helt _OK_, men det tok ofte ~1 min å finne løsningen. Dette programmet tar som regel under 1 sekund for å finne beste løsning.


* All minne blir allokert i starten av programmet. Minnet er capped til det du ønsker. Hvis minnet blir brukt opp, returnerer programmet beste svaret den har funnet til nå.
* Ingen garbage collector. Zig for the win <3
* Trekantsøk er en mye bedre søkealgoritme for problemstilling enn A* som jeg brukte [i forgje løsning](https://github.com/martcl/nrk-former).
* Implementert Tommy Odland's A* huristic algoritme for å finne et "lower bound" av hvor mange trekk et brett trenger for å bli løst. Jeg bruker den til å kaste bort brett der `move_count + lower_bound >= found_solution`.
* Single-threaded! Programmet er så effektivt at det ikke har vært nødvendig å legge til den ekstra kompleksiteten som kommer med multi-threading. Kanskje jeg legger det til senere...
* CLI for å se løsningen på alle brett, fortidens, dagens og fremtidens brett.
* Ingen manuel justeringer for å finne beste heuristikk. Det beste trekket er alltid det som reduserer hvor mange trekk som er mulig.

## Kjente svakheter

* Køene fra 5-9 kan bli veldig store og hvis det finnes et nedprioritert brett i en av disse køene som vil i neste brett gi en eksepsjonell gevinst, vil ikke dette bli funnet.


## Hastighet
Hvor lang tid tar det å finne samme eller bedre enn "Best i Norge". I parantes står totalt antall brett som har blitt tatt ut av køene og undersøkt. Testet på MacBook Air 2022.
```
16-11-2025 - 0.117056292 sekunder (1139 brett)
15-11-2025 - 0.056991792 sekunder (410 brett)
14-11-2025 - 0.381813792 sekunder (3576 brett)
13-11-2025 - 51.001239667 sekunder (630 404 brett)
12-11-2025 - 10.8367515 sekunder (121 409 brett)
11-11-2025 - 0.023420125 sekunder (161 brett)
10-11-2025 - 0.026146042 sekunder (161 brett)
09-11-2025 - 0.116512167 sekunder (1287 brett)
```

## Utvikling 

```bash
# brukte Zig versjon 0.15.1
git clone git@github.com:martcl/nrk-former-trekant.git && cd nrk-former-trekant
zig build
./zig-out/bin/nrkformer
```


### Referanser
- Lemons, S., Ruml, W., Linares López, C., & Holte, R. (2023). *Triangle Search: An Anytime Beam Search*. ICAPS 2023 Heuristics and Search for Domain-Independent Planning Workshop. https://openreview.net/forum?id=vJQ9iLJHBs  
- YouTube. (2023). “Triangle Search: An Anytime Beam Search (HSDIP 2023)”. YouTube channel 
Sofia Lemons. https://www.youtube.com/watch?v=pldJwKlWGSU  
- Tommy Odland — "Solving NRK’s game 'Former'". Artikkel og bakgrunn på: https://tommyodland.com/articles/2024/solving-nrks-game-former/index.html (hentet 15-11-2025)
