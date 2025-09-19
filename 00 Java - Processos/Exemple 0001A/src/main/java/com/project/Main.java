package com.project;

public class Main {
    public static void main(String[] args) {
        System.out.println("Main Class:");
        System.out.println("Exec args:");

        for (int i = 0; i < 10; i++) {
            final int id = i;
            Runnable task = () -> {
                System.out.println("Executant Task " + id);
            };

            Thread t = new Thread(task, "Thread-" + id);
            t.start();

            try {
                t.join(); // Espera que acabi aquest thread abans de continuar
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }
}
