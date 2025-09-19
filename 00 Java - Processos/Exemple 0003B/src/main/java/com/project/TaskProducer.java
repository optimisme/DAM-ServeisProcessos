package com.project;

import java.util.concurrent.BlockingQueue;

public class TaskProducer implements TaskStrategy {
    @Override
    public void execute(BlockingQueue<Integer> queue, int poisonPill) throws InterruptedException {
        for (int i = 0; i < 5; i++) {
            queue.put(i);
            System.out.println("Produït: " + i);
        }
        queue.put(poisonPill);  // Afegim el "Poison Pill" per aturar el consumidor
    }
}
