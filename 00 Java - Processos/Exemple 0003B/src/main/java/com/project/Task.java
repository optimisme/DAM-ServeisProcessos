package com.project;

public class Task implements Runnable {
    private final TaskStrategy strategy;
    private final String who;

    public Task(TaskStrategy strategy, String who) {
        this.strategy = strategy;
        this.who = who;
    }

    @Override
    public void run() {
        try {
            strategy.run(who);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
