package com.project;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicReference;

public class TaskModify implements TaskStrategy {
    private final AtomicReference<Integer> box;
    private final CountDownLatch start;

    public TaskModify(AtomicReference<Integer> box, CountDownLatch start) {
        this.box = box;
        this.start = start;
    }

    @Override
    public void run(String who) throws InterruptedException {
        start.await();            // espera que el valor inicial ja hi sigui
        Main.sleepRnd();          // competeix amb el lector
        box.set(200);             // publica el valor modificat
        Main.log(who, "ha modificat: 200");
    }
}
