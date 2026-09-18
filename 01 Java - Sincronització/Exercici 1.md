<div style="display: flex; width: 100%;">
    <div style="flex: 1; padding: 0px;">
        <p>© Albert Palacios Jiménez, 2024</p>
    </div>
    <div style="flex: 1; padding: 0px; text-align: right;">
        <img src="./assets/ieti.png" height="32" alt="Logo de IETI" style="max-height: 32px;">
    </div>
</div>
<br/>

# Exercici 1

Una aplicació de gestió d'aparcaments ha de controlar l'accés a un aparcament amb capacitat limitada. Els cotxes només poden entrar si hi ha espai disponible, i quan un cotxe surt, un altre pot entrar.

**Objectiu**

Implementa un sistema en Java que simuli l'entrada i sortida de cotxes en un aparcament utilitzant un semàfor per controlar la capacitat.

**Requisits**

- Crea una classe Java amb un mètode main.

- Defineix una classe ParkingLot que tingui un semàfor amb un nombre limitat de permisos (igual a la capacitat de l'aparcament).

- Defineix tasques (Runnable) que simulin l'entrada i sortida de cotxes a l'aparcament. Quan un cotxe entra, adquireix un permís, i quan surt, allibera un permís.

- Utilitza un ExecutorService amb un pool de fils per simular l'entrada i sortida de cotxes de manera concurrent.

- Mostra a la consola cada vegada que un cotxe entra o surt de l'aparcament i quan un cotxe espera perquè l'aparcament està ple.

- Assegura't de tancar l'executor al final.

**Important**: Fes servir el format MVN habitual, i no t'oblidis dels arxius 'run.ps1' i 'run.sh'