package com.project;

import java.util.concurrent.BlockingQueue;

public class Task implements Runnable {
    private final TaskStrategy strategy;
    private final BlockingQueue<Integer> queue;
    private final int poisonPill;

    public Task(TaskStrategy strategy, BlockingQueue<Integer> queue, int poisonPill) {
        this.strategy = strategy;
        this.queue = queue;
        this.poisonPill = poisonPill;
    }

    @Override
    public void run() {
        try {
            strategy.execute(queue, poisonPill);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
