<div style="display: flex; width: 100%;">
    <div style="flex: 1; padding: 0px;">
        <p>© Albert Palacios Jiménez, 2024</p>
    </div>
    <div style="flex: 1; padding: 0px; text-align: right;">
        <img src="./assets/ieti.png" height="32" alt="Logo de IETI" style="max-height: 32px;">
    </div>
</div>
<br/>

# Express

**[Express](https://expressjs.com/)** és un framework que permet crear aplicaions web i APIs sobre **Node.js**

<center><img src="./assets/logo-nodejs.png" style="max-width: 90%; max-height: 200px;" alt="">
<br/></center>
<br/>

## Nou projecte amb Express

Per crear un nou projecte:
```bash
mkdir exemple2
cd exemple2
npm init -y
```

Un cop creat el projecte apareix l'arxiu **"package.json"** que defineix la configruació del projecte.

Per afegir llibreries (dependències) al projecte:
```bash
npm install express
npm install pm2
```

- **Express** és el framework que simplifica crear APIs amb Node.js
- **[PM2](https://pm2.keymetrics.io/)** permet vigilar el funcionament del servidor en entorns de producció.

# Dins del projecte, crear el servidor

Enlloc de fer servir **index.js**, farem un arxiu **./server/app.js** que tindrà el codi principal del servidor:

```bash
mkdir server
touch ./server/app.js
```

A l'arxiu **"./server/app.js"** posar-hi:
```javascript
const express = require('express')
const app = express()
const port = 3000

// Continguts estàtics (carpeta public)
app.use(express.static('public'))

// Configurar direcció ‘/’ 
app.get('/', getHello)
    async function getHello (req, res) {
    res.send(`Hello World`)
}

// Activar el servidor
const httpServer = app.listen(port, appListen)
function appListen () {
    console.log(`Example app listening on: http://0.0.0.0:${port}`)
}

// Aturar el servidor correctament 
process.on('SIGTERM', shutDown);
process.on('SIGINT', shutDown);
function shutDown() {
    console.log('Received kill signal, shutting down gracefully');
    httpServer.close()
    process.exit(0);
}
```

A l'arxiu **"./package.json"** posar l'apartat **scripts** així:
```json
  "scripts": {
    "dev": "node --watch --watch-path ./server ./server/app.js",
    "pm2start": "pm2 start ./server/app.js",
    "pm2list": "pm2 list",
    "pm2stop": "pm2 delete app"
  },
```

L'arxiu **"package.json"** té les configuracions i dependències del nostre projecte.

L'eina **"npm"** s'encarrega d'actualitzar l'arxiu automàticament pel què fa les dependències quan fem **"npm install ??"**, però les configuracions **"scripts"** les hem d'editar nosaltres *manualment*

> **Nota**:
>
> **npm** crea automàticament la carpeta *"node_modules"* que és específica del nostre ordinador, quan compartim el nostre projecte a un altre equip o servidor ho hem de fer sense aquesta carpeta, i al nou equip la instrucció **"npm install"** la tornarà a crear descarregant les llibreries binàries específiques d'aquell equip.

**Desenvolupament**:

Quan estem desenvolupant, es fa anar el servidor amb:
```bash
node --run dev
```

**Nota**: Amb la configuració de *package.json* i el mode *dev* quan es fan canvis als arxius de la carpeta *./server* el servidor es reinicia automàticament.

**Producció (Proxmox)**:

A producció (Proxmox) el servidor funcionarà amb:
```bash
node --run pm2start
```

A producció (Proxmox) tindrem comandes per llistar o aturar el servidor:
```bash
node --run pm2list
node --run pm2stop
```

**Nota**: Amb la configuració de *package.json* i la llibreria *pm2*, quan el servidor s'atura o es penja, es renicia automàticament.

**Important**: Per simplificar la gestió amb proxmox, a la carpeta **./proxmox** hi ha scripts que empaqueten el codi i l'envien al servidor remot.

## Instal·lar dependències (d'un projecte existent)

Un projecte que ja té les llibreries (dependències) definides al **package.json**, pot instal·lar-les fàcilment amb:

```bash
npm install
```

**Nota**: Les llibreries s'instal·len a la carpeta **node_modules**

Per afegir llibreries (dependències) a un projecte només cal fer:
```bash
npm install express
```

I automàticament s'afegeix a l'arxiu **.package.json** com a llibreria necessària (dependència)

Hi ha moltes llibreries disponibles, a [npm.com](https://www.npmjs.com/)

**Nota**: Cal recordar que les llibreries (dependències) són arxius binaris, aquests arxius depenen de cada sistema i processador. Per aquest motiu no cal copiar la carpeta *node_modules*, el més pràctic és copiar el projecte sense aquesta carpeta (que ocupa molt espai), i a l'equip on es vol fer anar el projecte fer un *npm install*

## Validar el servidor local (cmd)

Amb el servidor funcionant, per comprovar que s'hi poden fer consultes:
```bash
curl http://0.0.0.0:3000
```

Ha de mostrar: **"Hello World"**, que és la resposta a la única URL configurada *"/"*

## Validar el servidor local (navegador)

Amb el servidor funcionant, per comprovar que s'hi poden fer consultes. 

Anar amb el navegador a [http://0.0.0.0:3000](http://0.0.0.0:3000)

S'ha de veure una pàgina web amb **"Hello World"**

Anar amb el navegador a [http://localhost:3000/web.html](http://localhost:3000/web.html)

S'ha de veure una pàgina web amb
**"Hello Web HTML"**

## Proxmox remot

Connectar al proxmox remot:
```bash
ssh -i id_rsa -p 20127 nomUsuari@ieticloudpro.ieti.cat
```

Cal instal·lar NodeJS al proxmox remot, i també 'unzip':
```bash
sudo apt install npm
sudo npm cache clean -f
sudo npm install -g n
sudo n latest
```

## Validar el servidor remot (cmd)

Amb el servidor funcionant, per comprovar que s'hi poden fer consultes:
```bash
cd proxmox
./proxmoxRun.ps1
curl https://nomUsuari.ieti.site/
```

## Validar el servidor remot (navegador)

Amb el servidor funcionant, per comprovar que s'hi poden fer consultes. 

Anar amb el navegador a [https://nomUsuari.ieti.site/](https://nomUsuari.ieti.site/)

S'ha de veure una pàgina web amb **"Hello World"**

Anar amb el navegador a [https://nomUsuari.ieti.site/web.html](https://nomUsuari.ieti.site/web.html)

S'ha de veure una pàgina web amb
**"Hello Web HTML"**

## Continguts estàtics (servir arxius públic)

Els continguts estàtics són aquells que no canvien, solen ser els arxius de la carpeta **"./public"** i s'entreguen al client tal i com són.

Per exemple la URL [https://nomUsuari.ieti.site/web.html](https://nomUsuari.ieti.site/web.html)

El servidor d'exemple configura la carpeta **"./public"** com la que conté arxius estàtics, normalment es posa aquest nom per deixar clar que tot el què estigui allà dins està accessible lliurement des de Internet.

```javascript
// Continguts estàtics (carpeta public)
app.use(express.static('public'))
```

## Arrencar i aturar el servidor

Tots els processos i configuracions que cal fer abans d'arrencar el servidor, s'han de fer abans de **app.listen**, ja que aquesta línia posa en funcionament el servidor:

```javascript
// Activar el servidor
const httpServer = app.listen(port, appListen)
function appListen () {
    console.log(`Example app listening on: http://0.0.0.0:${port}`)
}
```

Quan s'atura el servidor també es pot necessitar executar codi de finalització, per exemple tancar la connexió amb una base de dades o guardar una configuració. Això cal fer-ho al principi de la funció **shutDown**

```javascript
// Aturar el servidor correctament 
process.on('SIGTERM', shutDown);
process.on('SIGINT', shutDown);
function shutDown() {
    // Executar aquí el codi previ al tancament de servidor

    console.log('Received kill signal, shutting down gracefully');
    httpServer.close()
    process.exit(0);
}
```