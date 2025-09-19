package com.project;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicReference;

public class TaskWrite implements TaskStrategy {
    private final AtomicReference<Integer> box;
    private final CountDownLatch start;

    public TaskWrite(AtomicReference<Integer> box, CountDownLatch start) {
        this.box = box;
        this.start = start;
    }

    @Override
    public void run(String who) {
        Main.sleepRnd();          // simula treball abans d'escriure
        box.set(100);             // publica el valor inicial
        Main.log(who, "ha escrit: 100");
        start.countDown();        // ara poden córrer lector i modificador en paral·lel
    }
}
