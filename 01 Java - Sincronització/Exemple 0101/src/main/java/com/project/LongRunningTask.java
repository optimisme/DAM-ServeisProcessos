// LongRunningTask.java
package com.project;

import java.util.concurrent.Semaphore;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.atomic.AtomicInteger;

public class LongRunningTask extends Thread {
    private final Semaphore slots;              // nombre de slots paral·lels disponibles
    private final CountDownLatch done;          // tasques pendents
    private final AtomicInteger resultHolder;   // on acumular el resultat
    private final int id;                       // id de la tasca  

    public LongRunningTask(Semaphore slots, CountDownLatch done, AtomicInteger resultHolder, int id) {
        this.slots = slots;
        this.done = done;
        this.resultHolder = resultHolder;
        this.id = id;
    }

    @Override
    public void run() {
        try {
            slots.acquire(); // esperar slot del semàfor disponible

            int pre = ThreadLocalRandom.current().nextInt(100, 501);     // 100-500ms
            Thread.sleep(pre);
            int work = ThreadLocalRandom.current().nextInt(1000, 1501);  // 1000-1500ms
            System.out.println("Task " + id + " starting after " + pre + "ms, working " + work + "ms...");
            Thread.sleep(work);

            int partial = id * 100; // calcular un parcial d'exemple
            resultHolder.addAndGet(partial); // agafa el valor actual acumulat i suma el parcial calculat
            System.out.println("Task " + id + " done. Partial=" + partial);

        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } finally {
            slots.release(); // free slot
            done.countDown(); // signal completion
        }
    }
}
