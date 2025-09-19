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

- **Tasques seqüencials** són les que s’executen una rere l’altre, fins que no s’acaba una tasca no se’n executa una altre.

- **Tasques concurrents** són les que s’executen de manera intercalada, compartint els recursos.

<center><img src="./assets/seqcon.png" style="max-width: 90%; max-height: 400px;" alt="">
<br/></center>
<br/>

## Monotasking i multitasking

Els sistemes **monotasking** o de un sol procés, són aquells que només tenen un fil d’execució, és a dir, que només poden executar un programa al mateix temps.

Actualment es poden executar diferents programes simultàniament, el què es coneix com a **multitasking**, i per tant, es poden fer programes que facin processament concurrent de dades i es poden executar diversos programes al mateix temps.

El **multitasking** es pot aconseguir de diverses maneres, per fer-ho cal la col·laboració del sistema operatiu:

- **Multiprogramming**, el propi sistema operatiu s’encarrega de decidir quin programa pot fer ús del processador, i en quina preferència

- **Multithreading**, són processadors per permeten diferents fils d’execució de manera simultània
Multiprocessor, quan hi ha dos o més processadors disponibles

## Threads

Els **threads** o *fils d’execució* són petits conjunts d’instruccions que es poden executar de manera independent del procés principal. Habitualment, de manera paral·lela al procés principal.

En **Java** hi ha diverses maneres de treballar amb *Threads*, és a dir, de definir processos que s'executen en paral·lel.

### Classe Threads (Antigament)

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
- **Exemple 0000B**: Creació professional de threads separant-los per classes

## Task i Executors

### Executor

Els **Executor** són un mecanisme de java per gestionar tasques **Tasks** (processos, fils, ...)

Els **Executor** simplifiquen l'execució dels fils posant-los en un grup anomenat **pool**, per executar-los evitant sobrecàrregues, i ofereixen diferents mètodes de funcionament: 

- Single-threaded: Només s'executa un fil de manera seqüencial

- Fixed-threaded: Només s'executa un grup fix de tasques

- Cached-threades: El grup s'ajusta de manera dinàmica segons la càrrega de treball

- Scheduled: Es programen les tasques del grup amb opcions com intervals, retards, ...

```java
ExecutorService executor = Executors.newFixedThreadPool(10);
```

**ExecutorService** és una subinterífice d'executor que proporciona funcionalitats adicionals, com enviar tasques amb resultats i tancar l'executor amb *shutdown()*

### Task

Les **Task** són unitats de treball que es poden executar en un fil. N'hi ha de dos tipus:

- **Runnable**: una tasca que no retorna cap resultat ni llença excepcions.

```java
Runnable task = () -> {
    System.out.println("Executant tasca");
};
```

- **Callable**: però pot retornar un resultat (V) i llençar excepcions.

```java
public class Main {
    public static void main(String[] args) {
        System.out.println("Main Class:");
        System.out.println("Exec args:");

        for (int i = 0; i < 10; i++) {
            final int id = i;
            Runnable task = () -> {
                System.out.println("Executant Task " + id);
            }

            Thread t = new Thread(task, "Thread-" + id);
            t.start();

            try {
                t.join(); // Espera que acabi aquest thread abans de continuar
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }
}
```

```java
Callable myCallable = new Callable();
Integer result = myCallable.call();
System.out.println(result);
```
### Relació entre Executors i Tasks

- **Executors**: Són responsables de gestionar els fils i d'assignar Tasks per a la seva execució. S'encarreguen de crear, gestionar i finalitzar els fils.

- **Tasks**: Representen el treball real que s'executarà. Són lliurades a un Executor per ser processades.

```java
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Main {
    public static void main(String[] args) {
        // Crear un executor amb un pool de 3 fils
        ExecutorService executor = Executors.newFixedThreadPool(3);

        // Crear tasques
        Runnable task1 = () -> System.out.println("Executant Task 1");
        Runnable task2 = () -> System.out.println("Executant Task 2");
        Runnable task3 = () -> System.out.println("Executant Task 3");

        // Enviar tasques a l'executor per a la seva execució
        executor.execute(task1);
        executor.execute(task2);
        executor.execute(task3);

        // Tancar l'executor
        executor.shutdown();
    }
}
```

**Nota**: A l´**"Exemple 0001"** s'executen 10 tasquen de 3 en tres en paral·lel.

## Compartir dades

Java proporciona col·leccions dissenyades per ser segures en entorns concurrents, com les implementacions de les interfícies **ConcurrentMap**, **BlockingQueue**, o **ConcurrentLinkedQueue**.

Exemple amb *ConcurrentMap*:

```java
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

public class Main {
    public static void main(String[] args) throws InterruptedException {
        ConcurrentHashMap<String, Integer> sharedData = new ConcurrentHashMap<>();
        ExecutorService executor = Executors.newFixedThreadPool(3);

        // Tasca 1: Escriu dades i triga entre 1 i 3 segons
        Runnable task1 = () -> {
            try {
                int delay = ThreadLocalRandom.current().nextInt(1, 4); // Genera un retard aleatori entre 1 i 3 segons
                TimeUnit.SECONDS.sleep(delay);
                sharedData.put("key1", 100);
                System.out.println("Tasca 1 ha escrit: 100 (trigat " + delay + " segons)");
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        };

        // Tasca 2: Modifica dades i triga entre 1 i 3 segons
        Runnable task2 = () -> {
            try {
                int delay = ThreadLocalRandom.current().nextInt(1, 4);
                TimeUnit.SECONDS.sleep(delay);
                sharedData.computeIfPresent("key1", (key, value) -> value + 100);
                System.out.println("Tasca 2 ha modificat: 200 (trigat " + delay + " segons)");
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        };

        // Tasca 3: Llegeix dades i triga entre 1 i 3 segons
        Runnable task3 = () -> {
            try {
                int delay = ThreadLocalRandom.current().nextInt(1, 4);
                TimeUnit.SECONDS.sleep(delay);
                Integer value = sharedData.get("key1");
                System.out.println("Tasca 3 ha llegit: " + value + " (trigat " + delay + " segons)");
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        };

        executor.execute(task1);
        executor.execute(task2);
        executor.execute(task3);

        executor.shutdown();
        executor.awaitTermination(10, TimeUnit.SECONDS);
    }
}
```

A l'exemple anterior:

- Es fa servir *ThreadLocalRandom.current().nextInt(1, 4)* per generar una espera entre 1 i 3 segons

- Les tres tasques (task1, task2, task3) s'executen en paral·lel perquè l'executor té un pool de 3 fils. Això significa que cadascuna de les tasques pot estar executant-se al mateix temps en diferents fils.

**Nota**: A l´**"Exemple 0002"** es fa servir el patró de disseny **TaskStrategy** per definir el codi de cada tasca a executar.

Exemple amb *BlockingQueue*:

```java
public class Main {
    private static final int POISON_PILL = -1;

    public static void main(String[] args) throws InterruptedException {
        BlockingQueue<Integer> queue = new ArrayBlockingQueue<>(10);
        ExecutorService executor = Executors.newFixedThreadPool(2);

        // Tasca 1: Produeix dades
        Runnable producer = () -> {
            try {
                for (int i = 0; i < 5; i++) {
                    queue.put(i);
                    System.out.println("Produït: " + i);
                }
                queue.put(POISON_PILL); // Afegim el "Poison Pill" per aturar el consumidor
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        };

        // Tasca 2: Consumeix dades
        Runnable consumer = () -> {
            try {
                while (true) {
                    Integer value = queue.take();
                    if (value.equals(POISON_PILL)) {
                        System.out.println("Rebut poison pill. Aturant consumidor.");
                        break; // Sortim del bucle si rebem el "Poison Pill"
                    }
                    System.out.println("Consumit: " + value);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        };

        executor.execute(producer);
        executor.execute(consumer);

        executor.shutdown();
        executor.awaitTermination(5, TimeUnit.SECONDS);
    }
}
```

A l'exemple anterior:

- Una **BlockingQueue** és una estructura de dades que permet la inserció i extracció d'elements de manera segura en entorns concurrents. Es diu "bloquejant" perquè les operacions de posar (put()) o treure (take()) poden bloquejar-se fins que hi hagi espai o elements disponibles, respectivament.

- S'utilitza una **ArrayBlockingQueue** amb una capacitat de 10 elements. Això significa que la cua pot contenir fins a 10 elements abans que una tasca que intenta afegir-hi més elements quedi bloquejada.

- Es crea un ExecutorService amb un pool de 2 fils (newFixedThreadPool(2)), que permet executar dues tasques simultàniament. Tot i que hi ha capacitat per 10.

- La tasca 1, genera dades i les afegeix a la cua 'queue'. Ho fa 5 vegades. Si la cua està plena, el mètode 'put' bloqueja la tasca fins que hi ha espai disponible. Quan vol aturar el consumidor li envia un POISON_PILL

- La tasca 2, consumeix dades de la 'queue', eliminant les que procesa. Ho fa de manera indefinida. Si la cua està buila la tasca es bloqueja amb *take()* fins que hi ha espai a la cua. Aquesta tasca acaba quan rep un POISON_PILL

- Les tasques s'executen simultàniament fins que les tasques finalitzen.

**Nota**: A l´**"Exemple 0003"** s'aplica el patró **TaskStrategy** per definir el codi de cada tasca a executar.

## Future i CompletableFuture

Un **Future** és una eina en Java que representa el resultat d'una operació que es realitzarà en el futur. És part de la biblioteca java.util.concurrent i s'utilitza principalment per treballar amb operacions asíncrones o que triguen temps en completar-se.

Quan inicies una tasca asíncrona (no sabem quan acabarà, com per exemple una crida a un servidor), el Future actua com un placeholder (una mena de promesa) per al resultat de la tasca. Aquest resultat encara no està disponible, però ho estarà en algun moment.

**CompletableFuture** permet treballar amb operacions asincròniques, executant tasques en paral·lel (de manera no bloquejant) i gestionar el resultat quan estigui disponible.

En realitat els *CompletableFuture* son una versió complexa dels *Future*, per permetre encadenar operacions i gestionar excepcions de manera més fàcil.

Els avantatges són:

- **Execució Asíncrona**: Permet executar tasques en segon pla, alliberant el fil principal per fer altres operacions.

- **Cadena d'Operacions**: Pots encadenar múltiples operacions que es realitzen de manera seqüencial o paral·lela.

- **Control de Fluxe**: Proporciona diverses maneres de gestionar errors i combinar resultats de múltiples futures.

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
        future.thenAccept(result -> System.out.println("Resultat: " + result));

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
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;

public class Main {
    public static void main(String[] args) {
        // Primer CompletableFuture: retorna un número després d'una operació asíncrona
        CompletableFuture<Integer> future1 = CompletableFuture.supplyAsync(() -> {
            System.out.println("Tasques en Future1...");
            return 10;
        });

        // Segon CompletableFuture: suma 5 al resultat del primer
        CompletableFuture<Integer> future2 = future1.thenApply(result -> {
            System.out.println("Tasques en Future2...");
            return result + 5;
        });

        // Tercer CompletableFuture: multiplica el resultat anterior per 2
        CompletableFuture<Integer> future3 = future2.thenApply(result -> {
            System.out.println("Tasques en Future3...");
            return result * 2;
        });

        // Executar el càlcul final
        try {
            Integer finalResult = future3.get(); // Bloqueja fins que finalitza
            System.out.println("Resultat final: " + finalResult);
        } catch (InterruptedException | ExecutionException e) {
            e.printStackTrace();
        }
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
