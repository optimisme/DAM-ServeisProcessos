package com.project;

import java.util.concurrent.BlockingQueue;

public interface TaskStrategy {
    void execute(BlockingQueue<Integer> queue, int poisonPill) throws InterruptedException;
}
