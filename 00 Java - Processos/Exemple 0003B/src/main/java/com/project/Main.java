package com.project;

import java.util.concurrent.*;

public class Main {
    private static final int POISON_PILL = -1;

    // Log segur amb timestamp per evitar entrellaçats
    public static void log(String who, String msg) {
        System.out.printf("%d [%s] %s%n", System.nanoTime(), who, msg);
    }

    public static void main(String[] args) throws InterruptedException {
        BlockingQueue<Integer> queue = new LinkedBlockingQueue<>();
        ExecutorService pool = Executors.newFixedThreadPool(2);

        // Estratègies
        TaskStrategy producer = new TaskProducer(queue, POISON_PILL, 5);
        TaskStrategy consumer = new TaskConsumer(queue, POISON_PILL);

        // Envoltem amb Task per passar el nom de fil (who)
        pool.execute(new Task(producer, "Producer"));
        pool.execute(new Task(consumer, "Consumer"));

        pool.shutdown();
        if (!pool.awaitTermination(10, TimeUnit.SECONDS)) {
            pool.shutdownNow();
        }
    }
}
