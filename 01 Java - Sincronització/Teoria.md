<div style="display: flex; width: 100%;">
    <div style="flex: 1; padding: 0px;">
        <p>© Albert Palacios Jiménez, 2024</p>
    </div>
    <div style="flex: 1; padding: 0px; text-align: right;">
        <img src="./assets/ieti.png" height="32" alt="Logo de IETI" style="max-height: 32px;">
    </div>
</div>
<br/>

# Sincronització

## CyclicBarrier

Una **CyclicBarrier** és una eina de sincronització en Java que permet que un conjunt de fils es sincronitzi entre ells en un punt específic de l'execució. El seu funcionament es basa en la idea que un conjunt de fils (threads) han de "trobar-se" en una barrera comuna abans de continuar. Quan tots els fils han arribat a la barrera, la barrera es trenca i tots els fils poden continuar la seva execució.

Això és especialment útil en situacions en què diverses tasques (threads) han de sincronitzar-se per assegurar que totes han completat una certa fase de treball abans de passar a la següent fase.

```java
import java.util.concurrent.*;

public class MicroserviceApp {

    public static void main(String[] args) {
        // Creem un CyclicBarrier per a 3 fils
        CyclicBarrier barrier = new CyclicBarrier(3, new Runnable() {
            @Override
            public void run() {
                System.out.println("Tots els microserveis han acabat. Combinant els resultats...");
            }
        });

        // Executor per gestionar els fils
        ExecutorService executor = Executors.newFixedThreadPool(3);

        // Tasques que simulen els microserveis
        Runnable microservice1 = () -> {
            try {
                System.out.println("Microservei 1 processant dades...");
                // Simulem un treball
                Thread.sleep(1000);
                System.out.println("Microservei 1 completat.");
                barrier.await(); // Esperem que els altres fils acabin
            } catch (InterruptedException | BrokenBarrierException e) {
                e.printStackTrace();
            }
        };

        Runnable microservice2 = () -> {
            try {
                System.out.println("Microservei 2 processant dades...");
                Thread.sleep(1500);
                System.out.println("Microservei 2 completat.");
                barrier.await();
            } catch (InterruptedException | BrokenBarrierException e) {
                e.printStackTrace();
            }
        };

        Runnable microservice3 = () -> {
            try {
                System.out.println("Microservei 3 processant dades...");
                Thread.sleep(2000);
                System.out.println("Microservei 3 completat.");
                barrier.await();
            } catch (InterruptedException | BrokenBarrierException e) {
                e.printStackTrace();
            }
        };

        // Executem les tasques
        executor.submit(microservice1);
        executor.submit(microservice2);
        executor.submit(microservice3);

        // Tanquem l'executor
        executor.shutdown();
    }
}
```

A l'exemple anterior:

- **CyclicBarrier**: Es crea amb un compte de 3 perquè tenim tres microserveis. A més, es passa un Runnable que s'executa un cop tots els fils arriben a la barrera.

- **ExecutorService**: Gestiona l'execució dels fils en paral·lel.

- **Tasca de cada microservei**: Cada microservei processa les dades i, en acabar, crida await() per esperar que els altres microserveis també acabin.


- **Combina els resultats**: Quan tots els microserveis han acabat, es pot executar una tasca de combinació o enviar la resposta final al client.

## Semàfors

Un semàfor és un mecanisme de sincronització àmpliament utilitzat en la programació concurrent per controlar l'accés a recursos compartits per part de múltiples fils (threads). En essència, un semàfor és una variable que ajuda a gestionar l'ús de recursos limitats per evitar condicions de carrera, bloquejos, o altres problemes de concurrència.

Tipus de semàfors:

- **Semàfor binari** (o mutex): Aquest és el tipus més simple de semàfor. Té només dos valors possibles: 0 (bloquejat) o 1 (desbloquejat). Funciona de manera similar a un "candau" que un fil pot tancar per evitar que altres fils accedeixin a un recurs mentre ell està treballant amb ell. Quan el fil acaba d'utilitzar el recurs, allibera el semàfor, permetent que un altre fil el prengui.

- **Semàfor comptador**: A diferència d'un semàfor binari, un semàfor comptador pot tenir un valor superior a 1. Això permet controlar l'accés a un conjunt de recursos, on es permet que un nombre limitat de fils accedeixin simultàniament als recursos. Cada vegada que un fil agafa un recurs, el comptador del semàfor es redueix. Quan un fil allibera el recurs, el comptador s'incrementa.

Un semàfor es pot imaginar com un comptador de permisos:

- **Inicialització**: Quan es crea un semàfor, se li assigna un valor inicial que representa el nombre de permisos disponibles.

- **Acquisició (acquire)**: Un fil que vol accedir al recurs fa una operació d'acquisició (acquire). Si el comptador del semàfor és major que zero, el fil pot accedir al recurs i el comptador es redueix en un. Si el comptador és zero, el fil queda bloquejat fins que algun altre fil alliberi un permís.
 
 - **Alliberament (release)**: Quan un fil ha acabat d'utilitzar el recurs, allibera un permís amb l'operació de release, la qual cosa incrementa el comptador del semàfor. Si hi ha altres fils esperant, un d'ells podrà accedir al recurs.

És a dir, es bloqueja l'accés al recurs quan és 0.

 ```java
import java.util.concurrent.Semaphore;

public class SemaphoreExample {

    private static final Semaphore semaphore = new Semaphore(2); // Permet màxim 2 fils alhora

    public static void main(String[] args) {
        for (int i = 1; i <= 5; i++) {
            new Worker("Fil " + i).start();
        }
    }

    static class Worker extends Thread {
        private String name;

        Worker(String name) {
            this.name = name;
        }

        @Override
        public void run() {
            try {
                System.out.println(name + " intentant adquirir semàfor...");
                semaphore.acquire(); // Acquisició del semàfor
                System.out.println(name + " ha adquirit el semàfor. Està treballant...");

                // Simulem un treball amb el recurs
                Thread.sleep(2000);

                System.out.println(name + " ha acabat. Alliberant semàfor...");
                semaphore.release(); // Alliberació del semàfor
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }
}
```

A l'exemple anterior:

- **Creació del Semàfor**: Es crea un semàfor amb 2 permisos. Això significa que un màxim de 2 fils poden accedir al recurs compartit al mateix temps.

- **Acquisició del Semàfor (acquire)**: Cada fil intenta adquirir un permís del semàfor abans d'accedir al recurs. Si el semàfor ja té 0 permisos (tots estan ocupats), el fil haurà d'esperar.

- **Alliberament del Semàfor (release)**: Després que el fil hagi acabat d'usar el recurs, allibera el semàfor, permetent que un altre fil pugui accedir al recurs.

**Nota**: L´**"Exemple 0101"** fa servir un semàfor per esperar una tasca de duració indeterminada, que s'executa en paral·lel. Normalment sería una crida a un servidor o servei del que no en sabem el temps de resposta.

## CyclicBarrier vs Semàfors

**CyclicBarrier** adequats per coordinar punts de sincronització en què un conjunt de fils ha d'arribar al mateix punt abans de continuar.

**Semàfors** són útils per controlar l'accés concurrent a recursos compartits, limitant el nombre de fils que poden accedir-hi simultàniament. Els fils no necessàriament han d'arribar a un punt específic alhora.