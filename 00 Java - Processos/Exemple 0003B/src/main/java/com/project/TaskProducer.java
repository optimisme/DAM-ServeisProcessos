package com.project;

import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

public class TaskProducer implements TaskStrategy {
    private final BlockingQueue<Integer> queue;
    private final int poisonPill;
    private final int count;

    public TaskProducer(BlockingQueue<Integer> queue, int poisonPill, int count) {
        this.queue = queue;
        this.poisonPill = poisonPill;
        this.count = count;
    }

    @Override
    public void run(String who) throws InterruptedException {
        for (int i = 0; i < count; i++) {
            int delay = ThreadLocalRandom.current().nextInt(1, 200);
            TimeUnit.MILLISECONDS.sleep(delay);

            queue.put(i);
            Main.log(who, "Produït: " + i);
        }
        queue.put(poisonPill);
        Main.log(who, "Poison pill enviat.");
    }
}
