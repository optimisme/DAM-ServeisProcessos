package com.project;

import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

public class Task implements Runnable {
    private final String message;

    public Task(String message) {
        this.message = message;
    }

    @Override
    public void run() {
        // Delay aleatori per intercalar l'ordre
        try {
            TimeUnit.MILLISECONDS.sleep(ThreadLocalRandom.current().nextInt(1, 200));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        // Fem servir el log de Main (amb timestamps)
        Main.log(Thread.currentThread().getName(), message);
    }
}
