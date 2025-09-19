package com.project;

import java.util.concurrent.ConcurrentHashMap;

public class Task implements Runnable {
    private final TaskStrategy strategy;
    private final ConcurrentHashMap<String, Integer> sharedData;

    public Task(TaskStrategy strategy, ConcurrentHashMap<String, Integer> sharedData) {
        this.strategy = strategy;
        this.sharedData = sharedData;
    }

    @Override
    public void run() {
        try {
            strategy.execute(sharedData);  // Executar l'estratègia passada
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
