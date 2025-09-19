package com.project;

import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;

public class Main {

    // Necessari per assegurar que els missatges no s'entrellacin
    public static void log(String who, String msg) {
        System.out.printf("%d [%s] %s%n", System.nanoTime(), who, msg);
    }

    // Delay aleatori per intercalar l'ordre real entre fils
    public static void sleepRnd() {
        try {
            TimeUnit.MILLISECONDS.sleep(ThreadLocalRandom.current().nextInt(1, 200));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    public static void main(String[] args) throws InterruptedException {
        ExecutorService pool = Executors.newFixedThreadPool(3);

        // Estat compartit: el valor "vigent" observable per totes les tasques
        AtomicReference<Integer> box = new AtomicReference<>();
        // Senyal perquè lector i modificador comencin en paral·lel DESPRÉS d'escriure
        CountDownLatch start = new CountDownLatch(1);

        // Estratègies
        TaskStrategy write = new TaskWrite(box, start);
        TaskStrategy modify = new TaskModify(box, start);
        TaskStrategy read   = new TaskRead(box, start);

        // Runnables que apliquen l'estratègia
        pool.execute(new Task(write, "Tasca 1"));
        pool.execute(new Task(modify, "Tasca 2"));
        pool.execute(new Task(read,   "Tasca 3"));

        pool.shutdown();
        if (!pool.awaitTermination(5, TimeUnit.SECONDS)) {
            pool.shutdownNow();
        }
    }
}
