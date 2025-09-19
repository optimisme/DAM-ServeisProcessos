package com.project;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicReference;

public class TaskRead implements TaskStrategy {
    private final AtomicReference<Integer> box;
    private final CountDownLatch start;

    public TaskRead(AtomicReference<Integer> box, CountDownLatch start) {
        this.box = box;
        this.start = start;
    }

    @Override
    public void run(String who) throws InterruptedException {
        start.await();            // espera que el valor inicial ja hi sigui
        Main.sleepRnd();          // competeix amb el modificador
        Integer cur = box.get();  // llegeix la versió vigent (100 o 200)
        Main.log(who, "ha llegit: " + cur);
    }
}
