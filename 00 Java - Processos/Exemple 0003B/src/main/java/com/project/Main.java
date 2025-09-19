package com.project;

import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class Main {
    private static final int POISON_PILL = -1;

    public static void main(String[] args) throws InterruptedException {
        BlockingQueue<Integer> queue = new ArrayBlockingQueue<>(10);
        ExecutorService executor = Executors.newFixedThreadPool(2);

        // Executar productor i consumidor utilitzant el patró Estratègia
        executor.execute(new Task(new TaskProducer(), queue, POISON_PILL));
        executor.execute(new Task(new TaskConsumer(), queue, POISON_PILL));

        executor.shutdown();
        executor.awaitTermination(5, TimeUnit.SECONDS);
    }
}
