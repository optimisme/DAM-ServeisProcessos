package com.project;

import java.util.concurrent.*;

public class Main {

    public static void main(String[] args) throws InterruptedException {
        System.out.println("Main Class:");
        System.out.println("Exec args:");

        // Cua amb capacitat 1 per passar el valor entre tasques
        BlockingQueue<Integer> bus = new ArrayBlockingQueue<>(1);

        // Pool fix (pots posar 3)
        ExecutorService pool = Executors.newFixedThreadPool(3);

        // Tasca 1: escriure 100 (producer)
        Runnable writeTask = () -> {
            try {
                bus.put(100); // bloqueja fins que el valor es consumeix si la cua és plena
                System.out.println("Tasca 1 ha escrit: 100");
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        };

        // Tasca 2: modificar (consumeix 100 i publica 200)
        Runnable modifyTask = () -> {
            try {
                Integer cur = bus.take();      // espera fins tenir el 100
                int modified = 200;            // lògica de modificació
                bus.put(modified);             // publica 200
                System.out.println("Tasca 2 ha modificat: " + modified);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        };

        // Tasca 3: llegir (consumer final)
        Runnable readTask = () -> {
            try {
                Integer cur = bus.take();      // espera fins tenir el 200
                System.out.println("Tasca 3 ha llegit: " + cur);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        };

        // Envia les 3 tasques (en qualsevol ordre; la cua ja coordina)
        pool.execute(writeTask);
        pool.execute(modifyTask);
        pool.execute(readTask);

        pool.shutdown();
        pool.awaitTermination(10, TimeUnit.SECONDS);
    }
}
