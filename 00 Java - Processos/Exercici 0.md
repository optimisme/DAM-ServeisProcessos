<div style="display: flex; width: 100%;">
    <div style="flex: 1; padding: 0px;">
        <p>© Albert Palacios Jiménez, 2024</p>
    </div>
    <div style="flex: 1; padding: 0px; text-align: right;">
        <img src="./assets/ieti.png" height="32" alt="Logo de IETI" style="max-height: 32px;">
    </div>
</div>
<br/>

# Exercici 0

Imagina que treballes en un projecte per una empresa financera que necessita processar operacions bancàries en temps real. Per millorar la capacitat de resposta del sistema, és necessari implementar un mecanisme que permeti que diferents tasques es coordinin i comparteixin dades de manera segura. Això és crucial per garantir que les operacions es processen correctament i de manera concurrent.

**Objectiu**

Implementa un sistema on tres tasques s'executen en paral·lel compartint dades mitjançant una estructura segura per a la concurrència. Almenys una de les tasques ha de ser un Callable que retorni un resultat després de processar les dades compartides. Aquest exercici simula un entorn en què diferents components del sistema financen cooperar per assegurar l'actualització i l'accés consistents a les dades crítiques.

**Requisits**

- Crea una classe Java amb un mètode main.

- Defineix una estructura de dades concurrent (com ConcurrentHashMap) per compartir informació entre les tasques.

- Defineix tres tasques:

- Una tasca (Runnable) que introdueixi les dades inicials, simulant la recepció d'una operació bancària.

- Una altra tasca (Runnable) que modifiqui aquestes dades, simulant una operació de càlcul d'interessos o comissions.

- Una tercera tasca (Callable) que llegeixi les dades modificades i retorni un resultat final, com ara el saldo actualitzat.

- Utilitza un ExecutorService amb un pool de 3 fils (newFixedThreadPool(3)).

- Recull el resultat de la tasca Callable i mostra'l a la consola, simulant la presentació del resultat final d'una operació bancària al client.

- Tanca l'executor per alliberar els recursos.

**Important**: Fes servir el format MVN habitual, i no t'oblidis dels arxius 'run.ps1' i 'run.sh'