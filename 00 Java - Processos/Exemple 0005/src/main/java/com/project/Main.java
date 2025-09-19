package com.project;

import java.util.concurrent.*;

public class Main {
    public static void main(String[] args) {
        ExecutorService exec = Executors.newFixedThreadPool(2, r -> {
            Thread t = new Thread(r);
            t.setDaemon(true);     // ajuda a no retenir el JVM
            return t;
        });

        try {
            CompletableFuture<Integer> f1 =
                CompletableFuture.supplyAsync(() -> {
                    System.out.println("Tasques en Future1...");
                    return 10;
                }, exec);

            CompletableFuture<Integer> f2 = f1.thenApplyAsync(result -> {
                System.out.println("Tasques en Future2...");
                return result + 5;
            }, exec);

            CompletableFuture<Integer> f3 = f2.thenApplyAsync(result -> {
                System.out.println("Tasques en Future3...");
                return result * 2;
            }, exec);

            Integer finalResult = f3.join();   // o get()
            System.out.println("Resultat final: " + finalResult);
        } finally {
            exec.shutdown();                   // important!
        }
    }
}
