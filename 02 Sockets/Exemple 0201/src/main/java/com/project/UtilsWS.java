package com.project;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

import org.java_websocket.client.WebSocketClient;
import org.java_websocket.drafts.Draft;
import org.java_websocket.drafts.Draft_6455;
import org.java_websocket.handshake.ServerHandshake;

public class UtilsWS  extends WebSocketClient {

    public static UtilsWS sharedInstance = null;
    private Consumer<String> onOpenCallBack = null;
    private Consumer<String> onMessageCallBack = null;
    private Consumer<String> onCloseCallBack = null;
    private Consumer<String> onErrorCallBack = null;
    private String location = "";
    private static AtomicBoolean exitRequested = new AtomicBoolean(false); // Thread safe

    private UtilsWS (String location, Draft draft) throws URISyntaxException {
        super (new URI(location), draft);
        this.location = location;
    }

    static public UtilsWS getSharedInstance (String location) {

        if (sharedInstance == null) {
            try {
                sharedInstance = new UtilsWS(location, (Draft) new Draft_6455());
                sharedInstance.connect();
            } catch (URISyntaxException e) { 
                e.printStackTrace(); 
                System.out.println("WS Error, " + location + " is not a valid URI");
            }
        }

        return sharedInstance;
    }

    public void onOpen (Consumer<String> callBack) {
        this.onOpenCallBack = callBack;
    }

    public void onMessage (Consumer<String> callBack) {
        this.onMessageCallBack = callBack;
    }

    public void onClose (Consumer<String> callBack) {
        this.onCloseCallBack = callBack;
    }

    public void onError (Consumer<String> callBack) {
        this.onErrorCallBack = callBack;
    }

    @Override
    public void onOpen(ServerHandshake handshake) {
        String message = "WS connected to: " + getURI();
        System.out.println(message);
        if (onOpenCallBack != null) {
            onOpenCallBack.accept(message);
        }
    }

    @Override
    public void onMessage(String message) {
        if (onMessageCallBack != null) {
            onMessageCallBack.accept(message);
        }
    }

    @Override
    public void onClose(int code, String reason, boolean remote) {
        String message = "WS closed connection from: " + getURI();
        System.out.println(message);
        if (onCloseCallBack != null) {
            onCloseCallBack.accept(message);
        }
        if (remote) {
            reconnect();
        }
    }

    @Override
    public void onError(Exception e) {
        String message = e.getMessage();
        System.out.println("WS connection error: " + message);
        if (onErrorCallBack != null) {
            onErrorCallBack.accept(message);
        }
        if (e.getMessage().contains("Connection reset")) {
            reconnect();
        }
    }

    public void safeSend(String text) {
        try {
            sharedInstance.send(text);
        } catch (Exception e) {
            System.out.println("WS Error sending message");
        }
    }

    public void reconnect () {
        if (exitRequested.get()) { return; }
    
        System.out.println("WS reconnecting to: " + this.location);

        try {
            TimeUnit.SECONDS.sleep(5);
        } catch (InterruptedException e) {
            System.out.println("WD Error, waiting");
            Thread.currentThread().interrupt();  // Assegurar que el fil es torna a interrompre correctament
        }
    
        if (exitRequested.get()) { return; }
        
        Consumer<String> oldCallBack = this.onMessageCallBack;
        String oldLocation = this.location;
        sharedInstance.close();
        sharedInstance = null;
        getSharedInstance(oldLocation);
        sharedInstance.onMessage(oldCallBack);
    }
    
    public void forceExit () {
        System.out.println("WS Closing ...");
        exitRequested.set(true);
        try {
            if (!isClosed()) {
                super.closeBlocking();
            }
        } catch (Exception e) {
            System.out.println("WS Interrupted while closing WebSocket connection");
            Thread.currentThread().interrupt();
        }
    }
}