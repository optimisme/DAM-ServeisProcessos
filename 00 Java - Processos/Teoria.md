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
public static void main(String[] args) {
    // Informació que volem passar als threads
    String info1 = "Missatge pel Thread 1A";
    String info2 = "Missatge pel Thread 2A";
    int number = 42;

    // Thread amb lambda que rep info1
    new Thread(() -> {
        System.out.println(Thread.currentThread().getName() + " → " + info1);
    }, "Thread 1").start();

    // Thread amb lambda que rep info2 i un número
    new Thread(() -> {
        System.out.println(Thread.currentThread().getName() + " → " + info2 + " i el número " + number);
    }, "Thread 2").start();

    // Thread amb classe anònima que també fa servir informació
    new Thread() {
        @Override
        public void run() {
            System.out.println(Thread.currentThread().getName() + " → " + "Execució amb classe anònima, número *2 = " + (number * 2));
        }
    }.start();
}
```

Els exemples:

- **Exemple 0000A**: Creació senzilla de threads al Main
- **Exemple 0000B**: Creació amb classes separades

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

```java
public static void main(String[] args) {
    // Crear un executor amb un pool de 3 fils
    ExecutorService executor = Executors.newFixedThreadPool(3);

    // Llista per emmagatzemar les tasques
    List<Runnable> tasks = new ArrayList<>();

    // Primer bucle: Generar tasques de 0 a 9
    for (int i = 0; i < 10; i++) {
        tasks.add(new Task(i));
    }

    // Segon bucle: Executar les tasques
    for (Runnable task : tasks) {
        executor.execute(task);
    }

    // Tancar l'executor
    executor.shutdown();
}
```

**Exemple 0001**: Creació de tasques amb "Runnable", sense retorn de valor

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


```java
public static void main(String[] args) {
    System.out.println("Main Class:");
    System.out.println("Exec args:");

    ExecutorService executor = Executors.newFixedThreadPool(4);
    List<Future<String>> futures = new ArrayList<>();

    // Crear 10 tasques
    for (int i = 0; i < 10; i++) {
        Task task = new Task(i);
        futures.add(executor.submit(task)); // retorna un Future
    }

    // Recuperar i imprimir els resultats
    for (Future<String> f : futures) {
        try {
            System.out.println(f.get()); // get() espera i retorna el String
        } catch (InterruptedException | ExecutionException e) {
            e.printStackTrace();
        }
    }

    executor.shutdown();
}
```

**Exemple 0002**: Creació de tasques amb "Callable" i retorn de valor (un String)

### Relació entre Executors i Tasks

- **Executors**: Són responsables de gestionar els fils i d'assignar Tasks per a la seva execució. S'encarreguen de crear, gestionar i finalitzar els fils.

- **Tasks**: Representen el treball real que s'executarà. Són lliurades a un Executor per ser processades.

## Compartir dades

Java proporciona col·leccions dissenyades per ser segures en entorns concurrents, com les implementacions de les interfícies **AtomicReference**, **ConcurrentMap**, **BlockingQueue**, o **ConcurrentLinkedQueue**.

```java
public static void main(String[] args) throws InterruptedException {
    ExecutorService pool = Executors.newFixedThreadPool(3);

    AtomicReference<Integer> box = new AtomicReference<>();
    CountDownLatch start = new CountDownLatch(1); // senyal per arrencar T2 i T3 després d’escriure

    // Tasca 1: escriure valor inicial
    Runnable t1 = () -> {
        sleepRnd();
        box.set(100);                    // publica 100
        log("Tasca 1", "ha escrit: 100");
        start.countDown();               // ara poden córrer lector i modificador en paral·lel
    };

    // Tasca 2: modificar (pot córrer abans o després del lector)
    Runnable t2 = () -> {
        try {
            start.await();               // espera que ja hi hagi el valor inicial
            sleepRnd();
            box.set(200);                // publica 200
            log("Tasca 2", "ha modificat: 200");
        } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
    };

    // Tasca 3: llegir (si arriba abans de modificar → 100; si arriba després → 200)
    Runnable t3 = () -> {
        try {
            start.await();               // espera valor inicial disponible
            sleepRnd();
            Integer cur = box.get();     // llegeix l’estat actual
            log("Tasca 3", "ha llegit: " + cur);
        } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
    };

    pool.execute(t1);
    pool.execute(t2);
    pool.execute(t3);

    pool.shutdown();
    if (!pool.awaitTermination(5, TimeUnit.SECONDS)) {
        pool.shutdownNow();
    }
}
```

- **Exemple 0003A**: Compartir dades senzilla amb "AtomicReference"
- **Exemple 0003B**: Compartir dades professional segons el patró "Strategy" amb "AtomicReference"


- **Exemple 0003A**: Compartir dades senzilla amb "BlockingQueue"
- **Exemple 0003B**: Compartir dades professional segons el patró "Strategy"

### Poison Pill

**POISON_PILL** és una tècnica pel qual es passen dades, però es guarda un valor, per donar informació al fil que les processa. En aquest cas, que ha de sortir del bucle de processament perquè no hi ha més dades.

**Important!** Si hi hagués N processos consumint les dades, caldria afegir N píndoles.

```javapublic static void main(String[] args) throws InterruptedException {

    BlockingQueue<Integer> queue = new LinkedBlockingQueue<>();
    ExecutorService pool = Executors.newFixedThreadPool(2);

    // Consumer
    Runnable consumer = () -> {
        try {
            while (true) {
                int delay = ThreadLocalRandom.current().nextInt(1, 200);
                TimeUnit.MILLISECONDS.sleep(delay);

                int v = queue.take(); // bloqueja fins que hi hagi element
                if (v == POISON_PILL) {
                    log("Consumer", "Rebut poison pill. Aturant consumidor.");
                    break;
                }
                log("Consumer", "Consumit: " + v);
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    };

    // Producer
    Runnable producer = () -> {
        try {
            for (int i = 0; i < 5; i++) {
                int delay = ThreadLocalRandom.current().nextInt(1, 200);
                TimeUnit.MILLISECONDS.sleep(delay);

                queue.put(i); // primer posem a la cua
                log("Producer", "Produït: " + i);
            }
            queue.put(POISON_PILL); // senyal per aturar el consumidor
            log("Producer", "Poison pill enviat.");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    };

    pool.execute(consumer);
    pool.execute(producer);

    pool.shutdown();
    pool.awaitTermination(10, TimeUnit.SECONDS);
}
```

- **Exemple 0004A**: Compartir dades i POISON_PILL senzilla amb "BlockingQueue"
- **Exemple 0004B**: Compartir dades professional segons el patró "Strategy" i POISON_PILL

## Future i CompletableFuture

Future representa el resultat pendent d’una operació. Amb Future bàsic acostumes a bloquejar amb get() i no pots encadenar ni registrar callbacks.

**CompletableFuture** és una evolució que permet:

- Execució asíncrona sense bloqueig (supplyAsync, runAsync).
- Composició de tasques (thenApply, thenCompose, thenCombine, allOf, anyOf).
- Gestió d’errors (exceptionally, handle).
- Completar manualment (complete, completeExceptionally).
- Per defecte usa ForkJoinPool.commonPool (pots passar un Executor propi).

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

A l'exemple anterior:

- **supplyAsync()**: Executa una tasca de manera asíncrona en un altre fil, retornant un CompletableFuture.

- **thenApplyAsync()**: Defineix una acció que es realitzarà quan el CompletableFuture es completi amb un resultat.

- **join()**: Bloqueja el fil principal fins que el CompletableFuture es completa. És útil en un context com aquest per assegurar-nos que veiem el resultat abans que el programa acabi.

**CompletableFuture** és pràctic per executar accions en cadena, que no sabem quanta estona trigaràn.

- **Exemple 0005**: Encadenar processos de duració desconeguda amb "Futures"