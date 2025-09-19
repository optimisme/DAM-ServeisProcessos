package com.project;

public interface TaskStrategy {
    void run(String who) throws InterruptedException;
}
