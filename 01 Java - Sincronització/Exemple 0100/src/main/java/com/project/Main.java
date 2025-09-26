package com.project;

import java.util.Map;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

public class Main {

    // Shared data: partial results by microservice id
    private static final ConcurrentHashMap<Integer, Integer> partials = new ConcurrentHashMap<>();
    private static final AtomicLong t0 = new AtomicLong();

    public static void main(String[] args) {
        t0.set(System.nanoTime());

        CyclicBarrier barrier = new CyclicBarrier(3, () -> {
            // Combine partials
            int total = partials.values().stream().mapToInt(Integer::intValue).sum();
            long ms = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - t0.get());
            System.out.println("Tots els microserveis han acabat. Combinant els resultats...");
            System.out.println("Parcials: " + partials);
            System.out.println("Resultat global: " + total + " (temps total: " + ms + "ms)");
        });

        ExecutorService executor = Executors.newFixedThreadPool(3);

        executor.submit(microservice(1, barrier));
        executor.submit(microservice(2, barrier));
        executor.submit(microservice(3, barrier));

        executor.shutdown();
        try { executor.awaitTermination(10, TimeUnit.SECONDS); } catch (InterruptedException ignored) {}
    }

    private static Runnable microservice(int id, CyclicBarrier barrier) {
        return () -> {
            try {
                // Pre-delay 100-500 ms
                int preDelay = ThreadLocalRandom.current().nextInt(100, 501);
                Thread.sleep(preDelay);
                System.out.println("Microservei " + id + " començarà a processar dades (espera prèvia: " + preDelay + "ms)");

                // Process delay 1000-1500 ms
                int processDelay = ThreadLocalRandom.current().nextInt(1000, 1501);
                System.out.println("Microservei " + id + " processant dades... (trigarà " + processDelay + "ms)");
                Thread.sleep(processDelay);

                // Treball d'exemple, calcular un parcial i guarda les dades a 'partials'
                int base = id * 100;
                int partial = 0;
                for (int i = base; i < base + 10; i++) partial += i; // simple deterministic load
                partials.put(id, partial);

                System.out.println("Microservei " + id + " completat. (parcial=" + partial + ")");
                barrier.await();
            } catch (InterruptedException | BrokenBarrierException e) {
                System.err.println("Error al microservei " + id + ": " + e.getMessage());
                Thread.currentThread().interrupt();
            }
        };
    }
}
