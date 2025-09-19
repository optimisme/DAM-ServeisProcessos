package com.project;

import java.util.concurrent.*;

public class Main {
    private static final int POISON_PILL = Integer.MIN_VALUE;

    public static void main(String[] args) throws InterruptedException {

        BlockingQueue<Integer> queue = new LinkedBlockingQueue<>();
        ExecutorService pool = Executors.newFixedThreadPool(2);

        // Consumer
        Runnable consumer = () -> {
            try {
                while (true) {
                    int v = queue.take(); // bloqueja fins que hi hagi element
                    if (v == POISON_PILL) {
                        System.out.println("Rebut poison pill. Aturant consumidor.");
                        break;
                    }
                    System.out.println("Consumit: " + v);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        };

        // Producer
        Runnable producer = () -> {
            try {
                for (int i = 0; i < 5; i++) {
                    queue.put(i); // primer posem a la cua
                    System.out.println("Produït: " + i);
                }
                queue.put(POISON_PILL); // senyal per aturar el consumidor
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
