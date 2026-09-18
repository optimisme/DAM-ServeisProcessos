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

Un projecte de desenvolupament d'una aplicació web requereix processar les sol·licituds d'usuari de manera asíncrona per millorar la resposta del sistema i garantir una experiència fluida. Això implica que les operacions han de ser processades en cadena, passant els resultats d'una etapa a la següent, de manera no bloquejant.

**Objectiu**

Implementa una cadena de tres tasques asíncrones utilitzant CompletableFuture, on les dades es passin d'una tasca a la següent. L'objectiu és simular un procés de tractament de dades en una aplicació web, on cada tasca representa una etapa del processament d'una sol·licitud d'usuari, com ara validar les dades, calcular el resultat, i mostrar la resposta final.

**Requisits**

- Crea una classe Java amb un mètode main.

Defineix tres tasques:


- La primera tasca (supplyAsync) ha de simular la validació de les dades d'una sol·licitud, retornant un valor inicial.

- La segona tasca (thenApply) ha de processar aquestes dades, modificant-les per obtenir el resultat calculat.

- La tercera tasca (thenAccept) ha de mostrar el resultat final, simulant la resposta enviada a l'usuari.

- Utilitza CompletableFuture per encadenar les operacions, assegurant que cada etapa processa les dades de l'etapa anterior.

- Utilitza join() al final per esperar que totes les operacions asíncrones es completin abans de finalitzar el programa.

**Important**: Fes servir el format MVN habitual, i no t'oblidis dels arxius 'run.ps1' i 'run.sh'