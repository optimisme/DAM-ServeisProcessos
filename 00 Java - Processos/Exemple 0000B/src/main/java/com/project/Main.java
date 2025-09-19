package com.project;

import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

public class Main {
    // Log amb nanoTime per veure l'ordre real d'execució
    public static void log(String who, String msg) {
        System.out.printf("%d [%s] %s%n", System.nanoTime(), who, msg);
    }

    public static void main(String[] args) {
        System.out.println("Main Class: com.project.Main");
        System.out.println("Exec args: com.project.Main");

        // ThreadDemo amb nom (tenim constructor amb i sense paràmetres)
        ThreadDemo demo = new ThreadDemo("Demo");
        demo.runDemo();
    }
}
