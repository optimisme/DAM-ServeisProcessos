package com.project;

import java.util.concurrent.ConcurrentHashMap;

public interface TaskStrategy {
    void execute(ConcurrentHashMap<String, Integer> sharedData) throws InterruptedException;
}
