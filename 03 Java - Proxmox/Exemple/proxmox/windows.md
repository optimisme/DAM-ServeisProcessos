# Fer anar els scripts des de Windows

Cal tenir instal·lat Windows Subsystem for Linux, és a dir un terminal Ubuntu a Windows. 

Es pot instal·lar la última versió d'un terminal Ubuntu des de la botiga d'aplicacions de Windows.

A l'arxiu de configuració el camí a la clau privada RSA serà d'aquest estil (ruta a partir de /mnt/c/...):
```bash
DEFAULT_RSA_PATH="/mnt/c/Users/optim/Desktop/Proxmox IETI/id_rsa"
```


Quan editeu els arxius des de Windows, els haureu d'arreglar perquè funcionin amb WSL, feu servir l'script:
```bash
./windowsFixFilesForWSL.sh
```

Us caldrà instal·lar:
```bash
sudo apt install zip unzip dos2unix
```
