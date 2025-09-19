package com.project;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

public class TaskRead implements TaskStrategy {
    @Override
    public void execute(ConcurrentHashMap<String, Integer> sharedData) throws InterruptedException {
        int delay = ThreadLocalRandom.current().nextInt(1, 4);
        TimeUnit.SECONDS.sleep(delay);
        Integer value = sharedData.get("key1");
        System.out.println("Tasca 3 ha llegit: " + value + " (trigat " + delay + " segons)");
    }
}
