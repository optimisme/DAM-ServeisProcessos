package com.project;

import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

public class TaskConsumer implements TaskStrategy {
    private final BlockingQueue<Integer> queue;
    private final int poisonPill;

    public TaskConsumer(BlockingQueue<Integer> queue, int poisonPill) {
        this.queue = queue;
        this.poisonPill = poisonPill;
    }

    @Override
    public void run(String who) throws InterruptedException {
        while (true) {
            int delay = ThreadLocalRandom.current().nextInt(1, 200);
            TimeUnit.MILLISECONDS.sleep(delay);

            int v = queue.take();
            if (v == poisonPill) {
                Main.log(who, "Rebut poison pill. Aturant consumidor.");
                break;
            }
            Main.log(who, "Consumit: " + v);
        }
    }
}
