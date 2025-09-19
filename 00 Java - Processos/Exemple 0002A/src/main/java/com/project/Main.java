package com.project;

import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;

public class Main {

    // Necessari per assegurar que els missatges no s'entrellacin
    static void log(String who, String msg) {
        System.out.printf("%d [%s] %s%n", System.nanoTime(), who, msg);
    }

    static void sleepRnd() {
        try { TimeUnit.MILLISECONDS.sleep(ThreadLocalRandom.current().nextInt(1, 200)); }
        catch (InterruptedException e) { Thread.currentThread().interrupt(); }
    }

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
}
