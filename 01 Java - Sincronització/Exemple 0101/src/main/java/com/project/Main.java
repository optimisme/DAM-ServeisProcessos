// Main.java
package com.project;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Semaphore;
import java.util.concurrent.atomic.AtomicInteger;

public class Main {

    private static final int NUM_TASKS     = 8;  // tasques a llançar
    private static final int MAX_PARALLEL  = 4;  // tasques màximes en paral·lel

    public static void main(String[] args) {
        System.out.println("Llançant " + NUM_TASKS + " LongRunningTask (max paral·leles: " + MAX_PARALLEL + ")...");
        long t0 = System.currentTimeMillis();

        Semaphore slots = new Semaphore(MAX_PARALLEL); // limita parallelisme
        CountDownLatch done = new CountDownLatch(NUM_TASKS); // esperar finalització
        AtomicInteger resultHolder = new AtomicInteger(0);


        for (int i = 1; i <= NUM_TASKS; i++) {
            // Llança les tasques
            new LongRunningTask(slots, done, resultHolder, i).start();
        }

        try {
            done.await(); // espera que totes acabin
            long elapsed = System.currentTimeMillis() - t0;
            System.out.println("TOTES les tasques han acabat. Resultat acumulat: "
                    + resultHolder.get() + " (temps total: " + elapsed + "ms)");
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
