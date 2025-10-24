<div style="display: flex; width: 100%;">
    <div style="flex: 1; padding: 0px;">
        <p>© Albert Palacios Jiménez, 2024</p>
    </div>
    <div style="flex: 1; padding: 0px; text-align: right;">
        <img src="./assets/ieti.png" height="32" alt="Logo de IETI" style="max-height: 32px;">
    </div>
</div>
<br/>

# Recordatori Servidors

Un **servidor** és un programa (o ordinador) que **ofereix un servei** a altres programes (els clients) a través d’una xarxa.

Característiques:

- Permet comunicació a través d'un protocol (http, ws, ...)
- Respòn des de la seva adreça IP
- Està atent a un un port d'accés.

**Exemple:** un servidor web escolta a ws://192.168.1.10:80

# Sockets

Els sockets permeten enviar i rebre dades entre un client i un servidor, de manera que dues aplicacions es comuniquin entre elles a través d’una xarxa (com internet o una xarxa local).

- **Servidor**: Obre un socket en un port específic i esperarà a que un client es connecti. Una vegada connectat, pot rebre missatges i enviar respostes.

- **Client**: Es connecta a un servidor a través del socket (utilitzant l'adreça IP i el port). Un cop connectat, pot enviar missatges i rebre respostes del servidor.

Exemple de servidor:
```java
import java.io.*;
import java.net.*;

public class Servidor {
    public static void main(String[] args) {
        try {
            // Crear socket del servidor en el port 12345
            ServerSocket servidorSocket = new ServerSocket(12345);
            System.out.println("Servidor esperant connexions...");

            // Acceptar connexió del client
            Socket socket = servidorSocket.accept();
            System.out.println("Client connectat!");

            // Crear fluxos per llegir i escriure dades
            BufferedReader input = new BufferedReader(new InputStreamReader(socket.getInputStream()));
            PrintWriter output = new PrintWriter(socket.getOutputStream(), true);

            // Llegir missatge del client
            String missatgeClient = input.readLine();
            System.out.println("Missatge del client: " + missatgeClient);

            // Respondre al client
            output.println("Hola des del servidor!");

            // Tancar connexions
            input.close();
            output.close();
            socket.close();
            servidorSocket.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
```

Exemple de client:
```java
import java.io.*;
import java.net.*;

public class Client {
    public static void main(String[] args) {
        try {
            // Connectar al servidor a l'adreça localhost i port 12345
            Socket socket = new Socket("localhost", 12345);

            // Crear fluxos per llegir i escriure dades
            BufferedReader input = new BufferedReader(new InputStreamReader(socket.getInputStream()));
            PrintWriter output = new PrintWriter(socket.getOutputStream(), true);

            // Enviar missatge al servidor
            output.println("Hola des del client!");

            // Llegir resposta del servidor
            String respostaServidor = input.readLine();
            System.out.println("Resposta del servidor: " + respostaServidor);

            // Tancar connexions
            input.close();
            output.close();
            socket.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
```

Explicació:

- **Servidor**: Obre un socket al port 12345 i espera que un client es connecti.

    Quan el client es connecta, llegeix un missatge i envia una resposta.

- **Client**: Es connecta al servidor (en aquest cas, a localhost al port 12345).

    Envia un missatge al servidor i espera una resposta.

Per fer anar l´ **"Exemple 0200"**  cal obrir dues consoles, cada una amb les crides:

- ./run.sh com.server.Main
- ./run.sh com.client.Main

(o l'equivalent .ps1)

## Programació amb Sockets

Els **sockets** són una de les formes més bàsiques de comunicació en xarxa. Quan treballes directament amb sockets (sobretot en nivells baixos), estàs gestionant aspectes molt tècnics com:

- **Connexions persistents**: Cada vegada que un client es connecta al servidor, cal gestionar aquesta connexió de forma explícita. Mantenir una connexió oberta pot ser complex, sobretot si hi ha múltiples clients.

- **Control de flux de dades**: La comunicació per sockets utilitza fluxos de dades (streams), i sovint cal gestionar la codificació, decodificació, talls de dades, etc., per assegurar-te que tant el client com el servidor entenguin els missatges correctament.

- **Maneig d'errors i interrupcions**: Les xarxes poden fallar en qualsevol moment. Per tant, cal implementar mecàniques per manejar errors, connexions caigudes, intents de reconnexió, i altres problemes.

- **Bloqueig d'operacions**: Els sockets poden ser "bloquejants", la qual cosa significa que una operació de lectura o escriptura pot bloquejar el programa si no hi ha dades disponibles o si el servidor no respon immediatament.

- **Especificitat del protocol**: Quan treballes amb sockets, estàs a un nivell baix de la pila de xarxes i sovint has de crear les teves pròpies convencions per a l'enviament de dades, incloent com s'inicia i finalitza un missatge, com es fa la gestió de connexions, etc.

Tot això fa que treballar amb sockets directament sigui una tasca més complicada i "farragosa", sobretot quan es requereix desenvolupar aplicacions robustes i escalables.

## WebSockets

**WebSockets** són un protocol estàndard que facilita la comunicació bidireccional en temps real entre un client (per exemple, un navegador web) i un servidor. Es construeixen sobre HTTP però després d'establir la connexió, es comporten com sockets "tradicionals" amb diversos avantatges integrats:

- **Protocol estàndard**: Amb WebSockets, tant la connexió com el format de missatges estan definits per un estàndard. Això estalvia la necessitat de definir i gestionar a mà com es comuniquen el client i el servidor.

- **Connexió persistent**: WebSockets mantenen una connexió persistent oberta, evitant la necessitat de crear una connexió nova per cada interacció. Això és ideal per a aplicacions en temps real com xats, jocs en línia o actualitzacions en viu de dades.

- **Maneig de connexions i desconnexions**: El protocol WebSocket integra un mecanisme per establir, mantenir i tancar connexions, reduint la càrrega del desenvolupador de gestionar aquests processos manualment.

- **Bidireccionalitat**: A diferència de HTTP, que és orientat a petició-resposta, WebSockets permeten una comunicació bidireccional en temps real. Tant el client com el servidor poden enviar missatges en qualsevol moment, sense esperar una petició.

- **Optimització d'ample de banda**: WebSockets redueixen l'overhead associat a les comunicacions, ja que només hi ha una negociació HTTP inicial i després tota la comunicació es realitza en un canal obert. Això millora l'eficiència respecte a solucions com llarg polling amb HTTP.

- **Suport natiu en navegadors**: WebSockets són compatibles amb la majoria de navegadors moderns, cosa que fa que siguin fàcils d'implementar per a aplicacions web que es comuniquen amb servidors (també servidors Java).

Si bé els sockets poden proporcionar un gran control sobre la comunicació en xarxa, la seva complexitat i els requisits de gestió poden fer que siguin poc adequats per a moltes aplicacions modernes. En canvi, WebSockets ofereixen un protocol estàndard, més simple i eficient per a la comunicació bidireccional en temps real, amb avantatges significatius en termes d'escalabilitat, facilitat d'ús i optimització d'ample de banda.

### WebSockets, connexió

**Servidor**

S'ha de definir el servidor com a classe heredada de *WebSocketServer*
```java
public class Server extends WebSocketServer
```

Com en tots els Clients/Servidors la connexió e fa a partir d'una IP i un Port
```java
    int port = 3000; // Ajusta si el teu servidor s'executa en un port diferent
    Server server = new Server(new InetSocketAddress(port));
    server.start();
```

El servidor es queda a l'espera de rebre connexions i missatges dels clients, això ho fa sobreescribint les funcions:

- **onOpen**: Quan un client obre una nova connexió
- **onClose**: Quan un client tanca la connexió
- **onMessage**: Quan un client envia un missatge
- **onError**: Quan es produeix un error

Hi ha diferents tipus de missatges:

- **privat**: S'envia un missatge a un client específic
- **broadcast**: S'envia un missatge a tots els clients
- **bounce**: El missatge es rebota al client que l'ha enviat

**Clients**

Pel què fa als clients, han d'heretar de la classe *WebSocketClient*

```java
public class ClientCMD extends WebSocketClient
```

El client ha de dir a quin servidor es vol connectar a través de la IP i port del servidor.
```java
    int port = 3000; 
    Server server = new Server(new InetSocketAddress(port));
    server.start();
```

Els clients també han de sobreescriure les funcions:

- **onOpen**: Quan s'aconsegueix connectar amb el servidor
- **onMessage**: Quan es rep un missatge des del servidor
- **onClose**: Quan es tanca la connexió amb el servidor
- **onError**: Quan es produeix un error

Es poden obrir diverses finestres de ClientFX o ClientCMD per fer una conversa en grup

**UtilsWS**

Per simplificar el funcionament dels WebSockets la classe *UtilsWS* ajuda a fer la gestió amb el servidor. Per fer-la anar:

```java
// Crear un client de UtilsWS
private UtilsWS wsClient = UtilsWS.getSharedInstance(serverUri);

// Definir l'acció quan es rep un missatge remot
wsClient.onMessage(this::handleMessage);

private void handleMessage(String message) {
    JSONObject msgObj = new JSONObject(message);
    String type = msgObj.getString("type");

    switch (type) {
        // Actuar segons el tipus de missatge rebut
    }
}

// Per enviar missatges:
JSONObject obj = new JSONObject();
obj.put("type", "private");
obj.put("destination", destination);
obj.put("message", message);
wsClient.safeSend(obj.toString());
```

**Nota**: Per ajudar amb la gestió dels missatges, s'envien cadenes de text en format JSON a través dels *WebSockets*

Per fer anar l´**"Exemple 0201"** cal obrir diverses consoles, cada una amb les crides:

- ./run.sh com.server.Main
- ./run.sh com.clientFX.Main
- ./run.sh com.clientCMD.Main

(o l'equivalent .ps1)


<video width="100%" controls allowfullscreen>
  <source src="./assets/ex0201.mov" type="video/mp4">
</video>