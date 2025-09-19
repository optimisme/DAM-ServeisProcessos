<div style="display: flex; width: 100%;">
    <div style="flex: 1; padding: 0px;">
        <p>© Albert Palacios Jiménez, 2024</p>
    </div>
    <div style="flex: 1; padding: 0px; text-align: right;">
        <img src="./assets/ieti.png" height="32" alt="Logo de IETI" style="max-height: 32px;">
    </div>
</div>
<br/>

# Threads i Futures

## Processament

Les màquines executen instruccions de codi les unes rere les altres, aquestes instruccions fan ús dels recursos de la màquina, habitualment la memòria (registres, …)

```assembly
1 Load r1, X
2 Load r2, Y
3 Mult r2, r4, r1
4 Load r4, A
5 Mult r2, r4, r1
6 Add r5, r2, r4
7 Mult r1, r2, r5 
```

- **Tasques seqüencials** són les que s’executen una rere l’altra, fins que no s’acaba una tasca no se’n executa altra.

- **Tasques concurrents** són les que s’executen de manera intercalada, compartint els recursos.

<center><img src="./assets/seqcon.png" style="max-width: 90%; max-height: 400px;" alt="">
<br/></center>
<br/>

## Monotasking i multitasking

Els sistemes **monotasking** o d'un sol procés, són aquells que només tenen un fil d’execució, és a dir, que només poden executar un programa al mateix temps.

Actualment es poden executar diferents programes simultàniament, el què es coneix com a **multitasking**, i per tant, es poden fer programes que facin processament concurrent de dades i es poden executar diversos programes al mateix temps.

El **multitasking** es pot aconseguir de diverses maneres, per fer-ho cal la col·laboració del sistema operatiu:

- **Multiprogramming**, el propi sistema operatiu s’encarrega de decidir quin programa pot fer ús del processador, i en quina preferència

- **Multithreading**, són processadors per permeten diferents fils d’execució de manera simultània
Multiprocessor, quan hi ha dos o més processadors disponibles

## Threads

Els **threads** o *fils d’execució* són petits conjunts d’instruccions que es poden executar de manera independent del procés principal. Habitualment, de manera paral·lela al procés principal.

En **Java** hi ha diverses maneres de treballar amb *Threads*, és a dir, de definir processos que s'executen en paral·lel.

### Classe Thread (Antigament)

Antigament els Threads es feien amb la classe Threads.

Encara es poden fer així, i ho podeu trobar en alguna aplicació d’empresa.

Però per motius de gestió de recursos i llegibilitat del codi ja no és recomanable.

```java
package com.project;

public class Main {
    public static void main(String[] args) {
        // Amb lambda (Runnable és una interfície funcional)
        new Thread(() -> {
            // Codi que executa el thread 1
            System.out.println("Codi interface 1");
        }, "Thread 1").start();

        new Thread(() -> {
            // Codi que executa el thread 2
            System.out.println("Codi interface 2");
        }, "Thread 2").start();

        // Amb classe anònima que esten Thread
        new Thread() {
            @Override
            public void run() {
                System.out.println("Thread class - anònima");
            }
        }.start();
    }
}
```

Els exemples:

- **Exemple 0000A**: Creació senzilla de threads al Main
- **Exemple 0000B**: Creació professional segons el patró "Strategy"

## Task i Executors

### Executor

Els **Executor** són un mecanisme de java per gestionar tasques **Tasks** (processos, fils, ...)

Els **Executor** simplifiquen l'execució dels fils posant-los en un grup anomenat **pool**, per executar-los evitant sobrecàrregues, i ofereixen diferents mètodes de funcionament: 

- Single-threaded: Només s'executa un fil de manera seqüencial

- Fixed thread pool: Només s'executa un grup fix de tasques

- Cached thread pool: El grup s'ajusta de manera dinàmica segons la càrrega de treball

- Scheduled: Es programen les tasques del grup amb opcions com intervals, retards, ...

```java
ExecutorService executor = Executors.newFixedThreadPool(10);
```

**ExecutorService** és una subinterfície d'executor que proporciona funcionalitats adicionals, com enviar tasques amb resultats i tancar l'executor amb *shutdown()*

### Task

Les **Task** són unitats de treball que es poden executar en un fil. N'hi ha de dos tipus:

- **Runnable**: una tasca que no retorna cap resultat ni llença excepcions.

```java
class Task implements Runnable {
    private final int taskId;

    public Task(int taskId) {
        this.taskId = taskId;
    }

    @Override
    public void run() {
        System.out.println("Executant Task " + taskId);
    }
}
```

**Exemple 0001A**: Creació de tasques amb "Runnable", sense retorn de valor


```java
public class Task implements Callable<String> {
    private static final char[] VOCALS = {'a', 'e', 'i', 'o', 'u'};
    private final int id;

    public Task(int id) {
        this.id = id;
    }

    @Override
    public String call() {
        Random rnd = new Random();
        char v = VOCALS[rnd.nextInt(VOCALS.length)];
        return "Executant Task " + id + " → Lletra aleatòria " + v;
    }
}
```

**Exemple 0001B**: Creació de tasques amb "Callable" i retorn de valor (un String)

### Relació entre Executors i Tasks

- **Executors**: Són responsables de gestionar els fils i d'assignar Tasks per a la seva execució. S'encarreguen de crear, gestionar i finalitzar els fils.

- **Tasks**: Representen el treball real que s'executarà. Són lliurades a un Executor per ser processades.

## Compartir dades

Java proporciona col·leccions dissenyades per ser segures en entorns concurrents, com les implementacions de les interfícies **ConcurrentMap**, **BlockingQueue**, o **ConcurrentLinkedQueue**.

**Important!** Si hi hagués N processos consumint les dades, caldria afegir N píndoles.

- **Exemple 0002A**: Compartir dades senzilla amb "BlockingQueue"
- **Exemple 0002B**: Compartir dades professional segons el patró "Strategy"

**POISON_PILL** és una tècnica pel qual es passen dades, però es guarda un valor, per donar informació al fil que les processa. En aquest cas, que ha de sortir del bucle de processament perquè no hi ha més dades.

- **Exemple 0003A**: Compartir dades i POISON_PILL senzilla amb "BlockingQueue"
- **Exemple 0002B**: Compartir dades professional segons el patró "Strategy" i POISON_PILL

## Future i CompletableFuture

Future representa el resultat pendent d’una operació. Amb Future bàsic acostumes a bloquejar amb get() i no pots encadenar ni registrar callbacks.

**CompletableFuture** és una evolució que permet:

- Execució asíncrona sense bloqueig (supplyAsync, runAsync).
- Composició de tasques (thenApply, thenCompose, thenCombine, allOf, anyOf).
- Gestió d’errors (exceptionally, handle).
- Completar manualment (complete, completeExceptionally).
- Per defecte usa ForkJoinPool.commonPool (pots passar un Executor propi).

```java
import java.util.concurrent.CompletableFuture;

public class CompletableFutureExample {
    public static void main(String[] args) {
        // Crear un CompletableFuture que es completa amb un valor
        CompletableFuture<String> future = CompletableFuture.supplyAsync(() -> {
            // Simular una tasca pesada
            // amb una espera d'un segon
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
            return "Hola, món!";
        });

        // Definir què fer quan la tasca es completa
        future.thenAccept(result -> {
            System.out.println("Resultat: " + result)
        });

        // Esperar a que es completi la tasca abans de tancar el programa
        future.join();
    }
}
```

A l'exemple anterior:

- **supplyAsync()**: Executa una tasca de manera asíncrona en un altre fil, retornant un CompletableFuture.

- **thenAccept()**: Defineix una acció que es realitzarà quan el CompletableFuture es completi amb un resultat.

- **join()**: Bloqueja el fil principal fins que el CompletableFuture es completa. És útil en un context com aquest per assegurar-nos que veiem el resultat abans que el programa acabi.

### Accions en cadena

**CompletableFuture** és pràctic per executar accions en cadena, que no sabem quanta estona trigaràn:

```java
public static void main(String[] args) {
    ExecutorService exec = Executors.newFixedThreadPool(2, r -> {
        Thread t = new Thread(r);
        t.setDaemon(true);     // ajuda a no retenir el JVM
        return t;
    });

    try {
        CompletableFuture<Integer> f1 =
            CompletableFuture.supplyAsync(() -> {
                System.out.println("Tasques en Future1...");
                return 10;
            }, exec);

        CompletableFuture<Integer> f2 = f1.thenApplyAsync(result -> {
            System.out.println("Tasques en Future2...");
            return result + 5;
        }, exec);

        CompletableFuture<Integer> f3 = f2.thenApplyAsync(result -> {
            System.out.println("Tasques en Future3...");
            return result * 2;
        }, exec);

        Integer finalResult = f3.join();   // o get()
        System.out.println("Resultat final: " + finalResult);
    } finally {
        exec.shutdown();                   // important!
    }
}
```

Sortida del codi

```bash
Tasques en Future1...
Tasques en Future2...
Tasques en Future3...
Resultat final: 30
```

A l'exemple anterior:

- **CompletableFuture.supplyAsync()**: Crea el primer CompletableFuture (future1), que fa una operació asíncrona i retorna un valor (10).

- **thenApply()**: El segon CompletableFuture (future2) s'executa després que el primer es completa. Agafa el resultat del primer (10) i hi suma 5, donant 15.

- **Un altre thenApply()**: El tercer CompletableFuture (future3) s'executa després que el segon es completa. Agafa el resultat del segon (15) i el multiplica per 2, donant 30.

- **get()**: Espera a que el tercer CompletableFuture es completi i retorna el resultat final (30).
