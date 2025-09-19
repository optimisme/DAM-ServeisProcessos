<div style="display: flex; width: 100%;">
    <div style="flex: 1; padding: 0px;">
        <p>© Albert Palacios Jiménez, 2024</p>
    </div>
    <div style="flex: 1; padding: 0px; text-align: right;">
        <img src="./assets/ieti.png" height="32" alt="Logo de IETI" style="max-height: 32px;">
    </div>
</div>
<br/>

# Exercici 0, **"Connecta 4"** amb JavaFX i WebSockets

El joc ha de tenir **cinc vistes**:

1. **Configuració**  
   - Configura l’URL del servidor i el **nom del jugador**.  
   - Botó per **connectar-se** i continuar.

2. **Selecció de contrincant**  
   - Mostra una **llista de clients disponibles** (connectats però sense partida en curs).  
   - Permet **enviar i acceptar invitacions** per iniciar partida 1v1.

3. **Sala d’espera / Emparellament**  
   - Mostra l’estat **“Esperant contrincant”** o **“Emparellant…”**.  
   - Quan l’altre jugador accepta, passa automàticament a la partida.

4. **Partida (tauler i joc en temps real)**  
   - **Tauler de 7 columnes (A–G) x 6 files (0–5)**.  
   - El tauler es representa amb **botons** (o cel·les clicables) estilitzats amb **CSS de JavaFX**.  
   - **Torns**:  
     - El jugador amb el torn veu el text **“Et toca jugar”**.  
     - L’altre jugador té **totes les columnes desactivades** (no pot deixar fitxes).  
   - **Interacció i “hover”**:  
     - En passar el ratolí per sobre d’una **columna**, aquesta es **ressalta** (previsualització) per indicar on **cauria la fitxa**.  
     - El jugador que **no** té el torn veu **en temps real** la **columna** on l’altre jugador té el ratolí (ressaltada amb un estil diferent).  
   - **Col·locació de fitxes**:  
     - En fer clic a una **columna**, la fitxa cau fins a la **posició lliure més baixa** d’aquella columna.  
   - **Condicions de victòria i empat**:  
     - Guanya qui connecta **4 fitxes** consecutives **horitzontals, verticals o diagonals**.  
     - Si el tauler s’omple sense guanyador, és **empat**.

5. **Resultat**  
   - Mostra **Guanyador / Perdedor / Empat**.  
   - Botons per **tornar a la selecció de contrincant** o **tancar**.

---

## Representació de cel·les i estils (JavaFX CSS)

Cada cel·la és un **botó** amb lletra i color:

- **""** (buit): cel·la sense fitxa → **blanc**  
- **"V"**: fitxa **vermella** (jugador 1) → botó **vermell**  
- **"G"**: fitxa **groga** (jugador 2) → botó **groc**

Estils recomanats:
- **Buit**: fons blanc, vora gris suau  
- **Hover de columna (jugador actiu)**: marca **la columna** amb una **ombra** o fons lleuger  
- **Hover remot (contrincant)**: marca la columna amb un **contorn** o patró diferent  
- **Quatre en línia (victòria)**: destaca les 4 cel·les guanyadores (per exemple, **ombra/pulsació**)

> *Notes*: Les lletres **"V"** i **"G"** són només etiquetes internes; visualment el color del botó ha de ser clar i suficient.

---

## Normes i flux de joc

- El **servidor** gestiona tota la **lògica de joc**:
  - Validació de torns  
  - Caiguda de fitxes  
  - Detecció de **4 en línia** i **empat**  
  - Sincronització d’estat entre clients
- Els **clients**:
  - **Envien esdeveniments** (connectar, convidar, acceptar, **hover de columna**, **jugada a columna**)  
  - **Renderitzen** l’estat rebut del servidor

---

## Protocol (orientatiu) via WebSocket

Esdeveniments mínims (API - JSON):

- `join { name }`
- `lobby.list { players[] }`
- `invite { to }` / `invite.accept { from }` / `invite.decline`
- `game.start { gameId, youAre: "V"|"G", firstTurn }`
- `game.hover { gameId, column }` *(s’emet contínuament mentre el ratolí es mou per columnes)*
- `game.play { gameId, column }`
- `game.state { board, turn, lastMove, status: "playing"|"win"|"draw", winner? }`
- `game.end { result: "win"|"lose"|"draw" }`
- `error { message }`

---

## Requisits tècnics

- **JavaFX** per a la interfície (multi-escena o contenidor amb canvis de vista).  
- **WebSockets** per a la comunicació temps real (client Java; servidor pot ser Java o un altre llenguatge).  
- **ExecutorService** opcional per a tasques d’E/S o timers UI (sense bloquejar el fil d’UI).  
- **CSS** de JavaFX per a tots els canvis visuals (colors, hover, estat del torn, etc.).  
- **Separació clara** entre:
  - **Vista (UI JavaFX)**  
  - **Client WS** (gestió de missatges)  
  - **Model** (estat local derivat del servidor)

---

## Validacions mínimes

- No es pot jugar en una **columna plena**.  
- Només el **jugador amb torn** pot enviar `game.play`.  
- El servidor rebutja jugades **invàlides** i re-emet l’**estat autoritatiu**.  
- En acabar la partida, la vista 4 queda **en lectura** i es mostra la vista 5 (resultat).

---

## Important

- Fes servir el **format MVN habitual** (projecte Maven).  
- Inclou els scripts **`run.ps1`** i **`run.sh`** per compilar i executar fàcilment el client (i, si escau, el servidor).  
- Documenta al `README.md`:
  - Com **arrencar el servidor**  
  - Com **executar el client**  
  - **Ports**, variables d’entorn i dependències
