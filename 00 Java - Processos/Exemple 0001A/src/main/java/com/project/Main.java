package com.project;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class Main {
    public static void main(String[] args) {

		// Crear un executor amb un pool de 3 fils
        ExecutorService executor = Executors.newFixedThreadPool(3);

        // Llista per emmagatzemar les tasques
        List<Runnable> tasks = new ArrayList<>();

        // Primer bucle: Generar tasques de 0 a 9
        for (int i = 0; i < 10; i++) {
            tasks.add(new Task(i));
        }

        // Segon bucle: Executar les tasques
        for (Runnable task : tasks) {
            executor.execute(task);
        }

        // Tancar l'executor
        executor.shutdown();
    }
}
