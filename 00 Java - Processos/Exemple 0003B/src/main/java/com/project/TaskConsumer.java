package com.project;

import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

public class TaskConsumer implements TaskStrategy {
    @Override
    public void execute(BlockingQueue<Integer> queue, int poisonPill) throws InterruptedException {
        while (true) {
            int delay = ThreadLocalRandom.current().nextInt(1, 200);
            TimeUnit.MILLISECONDS.sleep(delay);

            Integer value = queue.take();
            if (value.equals(poisonPill)) {
                System.out.println("Rebut poison pill. Aturant consumidor.");
                break;  // Sortim del bucle si rebem el "Poison Pill"
            }
            System.out.println("Consumit: " + value);
        }
    }
}
