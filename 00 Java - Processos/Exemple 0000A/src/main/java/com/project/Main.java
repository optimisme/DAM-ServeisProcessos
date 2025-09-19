package com.project;

public class Main {
    public static void main(String[] args) {
        // Informació que volem passar als threads
        String info1 = "Missatge pel Thread 1A";
        String info2 = "Missatge pel Thread 2A";
        int number = 42;

        // Thread amb lambda que rep info1
        new Thread(() -> {
            System.out.println(Thread.currentThread().getName() + " → " + info1);
        }, "Thread 1").start();

        // Thread amb lambda que rep info2 i un número
        new Thread(() -> {
            System.out.println(Thread.currentThread().getName() + " → " + info2 + " i el número " + number);
        }, "Thread 2").start();

        // Thread amb classe anònima que també fa servir informació
        new Thread() {
            @Override
            public void run() {
                System.out.println(Thread.currentThread().getName() + " → " + "Execució amb classe anònima, número *2 = " + (number * 2));
            }
        }.start();
    }
}
