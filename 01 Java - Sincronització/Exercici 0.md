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

Una empresa vol millorar el rendiment del càlcul de la mitjana, la suma i la desviació estàndard d'un conjunt gran de dades. L'empresa ha decidit dividir el treball en tres fases paral·leles que s'han de sincronitzar abans de mostrar els resultats finals.

**Objectiu**

Implementa un sistema en Java que simuli el càlcul de la mitjana, la suma i la desviació estàndard en paral·lel. Utilitza una CyclicBarrier per assegurar que tots els càlculs han estat realitzats abans de mostrar els resultats finals.

**Requisits**

- Crea una classe Java amb un mètode main.

- Defineix tres tasques (Runnable) que facin els càlculs de la mitjana, la suma i la desviació estàndard d'un conjunt de dades.

- Utilitza una CyclicBarrier per sincronitzar les tres tasques, de manera que només es mostrin els resultats finals quan totes hagin acabat.

- Quan tots els càlculs hagin completat el seu treball, mostra els resultats finals a la consola.

- Utilitza un ExecutorService amb un pool de fils per executar les tasques en paral·lel.

- Assegura't de tancar l'executor al final.

**Important**: Fes servir el format MVN habitual, i no t'oblidis dels arxius 'run.ps1' i 'run.sh'