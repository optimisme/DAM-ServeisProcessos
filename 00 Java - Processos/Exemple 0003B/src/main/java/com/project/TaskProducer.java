package com.project;

import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

public class TaskProducer implements TaskStrategy {
    @Override
    public void execute(BlockingQueue<Integer> queue, int poisonPill) throws InterruptedException {
        for (int i = 0; i < 5; i++) {
            int delay = ThreadLocalRandom.current().nextInt(1, 200);
            TimeUnit.MILLISECONDS.sleep(delay);

            queue.put(i);
            System.out.println("Produït: " + i);
        }
        queue.put(poisonPill);  // Afegim el "Poison Pill" per aturar el consumidor
    }
}
