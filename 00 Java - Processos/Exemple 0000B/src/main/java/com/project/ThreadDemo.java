package com.project;

public class ThreadDemo {
    private final String name;

    // Constructor sense arguments (compatibilitat)
    public ThreadDemo() {
        this.name = "ThreadDemo";
    }

    // Constructor amb nom
    public ThreadDemo(String name) {
        this.name = name;
    }

    public void runDemo() {
        Thread t1 = new Thread(new Task(name + " · Missatge 1"), "Thread-1");
        Thread t2 = new Thread(new Task(name + " · Missatge 2"), "Thread-2");
        Thread t3 = new Thread(new Task(name + " · Missatge 3"), "Thread-3");

        t1.start();
        t2.start();
        t3.start();

        try {
            t1.join();
            t2.join();
            t3.join();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
