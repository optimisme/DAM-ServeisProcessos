package com.project;

class Task implements Runnable {

    private String info;

    public Task(String info) {
        this.info = info;
    }

	@Override
	public void run(){
		System.out.println ("Runnable interface:" + info);
	}
}
