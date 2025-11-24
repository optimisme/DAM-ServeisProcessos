<div style="display: flex; width: 100%;">
    <div style="flex: 1; padding: 0px;">
        <p>© Albert Palacios Jiménez, 2024</p>
    </div>
    <div style="flex: 1; padding: 0px; text-align: right;">
        <img src="./assets/ieti.png" height="32" alt="Logo de IETI" style="max-height: 32px;">
    </div>
</div>
<br/>

# Node.js

**[Node.js](https://nodejs.org/en)** és un entorn basat en JavaScript que permet  crear programes de xarxa altament escalables, com per exemple servidors web.

## Instal·lació

Per instral·lar Node.js amb [gestors de paquets](https://nodejs.org/en/download/package-manager):

A Linux:
```bash
sudo apt install npm unzip
sudo npm cache clean -f
sudo npm install -g n
sudo n latest
```

A MacOS:
```bash
sudo brew install node
sudo npm cache clean -f
sudo npm install -g n
sudo n latest
```
A Windows:
```bash
winget install Schniz.fnm
fnm env --use-on-cd | Out-String | Invoke-Expression
fnm use --install-if-missing 22
fnm install latest
fnm use latest
```

## Nou projecte

Per crear un nou projecte:
```bash
mkdir "Exemple 0"
cd "Exemple 0"
npm init -y
touch index.js
```

Un cop creat el projecte apareix l'arxiu **"package.json"** que defineix la configuració del projecte.

**Nota**: En aquesta configuració, l'arxiu inicial és: **"index.js"**, però cal crear-lo manualment (amb touch per exemple).

# Javascript

## Codi

- En JavaScript no cal posar “;” al final de cada línia
- “;” serveix per separar instruccions en una mateixa línia
- Els comentaris són amb // per una línia i /* */ per blocs de text
- Per escriure informació per consola es fa servir:

    * **console.log** per mostrar informació general.
    * **console.warn** per mostrar advertències.
    * **console.error** per mostrar missatges d’error.

- Les cadenes de text poden tenir variables si estàn entre caràcters ` (accent obert)
```javascript
nom = "Maria"
console.log(`Hola ${nom}`) // Output: Hola Maria
```

## Variables

- JavaScript **NO** defineix el tipus de variables (int, bool, ...)
- **var** aquestes variables només tenen àmbit dins de la funció on s'han declarat
- **let** només tenen àmbit dins el bloc *{, }* on s'han declarat. Per exemple, una *funció*, un *if* o un *for*.
- **const** també tenen àmbit de bloc però no es poden reasignar, són constants

JavaScript permet canviar el tipus de les variables:

```javascript
var a = 4
a = "hola"
```

**Important**: canvar el tipus de les variables **és una mala pràctica**, perquè perjudica el rendiment i pot generar bugs.

Els tipus de variables són:
- **undefined**: una variable que ha estat declarada però no inicialitzada.
- **null**: absència intencionada d’un valor. 
- **Number**: val per enter, float i double
- **String**: cadenes de text
- **Boolean**: boolean
- **Array**: poden contenir dades de diferents tipus
```javascript
let arr = [1, "text", true]
```
- **Objectes**: equival als diccionaris de Python
```javascript
let person = { name: "John", age: 30 }
```

Per obtenir el tipus d'una variable:
```javascript
let x = 10
console.log(typeof x) // Output: "number"
```

## Comparacions

En JavaScript es compara amb “==” i també amb “===”:

- **==** comparació valor
```javascript
(“3” == 3) // és true
```

- **===** comparació de valor i tipus
per exemple la comparació (“3” === 3) és false
```javascript
(“3” === 3) // és false
```

Així:
```javascript
"3" != 3  // false
"3" !== 3 // true, perquè són tipus diferents

"5" > 3   // true, perquè "5" es converteix a nombre
"10" < 20 // true, perquè "10" es converteix a nombre

null == undefined  // true
null === undefined // false
NaN == NaN   // false perquè NaN és diferent
NaN === NaN  // a qualsevol valor inclòs ell mateix
```

## Condicions

Exemples de condicions:

```javascript
if (condicio) {
  // codi a executar si la condició és certa
}
```

```javascript
if (condicio1) {
  // codi si condicio1 és certa
} else if (condicio2) {
  // codi si condicio2 és certa
} else {
  // codi si cap condició és certa
}
```

## Bucles for/forEach

Exemples de bucles for:

```javascript
// for tradicional
for (let i = 0; i < 5; i++) {
  console.log("Iteració:", i)
}
```

```javascript
// for d'elements d'una llista/array
let fruits = ["poma", "plàtan", "maduixa"]
for (let fruit of fruits) {
  console.log(fruit)
}
```

```javascript
// forEach d'elements d'una llista/array
let colors = ["vermell", "blau", "groc"]
colors.forEach(function(color) {
  console.log(color)
})
```

```javascript
// for de claus d'un objecte/diccionari
let person = { name: "Joan", age: 30, city: "Barcelona" }
for (let key in person) {
  console.log(key + ": " + person[key])
}
```

## Bucles map/filter

Javascript permet aplicar una funció o un filtre de manera atòmica a tots els elements d'una llista:

- **.map** aplica una funció a cada un dels elements d’un array
```javascript
let numbers = [1, 2, 3, 4, 5]
let doubled = numbers.map(num => num * 2)
console.log(doubled) // Output: [2, 4, 6, 8, 10]
```

- **.filter** permet filtrar els elements d’un array (si la funció definida torna ‘true’)
```javascript
let numbers = [1, 2, 3, 4, 5]
let doubledEvens = numbers
  .filter(num => num % 2 === 0) // Filtra els parells
  .map(num => num * 2)          // Duplica els parells
console.log(doubledEvens)       // Output: [4, 8]
```

## Funcions

Les funcions accepten paràmetres sense definir el tipus. Opcionalment es poden retornar valors amb *"return"*.

```javascript
function suma(a, b) {
  return a + b
}
let resultat = suma(3, 4)
console.log(resultat)  // Output: 7
```

JavaScript permet definir paràmetres opcionals, que assignen un valor per defecte:

```javascript
function saluda(nom = "amic") {
  console.log("Hola, " + nom + "!")
}

saluda("Maria")  // Output: Hola, Maria!
saluda()         // Ouput: Hola, amic!
```

## Classes

Exemple de definició d'objectes/classes:
```javascript
class Rectangle {
   constructor (width, height) {
       this.width = width
       this.height = height
   }
   area () {
       return this.width * this.height
   }
}
var rect = new Rectangle(100, 50)
```

- El constructor es diu **“constructor”**
- **No cal definir les propietats de l’objecte**, es poden afegir a mida que fan falta

**Nota**: No és aconsellable definir propietats noves fora del constructor

## Objectes literals

Un **objecte literal** és un objecte creat directament amb {}, sense necessitat d'una classe.

Els objectes literals permeten accedir als atributs de dues maneres:

- *["nomAtribut"]*
- *.nomAtribut*

```javascript
let persona = {
  nom: "Toni",
  edat: 10
}

console.log(persona["nom"]) // Output: Toni
console.log(persona.nom)    // Output: Toni
```

## Async/Await

Per evitar bloquejar l'aplicació, JavaScript permet definir funcions **asíncrones**, que esperen una resposta tot i no saber quanta estona trigarà a arribar.

Aquestes funcions retornen una **promise**, és com una promesa que tot i trigar en algun moment donaràn resposta.

Per exemple:

- Llegir o escriure un arxiu
- Fer una consulta a un servidor
- ...

Les funcions **async** faciliten treballar amb promeses. 

Quan una funció es defineix com **async**, podem utilitzar la paraula clau **await** dins d’ella per "esperar" el resultat d'una promesa sense bloquejar el codi.

```javascript
async function processFile() {
  try {
    let data = await readFile()
        // Espera que la promesa es completi
    console.log(data)
        // Output: "Dades de l'arxiu"
  } catch (error) {
    console.error(error);
  }
}

processFile()
```

**Nota**: En el cas anterior, el codi de després de la crida *processFile()* s'executa encara que la funció no hagi acabat, perquè està esperant rebre les dades de *readFile()*

## Escriptura per linia de comandes

Per obtenir dades a través de la línia de comandes, cal la llibreria "readline"

Les dades es llegeixen a través d'una interfície i no sabem quan estaràn disponibles, per això fem una funció que retorna una **promesa** i es resol amb el valor correcte quan l'usuari acaba d'escriure.

```javascript
const readline = require('readline').promises

async function main() {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    })

    const nom = await rl.question("Com et dius? ")
    console.log(`Hola ${nom}!`)
    rl.close() // Tancar la lectura 'readline'
}

main()
```

## Objectes i arxius JSON

JavaScript té completament integrat el format JSON. Això permet transformar objectes cap a JSON i a l'inrevés:

**Escriure** un objecte a un fitxer *.json*:
```javascript
const fs = require('fs').promises

async function writeData() {
  const data = {
    name: "Maria",
    age: 25,
    city: "Barcelona"
  }

  try {
    const jsonData = JSON.stringify(data, null, 2)
    await fs.writeFile('data.json', jsonData, 'utf-8')
    console.log("Dades escrites a data.json")
  } catch (error) {
    console.error("Error en escriure les dades:", error)
  }
}
```

**Llegir** un arxiu *.json* cap a un objecte:
```javascript
const fs = require('fs').promises
async function readData() {
  try {
    const jsonData = await fs.readFile('data.json', 'utf-8')
    const data = JSON.parse(jsonData)
    console.log("Dades llegides del fitxer:", data)
  } catch (error) {
    console.error("Error en llegir les dades:", error)
  }
}
```

## Exemple 0

En aquest exemple es pot veure com s'escriu i es llegeix un arxiu *.json* a partir d'un objecte JavaScript.

Per fer anar el codi:
```bash
node index.js 
```

**Important**: es pot guardar atributs d'objectes literals en format .json, però no funcions.

```javascript
const fs = require('fs').promises
const readline = require('readline').promises

// Funció per escriure un objecte en un arxiu .json
async function writeData(obj, file_path) {
    try {
        const txtData = JSON.stringify(obj, null, 2)
        await fs.writeFile(file_path, txtData, 'utf-8')
        console.log(`Dades escrites a ${file_path}`)
    } catch (error) {
        console.error("Error en escriure les dades:", error)
    }
}

// Funció per llegir un arxiu .json cap a un objecte
async function readData(file_path) {
    try {
        const txtData = await fs.readFile(file_path, 'utf-8')
        const data = JSON.parse(txtData)
        return data
    } catch (error) {
        console.error("Error en llegir les dades:", error)
    }
}

async function main() {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
    })

    const path = await rl.question("Nom de l'arxiu a generar? ")

    const person = {
        name: "Maria",
        age: 25,
        city: "Barcelona"
    }

    await writeData(person, path)
    const json_data = await readData(path)
    console.log(json_data)

    rl.close() // Tancar la lectura 'readline'
}

main()
```

