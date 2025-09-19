package com.project;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

public class TaskWrite implements TaskStrategy {
    @Override
    public void execute(ConcurrentHashMap<String, Integer> sharedData) throws InterruptedException {
        int delay = ThreadLocalRandom.current().nextInt(1, 4);
        TimeUnit.SECONDS.sleep(delay);
        sharedData.put("key1", 100);
        System.out.println("Tasca 1 ha escrit: 100 (trigat " + delay + " segons)");
    }
}
