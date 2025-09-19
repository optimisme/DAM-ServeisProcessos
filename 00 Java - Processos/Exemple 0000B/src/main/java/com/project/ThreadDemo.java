package com.project;

class ThreadDemo extends Thread {

    private String info;

    public ThreadDemo(String info) {
        this.info = info;
    }

	@Override
	public void run(){
		System.out.println( "ThreadDemo class: " + info);
	}
}