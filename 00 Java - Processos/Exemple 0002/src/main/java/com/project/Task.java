package com.project;

import java.util.Random;
import java.util.concurrent.Callable;

public class Task implements Callable<String> {
    private static final char[] VOCALS = {'a', 'e', 'i', 'o', 'u'};
    private final int id;

    public Task(int id) {
        this.id = id;
    }

    @Override
    public String call() {
        Random rnd = new Random();
        char v = VOCALS[rnd.nextInt(VOCALS.length)];
        return "Executant Task " + id + " → Lletra aleatòria " + v;
    }
}
