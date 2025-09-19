# Exercici 0

**Introducció a WebSockets**

En aquesta pràctica implementarem un sistema compartit on diversos clients poden modificar un **comptador global** en temps real. A més, el servidor guardarà les estadístiques de quantes vegades cada client ha premut els botons.

---

## Objectiu

Crear un **servidor WebSocket** que gestioni un **comptador global compartit** i un registre d’ús per cada client, i uns **clients JavaFX** que permetin incrementar o decrementar aquest comptador.

---

## Requisits

1. **Servidor**
   - Manté un **valor global** del comptador (per exemple, inicialment 0).
   - Rep peticions dels clients amb les accions:
     - `+1` → incrementar el comptador.
     - `-1` → decrementar el comptador.
   - Actualitza el comptador i envia el nou valor a **tots els clients connectats**.
   - Manté un **registre de participació** amb el nombre de clics de cada client:
     - Identificat pel nom d’usuari o ID que envia el client en connectar-se.
     - Exemple:  
       ```
       { "Anna": 5, "Marc": 2, "Joan": 7 }
       ```
   - En cada actualització, el servidor envia també l’estat complet:  
     - Valor actual del comptador.  
     - Estadístiques d’ús de tots els clients.

2. **Client (JavaFX)**
   - En iniciar-se, demana el **nom d’usuari**.
   - Mostra:
     - El **valor actual del comptador** (sincronitzat amb el servidor).
     - Dos botons: **“+1”** i **“-1”**.
     - Una llista amb les **estadístiques** de quants clics ha fet cada client.
   - Quan es prem un botó:
     - El client envia un missatge al servidor amb l’acció i el nom d’usuari.
   - Quan es rep una actualització del servidor:
     - Es mostra el nou valor del comptador.
     - Es mostra la llista actualitzada d’estadístiques.

3. **Protocol de missatges (JSON)**
   - Petició del client:
     ```json
     {
       "type": "action",
       "user": "Anna",
       "delta": +1
     }
     ```
   - Resposta del servidor (a tots els clients):
     ```json
     {
       "type": "state",
       "counter": 12,
       "stats": {
         "Anna": 5,
         "Marc": 2,
         "Joan": 7
       }
     }
     ```

---

## Funcionament esperat

1. Es llança el **servidor** en una consola.
2. S’obren un o més **clients JavaFX**.
3. Quan un client prem **“+1”** o **“-1”**:
   - El servidor rep l’acció i actualitza el valor.
   - El servidor incrementa el comptador individual d’aquell client.
   - El servidor envia el nou estat global a **tots els clients**.
4. Tots els clients mostren:
   - El valor del comptador actualitzat.
   - Les estadístiques d’ús de cada client.

---

## Extensió opcional

- Afegir un **reset** del comptador (només permès a un usuari “admin”).
- Afegir un **ranking** ordenat per qui ha premut més cops.
- Mostrar un petit **gràfic de barres** amb els clics de cada client (amb JavaFX).

---

## Notes

- El **servidor** és l’únic que manté l’estat real del joc (comptador i estadístiques).  
- Els **clients** només mostren l’estat rebut i envien accions.  
- El projecte s’ha d’estructurar amb **Maven** i incloure els scripts `run.sh` i `run.ps1`.  
