package com.project;

import java.util.concurrent.BlockingQueue;

public class TaskConsumer implements TaskStrategy {
    @Override
    public void execute(BlockingQueue<Integer> queue, int poisonPill) throws InterruptedException {
        while (true) {
            Integer value = queue.take();
            if (value.equals(poisonPill)) {
                System.out.println("Rebut poison pill. Aturant consumidor.");
                break;  // Sortim del bucle si rebem el "Poison Pill"
            }
            System.out.println("Consumit: " + value);
        }
    }
}
