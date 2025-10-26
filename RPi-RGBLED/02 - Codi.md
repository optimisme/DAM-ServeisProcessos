# Codi

El panell RGB-LED es controla amb una llibreria anomedada *"Adafruit"*, i està basada en C++.

Teniu disponible un *pont* entre Java i C++ anomenat *"piomatter-java-jni"*, que permet utilitzar la llibreria Adafruit des de Java.

```java
import com.piomatter.*;
```

La idea és generar imatges amb la llibreria **"Graphics2D"** *(canvas)** de Java, i enviar aquestes imatges al panell RGB-LED.

### Iniciar el panell:

```java
    static final int WIDTH = 64, HEIGHT = 64;
    static final int ADDR = 5;          // ABCDE (64x64)
    static final int LANES = 2;         // 2 lanes
    static final int BRIGHTNESS = 200;  // 0..255 (software)

    // 0) Open Piomatter
    var pm = new PioMatter(WIDTH, HEIGHT, ADDR, LANES, BRIGHTNESS, FPS_CAP);
    var fb = pm.mapFramebuffer(); 

    System.out.println("Config: WIDTH=" + WIDTH + ", HEIGHT=" + HEIGHT + ", LANES=" + LANES + ", BRIGHTNESS=" + BRIGHTNESS);
```

### Iniciar el canvas:

Tenint en compte que el canvas és de 64x64 píxels, desactivem l'anti-aliasing per evitar efectes no desitjats.

```java
    // 1) Create a Graphics2D canvas
        BufferedImage img = new BufferedImage(WIDTH, HEIGHT, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();

        // Prevent aliasing for “LED matrix”
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_OFF);
        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_OFF);
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_NEAREST_NEIGHBOR);
```

### Dibuix:

```java
    // Clear to black before starting
    PioMatter.flushBlack(pm, fb, 3, 15);

    g.setColor(Color.BLACK);
    g.fillRect(0, 0, WIDTH, HEIGHT);

    // Draw text "IETI"
    g.setFont(new Font("SansSerif", Font.PLAIN, 12));
    g.setColor(Color.WHITE);
    g.drawString("IETI", 5, 20);

    // White border
    g.setColor(Color.WHITE);
    g.drawRect(0, 0, WIDTH - 1, HEIGHT - 1);

    // Copy BufferedImage → framebuffer RGB888 with defined brightness
    PioMatter.copyBufferedImageToRGB888(img, fb.data, fb.strideBytes, WIDTH, HEIGHT, BRIGHTNESS);

    // Send to panel
    pm.swap();
```

### Acabar el programa:

Quan acaba l'ús, cal alliberar els recursos.

```java
    g.dispose();
    
    // Clear to black before exiting
    PioMatter.flushBlack(pm, fb, 3, 15);
    pm.close();
```

### Bucle d'animació i FPS:

La llibreria java *"piomatter-java-jni"* inclou un **"UtilsFPS"** per gestionar els frames per segon del bucle d'animació.

```java

static final int FPS_CAP = 60;
var fps = new UtilsFPS();
var running = true;
var lineY = 0.0;
var speedY = 20.0; // pixels per second

while (running) {
    fps.beginFrame();

    // Calculate speed according to FPS
    double dt = fps.getDeltaSeconds();
    if (dt <= 0) dt = 1.0 / FPS_CAP;

    // Update moving things according to dt
    lineY += speedY * dt;
    
    // FPS overlay (top-left)
    fps.drawOverlay(g, 2, 10);

    // Copy BufferedImage → framebuffer RGB888 with defined brightness
    PioMatter.copyBufferedImageToRGB888(back, fb.data, fb.strideBytes, WIDTH, HEIGHT, BRIGHTNESS);

    // Present frame
    pm.swap();

    // End frame + cap
    fps.endFrameAndCap(FPS_CAP);
}
```

### Imatges d'arxius:

La llibreria java *"piomatter-java-jni"* inclou un **"UtilsImage"** per carregar i mostrar imatges des d'arxius.

```java
// from "src/main/resources/ietilogo.png"
BufferedImage logo = UtilsImage.loadImage("ietilogo.png"); 
if (logo != null) {
    UtilsImage.drawImageFit(g, logo, 1, h2, w2, h2 - 2, UtilsImage.FitMode.CONTAIN);
}
```

### Imatges en Base64:

Al l'exemple de WebSockets, s'envien imatges en format Base64.

**Llegir la imatge i transformar-la a Base64:**

```java
/** Retorna Base64 d'una imatge (PNG/JPG/JPEG) via path o classpath */
/** per "classpath" l'arxiu ha d'estar a "src/main/resources/" */
private static String loadImageBase64(String spec) throws Exception {
    String lower = spec.toLowerCase(Locale.ROOT);
    if (lower.startsWith("classpath:")) {
        String resPath = spec.substring("classpath:".length());
        if (resPath.startsWith("/")) resPath = resPath.substring(1);
        if (!isAllowedExt(resPath)) return null;

        try (InputStream is = Thread.currentThread().getContextClassLoader().getResourceAsStream(resPath)) {
            if (is == null) return null;
            byte[] data = is.readAllBytes();
            String b64 = Base64.getEncoder().encodeToString(data);
            return b64;
        }
    } else {
        File f = new File(spec);
        if (!f.exists() || !f.isFile()) return null;

        byte[] data = Files.readAllBytes(f.toPath());
        String b64 = Base64.getEncoder().encodeToString(data);
        return b64;
    }
}
```

**Decodificar Base64 i mostrar la imatge:**

```java
try {
    byte[] data = Base64.getDecoder().decode(b64);
    BufferedImage img = ImageIO.read(new ByteArrayInputStream(data));
    if (img != null) {
        image = img;
        text = null;
        mode = Mode.IMAGE;
        System.out.println("[client] IMAGE: " + o.optString("name", "(unnamed)"));
    } else {
        System.out.println("[client] IMAGE decode failed.");
        mode = Mode.NONE;
    }
} catch (Exception e) {
    System.out.println("[client] IMAGE error: " + e.getMessage());
    mode = Mode.NONE;
}
```