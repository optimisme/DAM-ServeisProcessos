package com.project;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;

public class Main {
    public static void main(String[] args) {
        System.out.println("Main Class:");
        System.out.println("Exec args:");

        ExecutorService executor = Executors.newFixedThreadPool(4);
        List<Future<String>> futures = new ArrayList<>();

        // Crear 10 tasques
        for (int i = 0; i < 10; i++) {
            Task task = new Task(i);
            futures.add(executor.submit(task)); // retorna un Future
        }

        // Recuperar i imprimir els resultats
        for (Future<String> f : futures) {
            try {
                System.out.println(f.get()); // get() espera i retorna el String
            } catch (InterruptedException | ExecutionException e) {
                e.printStackTrace();
            }
        }

        executor.shutdown();
    }
}
