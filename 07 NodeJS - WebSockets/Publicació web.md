# Flutter al web

Per publicar una aplicació flutter com a pàgina web, cal seguir diversos passos:

**Afegir 'web' com a plataforma de compilació:**

```bash
flutter create . --platforms web
```

Compilar el projecte web:

```bash
flutter build web --wasm --base-href "/web/"
```

**Nota:** Per defecte flutter defineix la carpeta base de la pàgina web, com a l'arrel del servidor "/". Però si es vol posar en una carpeta diferent dins de public, per exmple dins "public/web" s'ha de definir --base-href i es canvia el tag <base> dins de index.html

**Publicar web al servidor**

Aleshores es pot copiar la web generada al servidor NodeJS:

```bash
# En local
cp -r ./build/web ../server/public/web

# Al proxmox
zip -r web.zip ./build/web
scp -i folder/id_rsa -P 20127 ./web.zip usuari@ieticloudpro.ieti.cat:/home/super/public/
unzip web.zip
mv build/web web
```

I accedir amb la direcció normal:

```text
http://localhost:3000/web
https://usuari.ieti.site/web
```

# Actualitzar NodeJS al Proxmox

Per actualitzar NodeJS al Proxmox:

```bash
sudo apt install npm
sudo npm install -g n
sudo n latest
```