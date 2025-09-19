package com.project;

import java.util.concurrent.*;

public class Main {
    private static final int POISON_PILL = -1;

    // Necessari per assegurar que els missatges no s'entrellacin
    public static void log(String who, String msg) {
        System.out.printf("%d [%s] %s%n", System.nanoTime(), who, msg);
    }

    public static void main(String[] args) throws InterruptedException {

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
}
