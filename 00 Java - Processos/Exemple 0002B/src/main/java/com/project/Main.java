package com.project;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class Main {
    public static void main(String[] args) throws InterruptedException {
        ConcurrentHashMap<String, Integer> sharedData = new ConcurrentHashMap<>();
        ExecutorService executor = Executors.newFixedThreadPool(3);

        // Crear i executar les tasques amb estratègies específiques
        executor.execute(new Task(new TaskWrite(), sharedData));
        executor.execute(new Task(new TaskModify(), sharedData));
        executor.execute(new Task(new TaskRead(), sharedData));

        // Tancar l'executor
        executor.shutdown();
        executor.awaitTermination(10, TimeUnit.SECONDS);
    }
}
