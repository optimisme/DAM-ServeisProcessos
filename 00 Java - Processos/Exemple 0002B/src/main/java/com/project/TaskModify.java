package com.project;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

public class TaskModify implements TaskStrategy {
    @Override
    public void execute(ConcurrentHashMap<String, Integer> sharedData) throws InterruptedException {
        int delay = ThreadLocalRandom.current().nextInt(1, 4);
        TimeUnit.SECONDS.sleep(delay);
        sharedData.computeIfPresent("key1", (key, value) -> value + 100);
        System.out.println("Tasca 2 ha modificat: 200 (trigat " + delay + " segons)");
    }
}
